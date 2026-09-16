#Requires -Version 5.1
param(
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ silent EXE installer for the RingCentral desktop application.

.DESCRIPTION
    Designed for a PDQ package that runs under the administrative deploy account
    pdqdeploy while RingCentral must install into the logged-on user's profile.

    The RingCentral EXE is a per-user NSIS installer. Running it directly as
    pdqdeploy installs RingCentral into the pdqdeploy profile. This wrapper uses
    the pdqdeploy/admin context only to:
      - validate the installer on the Hall County file share
      - stage the installer locally under ProgramData
      - create a one-shot scheduled task in the active user's interactive logon
        session

    The one-shot task then runs the RingCentral installer as the logged-on user
    with /S and verifies RingCentral.exe under that user's LocalAppData paths.

    This script does not store or embed credentials. If RingCentral ever changes
    this EXE so it truly requires elevation inside the user profile install,
    the correct deployment path is the RingCentral MSI/machine-wide deployment,
    not forcing pdqdeploy credentials into another user's HKCU/profile context.

.NOTES
    Version:        1.0.6
    Script Type:    PDQ PowerShell
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  29/06/2026
    Purpose:        Silent active-user install of RingCentral from PDQ

    CHANGE LOG
    Change: 07/07/2026 - Codex audit remediation: require expected installed version before
                         user-runner success -- ver. 1.0.6
    Change: 07/07/2026 - Codex audit remediation: generated user runner now performs post-install
                         RingCentral.exe detection before reporting success for reboot-required
                         installer codes 3010 or 1641 -- ver. 1.0.5
    Change: 29/06/2026 - Claude audit: removed dead wrapper-level Join-InstallerArguments function -- ver. 1.0.4
    Change: 29/06/2026 - Codex audit: harden staging ACLs and reuse one captured active user value -- ver. 1.0.3
    Change: 29/06/2026 - Claude audit: InvocationInfo null guard in Get-ExceptionSummary -- ver. 1.0.2
    Change: 29/06/2026 - Claude audit: Console.Error -> Write-Warning; Stage-Installer -> Copy-InstallerToStage; removed MSI exit code descriptions -- ver. 1.0.1
    Change: 29/06/2026 - Initial PDQ EXE installer using active-user scheduled task handoff -- ver. 1.0.0
#>

#region ========================= CONFIGURATION =========================

$script:AppName    = 'RingCentral'
$script:AppVersion = '1.0.6'

$script:InstallerPath = '\\hallcounty\filestore\MIS\CDS\Ring Central\RingCentral_V=10141857422126900.exe'

# RingCentral_V=10141857422126900.exe is an NSIS installer. NSIS silent mode is
# case-sensitive: use /S, not /s.
$script:InstallArguments = @('/S')

# Installer integrity guardrails. Update both values when replacing the EXE.
$script:ValidateInstallerSignature = $true
$script:ExpectedSignerText         = 'RingCentral, Inc.'
$script:ValidateInstallerHash      = $true
$script:ExpectedInstallerSha256    = 'B6F22FAC8FE4A3597E9A305CE43E7F752525DD13A5E470377DF06853794F6BAC'

# Local staging. The active user runs the staged local EXE, not the UNC path.
$script:StageRoot             = 'C:\ProgramData\HallCountyMIS\RingCentralPDQ'
$script:ResultRootName        = 'Results'
$script:StagedInstallerName   = 'RingCentral_V=10141857422126900.exe'
$script:UserRunnerScriptName  = 'Run-RingCentralInstallAsUser.ps1'
$script:ResultFileName        = 'RingCentralPDQ-InstallResult.txt'
$script:TaskNamePrefix        = 'Hall County MIS - RingCentral PDQ User Install'

# Current-user install evidence. These are relative to the user's LocalAppData.
$script:DetectionSubPaths = @(
    'Programs\RingCentral\RingCentral.exe',
    'RingCentral\DesktopApp\current\RingCentral.exe'
)

$script:ExpectedInstalledProductVersion      = '26.1.3015'
$script:SkipInstallIfInstalledVersionAtLeast = $true
$script:RequirePostInstallVersionAtLeast     = $true
$script:PostInstallDetectionTimeoutSeconds   = 90
$script:PostInstallDetectionPollSeconds      = 3

$script:TimeoutSeconds = 900
$script:TaskLaunchTimeoutSeconds = 60
$script:SuccessExitCodes = @(0, 3010, 1641)

# PDQ captures STDOUT/STDERR centrally; this local log is a backup for endpoint
# side troubleshooting if PDQ output is unavailable.
$script:LogRoot     = 'C:\ProgramData\HallCountyMIS\Logs'
$script:LogFileName = 'APP_RingCentral_PDQ_Install.txt'

#endregion ==============================================================


function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$Category = 'App'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)

        $logPath = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try {
            Write-Warning ('{0} - logging failed: {1}' -f $script:AppName, $Message)
        }
        catch {
            # Logging failure must never replace the real deployment failure.
        }
    }
}


