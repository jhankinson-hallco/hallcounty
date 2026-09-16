<# 
.SYNOPSIS
    Uninstall-SecureAccess.ps1
    Silently uninstalls Secure Access Client via MSI for Intune Win32 deployment.

.DESCRIPTION
    - Designed for Hybrid Join / Autopilot environments
    - Logs ONLY on failure to C:\IntuneAppLogs\SecureAccess_Uninstall.txt
    - MSI verbose log created during uninstall, deleted on success, kept on failure
    - 10-minute timeout prevents indefinite hangs
    - Stops Secure Access services before uninstall (prevents file locks)
    - Uses msiexec.exe /x with Product Code for reliable removal
    - Automatically finds Product Code from registry if not hardcoded
    - Removes marker file and configuration data
    - If application is not installed, exits success (nothing to uninstall)

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-SecureAccess.ps1
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application display name (used in logging and registry search)
$AppName = "SecureAccess"

# Display name as it appears in Programs and Features / Apps & Features
# Used to search registry for Product Code
$DisplayName = "Secure Access"

# MSI Product Code (GUID format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX})
# If left as placeholder, script will search registry using DisplayName above
# To find Product Code after manual install, run:
#   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
#   Where-Object { $_.DisplayName -like "*Secure Access*" } | Select DisplayName, PSChildName
$ProductCode = "{YOUR-PRODUCT-CODE-HERE}"

# Log folder location (standard for Intune deployments)
$LogFolder = "C:\IntuneAppLogs"

# Uninstallation timeout in seconds (600 = 10 minutes)
$TimeoutSeconds = 600

# Service stop timeout in seconds
$ServiceStopTimeoutSeconds = 60

# Marker file and configuration data locations (to be cleaned up)
$MarkerDir = "C:\ProgramData\SecureAccess"
$MarkerFile = Join-Path -Path $MarkerDir -ChildPath "Configured.marker"

# Installation directory (for verification)
$InstallDir = "C:\Program Files\Secure Access Client"

# Known service names for Secure Access (add more if needed)
# Script will attempt to stop these before uninstall
$ServiceNames = @(
    "SecureAccessService",
    "SAService",
    "nmservice"
)

#================================================================================
# CUSTOM ERROR CODES - INTUNE-FRIENDLY, RESEARCHABLE VALUES
#================================================================================

