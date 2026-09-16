#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes new Outlook for Windows from device scope and existing users.

.NOTES
    Version:        1.0.4
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  15/05/2026
    Purpose:        Removes the new Outlook provisioned package and per-user instances

    CHANGE LOG
    Change: 15/05/2026 - Deduplicate PackageFullName before per-user removal loop;
                         duplicate entries caused false exit 1 on multi-user machines -- ver. 1.0.4
    Change: 15/05/2026 - Restored documented -AllUsers flag for provisioned
                         package removal and resynchronized package script
                         versions -- ver. 1.0.3
    Change: 15/05/2026 - Superseded audit change that removed -AllUsers from
                         Remove-AppxProvisionedPackage -- ver. 1.0.2
    Change: 15/05/2026 - Add version sync, 64-bit guard, stricter AppX removal,
                         and post-uninstall verification -- ver. 1.0.1
    Change: 15/05/2026 - Initial release -- ver. 1.0.0

    INTUNE CONFIGURATION
    Uninstall command:
    %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-Outlook.ps1
#>

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
        $line = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
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


function Invoke-64BitRelaunchIfNeeded {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        exit 0
    }

    if ([System.Environment]::Is64BitProcess) {
        return
    }

    $sysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $sysNativePowerShell -PathType Leaf)) {
        Write-ErrorLog -Message ('64-bit Windows PowerShell was not found at ''{0}''.' -f $sysNativePowerShell) -Category 'Intune'
        exit 1
    }

    & $sysNativePowerShell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $PSCommandPath
    exit $LASTEXITCODE
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
    Invoke-64BitRelaunchIfNeeded

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