function Exit-Failure {
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

    Write-ErrorLog -Message $Message -Category $Category
    Write-Warning $Message
    exit $Code
}


function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $currentException = $ErrorRecord.Exception

    while ($null -ne $currentException) {
        $typeName = $currentException.GetType().FullName
        $message = $currentException.Message

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = '(no message provided)'
        }
        else {
            $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }

        [void]$parts.Add(('{0}: {1}' -f $typeName, $message))
        $currentException = $currentException.InnerException
    }

    if ($null -ne $ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
    }

    if ($null -ne $ErrorRecord.InvocationInfo -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.Line)) {
        $failingCommand = ($ErrorRecord.InvocationInfo.Line -replace '(\r\n|\n|\r)+', ' ').Trim()
        [void]$parts.Add(('Command: {0}' -f $failingCommand))
    }

    if (
        ($ErrorRecord.Exception -is [System.ComponentModel.Win32Exception]) -or
        ($ErrorRecord.Exception -is [System.Runtime.InteropServices.COMException])
    ) {
        $hResult = '0x{0:X8}' -f ($ErrorRecord.Exception.HResult -band 0xffffffff)
        [void]$parts.Add(('HResult: {0}' -f $hResult))
    }

    return ($parts -join ' | ')
}


function Get-ExceptionCategory {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $currentException = $ErrorRecord.Exception

    while ($null -ne $currentException) {
        $typeName = $currentException.GetType().FullName
        $message = $currentException.Message

        if (
            ($currentException -is [System.UnauthorizedAccessException]) -or
            ($typeName -match 'Security') -or
            ($message -match 'access is denied|access denied|access to the path .* is denied|cannot access the file|permission')
        ) {
            return 'Permissions'
        }

        if (
            ($currentException -is [System.Net.WebException]) -or
            ($currentException -is [System.Net.Sockets.SocketException]) -or
            ($typeName -match 'WebException|SocketException') -or
            ($message -match 'network path was not found|network name cannot be found|remote name could not be resolved|name resolution|semaphore timeout period has expired|rpc server is unavailable')
        ) {
            return 'Network'
        }

        $currentException = $currentException.InnerException
    }

    return 'System'
}


function Get-ExitCodeDescription {
    param(
        [int]$ExitCode
    )

    switch ($ExitCode) {
        0    { return 'Success.' }
        2    { return 'Installer aborted or user cancelled.' }
        3010 { return 'Success. Reboot required.' }
        1641 { return 'Success. Installer initiated reboot.' }
        default { return '' }
    }
}


function Test-IsAbsoluteFilePath {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $trimmedPath = $Path.Trim()

    if (-not [System.IO.Path]::IsPathRooted($trimmedPath)) {
        return $false
    }

    if ($trimmedPath.EndsWith('\') -or $trimmedPath.EndsWith('/')) {
        return $false
    }

    if (-not [System.IO.Path]::HasExtension($trimmedPath)) {
        return $false
    }

    return $true
}


function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -ne $identity.User -and [string]$identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}


