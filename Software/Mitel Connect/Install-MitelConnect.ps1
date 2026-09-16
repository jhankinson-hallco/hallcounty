#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Install-MitelConnect.ps1

.DESCRIPTION
    Installs Mitel Connect by:
    1. Copying the "Connect" folder to C:\Program Files (x86)\Mitel\
    2. Copying "Mitel Connect.lnk" to C:\Users\Public\Desktop
    
    Logs ONLY on error to C:\IntuneAppLogs\MitelConnect_Install.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-MitelConnect.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-MitelConnect.ps1
    Install behavior: System
    
    PACKAGE CONTENTS:
    MitelConnect\
    ├── Install-MitelConnect.ps1
    ├── Uninstall-MitelConnect.ps1
    ├── Detect.ps1
    ├── Mitel Connect.lnk
    └── Connect\
        └── (all Mitel Connect files)
#>

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'MitelConnect'

# Source paths (relative to script location in package)
$SourceFolderName = 'Connect'
$SourceShortcutName = 'Mitel Connect.lnk'

# Destination paths
$DestinationRoot = 'C:\Program Files (x86)\Mitel'
$DestinationFolder = Join-Path -Path $DestinationRoot -ChildPath 'Connect'

$PublicDesktop = 'C:\Users\Public\Desktop'
$DestinationShortcut = Join-Path -Path $PublicDesktop -ChildPath 'Mitel Connect.lnk'

# Logging
$LogFolder = 'C:\IntuneAppLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1
$EXIT_RETRY = 1618

$ERR_SOURCE_NOT_FOUND = 71001
$ERR_COPY_FAILED = 71002
$ERR_SHORTCUT_FAILED = 71003

# =============================================================================
# END CONFIGURATION
# =============================================================================

# Build source paths from package location
$SourceFolder = Join-Path -Path $PSScriptRoot -ChildPath $SourceFolderName
$SourceShortcut = Join-Path -Path $PSScriptRoot -ChildPath $SourceShortcutName

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS (Error-only)
#--------------------------------------------------------------------------------
$script:LogInitialized = $false

function Initialize-ErrorLog {
    if ($script:LogInitialized) { return }
    
    try {
        if (-not (Test-Path -Path $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
        $script:LogInitialized = $true
    }
    catch {
        $script:LogInitialized = $true
    }
}

function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    
    try {
        Initialize-ErrorLog
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message
    )
    
    Write-ErrorLog -Message "ERROR ($ExitCode): $Message"
    Write-ErrorLog -Message "Context: User=$env:USERNAME, ScriptRoot=$PSScriptRoot"
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# 64-BIT POWERSHELL RELAUNCH
#--------------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    
    if (Test-Path -LiteralPath $SysNativePwsh) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

# STEP 1: Verify source files exist in package
if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
    # Log package contents for troubleshooting
    $PackageContents = @()
    try {
        $PackageContents = Get-ChildItem -LiteralPath $PSScriptRoot -Force -ErrorAction SilentlyContinue | 
                           Select-Object -ExpandProperty Name
    }
    catch { }
    
    $Listing = if ($PackageContents.Count -gt 0) { $PackageContents -join ', ' } else { '<empty>' }
    Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Source folder not found: $SourceFolder. Package contents: $Listing"
}

if (-not (Test-Path -LiteralPath $SourceShortcut -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Source shortcut not found: $SourceShortcut"
}

# STEP 2: Create destination folder if needed
try {
    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
        New-Item -Path $DestinationRoot -ItemType Directory -Force | Out-Null
    }
}
catch {
    Exit-WithError -ExitCode $ERR_COPY_FAILED -Message "Failed to create destination folder: $($_.Exception.Message)"
}

# STEP 3: Copy Connect folder to Program Files (x86)\Mitel\
try {
    Copy-Item -LiteralPath $SourceFolder -Destination $DestinationRoot -Recurse -Force -ErrorAction Stop
}
catch {
    Exit-WithError -ExitCode $ERR_COPY_FAILED -Message "Failed to copy Connect folder: $($_.Exception.Message)"
}

# Verify copy succeeded
if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
    Exit-WithError -ExitCode $ERR_COPY_FAILED -Message "Connect folder not present after copy: $DestinationFolder"
}

# STEP 4: Copy shortcut to Public Desktop
try {
    Copy-Item -LiteralPath $SourceShortcut -Destination $DestinationShortcut -Force -ErrorAction Stop
}
catch {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Failed to copy shortcut: $($_.Exception.Message)"
}

# Verify shortcut exists
if (-not (Test-Path -LiteralPath $DestinationShortcut -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Shortcut not present after copy: $DestinationShortcut"
}

# SUCCESS
exit $EXIT_SUCCESS
