<# 
.SYNOPSIS
    Install-ESDraw.ps1
    Silently installs Easy Street Draw via MSI and activates the license.

.DESCRIPTION
    - Designed for Hybrid Join / Autopilot environments
    - Runs AFTER Autopilot completes (assign to device group, not ESP)
    - Logs ONLY on failure to C:\IntuneAppLogs\ESDraw_Install.txt
    - MSI verbose log created during install, deleted on success, kept on failure
    - 10-minute timeout prevents indefinite hangs (applies to both MSI and activation)
    - Uses msiexec.exe for maximum MSI compatibility
    - Post-install license activation via ESDraw.exe /activate
    - No reboot functionality - script never triggers or reports reboot

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-ESDraw.ps1
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application display name (used in logging)
$AppName = "ESDraw"

# MSI installer filename (must be in same folder as this script)
$MsiFileName = "ESDraw_7_7_1_60143.msi"

# Path to executable after installation (used for license activation)
$ExpectedExePath = "C:\Program Files (x86)\Easy Street Draw 7.7\ESDraw.exe"

# License activation arguments passed to ESDraw.exe
# Format: /activate --licenseID <ID> --licensePW <PASSWORD>
$ActivationArgs = '/activate --licenseID 64698688 --licensePW 44K9JL82'

# Log folder location (standard for Intune deployments)
$LogFolder = "C:\IntuneAppLogs"

# Installation timeout in seconds (600 = 10 minutes)
# Applies to both MSI installation and license activation processes
$TimeoutSeconds = 600

#================================================================================
# CUSTOM ERROR CODES - INTUNE-FRIENDLY, RESEARCHABLE VALUES
#================================================================================

# MSI-related errors (700xx range)
$ERR_MSI_NOT_FOUND       = 70001  # MSI file not in package
$ERR_MSIEXEC_NOT_FOUND   = 70002  # msiexec.exe missing (corrupt OS)
$ERR_MSI_START_FAILED    = 70003  # Could not start msiexec process
$ERR_MSI_TIMEOUT         = 70004  # MSI installation timed out

# Activation-related errors (710xx range)
$ERR_ACT_EXE_MISSING     = 71001  # ESDraw.exe not found after install
$ERR_ACT_START_FAILED    = 71002  # Could not start activation process
$ERR_ACT_TIMEOUT         = 71003  # Activation process timed out
$ERR_ACT_FAILED          = 71004  # Activation returned non-zero exit code

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

