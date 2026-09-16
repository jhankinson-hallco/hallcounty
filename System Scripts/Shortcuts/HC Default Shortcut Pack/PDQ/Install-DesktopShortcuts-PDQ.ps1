#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: installs the Hall County default shortcut pack to the Public Desktop.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-DesktopShortcuts.ps1 (v1.1.2). Unlike the Intune package, which
    bundles its own copies, this script pulls every shortcut and icon from the
    shared deployment repository on the filestore - the same repository used by
    the standalone shortcut deployments.

    Process for each shortcut:
    1. Copies the icon from the repository to C:\ProgramData\Microsoft\IntuneManagementExtension\Images
    2. Copies the shortcut from the repository to C:\Users\Public\Desktop
    3. Updates the shortcut to reference the locally stored icon

    TANDEM PARITY: the end state is identical to the Intune install, so the
    Intune detection script (Detect.ps1) passes no matter which channel
    deployed the pack. Any change to the shortcut list or on-device footprint
    must be made in BOTH this script and the Intune install script.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_DesktopShortcuts_Install.txt
    (same file as the Intune install; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (all shortcuts deployed)
        1 = Failure (one or more shortcuts failed)

.NOTES
    Version:        1.0.2
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Deploy the Hall County default Public Desktop shortcut pack via PDQ

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; hardened shortcut icon handling; tandem with Intune counterpart v1.1.2 -- ver. 1.0.2
    Change: 13/07/2026 - Added per-file copy verification, tandem with Intune Install-DesktopShortcuts.ps1 v1.1.1 -- ver. 1.0.1
    Change: 13/07/2026 - Initial PDQ release, tandem with Intune Install-DesktopShortcuts.ps1 v1.1.0 -- ver. 1.0.0

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
# Keep this list synchronized with the Intune Install-DesktopShortcuts.ps1,
# Detect.ps1, and both uninstall scripts.

$script:AppName = 'DesktopShortcuts'

$script:Shortcuts = @(
    @{
        ShortcutFile = 'ADP (Workforcenow).url'
        IconFile     = 'ADP Icon.ico'
    },
    @{
        ShortcutFile = 'My Account Settings.url'
        IconFile     = 'Hall County Logo Icon.ico'
    },
    @{
        ShortcutFile = 'Office 365 Web Apps.url'
        IconFile     = 'Office 365 Web App Icon.ico'
    },
    @{
        ShortcutFile = 'Webmail.url'
        IconFile     = 'Webmail Icon.ico'
    }
)

# Shared deployment repository on the filestore (PDQ scripts only)
$script:RepoShortcutFolder = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts'
$script:RepoIconFolder     = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Icons'

# Destination roots (current IME-rooted environment standard; must match Intune)
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

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

function Install-SingleShortcut {
    # Installs one shortcut with its icon from the repository.
    # Returns $true on success, $false on failure.
    param(
        [string]$ShortcutFile,
        [string]$IconFile
    )

    $Name = [System.IO.Path]::GetFileNameWithoutExtension($ShortcutFile)

    $SourceShortcutPath = Join-Path -Path $script:RepoShortcutFolder -ChildPath $ShortcutFile
    $SourceIconPath     = Join-Path -Path $script:RepoIconFolder -ChildPath $IconFile
    $DestShortcutPath   = Join-Path -Path $script:PublicDesktopPath -ChildPath $ShortcutFile
    $DestIconPath       = Join-Path -Path $script:IconFolder -ChildPath $IconFile

    if (-not (Test-Path -LiteralPath $SourceShortcutPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] SOURCE SHORTCUT NOT FOUND (Network/Repository): '$SourceShortcutPath'." -ErrorCode 'SRC_SHORTCUT_NOT_FOUND'
        return $false
    }
    if (-not (Test-Path -LiteralPath $SourceIconPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] SOURCE ICON NOT FOUND (Network/Repository): '$SourceIconPath'." -ErrorCode 'SRC_ICON_NOT_FOUND'
        return $false
    }

    try {
        Copy-Item -LiteralPath $SourceIconPath -Destination $DestIconPath -Force -ErrorAction Stop
    }
    catch {
        Write-ErrorLog -Message "[$Name] ICON COPY FAILED (Network/System): $($_.Exception.Message)" -ErrorCode 'ICON_COPY_FAIL'
        return $false
    }
    if (-not (Test-Path -LiteralPath $DestIconPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] ICON COPY VERIFICATION FAILED (System): icon not found at '$DestIconPath' after copy." -ErrorCode 'ICON_VERIFY_FAIL'
        return $false
    }

    try {
        Copy-Item -LiteralPath $SourceShortcutPath -Destination $DestShortcutPath -Force -ErrorAction Stop
    }
    catch {
        Write-ErrorLog -Message "[$Name] SHORTCUT COPY FAILED (Network/System): $($_.Exception.Message)" -ErrorCode 'SHORTCUT_COPY_FAIL'
        return $false
    }
    if (-not (Test-Path -LiteralPath $DestShortcutPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] SHORTCUT COPY VERIFICATION FAILED (System): shortcut not found at '$DestShortcutPath' after copy." -ErrorCode 'SHORTCUT_VERIFY_FAIL'
        return $false
    }

    try {
        Set-ShortcutIconReference -ShortcutPath $DestShortcutPath -IconPath $DestIconPath
    }
    catch {
        Write-ErrorLog -Message "[$Name] SHORTCUT ICON UPDATE FAILED (App): $($_.Exception.Message)" -ErrorCode 'ICON_UPDATE_FAIL'
        return $false
    }

    return $true
}

# =============================================================================
# MAIN
# =============================================================================

try {
    # Create the IME-rooted icon folder once, up front
    try {
        New-Item -ItemType Directory -Path $script:IconFolder -Force -ErrorAction Stop | Out-Null
    }
    catch {
        $Message = "ICON FOLDER CREATION FAILED (System/Permissions): could not create '$($script:IconFolder)'. Error: $($_.Exception.Message)"
        Write-ErrorLog -Message $Message -ErrorCode 'FOLDER_CREATE_FAIL'
        Write-Output $Message
        exit 1
    }

    $FailedCount = 0
    $SuccessCount = 0

    foreach ($Entry in $script:Shortcuts) {
        if (Install-SingleShortcut -ShortcutFile $Entry.ShortcutFile -IconFile $Entry.IconFile) {
            $SuccessCount++
        }
        else {
            $FailedCount++
        }
    }

    if ($FailedCount -gt 0) {
        $Message = "Desktop shortcut pack (PDQ) completed with errors: $SuccessCount succeeded, $FailedCount failed."
        Write-ErrorLog -Message $Message -ErrorCode 'PARTIAL_FAIL'
        Write-Output $Message
        exit 1
    }

    Write-Output "$($script:AppName) v1.0.2 (PDQ) deployed: $SuccessCount shortcuts installed from the repository."
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
