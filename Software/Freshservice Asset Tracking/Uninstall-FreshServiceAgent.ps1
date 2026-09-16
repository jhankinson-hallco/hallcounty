<#
.SYNOPSIS
    Uninstall-FreshServiceAgent.ps1

.DESCRIPTION
    Uninstalls Freshservice Discovery Agent.
    Searches the registry for the product code and performs MSI uninstall.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-FreshServiceAgent.ps1
    Install behavior: System
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "FreshServiceAgent"

# Display names to search for in registry
$DisplayNamePatterns = @(
    "*Freshservice Discovery*",
    "*Fresh Service*Discovery*"
)

# Known product code (from the MSI)
$KnownProductCode = "{8BE075F9-36C7-4145-8BC0-35D420223576}"

# MSI uninstall parameters
$MsiUninstallParameters = "/qn /norestart"

# Uninstall timeout (seconds)
$UninstallTimeoutSeconds = 300

# Detection path
$DetectionPath = "${env:ProgramFiles(x86)}\Freshdesk\Freshservice Discovery Agent\bin\FSAgentService.exe"

# Logging
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Uninstall.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

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

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Test-FreshServiceInstalled {
    if (Test-Path -LiteralPath $DetectionPath -PathType Leaf) {
        return $true
    }
    
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
                        foreach ($Pattern in $DisplayNamePatterns) {
                            if ($DisplayName -like $Pattern) {
                                return $true
                            }
                        }
                    }
                }
                catch { }
            }
        }
    }
    
    return $false
}

function Get-FreshServiceProductCode {
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path -LiteralPath $RegPath) {
            $Subkeys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
            foreach ($Subkey in $Subkeys) {
                try {
                    $Props = Get-ItemProperty -Path $Subkey.PSPath -ErrorAction SilentlyContinue
                    if ($Props.DisplayName) {
                        foreach ($Pattern in $DisplayNamePatterns) {
                            if ($Props.DisplayName -like $Pattern) {
                                return $Subkey.PSChildName
                            }
                        }
                    }
                }
                catch { }
            }
        }
    }
    
    return $null
}

function Uninstall-MsiByProductCode {
    param([Parameter(Mandatory)][string]$ProductCode)
    
    $MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\msiexec.exe"
    $MsiLogPath = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI_Uninstall.log"
    $MsiArguments = "/x `"$ProductCode`" $MsiUninstallParameters /L*v `"$MsiLogPath`""
    
    try {
        Write-ErrorLog -Message "Uninstalling product code: $ProductCode"
        
        $ProcessParams = @{
            FilePath     = $MsiExecPath
            ArgumentList = $MsiArguments
            Wait         = $false
            PassThru     = $true
            WindowStyle  = "Hidden"
        }
        
        $MsiProcess = Start-Process @ProcessParams
        $ProcessCompleted = $MsiProcess.WaitForExit($UninstallTimeoutSeconds * 1000)
        
        if (-not $ProcessCompleted) {
            try { $MsiProcess.Kill() } catch { }
            Write-ErrorLog -Message "Uninstall timed out"
            return $false
        }
        
        # Exit codes: 0 = success, 1605 = not installed, 3010 = reboot required
        if ($MsiProcess.ExitCode -in @(0, 1605, 3010)) {
            Write-ErrorLog -Message "Uninstall completed (Exit: $($MsiProcess.ExitCode))"
            return $true
        }
        else {
            Write-ErrorLog -Message "Uninstall failed (Exit: $($MsiProcess.ExitCode))"
            return $false
        }
    }
    catch {
        Write-ErrorLog -Message "Exception during uninstall: $($_.Exception.Message)"
        return $false
    }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # Check if already uninstalled
    if (-not (Test-FreshServiceInstalled)) {
        exit $EXIT_SUCCESS
    }
    
    # Get product code from registry
    $ProductCode = Get-FreshServiceProductCode
    
    # Use known product code as fallback
    if (-not $ProductCode) {
        $ProductCode = $KnownProductCode
    }
    
    # Uninstall
    $Result = Uninstall-MsiByProductCode -ProductCode $ProductCode
    
    # Wait and verify
    Start-Sleep -Seconds 3
    
    if (Test-FreshServiceInstalled) {
        Write-ErrorLog -Message "Warning: FreshService Agent may still be installed after uninstall attempt"
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -Message "Unexpected error: $($_.Exception.Message)"
    exit $EXIT_FAILURE
}
