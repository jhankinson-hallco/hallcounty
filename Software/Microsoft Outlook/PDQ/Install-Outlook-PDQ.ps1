#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: provisions new Outlook for Windows from the offline MSIX package.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-Outlook.ps1 (v1.0.3).

    Pulls only Microsoft.OutlookForWindows_x64.msix from the shared filestore
    repository, stages it locally, and provisions Microsoft.OutlookForWindows
    at device scope using Add-AppxProvisionedPackage. This keeps scripts and
    documentation in the PDQ folder while only deployment payload files live on
    the filestore.

    The script requires Windows 10 version 2004 / build 19041 or later and must
    run in 64-bit Windows PowerShell because AppX provisioning cmdlets are not
    safe in a 32-bit host.

    TANDEM PARITY: the provisioned package state is identical to the Intune
    install. The Intune Detect.ps1 custom detection script passes after either
    deployment channel provisions Microsoft.OutlookForWindows version
    1.2026.504.100 or newer.

    Logging is error-only to C:\IntuneAppLogs\NewOutlook_Install.txt
    (same file as the Intune install; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (required provisioned package version present)
        1 = Failure (preflight, repository access, provisioning, or verification failed)

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  16/07/2026
    Purpose:        Provision new Outlook for Windows from the shared offline MSIX repository via PDQ

    CHANGE LOG
    Change: 16/07/2026 - Initial PDQ release, tandem with Intune Install-Outlook.ps1 v1.0.3 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running Install-Outlook-PDQ.ps1
      Run As:        Deploy User with local administrator rights and READ access
                     to the filestore repository. Use Local System only if the
                     computer account can read the repository share.
      PowerShell:    64-bit host required
      Success codes: 0

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      Payload: \\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Outlook

    DETECTION
      Intune uses Detect.ps1. PDQ produces the same provisioned package state:
      Microsoft.OutlookForWindows version 1.2026.504.100 or newer.
#>

#region CONFIGURATION

$script:AppName = 'Microsoft Outlook'
$script:AppVersion = '1.0.3'
$script:PackageIdentityName = 'Microsoft.OutlookForWindows'
$script:PackageFileName = 'Microsoft.OutlookForWindows_x64.msix'
$script:RequiredPackageVersion = '1.2026.504.100'
$script:RequiredProcessorArchitecture = 'AMD64'
$script:MinimumWindowsBuild = 19041
$script:RepositoryRoot = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Outlook'
$script:StageRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\MicrosoftOutlookPDQ'
$script:PayloadStagePath = $null
$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFileName = 'NewOutlook_Install.txt'

#endregion CONFIGURATION


function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$Category = 'App'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)

        $logPath = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $encoding)
    }
    catch {
        try {
            [Console]::Error.WriteLine('{0} - logging failed: {1}' -f $script:AppName, $Message)
        }
        catch {
            # Logging failure must never override the real installer result.
        }
    }
}


function Stop-WithFailure {
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

    Remove-PDQPayloadStage
    Write-ErrorLog -Message $Message -Category $Category
    Write-Output $Message
    exit $Code
}


function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $currentException = $ErrorRecord.Exception

    while ($null -ne $currentException) {
        $message = $currentException.Message

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = '(no message provided)'
        }
        else {
            $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }

        [void]$parts.Add(('{0}: {1}' -f $currentException.GetType().FullName, $message))
        $currentException = $currentException.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
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
            ($message -match 'access is denied|access denied|permission')
        ) {
            return 'Permissions'
        }

        if (
            ($currentException -is [System.Net.WebException]) -or
            ($currentException -is [System.Net.Sockets.SocketException]) -or
            ($typeName -match 'WebException|SocketException') -or
            ($message -match 'network path was not found|remote name could not be resolved|rpc server is unavailable|network name cannot be found')
        ) {
            return 'Network'
        }

        $currentException = $currentException.InnerException
    }

    return 'System'
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


function Test-IsValidLeafFileName {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    if ([System.IO.Path]::GetFileName($Value) -ne $Value) {
        return $false
    }

    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        if ($Value.Contains([string]$invalidChar)) {
            return $false
        }
    }

    return $true
}


function Get-PDQPayloadFileNames {
    return @(
        $script:PackageFileName
    )
}


