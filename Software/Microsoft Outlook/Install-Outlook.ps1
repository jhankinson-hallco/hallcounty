#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Provisions new Outlook for Windows from the offline MSIX package.

.DESCRIPTION
    Installs Microsoft.OutlookForWindows at device scope using the offline MSIX
    package included in this Win32 app payload. This avoids the Microsoft Store
    path and avoids relying on the Outlook Setup.exe bootstrapper at install time.

    The script requires Windows 10 version 2004 / build 19041 or later and must
    run in 64-bit Windows PowerShell because AppX provisioning cmdlets are not
    safe in the Intune Management Extension 32-bit host.

.NOTES
    Version:        1.0.3
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  15/05/2026
    Purpose:        Provisions new Outlook for Windows from the offline MSIX package

    CHANGE LOG
    Change: 15/05/2026 - Synchronized companion script versions after uninstall
                         parameter correction -- ver. 1.0.3
    Change: 15/05/2026 - Use offline MSIX provisioning, add OS/build guard,
                         add 64-bit guard, and verify provisioned package
                         version -- ver. 1.0.1
    Change: 15/05/2026 - Initial release -- ver. 1.0.0

    INTUNE CONFIGURATION
    Install command:
    %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-Outlook.ps1

    Detection:
    Use companion Detect.ps1.
    Run script as 32-bit process on 64-bit clients: No
#>

#region CONFIGURATION

$script:AppName = 'Microsoft Outlook'
$script:AppVersion = '1.0.3'
$script:PackageIdentityName = 'Microsoft.OutlookForWindows'
$script:PackageFileName = 'Microsoft.OutlookForWindows_x64.msix'
$script:RequiredPackageVersion = '1.2026.504.100'
$script:RequiredProcessorArchitecture = 'AMD64'
$script:MinimumWindowsBuild = 19041
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
        $line = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
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

    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}


function Get-ScriptRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }

    return $null
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
            ($message -match 'network path was not found|remote name could not be resolved|rpc server is unavailable')
        ) {
            return 'Network'
        }

        $currentException = $currentException.InnerException
    }

    return 'System'
}


function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Invoke-64BitRelaunchIfNeeded {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        Stop-WithFailure -Code 1 -Message 'This package contains the x64 Outlook MSIX and requires a 64-bit operating system.' -Category 'Intune'
    }

    if ([System.Environment]::Is64BitProcess) {
        return
    }

    $sysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $sysNativePowerShell -PathType Leaf)) {
        Stop-WithFailure -Code 1 -Message ('64-bit Windows PowerShell was not found at ''{0}''.' -f $sysNativePowerShell) -Category 'Intune'
    }

    & $sysNativePowerShell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $PSCommandPath
    exit $LASTEXITCODE
}


function Test-ProcessorArchitectureSupported {
    if ($env:PROCESSOR_ARCHITECTURE -ne $script:RequiredProcessorArchitecture) {
        Stop-WithFailure -Code 1 -Message ('This package contains the x64 Outlook MSIX and requires processor architecture {0}. Current process architecture is {1}.' -f $script:RequiredProcessorArchitecture, $env:PROCESSOR_ARCHITECTURE) -Category 'Intune'
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
        Stop-WithFailure -Code 1 -Message 'Configuration error: PackageIdentityName is blank.' -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($script:PackageFileName)) {
        Stop-WithFailure -Code 1 -Message 'Configuration error: PackageFileName is blank.' -Category 'Intune'
    }

    if ([System.IO.Path]::GetFileName($script:PackageFileName) -ne $script:PackageFileName) {
        Stop-WithFailure -Code 1 -Message ('Configuration error: PackageFileName must be a file name only. Value: ''{0}''.' -f $script:PackageFileName) -Category 'Intune'
    }

    if ([System.IO.Path]::GetExtension($script:PackageFileName) -ine '.msix') {
        Stop-WithFailure -Code 1 -Message ('Configuration error: PackageFileName must point to an .msix file. Value: ''{0}''.' -f $script:PackageFileName) -Category 'Intune'
    }

    try {
        [version]$null = $script:RequiredPackageVersion
    }
    catch {
        Stop-WithFailure -Code 1 -Message ('Configuration error: RequiredPackageVersion is not a valid version. Value: ''{0}''.' -f $script:RequiredPackageVersion) -Category 'Intune'
    }

    if ($script:MinimumWindowsBuild -lt 19041) {
        Stop-WithFailure -Code 1 -Message ('Configuration error: MinimumWindowsBuild must be 19041 or higher. Value: ''{0}''.' -f $script:MinimumWindowsBuild) -Category 'Intune'
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
    Invoke-64BitRelaunchIfNeeded
    Test-Configuration
    Test-ProcessorArchitectureSupported

    if (-not (Test-IsAdministrator)) {
        Stop-WithFailure -Code 1 -Message 'This installer requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
    }

    $windowsBuild = Get-WindowsBuildNumber
    if ($windowsBuild -lt $script:MinimumWindowsBuild) {
        Stop-WithFailure -Code 1 -Message ('Unsupported Windows build {0}. New Outlook requires Windows build {1} or later.' -f $windowsBuild, $script:MinimumWindowsBuild) -Category 'Intune'
    }

    $scriptRoot = Get-ScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Stop-WithFailure -Code 1 -Message 'Unable to resolve script directory. Run this as a saved .ps1 file from disk.' -Category 'Intune'
    }

    $packagePath = Join-Path -Path $scriptRoot -ChildPath $script:PackageFileName
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        Stop-WithFailure -Code 1 -Message ('MSIX package not found at ''{0}''.' -f $packagePath) -Category 'Intune'
    }

    if (Test-RequiredPackageVersionPresent) {
        exit 0
    }

    Add-AppxProvisionedPackage -Online -PackagePath $packagePath -SkipLicense -ErrorAction Stop | Out-Null

    if (-not (Test-RequiredPackageVersionPresent)) {
        $installedVersion = Get-ProvisionedOutlookVersion
        $versionText = '(not provisioned)'

        if ($null -ne $installedVersion) {
            $versionText = $installedVersion.ToString()
        }

        Stop-WithFailure -Code 1 -Message ('Provisioning completed, but required package version was not detected. Required: {0}. Detected: {1}.' -f $script:RequiredPackageVersion, $versionText) -Category 'App'
    }

    exit 0
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Stop-WithFailure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
