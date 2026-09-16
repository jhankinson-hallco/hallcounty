<#
.SYNOPSIS
    Install-Centegix.ps1

.DESCRIPTION
    Installs Centegix CrisisAlert desktop application using the MSI installer.
    
    Centegix CrisisAlert is an emergency response and notification platform
    that allows staff to receive real-time alerts and respond to emergencies.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-Centegix.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-Centegix.ps1
    Install behavior: System
    
    PACKAGE CONTENTS:
    - Install-Centegix.ps1
    - Uninstall-Centegix.ps1
    - Detect-Centegix.ps1
    - Centegix-Setup-1.10.3-win64.msi
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "Centegix"

# MSI installer filename (must be in same folder as this script)
$MsiFileName = "Centegix-Setup-1.10.3-win64.msi"

# MSI installation parameters
# /qn = silent, no UI
# /norestart = suppress reboot
# ALLUSERS=1 = install for all users (per-machine)
$MsiParameters = "/qn /norestart ALLUSERS=1"

# Installation timeout (seconds)
$InstallTimeoutSeconds = 300

# Detection paths - common installation locations for Centegix
$DetectionPaths = @(
    "${env:ProgramFiles}\Centegix\Centegix.exe",
    "${env:ProgramFiles}\CENTEGIX\Centegix.exe",
    "${env:ProgramFiles}\Centegix\CrisisAlert.exe",
    "${env:ProgramFiles}\CENTEGIX\CrisisAlert.exe",
    "${env:LocalAppData}\Programs\centegix\Centegix.exe"
)

# Logging (error-only)
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_MSI_NOT_FOUND = 78001
$ERR_MSI_INSTALL_FAILED = 78002
$ERR_MSI_INSTALL_TIMEOUT = 78003
$ERR_DETECTION_FAILED = 78004

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
    param([Parameter(Mandatory = $true)][string]$Message)
    
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
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][string]$MsiExitCode = ""
    )
    
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "Script Path: $PSCommandPath"
    Write-ErrorLog -Message "MSI File: $MsiFileName"
    
    if ($MsiExitCode -ne "") {
        Write-ErrorLog -Message "MSI Exit Code: $MsiExitCode"
        
        $MsiExitCodeMeaning = switch ($MsiExitCode) {
            "0"    { "Success" }
            "1603" { "Fatal error during installation" }
            "1618" { "Another installation is in progress" }
            "1619" { "Installation package could not be opened" }
            "1620" { "Installation package is invalid" }
            "1625" { "Installation prohibited by system policy" }
            "1638" { "Another version already installed" }
            "3010" { "Reboot required" }
            default { "See MSI documentation" }
        }
        Write-ErrorLog -Message "MSI Exit Code Meaning: $MsiExitCodeMeaning"
    }
    
    Write-ErrorLog -Message "Detection Paths Checked:"
    foreach ($Path in $DetectionPaths) {
        $Exists = Test-Path -LiteralPath $Path -PathType Leaf
        Write-ErrorLog -Message "  [$Exists] $Path"
    }
    Write-ErrorLog -Message "=========================================="
    
    Write-Error "ERROR $ExitCode : $Message"
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Test-CentegixInstalled {
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }
    
    # Also check registry for installed product
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
                    if ($DisplayName -like "*Centegix*" -or $DisplayName -like "*CrisisAlert*") {
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
    
    if (Test-CentegixInstalled) {
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
    # STEP 3: Install Centegix via MSI
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
    
    if (-not (Test-CentegixInstalled)) {
        Exit-WithError -ExitCode $ERR_DETECTION_FAILED `
                       -Message "MSI installation completed (exit code: $MsiExitCode) but Centegix was not detected." `
                       -MsiExitCode $MsiExitCode
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Apply registry configuration
    # -------------------------------------------------------------------------
    
    # Create Centegix settings registry key and set playResponderBeep value
    $RegPath = "HKLM:\SOFTWARE\Centegix\Settings"
    
    # Create the registry path if it doesn't exist
    if (-not (Test-Path -LiteralPath $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    
    # Set the playResponderBeep value
    Set-ItemProperty -Path $RegPath -Name "playResponderBeep" -Value "1" -Type String -Force
    
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