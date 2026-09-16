<# 
.SYNOPSIS
    Install-SecureAccess.ps1
    Silently installs Secure Access Client via MSI and configures NMS address.

.DESCRIPTION
    - Designed for Hybrid Join / Autopilot environments
    - Runs AFTER Autopilot completes (assign to device group, not ESP)
    - Logs ONLY on failure to C:\IntuneAppLogs\SecureAccess_Install.txt
    - MSI verbose log created during install, deleted on success, kept on failure
    - 10-minute timeout on MSI installation
    - 15-second mandatory wait after MSI before configuration (service stabilization)
    - Additional wait for client readiness (tellmes.exe + nmclient.exe)
    - Retry logic for configuration step (3 attempts)
    - Returns 3010 for Intune soft reboot handling
    - Creates marker file to track successful configuration

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-SecureAccess.ps1
    
    INTUNE SETTINGS FOR FORCED REBOOT:
    - Device restart behavior: "Intune will force a mandatory device restart"
    - Return Codes: Add 1641 as "Hard reboot" type
    - Grace period: Configure in "End user experience" section (e.g., 60 minutes)
    
    This script returns 1641 on success to trigger Intune-managed FORCED reboot.
    The device will restart after the configured grace period expires.
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application display name (used in logging)
$AppName = "SecureAccess"

# MSI installer filename (must be in same folder as this script)
$MsiFileName = "SecureAccess_client_14.10_x64_release.msi"

# NMS (Network Management Server) address for tellmes.exe configuration
$NmsAddress = "75.131.187.249"

# Log folder location (standard for Intune deployments)
$LogFolder = "C:\IntuneAppLogs"

# Installation timeout in seconds (600 = 10 minutes)
$TimeoutSeconds = 600

# Mandatory wait time (seconds) after MSI completes before attempting configuration
# This allows services and drivers to fully initialize
$PostInstallWaitSeconds = 15

# Maximum time (seconds) to wait for client readiness after post-install wait
$ClientReadyTimeoutSeconds = 300

# Number of retry attempts for the configuration step
$ConfigRetryAttempts = 3

# Delay between configuration retry attempts (seconds)
$ConfigRetryDelaySeconds = 10

# Marker file location (used for detection and to prevent re-configuration)
$MarkerDir = "C:\ProgramData\SecureAccess"
$MarkerFile = Join-Path -Path $MarkerDir -ChildPath "Configured.marker"

# Installation paths (where Secure Access installs)
$InstallDir = "C:\Program Files\Secure Access Client"
$TellmesExePath = Join-Path -Path $InstallDir -ChildPath "tellmes.exe"
$NmclientExePath = Join-Path -Path $InstallDir -ChildPath "nmclient.exe"

#================================================================================
# RETURN CODES - INTUNE HANDLING
#================================================================================

# Success code that triggers Intune HARD reboot (forced restart)
# IMPORTANT: Configure this in Intune Win32 app return codes as "Hard reboot"
# 1641 = Installer initiated reboot - Intune will force restart
# 3010 = Soft reboot (user prompted, can delay) - use this if you want soft reboot instead
$RC_REBOOT_REQUIRED = 1641

#================================================================================
# CUSTOM ERROR CODES - INTUNE-FRIENDLY, RESEARCHABLE VALUES
#================================================================================

# MSI-related errors (730xx range)
$ERR_MSI_NOT_FOUND       = 73001  # MSI file not in package
$ERR_MSIEXEC_NOT_FOUND   = 73002  # msiexec.exe missing (corrupt OS)
$ERR_MSI_START_FAILED    = 73003  # Could not start msiexec process
$ERR_MSI_TIMEOUT         = 73004  # MSI installation timed out
$ERR_MSI_FAILED          = 73005  # MSI returned failure exit code
$ERR_MSI_MUTEX_TIMEOUT   = 73006  # Waited too long for MSI mutex

# Client readiness errors (731xx range)
$ERR_CLIENT_NOT_READY    = 73101  # Client files not present after timeout
$ERR_TELLMES_NOT_FOUND   = 73102  # tellmes.exe not found

# Configuration errors (732xx range)
$ERR_CONFIG_START_FAILED = 73201  # Could not start tellmes.exe
$ERR_CONFIG_TIMEOUT      = 73202  # Configuration process timed out
$ERR_CONFIG_FAILED       = 73203  # tellmes.exe returned non-zero after all retries
$ERR_MARKER_FAILED       = 73204  # Failed to write marker file

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
# ALLUSERS=1 = install for all users (required for system context)
# /qn = completely silent, no UI
# /norestart = prevent automatic reboot (we return 3010 for Intune to handle)
# /l*v = verbose logging
$MsiArguments = "/i `"$MsiPath`" ALLUSERS=1 /qn /norestart /l*v `"$MsiLogFile`""

