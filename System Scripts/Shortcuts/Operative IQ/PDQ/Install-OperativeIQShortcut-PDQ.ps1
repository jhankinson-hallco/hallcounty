#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: installs the Operative IQ shortcut to the Public Desktop with its custom icon.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-OperativeIQShortcut.ps1 (v1.1.1). Pulls the shortcut and icon from the shared
    deployment repository on the filestore instead of a bundled package.

    Process:
    1. Copies the icon from the repository to C:\ProgramData\Microsoft\IntuneManagementExtension\Images
    2. Copies the shortcut from the repository to C:\Users\Public\Desktop
    3. Updates the shortcut to reference the locally stored icon

    TANDEM PARITY: the end state is identical to the Intune install, so the
    Intune detection script (Detect.ps1) passes no matter which channel
    deployed the shortcut. Any change to the on-device footprint must be made
    in BOTH this script and the Intune install script.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_OperativeIQShortcut_Install.txt
    (same file as the Intune install; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (shortcut deployed and icon set)
        1 = Failure (an error occurred during execution)

.NOTES
    Version:        1.0.1
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Deploy the Operative IQ Public Desktop shortcut with custom icon via PDQ

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; hardened shortcut icon handling; tandem with Intune counterpart v1.1.1 -- ver. 1.0.1
    Change: 13/07/2026 - Initial PDQ release, tandem with Intune Install-OperativeIQShortcut.ps1 v1.1.0 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running this single script (no extra files needed)
      Run As:        Deploy User (requires READ access to the filestore repository;
                     do NOT use Local System - it cannot reach the share)
      Success codes: 0

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      Shortcuts: \\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts
      Icons:     \\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Icons
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'OperativeIQShortcut'
$script:ShortcutFileName = 'Operative IQ.url'
$script:IconFileName     = 'Operative IQ Icon.ico'

# Shared deployment repository on the filestore (PDQ scripts only)
$script:RepoShortcutFolder = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts'
$script:RepoIconFolder     = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Icons'

# Destination roots (current IME-rooted environment standard; must match Intune)
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

# Source paths (filestore repository)
$script:SourceShortcutPath = Join-Path -Path $script:RepoShortcutFolder -ChildPath $script:ShortcutFileName
$script:SourceIconPath     = Join-Path -Path $script:RepoIconFolder -ChildPath $script:IconFileName

# Destination paths
$script:DestShortcutPath = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName
$script:DestIconPath     = Join-Path -Path $script:IconFolder -ChildPath $script:IconFileName

# Error-only log file (shared with the Intune install; entries tagged [PDQ])
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_' + $script:AppName + '_Install.txt')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw; all I/O uses SilentlyContinue.
    param(
        [string]$Message,
        [string]$ErrorCode = 'N/A'
    )
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $LogEntry = "[$Timestamp] [$($env:COMPUTERNAME)] [PDQ] [$ErrorCode] $Message"
        Add-Content -LiteralPath $script:LogFile -Value $LogEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Stop-WithError {
    # Logs the failure, reports it on STDOUT for PDQ output capture, and exits 1.
    param(
        [string]$Message,
        [string]$ErrorCode
    )
    Write-ErrorLog -Message $Message -ErrorCode $ErrorCode
    Write-Output $Message
    exit 1
}

function Set-ShortcutIconReference {
    # Points a deployed shortcut (.lnk or .url) at the locally stored icon.
    param(
        [string]$ShortcutPath,
        [string]$IconPath
    )
    $Extension = [System.IO.Path]::GetExtension($ShortcutPath).ToLower()

    if ($Extension -eq '.lnk') {
        $WshShell = $null
        $Shortcut = $null
        try {
            $WshShell = New-Object -ComObject WScript.Shell -ErrorAction Stop
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            $Shortcut.IconLocation = "$IconPath,0"
            $Shortcut.Save()
        }
        finally {
            if ($null -ne $Shortcut) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null
            }
            if ($null -ne $WshShell) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
            }
        }
    }
    elseif ($Extension -eq '.url') {
        # .url files are INI format; keep icon keys inside [InternetShortcut].
        $Content = @(Get-Content -LiteralPath $ShortcutPath -ErrorAction Stop)
        $NewContent = @()
        $InternetShortcutFound = $false
        $InInternetShortcut = $false
        $IconFileSet = $false
        $IconIndexSet = $false
        $IconLinesInserted = $false

        foreach ($Line in $Content) {
            if ($Line -match '^\s*\[InternetShortcut\]\s*$') {
                $InternetShortcutFound = $true
                $InInternetShortcut = $true
                $NewContent += $Line
                continue
            }

            if ($Line -match '^\s*\[.+\]\s*$') {
                if ($InInternetShortcut -and -not $IconLinesInserted) {
                    if (-not $IconFileSet) { $NewContent += "IconFile=$IconPath" }
                    if (-not $IconIndexSet) { $NewContent += 'IconIndex=0' }
                    $IconLinesInserted = $true
                }
                $InInternetShortcut = $false
                $NewContent += $Line
                continue
            }

            if ($Line -match '^\s*IconFile=') {
                if ($InInternetShortcut) {
                    $NewContent += "IconFile=$IconPath"
                    $IconFileSet = $true
                }
                continue
            }

            if ($Line -match '^\s*IconIndex=') {
                if ($InInternetShortcut) {
                    $NewContent += 'IconIndex=0'
                    $IconIndexSet = $true
                }
                continue
            }

            $NewContent += $Line
        }

        if (-not $InternetShortcutFound) {
            throw "Malformed .url file '$ShortcutPath': missing [InternetShortcut] section."
        }

        if ($InInternetShortcut -and -not $IconLinesInserted) {
            if (-not $IconFileSet) { $NewContent += "IconFile=$IconPath" }
            if (-not $IconIndexSet) { $NewContent += 'IconIndex=0' }
        }

        $NewContent | Set-Content -LiteralPath $ShortcutPath -Force -ErrorAction Stop
    }
    else {
        throw "Unsupported shortcut type '$Extension'. Only .lnk and .url are supported."
    }
}

