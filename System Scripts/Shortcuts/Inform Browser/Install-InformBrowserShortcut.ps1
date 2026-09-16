#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Deploys the Inform Browser shortcut to the Public Desktop and sets its custom icon.

.DESCRIPTION
    Intune Win32 App installation script.

    Process:
    1. Copies the packaged icon file to C:\ProgramData\Microsoft\IntuneManagementExtension\Images
    2. Copies the packaged shortcut file to C:\Users\Public\Desktop
    3. Updates the shortcut to reference the locally stored icon

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_InformBrowserShortcut_Install.txt.

    Exit Codes:
        0 = Success (shortcut deployed and icon set)
        1 = Failure (an error occurred during execution)

.NOTES
    Version:        1.1.1
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Deploy the Inform Browser Public Desktop shortcut with custom icon

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; hardened shortcut icon handling -- ver. 1.1.1
    Change: 13/07/2026 - Standardized to IME-rooted runtime paths (Images, Logs), PS 5.1 hardening, error-only logging -- ver. 1.1.0

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-InformBrowserShortcut.ps1
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-InformBrowserShortcut.ps1
      Install behavior: System
      Device restart behavior: No specific action
      Detection rule: custom detection script Detect.ps1
        Run script as 32-bit process on 64-bit clients: No
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'InformBrowserShortcut'
$script:ShortcutFileName = 'Inform Browser.url'
$script:IconFileName     = 'Inform Browser Icon.ico'

# Destination roots (current IME-rooted environment standard)
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

# Source paths (Win32 app package extraction folder)
$script:SourceShortcutPath = Join-Path -Path $PSScriptRoot -ChildPath $script:ShortcutFileName
$script:SourceIconPath     = Join-Path -Path $PSScriptRoot -ChildPath $script:IconFileName

# Destination paths
$script:DestShortcutPath = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName
$script:DestIconPath     = Join-Path -Path $script:IconFolder -ChildPath $script:IconFileName

# Error-only log file
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
    # Verify packaged source files exist
    if (-not (Test-Path -LiteralPath $script:SourceShortcutPath -PathType Leaf)) {
        Stop-WithError -Message "SOURCE SHORTCUT NOT FOUND (Packaging): '$($script:ShortcutFileName)' was not found in the package at '$PSScriptRoot'." -ErrorCode 'SRC_SHORTCUT_NOT_FOUND'
    }
    if (-not (Test-Path -LiteralPath $script:SourceIconPath -PathType Leaf)) {
        Stop-WithError -Message "SOURCE ICON NOT FOUND (Packaging): '$($script:IconFileName)' was not found in the package at '$PSScriptRoot'." -ErrorCode 'SRC_ICON_NOT_FOUND'
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
        Stop-WithError -Message "ICON COPY FAILED (System/Permissions): could not copy icon to '$($script:DestIconPath)'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_COPY_FAIL'
    }
    if (-not (Test-Path -LiteralPath $script:DestIconPath -PathType Leaf)) {
        Stop-WithError -Message "ICON COPY VERIFICATION FAILED (System): icon not found at '$($script:DestIconPath)' after copy." -ErrorCode 'ICON_VERIFY_FAIL'
    }

    # Copy the shortcut and verify
    try {
        Copy-Item -LiteralPath $script:SourceShortcutPath -Destination $script:DestShortcutPath -Force -ErrorAction Stop
    }
    catch {
        Stop-WithError -Message "SHORTCUT COPY FAILED (System/Permissions): could not copy shortcut to '$($script:DestShortcutPath)'. Error: $($_.Exception.Message)" -ErrorCode 'SHORTCUT_COPY_FAIL'
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

    Write-Output "$($script:AppName) v1.1.1 deployed: '$($script:DestShortcutPath)' with icon '$($script:DestIconPath)'."
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