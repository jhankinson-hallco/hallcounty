#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Updates the icon of the existing Operative IQ shortcut on the Public Desktop.

.DESCRIPTION
    Intune Platform Script. If the shortcut exists on the Public Desktop, copies
    the icon from the network share to the IME-rooted Images folder and points
    the shortcut at the local copy. If the shortcut does not exist, exits 0
    silently (no action needed).

    Requires on-prem network connectivity to the file share. Not White Glove
    safe; deploy only to devices with domain network access after sign-in.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_OperativeIQShortcut_IconUpdate.txt.

    Exit Codes:
        0 = Success (icon updated OR shortcut not present)
        1 = Failure (an error occurred during execution)

.NOTES
    Version:        1.1.1
    Script Type:    Microsoft Intune Platform Script
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Refresh the Operative IQ shortcut icon from the network share

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; hardened shortcut icon handling -- ver. 1.1.1
    Change: 13/07/2026 - Standardized to IME-rooted runtime paths, PS 5.1 hardening, normalized network source path -- ver. 1.1.0

    INTUNE CONFIGURATION
      Run this script using the logged on credentials: No (runs as SYSTEM)
      Enforce script signature check: No
      Run script in 64-bit PowerShell: Yes
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'OperativeIQShortcut'
$script:ShortcutFileName = 'Operative IQ.url'
$script:IconFileName     = 'Operative IQ Icon.ico'

# Network source folder for icon files
$script:NetworkIconSourcePath = '\\hallcounty\filestore\mis\CDS\Intune Files\Shortcut Icons'

$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

$script:ShortcutPath   = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName
$script:SourceIconPath = Join-Path -Path $script:NetworkIconSourcePath -ChildPath $script:IconFileName
$script:DestIconPath   = Join-Path -Path $script:IconFolder -ChildPath $script:IconFileName

$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_' + $script:AppName + '_IconUpdate.txt')

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
        $LogEntry = "[$Timestamp] [$($env:COMPUTERNAME)] [$ErrorCode] $Message"
        Add-Content -LiteralPath $script:LogFile -Value $LogEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Stop-WithError {
    # Logs the failure, reports it on STDOUT for IME capture, and exits 1.
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
    # If the shortcut is not deployed, there is nothing to update.
    if (-not (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)) {
        exit 0
    }

    if (-not (Test-Path -LiteralPath $script:SourceIconPath -PathType Leaf)) {
        Stop-WithError -Message "SOURCE ICON NOT FOUND (Network): icon not found at '$($script:SourceIconPath)'. Verify share access and file name." -ErrorCode 'SRC_NOT_FOUND'
    }

    try {
        New-Item -ItemType Directory -Path $script:IconFolder -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Stop-WithError -Message "ICON FOLDER CREATION FAILED (System/Permissions): could not create '$($script:IconFolder)'. Error: $($_.Exception.Message)" -ErrorCode 'FOLDER_CREATE_FAIL'
    }

    try {
        Copy-Item -LiteralPath $script:SourceIconPath -Destination $script:DestIconPath -Force -ErrorAction Stop
    }
    catch {
        Stop-WithError -Message "ICON COPY FAILED (Network/System): could not copy icon to '$($script:DestIconPath)'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_COPY_FAIL'
    }
    if (-not (Test-Path -LiteralPath $script:DestIconPath -PathType Leaf)) {
        Stop-WithError -Message "ICON COPY VERIFICATION FAILED (System): icon not found at '$($script:DestIconPath)' after copy." -ErrorCode 'ICON_VERIFY_FAIL'
    }

    try {
        Set-ShortcutIconReference -ShortcutPath $script:ShortcutPath -IconPath $script:DestIconPath
    }
    catch {
        Stop-WithError -Message "SHORTCUT ICON UPDATE FAILED (App): could not update icon reference for '$($script:ShortcutPath)'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_UPDATE_FAIL'
    }

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