# =============================================================================
# MAIN
# =============================================================================

try {
    # Verify repository source files are reachable
    if (-not (Test-Path -LiteralPath $script:SourceShortcutPath -PathType Leaf)) {
        Stop-WithError -Message "SOURCE SHORTCUT NOT FOUND (Network/Repository): '$($script:SourceShortcutPath)' is not reachable. Verify share access for the PDQ deploy user and the repository file name." -ErrorCode 'SRC_SHORTCUT_NOT_FOUND'
    }
    if (-not (Test-Path -LiteralPath $script:SourceIconPath -PathType Leaf)) {
        Stop-WithError -Message "SOURCE ICON NOT FOUND (Network/Repository): '$($script:SourceIconPath)' is not reachable. Verify share access for the PDQ deploy user and the repository file name." -ErrorCode 'SRC_ICON_NOT_FOUND'
    }

    # Create the IME-rooted icon folder if needed
    try {
        New-Item -ItemType Directory -Path $script:IconFolder -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Stop-WithError -Message "ICON FOLDER CREATION FAILED (System/Permissions): could not create '$($script:IconFolder)'. Error: $($_.Exception.Message)" -ErrorCode 'FOLDER_CREATE_FAIL'
    }

    # Copy the icon and verify
    try {
        Copy-Item -LiteralPath $script:SourceIconPath -Destination $script:DestIconPath -Force -ErrorAction Stop
    }
    catch {
        Stop-WithError -Message "ICON COPY FAILED (Network/System): could not copy icon to '$($script:DestIconPath)'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_COPY_FAIL'
    }
    if (-not (Test-Path -LiteralPath $script:DestIconPath -PathType Leaf)) {
        Stop-WithError -Message "ICON COPY VERIFICATION FAILED (System): icon not found at '$($script:DestIconPath)' after copy." -ErrorCode 'ICON_VERIFY_FAIL'
    }

    # Copy the shortcut and verify
    try {
        Copy-Item -LiteralPath $script:SourceShortcutPath -Destination $script:DestShortcutPath -Force -ErrorAction Stop
    }
    catch {
        Stop-WithError -Message "SHORTCUT COPY FAILED (Network/System): could not copy shortcut to '$($script:DestShortcutPath)'. Error: $($_.Exception.Message)" -ErrorCode 'SHORTCUT_COPY_FAIL'
    }
    if (-not (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf)) {
        Stop-WithError -Message "SHORTCUT COPY VERIFICATION FAILED (System): shortcut not found at '$($script:DestShortcutPath)' after copy." -ErrorCode 'SHORTCUT_VERIFY_FAIL'
    }

    # Point the deployed shortcut at the local icon
    try {
        Set-ShortcutIconReference -ShortcutPath $script:DestShortcutPath -IconPath $script:DestIconPath
    }
    catch {
        Stop-WithError -Message "SHORTCUT ICON UPDATE FAILED (App): could not update icon reference for '$($script:DestShortcutPath)'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_UPDATE_FAIL'
    }

    Write-Output "$($script:AppName) v1.0.1 (PDQ) deployed: '$($script:DestShortcutPath)' with icon '$($script:DestIconPath)'."
    exit 0
}
catch {
    $Message = "UNEXPECTED ERROR (App/System): $($_.Exception.Message)"
    $Code = 'UNKNOWN'
    try { $Code = '0x{0:X8}' -f $_.Exception.HResult } catch { }
    Write-ErrorLog -Message $Message -ErrorCode $Code
    Write-Output $Message
    exit 1
}