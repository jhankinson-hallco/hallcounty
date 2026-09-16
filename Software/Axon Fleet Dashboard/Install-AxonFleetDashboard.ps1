<# 
.SYNOPSIS
    Install-AxonFleetDashboard.ps1
    Silently installs Axon Fleet Dashboard via MSI for Intune Win32 deployment.

.DESCRIPTION
    - Designed for Hybrid Join / Autopilot environments
    - Runs AFTER Autopilot completes (assign to device group, not ESP)
    - Logs ONLY on failure to C:\IntuneAppLogs\AxonFleetDashboard_Install.txt
    - MSI verbose log created during install, deleted on success, kept on failure
    - 10-minute timeout prevents indefinite hangs
    - Uses msiexec.exe for maximum MSI compatibility
    - No reboot functionality - script never triggers or reports reboot

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-AxonFleetDashboard.ps1
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application display name (used in logging)
$AppName = "AxonFleetDashboard"

# MSI installer filename (must be in same folder as this script)
$MsiFileName = "Axon Fleet Dashboard_1.2.7685.msi"

# Log folder location (standard for Intune deployments)
$LogFolder = "C:\IntuneAppLogs"

# Installation timeout in seconds (600 = 10 minutes)
# If MSI takes longer than this, it will be terminated and marked as failed
$TimeoutSeconds = 600

#================================================================================
# END CONFIGURATION SECTION - DO NOT MODIFY BELOW UNLESS NECESSARY
#================================================================================

# Build log file paths using required naming schema
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"
$MsiLogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_MSI.log"

# Build full path to MSI installer
$MsiPath = Join-Path -Path $PSScriptRoot -ChildPath $MsiFileName

# Build msiexec path
$MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\msiexec.exe"

# Silent install arguments for msiexec
# /qn = completely silent, no UI
# /norestart = prevent automatic reboot (critical for Autopilot)
# /l*v = verbose logging to specified file (will be deleted on success)
$MsiArguments = "/i `"$MsiPath`" /qn /norestart /l*v `"$MsiLogFile`""

