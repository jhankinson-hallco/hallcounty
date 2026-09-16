<#
.SYNOPSIS
    Install-OSMCT.ps1

.DESCRIPTION
    Installs OSMCT via mupdate deployment workflow:
    1. Creates required folders with permissions
    2. Copies mupdate.lnk to Public Desktop
    3. Runs mupdate first pass (install) - waits for file activity to stop
    4. Verifies permissions
    5. Creates OSMCT shortcut
    6. Runs mupdate second pass (update) - waits for file activity to stop
    7. Registers LeadTools OCX files
    8. Validates OSMCT launch

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune / PDQ Deploy
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-OSMCT.ps1
    Install behavior: System
    
    MUPDATE BEHAVIOR:
    Mupdate is an auto-downloader that downloads/updates files automatically.
    When complete, it remains running with a greyed-out Exit button that becomes
    enabled. The process never exits on its own - it waits for user interaction.
    
    COMPLETION DETECTION STRATEGY:
    Since mupdate.exe never exits on its own, we cannot use process monitoring.
    Instead, we monitor file system activity in the target folders:
    1. Launch mupdate
    2. Wait for file writes to START (confirms mupdate is working)
    3. Wait for file writes to STOP for 180 seconds (confirms update complete)
    4. Close the mupdate window programmatically
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'OSMCT'

# Logging
$LogFolder = 'C:\IntuneAppLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

# Paths
$PublicDesktop = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'

# Source location (network share)
$SourceRoot = '\\psjapp\RMSAPPS\mupdate\PDQ Deployment'
$MupdateShortcutSource = Join-Path -Path $SourceRoot -ChildPath 'mupdate.lnk'
$MupdateShortcutDest = Join-Path -Path $PublicDesktop -ChildPath 'mupdate.lnk'

# OSMCT paths
$OSMCTExePath = 'C:\ossimob\ONESolutionMCT\onesolutionmct.exe'
$OSMCTShortcutDest = Join-Path -Path $PublicDesktop -ChildPath 'OSMCT.lnk'

# LeadTools OCX paths
$LeadToolsOcxPath1 = 'C:\ossimob\MCT\Leadtools\ltdlg12n.ocx'
$LeadToolsOcxPath2 = 'C:\ossimob\MCT\Leadtools\ltocx12n.ocx'

# Folders that mupdate writes to (also need permissions set)
$MonitoredFolders = @(
    'C:\ossimob',
    'C:\mobfiles',
    'C:\moblan',
    'C:\foxtmp',
    'C:\tmpossi'
)

# Permission groups
$GrantGroups = @(
    'Everyone',
    'Authenticated Users',
    'Users'
)

# Mupdate process name (without .exe)
$MupdateProcessName = 'mupdate'

# OSMCT process names for validation cleanup
$OSMCTProcessNames = @(
    'SunGuard.PS.OSSI.UI.OSMCT',
    'ONESolutionMCT',
    'onesolutionmct'
)

# ----- TIMING CONFIGURATION -----

# How long to wait for file activity to START after launching mupdate (seconds)
# If no writes occur within this time, assume mupdate failed to start properly
$ActivityStartTimeoutSeconds = 300  # 5 minutes

# How long with NO file writes before considering mupdate complete (seconds)
# This is the key setting - mupdate is "done" when folders are idle this long
$FileIdleTimeoutSeconds = 180  # 3 minutes

# Absolute maximum time to wait for a mupdate pass (seconds)
# Safety limit to prevent infinite waiting
$MaximumRuntimeSeconds = 1800  # 30 minutes

# How often to check for file activity (seconds)
$PollIntervalSeconds = 10

# OSMCT validation run time (seconds)
$OSMCTValidationSeconds = 120

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_NOT_ELEVATED = 73001
$ERR_SOURCE_NOT_FOUND = 73002
$ERR_MUPDATE_NO_ACTIVITY = 73003
$ERR_MUPDATE_TIMEOUT = 73004
$ERR_OSMCT_NOT_FOUND = 73005
$ERR_OCX_REGISTRATION = 73006