function Test-Configuration {
    if ([string]::IsNullOrWhiteSpace($script:AppName)) {
        Exit-Failure -Code 1 -Message 'Configuration error: AppName is blank.' -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:AppVersion)) {
        Exit-Failure -Code 1 -Message 'Configuration error: AppVersion is blank.' -Category 'PDQ'
    }

    if (-not (Test-IsAbsoluteFilePath -Path $script:InstallerPath)) {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerPath must be a full file path. Value: ''{0}''.' -f $script:InstallerPath) -Category 'PDQ'
    }

    if ([System.IO.Path]::GetExtension($script:InstallerPath) -ine '.exe') {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerPath must point to an .exe file. Value: ''{0}''.' -f $script:InstallerPath) -Category 'PDQ'
    }

    if ($null -eq $script:InstallArguments) {
        $script:InstallArguments = @()
    }
    else {
        $normalizedArguments = New-Object 'System.Collections.Generic.List[string]'

        foreach ($argument in $script:InstallArguments) {
            if ($null -eq $argument) {
                Exit-Failure -Code 1 -Message 'Configuration error: InstallArguments contains a null element.' -Category 'PDQ'
            }

            [void]$normalizedArguments.Add([string]$argument)
        }

        $script:InstallArguments = $normalizedArguments.ToArray()
    }

    if ([string]::IsNullOrWhiteSpace($script:StageRoot)) {
        Exit-Failure -Code 1 -Message 'Configuration error: StageRoot is blank.' -Category 'PDQ'
    }

    if (-not [System.IO.Path]::IsPathRooted($script:StageRoot)) {
        Exit-Failure -Code 1 -Message ('Configuration error: StageRoot must be an absolute path. Value: ''{0}''.' -f $script:StageRoot) -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:LogRoot)) {
        Exit-Failure -Code 1 -Message 'Configuration error: LogRoot is blank.' -Category 'PDQ'
    }

    if (-not [System.IO.Path]::IsPathRooted($script:LogRoot)) {
        Exit-Failure -Code 1 -Message ('Configuration error: LogRoot must be an absolute path. Value: ''{0}''.' -f $script:LogRoot) -Category 'PDQ'
    }

    if (($script:TimeoutSeconds -lt 1) -or ($script:TimeoutSeconds -gt 7200)) {
        Exit-Failure -Code 1 -Message ('Configuration error: TimeoutSeconds must be between 1 and 7200. Value: ''{0}''.' -f $script:TimeoutSeconds) -Category 'PDQ'
    }

    if (($script:TaskLaunchTimeoutSeconds -lt 1) -or ($script:TaskLaunchTimeoutSeconds -gt 600)) {
        Exit-Failure -Code 1 -Message ('Configuration error: TaskLaunchTimeoutSeconds must be between 1 and 600. Value: ''{0}''.' -f $script:TaskLaunchTimeoutSeconds) -Category 'PDQ'
    }

    if (($script:PostInstallDetectionTimeoutSeconds -lt 0) -or ($script:PostInstallDetectionTimeoutSeconds -gt 600)) {
        Exit-Failure -Code 1 -Message ('Configuration error: PostInstallDetectionTimeoutSeconds must be between 0 and 600. Value: ''{0}''.' -f $script:PostInstallDetectionTimeoutSeconds) -Category 'PDQ'
    }

    if (($script:PostInstallDetectionPollSeconds -lt 1) -or ($script:PostInstallDetectionPollSeconds -gt 60)) {
        Exit-Failure -Code 1 -Message ('Configuration error: PostInstallDetectionPollSeconds must be between 1 and 60. Value: ''{0}''.' -f $script:PostInstallDetectionPollSeconds) -Category 'PDQ'
    }

    if ($null -eq $script:DetectionSubPaths -or $script:DetectionSubPaths.Count -eq 0) {
        Exit-Failure -Code 1 -Message 'Configuration error: DetectionSubPaths is empty.' -Category 'PDQ'
    }

    foreach ($subPath in $script:DetectionSubPaths) {
        if ([string]::IsNullOrWhiteSpace($subPath)) {
            Exit-Failure -Code 1 -Message 'Configuration error: DetectionSubPaths contains a blank value.' -Category 'PDQ'
        }

        if ([System.IO.Path]::IsPathRooted($subPath)) {
            Exit-Failure -Code 1 -Message ('Configuration error: DetectionSubPaths must be relative to LocalAppData. Value: ''{0}''.' -f $subPath) -Category 'PDQ'
        }
    }

    if ($null -eq $script:SuccessExitCodes -or $script:SuccessExitCodes.Count -eq 0) {
        Exit-Failure -Code 1 -Message 'Configuration error: SuccessExitCodes is empty.' -Category 'PDQ'
    }

    $normalizedExitCodes = New-Object 'System.Collections.Generic.List[int]'

    foreach ($exitCode in $script:SuccessExitCodes) {
        try {
            $convertedExitCode = [int]$exitCode
        }
        catch {
            Exit-Failure -Code 1 -Message ('Configuration error: SuccessExitCodes contains a non-integer value: ''{0}''.' -f $exitCode) -Category 'PDQ'
        }

        if (-not $normalizedExitCodes.Contains($convertedExitCode)) {
            [void]$normalizedExitCodes.Add($convertedExitCode)
        }
    }

    $script:SuccessExitCodes = $normalizedExitCodes.ToArray()
}


function Get-CurrentIdentityName {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    if ($null -eq $identity) {
        return ''
    }

    return [string]$identity.Name
}


function Get-ActiveConsoleUserName {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    return [string]$computerSystem.UserName
}


function Assert-DeploymentContext {
    param(
        [string]$ActiveUser
    )

    if (-not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This PDQ wrapper must run with an elevated administrative token so it can stage the installer and register the active-user scheduled task. Use the PDQ deploy user account.' -Category 'Permissions'
    }

    if ([string]::IsNullOrWhiteSpace($ActiveUser)) {
        Exit-Failure -Code 1 -Message 'No active console user was detected. RingCentral EXE deployment must run while the target user is logged on.' -Category 'PDQ'
    }
}


