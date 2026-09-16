<# 
.SYNOPSIS
    Uninstall-AxonFleetDashboard.ps1
    Silently uninstalls Axon Fleet Dashboard via MSI for Intune Win32 deployment.

.DESCRIPTION
    - Designed for Hybrid Join / Autopilot environments
    - Logs ONLY on failure to C:\IntuneAppLogs\AxonFleetDashboard_Uninstall.txt
    - MSI verbose log created during uninstall, deleted on success, kept on failure
    - 10-minute timeout prevents indefinite hangs
    - Uses msiexec.exe /x with Product Code for reliable removal
    - Automatically finds Product Code from registry if not hardcoded
    - If application is not installed, exits success (nothing to uninstall)

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-AxonFleetDashboard.ps1
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application display name (used in logging and registry search)
$AppName = "AxonFleetDashboard"

# Display name as it appears in Programs and Features / Apps & Features
# Used to search registry for Product Code
# Supports wildcards: "Axon*Fleet*" or exact match: "Axon Fleet Dashboard"
$DisplayName = "Axon Fleet Dashboard"

# MSI Product Code (GUID format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX})
# If left as placeholder, script will search registry using DisplayName above
# To find Product Code after manual install, run:
#   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
#   Where-Object { $_.DisplayName -like "*Axon*Fleet*" } | Select DisplayName, PSChildName
$ProductCode = "{YOUR-PRODUCT-CODE-HERE}"

# Log folder location (standard for Intune deployments)
$LogFolder = "C:\IntuneAppLogs"

# Uninstallation timeout in seconds (600 = 10 minutes)
# If MSI takes longer than this, it will be terminated and marked as failed
$TimeoutSeconds = 600

#================================================================================
# END CONFIGURATION SECTION - DO NOT MODIFY BELOW UNLESS NECESSARY
#================================================================================

# Build log file paths using required naming schema
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Uninstall.txt"
$MsiLogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Uninstall_MSI.log"

# Build msiexec path
$MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\msiexec.exe"

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
# FUNCTION: Get-InstalledProductCode
# PURPOSE:  Searches the Windows registry to find the MSI Product Code.
# PARAMS:   Name - Display name to search for (supports wildcards)
# RETURNS:  Product Code string (GUID) if found, $null if not found.
# NOTES:    Checks both 64-bit and 32-bit registry locations.
#           This is more reliable than using Win32_Product WMI class,
#           which is slow and can trigger MSI self-repairs.
#--------------------------------------------------------------------------------
function Get-InstalledProductCode {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    # Registry paths where installed programs are listed
    # Must check both 64-bit and 32-bit (WOW6432Node) locations
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    # Search each registry path for matching display name
    foreach ($Path in $RegistryPaths) {
        try {
            $Found = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | 
                     Where-Object { $_.DisplayName -like "*$Name*" } |
                     Select-Object -First 1
            
            # Verify we found something and it has a valid GUID as its key name
            if ($Found -and $Found.PSChildName -match '^\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\}$') {
                # Return the Product Code (registry key name is the GUID)
                return $Found.PSChildName
            }
        }
        catch {
            # If registry access fails, continue to next path
            continue
        }
    }
    
    # Not found in any registry location
    return $null
}

#================================================================================
# MAIN UNINSTALLATION LOGIC
#================================================================================

# STEP 1: Determine the Product Code to use for uninstall
#         First check if a valid Product Code was provided in configuration
#         If not, search the registry using the DisplayName

$UninstallProductCode = $null

# Check if a valid Product Code was hardcoded in configuration section
if ($ProductCode -ne "{YOUR-PRODUCT-CODE-HERE}" -and 
    $ProductCode -match '^\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\}$') {
    # Valid GUID provided; use it
    $UninstallProductCode = $ProductCode
}
else {
    # No valid Product Code configured; search registry using DisplayName
    $UninstallProductCode = Get-InstalledProductCode -Name $DisplayName
}

