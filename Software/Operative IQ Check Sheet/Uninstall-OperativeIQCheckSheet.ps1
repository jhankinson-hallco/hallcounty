#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstall-OperativeIQCheckSheet.ps1

.DESCRIPTION
    Uninstalls Operative IQ Check Sheet using the cached MSI.
    
    - Uses cached MSI from install (no product code dependency)
    - Removes tag file and cache directory
    - Logs ONLY on error to C:\IntuneUninstallLogs\OperativeIQ_CheckSheet_Uninstall.txt

.NOTES
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-OperativeIQCheckSheet.ps1
#>

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'OperativeIQ_CheckSheet'
$MsiFileName = 'IQCheckSheet.msi'

# Cache location for MSI
$CacheDir = Join-Path -Path $env:ProgramData -ChildPath 'OperativeIQ\CheckSheet'

# Detection tag file
$TagDir = Join-Path -Path $env:ProgramData -ChildPath 'IntuneTags'
$TagFile = Join-Path -Path $TagDir -ChildPath 'OperativeIQ_CheckSheet.tag'

# MSI arguments
$MsiUninstallArgs = '/qn /norestart'

# Timeout for MSI (seconds)
$MsiTimeoutSeconds = 300

# Logging (error-only)
$LogFolder = 'C:\IntuneUninstallLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Uninstall.txt"

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_MSI_NOT_FOUND = 71001
$ERR_MSI_FAILED = 71002
$ERR_MSI_TIMEOUT = 71003
$ERR_GENERAL = 71099

# =============================================================================
# END CONFIGURATION
# =============================================================================

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS (Error-only)
#--------------------------------------------------------------------------------
$script:LogInitialized = $false

function Initialize-ErrorLog {
    if ($script:LogInitialized) { return }
    
    try {
        if (-not (Test-Path -LiteralPath $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
        $script:LogInitialized = $true
    }
    catch {
        $script:LogInitialized = $true
    }
}

function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    
    try {
        Initialize-ErrorLog
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $LogFile -Value "[$Timestamp] $Message"
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message
    )
    
    Write-ErrorLog -Message "ERROR ($ExitCode): $Message"
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# 64-BIT POWERSHELL RELAUNCH
#--------------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    
    if (Test-Path -LiteralPath $SysNativePwsh) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Invoke-MsiUninstall {
    param([Parameter(Mandatory)][string]$MsiPath)
    
    $TempMsiLog = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI_Uninstall.log"
    
    # Remove old temp log if exists
    if (Test-Path -LiteralPath $TempMsiLog) {
        Remove-Item -LiteralPath $TempMsiLog -Force -ErrorAction SilentlyContinue
    }
    
    $MsiArguments = "/x `"$MsiPath`" $MsiUninstallArgs /L*v `"$TempMsiLog`""
    
    try {
        $Process = Start-Process -FilePath 'msiexec.exe' `
                                 -ArgumentList $MsiArguments `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -ErrorAction Stop
        
        $Completed = $Process.WaitForExit($MsiTimeoutSeconds * 1000)
        
        if (-not $Completed) {
            try { $Process.Kill() } catch { }
            
            # Persist MSI log on timeout
            if (Test-Path -LiteralPath $TempMsiLog) {
                Initialize-ErrorLog
                $DestLog = Join-Path -Path $LogFolder -ChildPath "${AppName}_MSI_Uninstall.log"
                Copy-Item -LiteralPath $TempMsiLog -Destination $DestLog -Force -ErrorAction SilentlyContinue
            }
            
            return @{ ExitCode = -1; TimedOut = $true }
        }
        
        $ExitCode = $Process.ExitCode
    }
    catch {
        return @{ ExitCode = -1; TimedOut = $false; Error = $_.Exception.Message }
    }
    
    # Success codes: 0, 3010 (reboot required), 1641 (reboot initiated)
    if ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq 1641) {
        # Remove temp MSI log on success
        if (Test-Path -LiteralPath $TempMsiLog) {
            Remove-Item -LiteralPath $TempMsiLog -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        # Persist MSI log on failure
        if (Test-Path -LiteralPath $TempMsiLog) {
            try {
                Initialize-ErrorLog
                $DestLog = Join-Path -Path $LogFolder -ChildPath "${AppName}_MSI_Uninstall.log"
                Copy-Item -LiteralPath $TempMsiLog -Destination $DestLog -Force
            }
            catch { }
        }
    }
    
    return @{ ExitCode = $ExitCode; TimedOut = $false }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # STEP 1: Verify cached MSI exists
    $MsiCached = Join-Path -Path $CacheDir -ChildPath $MsiFileName
    
    if (-not (Test-Path -LiteralPath $MsiCached -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_MSI_NOT_FOUND -Message "Cached MSI not found: $MsiCached"
    }
    
    # STEP 2: Run MSI uninstall
    $Result = Invoke-MsiUninstall -MsiPath $MsiCached
    
    if ($Result.TimedOut) {
        Exit-WithError -ExitCode $ERR_MSI_TIMEOUT -Message "MSI uninstall timed out after $MsiTimeoutSeconds seconds"
    }
    
    $MsiExitCode = $Result.ExitCode
    
    if ($MsiExitCode -ne 0 -and $MsiExitCode -ne 3010 -and $MsiExitCode -ne 1641) {
        Exit-WithError -ExitCode $ERR_MSI_FAILED -Message "MSI uninstall failed with exit code: $MsiExitCode"
    }
    
    # STEP 3: Remove detection tag file
    if (Test-Path -LiteralPath $TagFile) {
        Remove-Item -LiteralPath $TagFile -Force -ErrorAction SilentlyContinue
    }
    
    # STEP 4: Clean up cache directory
    if (Test-Path -LiteralPath $CacheDir) {
        Remove-Item -LiteralPath $CacheDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Also remove parent OperativeIQ folder if empty
    $ParentDir = Split-Path -Path $CacheDir -Parent
    if (Test-Path -LiteralPath $ParentDir) {
        $RemainingItems = Get-ChildItem -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
        if (-not $RemainingItems -or $RemainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
        }
    }
    
    # STEP 5: Return appropriate exit code
    if ($MsiExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Exit-WithError -ExitCode $ERR_GENERAL -Message "Unhandled exception: $($_.Exception.Message)"
}
