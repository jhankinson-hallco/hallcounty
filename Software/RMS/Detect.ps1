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

$DestPath = Join-Path $DestFolder $ShortcutName

$RegRoot = 'HKLM:\SOFTWARE\HallCounty\IntuneShortcuts'
$RegPath = Join-Path $RegRoot $BaseName

try {
    if (-not (Test-Path -LiteralPath $DestPath)) { exit 1 }
    if (-not (Test-Path -LiteralPath $RegPath))  { exit 1 }

    $expectedName = (Get-ItemProperty -LiteralPath $RegPath -Name 'ShortcutName' -ErrorAction Stop).ShortcutName
    $expectedHash = (Get-ItemProperty -LiteralPath $RegPath -Name 'Sha256'       -ErrorAction Stop).Sha256

    if ($expectedName -ne $ShortcutName) { exit 1 }

    $actualHash = (Get-FileHash -LiteralPath $DestPath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { exit 1 }

    exit 0
}
catch {
    exit 1
}