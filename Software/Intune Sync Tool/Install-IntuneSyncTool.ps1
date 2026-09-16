<#
.SYNOPSIS
    Install-IntuneSyncTool.ps1

.DESCRIPTION
    Installs the Intune Sync Tool to the device and creates a desktop shortcut.
    Allows users to trigger Intune/Entra sync from the desktop without navigating
    through Settings.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-IntuneSyncTool.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-IntuneSyncTool.ps1
    Install behavior: System
    
    PACKAGE CONTENTS:
    - Install-IntuneSyncTool.ps1
    - Uninstall-IntuneSyncTool.ps1
    - Detect-IntuneSyncTool.ps1
    - Sync-IntuneDevice.ps1
    - Intune Sync Icon.ico
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

$AppName = "IntuneSyncTool"

# Installation paths
$InstallFolder = "C:\ProgramData\IntuneSyncTool"
$ScriptName = "Sync-IntuneDevice.ps1"

# Icon settings
$IconFileName = "Intune Sync Icon.ico"
$IconStorageFolder = "C:\IntuneDeploymentFiles\Images"

# Shortcut settings
$ShortcutName = "Sync with Intune.lnk"
$ShortcutDescription = "Sync this device with Intune and Entra ID"

# Where to place shortcut
$PublicDesktop = "C:\Users\Public\Desktop"

# Logging
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# =============================================================================
# END CONFIGURATION
# =============================================================================

function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    
    try {
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $LogFilePath -Value "[$Timestamp] $Message" -ErrorAction Stop
    }
    catch {
        Write-Error "LOGGING FAILED: $Message"
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    # -------------------------------------------------------------------------
    # STEP 1: Create installation folder
    # -------------------------------------------------------------------------
    
    if (-not (Test-Path -LiteralPath $InstallFolder -PathType Container)) {
        New-Item -Path $InstallFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Copy sync script to installation folder
    # -------------------------------------------------------------------------
    
    $SourceScript = Join-Path -Path $PSScriptRoot -ChildPath $ScriptName
    $DestScript = Join-Path -Path $InstallFolder -ChildPath $ScriptName
    
    if (Test-Path -LiteralPath $SourceScript -PathType Leaf) {
        Copy-Item -LiteralPath $SourceScript -Destination $DestScript -Force -ErrorAction Stop
    }
    else {
        Write-ErrorLog -Message "Source script not found: $SourceScript"
        exit 1
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Create icon storage folder and copy icon
    # -------------------------------------------------------------------------
    
    # Create the icon storage folder if it doesn't exist
    if (-not (Test-Path -LiteralPath $IconStorageFolder -PathType Container)) {
        New-Item -Path $IconStorageFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    
    $SourceIcon = Join-Path -Path $PSScriptRoot -ChildPath $IconFileName
    $DestIcon = Join-Path -Path $IconStorageFolder -ChildPath $IconFileName
    $IconPath = $null
    
    if (Test-Path -LiteralPath $SourceIcon -PathType Leaf) {
        Copy-Item -LiteralPath $SourceIcon -Destination $DestIcon -Force -ErrorAction Stop
        $IconPath = $DestIcon
    }
    else {
        # Fallback: Use built-in sync icon from shell32.dll if icon file not in package
        $IconPath = "%SystemRoot%\System32\shell32.dll,238"
        Write-ErrorLog -Message "Warning: Icon file '$IconFileName' not found in package. Using default shell icon."
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Create desktop shortcut
    # -------------------------------------------------------------------------
    
    $ShortcutPath = Join-Path -Path $PublicDesktop -ChildPath $ShortcutName
    
    $WshShell = New-Object -ComObject WScript.Shell -ErrorAction Stop
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$DestScript`""
    $Shortcut.WorkingDirectory = $InstallFolder
    $Shortcut.Description = $ShortcutDescription
    $Shortcut.WindowStyle = 7  # Minimized
    
    # Set icon
    if ($IconPath -like "*.ico") {
        $Shortcut.IconLocation = "$IconPath,0"
    }
    else {
        $Shortcut.IconLocation = $IconPath
    }
    
    $Shortcut.Save()
    
    # Release COM object
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    
    # -------------------------------------------------------------------------
    # STEP 5: Verify installation
    # -------------------------------------------------------------------------
    
    if (-not (Test-Path -LiteralPath $DestScript -PathType Leaf)) {
        Write-ErrorLog -Message "Installation verification failed - script not found at $DestScript"
        exit 1
    }
    
    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
        Write-ErrorLog -Message "Installation verification failed - shortcut not found at $ShortcutPath"
        exit 1
    }
    
    exit 0
}
catch {
    Write-ErrorLog -Message "Installation failed: $($_.Exception.Message)"
    exit 1
}
