#requires -version 5.1

param(
    [string]$ExpectedComputerName = '',
    [string]$EnrollmentId = '',
    [string]$ExpectedIntuneDeviceId = '',
    [string]$MdmCertificateThumbprint = '',
    [string]$KeyContainer = '',
    [string]$CryptoProvider = 'Microsoft Platform Crypto Provider',
    [switch]$Execute,
    [switch]$KeepIntuneManagementExtension,
    [switch]$KeepPolicyManagerCurrent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes one specifically identified, broken local Intune MDM enrollment.

.DESCRIPTION
    This is a last-resort local repair tool for a Windows device where the
    supported Access work or school Disconnect action did not remove the old
    machine-level Intune enrollment.

    The script defaults to audit-only mode. It makes changes only when -Execute
    is supplied and all device, enrollment, certificate, provider, and key
    identity checks pass.

    The script preserves the on-premises Active Directory domain join. It does
    not clear the TPM, remove BitLocker protectors, delete cloud objects, or
    delete per-user WAM or Microsoft Entra registration data.

    Before execution, the affected user must disconnect the Hall County entry
    under Settings > Accounts > Access work or school in that user's session.

.NOTES
    Version:        1.0.1
    Script Type:    Standalone elevated repair script
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  12/08/2026
    Purpose:        Remove one corrupt local Intune enrollment before reenrollment

    CHANGE LOG
    Change: 12/08/2026 - Initial release -- ver. 1.0.0
    Change: 12/08/2026 - Audit fixes -- ver. 1.0.1
        - Replaced a tautological self-comparison in the IME residual-path move
          guard with a real reparse-point check.
        - Restricted the backup ROOT directory (not just the per-run timestamped
          subfolder) to SYSTEM and local Administrators.
        - Replaced Split-Path -Leaf with [System.IO.Path]::GetFileName() to avoid
          a documented PS 5.1 Split-Path parameter-binding pitfall and wildcard
          interpretation risk.

    This script uses certutil only against the exact key container recorded in
    the verified Intune enrollment. If certutil cannot delete that container,
    the script stops. Do not delete raw TPM or crypto-provider files manually.
#>

#region CONFIGURATION
$script:ScriptVersion = '1.0.1'
$script:BackupRoot = 'C:\IntuneEnrollmentCleanupBackup'
$script:LogPath = $null
$script:Utf8BomEncoding = New-Object `
    -TypeName 'System.Text.UTF8Encoding' `
    -ArgumentList $true
$script:RegExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
$script:CertUtilExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\certutil.exe'
$script:DsRegCmdExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dsregcmd.exe'
$script:MsiExecExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
$script:IcaclsExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\icacls.exe'
#endregion CONFIGURATION

function Write-ErrorLog {
    param(
        [string]$Category,
        [string]$Message
    )

    try {
        if (-not [string]::IsNullOrWhiteSpace($script:LogPath)) {
            $line = '[{0}] [v{1}] [{2}] {3}{4}' -f (
                Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            ), $script:ScriptVersion, $Category, $Message, [Environment]::NewLine
            [System.IO.File]::AppendAllText(
                $script:LogPath,
                $line,
                $script:Utf8BomEncoding
            )
        }
    }
    catch {
        # Logging must never mask the original error.
        [void]$_.Exception.Message
    }
}

function Write-OperatorMessage {
    param(
        [string]$Category,
        [string]$Message
    )

    $line = '[{0}] {1}' -f $Category, $Message
    [Console]::WriteLine($line)
    Write-ErrorLog -Category $Category -Message $Message
}

function Get-PropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Required executable not found: $FilePath"
    }

    $nativeOutput = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object {
        $_.ToString()
    })
    $nativeExitCode = $LASTEXITCODE

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        [System.IO.File]::WriteAllText(
            $OutputPath,
            (($nativeOutput -join [Environment]::NewLine) + [Environment]::NewLine),
            $script:Utf8BomEncoding
        )
    }

    return [pscustomobject]@{
        ExitCode = $nativeExitCode
        Output   = $nativeOutput
    }
}

function Get-DsRegValue {
    param(
        [string[]]$DsRegOutput,
        [string]$Name
    )

    foreach ($line in $DsRegOutput) {
        if ($line -match ('^\s*{0}\s*:\s*(\S+)' -f [regex]::Escape($Name))) {
            return $matches[1]
        }
    }

    return $null
}

function Get-TargetTaskFolderPaths {
    param(
        [string]$NormalizedEnrollmentId
    )

    $paths = New-Object -TypeName 'System.Collections.Generic.List[string]'
    try {
        $taskService = New-Object -ComObject 'Schedule.Service'
        $taskService.Connect()
        $parentFolder = $taskService.GetFolder('\Microsoft\Windows\EnterpriseMgmt')
        foreach ($folder in @($parentFolder.GetFolders(0))) {
            $candidate = $folder.Name.Trim([char[]]'{}')
            if ($candidate -ieq $NormalizedEnrollmentId) {
                $paths.Add([string]$folder.Path)
            }
        }
    }
    catch {
        $fileNotFoundHResult = -2147024894
        if ($_.Exception.HResult -ne $fileNotFoundHResult) {
            throw
        }
    }

    return @($paths.ToArray())
}

