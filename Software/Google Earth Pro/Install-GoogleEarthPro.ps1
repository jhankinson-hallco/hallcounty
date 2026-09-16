<#
.SYNOPSIS
    Install-GoogleEarthPro.ps1

.DESCRIPTION
    Installs Google Earth Pro using the packaged installer GoogleEarthProSetup.exe.
    
    - Silent install via OMAHA=1 parameter
    - Monitors for successful installation rather than waiting for process exit
      (Google's OMAHA installer spawns child processes and doesn't exit cleanly)
    - Validates installation by checking for googleearth.exe
    - Logs ONLY on error to C:\IntuneAppLogs\GoogleEarthPro_Install.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-GoogleEarthPro.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleEarthPro.ps1
    Install behavior: System
    Device restart behavior: No specific action
    
    KNOWN ISSUE:
    Google's OMAHA installer spawns background processes and the main process
    may not exit cleanly. This script monitors for successful file installation
    rather than relying on process exit.
    
    PACKAGE CONTENTS:
    GoogleEarthPro\
    ├── Install-GoogleEarthPro.ps1
    ├── Uninstall-GoogleEarthPro.ps1
    ├── Detect-GoogleEarthPro.ps1
    └── GoogleEarthProSetup.exe (either 32-bit or 64-bit version)
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION - Modify these variables for your deployment
# =============================================================================

# Application name (used for logging)
$AppName = "GoogleEarthPro"

# Installer filename - must match the file included in the Win32 app package
# Use "googleearthprowin-7.3.6.exe" for 32-bit
# Use "googleearthprowin-7.3.6-x64.exe" for 64-bit
$InstallerName = "GoogleEarthProSetup.exe"

# Silent install argument for Google Earth Pro EXE installer
# OMAHA=1 enables silent/unattended installation
# DESKTOPSHORTCUT=0 can be added to prevent desktop shortcut creation
$InstallerArguments = "OMAHA=1"

# Maximum time to wait for installation to complete (in seconds)
# This is how long we poll for the installed executable, not process wait time
$InstallationTimeoutSeconds = 300

# How often to check if installation is complete (in seconds)
$PollingIntervalSeconds = 10

# Detection paths - locations where googleearth.exe may be installed
# Script checks these paths in order to verify successful installation
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Google Earth Pro\client\googleearth.exe",
    "${env:ProgramFiles(x86)}\Google\Google Earth Pro\client\googleearth.exe"
)

# =============================================================================
# LOGGING CONFIGURATION - Do not modify unless organizational standards change
# =============================================================================

# Log directory for Win32 app errors (per specifications)
$LogDirectory = "C:\IntuneAppLogs"

# Log file name follows schema: <application-name>_Install.txt
$LogFileName = "${AppName}_Install.txt"

# Full path to log file (constructed from above)
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# =============================================================================
# EXIT CODES - Standard Intune and custom error codes
# =============================================================================

# Standard exit codes
$EXIT_SUCCESS = 0          # Installation completed successfully
$EXIT_FAILURE = 1          # General failure

# Intune retry code
$EXIT_RETRY = 1618         # Another installation in progress, Intune will retry

# Custom error codes (72xxx range for easy identification)
$ERR_INSTALLER_NOT_FOUND = 72001   # Installer EXE not found in package
$ERR_INSTALLER_FAILED = 72002      # Installer process failed to start
$ERR_INSTALLER_TIMEOUT = 72003     # Installation did not complete within timeout
$ERR_NOT_DETECTED = 72004          # Installation completed but app not found

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Writes error information to the log file.
    
    .DESCRIPTION
        Creates the log directory and file if they don't exist (as separate operations),
        then appends the error message with timestamp.
        Per requirements: logging only occurs when errors happen.
    
    .PARAMETER Message
        The error message to write to the log file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        # Step 1: Create log directory if it doesn't exist
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 2: Create log file if it doesn't exist (separate from writing)
        if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 3: Write to log file (separate operation from creation)
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $LogFilePath -Value "[$Timestamp] $Message" -ErrorAction Stop
    }
    catch {
        # If logging fails, write to stderr so Intune captures it
        Write-Error "LOGGING FAILED: Could not write to log. Original message: $Message"
    }
}

function Exit-WithError {
    <#
    .SYNOPSIS
        Logs detailed error information and exits with the specified code.
    
    .DESCRIPTION
        Writes comprehensive error details to the log file for troubleshooting,
        then exits the script with the specified exit code.
    
    .PARAMETER ExitCode
        The exit code to return when the script terminates.
    
    .PARAMETER Message
        Description of the error that occurred.
    
    .PARAMETER ErrorCategory
        Optional. Category of error: PROGRAM, SYSTEM, NETWORK, PERMISSIONS, or INTUNE.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorCategory = "PROGRAM"
    )
    
    # Write header
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Category: $ErrorCategory"
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "Script Path: $PSCommandPath"
    Write-ErrorLog -Message "Installer: $InstallerName"
    Write-ErrorLog -Message "Arguments: $InstallerArguments"
    
    # Log detection paths for troubleshooting
    Write-ErrorLog -Message "Detection Paths Checked:"
    foreach ($Path in $DetectionPaths) {
        $Exists = Test-Path -LiteralPath $Path -PathType Leaf
        Write-ErrorLog -Message "  [$Exists] $Path"
    }
    
    Write-ErrorLog -Message "=========================================="
    
    # Write to stderr for Intune to capture
    Write-Error "[$ErrorCategory] ERROR $ExitCode : $Message"
    
    exit $ExitCode
}

