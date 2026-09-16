<#
.SYNOPSIS
    Uninstall-GoogleChromeEnterprise.ps1

.DESCRIPTION
    Uninstalls Google Chrome Enterprise and optional components.
    
    This script removes:
    - Google Chrome Enterprise (64-bit or 32-bit)
    - Legacy Browser Support Extension (if installed)
    - Endpoint Verification Extension (if installed)
    
    The script searches the registry to find the correct product codes,
    allowing it to work across different Chrome versions.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleChromeEnterprise.ps1
    Install behavior: System
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Application name (used for logging)
$AppName = "GoogleChromeEnterprise"

# Product display names to search for in registry
# These are used to find the product codes for uninstallation

# Chrome browser names (search matches any of these)
$ChromeDisplayNames = @(
    "Google Chrome"
)

# Legacy Browser Support names
$LegacyBrowserSupportDisplayNames = @(
    "Legacy Browser Support",
    "Google Chrome Legacy Browser Support"
)

# Endpoint Verification names
$EndpointVerificationDisplayNames = @(
    "Endpoint Verification",
    "Google Endpoint Verification"
)

# ----- UNINSTALLATION OPTIONS -----
# Set to $true to uninstall the component, $false to leave it

$UninstallLegacyBrowserSupport = $true
$UninstallEndpointVerification = $true

# MSI uninstall parameters
$MsiUninstallParameters = "/qn /norestart"

# Uninstall timeout per MSI (seconds)
$MsiTimeoutSeconds = 300

# Detection paths (to verify uninstallation)
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Uninstall.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# =============================================================================
# EXIT CODES
# =============================================================================

$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

# Custom error codes
$ERR_CHROME_NOT_FOUND = 76010
$ERR_CHROME_UNINSTALL_FAILED = 76011
$ERR_CHROME_UNINSTALL_TIMEOUT = 76012
$ERR_CHROME_STILL_DETECTED = 76013

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

function Write-ErrorLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $LogFilePath -Value "[$Timestamp] $Message" -ErrorAction Stop
    }
    catch {
        Write-Error "LOGGING FAILED: $Message"
    }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$MsiExitCode = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "Chrome"
    )
    
    Write-ErrorLog -Message "========== UNINSTALLATION FAILED =========="
    Write-ErrorLog -Message "Component: $Component"
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    
    if ($MsiExitCode -ne "") {
        Write-ErrorLog -Message "MSI Exit Code: $MsiExitCode"
    }
    
    Write-ErrorLog -Message "============================================="
    
    Write-Error "ERROR $ExitCode : $Message"
    exit $ExitCode
}

function Get-ProductCodeFromRegistry {
    <#
    .SYNOPSIS
        Searches the registry for a product matching the display name.
    
    .PARAMETER DisplayNames
        Array of display names to search for.
    
    .OUTPUTS
        Returns the product code (GUID) if found, or $null if not found.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DisplayNames
    )
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path -LiteralPath $RegPath) {
            $Subkeys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
            
            foreach ($Subkey in $Subkeys) {
                try {
                    $DisplayName = (Get-ItemProperty -Path $Subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                    
                    if ($DisplayName) {
                        foreach ($SearchName in $DisplayNames) {
                            if ($DisplayName -eq $SearchName) {
                                # Return the subkey name (product code)
                                return $Subkey.PSChildName
                            }
                        }
                    }
                }
                catch {
                    continue
                }
            }
        }
    }
    
    return $null
}