function Remove-PDQPayloadStage {
    # Removes only the exact files this PDQ package stages locally.
    try {
        if ([string]::IsNullOrWhiteSpace($script:PayloadStagePath)) {
            return
        }

        foreach ($fileName in (Get-PDQPayloadFileNames)) {
            $stagedFile = Join-Path -Path $script:PayloadStagePath -ChildPath $fileName
            if (Test-Path -LiteralPath $stagedFile -PathType Leaf) {
                Remove-Item -LiteralPath $stagedFile -Force -ErrorAction SilentlyContinue
            }
        }

        if (Test-Path -LiteralPath $script:PayloadStagePath -PathType Container) {
            $remainingItems = @(Get-ChildItem -LiteralPath $script:PayloadStagePath -Force -ErrorAction SilentlyContinue)
            if ($remainingItems.Count -eq 0) {
                Remove-Item -LiteralPath $script:PayloadStagePath -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-ErrorLog -Message ('Best-effort PDQ payload stage cleanup left {0} item(s) in ''{1}''.' -f $remainingItems.Count, $script:PayloadStagePath) -Category 'System'
            }
        }
    }
    catch {
        try {
            Write-ErrorLog -Message ('Best-effort PDQ payload stage cleanup failed for ''{0}'': {1}' -f $script:PayloadStagePath, $_.Exception.Message) -Category 'System'
        }
        catch {
            # Cleanup logging must never change the deployment result.
        }
    }
    finally {
        $script:PayloadStagePath = $null
    }
}


function Copy-PDQPayloadToLocalStage {
    if ([string]::IsNullOrWhiteSpace($script:RepositoryRoot)) {
        Stop-WithFailure -Code 1 -Message 'Configuration error: RepositoryRoot is blank.' -Category 'PDQ'
    }

    try {
        [void][System.IO.Directory]::CreateDirectory($script:StageRoot)
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Stop-WithFailure -Code 1 -Message ('Cannot create PDQ payload stage folder ''{0}'': {1}' -f $script:StageRoot, $summary) -Category 'Permissions'
    }

    $script:PayloadStagePath = $script:StageRoot

    foreach ($fileName in (Get-PDQPayloadFileNames)) {
        $sourcePath = Join-Path -Path $script:RepositoryRoot -ChildPath $fileName
        $destPath = Join-Path -Path $script:PayloadStagePath -ChildPath $fileName

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Stop-WithFailure -Code 1 -Message ('PDQ payload file not found or not reachable: ''{0}''. Verify repository contents and PDQ run-as account access.' -f $sourcePath) -Category 'Network'
        }

        try {
            Copy-Item -LiteralPath $sourcePath -Destination $destPath -Force -ErrorAction Stop
        }
        catch {
            $summary = Get-ExceptionSummary -ErrorRecord $_
            Stop-WithFailure -Code 1 -Message ('Failed to stage PDQ payload file ''{0}'' to ''{1}'': {2}' -f $sourcePath, $destPath, $summary) -Category 'Network'
        }

        if (-not (Test-Path -LiteralPath $destPath -PathType Leaf)) {
            Stop-WithFailure -Code 1 -Message ('PDQ payload staging verification failed. File missing after copy: ''{0}''.' -f $destPath) -Category 'System'
        }
    }

    return $script:PayloadStagePath
}


function Test-ProcessorArchitectureSupported {
    if ($env:PROCESSOR_ARCHITECTURE -ne $script:RequiredProcessorArchitecture) {
        Stop-WithFailure -Code 1 -Message ('This package contains the x64 Outlook MSIX and requires processor architecture {0}. Current process architecture is {1}.' -f $script:RequiredProcessorArchitecture, $env:PROCESSOR_ARCHITECTURE) -Category 'PDQ'
    }
}


function Get-WindowsBuildNumber {
    $currentVersionPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $currentVersion = Get-ItemProperty -LiteralPath $currentVersionPath -ErrorAction Stop
    $buildProperty = $currentVersion.PSObject.Properties['CurrentBuildNumber']

    if ($null -eq $buildProperty -or [string]::IsNullOrWhiteSpace([string]$buildProperty.Value)) {
        throw 'Unable to read CurrentBuildNumber from the Windows CurrentVersion registry key.'
    }

    return [int]$buildProperty.Value
}


