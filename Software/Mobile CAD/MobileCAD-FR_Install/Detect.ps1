#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Detect.ps1

Detection strategy (file existence only):
- Desktop shortcut exists on Common/Public Desktop
- Primary executable exists under C:\Mobile Client FD\Mobile Client\VMLaunch.exe

Exit codes:
- 0 = Detected (installed)
- 1 = Not detected
#>

# ============================
# CONFIG (CHANGE HERE ONLY)
# ============================
$ShortcutFileName  = 'FD.Classic.lnk'
$DestExe           = 'C:\Mobile Client FD\Mobile Client\VMLaunch.exe'
# ============================

$CommonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
if ([string]::IsNullOrWhiteSpace($CommonDesktop)) {
    $CommonDesktop = Join-Path $env:PUBLIC 'Desktop'
}
$DestLnk = Join-Path $CommonDesktop $ShortcutFileName

$shortcutOk = Test-Path -LiteralPath $DestLnk
$exeOk      = Test-Path -LiteralPath $DestExe

if ($shortcutOk -and $exeOk) {
    exit 0
}

exit 1