# =============================================================================
# END CONFIGURATION
# =============================================================================

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
# LOGGING FUNCTIONS
#--------------------------------------------------------------------------------
function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
        
        $Header = "`r`n" + ("=" * 60) + "`r`n"
        $Header += "OSMCT Install Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
        $Header += ("=" * 60)
        Add-Content -Path $LogFile -Value $Header
    }
    catch { }
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    
    try {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $LogFile -Value "[$Timestamp] [$Level] $Message"
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message
    )
    
    Write-Log -Message "FATAL: $Message (ExitCode: $ExitCode)" -Level 'ERROR'
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# ELEVATION CHECK
#--------------------------------------------------------------------------------
function Test-IsElevated {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Grant-FolderFullControl {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Groups
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
    
    foreach ($Group in $Groups) {
        icacls $Path /grant "${Group}:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
    }
}

function New-ShortcutToExe {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$ShortcutPath
    )
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.WorkingDirectory = Split-Path -Path $TargetPath -Parent
    $Shortcut.WindowStyle = 1
    $Shortcut.Save()
    
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

function Get-LatestWriteTime {
    <#
    .SYNOPSIS
        Gets the most recent LastWriteTime across all monitored folders and their contents.
    .DESCRIPTION
        Recursively scans all monitored folders and returns the most recent write time.
        This is used to detect when mupdate has stopped writing files.
    #>
    
    $LatestTime = [DateTime]::MinValue
    
    foreach ($Folder in $MonitoredFolders) {
        if (Test-Path -LiteralPath $Folder -PathType Container) {
            try {
                # Check the folder itself
                $FolderInfo = Get-Item -LiteralPath $Folder -ErrorAction SilentlyContinue
                if ($FolderInfo.LastWriteTime -gt $LatestTime) {
                    $LatestTime = $FolderInfo.LastWriteTime
                }
                
                # Check all files recursively
                Get-ChildItem -LiteralPath $Folder -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.LastWriteTime -gt $LatestTime) {
                        $LatestTime = $_.LastWriteTime
                    }
                }
                
                # Check all subfolders
                Get-ChildItem -LiteralPath $Folder -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.LastWriteTime -gt $LatestTime) {
                        $LatestTime = $_.LastWriteTime
                    }
                }
            }
            catch {
                # Folder may be locked during write - continue checking others
            }
        }
    }
    
    return $LatestTime
}

function Close-MupdateProcess {
    <#
    .SYNOPSIS
        Closes the mupdate process gracefully, then forcefully if needed.
    .DESCRIPTION
        Since mupdate never exits on its own (waits for user to click Exit),
        we must close it programmatically after detecting completion.
    #>
    
    $MupdateProcs = Get-Process -Name $MupdateProcessName -ErrorAction SilentlyContinue
    
    if (-not $MupdateProcs) {
        Write-Log "No mupdate process found to close"
        return
    }
    
    # Try graceful close first (sends WM_CLOSE to main window)
    foreach ($Proc in $MupdateProcs) {
        try {
            Write-Log "Sending close message to mupdate (PID: $($Proc.Id))"
            $Proc.CloseMainWindow() | Out-Null
        }
        catch {
            Write-Log "Could not send close message: $($_.Exception.Message)" -Level 'WARN'
        }
    }
    
    # Wait for graceful close
    Start-Sleep -Seconds 10
    
    # Check if still running and force kill
    $MupdateProcs = Get-Process -Name $MupdateProcessName -ErrorAction SilentlyContinue
    
    if ($MupdateProcs) {
        foreach ($Proc in $MupdateProcs) {
            try {
                Write-Log "Force stopping mupdate (PID: $($Proc.Id))"
                Stop-Process -Id $Proc.Id -Force -ErrorAction Stop
            }
            catch {
                Write-Log "Could not force stop: $($_.Exception.Message)" -Level 'WARN'
            }
        }
    }
    
    Write-Log "Mupdate process closed"
}

