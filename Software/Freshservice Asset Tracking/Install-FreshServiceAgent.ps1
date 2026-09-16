<#
.SYNOPSIS
    Install-FreshServiceAgent.ps1

.DESCRIPTION
    Installs Freshservice Discovery Agent using the MSI installer with organization-specific
    registration token.
    
    Freshservice Discovery Agent is used for asset discovery and inventory management
    in the Freshservice IT service management platform.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-FreshServiceAgent.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-FreshServiceAgent.ps1
    Install behavior: System
    
    PACKAGE CONTENTS:
    - Install-FreshServiceAgent.ps1
    - Uninstall-FreshServiceAgent.ps1
    - Detect-FreshServiceAgent.ps1
    - Fresh_Service_Asset_Agent_3.10.0.msi
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "FreshServiceAgent"

# MSI installer filename (must be in same folder as this script)
$MsiFileName = "Fresh_Service_Asset_Agent_3.10.0.msi"

# ----- FRESHSERVICE CONFIGURATION -----
# Registration token for your Freshservice instance
$RegistrationToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwb3J0YWxfdXJsIjoiaHR0cHM6Ly9kaXNjb3ZlcnktdXMuZnJlc2hzZXJ2aWNlLmNvbSIsImFjY291bnRfZnVsbF9kb21haW4iOiJodHRwczovL2hhbGxtaXMuZnJlc2hzZXJ2aWNlLmNvbSIsImFjY291bnRfaWQiOjIxNjgyMX0.p2WNIjP-zWnq1SxdJmzs2uiRSSo_aPr_cC9xnxNjOGY"

# ----- MSI PARAMETERS -----
$MsiParameters = "REGISTRATIONTOKEN=`"$RegistrationToken`" ALLUSERS=1 /qn /norestart"

# Installation timeout (seconds)
$InstallTimeoutSeconds = 300

# Detection path
$DetectionPath = "${env:ProgramFiles(x86)}\Freshdesk\Freshservice Discovery Agent\bin\FSAgentService.exe"

# Logging (error-only)
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_MSI_NOT_FOUND = 80001
$ERR_MSI_INSTALL_FAILED = 80002
$ERR_MSI_INSTALL_TIMEOUT = 80003
$ERR_DETECTION_FAILED = 80004

# =============================================================================
# END CONFIGURATION
# =============================================================================

#--------------------------------------------------------------------------------
# 64-BIT POWERSHELL RELAUNCH
#--------------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    
    if (Test-Path -LiteralPath $SysNativePwsh -PathType Leaf) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#--------------------------------------------------------------------------------
function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    
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
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message,
        [string]$MsiExitCode = ""
    )
    
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "MSI File: $MsiFileName"
    
    if ($MsiExitCode -ne "") {
        Write-ErrorLog -Message "MSI Exit Code: $MsiExitCode"
        
        $MsiExitCodeMeaning = switch ($MsiExitCode) {
            "0"    { "Success" }
            "1603" { "Fatal error during installation" }
            "1618" { "Another installation is in progress" }
            "1619" { "Installation package could not be opened" }
            "1625" { "Installation prohibited by system policy" }
            "1638" { "Another version already installed" }
            "1925" { "Insufficient privileges - requires admin" }
            "3010" { "Reboot required" }
            default { "See MSI documentation" }
        }
        Write-ErrorLog -Message "MSI Exit Code Meaning: $MsiExitCodeMeaning"
    }
    
    Write-ErrorLog -Message "Detection Path Exists: $(Test-Path -LiteralPath $DetectionPath -PathType Leaf)"
    Write-ErrorLog -Message "=========================================="
    
    Write-Error "ERROR $ExitCode : $Message"
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Test-FreshServiceInstalled {
    if (Test-Path -LiteralPath $DetectionPath -PathType Leaf) {
        return $true
    }
    
    # Fallback: check registry
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
                    if ($DisplayName -like "*Freshservice Discovery*") {
                        return $true
                    }
                }
                catch { }
            }
        }
    }
    
    return $false
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # -------------------------------------------------------------------------
    # STEP 1: Check if already installed
    # -------------------------------------------------------------------------
    
    if (Test-FreshServiceInstalled) {
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Locate MSI installer
    # -------------------------------------------------------------------------
    
    $MsiPath = Join-Path -Path $PSScriptRoot -ChildPath $MsiFileName
    
    if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_MSI_NOT_FOUND `
                       -Message "MSI installer not found: '$MsiPath'. Ensure '$MsiFileName' is in the package."
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Install FreshService Agent via MSI
    # -------------------------------------------------------------------------
    
    $MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\msiexec.exe"
    $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI_Install.log"
    $MsiArguments = "/i `"$MsiPath`" $MsiParameters /L*v `"$MsiLogPath`""
    
    $ProcessParams = @{
        FilePath     = $MsiExecPath
        ArgumentList = $MsiArguments
        Wait         = $false
        PassThru     = $true
        WindowStyle  = "Hidden"
    }
    
    $MsiProcess = Start-Process @ProcessParams
    $ProcessCompleted = $MsiProcess.WaitForExit($InstallTimeoutSeconds * 1000)
    
    if (-not $ProcessCompleted) {
        try { $MsiProcess.Kill() } catch { }
        Exit-WithError -ExitCode $ERR_MSI_INSTALL_TIMEOUT `
                       -Message "MSI installation timed out after $InstallTimeoutSeconds seconds."
    }
    
    $MsiExitCode = $MsiProcess.ExitCode
    
    # Exit codes: 0 = success, 3010 = reboot required
    if ($MsiExitCode -notin @(0, 3010)) {
        Exit-WithError -ExitCode $ERR_MSI_INSTALL_FAILED `
                       -Message "MSI installation failed." `
                       -MsiExitCode $MsiExitCode
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Verify installation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 5
    
    if (-not (Test-FreshServiceInstalled)) {
        Exit-WithError -ExitCode $ERR_DETECTION_FAILED `
                       -Message "MSI installation completed (exit code: $MsiExitCode) but FreshService Agent was not detected." `
                       -MsiExitCode $MsiExitCode
    }
    
    # -------------------------------------------------------------------------
    # SUCCESS
    # -------------------------------------------------------------------------
    
    if ($MsiExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $($_.Exception.Message)"
    Write-ErrorLog -Message "Stack: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    Write-Error $_.Exception.Message
    exit $EXIT_FAILURE
}
