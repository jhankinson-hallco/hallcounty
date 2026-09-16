#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detects whether new Outlook for Windows is provisioned at device scope.

.NOTES
    Version:        1.0.3
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  15/05/2026
    Purpose:        Intune custom detection script for new Outlook Win32 app

    CHANGE LOG
    Change: 15/05/2026 - Synchronized companion script versions after uninstall
                         parameter correction -- ver. 1.0.3
    Change: 15/05/2026 - Require the expected provisioned MSIX version and
                         enforce 64-bit PowerShell relaunch -- ver. 1.0.1
    Change: 15/05/2026 - Initial release -- ver. 1.0.0
#>

$script:PackageIdentityName = 'Microsoft.OutlookForWindows'
$script:RequiredPackageVersion = '1.2026.504.100'


function Invoke-64BitRelaunchIfNeeded {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        exit 1
    }

    if ([System.Environment]::Is64BitProcess) {
        return
    }

    $sysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $sysNativePowerShell -PathType Leaf)) {
        exit 1
    }

    & $sysNativePowerShell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $PSCommandPath
    exit $LASTEXITCODE
}


try {
    Invoke-64BitRelaunchIfNeeded

    $requiredVersion = [version]$script:RequiredPackageVersion
    $packages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -eq $script:PackageIdentityName }
    )

    foreach ($package in $packages) {
        $versionProperty = $package.PSObject.Properties['Version']

        if ($null -eq $versionProperty -or [string]::IsNullOrWhiteSpace([string]$versionProperty.Value)) {
            continue
        }

        $packageVersion = [version]$versionProperty.Value

        if ($packageVersion -ge $requiredVersion) {
            Write-Output ('Detected: {0} {1}' -f $script:PackageIdentityName, $packageVersion)
            exit 0
        }
    }

    exit 1
}
catch {
    exit 1
}
