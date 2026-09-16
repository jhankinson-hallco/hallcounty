<#
.SYNOPSIS
    Install-GoogleChromeEnterprise.ps1

.DESCRIPTION
    Installs Google Chrome Enterprise (64-bit) using the standalone MSI installer.
    
    This script installs:
    - Google Chrome Enterprise (64-bit) - REQUIRED
    - Legacy Browser Support Extension (optional, enabled by default)
    - Endpoint Verification Extension (optional, disabled by default)
    
    Features:
    - Silent MSI installation
    - Suppresses automatic updates (manageable via policy)
    - Suppresses first-run dialogs
    - Validates installation by checking for chrome.exe
    - Logs ONLY on error to C:\IntuneAppLogs\GoogleChromeEnterprise_Install.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-GoogleChromeEnterprise.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleChromeEnterprise.ps1
    Install behavior: System
    Device restart behavior: No specific action
    
    PACKAGE CONTENTS:
    root:\
    ├── Configuration\           (ADMX templates, preferences, policies)
    ├── Documentation\           (README and documentation)
    ├── Installers\
    │   ├── GoogleChromeStandaloneEnterprise64.msi
    │   ├── LegacyBrowserSupport_8.1.0.0_en_x64.msi
    │   └── EndpointVerification_2.0.3.msi
    ├── Install-GoogleChromeEnterprise.ps1
    ├── Uninstall-GoogleChromeEnterprise.ps1
    ├── Detect.ps1
    └── VERSION.file
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION - Modify these variables for your deployment
# =============================================================================

# Application name (used for logging)
$AppName = "GoogleChromeEnterprise"

# ----- INSTALLER FILENAMES -----
# These must match the files in the Installers\ subfolder

# Main Chrome Enterprise MSI (REQUIRED)
$ChromeMsiName = "GoogleChromeStandaloneEnterprise64.msi"

# Legacy Browser Support Extension MSI (OPTIONAL)
$LegacyBrowserSupportMsiName = "LegacyBrowserSupport_8.1.0.0_en_x64.msi"

# Endpoint Verification Extension MSI (OPTIONAL)
$EndpointVerificationMsiName = "EndpointVerification_2.0.3.msi"

# ----- INSTALLATION OPTIONS -----
# Set to $true to install the component, $false to skip

# Install Legacy Browser Support extension (for IE/Edge Legacy compatibility)
$InstallLegacyBrowserSupport = $true

# Install Endpoint Verification extension (for Google BeyondCorp/Context-Aware Access)
$InstallEndpointVerification = $false

# ----- MSI PARAMETERS -----
# Standard silent install parameters for all MSI packages

# Chrome-specific MSI properties:
# - ALLUSERS=1: Install for all users (per-machine)
# - /qn: Silent install with no UI
# - /norestart: Suppress automatic restart
$ChromeMsiParameters = "ALLUSERS=1 /qn /norestart"

# Extension MSI parameters (standard silent)
$ExtensionMsiParameters = "/qn /norestart"

# Installation timeout per MSI (seconds)
$MsiTimeoutSeconds = 300

# ----- DETECTION PATHS -----
# Locations where chrome.exe may be installed (checked in order)
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

# =============================================================================
# LOGGING CONFIGURATION - Do not modify unless organizational standards change
# =============================================================================

$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# =============================================================================
# EXIT CODES - Standard Intune and custom error codes
# =============================================================================

$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1
$EXIT_RETRY = 1618              # Another installation in progress

