<#
.SYNOPSIS
    Uninstall-IntuneSyncTool.ps1

.DESCRIPTION
    Removes the Intune Sync Tool and desktop shortcut.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-IntuneSyncTool.ps1
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION - Must match Install script
# =============================================================================

$InstallFolder = "C:\ProgramData\IntuneSyncTool"
$ShortcutName = "Sync with Intune.lnk"
$PublicDesktop = "C:\Users\Public\Desktop"

# Icon settings - must match Install script
$IconFileName = "Intune Sync Icon.ico"
$IconStorageFolder = "C:\IntuneDeploymentFiles\Images"

# =============================================================================
# END CONFIGURATION
# =============================================================================

try {
    # Remove desktop shortcut
    $ShortcutPath = Join-Path -Path $PublicDesktop -ChildPath $ShortcutName
    
    if (Test-Path -LiteralPath $ShortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $ShortcutPath -Force -ErrorAction SilentlyContinue
    }
    
    # Remove installation folder
    if (Test-Path -LiteralPath $InstallFolder -PathType Container) {
        Remove-Item -LiteralPath $InstallFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove icon from storage folder
    $IconPath = Join-Path -Path $IconStorageFolder -ChildPath $IconFileName
    if (Test-Path -LiteralPath $IconPath -PathType Leaf) {
        Remove-Item -LiteralPath $IconPath -Force -ErrorAction SilentlyContinue
    }
    
    exit 0
}
catch {
    # Uninstall should not fail hard
    exit 0
}
