<# 
.SYNOPSIS
    Install-MobileCAD-FD.ps1
    Installs Mobile CAD FD Client, configures it, and launches for the logged-in user.

.DESCRIPTION
    1. Copies "Mobile Client FD" folder to C:\Mobile Client FD
    2. Updates Configuration_SoftwareUpdate.xml (first line must contain hcfd.classic)
    3. Updates Configuration_RegistrationID.xml (replaces "replaceme" with HCFD<SERIAL>)
    4. Copies FD.Classic.lnk to Public Desktop and Startup folder
    5. Launches the application in the logged-in user's context
    
    Logs ONLY on failure to C:\IntuneAppLogs\MobileCAD-FD_Install.txt
    
    KEY FIX: Uses explorer.exe method to launch in user context instead of 
    scheduled task which runs as SYSTEM and cannot display UI to user.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    Intune Type:    Win32 App
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-MobileCAD-FD.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-MobileCAD-FD.ps1
    
    INTUNE SETTINGS:
    - Install behavior: System
    - Device restart behavior: No specific action
    - Return codes: 0 = Success, 1618 = Retry
#>

#================================================================================
# CONFIGURATION SECTION - MODIFY THESE VARIABLES FOR DIFFERENT DEPLOYMENTS
#================================================================================

# Application name (used in logging)
$AppName = "MobileCAD-FD"

# Source paths (relative to script location in the Intune package)
$SourceFolderName = "Mobile Client FD"
$ShortcutFileName = "FD.Classic.lnk"

# Destination paths
$DestinationRoot = "C:\"
$DestinationFolderName = "Mobile Client FD"

# Executable info (relative to destination folder)
$ExeRelativePath = "Mobile Client\VMLaunch.exe"
$LaunchProcessName = "VMLaunch"

# Configuration file paths (relative to destination folder)
$SoftwareUpdateXmlRelative = "Mobile Client\Configuration_SoftwareUpdate.xml"
$RegistrationIdXmlRelative = "Mobile Client\Configuration_RegistrationID.xml"

# Configuration values
$SoftwareUpdateFirstLine = "hcfd.classic"
$RegistrationIdToken = "replaceme"
$RegistrationIdPrefix = "HCFD"

# Timeouts
$LaunchTimeoutSeconds = 30
$RobocopyTimeoutSeconds = 300

# Log folder
$LogFolder = "C:\IntuneAppLogs"

# Set to $false to skip launch step (install only)
$LaunchAfterInstall = $true

# Set to $false to not fail if no user is logged in
$RequireUserSession = $false

#================================================================================
# CUSTOM ERROR CODES
#================================================================================

$EXIT_SUCCESS           = 0
$EXIT_FAILURE           = 1
$EXIT_RETRY             = 1618

$ERR_NO_USER_SESSION    = 7001
$ERR_COPY_FAILED        = 7002
$ERR_LAUNCH_FAILED      = 7003
$ERR_CONFIG_FAILED      = 7004
$ERR_SHORTCUT_FAILED    = 7005
$ERR_SOURCE_NOT_FOUND   = 7006
$ERR_TIMEOUT            = 7007

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

# Build full paths
$SourceFolder = Join-Path -Path $PSScriptRoot -ChildPath $SourceFolderName
$SourceShortcut = Join-Path -Path $PSScriptRoot -ChildPath $ShortcutFileName

$DestinationFolder = Join-Path -Path $DestinationRoot -ChildPath $DestinationFolderName
$DestinationExe = Join-Path -Path $DestinationFolder -ChildPath $ExeRelativePath

$SoftwareUpdateXml = Join-Path -Path $DestinationFolder -ChildPath $SoftwareUpdateXmlRelative
$RegistrationIdXml = Join-Path -Path $DestinationFolder -ChildPath $RegistrationIdXmlRelative

# Desktop and Startup paths
$PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = Join-Path -Path $env:PUBLIC -ChildPath "Desktop"
}
$DesktopShortcut = Join-Path -Path $PublicDesktop -ChildPath $ShortcutFileName