function Test-ChromeInstalled {
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Uninstall-MsiByProductCode {
    <#
    .SYNOPSIS
        Uninstalls an MSI product using its product code.
    
    .OUTPUTS
        Returns the MSI exit code.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProductCode,
        
        [Parameter(Mandatory = $true)]
        [string]$ComponentName
    )
    
    try {
        $MsiExecPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msiexec.exe"
        $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_${ComponentName}_Uninstall.log"
        $MsiArguments = "/x `"$ProductCode`" $MsiUninstallParameters /L*v `"$MsiLogPath`""
        
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
            return -999
        }
        
        return $MsiProcess.ExitCode
    }
    catch {
        Write-ErrorLog -Message "Exception uninstalling ${ComponentName}: $($_.Exception.Message)"
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
    # STEP 1: Check if Chrome is installed
    # -------------------------------------------------------------------------
    
    if (-not (Test-ChromeInstalled)) {
        # Chrome not detected - consider this success (idempotent)
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Find Chrome product code
    # -------------------------------------------------------------------------
    
    $ChromeProductCode = Get-ProductCodeFromRegistry -DisplayNames $ChromeDisplayNames
    
    if (-not $ChromeProductCode) {
        # Chrome files exist but no registry entry - unusual situation
        # Try known product code format or report error
        Exit-WithError -ExitCode $ERR_CHROME_NOT_FOUND `
                       -Message "Chrome is installed but product code not found in registry. Manual removal may be required." `
                       -Component "Chrome"
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Uninstall optional components first (Legacy Browser Support)
    # -------------------------------------------------------------------------
    
    if ($UninstallLegacyBrowserSupport) {
        $LbsProductCode = Get-ProductCodeFromRegistry -DisplayNames $LegacyBrowserSupportDisplayNames
        
        if ($LbsProductCode) {
            $LbsExitCode = Uninstall-MsiByProductCode -ProductCode $LbsProductCode -ComponentName "LegacyBrowserSupport"
            
            if ($LbsExitCode -notin @(0, 1605, 3010)) {
                Write-ErrorLog -Message "WARNING: Legacy Browser Support uninstall returned exit code: $LbsExitCode"
            }
        }
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Uninstall Endpoint Verification
    # -------------------------------------------------------------------------
    
    if ($UninstallEndpointVerification) {
        $EvProductCode = Get-ProductCodeFromRegistry -DisplayNames $EndpointVerificationDisplayNames
        
        if ($EvProductCode) {
            $EvExitCode = Uninstall-MsiByProductCode -ProductCode $EvProductCode -ComponentName "EndpointVerification"
            
            if ($EvExitCode -notin @(0, 1605, 3010)) {
                Write-ErrorLog -Message "WARNING: Endpoint Verification uninstall returned exit code: $EvExitCode"
            }
        }
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Uninstall Google Chrome
    # -------------------------------------------------------------------------
    
    $ChromeExitCode = Uninstall-MsiByProductCode -ProductCode $ChromeProductCode -ComponentName "Chrome"
    
    if ($ChromeExitCode -eq -999) {
        Exit-WithError -ExitCode $ERR_CHROME_UNINSTALL_TIMEOUT `
                       -Message "Chrome uninstallation timed out after $MsiTimeoutSeconds seconds." `
                       -Component "Chrome"
    }
    
    # Exit codes: 0 = success, 1605 = product not installed, 3010 = reboot required
    if ($ChromeExitCode -notin @(0, 1605, 3010)) {
        Exit-WithError -ExitCode $ERR_CHROME_UNINSTALL_FAILED `
                       -Message "Chrome uninstallation failed." `
                       -MsiExitCode $ChromeExitCode `
                       -Component "Chrome"
    }
    
    # -------------------------------------------------------------------------
    # STEP 6: Verify Chrome is removed
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 3
    
    if (Test-ChromeInstalled) {
        Exit-WithError -ExitCode $ERR_CHROME_STILL_DETECTED `
                       -Message "Chrome uninstallation completed but chrome.exe is still detected." `
                       -MsiExitCode $ChromeExitCode `
                       -Component "Chrome"
    }
    
    # -------------------------------------------------------------------------
    # STEP 7: Success
    # -------------------------------------------------------------------------
    
    if ($ChromeExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    $ErrorMsg = "Unexpected error during uninstallation: $($_.Exception.Message)"
    
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $ErrorMsg"
    Write-ErrorLog -Message "Exception Type: $($_.Exception.GetType().FullName)"
    Write-ErrorLog -Message "Stack Trace: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}