#--------------------------------------------------------------------------------
# FUNCTION: Initialize-ErrorLog
# PURPOSE:  Creates the log folder and log file ONLY when an error occurs.
#           Per requirements, we do not log success - only failures.
# NOTES:    Creates folder first, then file separately (never same line).
#--------------------------------------------------------------------------------
function Initialize-ErrorLog {
    # Check if log folder exists; create if missing
    if (-not (Test-Path -Path $LogFolder -PathType Container)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    
    # Check if log file exists; create if missing (separate step per requirement #5)
    if (-not (Test-Path -Path $LogFile -PathType Leaf)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Write-ErrorLog
# PURPOSE:  Writes a timestamped error message to the log file.
# PARAMS:   Message - The error message to record
#           ExitCode - The exit code associated with this error
# NOTES:    Initializes log infrastructure before writing (ensures file exists).
#--------------------------------------------------------------------------------
function Write-ErrorLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [int]$ExitCode
    )
    
    # Ensure log folder and file exist before writing
    Initialize-ErrorLog
    
    # Build timestamped log entry
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [ERROR] $Message | ExitCode: $ExitCode"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry
}

#--------------------------------------------------------------------------------
# FUNCTION: Exit-WithError
# PURPOSE:  Logs the error and exits with the specified code.
# PARAMS:   ExitCode - Intune-compatible exit code to return
#           Message - Descriptive error message for troubleshooting
# NOTES:    This is the single exit point for all error conditions.
#           MSI log is preserved on failure for troubleshooting.
#--------------------------------------------------------------------------------
function Exit-WithError {
    param(
        [Parameter(Mandatory)]
        [int]$ExitCode,
        
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    # Log the error with full details
    Write-ErrorLog -Message $Message -ExitCode $ExitCode
    
    # Note: MSI log file is intentionally NOT deleted here
    # It provides detailed troubleshooting info for failures
    
    # Exit with the error code (Intune will capture this)
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Exit-WithSuccess
# PURPOSE:  Cleans up MSI log file and exits with code 0.
# NOTES:    MSI verbose log is deleted on success to keep things clean.
#           No logging occurs on success per requirement #3.
#--------------------------------------------------------------------------------
function Exit-WithSuccess {
    # Delete MSI verbose log on success (not needed for troubleshooting)
    if (Test-Path -Path $MsiLogFile -PathType Leaf) {
        Remove-Item -Path $MsiLogFile -Force -ErrorAction SilentlyContinue
    }
    
    # Exit success
    exit 0
}

#================================================================================
# MAIN INSTALLATION LOGIC
#================================================================================

# STEP 1: Verify the MSI installer file exists in the script directory
#         If missing, the IntuneWin package was not built correctly
if (-not (Test-Path -Path $MsiPath -PathType Leaf)) {
    Exit-WithError -ExitCode 2 -Message "MSI installer not found at path: $MsiPath"
}

# STEP 2: Verify msiexec.exe is available (should always exist on Windows)
#         This is a sanity check for corrupted/minimal OS installations
if (-not (Test-Path -Path $MsiExecPath -PathType Leaf)) {
    Exit-WithError -ExitCode 3 -Message "msiexec.exe not found at: $MsiExecPath"
}

# STEP 3: Ensure log folder exists for MSI verbose logging
#         MSI needs this folder to exist before it can write the log
if (-not (Test-Path -Path $LogFolder -PathType Container)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# STEP 4: Execute the MSI installation
#         -PassThru returns the process object so we can monitor it
#         -WindowStyle Hidden prevents any UI flash
#         Note: We do NOT use -Wait here because we need to implement timeout
try {
    $InstallProcess = Start-Process -FilePath $MsiExecPath `
                                    -ArgumentList $MsiArguments `
                                    -PassThru `
                                    -WindowStyle Hidden `
                                    -ErrorAction Stop
}
catch {
    # Catch any PowerShell-level errors (process couldn't start, access denied, etc.)
    Exit-WithError -ExitCode 1 -Message "Failed to start msiexec.exe: $($_.Exception.Message)"
}

# STEP 5: Wait for process to complete with timeout
#         WaitForExit returns $true if process exited, $false if timeout reached
#         Timeout is in milliseconds, so multiply seconds by 1000
$ProcessCompleted = $InstallProcess.WaitForExit($TimeoutSeconds * 1000)

# STEP 6: Handle timeout scenario
#         If process did not complete within timeout, kill it and fail
if (-not $ProcessCompleted) {
    # Attempt to kill the hung process
    try {
        $InstallProcess.Kill()
    }
    catch {
        # Process may have exited between check and kill attempt; ignore error
    }
    
    Exit-WithError -ExitCode 258 -Message "Installation timed out after $TimeoutSeconds seconds. Process was terminated."
}

# STEP 7: Evaluate the MSI exit code
#         Standard MSI exit codes: https://docs.microsoft.com/en-us/windows/win32/msi/error-codes
$MsiExitCode = $InstallProcess.ExitCode

switch ($MsiExitCode) {
    # SUCCESS CODES - Clean up MSI log and exit 0
    0       { Exit-WithSuccess }  # Standard success
    3010    { Exit-WithSuccess }  # Success, reboot would be needed (ignored per requirements)
    1641    { Exit-WithSuccess }  # Success, reboot was requested (ignored per requirements)
    
    # FAILURE CODES - Log error, preserve MSI log, exit with MSI code
    1618    { Exit-WithError -ExitCode 1618 -Message "Another installation is in progress. MSI mutex locked." }
    1619    { Exit-WithError -ExitCode 1619 -Message "MSI package could not be opened. File may be corrupt." }
    1620    { Exit-WithError -ExitCode 1620 -Message "MSI package path is invalid: $MsiPath" }
    1603    { Exit-WithError -ExitCode 1603 -Message "Fatal error during installation (MSI 1603). See ${AppName}_MSI.log for details." }
    1602    { Exit-WithError -ExitCode 1602 -Message "Installation was cancelled (MSI 1602)." }
    1601    { Exit-WithError -ExitCode 1601 -Message "Windows Installer service is not accessible (MSI 1601)." }
    default { Exit-WithError -ExitCode $MsiExitCode -Message "MSI installation failed with unexpected exit code. See ${AppName}_MSI.log for details." }
}
