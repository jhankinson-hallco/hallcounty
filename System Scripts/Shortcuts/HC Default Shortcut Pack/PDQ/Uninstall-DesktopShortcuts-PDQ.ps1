#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: removes the Hall County default shortcut pack from the Public Desktop.

.DESCRIPTION
    PDQ Deploy uninstallation script. Tandem counterpart of the Intune Win32
    uninstall Uninstall-DesktopShortcuts.ps1 (v1.1.2); the on-device result is
    identical. Removes every configured shortcut from the Public Desktop and
    optionally removes the stored icon files from both the current IME-rooted
    Images folder and the legacy Images folder. Does not touch the filestore.

    Logging is error-only to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_DesktopShortcuts_Uninstall.txt
    (same file as the Intune uninstall; PDQ entries are tagged [PDQ]).

    Exit Codes:
        0 = Success (all shortcuts removed or already absent)
        1 = Failure (one or more shortcuts could not be removed)

.NOTES
    Version:        1.0.2
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Remove the Hall County default Public Desktop shortcut pack via PDQ

    CHANGE LOG
    Change: 13/07/2026 - Removed advanced parameter attributes for PS 5.1/IME binding safety; tandem with Intune counterpart v1.1.2 -- ver. 1.0.2
    Change: 13/07/2026 - Version synchronized with Intune Uninstall-DesktopShortcuts.ps1 v1.1.1; uninstall logic unchanged -- ver. 1.0.1
    Change: 13/07/2026 - Initial PDQ release, tandem with Intune Uninstall-DesktopShortcuts.ps1 v1.1.0 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running this single script (separate package
                     or step from the install script)
      Run As:        Deploy User or Local System (no filestore access required)
      Success codes: 0
#>

# =============================================================================
# CONFIGURATION
# =============================================================================
# Keep this list synchronized with the Intune Install-DesktopShortcuts.ps1,
# Detect.ps1, and Install-DesktopShortcuts-PDQ.ps1.

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
# Leave $false when other deployments share the same icons. Must match the
# Intune uninstall setting to preserve tandem parity.
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
        $LogEntry = "[$Timestamp] [$($env:COMPUTERNAME)] [PDQ] [$ErrorCode] $Message"
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
        $Message = "Desktop shortcut pack uninstall (PDQ) completed with errors: $FailedCount shortcut(s) could not be removed."
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