function Test-InstallerFile {
    if (-not (Test-Path -LiteralPath $script:InstallerPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Installer not found at ''{0}''. Verify the PDQ deploy account can read the Hall County file share path.' -f $script:InstallerPath) -Category 'Network'
    }

    if ($script:ValidateInstallerSignature) {
        $signature = Get-AuthenticodeSignature -LiteralPath $script:InstallerPath -ErrorAction Stop

        if ([string]$signature.Status -ne 'Valid') {
            Exit-Failure -Code 1 -Message ('Installer signature is not valid. Status: {0}. Message: {1}. Path: ''{2}''.' -f $signature.Status, $signature.StatusMessage, $script:InstallerPath) -Category 'Permissions'
        }

        if ($null -eq $signature.SignerCertificate) {
            Exit-Failure -Code 1 -Message ('Installer signature did not include a signer certificate. Path: ''{0}''.' -f $script:InstallerPath) -Category 'Permissions'
        }

        $signerSubject = [string]$signature.SignerCertificate.Subject
        if ($signerSubject -notlike ('*' + $script:ExpectedSignerText + '*')) {
            Exit-Failure -Code 1 -Message ('Installer signer mismatch. Expected signer text ''{0}'', actual signer ''{1}''.' -f $script:ExpectedSignerText, $signerSubject) -Category 'Permissions'
        }
    }

    if ($script:ValidateInstallerHash) {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $script:InstallerPath -ErrorAction Stop
        $actualHash = ([string]$hash.Hash).ToUpperInvariant()
        $expectedHash = ([string]$script:ExpectedInstallerSha256).ToUpperInvariant()

        if ($actualHash -ne $expectedHash) {
            Exit-Failure -Code 1 -Message ('Installer SHA256 mismatch. Expected {0}; actual {1}. Path: ''{2}''.' -f $expectedHash, $actualHash, $script:InstallerPath) -Category 'Permissions'
        }
    }
}


function New-StageAccessRule {
    param(
        [string]$Sid,
        [System.Security.AccessControl.FileSystemRights]$Rights,
        [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags
    )

    $identity = New-Object Security.Principal.SecurityIdentifier($Sid)
    $account = $identity.Translate([Security.Principal.NTAccount])
    $propagation = [System.Security.AccessControl.PropagationFlags]::None
    $accessType = [System.Security.AccessControl.AccessControlType]::Allow

    return (New-Object System.Security.AccessControl.FileSystemAccessRule($account, $Rights, $InheritanceFlags, $propagation, $accessType))
}


function Reset-StageAcl {
    param(
        $Acl
    )

    $Acl.SetAccessRuleProtection($true, $false)

    foreach ($rule in @($Acl.Access)) {
        [void]$Acl.RemoveAccessRuleSpecific($rule)
    }
}


function Set-StageDirectoryAcl {
    param(
        [string]$Path,
        [System.Security.AccessControl.FileSystemRights]$UsersRights
    )

    $acl = Get-Acl -LiteralPath $Path
    Reset-StageAcl -Acl $acl

    $fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
    $inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'

    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-18' -Rights $fullControl -InheritanceFlags $inheritance))
    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-32-544' -Rights $fullControl -InheritanceFlags $inheritance))
    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-32-545' -Rights $UsersRights -InheritanceFlags $inheritance))

    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}


function Set-StageFileAcl {
    param(
        [string]$Path,
        [System.Security.AccessControl.FileSystemRights]$UsersRights
    )

    $acl = Get-Acl -LiteralPath $Path
    Reset-StageAcl -Acl $acl

    $fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
    $inheritance = [System.Security.AccessControl.InheritanceFlags]::None

    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-18' -Rights $fullControl -InheritanceFlags $inheritance))
    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-32-544' -Rights $fullControl -InheritanceFlags $inheritance))
    $acl.AddAccessRule((New-StageAccessRule -Sid 'S-1-5-32-545' -Rights $UsersRights -InheritanceFlags $inheritance))

    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}


function Get-StagedInstallerPath {
    return (Join-Path -Path $script:StageRoot -ChildPath $script:StagedInstallerName)
}


function Get-UserRunnerScriptPath {
    return (Join-Path -Path $script:StageRoot -ChildPath $script:UserRunnerScriptName)
}


function Get-ResultPath {
    $resultRoot = Get-ResultRoot
    return (Join-Path -Path $resultRoot -ChildPath $script:ResultFileName)
}


function Get-ResultRoot {
    return (Join-Path -Path $script:StageRoot -ChildPath $script:ResultRootName)
}


function Test-FileHashMatchesExpected {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop
    return (([string]$hash.Hash).ToUpperInvariant() -eq ([string]$script:ExpectedInstallerSha256).ToUpperInvariant())
}


function Copy-InstallerToStage {
    $usersReadAndExecute = [System.Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize'
    $usersModify = [System.Security.AccessControl.FileSystemRights]'Modify, Synchronize'

    [void][System.IO.Directory]::CreateDirectory($script:StageRoot)

    $resultRoot = Get-ResultRoot
    [void][System.IO.Directory]::CreateDirectory($resultRoot)

    Set-StageDirectoryAcl -Path $script:StageRoot -UsersRights $usersReadAndExecute
    Set-StageDirectoryAcl -Path $resultRoot -UsersRights $usersModify

    $stagedInstallerPath = Get-StagedInstallerPath

    if (-not (Test-FileHashMatchesExpected -Path $stagedInstallerPath)) {
        Copy-Item -LiteralPath $script:InstallerPath -Destination $stagedInstallerPath -Force -ErrorAction Stop
    }

    if (-not (Test-FileHashMatchesExpected -Path $stagedInstallerPath)) {
        Exit-Failure -Code 1 -Message ('Staged installer hash validation failed after copy. Path: ''{0}''.' -f $stagedInstallerPath) -Category 'Permissions'
    }

    Set-StageFileAcl -Path $stagedInstallerPath -UsersRights $usersReadAndExecute

    return $stagedInstallerPath
}


function ConvertTo-SingleQuotedLiteral {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return "''"
    }

    return ("'{0}'" -f $Value.Replace("'", "''"))
}


function ConvertTo-SingleQuotedArrayLiteral {
    param(
        [string[]]$Values
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'

    foreach ($value in $Values) {
        [void]$parts.Add((ConvertTo-SingleQuotedLiteral -Value $value))
    }

    return ('@({0})' -f ($parts.ToArray() -join ', '))
}


function Write-UserRunnerScript {
    param(
        [string]$StagedInstallerPath,
        [string]$ResultPath
    )

    $runnerPath = Get-UserRunnerScriptPath
    $installArgumentsLiteral = ConvertTo-SingleQuotedArrayLiteral -Values $script:InstallArguments
    $detectionSubPathsLiteral = ConvertTo-SingleQuotedArrayLiteral -Values $script:DetectionSubPaths

    $lines = @(
        '#Requires -Version 5.1',
        'Set-StrictMode -Version Latest',
        '$ErrorActionPreference = ''Stop''',
        '',
        ('$script:AppName = {0}' -f (ConvertTo-SingleQuotedLiteral -Value $script:AppName)),
        ('$script:InstallerPath = {0}' -f (ConvertTo-SingleQuotedLiteral -Value $StagedInstallerPath)),
        ('$script:ResultPath = {0}' -f (ConvertTo-SingleQuotedLiteral -Value $ResultPath)),
        ('$script:InstallArguments = {0}' -f $installArgumentsLiteral),
        ('$script:DetectionSubPaths = {0}' -f $detectionSubPathsLiteral),
        ('$script:ExpectedInstalledProductVersion = {0}' -f (ConvertTo-SingleQuotedLiteral -Value $script:ExpectedInstalledProductVersion)),
        ('$script:SkipInstallIfInstalledVersionAtLeast = ${0}' -f $script:SkipInstallIfInstalledVersionAtLeast.ToString().ToLowerInvariant()),
        ('$script:RequirePostInstallVersionAtLeast = ${0}' -f $script:RequirePostInstallVersionAtLeast.ToString().ToLowerInvariant()),
        ('$script:TimeoutSeconds = {0}' -f $script:TimeoutSeconds),
        ('$script:PostInstallDetectionTimeoutSeconds = {0}' -f $script:PostInstallDetectionTimeoutSeconds),
        ('$script:PostInstallDetectionPollSeconds = {0}' -f $script:PostInstallDetectionPollSeconds),
        ('$script:SuccessExitCodes = @({0})' -f ([string]::Join(', ', $script:SuccessExitCodes))),
        '',
        'function Join-InstallerArguments {',
        '    param([string[]]$ArgumentList = @())',
        '    if ($null -eq $ArgumentList -or $ArgumentList.Count -eq 0) { return '''' }',
        '    $items = New-Object ''System.Collections.Generic.List[string]''',
        '    foreach ($argument in $ArgumentList) {',
        '        if ($null -eq $argument) { throw ''InstallArguments contains a null element.'' }',
        '        [void]$items.Add([string]$argument)',
        '    }',
        '    return ($items.ToArray() -join '' '')',
        '}',
        '',
        'function Write-ResultFile {',
        '    param([string]$Status, [int]$ExitCode, [string]$Message, [string]$DetectedPath = '''')',
        '    $lines = @(',
        '        (''Status={0}'' -f $Status),',
        '        (''ExitCode={0}'' -f $ExitCode),',
        '        (''Message={0}'' -f (($Message -replace ''(\r\n|\n|\r)+'', '' '').Trim())),',
        '        (''DetectedPath={0}'' -f $DetectedPath),',
        '        (''User={0}'' -f [Security.Principal.WindowsIdentity]::GetCurrent().Name),',
        '        (''Timestamp={0}'' -f (Get-Date -Format ''yyyy-MM-dd HH:mm:ss''))',
        '    )',
        '    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)',
        '    [System.IO.File]::WriteAllText($script:ResultPath, ($lines -join [System.Environment]::NewLine) + [System.Environment]::NewLine, $utf8NoBom)',
        '}',
        '',
        'function Get-LocalAppDataPath {',
        '    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)',
        '    if ([string]::IsNullOrWhiteSpace($localAppData)) { $localAppData = [string]$env:LOCALAPPDATA }',
        '    if ([string]::IsNullOrWhiteSpace($localAppData)) { throw ''Unable to resolve LocalAppData for current user.'' }',
        '    return $localAppData',
        '}',
        '',
        'function Get-RingCentralDetectionPaths {',
        '    $localAppData = Get-LocalAppDataPath',
        '    $paths = New-Object ''System.Collections.Generic.List[string]''',
        '    foreach ($subPath in $script:DetectionSubPaths) { [void]$paths.Add((Join-Path -Path $localAppData -ChildPath $subPath)) }',
        '    return $paths.ToArray()',
        '}',
        '',
        'function Get-InstalledRingCentralPath {',
        '    foreach ($path in (Get-RingCentralDetectionPaths)) {',
        '        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }',
        '    }',
        '    return ''''',
        '}',
        '',
        'function ConvertTo-VersionOrNull {',
        '    param([string]$Value)',
        '    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }',
        '    $match = [regex]::Match($Value, ''\d+(\.\d+){1,3}'')',
        '    if (-not $match.Success) { return $null }',
        '    try { return New-Object System.Version($match.Value) } catch { return $null }',
        '}',
        '',
        'function Test-InstalledVersionAtLeast {',
        '    param([string]$InstalledPath, [string]$MinimumVersion)',
        '    if ([string]::IsNullOrWhiteSpace($InstalledPath)) { return $false }',
        '    if ([string]::IsNullOrWhiteSpace($MinimumVersion)) { return $true }',
        '    $item = Get-Item -LiteralPath $InstalledPath -ErrorAction Stop',
        '    $installedVersion = ConvertTo-VersionOrNull -Value ([string]$item.VersionInfo.ProductVersion)',
        '    $minimum = ConvertTo-VersionOrNull -Value $MinimumVersion',
        '    if ($null -eq $installedVersion -or $null -eq $minimum) { return $false }',
        '    return ($installedVersion -ge $minimum)',
        '}',
        '',
        'function Stop-ProcessTree {',
        '    param([int]$ProcessId)',
        '    $taskKillPath = Join-Path -Path $env:SystemRoot -ChildPath ''System32\taskkill.exe''',
        '    if (Test-Path -LiteralPath $taskKillPath -PathType Leaf) {',
        '        try {',
        '            $null = & $taskKillPath /PID $ProcessId /T /F 2>&1',
        '            if ($LASTEXITCODE -in @(0, 128)) { return }',
        '        }',
        '        catch { $null = $_ }',
        '    }',
        '    try {',
        '        $process = [System.Diagnostics.Process]::GetProcessById($ProcessId)',
        '        try { $process.Kill(); $null = $process.WaitForExit(5000) }',
        '        finally { $process.Dispose() }',
        '    }',
        '    catch { $null = $_ }',
        '}',
        '',
        'function Invoke-InstallerProcess {',
        '    param([string]$FilePath, [string[]]$ArgumentList = @(), [int]$TimeoutSeconds)',
        '    $startInfo = New-Object System.Diagnostics.ProcessStartInfo',
        '    $startInfo.FileName = $FilePath',
        '    $startInfo.Arguments = Join-InstallerArguments -ArgumentList $ArgumentList',
        '    $startInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($FilePath)',
        '    $startInfo.UseShellExecute = $false',
        '    $startInfo.CreateNoWindow = $true',
        '    $process = New-Object System.Diagnostics.Process',
        '    $process.StartInfo = $startInfo',
        '    try {',
        '        $started = $process.Start()',
        '        if (-not $started) { throw ''Process.Start() returned False without throwing.'' }',
        '        $hasExited = $process.WaitForExit($TimeoutSeconds * 1000)',
        '        if (-not $hasExited) {',
        '            Stop-ProcessTree -ProcessId $process.Id',
        '            try { $null = $process.WaitForExit(5000) } catch { $null = $_ }',
        '            throw (''Installer timed out after {0} seconds.'' -f $TimeoutSeconds)',
        '        }',
        '        return [int]$process.ExitCode',
        '    }',
        '    finally { $process.Dispose() }',
        '}',
        '',
        'function Wait-RingCentralDetected {',
        '    $deadline = (Get-Date).AddSeconds($script:PostInstallDetectionTimeoutSeconds)',
        '    do {',
        '        $installedPath = Get-InstalledRingCentralPath',
        '        if (-not [string]::IsNullOrWhiteSpace($installedPath)) {',
        '            if (-not $script:RequirePostInstallVersionAtLeast) { return $installedPath }',
        '            if (Test-InstalledVersionAtLeast -InstalledPath $installedPath -MinimumVersion $script:ExpectedInstalledProductVersion) { return $installedPath }',
        '        }',
        '        if ($script:PostInstallDetectionTimeoutSeconds -eq 0) { break }',
        '        Start-Sleep -Seconds $script:PostInstallDetectionPollSeconds',
        '    } while ((Get-Date) -lt $deadline)',
        '    return ''''',
        '}',
        '',
        'try {',
        '    if (-not (Test-Path -LiteralPath $script:InstallerPath -PathType Leaf)) { throw (''Staged installer not found: {0}'' -f $script:InstallerPath) }',
        '    $existingPath = Get-InstalledRingCentralPath',
        '    if (-not [string]::IsNullOrWhiteSpace($existingPath)) {',
        '        if ($script:SkipInstallIfInstalledVersionAtLeast -and (Test-InstalledVersionAtLeast -InstalledPath $existingPath -MinimumVersion $script:ExpectedInstalledProductVersion)) {',
        '            Write-ResultFile -Status ''Success'' -ExitCode 0 -Message ''RingCentral is already installed for this user.'' -DetectedPath $existingPath',
        '            exit 0',
        '        }',
        '    }',
        '    $exitCode = Invoke-InstallerProcess -FilePath $script:InstallerPath -ArgumentList $script:InstallArguments -TimeoutSeconds $script:TimeoutSeconds',
        '    if ($script:SuccessExitCodes -notcontains $exitCode) {',
        '        Write-ResultFile -Status ''Failure'' -ExitCode $exitCode -Message (''Installer returned exit code {0}.'' -f $exitCode)',
        '        exit $exitCode',
        '    }',
        '    $installedPath = Wait-RingCentralDetected',
        '    if ([string]::IsNullOrWhiteSpace($installedPath)) {',
        '        $detectedPath = Get-InstalledRingCentralPath',
        '        $message = (''Installer returned {0}, but RingCentral.exe was not detected for this user.'' -f $exitCode)',
        '        if ($script:RequirePostInstallVersionAtLeast) {',
        '            $message = (''Installer returned {0}, but RingCentral.exe version {1} or newer was not detected for this user.'' -f $exitCode, $script:ExpectedInstalledProductVersion)',
        '        }',
        '        Write-ResultFile -Status ''Failure'' -ExitCode 1 -Message $message -DetectedPath $detectedPath',
        '        exit 1',
        '    }',
        '    if ($exitCode -in @(3010, 1641)) {',
        '        Write-ResultFile -Status ''Success'' -ExitCode $exitCode -Message (''RingCentral installed for the active user; installer returned success code {0}; reboot may be required.'' -f $exitCode) -DetectedPath $installedPath',
        '        exit $exitCode',
        '    }',
        '    Write-ResultFile -Status ''Success'' -ExitCode $exitCode -Message ''RingCentral installed for the active user.'' -DetectedPath $installedPath',
        '    exit $exitCode',
        '}',
        'catch {',
        '    $message = $_.Exception.Message',
        '    if ([string]::IsNullOrWhiteSpace($message)) { $message = ''Unknown user-runner error.'' }',
        '    Write-ResultFile -Status ''Failure'' -ExitCode 1 -Message $message',
        '    exit 1',
        '}'
    )

    $content = ($lines -join [System.Environment]::NewLine) + [System.Environment]::NewLine
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($runnerPath, $content, $utf8Bom)
    Set-StageFileAcl -Path $runnerPath -UsersRights ([System.Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize')

    return $runnerPath
}


function Remove-StaleResult {
    $resultPath = Get-ResultPath

    if (Test-Path -LiteralPath $resultPath) {
        Remove-Item -LiteralPath $resultPath -Force -ErrorAction Stop
    }
}


function Read-ResultFile {
    param(
        [string]$Path
    )

    $result = @{}
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)

    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') {
            $result[$matches[1]] = $matches[2]
        }
    }

    return $result
}


function Get-TaskName {
    param(
        [string]$ActiveUser
    )

    $safeUser = $ActiveUser -replace '[\\/:*?"<>| ]', '_'
    if ([string]::IsNullOrWhiteSpace($safeUser)) {
        $safeUser = 'ActiveUser'
    }

    return ('{0} - {1}' -f $script:TaskNamePrefix, $safeUser)
}


function Register-ActiveUserInstallTask {
    param(
        [string]$TaskName,
        [string]$ActiveUser,
        [string]$RunnerPath
    )

    $powershellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $taskArgument = '-ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File "{0}"' -f $RunnerPath

    $action = New-ScheduledTaskAction -Execute $powershellPath -Argument $taskArgument
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(10)
    $principal = New-ScheduledTaskPrincipal -UserId $ActiveUser -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds ($script:TimeoutSeconds + $script:PostInstallDetectionTimeoutSeconds + 120)) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description 'Runs the RingCentral per-user installer in the active user session for PDQ deployment.' `
        -Force `
        -ErrorAction Stop | Out-Null
}


function Start-ActiveUserInstallTask {
    param(
        [string]$TaskName
    )

    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
}


function Wait-ForUserInstallResult {
    param(
        [string]$TaskName,
        [string]$ResultPath
    )

    $deadline = (Get-Date).AddSeconds($script:TimeoutSeconds + $script:PostInstallDetectionTimeoutSeconds + $script:TaskLaunchTimeoutSeconds + 120)
    $lastTaskResult = $null
    $lastTaskState = ''

    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
            return (Read-ResultFile -Path $ResultPath)
        }

        try {
            $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
            $lastTaskState = [string]$task.State
        }
        catch {
            $lastTaskState = 'Unavailable'
        }

        try {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
            $lastTaskResult = $taskInfo.LastTaskResult
        }
        catch {
            $lastTaskResult = $null
        }

        Start-Sleep -Seconds 3
    }

    $message = 'Timed out waiting for active-user RingCentral install result. TaskState={0}; LastTaskResult={1}; ResultPath=''{2}''.' -f $lastTaskState, $lastTaskResult, $ResultPath
    Exit-Failure -Code 1 -Message $message -Category 'PDQ'
}


function Remove-InstallTask {
    param(
        [string]$TaskName
    )

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        # Task cleanup failure should not override a completed install result.
    }
}


# =========================
# MAIN
# =========================
try {
    Test-Configuration
    $activeUser = Get-ActiveConsoleUserName
    Assert-DeploymentContext -ActiveUser $activeUser
    Test-InstallerFile

    $currentIdentity = Get-CurrentIdentityName
    $resultPath = Get-ResultPath
    $taskName = Get-TaskName -ActiveUser $activeUser

    $stagedInstallerPath = Copy-InstallerToStage
    $runnerPath = Write-UserRunnerScript -StagedInstallerPath $stagedInstallerPath -ResultPath $resultPath

    Write-Output ('PDQ context: {0}' -f $currentIdentity)
    Write-Output ('Active user: {0}' -f $activeUser)
    Write-Output ('Staged installer: {0}' -f $stagedInstallerPath)
    Write-Output ('User runner: {0}' -f $runnerPath)

    if ($ValidateOnly) {
        Write-Output 'ValidateOnly: configuration, installer integrity, staging, ACL, and runner generation succeeded. Install task was not started.'
        exit 0
    }

    Remove-StaleResult
    Register-ActiveUserInstallTask -TaskName $taskName -ActiveUser $activeUser -RunnerPath $runnerPath

    try {
        Start-ActiveUserInstallTask -TaskName $taskName
        $result = Wait-ForUserInstallResult -TaskName $taskName -ResultPath $resultPath
    }
    finally {
        Remove-InstallTask -TaskName $taskName
    }

    $status = [string]$result['Status']
    $exitCodeText = [string]$result['ExitCode']
    $message = [string]$result['Message']
    $detectedPath = [string]$result['DetectedPath']

    $exitCode = 1
    if (-not [string]::IsNullOrWhiteSpace($exitCodeText)) {
        try { $exitCode = [int]$exitCodeText } catch { $exitCode = 1 }
    }

    if ($status -ne 'Success') {
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'RingCentral active-user install failed without a result message.'
        }

        $description = Get-ExitCodeDescription -ExitCode $exitCode
        if (-not [string]::IsNullOrWhiteSpace($description)) {
            $message = '{0} {1}' -f $message, $description
        }

        if ($exitCode -eq 0) {
            $exitCode = 1
        }

        Exit-Failure -Code $exitCode -Message $message -Category 'App'
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'RingCentral active-user install completed.'
    }

    Write-Output $message

    if (-not [string]::IsNullOrWhiteSpace($detectedPath)) {
        Write-Output ('Detected path: {0}' -f $detectedPath)
    }

    exit $exitCode
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
