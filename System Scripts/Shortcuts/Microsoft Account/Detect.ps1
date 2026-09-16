#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for the Microsoft Account Settings Public Desktop shortcut.

.DESCRIPTION
    Detects the deployed shortcut on the Public Desktop and its icon file.
    The icon check passes when the icon exists at EITHER the current
    IME-rooted location OR the legacy location, so devices deployed before
    the IME path migration keep passing detection without files being moved.

    Exit 0 + STDOUT = detected (shortcut present and icon present in either location).
    Exit 1 / no STDOUT = not detected.

    On unhandled exception: exits 1 so Intune retries the install.

.NOTES
    Version:        1.1.1
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/07/2026
    Purpose:        Detect the Microsoft Account Settings shortcut with IME or legacy icon location

    CHANGE LOG
    Change: 13/07/2026 - Version synchronized with package hardening; detection logic unchanged -- ver. 1.1.1
    Change: 13/07/2026 - Standardized detection; icon accepted at IME-rooted or legacy location -- ver. 1.1.0

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect.ps1
      Run script as 32-bit process on 64-bit clients: No
#>

# Configuration - must match Install-MicrosoftAccountShortcut.ps1 exactly
$script:ShortcutFileName = 'My Account Settings.url'
$script:IconFileName     = 'Hall County Logo Icon.ico'

$script:ShortcutPath   = Join-Path -Path 'C:\Users\Public\Desktop' -ChildPath $script:ShortcutFileName
$script:IconPathIme    = Join-Path -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Images' -ChildPath $script:IconFileName
$script:IconPathLegacy = Join-Path -Path 'C:\IntuneDeploymentFiles\Images' -ChildPath $script:IconFileName

try {
    if (-not (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)) {
        exit 1
    }

    if (Test-Path -LiteralPath $script:IconPathIme -PathType Leaf) {
        Write-Output "Detected: '$($script:ShortcutFileName)' with icon at IME location."
        exit 0
    }

    if (Test-Path -LiteralPath $script:IconPathLegacy -PathType Leaf) {
        Write-Output "Detected: '$($script:ShortcutFileName)' with icon at legacy location."
        exit 0
    }

    exit 1
}
catch {
    # Detection exception - treat as not detected so Intune retries the install.
    exit 1
}