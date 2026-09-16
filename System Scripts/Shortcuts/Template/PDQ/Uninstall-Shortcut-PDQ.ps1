#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: removes the Example App shortcut from the Public Desktop.

.DESCRIPTION
    PDQ Deploy uninstallation script. Tandem counterpart of the Intune Win32
    uninstall Uninstall-Shortcut.ps1 (v1.1.1); the on-device result is identical.
    Removes the shortcut from the Public Desktop and optionally removes the
    stored icon from both the current IME-rooted Images folder and the legacy
    Images folder. Does not touch the filestore.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_ExampleShortcut_Uninstall.txt
    (same file as the Intune uninstall; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (shortcut removed or already absent)
        1 = Failure (an error occurred during removal)

.NOTES
    Version:        1.0.1
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Remove the Example App Public Desktop shortcut via PDQ

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; tandem with Intune counterpart v1.1.1 -- ver. 1.0.1
    Change: 13/07/2026 - Initial PDQ release, tandem with Intune Uninstall-Shortcut.ps1 v1.1.0 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running this single script (separate package
                     or step from the install script)
      Run As:        Deploy User or Local System (no filestore access required)
      Success codes: 0
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'ExampleShortcut'
$script:ShortcutFileName = 'Example App.url'
$script:IconFileName     = 'Example Icon.ico'

# Set to $true to also remove the stored icon file from both icon locations.
# Leave $false when multiple shortcuts share the same icon. Must match the
# Intune uninstall setting to preserve tandem parity.
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
        $LogEntry = "[$Timestamp] [$($env:COMPUTERNAME)] [PDQ] [$ErrorCode] $Message"
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