#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Deploys the Hall County default shortcut pack to the Public Desktop.

.DESCRIPTION
    Intune Win32 App installation script. Processes an array of shortcut
    definitions so multiple shortcuts deploy from a single package.

    Process for each shortcut:
    1. Copies the icon file to C:\ProgramData\Microsoft\IntuneManagementExtension\Images
    2. Copies the shortcut file to C:\Users\Public\Desktop
    3. Updates the shortcut to reference the locally stored icon

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_DesktopShortcuts_Install.txt.

    Exit Codes:
        0 = Success (all shortcuts deployed)
        1 = Failure (one or more shortcuts failed)

.NOTES
    Version:        1.1.2
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Deploy the Hall County default Public Desktop shortcut pack

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; hardened shortcut icon handling -- ver. 1.1.2
    Change: 13/07/2026 - Added per-file copy verification for pack installs -- ver. 1.1.1
    Change: 13/07/2026 - Standardized to IME-rooted runtime paths (Images, Logs), PS 5.1 hardening, error-only logging -- ver. 1.1.0

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-DesktopShortcuts.ps1
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-DesktopShortcuts.ps1
      Install behavior: System
      Device restart behavior: No specific action
      Detection rule: custom detection script Detect.ps1
        Run script as 32-bit process on 64-bit clients: No

    PACKAGE CONTENTS
      This script plus every .url/.lnk and .ico file listed in $script:Shortcuts.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================
# Each entry needs:
#   ShortcutFile = name of the .lnk or .url file in the package
#   IconFile     = name of the .ico file in the package
# Keep this list synchronized with Detect.ps1 and Uninstall-DesktopShortcuts.ps1.

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

# Destination roots (current IME-rooted environment standard)
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
        $LogEntry = "[$Timestamp] [$($env:COMPUTERNAME)] [$ErrorCode] $Message"
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
    # Installs one shortcut with its icon. Returns $true on success, $false on failure.
    param(
        [string]$ShortcutFile,
        [string]$IconFile
    )

    $Name = [System.IO.Path]::GetFileNameWithoutExtension($ShortcutFile)

    $SourceShortcutPath = Join-Path -Path $PSScriptRoot -ChildPath $ShortcutFile
    $SourceIconPath     = Join-Path -Path $PSScriptRoot -ChildPath $IconFile
    $DestShortcutPath   = Join-Path -Path $script:PublicDesktopPath -ChildPath $ShortcutFile
    $DestIconPath       = Join-Path -Path $script:IconFolder -ChildPath $IconFile

    if (-not (Test-Path -LiteralPath $SourceShortcutPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] SOURCE SHORTCUT NOT FOUND (Packaging): '$SourceShortcutPath'." -ErrorCode 'SRC_SHORTCUT_NOT_FOUND'
        return $false
    }
    if (-not (Test-Path -LiteralPath $SourceIconPath -PathType Leaf)) {
        Write-ErrorLog -Message "[$Name] SOURCE ICON NOT FOUND (Packaging): '$SourceIconPath'." -ErrorCode 'SRC_ICON_NOT_FOUND'
        return $false
    }

    try {
        Copy-Item -LiteralPath $SourceIconPath -Destination $DestIconPath -Force -ErrorAction Stop
    }
    catch {
        Write-ErrorLog -Message "[$Name] ICON COPY FAILED (System/Permissions): $($_.Exception.Message)" -ErrorCode 'ICON_COPY_FAIL'
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
        Write-ErrorLog -Message "[$Name] SHORTCUT COPY FAILED (System/Permissions): $($_.Exception.Message)" -ErrorCode 'SHORTCUT_COPY_FAIL'
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
        $Message = "Desktop shortcut pack completed with errors: $SuccessCount succeeded, $FailedCount failed."
        Write-ErrorLog -Message $Message -ErrorCode 'PARTIAL_FAIL'
        Write-Output $Message
        exit 1
    }

    Write-Output "$($script:AppName) v1.1.2 deployed: $SuccessCount shortcuts installed."
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
