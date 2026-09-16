<#
.SYNOPSIS
    Install-EVReachClient.ps1

.DESCRIPTION
    Installs EV Reach Client (formerly Goverlan Reach Client) using the MSI installer.
    
    - Silent MSI installation using msiexec
    - Validates installation by checking for GovAgentx64.exe
    - Logs ONLY on error to C:\IntuneAppLogs\EVReachClient_Install.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-EVReachClient.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-EVReachClient.ps1
    Install behavior: System
    Device restart behavior: No specific action
    
    PACKAGE CONTENTS:
    EVReachClient\
    ├── Install-EVReachClient.ps1
    ├── Uninstall-EVReachClient.ps1
    ├── Detect-EVReachClient.ps1
    └── EVReachClient64.msi
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION - Modify these variables for your deployment
# =============================================================================

# Application name (used for logging)
$AppName = "EVReachClient"

# MSI installer filename - must match the file in the Win32 app package
$InstallerName = "EVReachClient64.msi"

# MSI installation parameters
# /qn = Quiet mode, no UI
# /norestart = Suppress restart (Intune handles restarts)
# ALLUSERS=1 = Install for all users (per-machine)
$MsiParameters = "/qn /norestart ALLUSERS=1"

# Timeout for installation (seconds)
$InstallationTimeoutSeconds = 300

# Detection paths - locations where EV Reach Client components are installed
# The client installs to "Program Files\Goverlan Inc\GoverlanAgent"
$DetectionPaths = @(
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgent.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgent.exe"
)

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# =============================================================================
# EXIT CODES
# =============================================================================

$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1
$EXIT_RETRY = 1618          # Another installation in progress

# Custom error codes
$ERR_INSTALLER_NOT_FOUND = 74001
$ERR_MSIEXEC_FAILED = 74002
$ERR_INSTALLER_TIMEOUT = 74003
$ERR_NOT_DETECTED = 74004

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Writes error information to the log file.
        Per requirements: logging only occurs when errors happen.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        # Step 1: Create log directory if needed
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 2: Create log file if needed (separate operation)
        if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 3: Write to log file
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $LogFilePath -Value "[$Timestamp] $Message" -ErrorAction Stop
    }
    catch {
        Write-Error "LOGGING FAILED: $Message"
    }
}

function Exit-WithError {
    <#
    .SYNOPSIS
        Logs detailed error information and exits with specified code.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$MsiExitCode = "",
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorCategory = "PROGRAM"
    )
    
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Category: $ErrorCategory"
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "Script Path: $PSCommandPath"
    Write-ErrorLog -Message "Installer: $InstallerName"
    Write-ErrorLog -Message "MSI Parameters: $MsiParameters"
    
    if ($MsiExitCode -ne "") {
        Write-ErrorLog -Message "MSI Exit Code: $MsiExitCode"
        
        # Decode common MSI exit codes for easier troubleshooting
        $MsiExitCodeMeaning = switch ($MsiExitCode) {
            "1603" { "Fatal error during installation" }
            "1618" { "Another installation is in progress" }
            "1619" { "Installation package could not be opened" }
            "1620" { "Installation package is invalid" }
            "1622" { "Error opening installation log file" }
            "1624" { "Error applying transforms" }
            "1625" { "Installation prohibited by system policy" }
            "1638" { "Another version of this product is already installed" }
            default { "See MSI documentation for details" }
        }
        Write-ErrorLog -Message "MSI Exit Code Meaning: $MsiExitCodeMeaning"
    }
    
    Write-ErrorLog -Message "Detection Paths Checked:"
    foreach ($Path in $DetectionPaths) {
        $Exists = Test-Path -LiteralPath $Path -PathType Leaf
        Write-ErrorLog -Message "  [$Exists] $Path"
    }
    
    Write-ErrorLog -Message "=========================================="
    
    Write-Error "[$ErrorCategory] ERROR $ExitCode : $Message"
    exit $ExitCode
}

function Test-EVReachInstalled {
    <#
    .SYNOPSIS
        Checks if EV Reach Client is installed by verifying file existence.
    #>
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

# =============================================================================
# PRE-EXECUTION: Ensure 64-bit PowerShell
# =============================================================================

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    
    if (Test-Path -LiteralPath $SysNativePowerShell -PathType Leaf) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePowerShell -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

# =============================================================================
# MAIN SCRIPT EXECUTION
# =============================================================================

try {
    # -------------------------------------------------------------------------
    # STEP 1: Check if already installed (idempotent)
    # -------------------------------------------------------------------------
    
    if (Test-EVReachInstalled) {
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Locate the MSI installer in the package
    # -------------------------------------------------------------------------
    
    $InstallerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerName
    
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_INSTALLER_NOT_FOUND `
                       -Message "MSI installer not found: '$InstallerPath'. Ensure '$InstallerName' is included in the .intunewin package." `
                       -ErrorCategory "INTUNE"
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Execute MSI installation using msiexec
    # -------------------------------------------------------------------------
    
    try {
        $MsiExecPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msiexec.exe"
        
        # Build the argument list for msiexec
        # /i = Install
        # /L*v = Verbose logging (to temp for troubleshooting if needed)
        $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI_Install.log"
        $MsiArguments = "/i `"$InstallerPath`" $MsiParameters /L*v `"$MsiLogPath`""
        
        $ProcessStartInfo = @{
            FilePath     = $MsiExecPath
            ArgumentList = $MsiArguments
            PassThru     = $true
            Wait         = $false
            WindowStyle  = "Hidden"
            ErrorAction  = "Stop"
        }
        
        $MsiProcess = Start-Process @ProcessStartInfo
        
        # Wait for MSI to complete with timeout
        $ProcessCompleted = $MsiProcess.WaitForExit($InstallationTimeoutSeconds * 1000)
        
        if (-not $ProcessCompleted) {
            try { $MsiProcess.Kill() } catch { }
            
            Exit-WithError -ExitCode $ERR_INSTALLER_TIMEOUT `
                           -Message "MSI installation timed out after $InstallationTimeoutSeconds seconds." `
                           -ErrorCategory "SYSTEM"
        }
        
        $MsiReturnCode = $MsiProcess.ExitCode
        
        # Check MSI return code
        # 0 = Success, 3010 = Success but reboot required
        if ($MsiReturnCode -notin @(0, 3010)) {
            Exit-WithError -ExitCode $ERR_MSIEXEC_FAILED `
                           -Message "MSI installation failed." `
                           -MsiExitCode $MsiReturnCode `
                           -ErrorCategory "PROGRAM"
        }
    }
    catch {
        Exit-WithError -ExitCode $ERR_MSIEXEC_FAILED `
                       -Message "Failed to execute msiexec: $($_.Exception.Message)" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Verify installation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 5
    
    if (-not (Test-EVReachInstalled)) {
        Exit-WithError -ExitCode $ERR_NOT_DETECTED `
                       -Message "MSI installation completed (exit code: $MsiReturnCode) but EV Reach Client was not detected." `
                       -MsiExitCode $MsiReturnCode `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Success
    # -------------------------------------------------------------------------
    
    # Return 3010 if MSI requested reboot, otherwise 0
    if ($MsiReturnCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    $ErrorMsg = "Unexpected error during installation: $($_.Exception.Message)"
    
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $ErrorMsg"
    Write-ErrorLog -Message "Exception Type: $($_.Exception.GetType().FullName)"
    Write-ErrorLog -Message "Stack Trace: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}
