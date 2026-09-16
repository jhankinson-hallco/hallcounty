<#
.SYNOPSIS
    Detect-IntuneSyncTool.ps1

.DESCRIPTION
    Detects if the Intune Sync Tool is installed.

.NOTES
    INTUNE DETECTION:
    - Exit 0 + Write-Output = DETECTED
    - Exit 1 = NOT DETECTED
#>

#Requires -Version 5.1

$InstallFolder = "C:\ProgramData\IntuneSyncTool"
$ScriptName = "Sync-IntuneDevice.ps1"
$ShortcutName = "Sync with Intune.lnk"
$PublicDesktop = "C:\Users\Public\Desktop"

$ScriptPath = Join-Path -Path $InstallFolder -ChildPath $ScriptName
$ShortcutPath = Join-Path -Path $PublicDesktop -ChildPath $ShortcutName

# Check both script and shortcut exist
if ((Test-Path -LiteralPath $ScriptPath -PathType Leaf) -and 
    (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
    Write-Output "Intune Sync Tool detected"
    exit 0
}

exit 1