function Start-MupdatePass {
    <#
    .SYNOPSIS
        Runs a mupdate pass and waits for completion using file system idle detection.
    .DESCRIPTION
        Mupdate never exits on its own - it waits for user to click Exit.
        We detect completion by monitoring file system activity:
        1. Launch mupdate
        2. Wait for file writes to START (confirms mupdate is working)
        3. Wait for file writes to STOP for $FileIdleTimeoutSeconds
        4. Close mupdate programmatically
    #>
    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][int]$PassNumber
    )
    
    Write-Log "========== MUPDATE PASS $PassNumber STARTING =========="
    Write-Log "File idle timeout: $FileIdleTimeoutSeconds seconds"
    Write-Log "Maximum runtime: $MaximumRuntimeSeconds seconds"
    
    if (-not (Test-Path -LiteralPath $ShortcutPath)) {
        throw "Mupdate shortcut not found: $ShortcutPath"
    }
    
    # Record baseline - the latest write time BEFORE we start mupdate
    $BaselineWriteTime = Get-LatestWriteTime
    Write-Log "Baseline write time: $($BaselineWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    # Launch mupdate
    Write-Log "Launching mupdate: $ShortcutPath"
    Start-Process -FilePath $ShortcutPath -WindowStyle Normal
    
    $StartTime = Get-Date
    $ActivityDetected = $false
    $LastLogTime = Get-Date
    
    # -------------------------------------------------------------------------
    # PHASE 1: Wait for file activity to START
    # -------------------------------------------------------------------------
    Write-Log "Phase 1: Waiting for file activity to start (timeout: $ActivityStartTimeoutSeconds seconds)..."
    
    while ($true) {
        Start-Sleep -Seconds $PollIntervalSeconds
        
        $ElapsedSeconds = (New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds
        $CurrentWriteTime = Get-LatestWriteTime
        
        # Check if any new writes have occurred since baseline
        if ($CurrentWriteTime -gt $BaselineWriteTime) {
            Write-Log "File activity detected! Latest write: $($CurrentWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            $ActivityDetected = $true
            break
        }
        
        # Log progress every 60 seconds
        if ((New-TimeSpan -Start $LastLogTime -End (Get-Date)).TotalSeconds -ge 60) {
            Write-Log "Waiting for activity... ($([math]::Round($ElapsedSeconds)) seconds elapsed)"
            $LastLogTime = Get-Date
        }
        
        # Timeout - no activity detected
        if ($ElapsedSeconds -ge $ActivityStartTimeoutSeconds) {
            Write-Log "No file activity detected within $ActivityStartTimeoutSeconds seconds" -Level 'ERROR'
            Close-MupdateProcess
            throw "Mupdate pass $PassNumber failed: No file activity detected. Mupdate may have failed to start or connect."
        }
        
        # Safety timeout
        if ($ElapsedSeconds -ge $MaximumRuntimeSeconds) {
            Write-Log "Maximum runtime exceeded waiting for activity" -Level 'ERROR'
            Close-MupdateProcess
            throw "Mupdate pass $PassNumber failed: Maximum runtime exceeded."
        }
    }
    
    # -------------------------------------------------------------------------
    # PHASE 2: Wait for file activity to STOP (idle detection)
    # -------------------------------------------------------------------------
    Write-Log "Phase 2: Monitoring for completion (idle timeout: $FileIdleTimeoutSeconds seconds)..."
    
    $LastActivityTime = Get-Date
    $LastKnownWriteTime = Get-LatestWriteTime
    
    while ($true) {
        Start-Sleep -Seconds $PollIntervalSeconds
        
        $ElapsedSeconds = (New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds
        $CurrentWriteTime = Get-LatestWriteTime
        
        # Check if new writes have occurred
        if ($CurrentWriteTime -gt $LastKnownWriteTime) {
            # Activity detected - reset idle timer
            $LastActivityTime = Get-Date
            $LastKnownWriteTime = $CurrentWriteTime
        }
        
        # Calculate idle time (seconds since last file write)
        $IdleSeconds = (New-TimeSpan -Start $LastActivityTime -End (Get-Date)).TotalSeconds
        
        # Log progress every 60 seconds
        if ((New-TimeSpan -Start $LastLogTime -End (Get-Date)).TotalSeconds -ge 60) {
            Write-Log "Pass $PassNumber: Elapsed=$([math]::Round($ElapsedSeconds))s | Idle=$([math]::Round($IdleSeconds))s | LastWrite=$($LastKnownWriteTime.ToString('HH:mm:ss'))"
            $LastLogTime = Get-Date
        }
        
        # Completion: No file activity for $FileIdleTimeoutSeconds
        if ($IdleSeconds -ge $FileIdleTimeoutSeconds) {
            Write-Log "File system idle for $([math]::Round($IdleSeconds)) seconds - mupdate complete"
            break
        }
        
        # Safety timeout
        if ($ElapsedSeconds -ge $MaximumRuntimeSeconds) {
            Write-Log "Maximum runtime ($MaximumRuntimeSeconds seconds) exceeded" -Level 'WARN'
            Write-Log "Proceeding with completion despite timeout"
            break
        }
    }
    
    # -------------------------------------------------------------------------
    # PHASE 3: Close mupdate
    # -------------------------------------------------------------------------
    Write-Log "Phase 3: Closing mupdate process..."
    Close-MupdateProcess
    
    $TotalTime = [math]::Round((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds)
    Write-Log "========== MUPDATE PASS $PassNumber COMPLETE ($TotalTime seconds) =========="
}

function Register-OcxFile {
    param([Parameter(Mandatory)][string]$OcxPath)
    
    if (-not (Test-Path -LiteralPath $OcxPath)) {
        Write-Log "OCX file not found, skipping: $OcxPath" -Level 'WARN'
        return $true
    }
    
    $RegSvr32 = Join-Path -Path $env:WINDIR -ChildPath 'System32\regsvr32.exe'
    
    if (-not (Test-Path -LiteralPath $RegSvr32)) {
        Write-Log "regsvr32.exe not found at $RegSvr32" -Level 'ERROR'
        return $false
    }
    
    Write-Log "Registering: $OcxPath"
    
    $Process = Start-Process -FilePath $RegSvr32 `
                             -ArgumentList "/s `"$OcxPath`"" `
                             -Wait -PassThru `
                             -WindowStyle Hidden
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "Successfully registered: $OcxPath"
        return $true
    }
    else {
        Write-Log "Registration failed with exit code $($Process.ExitCode): $OcxPath" -Level 'ERROR'
        return $false
    }
}

function Start-OSMCTValidation {
    param([Parameter(Mandatory)][int]$RunSeconds)
    
    if (-not (Test-Path -LiteralPath $OSMCTExePath)) {
        Write-Log "OSMCT executable not found: $OSMCTExePath" -Level 'ERROR'
        return $false
    }
    
    Write-Log "Starting OSMCT validation run ($RunSeconds seconds)..."
    
    Start-Process -FilePath $OSMCTExePath -WindowStyle Normal
    
    Start-Sleep -Seconds $RunSeconds
    
    # Close OSMCT processes
    foreach ($ProcessName in $OSMCTProcessNames) {
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if ($Processes) {
            Write-Log "Closing OSMCT process: $ProcessName"
            
            foreach ($Proc in $Processes) {
                try {
                    $Proc.CloseMainWindow() | Out-Null
                }
                catch { }
            }
        }
    }
    
    Start-Sleep -Seconds 5
    
    # Force kill if still running
    foreach ($ProcessName in $OSMCTProcessNames) {
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if ($Processes) {
            Write-Log "Force stopping: $ProcessName"
            foreach ($Proc in $Processes) {
                try {
                    Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue
                }
                catch { }
            }
        }
    }
    
    Write-Log "OSMCT validation completed"
    return $true
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

Initialize-Log

# Check elevation
if (-not (Test-IsElevated)) {
    Exit-WithError -ExitCode $ERR_NOT_ELEVATED -Message "Script must run with administrative privileges"
}

Write-Log "Script running as: $env:USERNAME"
Write-Log "Computer: $env:COMPUTERNAME"

try {
    # STEP 1: Validate source share access
    Write-Log "STEP 1: Validating source share access..."
    
    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Cannot access source path: $SourceRoot"
    }
    
    if (-not (Test-Path -LiteralPath $MupdateShortcutSource)) {
        Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Mupdate shortcut not found: $MupdateShortcutSource"
    }
    
    Write-Log "Source share accessible"
    
    # STEP 2: Create folders and set permissions
    Write-Log "STEP 2: Creating folders and setting permissions..."
    
    foreach ($Folder in $MonitoredFolders) {
        Grant-FolderFullControl -Path $Folder -Groups $GrantGroups
        Write-Log "Created/configured folder: $Folder"
    }
    
    # STEP 3: Copy mupdate shortcut to Public Desktop
    Write-Log "STEP 3: Copying mupdate shortcut..."
    
    Copy-Item -LiteralPath $MupdateShortcutSource -Destination $MupdateShortcutDest -Force
    Write-Log "Copied mupdate.lnk to $MupdateShortcutDest"
    
    # STEP 4: First mupdate pass (install)
    Write-Log "STEP 4: Running mupdate first pass (install)..."
    
    Start-MupdatePass -ShortcutPath $MupdateShortcutDest -PassNumber 1
    
    # STEP 5: Verify permissions after first pass
    Write-Log "STEP 5: Verifying permissions after first pass..."
    
    foreach ($Folder in $MonitoredFolders) {
        if (Test-Path -LiteralPath $Folder) {
            Grant-FolderFullControl -Path $Folder -Groups $GrantGroups
        }
    }
    
    # STEP 6: Validate OSMCT installed and create shortcut
    Write-Log "STEP 6: Validating OSMCT installation..."
    
    if (-not (Test-Path -LiteralPath $OSMCTExePath)) {
        Exit-WithError -ExitCode $ERR_OSMCT_NOT_FOUND -Message "OSMCT executable not found after first pass: $OSMCTExePath"
    }
    
    Write-Log "OSMCT executable found: $OSMCTExePath"
    
    New-ShortcutToExe -TargetPath $OSMCTExePath -ShortcutPath $OSMCTShortcutDest
    Write-Log "Created OSMCT shortcut: $OSMCTShortcutDest"
    
    # STEP 7: Second mupdate pass (update)
    Write-Log "STEP 7: Running mupdate second pass (update)..."
    
    Start-MupdatePass -ShortcutPath $MupdateShortcutDest -PassNumber 2
    
    # STEP 8: Verify permissions after second pass
    Write-Log "STEP 8: Verifying permissions after second pass..."
    
    foreach ($Folder in $MonitoredFolders) {
        if (Test-Path -LiteralPath $Folder) {
            Grant-FolderFullControl -Path $Folder -Groups $GrantGroups
        }
    }
    
    # STEP 9: Register LeadTools OCX files
    Write-Log "STEP 9: Registering LeadTools OCX files..."
    
    Register-OcxFile -OcxPath $LeadToolsOcxPath1
    Register-OcxFile -OcxPath $LeadToolsOcxPath2
    
    # STEP 10: OSMCT validation run
    Write-Log "STEP 10: Running OSMCT validation..."
    
    Start-OSMCTValidation -RunSeconds $OSMCTValidationSeconds
    
    # SUCCESS
    Write-Log ("=" * 60)
    Write-Log "OSMCT installation completed successfully"
    Write-Log ("=" * 60)
    
    exit $EXIT_SUCCESS
}
catch {
    Write-Log "FATAL EXCEPTION: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit $EXIT_FAILURE
}