#--------------------------------------------------------------------------------
# FUNCTION: Initialize-ErrorLog
# PURPOSE:  Creates the log folder and log file ONLY when an error occurs.
# NOTES:    Creates folder first, then file separately (never same line).
#--------------------------------------------------------------------------------
function Initialize-ErrorLog {
    # Check if log folder exists; create if missing
    if (-not (Test-Path -Path $LogFolder -PathType Container)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    
    # Check if log file exists; create if missing (separate step)
    if (-not (Test-Path -Path $LogFile -PathType Leaf)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Write-ErrorLog
# PURPOSE:  Writes a timestamped error message to the log file.
# PARAMS:   Message - The error message to record
#           ExitCode - The exit code associated with this error
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
# NOTES:    MSI log is preserved on failure for troubleshooting.
#--------------------------------------------------------------------------------
function Exit-WithError {
    param(
        [Parameter(Mandatory)]
        [int]$ExitCode,
        
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    Write-ErrorLog -Message $Message -ExitCode $ExitCode
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Exit-WithReboot
# PURPOSE:  Cleans up MSI log file and exits with 1641 for Intune forced reboot.
# NOTES:    MSI verbose log is deleted on success.
#           Returns 1641 which Intune interprets as "hard reboot required".
#           Device will be forced to restart after grace period.
#--------------------------------------------------------------------------------
function Exit-WithReboot {
    # Delete MSI verbose log on success
    if (Test-Path -Path $MsiLogFile -PathType Leaf) {
        Remove-Item -Path $MsiLogFile -Force -ErrorAction SilentlyContinue
    }
    
    # Exit with 3010 - Intune will handle the reboot based on app settings
    exit $RC_REBOOT_REQUIRED
}

#--------------------------------------------------------------------------------
# FUNCTION: Test-MsiMutexAvailable
# PURPOSE:  Checks if the Windows Installer mutex is available.
# RETURNS:  $true if available (no other MSI running), $false if locked.
# NOTES:    Helps avoid 1618 errors by waiting for other installs to complete.
#--------------------------------------------------------------------------------
function Test-MsiMutexAvailable {
    $mutexName = "Global\_MSIExecute"
    $mutex = $null
    
    try {
        # Try to open existing mutex (don't create new one)
        $mutex = [System.Threading.Mutex]::OpenExisting($mutexName)
        
        # If we got here, mutex exists - try to acquire it briefly
        $acquired = $mutex.WaitOne(0)
        
        if ($acquired) {
            # We got it - release immediately and report available
            $mutex.ReleaseMutex()
            return $true
        }
        else {
            # Mutex is held by another process
            return $false
        }
    }
    catch [System.Threading.WaitHandleCannotBeOpenedException] {
        # Mutex doesn't exist - no MSI is running
        return $true
    }
    catch {
        # Other error - assume available and let MSI handle it
        return $true
    }
    finally {
        if ($mutex) {
            $mutex.Dispose()
        }
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Wait-ForMsiMutex
# PURPOSE:  Waits for the MSI mutex to become available.
# PARAMS:   TimeoutSeconds - Maximum time to wait
# RETURNS:  $true if mutex became available, $false if timeout.
# NOTES:    Prevents 1618 errors by ensuring no other MSI is running.
#--------------------------------------------------------------------------------
function Wait-ForMsiMutex {
    param(
        [int]$TimeoutSeconds = 300
    )
    
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $deadline) {
        if (Test-MsiMutexAvailable) {
            return $true
        }
        
        # Wait before checking again
        Start-Sleep -Seconds 5
    }
    
    return $false
}

#--------------------------------------------------------------------------------
# FUNCTION: Test-ClientReady
# PURPOSE:  Checks if the Secure Access client files are present.
# RETURNS:  $true if both tellmes.exe and nmclient.exe exist.
# NOTES:    Indicates MSI extraction and file deployment completed.
#--------------------------------------------------------------------------------
function Test-ClientReady {
    # Both executables must exist for client to be considered ready
    $tellmesExists = Test-Path -Path $TellmesExePath -PathType Leaf
    $nmclientExists = Test-Path -Path $NmclientExePath -PathType Leaf
    
    return ($tellmesExists -and $nmclientExists)
}

#--------------------------------------------------------------------------------
# FUNCTION: Wait-ForClientReady
# PURPOSE:  Waits for client files to appear after MSI installation.
# PARAMS:   TimeoutSeconds - Maximum time to wait
# RETURNS:  $true if client became ready, $false if timeout.
#--------------------------------------------------------------------------------
function Wait-ForClientReady {
    param(
        [int]$TimeoutSeconds = 300
    )
    
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $deadline) {
        if (Test-ClientReady) {
            return $true
        }
        
        # Poll every 5 seconds
        Start-Sleep -Seconds 5
    }
    
    return $false
}

#--------------------------------------------------------------------------------
# FUNCTION: Invoke-MsiInstall
# PURPOSE:  Executes the MSI installation with timeout protection.
# RETURNS:  MSI exit code if successful.
# NOTES:    Exits script directly on failure (does not return).
#--------------------------------------------------------------------------------
function Invoke-MsiInstall {
    # Start the MSI installation process
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
    $ProcessCompleted = $InstallProcess.WaitForExit($TimeoutSeconds * 1000)
    
    # Handle timeout scenario
    if (-not $ProcessCompleted) {
        try {
            $InstallProcess.Kill()
        }
        catch {
            # Ignore kill errors
        }
        
        Exit-WithError -ExitCode $ERR_MSI_TIMEOUT -Message "MSI installation timed out after $TimeoutSeconds seconds."
    }
    
    return $InstallProcess.ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Invoke-NmsConfiguration
# PURPOSE:  Runs tellmes.exe to configure the NMS address.
# PARAMS:   AttemptNumber - Current attempt number (for logging)
# RETURNS:  Exit code from tellmes.exe
# NOTES:    Has its own timeout protection.
#--------------------------------------------------------------------------------
function Invoke-NmsConfiguration {
    param(
        [int]$AttemptNumber = 1
    )
    
    # Verify tellmes.exe exists
    if (-not (Test-Path -Path $TellmesExePath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_TELLMES_NOT_FOUND -Message "tellmes.exe not found at: $TellmesExePath"
    }
    
    # Build arguments as array to avoid parsing issues
    $ConfigArgs = @("--nms-address", $NmsAddress)
    
    # Start configuration process
    try {
        $ConfigProcess = Start-Process -FilePath $TellmesExePath `
                                       -ArgumentList $ConfigArgs `
                                       -PassThru `
                                       -WindowStyle Hidden `
                                       -ErrorAction Stop
    }
    catch {
        Exit-WithError -ExitCode $ERR_CONFIG_START_FAILED -Message "Failed to start tellmes.exe (attempt $AttemptNumber): $($_.Exception.Message)"
    }
    
    # Wait for configuration to complete (60 second timeout per attempt)
    $ProcessCompleted = $ConfigProcess.WaitForExit(60000)
    
    if (-not $ProcessCompleted) {
        try {
            $ConfigProcess.Kill()
        }
        catch {
            # Ignore kill errors
        }
        
        # Return a failure code to trigger retry, don't exit yet
        return -1
    }
    
    return $ConfigProcess.ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Write-MarkerFile
# PURPOSE:  Creates the marker file indicating successful configuration.
# RETURNS:  $true if marker written successfully, $false otherwise.
# NOTES:    Marker file is used for detection and to prevent re-runs.
#--------------------------------------------------------------------------------
function Write-MarkerFile {
    try {
        # Create marker directory if needed
        if (-not (Test-Path -Path $MarkerDir -PathType Container)) {
            New-Item -Path $MarkerDir -ItemType Directory -Force | Out-Null
        }
        
        # Build marker content with configuration details
        $MarkerContent = @(
            "ConfiguredDate=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "NmsAddress=$NmsAddress"
            "InstallerVersion=$MsiFileName"
            "ScriptVersion=2.0"
        ) -join "`r`n"
        
        # Write marker file
        Set-Content -Path $MarkerFile -Value $MarkerContent -Encoding ASCII -Force
        
        return $true
    }
    catch {
        return $false
    }
}

#================================================================================
# MAIN INSTALLATION LOGIC
#================================================================================

# STEP 1: Check if already configured (marker file exists)
#         If so, exit success - no work needed
if (Test-Path -Path $MarkerFile -PathType Leaf) {
    # Already configured from previous run
    # Return 0 (not 3010) since reboot already happened
    exit 0
}

# STEP 2: Verify the MSI installer file exists in the script directory
if (-not (Test-Path -Path $MsiPath -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_MSI_NOT_FOUND -Message "MSI installer not found at path: $MsiPath"
}

# STEP 3: Verify msiexec.exe is available
if (-not (Test-Path -Path $MsiExecPath -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_MSIEXEC_NOT_FOUND -Message "msiexec.exe not found at: $MsiExecPath"
}

# STEP 4: Ensure log folder exists for MSI verbose logging
if (-not (Test-Path -Path $LogFolder -PathType Container)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# STEP 5: Wait for MSI mutex to be available (prevent 1618 errors)
#         This is a key reliability improvement - waits for other installs to finish
$MutexAvailable = Wait-ForMsiMutex -TimeoutSeconds 300

if (-not $MutexAvailable) {
    Exit-WithError -ExitCode $ERR_MSI_MUTEX_TIMEOUT -Message "Timed out waiting for MSI mutex. Another installation may be stuck."
}

# STEP 6: Execute the MSI installation with timeout
$MsiExitCode = Invoke-MsiInstall

# STEP 7: Evaluate the MSI exit code
switch ($MsiExitCode) {
    # SUCCESS CODES - Continue to configuration
    0       { }  # Standard success
    3010    { }  # Success, reboot needed (we'll return this at the end)
    1641    { }  # Success, reboot initiated (shouldn't happen with /norestart)
    
    # FAILURE CODES
    1618    { Exit-WithError -ExitCode 1618 -Message "Another installation is in progress (MSI 1618). See ${AppName}_MSI.log" }
    1619    { Exit-WithError -ExitCode 1619 -Message "MSI package could not be opened. File may be corrupt." }
    1620    { Exit-WithError -ExitCode 1620 -Message "MSI package path is invalid: $MsiPath" }
    1603    { Exit-WithError -ExitCode 1603 -Message "Fatal error during installation (MSI 1603). See ${AppName}_MSI.log" }
    1602    { Exit-WithError -ExitCode 1602 -Message "Installation was cancelled (MSI 1602)." }
    1601    { Exit-WithError -ExitCode 1601 -Message "Windows Installer service not accessible (MSI 1601)." }
    default { Exit-WithError -ExitCode $ERR_MSI_FAILED -Message "MSI failed with exit code: $MsiExitCode. See ${AppName}_MSI.log" }
}

# STEP 8: MANDATORY POST-INSTALL WAIT
#         This is critical - allows services and drivers to initialize
#         15 seconds as requested (between 10-15)
Start-Sleep -Seconds $PostInstallWaitSeconds

# STEP 9: Wait for client files to be ready
#         Polls for tellmes.exe and nmclient.exe existence
$ClientReady = Wait-ForClientReady -TimeoutSeconds $ClientReadyTimeoutSeconds

if (-not $ClientReady) {
    Exit-WithError -ExitCode $ERR_CLIENT_NOT_READY -Message "Client files not ready after $ClientReadyTimeoutSeconds seconds. tellmes.exe or nmclient.exe not found."
}

# STEP 10: Execute NMS configuration with retry logic
#          Retries help handle transient failures (service not fully started, etc.)
$ConfigSuccess = $false
$LastConfigExitCode = -1

for ($Attempt = 1; $Attempt -le $ConfigRetryAttempts; $Attempt++) {
    $LastConfigExitCode = Invoke-NmsConfiguration -AttemptNumber $Attempt
    
    if ($LastConfigExitCode -eq 0) {
        $ConfigSuccess = $true
        break
    }
    
    # If not the last attempt, wait before retrying
    if ($Attempt -lt $ConfigRetryAttempts) {
        Start-Sleep -Seconds $ConfigRetryDelaySeconds
    }
}

if (-not $ConfigSuccess) {
    Exit-WithError -ExitCode $ERR_CONFIG_FAILED -Message "NMS configuration failed after $ConfigRetryAttempts attempts. Last exit code: $LastConfigExitCode. Command: tellmes.exe --nms-address $NmsAddress"
}

# STEP 11: Write marker file to indicate successful configuration
$MarkerWritten = Write-MarkerFile

if (-not $MarkerWritten) {
    Exit-WithError -ExitCode $ERR_MARKER_FAILED -Message "Configuration succeeded but failed to write marker file: $MarkerFile"
}

# STEP 12: All steps completed successfully
#          Return 3010 to trigger Intune-managed reboot
Exit-WithReboot
