#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================
# CONFIG - CHANGE ONLY THIS LINE
# ============================
$ShortcutName = 'RMS OneSolution.lnk'   # <=== CHANGE ONLY THIS LINE
# ============================

$DestFolder = Join-Path $env:PUBLIC 'Desktop'
$BaseName   = [System.IO.Path]::GetFileNameWithoutExtension($ShortcutName)

$LogRoot = 'C:\IntuneAppLogs'
$LogFile = Join-Path $LogRoot ("{0}_Install.txt" -f $BaseName)

$RegRoot = 'HKLM:\SOFTWARE\HallCounty\IntuneShortcuts'
$RegPath = Join-Path $RegRoot $BaseName

function Initialize-Logging {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}
function Write-Log {
    param([Parameter(Mandatory)][string]$Message)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $LogFile -Value "[$ts] $Message"
}
function Fail {
    param([Parameter(Mandatory)][string]$Message, [Parameter(Mandatory)][int]$ExitCode)
    try { Write-Log "ERROR: $Message" } catch {}
    exit $ExitCode
}

Initialize-Logging
Write-Log "Starting uninstall for shortcut '$ShortcutName'."

$DestPath = Join-Path $DestFolder $ShortcutName

try {
    if (Test-Path -LiteralPath $DestPath) {
        Write-Log "Removing shortcut: $DestPath"
        Remove-Item -LiteralPath $DestPath -Force
    } else {
        Write-Log "Shortcut not present: $DestPath"
    }

    if (Test-Path -LiteralPath $RegPath) {
        Write-Log "Removing detection marker: $RegPath"
        Remove-Item -LiteralPath $RegPath -Recurse -Force
    } else {
        Write-Log "Detection marker not present: $RegPath"
    }

    Write-Log "Uninstall completed successfully."
    exit 0
}
catch [System.UnauthorizedAccessException] {
    Fail -Message "Access denied. Details: $($_.Exception.Message)" -ExitCode 5
}
catch {
    Fail -Message "Unhandled exception: $($_.Exception.Message)" -ExitCode 1
}