#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for the Hall County default shortcut pack.

.DESCRIPTION
    Detects every configured shortcut on the Public Desktop and its icon file.
    Each icon check passes when the icon exists at EITHER the current
    IME-rooted location OR the legacy location, so devices deployed before
    the IME path migration keep passing detection without files being moved.

    All shortcuts and icons must be present for detection to succeed.

    Exit 0 + STDOUT = detected (all shortcuts present, all icons present in either location).
    Exit 1 / no STDOUT = not detected.

    On unhandled exception: exits 1 so Intune retries the install.

.NOTES
    Version:        1.1.2
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Detect the default shortcut pack with IME or legacy icon locations

    CHANGE LOG
    Change: 13/07/2026 - Version synchronized with package hardening; detection logic unchanged -- ver. 1.1.2
    Change: 13/07/2026 - Version synchronized with install hardening; detection logic unchanged -- ver. 1.1.1
    Change: 13/07/2026 - Standardized detection; icons accepted at IME-rooted or legacy location -- ver. 1.1.0

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect.ps1
      Run script as 32-bit process on 64-bit clients: No
#>

# Configuration - must match Install-DesktopShortcuts.ps1 exactly
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

$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:IconFolderIme     = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images'
$script:IconFolderLegacy  = 'C:\IntuneDeploymentFiles\Images'

try {
    foreach ($Entry in $script:Shortcuts) {
        $ShortcutPath   = Join-Path -Path $script:PublicDesktopPath -ChildPath $Entry.ShortcutFile
        $IconPathIme    = Join-Path -Path $script:IconFolderIme -ChildPath $Entry.IconFile
        $IconPathLegacy = Join-Path -Path $script:IconFolderLegacy -ChildPath $Entry.IconFile

        if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
            exit 1
        }

        $IconPresent = (Test-Path -LiteralPath $IconPathIme -PathType Leaf) -or
                       (Test-Path -LiteralPath $IconPathLegacy -PathType Leaf)
        if (-not $IconPresent) {
            exit 1
        }
    }

    Write-Output "Detected: all $(@($script:Shortcuts).Count) default desktop shortcuts present with icons."
    exit 0
}
catch {
    # Detection exception - treat as not detected so Intune retries the install.
    exit 1
}