# STEP 2: If no Product Code found, application is not installed
#         This is not an error - exit success (nothing to uninstall)
if (-not $UninstallProductCode) {
    # Application not found in registry; already uninstalled or never installed
    # Exit success so Intune marks uninstall as complete
    exit 0
}

# STEP 3: Verify msiexec.exe is available (should always exist on Windows)
if (-not (Test-Path -Path $MsiExecPath -PathType Leaf)) {
    Exit-WithError -ExitCode 3 -Message "msiexec.exe not found at: $MsiExecPath"
}

# STEP 4: Ensure log folder exists for MSI verbose logging
#         MSI needs this folder to exist before it can write the log
if (-not (Test-Path -Path $LogFolder -PathType Container)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# STEP 5: Build the msiexec uninstall command arguments
#         /x = uninstall using Product Code
#         /qn = completely silent, no UI
#         /norestart = prevent automatic reboot
#         /l*v = verbose logging to specified file (deleted on success)
$MsiArguments = "/x $UninstallProductCode /qn /norestart /l*v `"$MsiLogFile`""

# STEP 6: Execute the MSI uninstallation
#         -PassThru returns the process object so we can monitor it
#         -WindowStyle Hidden prevents any UI flash
#         Note: We do NOT use -Wait here because we need to implement timeout
try {
    $UninstallProcess = Start-Process -FilePath $MsiExecPath `
                                      -ArgumentList $MsiArguments `
                                      -PassThru `
                                      -WindowStyle Hidden `
                                      -ErrorAction Stop
}
catch {
    # Catch any PowerShell-level errors (process couldn't start, access denied, etc.)
    Exit-WithError -ExitCode 1 -Message "Failed to start msiexec.exe: $($_.Exception.Message)"
}

# STEP 7: Wait for process to complete with timeout
#         WaitForExit returns $true if process exited, $false if timeout reached
#         Timeout is in milliseconds, so multiply seconds by 1000
$ProcessCompleted = $UninstallProcess.WaitForExit($TimeoutSeconds * 1000)

# STEP 8: Handle timeout scenario
#         If process did not complete within timeout, kill it and fail
if (-not $ProcessCompleted) {
    # Attempt to kill the hung process
    try {
        $UninstallProcess.Kill()
    }
    catch {
        # Process may have exited between check and kill attempt; ignore error
    }
    
    Exit-WithError -ExitCode 258 -Message "Uninstallation timed out after $TimeoutSeconds seconds. Process was terminated."
}

# STEP 9: Evaluate the MSI exit code
#         Standard MSI exit codes: https://docs.microsoft.com/en-us/windows/win32/msi/error-codes
$MsiExitCode = $UninstallProcess.ExitCode

switch ($MsiExitCode) {
    # SUCCESS CODES - Clean up MSI log and exit 0
    0       { Exit-WithSuccess }  # Standard success
    3010    { Exit-WithSuccess }  # Success, reboot would be needed (ignored per requirements)
    1641    { Exit-WithSuccess }  # Success, reboot was requested (ignored per requirements)
    1605    { Exit-WithSuccess }  # Product not installed (already removed; this is success for uninstall)
    
    # FAILURE CODES - Log error, preserve MSI log, exit with MSI code
    1618    { Exit-WithError -ExitCode 1618 -Message "Another installation/uninstallation is in progress. MSI mutex locked." }
    1619    { Exit-WithError -ExitCode 1619 -Message "MSI package could not be accessed for uninstall." }
    1603    { Exit-WithError -ExitCode 1603 -Message "Fatal error during uninstallation (MSI 1603). See ${AppName}_Uninstall_MSI.log for details." }
    1602    { Exit-WithError -ExitCode 1602 -Message "Uninstallation was cancelled (MSI 1602)." }
    1601    { Exit-WithError -ExitCode 1601 -Message "Windows Installer service is not accessible (MSI 1601)." }
    default { Exit-WithError -ExitCode $MsiExitCode -Message "MSI uninstallation failed with unexpected exit code. See ${AppName}_Uninstall_MSI.log for details." }
}
