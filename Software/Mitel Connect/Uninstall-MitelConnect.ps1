#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstall-MitelConnect.ps1

.DESCRIPTION
    Uninstalls Mitel Connect by:
    1. Stopping any running Mitel processes
    2. Removing C:\Program Files (x86)\Mitel\Connect folder
    3. Removing "Mitel Connect.lnk" from Public Desktop
    
    Logs ONLY on error to C:\IntuneUninstallLogs\MitelConnect_Uninstall.txt

.NOTES
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-MitelConnect.ps1
#>

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'MitelConnect'

# Paths to remove
$DestinationRoot = 'C:\Program Files (x86)\Mitel'
$DestinationFolder = Join-Path -Path $DestinationRoot -ChildPath 'Connect'
$DestinationShortcut = 'C:\Users\Public\Desktop\Mitel Connect.lnk'

# Process names to stop (without .exe)
$ProcessNames = @('mabortal', 'Mitel Connect', 'Connect')

# Logging
$LogFolder = 'C:\IntuneUninstallLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Uninstall.txt"

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_REMOVE_FAILED = 71101

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
        if (-not (Test-Path -Path $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
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
        Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
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
# MAIN EXECUTION
#--------------------------------------------------------------------------------

# STEP 1: Stop any running Mitel processes
foreach ($ProcessName in $ProcessNames) {
    try {
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        foreach ($Proc in $Processes) {
            try {
                $Proc.Kill()
                $Proc.WaitForExit(10000)
            }
            catch { }
        }
    }
    catch { }
}

# Brief wait for handles to release
Start-Sleep -Seconds 2

# STEP 2: Remove Connect folder
if (Test-Path -LiteralPath $DestinationFolder -PathType Container) {
    # Try up to 3 times with delays
    $Removed = $false
    
    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
        try {
            Remove-Item -LiteralPath $DestinationFolder -Recurse -Force -ErrorAction Stop
            $Removed = $true
            break
        }
        catch {
            if ($Attempt -lt 3) {
                Start-Sleep -Seconds 3
            }
        }
    }
    
    if (-not $Removed -and (Test-Path -LiteralPath $DestinationFolder)) {
        Exit-WithError -ExitCode $ERR_REMOVE_FAILED -Message "Failed to remove Connect folder after 3 attempts: $DestinationFolder"
    }
}

# STEP 3: Remove Mitel folder if empty
if (Test-Path -LiteralPath $DestinationRoot -PathType Container) {
    $RemainingItems = Get-ChildItem -LiteralPath $DestinationRoot -Force -ErrorAction SilentlyContinue
    
    if (-not $RemainingItems -or $RemainingItems.Count -eq 0) {
        try {
            Remove-Item -LiteralPath $DestinationRoot -Force -ErrorAction SilentlyContinue
        }
        catch { }
    }
}

# STEP 4: Remove shortcut from Public Desktop
if (Test-Path -LiteralPath $DestinationShortcut -PathType Leaf) {
    try {
        Remove-Item -LiteralPath $DestinationShortcut -Force -ErrorAction Stop
    }
    catch {
        # Non-fatal - continue
        Write-ErrorLog -Message "Warning: Could not remove shortcut: $($_.Exception.Message)"
    }
}

# SUCCESS
exit $EXIT_SUCCESS
