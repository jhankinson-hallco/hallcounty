#requires -version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PIAInstallEntry {
    [CmdletBinding()]
    param()

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -and (
                    $_.DisplayName -like '*Primary Interop*2005*' -or
                    $_.DisplayName -like '*Primary Interoperability Assemblies 2005*'
                )
            }
    }
}

try {
    $entry = Get-PIAInstallEntry | Select-Object -First 1

    if ($entry) {
        Write-Host "Microsoft Primary Interop Assemblies 2005 detected: $($entry.DisplayName)"
        exit 0
    }
    else {
        Write-Host "Microsoft Primary Interop Assemblies 2005 not detected."
        exit 1
    }
}
catch {
    # Any unexpected error means detection should fail (app considered not installed)
    Write-Host "Error during detection: $($_.Exception.Message)"
    exit 1
}