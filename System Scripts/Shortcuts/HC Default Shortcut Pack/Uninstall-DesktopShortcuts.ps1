#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes the Hall County default shortcut pack from the Public Desktop.

.DESCRIPTION
    Intune Win32 App uninstallation script. Removes every configured shortcut
    file from the Public Desktop. Optionally removes the stored icon files from
    both the current IME-rooted Images folder and the legacy Images folder.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_DesktopShortcuts_Uninstall.txt.

    Exit Codes:
        0 = Success (all shortcuts removed or already absent)
        1 = Failure (one or more shortcuts could not be removed)

.NOTES
    Version:        1.1.2
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Remove the Hall County default Public Desktop shortcut pack

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety -- ver. 1.1.2
    Change: 13/07/2026 - Version synchronized with install hardening; uninstall logic unchanged -- ver. 1.1.1
    Change: 13/07/2026 - Standardized to IME-rooted runtime paths, PS 5.1 hardening, fixed uninstall log naming -- ver. 1.1.0

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-DesktopShortcuts.ps1
#>

# =============================================================================
# CONFIGURATION
# =============================================================================
# Keep this list synchronized with Install-DesktopShortcuts.ps1 and Detect.ps1.

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

# Set to $true to also remove the stored icon files from both icon locations.
# Leave $false when other deployments share the same icons.
$script:RemoveIconFiles = $false

$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolder        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:LegacyIconFolder  = 'C:\IntuneDeploymentFiles\Images'
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

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
    $FailedCount = 0

    foreach ($Entry in $script:Shortcuts) {
        $Name = [System.IO.Path]::GetFileNameWithoutExtension($Entry.ShortcutFile)
        $ShortcutPath = Join-Path -Path $script:PublicDesktopPath -ChildPath $Entry.ShortcutFile

        if (Test-Path -LiteralPath $ShortcutPath -PathType Leaf) {
            try {
                Remove-Item -LiteralPath $ShortcutPath -Force -ErrorAction Stop
            }
            catch {
                Write-ErrorLog -Message "[$Name] SHORTCUT REMOVAL FAILED (System/Permissions): $($_.Exception.Message)" -ErrorCode 'SHORTCUT_REMOVE_FAIL'
                $FailedCount++
                continue
            }

            if (Test-Path -LiteralPath $ShortcutPath -PathType Leaf) {
                Write-ErrorLog -Message "[$Name] SHORTCUT REMOVAL VERIFICATION FAILED (System): still exists at '$ShortcutPath'." -ErrorCode 'SHORTCUT_VERIFY_FAIL'
                $FailedCount++
                continue
            }
        }

        # Optional icon cleanup from both current and legacy locations (best effort)
        if ($script:RemoveIconFiles) {
            $IconPaths = @(
                (Join-Path -Path $script:IconFolder -ChildPath $Entry.IconFile),
                (Join-Path -Path $script:LegacyIconFolder -ChildPath $Entry.IconFile)
            )
            foreach ($IconPath in $IconPaths) {
                if (Test-Path -LiteralPath $IconPath -PathType Leaf) {
                    try {
                        Remove-Item -LiteralPath $IconPath -Force -ErrorAction Stop
                    }
                    catch {
                        # Icon cleanup failure is not fatal; the shortcut removal succeeded.
                        Write-ErrorLog -Message "[$Name] ICON REMOVAL WARNING (System): could not remove '$IconPath'. Error: $($_.Exception.Message)" -ErrorCode 'ICON_REMOVE_WARN'
                    }
                }
            }
        }
    }

    if ($FailedCount -gt 0) {
        $Message = "Desktop shortcut pack uninstall completed with errors: $FailedCount shortcut(s) could not be removed."
        Write-ErrorLog -Message $Message -ErrorCode 'PARTIAL_FAIL'
        Write-Output $Message
        exit 1
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