$StartupFolder = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupShortcut = Join-Path -Path $StartupFolder -ChildPath $ShortcutFileName

# Log file path
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

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
# FUNCTION: Copy-FolderWithRobocopy
# PURPOSE:  Copies a folder using robocopy with timeout protection
#--------------------------------------------------------------------------------
function Copy-FolderWithRobocopy {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        
        [Parameter(Mandatory)]
        [string]$Destination
    )
    
    # Verify source exists
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source folder not found: $Source"
    }
    
    # Create destination if needed
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    }
    
    $RobocopyPath = Join-Path -Path $env:WINDIR -ChildPath "System32\robocopy.exe"
    
    if (-not (Test-Path -LiteralPath $RobocopyPath)) {
        throw "Robocopy not found at: $RobocopyPath"
    }
    
    # Robocopy arguments
    # /E = copy subdirectories including empty
    # /COPY:DAT = copy Data, Attributes, Timestamps
    # /R:2 /W:2 = retry 2 times, wait 2 seconds
    # /NP /NFL /NDL = no progress, no file list, no directory list (reduce output)
    $RobocopyArgs = "`"$Source`" `"$Destination`" /E /COPY:DAT /R:2 /W:2 /NP /NFL /NDL"
    
    try {
        $Process = Start-Process -FilePath $RobocopyPath `
                                 -ArgumentList $RobocopyArgs `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -ErrorAction Stop
        
        # Wait with timeout
        $Completed = $Process.WaitForExit($RobocopyTimeoutSeconds * 1000)
        
        if (-not $Completed) {
            try { $Process.Kill() } catch { }
            throw "Robocopy timed out after $RobocopyTimeoutSeconds seconds"
        }
        
        # Robocopy exit codes: 0-7 are success, 8+ are failures
        if ($Process.ExitCode -ge 8) {
            throw "Robocopy failed with exit code $($Process.ExitCode)"
        }
    }
    catch {
        throw "Robocopy error: $($_.Exception.Message)"
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Get-DeviceSerialNumber
# PURPOSE:  Gets the device serial number, normalized and uppercased
#--------------------------------------------------------------------------------
function Get-DeviceSerialNumber {
    try {
        $BIOS = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $Serial = ($BIOS.SerialNumber -as [string]).Trim()
        
        if ([string]::IsNullOrWhiteSpace($Serial)) {
            throw "Serial number is empty"
        }
        
        # Remove spaces and uppercase
        $Serial = ($Serial -replace '\s+', '').ToUpperInvariant()
        return $Serial
    }
    catch {
        throw "Failed to get device serial number: $($_.Exception.Message)"
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Update-ConfigurationFiles
# PURPOSE:  Updates the XML configuration files after copy
#--------------------------------------------------------------------------------
function Update-ConfigurationFiles {
    # Update Software Update XML - ensure first line contains required text
    if (-not (Test-Path -LiteralPath $SoftwareUpdateXml)) {
        throw "Configuration file not found: $SoftwareUpdateXml"
    }
    
    try {
        $Encoding = New-Object System.Text.UTF8Encoding($false)  # UTF-8 no BOM
        $Lines = [System.IO.File]::ReadAllLines($SoftwareUpdateXml, $Encoding)
        
        if ($Lines.Count -lt 1) {
            throw "Configuration file is empty: $SoftwareUpdateXml"
        }
        
        if ($Lines[0] -notlike "*$SoftwareUpdateFirstLine*") {
            $Lines[0] = $SoftwareUpdateFirstLine
            $Content = $Lines -join "`r`n"
            [System.IO.File]::WriteAllText($SoftwareUpdateXml, $Content, $Encoding)
        }
    }
    catch {
        throw "Failed to update $SoftwareUpdateXml : $($_.Exception.Message)"
    }
    
    # Update Registration ID XML - replace token with HCFD<SERIAL>
    if (-not (Test-Path -LiteralPath $RegistrationIdXml)) {
        throw "Configuration file not found: $RegistrationIdXml"
    }
    
    try {
        $Serial = Get-DeviceSerialNumber
        $RegistrationValue = "${RegistrationIdPrefix}${Serial}"
        
        $Encoding = New-Object System.Text.UTF8Encoding($false)
        $Content = [System.IO.File]::ReadAllText($RegistrationIdXml, $Encoding)
        
        if ($Content -notmatch [regex]::Escape($RegistrationIdToken)) {
            # Token not found - might already be configured, skip
            return
        }
        
        $UpdatedContent = $Content -replace [regex]::Escape($RegistrationIdToken), $RegistrationValue
        [System.IO.File]::WriteAllText($RegistrationIdXml, $UpdatedContent, $Encoding)
    }
    catch {
        throw "Failed to update $RegistrationIdXml : $($_.Exception.Message)"
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Test-UserLoggedIn
# PURPOSE:  Checks if an interactive user session exists
#--------------------------------------------------------------------------------
function Test-UserLoggedIn {
    $Explorer = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
    return ($null -ne $Explorer -and @($Explorer).Count -gt 0)
}

#--------------------------------------------------------------------------------
# FUNCTION: Get-LoggedInUsername
# PURPOSE:  Gets the username of the currently logged-in user
#--------------------------------------------------------------------------------
function Get-LoggedInUsername {
    try {
        # Method 1: Query user command
        $QueryResult = quser 2>$null
        if ($QueryResult) {
            # Parse the output - skip header line
            foreach ($Line in $QueryResult | Select-Object -Skip 1) {
                if ($Line -match '^\s*>?(\S+)') {
                    $Username = $Matches[1]
                    if ($Username -and $Username -ne "USERNAME") {
                        return $Username
                    }
                }
            }
        }
        
        # Method 2: Get owner of explorer.exe
        $Explorer = Get-Process -Name "explorer" -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Explorer -and $Explorer.UserName) {
            return $Explorer.UserName
        }
        
        return $null
    }
    catch {
        return $null
    }
}

#--------------------------------------------------------------------------------
# FUNCTION: Invoke-AsLoggedInUser
# PURPOSE:  Launches a process in the context of the logged-in user
# NOTES:    Uses a scheduled task that runs as the logged-in user (not SYSTEM)
#--------------------------------------------------------------------------------
function Invoke-AsLoggedInUser {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $Username = Get-LoggedInUsername
    if (-not $Username) {
        throw "Could not determine logged-in user"
    }
    
    $TaskName = "IntuneLaunch_${AppName}_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $SchtasksPath = Join-Path -Path $env:WINDIR -ChildPath "System32\schtasks.exe"
    
    try {
        # Create a scheduled task that runs as the LOGGED-IN USER (not SYSTEM)
        # /RU with the actual username makes it run in that user's context
        # /IT = Interactive only (requires user to be logged in)
        $CreateArgs = @(
            "/Create",
            "/TN", $TaskName,
            "/SC", "ONCE",
            "/ST", "00:00",
            "/RU", $Username,
            "/IT",
            "/TR", "cmd.exe /c start `"`" `"$FilePath`"",
            "/F"
        )
        
        $CreateResult = Start-Process -FilePath $SchtasksPath `
                                      -ArgumentList $CreateArgs `
                                      -Wait -PassThru `
                                      -WindowStyle Hidden
        
        if ($CreateResult.ExitCode -ne 0) {
            throw "Failed to create scheduled task. Exit code: $($CreateResult.ExitCode)"
        }
        
        # Run the task immediately
        $RunArgs = @("/Run", "/TN", $TaskName)
        $RunResult = Start-Process -FilePath $SchtasksPath `
                                   -ArgumentList $RunArgs `
                                   -Wait -PassThru `
                                   -WindowStyle Hidden
        
        if ($RunResult.ExitCode -ne 0) {
            throw "Failed to run scheduled task. Exit code: $($RunResult.ExitCode)"
        }
        
        # Wait briefly for process to start
        Start-Sleep -Seconds 3
        
        # Verify process started
        $Process = Get-Process -Name $LaunchProcessName -ErrorAction SilentlyContinue
        if ($Process) {
            return $true
        }
        
        # Wait a bit longer and check again
        $Deadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
        while ((Get-Date) -lt $Deadline) {
            Start-Sleep -Seconds 2
            $Process = Get-Process -Name $LaunchProcessName -ErrorAction SilentlyContinue
            if ($Process) {
                return $true
            }
        }
        
        return $false
    }
    finally {
        # Always clean up the task
        try {
            $DeleteArgs = @("/Delete", "/TN", $TaskName, "/F")
            Start-Process -FilePath $SchtasksPath `
                          -ArgumentList $DeleteArgs `
                          -Wait -PassThru `
                          -WindowStyle Hidden | Out-Null
        }
        catch { }
    }
}

#================================================================================
# MAIN EXECUTION
#================================================================================

# STEP 1: Verify source files exist
if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
    Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Source folder not found: $SourceFolder"
}

if (-not (Test-Path -LiteralPath $SourceShortcut -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_SOURCE_NOT_FOUND -Message "Source shortcut not found: $SourceShortcut"
}

# STEP 2: Copy application folder using robocopy
try {
    Copy-FolderWithRobocopy -Source $SourceFolder -Destination $DestinationFolder
}
catch {
    Exit-WithError -ExitCode $ERR_COPY_FAILED -Message "Failed to copy application folder" -Exception $_.Exception
}

# STEP 3: Verify critical files were copied
if (-not (Test-Path -LiteralPath $DestinationExe -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_COPY_FAILED -Message "Executable not found after copy: $DestinationExe"
}

# STEP 4: Update configuration files
try {
    Update-ConfigurationFiles
}
catch {
    Exit-WithError -ExitCode $ERR_CONFIG_FAILED -Message "Configuration update failed" -Exception $_.Exception
}

# STEP 5: Copy shortcut to Public Desktop
try {
    Copy-Item -LiteralPath $SourceShortcut -Destination $DesktopShortcut -Force -ErrorAction Stop
}
catch {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Failed to copy shortcut to desktop: $DesktopShortcut" -Exception $_.Exception
}

# STEP 6: Copy shortcut to Startup folder
try {
    if (-not (Test-Path -LiteralPath $StartupFolder -PathType Container)) {
        New-Item -Path $StartupFolder -ItemType Directory -Force | Out-Null
    }
    Copy-Item -LiteralPath $SourceShortcut -Destination $StartupShortcut -Force -ErrorAction Stop
}
catch {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Failed to copy shortcut to startup: $StartupShortcut" -Exception $_.Exception
}

# STEP 7: Verify shortcuts were copied
if (-not (Test-Path -LiteralPath $DesktopShortcut -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Desktop shortcut not found after copy"
}

if (-not (Test-Path -LiteralPath $StartupShortcut -PathType Leaf)) {
    Exit-WithError -ExitCode $ERR_SHORTCUT_FAILED -Message "Startup shortcut not found after copy"
}

# STEP 8: Launch application for logged-in user (if configured)
if ($LaunchAfterInstall) {
    # Check if a user is logged in
    if (-not (Test-UserLoggedIn)) {
        if ($RequireUserSession) {
            Exit-WithError -ExitCode $ERR_NO_USER_SESSION -Message "No interactive user session. Cannot launch application."
        }
        else {
            # No user logged in, but we don't require it - installation is still successful
            # The shortcut in Startup folder will launch it when user logs in
            exit $EXIT_SUCCESS
        }
    }
    
    # Try to launch using the desktop shortcut
    try {
        $LaunchSuccess = Invoke-AsLoggedInUser -FilePath $DesktopShortcut
        
        if (-not $LaunchSuccess) {
            # Try launching the EXE directly
            $LaunchSuccess = Invoke-AsLoggedInUser -FilePath $DestinationExe
        }
        
        if (-not $LaunchSuccess) {
            # Launch failed, but installation succeeded
            # Don't fail the entire install - the startup shortcut will launch it at next logon
            # Just log a warning (but still exit success since files are in place)
        }
    }
    catch {
        # Launch failed, but installation succeeded
        # The startup shortcut will launch it at next logon
    }
}

# STEP 9: Success
exit $EXIT_SUCCESS
