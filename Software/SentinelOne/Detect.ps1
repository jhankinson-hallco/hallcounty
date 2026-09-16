<#
Detect-SentinelOne.ps1
- Detects SentinelOne installed status for Intune
- Uses service check + uninstall registry fallback
- Does not attempt to enforce reboot gating in detection
#>

$ErrorActionPreference = "SilentlyContinue"

function Test-SentinelOneInstalled {
    $svc = Get-Service -Name "SentinelAgent" -ErrorAction SilentlyContinue
    if ($svc) { return $true }

    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($r in $roots) {
        foreach ($k in (Get-ChildItem $r -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -and $p.DisplayName -like "SentinelOne*") {
                return $true
            }
        }
    }

    return $false
}

if (Test-SentinelOneInstalled) {
    Write-Output "Installed"
    exit 0
}

exit 1