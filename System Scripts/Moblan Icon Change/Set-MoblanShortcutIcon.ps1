#requires -version 5.1

<#
.SYNOPSIS
    Set-MoblanShortcutIcon.ps1

.DESCRIPTION
    Copies the Moblan icon from network share and updates the desktop shortcut icon.
    
    - Copies MobLanIcon.ico to C:\IntuneDeploymentFiles\Images
    - Updates C:\Users\Public\Desktop\Moblan.lnk to use the new icon

.NOTES
    Deploy as Intune Platform Script (not Win32 app)
    
    INTUNE SCRIPT SETTINGS:
    Run this script using the logged on credentials: No
    Enforce script signature check: No
    Run script in 64-bit PowerShell: Yes
#>

$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION
# =============================================================================

$SourceIcon = '\\psjapp\RMSAPPS\moblan\Mfr\MobLanIcon.ico'
$LocalIconFolder = 'C:\IntuneDeploymentFiles\Images'
$LocalIconPath = Join-Path -Path $LocalIconFolder -ChildPath 'MobLanIcon.ico'
$ShortcutPath = 'C:\Users\Public\Desktop\Moblan.lnk'

$LogFolder = 'C:\IntuneScriptLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath 'MoblanIcon_Install.txt'

# =============================================================================
# LOGGING
# =============================================================================

function Write-Log {
    param([string]$Message)
    
    try {
        if (-not (Test-Path -LiteralPath $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
    }
    catch { }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Log "========== Set-MoblanShortcutIcon Started =========="
Write-Log "Computer: $env:COMPUTERNAME"

try {
    # Verify shortcut exists
    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
        Write-Log "ERROR: Shortcut not found: $ShortcutPath"
        exit 1
    }
    Write-Log "Shortcut found: $ShortcutPath"
    
    # Verify source icon is accessible
    if (-not (Test-Path -LiteralPath $SourceIcon -PathType Leaf)) {
        Write-Log "ERROR: Source icon not found: $SourceIcon"
        exit 1
    }
    Write-Log "Source icon accessible: $SourceIcon"
    
    # Create local icon folder if needed
    if (-not (Test-Path -LiteralPath $LocalIconFolder)) {
        New-Item -Path $LocalIconFolder -ItemType Directory -Force | Out-Null
        Write-Log "Created folder: $LocalIconFolder"
    }
    
    # Copy icon to local folder
    Copy-Item -LiteralPath $SourceIcon -Destination $LocalIconPath -Force
    Write-Log "Copied icon to: $LocalIconPath"
    
    # Verify copy succeeded
    if (-not (Test-Path -LiteralPath $LocalIconPath -PathType Leaf)) {
        Write-Log "ERROR: Icon copy failed"
        exit 1
    }
    
    # Update shortcut icon
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    
    Write-Log "Current icon: $($Shortcut.IconLocation)"
    
    $Shortcut.IconLocation = "$LocalIconPath,0"
    $Shortcut.Save()
    
    Write-Log "Updated icon to: $LocalIconPath,0"
    
    # Release COM object
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    
    Write-Log "========== Set-MoblanShortcutIcon Completed Successfully =========="
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
