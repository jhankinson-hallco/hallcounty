#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes the Webmail shortcut from the Public Desktop.

.DESCRIPTION
    Intune Win32 App uninstallation script. Removes the shortcut file from the
    Public Desktop. Optionally removes the stored icon file from both the
    current IME-rooted Images folder and the legacy Images folder.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_WebmailShortcut_Uninstall.txt.

    Exit Codes:
        0 = Success (shortcut removed or already absent)
        1 = Failure (an error occurred during removal)

.NOTES
    Version:        1.1.1
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Remove the Webmail Public Desktop shortcut

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety -- ver. 1.1.1
    Change: 13/07/2026 - Standardized to IME-rooted runtime paths, PS 5.1 hardening, fixed uninstall log naming -- ver. 1.1.0

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-Shortcut.ps1
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'WebmailShortcut'
$script:ShortcutFileName = 'Webmail.url'
$script:IconFileName     = 'Webmail Icon.ico'

# Set to $true to also remove the stored icon file from both icon locations.
# Leave $false when multiple shortcuts share the same icon.
$script:RemoveIconFile = $false

$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LegacyIconFolder  = 'C:\IntuneDeploymentFiles\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

$script:ShortcutPath   = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName
$script:IconPathIme    = Join-Path -Path $script:IconFolder -ChildPath $script:IconFileName
$script:IconPathLegacy = Join-Path -Path $script:LegacyIconFolder -ChildPath $script:IconFileName

$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_' + $script:AppName + '_Uninstall.txt')

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

# =============================================================================
# MAIN
# =============================================================================

try {
    if (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf) {
        try {
            Remove-Item -LiteralPath $script:ShortcutPath -Force -ErrorAction Stop
        }
        catch {
            $Message = "SHORTCUT REMOVAL FAILED (System/Permissions): could not remove '$($script:ShortcutPath)'. Error: $($_.Exception.Message)"
            Write-ErrorLog -Message $Message -ErrorCode 'SHORTCUT_REMOVE_FAIL'
            Write-Output $Message
            exit 1
        }

        if (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf) {
            $Message = "SHORTCUT REMOVAL VERIFICATION FAILED (System): shortcut still exists at '$($script:ShortcutPath)'."
            Write-ErrorLog -Message $Message -ErrorCode 'SHORTCUT_VERIFY_FAIL'
            Write-Output $Message
            exit 1
        }
    }

    # Optional icon cleanup from both current and legacy locations (best effort)
    if ($script:RemoveIconFile) {
        foreach ($IconPath in @($script:IconPathIme, $script:IconPathLegacy)) {
            if (Test-Path -LiteralPath $IconPath -PathType Leaf) {
                try {
                    Remove-Item -LiteralPath $IconPath -Force -ErrorAction Stop
                }
                catch {
                    # Icon cleanup failure is not fatal; the shortcut removal succeeded.
                    Write-ErrorLog -Message "ICON REMOVAL WARNING (System): could not remove '$IconPath'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_REMOVE_WARN'
                }
            }
        }
    }

    exit 0
}
catch {
    $Message = "UNEXPECTED ERROR DURING UNINSTALL (App/System): $($_.Exception.Message)"
    $Code = 'UNKNOWN'
    try { $Code = '0x{0:X8}' -f $_.Exception.HResult } catch { }
    Write-ErrorLog -Message $Message -ErrorCode $Code
    Write-Output $Message
    exit 1
}