function Test-Configuration {
    if ([string]::IsNullOrWhiteSpace($script:PackageIdentityName)) {
        Stop-WithFailure -Code 1 -Message 'Configuration error: PackageIdentityName is blank.' -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:PackageFileName)) {
        Stop-WithFailure -Code 1 -Message 'Configuration error: PackageFileName is blank.' -Category 'PDQ'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:PackageFileName)) {
        Stop-WithFailure -Code 1 -Message ('Configuration error: PackageFileName must be a file name only. Value: ''{0}''.' -f $script:PackageFileName) -Category 'PDQ'
    }

    if ([System.IO.Path]::GetExtension($script:PackageFileName) -ine '.msix') {
        Stop-WithFailure -Code 1 -Message ('Configuration error: PackageFileName must point to an .msix file. Value: ''{0}''.' -f $script:PackageFileName) -Category 'PDQ'
    }

    try {
        [version]$null = $script:RequiredPackageVersion
    }
    catch {
        Stop-WithFailure -Code 1 -Message ('Configuration error: RequiredPackageVersion is not a valid version. Value: ''{0}''.' -f $script:RequiredPackageVersion) -Category 'PDQ'
    }

    if ($script:MinimumWindowsBuild -lt 19041) {
        Stop-WithFailure -Code 1 -Message ('Configuration error: MinimumWindowsBuild must be 19041 or higher. Value: ''{0}''.' -f $script:MinimumWindowsBuild) -Category 'PDQ'
    }
}


function Get-ProvisionedOutlookPackages {
    $packages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -eq $script:PackageIdentityName }
    )

    foreach ($package in $packages) {
        $package
    }
}


function Get-ProvisionedOutlookVersion {
    $versions = New-Object 'System.Collections.Generic.List[version]'
    $packages = @(Get-ProvisionedOutlookPackages)

    foreach ($package in $packages) {
        $versionProperty = $package.PSObject.Properties['Version']

        if ($null -ne $versionProperty -and -not [string]::IsNullOrWhiteSpace([string]$versionProperty.Value)) {
            try {
                [void]$versions.Add([version]$versionProperty.Value)
            }
            catch {
                throw ('Provisioned package version is not parseable: ''{0}''.' -f $versionProperty.Value)
            }
        }
    }

    if ($versions.Count -eq 0) {
        return $null
    }

    return ($versions.ToArray() | Sort-Object -Descending | Select-Object -First 1)
}


function Test-RequiredPackageVersionPresent {
    $installedVersion = Get-ProvisionedOutlookVersion

    if ($null -eq $installedVersion) {
        return $false
    }

    $requiredVersion = [version]$script:RequiredPackageVersion
    return ($installedVersion -ge $requiredVersion)
}


try {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        Stop-WithFailure -Code 1 -Message 'This package contains the x64 Outlook MSIX and requires a 64-bit operating system.' -Category 'PDQ'
    }

    if (-not [System.Environment]::Is64BitProcess) {
        Stop-WithFailure -Code 1 -Message 'This script requires 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -Category 'PDQ'
    }

    Test-Configuration
    Test-ProcessorArchitectureSupported

    if (-not (Test-IsAdministrator)) {
        Stop-WithFailure -Code 1 -Message 'This installer requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -Category 'Permissions'
    }

    $windowsBuild = Get-WindowsBuildNumber
    if ($windowsBuild -lt $script:MinimumWindowsBuild) {
        Stop-WithFailure -Code 1 -Message ('Unsupported Windows build {0}. New Outlook requires Windows build {1} or later.' -f $windowsBuild, $script:MinimumWindowsBuild) -Category 'PDQ'
    }

    if (Test-RequiredPackageVersionPresent) {
        exit 0
    }

    $payloadRoot = Copy-PDQPayloadToLocalStage
    $packagePath = Join-Path -Path $payloadRoot -ChildPath $script:PackageFileName

    Add-AppxProvisionedPackage -Online -PackagePath $packagePath -SkipLicense -ErrorAction Stop | Out-Null

    if (-not (Test-RequiredPackageVersionPresent)) {
        $installedVersion = Get-ProvisionedOutlookVersion
        $versionText = '(not provisioned)'

        if ($null -ne $installedVersion) {
            $versionText = $installedVersion.ToString()
        }

        Stop-WithFailure -Code 1 -Message ('Provisioning completed, but required package version was not detected. Required: {0}. Detected: {1}.' -f $script:RequiredPackageVersion, $versionText) -Category 'App'
    }

    Remove-PDQPayloadStage
    exit 0
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Stop-WithFailure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
