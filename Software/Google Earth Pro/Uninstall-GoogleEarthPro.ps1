<#
.SYNOPSIS
    Uninstall-GoogleEarthPro.ps1

.DESCRIPTION
    Uninstalls Google Earth Pro using MSI uninstall via product code.
    
    - Searches registry for Google Earth Pro uninstall information
    - Performs silent MSI uninstall
    - Logs ONLY on error to C:\IntuneAppLogs\GoogleEarthPro_Uninstall.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleEarthPro.ps1
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Application name (used for logging and registry search)
$AppName = "GoogleEarthPro"

# Display name to search for in registry (partial match)
$AppDisplayName = "Google Earth Pro"

# Known product codes for Google Earth Pro versions
# These are used as fallback if registry search fails
$KnownProductCodes = @(
    "{F27DBA46-80E1-4858-9285-19198FFFBF3D}",  # 7.3.6 64-bit
    "{EFE749BA-B12B-45EA-9A41-81E80A90DC4B}",  # 7.3.6 32-bit
    "{9BFB06CD-3925-49E2-BAB7-EA695821CE4C}",  # 7.3.4 64-bit
    "{67EC952F-44CE-4A14-8EBD-8D3CBCDA3785}",  # 7.3.4 32-bit
    "{FB8010D4-05F4-420D-8DFC-2F911A6DD100}",  # 7.3.3 64-bit
    "{59F21DFB-6977-434B-9CB9-67783D6E7B6B}",  # 7.3.3 32-bit
    "{70A0F34E-564B-4F93-ADD6-3BAEC6E44075}",  # 7.3.2 64-bit
    "{9D524A1E-F2FC-444D-B12A-7592CEB56EB5}",  # 7.3.2 32-bit
    "{D9EF644E-2FAE-493B-8180-5617CC774C4F}",  # 7.3.1 64-bit
    "{FA1BBF34-E994-4310-95D7-BE93092B8E61}"   # 7.3.1 32-bit
)

# Detection paths - used to verify uninstallation
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Google Earth Pro\client\googleearth.exe",
    "${env:ProgramFiles(x86)}\Google\Google Earth Pro\client\googleearth.exe"
)

# Timeout for uninstaller (seconds)
$UninstallerTimeoutSeconds = 300

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

$ERR_NOT_INSTALLED = 0        # Not an error - already uninstalled
$ERR_UNINSTALL_FAILED = 73001
$ERR_UNINSTALL_TIMEOUT = 73002
$ERR_STILL_DETECTED = 73003

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

function Test-GoogleEarthInstalled {
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Get-GoogleEarthUninstallString {
    <#
    .SYNOPSIS
        Searches registry for Google Earth Pro uninstall information.
    
    .DESCRIPTION
        Searches both 32-bit and 64-bit registry locations for Google Earth Pro
        and returns the product code if found.
    
    .OUTPUTS
        String - Product code (GUID) or empty string if not found
    #>
    
    # Registry paths to search for uninstall information
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($RegistryPath in $RegistryPaths) {
        if (Test-Path -LiteralPath $RegistryPath) {
            $Subkeys = Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue
            
            foreach ($Subkey in $Subkeys) {
                try {
                    $DisplayName = (Get-ItemProperty -Path $Subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                    
                    if ($DisplayName -like "*$AppDisplayName*") {
                        # Found Google Earth Pro - return the subkey name (product code)
                        return $Subkey.PSChildName
                    }
                }
                catch {
                    # Continue searching if this key fails
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
    # STEP 1: Check if Google Earth Pro is installed
    # -------------------------------------------------------------------------
    
    if (-not (Test-GoogleEarthInstalled)) {
        # Not installed - exit success (already in desired state)
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Find the product code for uninstallation
    # -------------------------------------------------------------------------
    
    $ProductCode = Get-GoogleEarthUninstallString
    
    # If registry search failed, try known product codes
    if ([string]::IsNullOrEmpty($ProductCode)) {
        foreach ($Code in $KnownProductCodes) {
            # Check if this product code exists in registry
            $TestPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$Code"
            $TestPath32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$Code"
            
            if ((Test-Path -LiteralPath $TestPath) -or (Test-Path -LiteralPath $TestPath32)) {
                $ProductCode = $Code
                break
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($ProductCode)) {
        Exit-WithError -ExitCode $ERR_UNINSTALL_FAILED `
                       -Message "Could not find Google Earth Pro product code in registry. Manual uninstall may be required." `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Execute MSI uninstall
    # -------------------------------------------------------------------------
    
    try {
        # Build msiexec command for silent uninstall
        $MsiExecPath = Join-Path -Path $env:WINDIR -ChildPath "System32\msiexec.exe"
        $MsiArguments = "/x $ProductCode /qn /norestart"
        
        $ProcessStartInfo = @{
            FilePath     = $MsiExecPath
            ArgumentList = $MsiArguments
            PassThru     = $true
            WindowStyle  = "Hidden"
            ErrorAction  = "Stop"
        }
        
        $UninstallProcess = Start-Process @ProcessStartInfo
        
        $ProcessCompleted = $UninstallProcess.WaitForExit($UninstallerTimeoutSeconds * 1000)
        
        if (-not $ProcessCompleted) {
            try { $UninstallProcess.Kill() } catch { }
            
            Exit-WithError -ExitCode $ERR_UNINSTALL_TIMEOUT `
                           -Message "Uninstall process timed out after $UninstallerTimeoutSeconds seconds." `
                           -ErrorCategory "SYSTEM"
        }
        
        $UninstallReturnCode = $UninstallProcess.ExitCode
        
        # Check for common MSI error codes
        # 0 = Success, 1605 = Product not installed (OK), 3010 = Reboot required (OK)
        if ($UninstallReturnCode -notin @(0, 1605, 3010)) {
            Exit-WithError -ExitCode $ERR_UNINSTALL_FAILED `
                           -Message "MSI uninstall failed with exit code: $UninstallReturnCode" `
                           -ErrorCategory "PROGRAM"
        }
    }
    catch {
        Exit-WithError -ExitCode $ERR_UNINSTALL_FAILED `
                       -Message "Failed to execute uninstaller: $($_.Exception.Message)" `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Verify uninstallation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 3
    
    if (Test-GoogleEarthInstalled) {
        Exit-WithError -ExitCode $ERR_STILL_DETECTED `
                       -Message "Uninstall completed but Google Earth Pro executable still exists." `
                       -ErrorCategory "PROGRAM"
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Uninstall successful
    # -------------------------------------------------------------------------
    
    exit $EXIT_SUCCESS
}
catch {
    $ErrorMsg = "Unexpected error during uninstall: $($_.Exception.Message)"
    Write-ErrorLog -Message "UNEXPECTED ERROR: $ErrorMsg"
    Write-Error $ErrorMsg
    exit $EXIT_FAILURE
}