function Export-TaskFolderEvidence {
    param(
        [string]$TaskFolderPath,
        [string]$DestinationDirectory
    )

    $taskService = New-Object -ComObject 'Schedule.Service'
    $taskService.Connect()
    $folder = $taskService.GetFolder($TaskFolderPath)

    foreach ($task in @($folder.GetTasks(1))) {
        $safeName = [regex]::Replace($task.Name, '[^A-Za-z0-9._-]', '_')
        $outputFile = Join-Path -Path $DestinationDirectory -ChildPath ($safeName + '.xml')
        [System.IO.File]::WriteAllText(
            $outputFile,
            [string]$task.Xml,
            $script:Utf8BomEncoding
        )
    }

    foreach ($childFolder in @($folder.GetFolders(0))) {
        Export-TaskFolderEvidence `
            -TaskFolderPath ([string]$childFolder.Path) `
            -DestinationDirectory $DestinationDirectory
    }
}

function Remove-TaskFolderRecursive {
    param(
        [object]$TaskService,
        [string]$TaskFolderPath
    )

    $folder = $TaskService.GetFolder($TaskFolderPath)

    foreach ($childFolder in @($folder.GetFolders(0))) {
        Remove-TaskFolderRecursive `
            -TaskService $TaskService `
            -TaskFolderPath ([string]$childFolder.Path)
    }

    foreach ($task in @($folder.GetTasks(1))) {
        $folder.DeleteTask([string]$task.Name, 0)
    }

    $lastSeparator = $TaskFolderPath.LastIndexOf('\')
    if ($lastSeparator -lt 1) {
        throw "Refusing to delete unexpected task folder path: $TaskFolderPath"
    }

    $parentPath = $TaskFolderPath.Substring(0, $lastSeparator)
    $folderName = $TaskFolderPath.Substring($lastSeparator + 1)
    $parentFolder = $TaskService.GetFolder($parentPath)
    $parentFolder.DeleteFolder($folderName, 0)
}

function Export-RegistryRoot {
    param(
        [string]$PowerShellPath,
        [string]$NativePath,
        [string]$DestinationFile
    )

    if (-not (Test-Path -LiteralPath $PowerShellPath)) {
        return
    }

    $result = Invoke-NativeCommand `
        -FilePath $script:RegExe `
        -ArgumentList @('export', $NativePath, $DestinationFile, '/y') `
        -OutputPath ''

    if ($result.ExitCode -ne 0) {
        throw "Registry export failed for $NativePath with exit code $($result.ExitCode)."
    }
}

function Get-IntuneManagementExtensionProducts {
    $products = New-Object -TypeName 'System.Collections.Generic.List[object]'
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)) {
            $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            $displayName = Get-PropertyValue -InputObject $item -PropertyName 'DisplayName'
            if ([string]$displayName -eq 'Microsoft Intune Management Extension') {
                $products.Add([pscustomobject]@{
                    RegistryPath = [string]$key.PSPath
                    ProductCode  = [string]$key.PSChildName
                    DisplayName  = [string]$displayName
                    Version      = [string](
                        Get-PropertyValue -InputObject $item -PropertyName 'DisplayVersion'
                    )
                })
            }
        }
    }

    return @($products.ToArray())
}

function Uninstall-IntuneManagementExtension {
    param(
        [string]$BackupDirectory
    )

    $imeService = Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
    if ($null -ne $imeService -and $imeService.Status -ne 'Stopped') {
        Stop-Service -Name 'IntuneManagementExtension' -Force -ErrorAction Stop
        $imeService.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }

    $products = @(Get-IntuneManagementExtensionProducts)
    if ($products.Count -gt 1) {
        throw 'Multiple Microsoft Intune Management Extension uninstall entries were found.'
    }

    if ($products.Count -eq 1) {
        $productCode = $products[0].ProductCode
        $parsedProductCode = [guid]::Empty
        if (-not [guid]::TryParse($productCode, [ref]$parsedProductCode)) {
            throw "IME uninstall entry does not have a GUID product code: $productCode"
        }

        $msiLog = Join-Path -Path $BackupDirectory -ChildPath 'IME-Uninstall.log'
        $result = Invoke-NativeCommand `
            -FilePath $script:MsiExecExe `
            -ArgumentList @(
                '/x',
                ('{' + $parsedProductCode.ToString().ToUpperInvariant() + '}'),
                '/qn',
                '/norestart',
                '/L*v',
                $msiLog
            ) `
            -OutputPath ''

        $acceptedCodes = @(0, 1605, 1614, 3010, 1641)
        if ($acceptedCodes -notcontains $result.ExitCode) {
            throw "IME uninstall failed with MSI exit code $($result.ExitCode)."
        }
    }
    elseif ($null -ne $imeService) {
        throw 'IME service exists, but its Windows Installer uninstall entry is missing.'
    }

    $residualRoot = Join-Path -Path $BackupDirectory -ChildPath 'IME-Residual'
    [void][System.IO.Directory]::CreateDirectory($residualRoot)
    $residualPaths = @(
        'C:\Program Files (x86)\Microsoft Intune Management Extension',
        'C:\ProgramData\Microsoft\IntuneManagementExtension'
    )

    foreach ($residualPath in $residualPaths) {
        if (-not (Test-Path -LiteralPath $residualPath)) {
            continue
        }

        $sourceItem = Get-Item -LiteralPath $residualPath -Force -ErrorAction Stop
        if ($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw (
                "Refusing to move IME residual path because it is a reparse point, " +
                "not a real directory: $residualPath"
            )
        }

        $leafName = [System.IO.Path]::GetFileName($residualPath)
        if ($residualPath -like 'C:\Program Files*') {
            $leafName = 'ProgramFiles-' + $leafName
        }
        else {
            $leafName = 'ProgramData-' + $leafName
        }

        $destination = Join-Path -Path $residualRoot -ChildPath $leafName
        $resolvedDestination = [System.IO.Path]::GetFullPath($destination)
        $resolvedResidualRoot = [System.IO.Path]::GetFullPath($residualRoot).TrimEnd('\') + '\'
        if (-not $resolvedDestination.StartsWith(
            $resolvedResidualRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to move IME data outside the backup root: $resolvedDestination"
        }

        Move-Item `
            -LiteralPath $residualPath `
            -Destination $destination `
            -Force `
            -ErrorAction Stop
    }

    $imeRegistryPath = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension'
    if (Test-Path -LiteralPath $imeRegistryPath) {
        Remove-Item `
            -LiteralPath $imeRegistryPath `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }
}

function Remove-PolicyManagerCurrentState {
    param(
        [string]$NormalizedEnrollmentId
    )

    $root = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current'
    if (-not (Test-Path -LiteralPath $root)) {
        return
    }

    $keys = @((Get-Item -LiteralPath $root -ErrorAction Stop)) +
        @(Get-ChildItem -LiteralPath $root -Recurse -ErrorAction Stop)

    foreach ($key in $keys) {
        $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
        $properties = @($item.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        })
        $baseNames = New-Object -TypeName 'System.Collections.Generic.List[string]'

        foreach ($property in $properties) {
            $valueText = [string]($property.Value -join '|')
            if ($valueText.IndexOf(
                $NormalizedEnrollmentId,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -lt 0) {
                continue
            }

            if ($property.Name -match '^(.*)_(WinningProvider|ADMXInstanceData)$') {
                if (-not $baseNames.Contains($matches[1])) {
                    $baseNames.Add($matches[1])
                }
            }
            elseif (-not $baseNames.Contains($property.Name)) {
                $baseNames.Add($property.Name)
            }
        }

        $propertiesToRemove = New-Object `
            -TypeName 'System.Collections.Generic.List[string]'
        foreach ($baseName in @($baseNames.ToArray())) {
            foreach ($property in $properties) {
                $matchesPolicyFamily = $property.Name -eq $baseName -or
                    $property.Name.StartsWith(
                        $baseName + '_',
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                if ($matchesPolicyFamily -and
                    -not $propertiesToRemove.Contains($property.Name)) {
                    $propertiesToRemove.Add($property.Name)
                }
            }
        }

        foreach ($propertyName in @($propertiesToRemove.ToArray())) {
            Remove-ItemProperty `
                -LiteralPath $key.PSPath `
                -Name $propertyName `
                -Force `
                -ErrorAction Stop
        }
    }
}

function Remove-EnterpriseDesktopAppState {
    param(
        [string]$NormalizedEnrollmentId
    )

    $root = 'HKLM:\SOFTWARE\Microsoft\EnterpriseDesktopAppManagement'
    if (-not (Test-Path -LiteralPath $root)) {
        return
    }

    $matchingKeys = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($key in @(Get-ChildItem -LiteralPath $root -Recurse -ErrorAction Stop)) {
        $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
        $serverAccountId = Get-PropertyValue `
            -InputObject $item `
            -PropertyName 'ServerAccountID'
        if ([string]$serverAccountId -ieq $NormalizedEnrollmentId) {
            $matchingKeys.Add([string]$key.PSPath)
        }
    }

    foreach ($registryPath in @(
        $matchingKeys.ToArray() | Sort-Object -Property Length -Descending
    )) {
        if (Test-Path -LiteralPath $registryPath) {
            Remove-Item `
                -LiteralPath $registryPath `
                -Recurse `
                -Force `
                -ErrorAction Stop
        }
    }
}

function Remove-ExactEnrollmentRegistryState {
    param(
        [string]$NormalizedEnrollmentId,
        [bool]$RemoveCurrentPolicyState
    )

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Enrollments\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Enrollment\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$NormalizedEnrollmentId"
    )

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item `
                -LiteralPath $path `
                -Recurse `
                -Force `
                -ErrorAction Stop
        }
    }

    $loggerPath = 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger'
    if (Test-Path -LiteralPath $loggerPath) {
        $logger = Get-ItemProperty -LiteralPath $loggerPath -ErrorAction Stop
        $currentEnrollmentId = Get-PropertyValue `
            -InputObject $logger `
            -PropertyName 'CurrentEnrollmentId'
        if ([string]$currentEnrollmentId -ieq $NormalizedEnrollmentId) {
            Remove-ItemProperty `
                -LiteralPath $loggerPath `
                -Name 'CurrentEnrollmentId' `
                -Force `
                -ErrorAction Stop
        }
    }

    Remove-EnterpriseDesktopAppState `
        -NormalizedEnrollmentId $NormalizedEnrollmentId

    if ($RemoveCurrentPolicyState) {
        Remove-PolicyManagerCurrentState `
            -NormalizedEnrollmentId $NormalizedEnrollmentId
    }
}

function Test-CleanupState {
    param(
        [string]$NormalizedEnrollmentId,
        [string]$NormalizedThumbprint,
        [string]$NormalizedKeyContainer,
        [string]$NormalizedCryptoProvider,
        [bool]$ExpectImeRemoved,
        [string]$VerificationDirectory
    )

    $failures = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $criticalPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Enrollments\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Enrollment\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$NormalizedEnrollmentId",
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$NormalizedEnrollmentId"
    )

    foreach ($path in $criticalPaths) {
        if (Test-Path -LiteralPath $path) {
            $failures.Add("Registry path remains: $path")
        }
    }

    $taskFolders = @(Get-TargetTaskFolderPaths `
        -NormalizedEnrollmentId $NormalizedEnrollmentId)
    foreach ($taskFolder in $taskFolders) {
        $failures.Add("EnterpriseMgmt task folder remains: $taskFolder")
    }

    $certificatePath = "Cert:\LocalMachine\My\$NormalizedThumbprint"
    if (Test-Path -LiteralPath $certificatePath) {
        $failures.Add("MDM certificate remains: $NormalizedThumbprint")
    }

    $keyCheckPath = Join-Path -Path $VerificationDirectory -ChildPath 'Key-After.txt'
    $keyCheck = Invoke-NativeCommand `
        -FilePath $script:CertUtilExe `
        -ArgumentList @(
            '-csp',
            $NormalizedCryptoProvider,
            '-key',
            $NormalizedKeyContainer
        ) `
        -OutputPath $keyCheckPath
    $keyCheckText = $keyCheck.Output -join [Environment]::NewLine
    $keyIsMissing = $keyCheckText -match '(?i)(NTE_BAD_KEYSET|Keyset does not exist)'
    if ($keyCheck.ExitCode -ne 0 -and -not $keyIsMissing) {
        $failures.Add(
            "Crypto key verification failed with exit code $($keyCheck.ExitCode)."
        )
    }
    elseif (-not $keyIsMissing) {
        $failures.Add("Crypto key container remains: $NormalizedKeyContainer")
    }

    if ($ExpectImeRemoved) {
        if ($null -ne (Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue)) {
            $failures.Add('IntuneManagementExtension service remains.')
        }
        if (@(Get-IntuneManagementExtensionProducts).Count -gt 0) {
            $failures.Add('Intune Management Extension uninstall entry remains.')
        }
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension') {
            $failures.Add('IntuneManagementExtension registry state remains.')
        }
        if (Test-Path -LiteralPath 'C:\Program Files (x86)\Microsoft Intune Management Extension') {
            $failures.Add('IME Program Files directory remains.')
        }
        if (Test-Path -LiteralPath 'C:\ProgramData\Microsoft\IntuneManagementExtension') {
            $failures.Add('IME ProgramData directory remains.')
        }
    }

    return @($failures.ToArray())
}

try {
    if (-not [Environment]::Is64BitProcess) {
        throw 'Run this script in 64-bit Windows PowerShell 5.1.'
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object `
        -TypeName 'Security.Principal.WindowsPrincipal' `
        -ArgumentList $identity
    if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw 'Run this script from an elevated Windows PowerShell session.'
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedComputerName)) {
        throw 'ExpectedComputerName is required.'
    }
    if ([string]::IsNullOrWhiteSpace($EnrollmentId)) {
        throw 'EnrollmentId is required.'
    }
    if ([string]::IsNullOrWhiteSpace($MdmCertificateThumbprint)) {
        throw 'MdmCertificateThumbprint is required.'
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedIntuneDeviceId)) {
        throw 'ExpectedIntuneDeviceId is required.'
    }
    if ([string]::IsNullOrWhiteSpace($KeyContainer)) {
        throw 'KeyContainer is required.'
    }
    if ([string]::IsNullOrWhiteSpace($CryptoProvider)) {
        throw 'CryptoProvider is required.'
    }

    $parsedEnrollmentId = [guid]::Empty
    if (-not [guid]::TryParse($EnrollmentId, [ref]$parsedEnrollmentId)) {
        throw "EnrollmentId is not a valid GUID: $EnrollmentId"
    }
    $normalizedEnrollmentId = $parsedEnrollmentId.ToString().ToUpperInvariant()
    $parsedIntuneDeviceId = [guid]::Empty
    if (-not [guid]::TryParse($ExpectedIntuneDeviceId, [ref]$parsedIntuneDeviceId)) {
        throw "ExpectedIntuneDeviceId is not a valid GUID: $ExpectedIntuneDeviceId"
    }
    $normalizedIntuneDeviceId = $parsedIntuneDeviceId.ToString().ToLowerInvariant()
    $normalizedThumbprint = ($MdmCertificateThumbprint -replace '\s', '').ToUpperInvariant()
    if ($normalizedThumbprint -notmatch '^[A-F0-9]{40}$') {
        throw 'MdmCertificateThumbprint must be a 40-character SHA-1 thumbprint.'
    }
    $normalizedKeyContainer = $KeyContainer.Trim()
    $normalizedCryptoProvider = $CryptoProvider.Trim()

    if ($env:COMPUTERNAME -ine $ExpectedComputerName.Trim()) {
        throw (
            "Computer-name safety check failed. Expected '$ExpectedComputerName'; " +
            "actual '$($env:COMPUTERNAME)'."
        )
    }

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if (-not [bool]$computerSystem.PartOfDomain) {
        throw 'This repair script is restricted to an on-premises domain-joined device.'
    }

    $dsregBefore = Invoke-NativeCommand `
        -FilePath $script:DsRegCmdExe `
        -ArgumentList @('/status') `
        -OutputPath ''
    if ($dsregBefore.ExitCode -ne 0) {
        throw "dsregcmd /status failed with exit code $($dsregBefore.ExitCode)."
    }

    $azureAdJoined = Get-DsRegValue `
        -DsRegOutput $dsregBefore.Output `
        -Name 'AzureAdJoined'
    $domainJoined = Get-DsRegValue `
        -DsRegOutput $dsregBefore.Output `
        -Name 'DomainJoined'
    if ([string]$azureAdJoined -ine 'NO') {
        throw "AzureAdJoined must be NO for this repair workflow; actual value: $azureAdJoined"
    }
    if ([string]$domainJoined -ine 'YES') {
        throw "DomainJoined must be YES for this repair workflow; actual value: $domainJoined"
    }

    $enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\$normalizedEnrollmentId"
    if (-not (Test-Path -LiteralPath $enrollmentPath)) {
        throw "Target enrollment registry path was not found: $enrollmentPath"
    }

    $enrollment = Get-ItemProperty -LiteralPath $enrollmentPath -ErrorAction Stop
    $providerId = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'ProviderID')
    $discoveryUrl = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'DiscoveryServiceFullURL')
    $actualThumbprint = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'DMPCertThumbPrint')
    $actualKeyContainer = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'CurKeyContainer')
    $actualCryptoProvider = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'CurCryptoProvider')
    $enrollmentUpn = [string](Get-PropertyValue `
        -InputObject $enrollment `
        -PropertyName 'UPN')
    $dmClientPath = Join-Path `
        -Path $enrollmentPath `
        -ChildPath 'DMClient\MS DM Server'
    if (-not (Test-Path -LiteralPath $dmClientPath)) {
        throw "Target Intune DMClient state was not found: $dmClientPath"
    }
    $dmClient = Get-ItemProperty -LiteralPath $dmClientPath -ErrorAction Stop
    $actualIntuneDeviceId = [string](Get-PropertyValue `
        -InputObject $dmClient `
        -PropertyName 'EntDMID')

    if ($providerId -ine 'MS DM Server') {
        throw "Target enrollment ProviderID is not Intune MS DM Server: $providerId"
    }
    if ($discoveryUrl -notmatch '(?i)manage\.microsoft\.com') {
        throw "Target enrollment discovery URL is not an Intune URL: $discoveryUrl"
    }
    if ($actualIntuneDeviceId -ine $normalizedIntuneDeviceId) {
        throw (
            "Intune-device-ID safety check failed. Expected '$normalizedIntuneDeviceId'; " +
            "enrollment records '$actualIntuneDeviceId'."
        )
    }
    if (($actualThumbprint -replace '\s', '').ToUpperInvariant() -cne
        $normalizedThumbprint) {
        throw (
            "Certificate safety check failed. Expected '$normalizedThumbprint'; " +
            "enrollment records '$actualThumbprint'."
        )
    }
    if ($actualKeyContainer -cne $normalizedKeyContainer) {
        throw (
            "Key-container safety check failed. Expected '$normalizedKeyContainer'; " +
            "enrollment records '$actualKeyContainer'."
        )
    }
    if ($actualCryptoProvider -cne $normalizedCryptoProvider) {
        throw (
            "Crypto-provider safety check failed. Expected '$normalizedCryptoProvider'; " +
            "enrollment records '$actualCryptoProvider'."
        )
    }

    $taskFoldersBefore = @(Get-TargetTaskFolderPaths `
        -NormalizedEnrollmentId $normalizedEnrollmentId)
    $certificatePath = "Cert:\LocalMachine\My\$normalizedThumbprint"
    $certificateBefore = Get-Item `
        -LiteralPath $certificatePath `
        -ErrorAction SilentlyContinue
    if ($null -eq $certificateBefore) {
        throw "The exact MDM certificate was not found: $normalizedThumbprint"
    }
    if ($certificateBefore.Issuer -notmatch '(?i)Microsoft Intune MDM Device CA') {
        throw (
            "Certificate issuer safety check failed. Actual issuer: " +
            "$($certificateBefore.Issuer)"
        )
    }
    if ($certificateBefore.Subject -notmatch [regex]::Escape($normalizedIntuneDeviceId)) {
        throw (
            "Certificate subject safety check failed. Expected Intune device ID " +
            "'$normalizedIntuneDeviceId'; actual subject '$($certificateBefore.Subject)'."
        )
    }
    if ($taskFoldersBefore.Count -eq 0) {
        throw (
            "No EnterpriseMgmt task folder matched enrollment $normalizedEnrollmentId."
        )
    }
    $certificateExists = $true
    $imeProductsBefore = @(Get-IntuneManagementExtensionProducts)
    $imeServiceBefore = Get-Service `
        -Name 'IntuneManagementExtension' `
        -ErrorAction SilentlyContinue

    $modeText = 'AUDIT ONLY - no changes'
    if ($Execute.IsPresent) {
        $modeText = 'EXECUTE'
    }
    Write-OperatorMessage -Category 'MODE' -Message $modeText
    Write-OperatorMessage -Category 'DEVICE' -Message (
        "Computer=$($env:COMPUTERNAME); Domain=$($computerSystem.Domain); " +
        "DomainJoined=$domainJoined; AzureAdJoined=$azureAdJoined"
    )
    Write-OperatorMessage -Category 'TARGET' -Message (
        "EnrollmentId=$normalizedEnrollmentId; IntuneDeviceId=$normalizedIntuneDeviceId; " +
        "UPN=$enrollmentUpn; ProviderID=$providerId"
    )
    Write-OperatorMessage -Category 'TARGET' -Message (
        "Certificate=$normalizedThumbprint; Present=$certificateExists; " +
        "KeyContainer=$normalizedKeyContainer; CryptoProvider=$normalizedCryptoProvider"
    )
    Write-OperatorMessage -Category 'TARGET' -Message (
        "EnterpriseMgmtFolders=$($taskFoldersBefore.Count); " +
        "IMEProducts=$($imeProductsBefore.Count); IMEServicePresent=$($null -ne $imeServiceBefore)"
    )
    Write-OperatorMessage -Category 'PRESERVE' -Message (
        'The AD domain join, TPM, BitLocker protectors, cloud objects, installed apps, ' +
        'and user WAM/Entra registration are not removed.'
    )

    if (-not $Execute.IsPresent) {
        Write-OperatorMessage -Category 'NEXT' -Message (
            'Review the values above. Rerun the same command with -Execute only after ' +
            'the affected user disconnects Access work or school.'
        )
        exit 0
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    [void][System.IO.Directory]::CreateDirectory($script:BackupRoot)
    $backupRootAclResult = Invoke-NativeCommand `
        -FilePath $script:IcaclsExe `
        -ArgumentList @(
            $script:BackupRoot,
            '/inheritance:r',
            '/grant:r',
            '*S-1-5-18:(OI)(CI)F',
            '*S-1-5-32-544:(OI)(CI)F'
        ) `
        -OutputPath ''
    if ($backupRootAclResult.ExitCode -ne 0) {
        throw (
            "Could not restrict the backup root directory to SYSTEM and Administrators. " +
            "icacls exit code: $($backupRootAclResult.ExitCode)."
        )
    }
    $backupDirectory = Join-Path `
        -Path $script:BackupRoot `
        -ChildPath ("$($env:COMPUTERNAME)_$timestamp")
    [void][System.IO.Directory]::CreateDirectory($backupDirectory)
    $backupAclResult = Invoke-NativeCommand `
        -FilePath $script:IcaclsExe `
        -ArgumentList @(
            $backupDirectory,
            '/inheritance:r',
            '/grant:r',
            '*S-1-5-18:(OI)(CI)F',
            '*S-1-5-32-544:(OI)(CI)F'
        ) `
        -OutputPath ''
    if ($backupAclResult.ExitCode -ne 0) {
        throw (
            "Could not restrict the backup directory to SYSTEM and Administrators. " +
            "icacls exit code: $($backupAclResult.ExitCode)."
        )
    }
    $script:LogPath = Join-Path -Path $backupDirectory -ChildPath 'Cleanup.log'
    [System.IO.File]::WriteAllText(
        $script:LogPath,
        '',
        $script:Utf8BomEncoding
    )

    Write-OperatorMessage -Category 'BACKUP' -Message "Backup directory: $backupDirectory"

    [System.IO.File]::WriteAllText(
        (Join-Path -Path $backupDirectory -ChildPath 'DsRegCmd-Before.txt'),
        (($dsregBefore.Output -join [Environment]::NewLine) + [Environment]::NewLine),
        $script:Utf8BomEncoding
    )

    $inputSummary = @(
        "ScriptVersion=$($script:ScriptVersion)",
        "ComputerName=$($env:COMPUTERNAME)",
        "Domain=$($computerSystem.Domain)",
        "EnrollmentId=$normalizedEnrollmentId",
        "IntuneDeviceId=$normalizedIntuneDeviceId",
        "EnrollmentUPN=$enrollmentUpn",
        "ProviderID=$providerId",
        "DiscoveryURL=$discoveryUrl",
        "CertificateThumbprint=$normalizedThumbprint",
        "KeyContainer=$normalizedKeyContainer",
        "CryptoProvider=$normalizedCryptoProvider",
        "RemoveIME=$(-not $KeepIntuneManagementExtension.IsPresent)",
        "RemovePolicyManagerCurrent=$(-not $KeepPolicyManagerCurrent.IsPresent)"
    )
    [System.IO.File]::WriteAllText(
        (Join-Path -Path $backupDirectory -ChildPath 'Cleanup-Inputs.txt'),
        (($inputSummary -join [Environment]::NewLine) + [Environment]::NewLine),
        $script:Utf8BomEncoding
    )

    $registryExports = @(
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\Enrollments'
            Native = 'HKLM\SOFTWARE\Microsoft\Enrollments'
            File   = 'Registry-Enrollments.reg'
        },
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager'
            Native = 'HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager'
            File   = 'Registry-EnterpriseResourceManager.reg'
        },
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager'
            Native = 'HKLM\SOFTWARE\Microsoft\PolicyManager'
            File   = 'Registry-PolicyManager.reg'
        },
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\Provisioning'
            Native = 'HKLM\SOFTWARE\Microsoft\Provisioning'
            File   = 'Registry-Provisioning.reg'
        },
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\EnterpriseDesktopAppManagement'
            Native = 'HKLM\SOFTWARE\Microsoft\EnterpriseDesktopAppManagement'
            File   = 'Registry-EnterpriseDesktopAppManagement.reg'
        },
        [pscustomobject]@{
            PSPath = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension'
            Native = 'HKLM\SOFTWARE\Microsoft\IntuneManagementExtension'
            File   = 'Registry-IntuneManagementExtension.reg'
        }
    )
    foreach ($registryExport in $registryExports) {
        Export-RegistryRoot `
            -PowerShellPath $registryExport.PSPath `
            -NativePath $registryExport.Native `
            -DestinationFile (Join-Path `
                -Path $backupDirectory `
                -ChildPath $registryExport.File)
    }

    $certificate = Get-Item -LiteralPath $certificatePath -ErrorAction SilentlyContinue
    if ($null -ne $certificate) {
        [System.IO.File]::WriteAllBytes(
            (Join-Path -Path $backupDirectory -ChildPath 'MDM-Certificate-Public.cer'),
            $certificate.RawData
        )
        $certificateSummary = @(
            "Subject=$($certificate.Subject)",
            "Issuer=$($certificate.Issuer)",
            "Thumbprint=$($certificate.Thumbprint)",
            "NotBefore=$($certificate.NotBefore.ToString('o'))",
            "NotAfter=$($certificate.NotAfter.ToString('o'))",
            "HasPrivateKey=$($certificate.HasPrivateKey)"
        )
        [System.IO.File]::WriteAllText(
            (Join-Path -Path $backupDirectory -ChildPath 'MDM-Certificate.txt'),
            (($certificateSummary -join [Environment]::NewLine) + [Environment]::NewLine),
            $script:Utf8BomEncoding
        )
    }

    [void](Invoke-NativeCommand `
        -FilePath $script:CertUtilExe `
        -ArgumentList @('-store', 'My', $normalizedThumbprint) `
        -OutputPath (Join-Path -Path $backupDirectory -ChildPath 'Certificate-Store-Before.txt'))
    [void](Invoke-NativeCommand `
        -FilePath $script:CertUtilExe `
        -ArgumentList @(
            '-csp',
            $normalizedCryptoProvider,
            '-key',
            $normalizedKeyContainer
        ) `
        -OutputPath (Join-Path -Path $backupDirectory -ChildPath 'Key-Before.txt'))

    $taskBackupDirectory = Join-Path -Path $backupDirectory -ChildPath 'EnterpriseMgmt-Tasks'
    [void][System.IO.Directory]::CreateDirectory($taskBackupDirectory)
    foreach ($taskFolderPath in $taskFoldersBefore) {
        Export-TaskFolderEvidence `
            -TaskFolderPath $taskFolderPath `
            -DestinationDirectory $taskBackupDirectory
    }

    Write-OperatorMessage -Category 'BACKUP' -Message 'Required pre-cleanup evidence was exported.'

    if (-not $KeepIntuneManagementExtension.IsPresent) {
        Write-OperatorMessage -Category 'REMOVE' -Message 'Uninstalling Intune Management Extension.'
        Uninstall-IntuneManagementExtension -BackupDirectory $backupDirectory
    }
    else {
        $imeService = Get-Service `
            -Name 'IntuneManagementExtension' `
            -ErrorAction SilentlyContinue
        if ($null -ne $imeService -and $imeService.Status -ne 'Stopped') {
            Stop-Service -Name 'IntuneManagementExtension' -Force -ErrorAction Stop
            $imeService.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
        }
        Write-OperatorMessage -Category 'PRESERVE' -Message (
            'IME was preserved by parameter; its old identity may delay clean recovery.'
        )
    }

    $taskService = New-Object -ComObject 'Schedule.Service'
    $taskService.Connect()
    foreach ($taskFolderPath in $taskFoldersBefore) {
        Write-OperatorMessage -Category 'REMOVE' -Message (
            "Removing EnterpriseMgmt task folder: $taskFolderPath"
        )
        Remove-TaskFolderRecursive `
            -TaskService $taskService `
            -TaskFolderPath $taskFolderPath
    }

    Write-OperatorMessage -Category 'REMOVE' -Message (
        "Deleting exact crypto key container: $normalizedKeyContainer"
    )
    $keyDeleteAttempt1 = Invoke-NativeCommand `
        -FilePath $script:CertUtilExe `
        -ArgumentList @(
            '-csp',
            $normalizedCryptoProvider,
            '-delkey',
            $normalizedKeyContainer
        ) `
        -OutputPath (Join-Path -Path $backupDirectory -ChildPath 'Key-Delete-Attempt1.txt')

    if ($keyDeleteAttempt1.ExitCode -ne 0 -and
        (Test-Path -LiteralPath $certificatePath)) {
        Write-OperatorMessage -Category 'REMOVE' -Message (
            'First key deletion failed. Removing the exact MDM certificate and retrying once.'
        )
        Remove-Item -LiteralPath $certificatePath -Force -ErrorAction Stop
        $keyDeleteAttempt2 = Invoke-NativeCommand `
            -FilePath $script:CertUtilExe `
            -ArgumentList @(
                '-csp',
                $normalizedCryptoProvider,
                '-delkey',
                $normalizedKeyContainer
            ) `
            -OutputPath (Join-Path -Path $backupDirectory -ChildPath 'Key-Delete-Attempt2.txt')
        if ($keyDeleteAttempt2.ExitCode -ne 0) {
            throw (
                "The exact TPM key container could not be deleted. certutil exit code: " +
                "$($keyDeleteAttempt2.ExitCode). Stop and reimage; do not clear the TPM " +
                'or delete raw crypto-provider files.'
            )
        }
    }
    elseif ($keyDeleteAttempt1.ExitCode -ne 0) {
        throw (
            "The exact TPM key container could not be deleted. certutil exit code: " +
            "$($keyDeleteAttempt1.ExitCode). Stop and reimage; do not clear the TPM " +
            'or delete raw crypto-provider files.'
        )
    }

    if (Test-Path -LiteralPath $certificatePath) {
        Write-OperatorMessage -Category 'REMOVE' -Message (
            "Removing exact MDM certificate: $normalizedThumbprint"
        )
        Remove-Item -LiteralPath $certificatePath -Force -ErrorAction Stop
    }

    Write-OperatorMessage -Category 'REMOVE' -Message (
        "Removing exact enrollment registry state: $normalizedEnrollmentId"
    )
    Remove-ExactEnrollmentRegistryState `
        -NormalizedEnrollmentId $normalizedEnrollmentId `
        -RemoveCurrentPolicyState (-not $KeepPolicyManagerCurrent.IsPresent)

    $dsregAfter = Invoke-NativeCommand `
        -FilePath $script:DsRegCmdExe `
        -ArgumentList @('/status') `
        -OutputPath (Join-Path -Path $backupDirectory -ChildPath 'DsRegCmd-After.txt')
    if ($dsregAfter.ExitCode -ne 0) {
        throw "Post-cleanup dsregcmd /status failed with exit code $($dsregAfter.ExitCode)."
    }

    $domainJoinedAfter = Get-DsRegValue `
        -DsRegOutput $dsregAfter.Output `
        -Name 'DomainJoined'
    if ([string]$domainJoinedAfter -ine 'YES') {
        throw 'Post-cleanup verification found that the AD domain join is not intact.'
    }

    $verificationFailures = @(Test-CleanupState `
        -NormalizedEnrollmentId $normalizedEnrollmentId `
        -NormalizedThumbprint $normalizedThumbprint `
        -NormalizedKeyContainer $normalizedKeyContainer `
        -NormalizedCryptoProvider $normalizedCryptoProvider `
        -ExpectImeRemoved (-not $KeepIntuneManagementExtension.IsPresent) `
        -VerificationDirectory $backupDirectory)

    $summaryLines = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $summaryLines.Add("ComputerName=$($env:COMPUTERNAME)")
    $summaryLines.Add("EnrollmentIdRemoved=$normalizedEnrollmentId")
    $summaryLines.Add("CertificateRemoved=$normalizedThumbprint")
    $summaryLines.Add("KeyContainerRemoved=$normalizedKeyContainer")
    $summaryLines.Add("DomainJoinedAfter=$domainJoinedAfter")
    $summaryLines.Add("IMEExpectedRemoved=$(-not $KeepIntuneManagementExtension.IsPresent)")
    $summaryLines.Add("VerificationFailureCount=$($verificationFailures.Count)")
    foreach ($failure in $verificationFailures) {
        $summaryLines.Add("FAILURE=$failure")
    }
    [System.IO.File]::WriteAllText(
        (Join-Path -Path $backupDirectory -ChildPath 'Cleanup-Summary.txt'),
        (($summaryLines.ToArray() -join [Environment]::NewLine) + [Environment]::NewLine),
        $script:Utf8BomEncoding
    )

    if ($verificationFailures.Count -gt 0) {
        foreach ($failure in $verificationFailures) {
            Write-OperatorMessage -Category 'FAILED' -Message $failure
        }
        throw 'Cleanup verification failed. Do not attempt reenrollment.'
    }

    Write-OperatorMessage -Category 'SUCCESS' -Message (
        'The targeted machine-level Intune enrollment was removed and the AD domain join remains intact.'
    )
    Write-OperatorMessage -Category 'REBOOT' -Message (
        'Restart the computer before reconnecting the user work/school account.'
    )
    Write-OperatorMessage -Category 'REENROLL' -Message (
        'After reboot, sign in as the intended user and connect Access work or school once. ' +
        'Then verify that Windows created a new enrollment GUID, certificate, key container, ' +
        'Intune device ID, and EnterpriseMgmt task folder.'
    )
    exit 3010
}
catch {
    $exceptionMessage = $_.Exception.Message
    $lineNumber = $_.InvocationInfo.ScriptLineNumber
    Write-ErrorLog -Category 'System' -Message (
        "Cleanup failed at line $lineNumber. $exceptionMessage"
    )
    [Console]::Error.WriteLine(
        "FAILED at line ${lineNumber}: $exceptionMessage"
    )
    exit 1
}
