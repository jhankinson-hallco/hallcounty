<# 
Easy Street Draw Intune Detection Script
Exit 0 = detected
Exit 1 = not detected
#>

$ErrorActionPreference = "SilentlyContinue"

$ExePath = "C:\Program Files (x86)\Easy Street Draw 7.7\ESDraw.exe"
$MinVersion = [version]"7.7.1.60143"

function Get-UninstallEntry {
    param([string]$Root)

    Get-ChildItem $Root -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.DisplayName -and $p.DisplayName -like "Easy Street Draw*") {
            return $p
        }
    }
    return $null
}

# 1) File presence + version check if possible
if (Test-Path $ExePath) {
    $file = Get-Item $ExePath
    $verString = $file.VersionInfo.ProductVersion

    if ([string]::IsNullOrWhiteSpace($verString)) {
        Write-Output "Installed"
        exit 0
    }

    try {
        $ver = [version]$verString
        if ($ver -ge $MinVersion) {
            Write-Output "Installed"
            exit 0
        }
    } catch {
        # If version parsing fails but file exists, treat as installed
        Write-Output "Installed"
        exit 0
    }
}

# 2) Registry-based fallback (checks both native + WOW6432Node)
$uninstall64 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$uninstall32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

$entry = Get-UninstallEntry -Root $uninstall64
if (-not $entry) { $entry = Get-UninstallEntry -Root $uninstall32 }

if ($entry -and $entry.DisplayVersion) {
    try {
        $regVer = [version]$entry.DisplayVersion
        if ($regVer -ge [version]"7.7.1") {
            Write-Output "Installed"
            exit 0
        }
    } catch {
        Write-Output "Installed"
        exit 0
    }
}

exit 1