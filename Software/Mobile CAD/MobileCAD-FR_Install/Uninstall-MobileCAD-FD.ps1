<# 
.SYNOPSIS
    Uninstall-MobileCAD-FD.ps1
    Uninstalls Mobile CAD FD Client by removing files and shortcuts.

.DESCRIPTION
    1. Stops VMLaunch process if running
    2. Removes FD.Classic.lnk from Public Desktop
    3. Removes FD.Classic.lnk from Startup folder
    4. Removes C:\Mobile Client FD folder
    
    Logs ONLY on failure to C:\IntuneAppLogs\MobileCAD-FD_Uninstall.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-MobileCAD-FD.ps1
#>

#================================================================================
# CONFIGURATION SECTION - MUST MATCH INSTALL SCRIPT
#================================================================================

# Application name (used in logging)
$AppName = "MobileCAD-FD"

# Shortcut filename
$ShortcutFileName = "FD.Classic.lnk"

# Installation folder
$DestinationRoot = "C:\"
$DestinationFolderName = "Mobile Client FD"

# Process to stop before uninstall
$ProcessName = "VMLaunch"

# Log folder
$LogFolder = "C:\IntuneAppLogs"

# Timeout for process stop (seconds)
$ProcessStopTimeoutSeconds = 30

#================================================================================
# ERROR CODES
#================================================================================

$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_FOLDER_REMOVE_FAILED = 7101
$ERR_PROCESS_STOP_FAILED  = 7102

#================================================================================
# END CONFIGURATION SECTION
#================================================================================

# Ensure 64-bit execution on 64-bit OS
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePS = Join-Path -Path $env:WINDIR -ChildPath "SysNative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path -LiteralPath $SysNativePS) {
        & $SysNativePS -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
        exit $LASTEXITCODE
    }
}

# Build paths
$DestinationFolder = Join-Path -Path $DestinationRoot -ChildPath $DestinationFolderName

$PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = Join-Path -Path $env:PUBLIC -ChildPath "Desktop"
}
$DesktopShortcut = Join-Path -Path $PublicDesktop -ChildPath $ShortcutFileName

$StartupFolder = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupShortcut = Join-Path -Path $StartupFolder -ChildPath $ShortcutFileName

$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Uninstall.txt"

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#--------------------------------------------------------------------------------
function Initialize-ErrorLog {
    try {
        if (-not (Test-Path -Path $LogFolder -PathType Container)) {
            New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile -PathType Leaf)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [int]$ExitCode,
        
        [System.Exception]$Exception
    )
    
    try {
        if (Initialize-ErrorLog) {
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $LogFile -Value "$Timestamp [ERROR] $Message | ExitCode: $ExitCode" -ErrorAction Stop
            if ($Exception) {
                Add-Content -Path $LogFile -Value "$Timestamp [EXCEPTION] $($Exception.GetType().FullName): $($Exception.Message)" -ErrorAction Stop
            }
        }
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)]
        [int]$ExitCode,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [System.Exception]$Exception
    )
    
    Write-ErrorLog -Message $Message -ExitCode $ExitCode -Exception $Exception
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# FUNCTION: Stop-ApplicationProcess
# PURPOSE:  Stops the application process if running
#--------------------------------------------------------------------------------
function Stop-ApplicationProcess {
    try {
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if ($Processes) {
            foreach ($Proc in $Processes) {
                try {
                    $Proc.Kill()
                    $Proc.WaitForExit($ProcessStopTimeoutSeconds * 1000)
                }
                catch {
                    # Process may have already exited
                }
            }
            
            # Brief wait for handles to release
            Start-Sleep -Seconds 2
        }
    }
    catch {
        # Non-fatal - continue with uninstall
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Remove-ShortcutSafely
# PURPOSE:  Removes a shortcut file if it exists
#--------------------------------------------------------------------------------
function Remove-ShortcutSafely {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
        catch {
            # Non-fatal - continue
        }
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Remove-FolderSafely
# PURPOSE:  Removes a folder and all contents, with retry logic
#--------------------------------------------------------------------------------
function Remove-FolderSafely {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $true
    }
    
    # Try up to 3 times with delays (files might be locked)
    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return $true
        }
        catch {
            if ($Attempt -lt 3) {
                Start-Sleep -Seconds 3
            }
        }
    }
    
    # Final check - if folder still exists, return false
    return (-not (Test-Path -LiteralPath $Path -PathType Container))
}

#================================================================================
# MAIN EXECUTION
#================================================================================

# STEP 1: Stop the application process if running
Stop-ApplicationProcess

# STEP 2: Remove desktop shortcut
Remove-ShortcutSafely -Path $DesktopShortcut

# STEP 3: Remove startup shortcut
Remove-ShortcutSafely -Path $StartupShortcut

# STEP 4: Remove application folder
$FolderRemoved = Remove-FolderSafely -Path $DestinationFolder

if (-not $FolderRemoved) {
    Exit-WithError -ExitCode $ERR_FOLDER_REMOVE_FAILED -Message "Failed to remove application folder: $DestinationFolder"
}

# STEP 5: Success
exit $EXIT_SUCCESS
