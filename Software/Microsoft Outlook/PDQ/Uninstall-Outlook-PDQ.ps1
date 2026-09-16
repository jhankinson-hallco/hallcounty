#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: removes new Outlook for Windows from device scope and existing users.

.DESCRIPTION
    PDQ Deploy uninstall script. Tandem counterpart of the Intune Win32 app
    Uninstall-Outlook.ps1 (v1.0.4).

    Removes the Microsoft.OutlookForWindows provisioned package and removes
    existing per-user package instances. No filestore access is required for
    uninstall because all work is performed against local AppX package state.

    TANDEM PARITY: the removed Outlook footprint is intended to be
    indistinguishable from the Intune uninstall. Any uninstall-scope or
    detection-impacting change must be evaluated against BOTH deployment
    channels.

    Logging is error-only to C:\IntuneAppLogs\NewOutlook_Uninstall.txt
    (same file as the Intune uninstall; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (package removed or already absent)
        1 = Failure (removal or post-uninstall verification failed)

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  16/07/2026
    Purpose:        Remove new Outlook for Windows via PDQ

    CHANGE LOG
    Change: 16/07/2026 - Initial PDQ release, tandem with Intune Uninstall-Outlook.ps1 v1.0.4 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-Outlook-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      PowerShell:    64-bit host required
      Success codes: 0
#>

$script:AppName = 'Microsoft Outlook'
$script:AppVersion = '1.0.4'
$script:PackageIdentityName = 'Microsoft.OutlookForWindows'
$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFileName = 'NewOutlook_Uninstall.txt'


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
        # Logging failure must never override the real uninstaller result.
    }
}


function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $message = $ErrorRecord.Exception.Message

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = '(no message provided)'
    }
    else {
        $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        return '{0}: {1} | Line: {2}' -f $ErrorRecord.Exception.GetType().FullName, $message, $ErrorRecord.InvocationInfo.ScriptLineNumber
    }

    return '{0}: {1}' -f $ErrorRecord.Exception.GetType().FullName, $message
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


function Get-ProvisionedOutlookPackages {
    $packages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -eq $script:PackageIdentityName }
    )

    foreach ($package in $packages) {
        $package
    }
}


try {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        exit 0
    }

    if (-not [System.Environment]::Is64BitProcess) {
        Write-ErrorLog -Message 'This script requires 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -Category 'PDQ'
        exit 1
    }

    if (-not (Test-IsAdministrator)) {
        Write-ErrorLog -Message 'This uninstall script requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -Category 'Permissions'
        exit 1
    }

    $provisionedPackages = @(Get-ProvisionedOutlookPackages)
    foreach ($package in $provisionedPackages) {
        Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $package.PackageName -ErrorAction Stop | Out-Null
    }

    # Deduplicate by PackageFullName before removal. Get-AppxPackage -AllUsers returns one
    # entry per user profile; Remove-AppxPackage -AllUsers removes for all users at once on
    # the first call, so subsequent calls for the same full name would throw unnecessarily.
    $uniqueFullNames = @(
        Get-AppxPackage -AllUsers -Name $script:PackageIdentityName -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty PackageFullName -Unique
    )

    foreach ($fullName in $uniqueFullNames) {
        Remove-AppxPackage -AllUsers -Package $fullName -ErrorAction Stop
    }

    $remainingProvisionedPackages = @(Get-ProvisionedOutlookPackages)
    $remainingUserPackages = @(Get-AppxPackage -AllUsers -Name $script:PackageIdentityName -ErrorAction SilentlyContinue)

    if (($remainingProvisionedPackages.Count -gt 0) -or ($remainingUserPackages.Count -gt 0)) {
        Write-ErrorLog -Message ('Uninstall completed but Outlook package evidence remains. Provisioned={0}; UserPackages={1}.' -f $remainingProvisionedPackages.Count, $remainingUserPackages.Count) -Category 'App'
        exit 1
    }

    exit 0
}
catch {
    Write-ErrorLog -Message ('Uninstall failed: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
    exit 1
}