function Test-GoogleEarthInstalled {
    <#
    .SYNOPSIS
        Checks if Google Earth Pro is installed by verifying file existence.
    
    .DESCRIPTION
        Iterates through known installation paths to find googleearth.exe.
        File-based detection is preferred over registry detection per requirements.
    
    .OUTPUTS
        Boolean - $true if installed, $false if not found
    #>
    
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Wait-ForInstallation {
    <#
    .SYNOPSIS
        Polls for successful installation instead of waiting for process exit.
    
    .DESCRIPTION
        Google's OMAHA installer spawns child processes and the main process
        may not exit cleanly. This function monitors for the appearance of
        the installed executable to determine when installation is complete.
    
    .OUTPUTS
        Boolean - $true if installation detected, $false if timeout reached
    #>
    
    $ElapsedSeconds = 0
    
    while ($ElapsedSeconds -lt $InstallationTimeoutSeconds) {
        # Check if Google Earth Pro is now installed
        if (Test-GoogleEarthInstalled) {
            return $true
        }
        
        # Wait before checking again
        Start-Sleep -Seconds $PollingIntervalSeconds
        $ElapsedSeconds += $PollingIntervalSeconds
    }
    
    # Timeout reached without detecting installation
    return $false
}

# =============================================================================
# PRE-EXECUTION: Ensure 64-bit PowerShell on 64-bit OS
# =============================================================================
# The Intune Management Extension may launch PowerShell as 32-bit.
# Google Earth Pro 64-bit installs to Program Files, which requires 64-bit PowerShell
# to correctly resolve environment variables and paths.

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    # Currently running as 32-bit on 64-bit OS - relaunch as 64-bit
    $SysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    
    if (Test-Path -LiteralPath $SysNativePowerShell -PathType Leaf) {
        # Build argument string to relaunch this script in 64-bit PowerShell
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        
        # Start 64-bit PowerShell and wait for completion
        $Process = Start-Process -FilePath $SysNativePowerShell -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        
        # Exit with the same code as the relaunched process
        exit $Process.ExitCode
    }
    # If Sysnative path doesn't exist, continue with 32-bit (shouldn't happen on modern Windows)
}

# =============================================================================
# MAIN SCRIPT EXECUTION
# =============================================================================

try {
    # -------------------------------------------------------------------------
    # STEP 1: Check if Google Earth Pro is already installed (idempotent)
    # -------------------------------------------------------------------------
    # If already installed, exit success immediately to avoid reinstallation.
    # This makes the script idempotent and safe to run multiple times.
    
    if (Test-GoogleEarthInstalled) {
        # Already installed - exit success without logging (not an error condition)
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Locate the installer in the Win32 app package
    # -------------------------------------------------------------------------
    # $PSScriptRoot contains the directory where this script is located,
    # which is the extracted Win32 app package folder.
    
    $InstallerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerName
    
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_INSTALLER_NOT_FOUND `
                       -Message "Installer file not found: '$InstallerPath'. Ensure '$InstallerName' is included in the .intunewin package." `
                       -ErrorCategory "INTUNE"
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Launch the installer (fire and forget - don't wait for exit)
    # -------------------------------------------------------------------------
    # Google Earth Pro's OMAHA installer spawns child processes and the main
    # process may not exit cleanly. We start the installer and then poll for
    # successful installation rather than waiting for the process to exit.
    
    try {
        # Start the installer process without waiting
        # The OMAHA installer will run in the background
        $ProcessStartInfo = @{
            FilePath     = $InstallerPath
            ArgumentList = $InstallerArguments
            WindowStyle  = "Hidden"
            ErrorAction  = "Stop"
        }
        
        Start-Process @ProcessStartInfo
    }
    catch {
        Exit-WithError -ExitCode $ERR_INSTALLER_FAILED `
                       -Message "Failed to start installer process: $($_.Exception.Message)" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Monitor for successful installation
    # -------------------------------------------------------------------------
    # Poll for the installed executable to appear instead of waiting for
    # the installer process to exit. This works around the OMAHA issue.
    
    # Brief initial delay to let installer start
    Start-Sleep -Seconds 5
    
    $InstallationDetected = Wait-ForInstallation
    
    if (-not $InstallationDetected) {
        Exit-WithError -ExitCode $ERR_INSTALLER_TIMEOUT `
                       -Message "Installation did not complete within $InstallationTimeoutSeconds seconds. Google Earth Pro executable was not detected." `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Final verification
    # -------------------------------------------------------------------------
    # Double-check installation is complete
    
    Start-Sleep -Seconds 3
    
    if (-not (Test-GoogleEarthInstalled)) {
        Exit-WithError -ExitCode $ERR_NOT_DETECTED `
                       -Message "Installation appeared to complete but Google Earth Pro was not detected on final verification." `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 6: Installation successful
    # -------------------------------------------------------------------------
    # No logging on success (per requirements - error-only logging)
    
    exit $EXIT_SUCCESS
}
catch {
    # -------------------------------------------------------------------------
    # CATCH BLOCK: Handle any unexpected errors
    # -------------------------------------------------------------------------
    # This catches any unhandled exceptions that weren't caught by specific
    # error handling above.
    
    $ErrorMsg = "Unexpected error during installation: $($_.Exception.Message)"
    
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $ErrorMsg"
    Write-ErrorLog -Message "Exception Type: $($_.Exception.GetType().FullName)"
    Write-ErrorLog -Message "Stack Trace: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}