# Custom error codes (76xxx range for Chrome)
$ERR_CHROME_MSI_NOT_FOUND = 76001
$ERR_CHROME_INSTALL_FAILED = 76002
$ERR_CHROME_INSTALL_TIMEOUT = 76003
$ERR_CHROME_NOT_DETECTED = 76004
$ERR_LBS_INSTALL_FAILED = 76005      # Legacy Browser Support
$ERR_EV_INSTALL_FAILED = 76006       # Endpoint Verification

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
        [string]$Component = "Chrome",
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorCategory = "PROGRAM"
    )
    
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Category: $ErrorCategory"
    Write-ErrorLog -Message "Component: $Component"
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "Script Path: $PSCommandPath"
    
    if ($MsiExitCode -ne "") {
        Write-ErrorLog -Message "MSI Exit Code: $MsiExitCode"
        
        # Decode common MSI exit codes
        $MsiExitCodeMeaning = switch ($MsiExitCode) {
            "1603" { "Fatal error during installation" }
            "1618" { "Another installation is in progress" }
            "1619" { "Installation package could not be opened" }
            "1620" { "Installation package is invalid" }
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

function Test-ChromeInstalled {
    <#
    .SYNOPSIS
        Checks if Google Chrome is installed by verifying file existence.
    #>
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Install-MsiPackage {
    <#
    .SYNOPSIS
        Installs an MSI package silently with timeout and error handling.
    
    .PARAMETER MsiPath
        Full path to the MSI file.
    
    .PARAMETER Parameters
        MSI command line parameters (e.g., "/qn /norestart").
    
    .PARAMETER ComponentName
        Name of the component for logging purposes.
    
    .OUTPUTS
        Returns the MSI exit code, or -1 if an error occurred.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsiPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Parameters,
        
        [Parameter(Mandatory = $true)]
        [string]$ComponentName
    )
    
    try {
        $MsiExecPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msiexec.exe"
        $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_${ComponentName}_Install.log"
        $MsiArguments = "/i `"$MsiPath`" $Parameters /L*v `"$MsiLogPath`""
        
        $ProcessStartInfo = @{
            FilePath     = $MsiExecPath
            ArgumentList = $MsiArguments
            PassThru     = $true
            Wait         = $false
            WindowStyle  = "Hidden"
            ErrorAction  = "Stop"
        }
        
        $MsiProcess = Start-Process @ProcessStartInfo
        $ProcessCompleted = $MsiProcess.WaitForExit($MsiTimeoutSeconds * 1000)
        
        if (-not $ProcessCompleted) {
            try { $MsiProcess.Kill() } catch { }
            return -999  # Timeout code
        }
        
        return $MsiProcess.ExitCode
    }
    catch {
        Write-ErrorLog -Message "Exception installing ${ComponentName}: $($_.Exception.Message)"
        return -1
    }
}

# =============================================================================
# PRE-EXECUTION: Ensure 64-bit PowerShell on 64-bit OS
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
    # STEP 1: Check if Chrome is already installed (idempotent)
    # -------------------------------------------------------------------------
    
    if (Test-ChromeInstalled) {
        # Already installed - exit success
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Build paths to installer files
    # -------------------------------------------------------------------------
    
    $InstallersFolder = Join-Path -Path $PSScriptRoot -ChildPath "Installers"
    $ChromeMsiPath = Join-Path -Path $InstallersFolder -ChildPath $ChromeMsiName
    $LbsMsiPath = Join-Path -Path $InstallersFolder -ChildPath $LegacyBrowserSupportMsiName
    $EvMsiPath = Join-Path -Path $InstallersFolder -ChildPath $EndpointVerificationMsiName
    
    # -------------------------------------------------------------------------
    # STEP 3: Verify Chrome MSI exists (required)
    # -------------------------------------------------------------------------
    
    if (-not (Test-Path -LiteralPath $ChromeMsiPath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_CHROME_MSI_NOT_FOUND `
                       -Message "Chrome MSI not found: '$ChromeMsiPath'. Ensure '$ChromeMsiName' exists in the Installers folder." `
                       -Component "Chrome" `
                       -ErrorCategory "INTUNE"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Install Google Chrome Enterprise
    # -------------------------------------------------------------------------
    
    $ChromeExitCode = Install-MsiPackage -MsiPath $ChromeMsiPath `
                                          -Parameters $ChromeMsiParameters `
                                          -ComponentName "Chrome"
    
    if ($ChromeExitCode -eq -999) {
        Exit-WithError -ExitCode $ERR_CHROME_INSTALL_TIMEOUT `
                       -Message "Chrome MSI installation timed out after $MsiTimeoutSeconds seconds." `
                       -Component "Chrome" `
                       -ErrorCategory "SYSTEM"
    }
    
    if ($ChromeExitCode -notin @(0, 3010)) {
        Exit-WithError -ExitCode $ERR_CHROME_INSTALL_FAILED `
                       -Message "Chrome MSI installation failed." `
                       -MsiExitCode $ChromeExitCode `
                       -Component "Chrome" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Verify Chrome installation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 3
    
    if (-not (Test-ChromeInstalled)) {
        Exit-WithError -ExitCode $ERR_CHROME_NOT_DETECTED `
                       -Message "Chrome MSI installation completed (exit code: $ChromeExitCode) but chrome.exe was not detected." `
                       -MsiExitCode $ChromeExitCode `
                       -Component "Chrome" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 6: Install Legacy Browser Support (optional)
    # -------------------------------------------------------------------------
    
    if ($InstallLegacyBrowserSupport) {
        if (Test-Path -LiteralPath $LbsMsiPath -PathType Leaf) {
            $LbsExitCode = Install-MsiPackage -MsiPath $LbsMsiPath `
                                              -Parameters $ExtensionMsiParameters `
                                              -ComponentName "LegacyBrowserSupport"
            
            # Log warning if LBS fails, but don't fail the entire installation
            # Chrome is already installed at this point
            if ($LbsExitCode -notin @(0, 3010)) {
                Write-ErrorLog -Message "WARNING: Legacy Browser Support installation failed (exit code: $LbsExitCode). Chrome installation will continue."
            }
        }
        else {
            Write-ErrorLog -Message "WARNING: Legacy Browser Support MSI not found at '$LbsMsiPath'. Skipping."
        }
    }
    
    # -------------------------------------------------------------------------
    # STEP 7: Install Endpoint Verification (optional)
    # -------------------------------------------------------------------------
    
    if ($InstallEndpointVerification) {
        if (Test-Path -LiteralPath $EvMsiPath -PathType Leaf) {
            $EvExitCode = Install-MsiPackage -MsiPath $EvMsiPath `
                                             -Parameters $ExtensionMsiParameters `
                                             -ComponentName "EndpointVerification"
            
            # Log warning if EV fails, but don't fail the entire installation
            if ($EvExitCode -notin @(0, 3010)) {
                Write-ErrorLog -Message "WARNING: Endpoint Verification installation failed (exit code: $EvExitCode). Chrome installation will continue."
            }
        }
        else {
            Write-ErrorLog -Message "WARNING: Endpoint Verification MSI not found at '$EvMsiPath'. Skipping."
        }
    }
    
    # -------------------------------------------------------------------------
    # STEP 8: Success
    # -------------------------------------------------------------------------
    
    # Return 3010 if Chrome MSI requested reboot, otherwise 0
    if ($ChromeExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    # -------------------------------------------------------------------------
    # CATCH BLOCK: Handle any unexpected errors
    # -------------------------------------------------------------------------
    
    $ErrorMsg = "Unexpected error during installation: $($_.Exception.Message)"
    
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $ErrorMsg"
    Write-ErrorLog -Message "Exception Type: $($_.Exception.GetType().FullName)"
    Write-ErrorLog -Message "Stack Trace: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}
