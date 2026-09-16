<#
.SYNOPSIS
    Uninstall-EVReachClient.ps1

.DESCRIPTION
    Uninstalls EV Reach Client (formerly Goverlan Reach Client) using MSI uninstall.
    
    - Searches registry for product code
    - Performs silent MSI uninstall
    - Logs ONLY on error to C:\IntuneAppLogs\EVReachClient_Uninstall.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-EVReachClient.ps1
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "EVReachClient"

# Display names to search for in registry (partial match)
# EV Reach Client may be registered under different names
$AppDisplayNames = @(
    "EV Reach Client",
    "Goverlan Client",
    "Goverlan Reach Client",
    "EV Reach Agents"
)

# Detection paths - used to verify uninstallation
$DetectionPaths = @(
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgent.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgent.exe"
)

# Timeout for uninstallation (seconds)
$UninstallTimeoutSeconds = 300

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

$ERR_PRODUCT_NOT_FOUND = 75001
$ERR_UNINSTALL_FAILED = 75002
$ERR_UNINSTALL_TIMEOUT = 75003
$ERR_STILL_DETECTED = 75004

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
        [string]$ErrorCategory = "PROGRAM"
    )
    
    Write-ErrorLog -Message "========== UNINSTALL FAILED =========="
    Write-ErrorLog -Message "Error Category: $ErrorCategory"
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "======================================="
    
    Write-Error "[$ErrorCategory] ERROR $ExitCode : $Message"
    exit $ExitCode
}

function Test-EVReachInstalled {
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Get-EVReachProductCode {
    <#
    .SYNOPSIS
        Searches registry for EV Reach Client product code.
    #>
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($RegistryPath in $RegistryPaths) {
        if (Test-Path -LiteralPath $RegistryPath) {
            $Subkeys = Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue
            
            foreach ($Subkey in $Subkeys) {
                try {
                    $Props = Get-ItemProperty -Path $Subkey.PSPath -ErrorAction SilentlyContinue
                    $DisplayName = $Props.DisplayName
                    
                    foreach ($SearchName in $AppDisplayNames) {
                        if ($DisplayName -like "*$SearchName*") {
                            # Found it - return the product code (subkey name)
                            return $Subkey.PSChildName
                        }
                    }
                }
                catch {
                    continue
                }
            }
        }
    }
    
    return ""
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
    # STEP 1: Check if EV Reach Client is installed
    # -------------------------------------------------------------------------
    
    if (-not (Test-EVReachInstalled)) {
        # Not installed - already in desired state
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Find the product code
    # -------------------------------------------------------------------------
    
    $ProductCode = Get-EVReachProductCode
    
    if ([string]::IsNullOrEmpty($ProductCode)) {
        # Try alternate detection - look for Goverlan folder and check for uninstaller
        $GoverlanPath = "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent"
        if (Test-Path -LiteralPath $GoverlanPath -PathType Container) {
            # Files exist but no registry entry - may need manual cleanup
            Exit-WithError -ExitCode $ERR_PRODUCT_NOT_FOUND `
                           -Message "EV Reach Client files exist but product code not found in registry. Manual uninstall may be required." `
                           -ErrorCategory "PROGRAM"
        }
        
        # No files and no registry - already uninstalled
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Execute MSI uninstall
    # -------------------------------------------------------------------------
    
    try {
        $MsiExecPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msiexec.exe"
        $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI_Uninstall.log"
        $MsiArguments = "/x $ProductCode /qn /norestart /L*v `"$MsiLogPath`""
        
        $ProcessStartInfo = @{
            FilePath     = $MsiExecPath
            ArgumentList = $MsiArguments
            PassThru     = $true
            Wait         = $false
            WindowStyle  = "Hidden"
            ErrorAction  = "Stop"
        }
        
        $MsiProcess = Start-Process @ProcessStartInfo
        
        $ProcessCompleted = $MsiProcess.WaitForExit($UninstallTimeoutSeconds * 1000)
        
        if (-not $ProcessCompleted) {
            try { $MsiProcess.Kill() } catch { }
            
            Exit-WithError -ExitCode $ERR_UNINSTALL_TIMEOUT `
                           -Message "MSI uninstall timed out after $UninstallTimeoutSeconds seconds." `
                           -ErrorCategory "SYSTEM"
        }
        
        $MsiReturnCode = $MsiProcess.ExitCode
        
        # Check MSI return code
        # 0 = Success, 1605 = Product not installed, 3010 = Reboot required
        if ($MsiReturnCode -notin @(0, 1605, 3010)) {
            Exit-WithError -ExitCode $ERR_UNINSTALL_FAILED `
                           -Message "MSI uninstall failed with exit code: $MsiReturnCode" `
                           -ErrorCategory "PROGRAM"
        }
    }
    catch {
        Exit-WithError -ExitCode $ERR_UNINSTALL_FAILED `
                       -Message "Failed to execute msiexec: $($_.Exception.Message)" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Verify uninstallation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 5
    
    if (Test-EVReachInstalled) {
        Exit-WithError -ExitCode $ERR_STILL_DETECTED `
                       -Message "Uninstall completed but EV Reach Client executable still exists." `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Success
    # -------------------------------------------------------------------------
    
    exit $EXIT_SUCCESS
}
catch {
    $ErrorMsg = "Unexpected error during uninstall: $($_.Exception.Message)"
    Write-ErrorLog -Message "UNEXPECTED ERROR: $ErrorMsg"
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}