# Uninstall-related errors (733xx range)
$ERR_MSIEXEC_NOT_FOUND   = 73301  # msiexec.exe missing (corrupt OS)
$ERR_MSI_START_FAILED    = 73302  # Could not start msiexec process
$ERR_MSI_TIMEOUT         = 73303  # MSI uninstallation timed out
$ERR_MSI_FAILED          = 73304  # MSI returned failure exit code
$ERR_SERVICE_STOP_FAILED = 73305  # Could not stop services (non-fatal warning)

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
# NOTES:    Creates folder first, then file separately (never same line).
#--------------------------------------------------------------------------------
function Initialize-ErrorLog {
    if (-not (Test-Path -Path $LogFolder -PathType Container)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    
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
    
    Initialize-ErrorLog
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [ERROR] $Message | ExitCode: $ExitCode"
    
    Add-Content -Path $LogFile -Value $LogEntry
}

#--------------------------------------------------------------------------------
# FUNCTION: Exit-WithError
# PURPOSE:  Logs the error and exits with the specified code.
# PARAMS:   ExitCode - Intune-compatible exit code to return
#           Message - Descriptive error message for troubleshooting
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
# FUNCTION: Exit-WithSuccess
# PURPOSE:  Cleans up MSI log file and exits with code 0.
# NOTES:    MSI verbose log is deleted on success.
#--------------------------------------------------------------------------------
function Exit-WithSuccess {
    if (Test-Path -Path $MsiLogFile -PathType Leaf) {
        Remove-Item -Path $MsiLogFile -Force -ErrorAction SilentlyContinue
    }
    
    exit 0
}

#--------------------------------------------------------------------------------
# FUNCTION: Get-InstalledProductCode
# PURPOSE:  Searches the Windows registry to find the MSI Product Code.
# PARAMS:   Name - Display name to search for (partial match supported)
# RETURNS:  Product Code string (GUID) if found, $null if not found.
#--------------------------------------------------------------------------------
function Get-InstalledProductCode {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($Path in $RegistryPaths) {
        try {
            $Found = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | 
                     Where-Object { $_.DisplayName -like "*$Name*" } |
                     Select-Object -First 1
            
            if ($Found -and $Found.PSChildName -match '^\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\}$') {
                return $Found.PSChildName
            }
        }
        catch {
            continue
        }
    }
    
    return $null
}

#--------------------------------------------------------------------------------
# FUNCTION: Stop-SecureAccessServices
# PURPOSE:  Attempts to stop all known Secure Access services.
# NOTES:    Non-fatal if services don't exist or can't be stopped.
#           Helps prevent file locks during uninstall.
#--------------------------------------------------------------------------------
function Stop-SecureAccessServices {
    foreach ($ServiceName in $ServiceNames) {
        try {
            $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            
            if ($Service -and $Service.Status -eq 'Running') {
                # Attempt to stop the service
                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                
                # Wait for service to stop
                $Service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds($ServiceStopTimeoutSeconds))
            }
        }
        catch {
            # Service stop failed - continue anyway
            # The MSI uninstaller should handle this
        }
    }
    
    # Also try to stop any processes that might hold file locks
    $ProcessNames = @("nmclient", "tellmes", "SAClient")
    
    foreach ($ProcessName in $ProcessNames) {
        try {
            $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            
            foreach ($Process in $Processes) {
                $Process.Kill()
                $Process.WaitForExit(5000)
            }
        }
        catch {
            # Process kill failed - continue anyway
        }
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Remove-ConfigurationData
# PURPOSE:  Removes marker file and configuration directory.
# NOTES:    Called after successful MSI uninstall.
#           Non-fatal if files don't exist or can't be removed.
#--------------------------------------------------------------------------------
function Remove-ConfigurationData {
    # Remove marker file
    if (Test-Path -Path $MarkerFile -PathType Leaf) {
        Remove-Item -Path $MarkerFile -Force -ErrorAction SilentlyContinue
    }
    
    # Remove marker directory if empty
    if (Test-Path -Path $MarkerDir -PathType Container) {
        $Items = Get-ChildItem -Path $MarkerDir -ErrorAction SilentlyContinue
        
        if (-not $Items -or $Items.Count -eq 0) {
            Remove-Item -Path $MarkerDir -Force -ErrorAction SilentlyContinue
        }
    }
}

#================================================================================
# MAIN UNINSTALLATION LOGIC
#================================================================================

# STEP 1: Determine the Product Code to use for uninstall
$UninstallProductCode = $null

# Check if a valid Product Code was hardcoded
if ($ProductCode -ne "{YOUR-PRODUCT-CODE-HERE}" -and 
    $ProductCode -match '^\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\}$') {
    $UninstallProductCode = $ProductCode
}
else {
    # Search registry using DisplayName
    $UninstallProductCode = Get-InstalledProductCode -Name $DisplayName
}

# STEP 2: If no Product Code found, application is not installed
if (-not $UninstallProductCode) {
    # Also remove any leftover configuration data
    Remove-ConfigurationData
    
    # Exit success - nothing to uninstall
    exit 0
}

# STEP 3: Verify msiexec.exe is available
if (-not (Test-Path -Path $MsiExecPath -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_MSIEXEC_NOT_FOUND -Message "msiexec.exe not found at: $MsiExecPath"
}

# STEP 4: Ensure log folder exists for MSI verbose logging
if (-not (Test-Path -Path $LogFolder -PathType Container)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# STEP 5: Stop Secure Access services and processes
#         This helps prevent file locks during uninstall
Stop-SecureAccessServices

# Brief pause to ensure handles are released
Start-Sleep -Seconds 3

# STEP 6: Build the msiexec uninstall command arguments
$MsiArguments = "/x $UninstallProductCode /qn /norestart /l*v `"$MsiLogFile`""

# STEP 7: Execute the MSI uninstallation
try {
    $UninstallProcess = Start-Process -FilePath $MsiExecPath `
                                      -ArgumentList $MsiArguments `
                                      -PassThru `
                                      -WindowStyle Hidden `
                                      -ErrorAction Stop
}
catch {
    Exit-WithError -ExitCode $ERR_MSI_START_FAILED -Message "Failed to start msiexec.exe: $($_.Exception.Message)"
}

# STEP 8: Wait for process to complete with timeout
$ProcessCompleted = $UninstallProcess.WaitForExit($TimeoutSeconds * 1000)

# STEP 9: Handle timeout scenario
if (-not $ProcessCompleted) {
    try {
        $UninstallProcess.Kill()
    }
    catch {
        # Ignore kill errors
    }
    
    Exit-WithError -ExitCode $ERR_MSI_TIMEOUT -Message "Uninstallation timed out after $TimeoutSeconds seconds."
}

# STEP 10: Evaluate the MSI exit code
$MsiExitCode = $UninstallProcess.ExitCode

switch ($MsiExitCode) {
    # SUCCESS CODES
    0       { 
        Remove-ConfigurationData
        Exit-WithSuccess 
    }
    3010    { 
        Remove-ConfigurationData
        Exit-WithSuccess  # Don't return 3010 for uninstall
    }
    1641    { 
        Remove-ConfigurationData
        Exit-WithSuccess 
    }
    1605    { 
        # Product not installed - already removed
        Remove-ConfigurationData
        Exit-WithSuccess 
    }
    
    # FAILURE CODES
    1618    { Exit-WithError -ExitCode 1618 -Message "Another installation/uninstallation is in progress (MSI 1618)." }
    1619    { Exit-WithError -ExitCode 1619 -Message "MSI package could not be accessed for uninstall." }
    1603    { Exit-WithError -ExitCode 1603 -Message "Fatal error during uninstallation (MSI 1603). See ${AppName}_Uninstall_MSI.log" }
    1602    { Exit-WithError -ExitCode 1602 -Message "Uninstallation was cancelled (MSI 1602)." }
    1601    { Exit-WithError -ExitCode 1601 -Message "Windows Installer service not accessible (MSI 1601)." }
    default { Exit-WithError -ExitCode $ERR_MSI_FAILED -Message "MSI uninstallation failed with exit code: $MsiExitCode. See ${AppName}_Uninstall_MSI.log" }
}