#--------------------------------------------------------------------------------
# FUNCTION: Invoke-MsiInstall
# PURPOSE:  Executes the MSI installation with timeout protection.
# RETURNS:  MSI exit code if successful
# NOTES:    Exits script directly on failure (does not return)
#--------------------------------------------------------------------------------
function Invoke-MsiInstall {
    # Start the MSI installation process
    # -PassThru returns process object for monitoring
    # -WindowStyle Hidden prevents any UI flash
    # Note: We do NOT use -Wait because we need to implement timeout
    try {
        $InstallProcess = Start-Process -FilePath $MsiExecPath `
                                        -ArgumentList $MsiArguments `
                                        -PassThru `
                                        -WindowStyle Hidden `
                                        -ErrorAction Stop
    }
    catch {
        Exit-WithError -ExitCode $ERR_MSI_START_FAILED -Message "Failed to start msiexec.exe: $($_.Exception.Message)"
    }
    
    # Wait for process to complete with timeout
    # WaitForExit returns $true if process exited, $false if timeout reached
    $ProcessCompleted = $InstallProcess.WaitForExit($TimeoutSeconds * 1000)
    
    # Handle timeout scenario
    if (-not $ProcessCompleted) {
        # Attempt to kill the hung process
        try {
            $InstallProcess.Kill()
        }
        catch {
            # Process may have exited between check and kill; ignore
        }
        
        Exit-WithError -ExitCode $ERR_MSI_TIMEOUT -Message "MSI installation timed out after $TimeoutSeconds seconds. Process was terminated."
    }
    
    # Return the exit code for evaluation
    return $InstallProcess.ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Invoke-LicenseActivation
# PURPOSE:  Runs the license activation command after MSI installation.
# NOTES:    Exits script directly on failure (does not return)
#           Uses same timeout as MSI installation
#--------------------------------------------------------------------------------
function Invoke-LicenseActivation {
    # Verify the executable exists (MSI installed correctly)
    if (-not (Test-Path -Path $ExpectedExePath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_ACT_EXE_MISSING -Message "Activation executable not found at: $ExpectedExePath"
    }
    
    # Start the activation process
    try {
        $ActivationProcess = Start-Process -FilePath $ExpectedExePath `
                                           -ArgumentList $ActivationArgs `
                                           -PassThru `
                                           -WindowStyle Hidden `
                                           -ErrorAction Stop
    }
    catch {
        Exit-WithError -ExitCode $ERR_ACT_START_FAILED -Message "Failed to start activation process: $($_.Exception.Message)"
    }
    
    # Wait for activation to complete with timeout
    $ProcessCompleted = $ActivationProcess.WaitForExit($TimeoutSeconds * 1000)
    
    # Handle timeout scenario
    if (-not $ProcessCompleted) {
        try {
            $ActivationProcess.Kill()
        }
        catch {
            # Process may have exited between check and kill; ignore
        }
        
        Exit-WithError -ExitCode $ERR_ACT_TIMEOUT -Message "License activation timed out after $TimeoutSeconds seconds. Process was terminated."
    }
    
    # Check activation exit code
    $ActivationExitCode = $ActivationProcess.ExitCode
    if ($ActivationExitCode -ne 0) {
        Exit-WithError -ExitCode $ERR_ACT_FAILED -Message "License activation failed. ESDraw.exe returned exit code: $ActivationExitCode"
    }
    
    # Activation successful - no return value needed
}

#================================================================================
# MAIN INSTALLATION LOGIC
#================================================================================

# STEP 1: Verify the MSI installer file exists in the script directory
#         If missing, the IntuneWin package was not built correctly
if (-not (Test-Path -Path $MsiPath -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_MSI_NOT_FOUND -Message "MSI installer not found at path: $MsiPath"
}

# STEP 2: Verify msiexec.exe is available (should always exist on Windows)
#         This is a sanity check for corrupted/minimal OS installations
if (-not (Test-Path -Path $MsiExecPath -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_MSIEXEC_NOT_FOUND -Message "msiexec.exe not found at: $MsiExecPath"
}

# STEP 3: Ensure log folder exists for MSI verbose logging
#         MSI needs this folder to exist before it can write the log
if (-not (Test-Path -Path $LogFolder -PathType Container)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# STEP 4: Execute the MSI installation with timeout
$MsiExitCode = Invoke-MsiInstall

# STEP 5: Evaluate the MSI exit code
#         Standard MSI exit codes: https://docs.microsoft.com/en-us/windows/win32/msi/error-codes
switch ($MsiExitCode) {
    # SUCCESS CODES - Continue to activation
    0       { }  # Standard success
    3010    { }  # Success, reboot would be needed (ignored per requirements)
    1641    { }  # Success, reboot was requested (ignored per requirements)
    
    # FAILURE CODES - Log error, preserve MSI log, exit with MSI code
    1618    { Exit-WithError -ExitCode 1618 -Message "Another installation is in progress. MSI mutex locked." }
    1619    { Exit-WithError -ExitCode 1619 -Message "MSI package could not be opened. File may be corrupt." }
    1620    { Exit-WithError -ExitCode 1620 -Message "MSI package path is invalid: $MsiPath" }
    1603    { Exit-WithError -ExitCode 1603 -Message "Fatal error during installation (MSI 1603). See ${AppName}_MSI.log for details." }
    1602    { Exit-WithError -ExitCode 1602 -Message "Installation was cancelled (MSI 1602)." }
    1601    { Exit-WithError -ExitCode 1601 -Message "Windows Installer service is not accessible (MSI 1601)." }
    default { Exit-WithError -ExitCode $MsiExitCode -Message "MSI installation failed with unexpected exit code. See ${AppName}_MSI.log for details." }
}

# STEP 6: Execute license activation (only reached if MSI succeeded)
Invoke-LicenseActivation

# STEP 7: All steps completed successfully
#         Clean up MSI log and exit success
Exit-WithSuccess
