#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for OnBase Client 16 (Full).

.DESCRIPTION
    Detected only when ALL of the following are true:
      1. The OnBase Client 16 executable exists at its known Program Files
         path (raw-copied by the install batch, not MSI-installed, so there
         is no registry evidence for this specific piece).
      2. The Hyland Desktop MSI product is registered (exact ProductCode,
         read directly from the bundled Hyland Desktop.msi, not guessed or
         pattern-matched).
      3. The Hyland Unity Client MSI product is registered (same, from the
         bundled Hyland Unity Client.msi).
      4. The Public Desktop shortcut exists.

    Does not check the VC++ 2013 runtime prerequisite (an earlier draft of
    this project incorrectly called this VC++ 2010 - see
    AI-Audit-Decisions.md) or the SQL Native Client ODBC drivers - those are
    shared/prerequisite components, not OnBase-specific evidence, matching
    how the site's own OB16Uninstall.bat also leaves them alone. Per
    Jeremy's direction (2026-08-18), VC++ 2013 specifically is intended to
    be covered by a separate, required Intune Win32 app dependency
    configured in the portal, not by this app's own detection.

    This is NOT a complete verification of every artifact the install batch
    creates (onbase32.ini, the ODBC registry imports, and the Desktop
    ServerLocation registry value are not checked) - see project
    AI-Audit-Handoff.md for the full, still-open list of gaps.

    NOTE (shop-preferred alternative, not acted on here per explicit
    request for a script): since both ProductCodes are exactly known from
    the bundled MSI files, this could equally be expressed as two native
    Intune "MSI" detection rules plus one or two native "File" detection
    rules, with no custom script at all - reference_intune_detection.md
    lists MSI/file/registry detection ahead of custom scripts specifically
    because they are simpler and need no script maintenance. This script
    was still written because it was explicitly requested; either approach
    is valid given the same proven evidence.

    Exit 0 + STDOUT = detected. Exit 1 / no STDOUT = not detected (Intune
    retries the install).

.NOTES
    Version:        1.1.3
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Detect OnBase Client 16 (Full) install

    CHANGE LOG
    Change: 17/08/2026 - Initial release, located in Auto\ -- ver. 1.0.0
    Change: 18/08/2026 - Relocated to the project root (Software\OnBase\);
                         no path logic changed (all checked paths are
                         absolute - this script has no dependency on its own
                         location); corrected prerequisite documentation
                         from VC++ 2010 to VC++ 2013 (proven from the
                         bundled installer's own signed version metadata -
                         see AI-Audit-Decisions.md) -- ver. 1.1.0
    Change: 18/08/2026 - Documentation only: recorded that VC++ 2013
                         exclusion from this detection is confirmed
                         intentional (Jeremy's direction - covered by a
                         separate required Intune dependency instead). No
                         detection logic changed -- ver. 1.1.1
    Change: 19/08/2026 - Documentation only: updated the paired-script
                         version reference below (Install-OnBase.ps1 added
                         a post-install Windows 11 DPI compatibility fix,
                         v1.1.2). No detection logic changed - the DPI flag
                         is not part of what defines "installed" and is
                         deliberately not checked here -- ver. 1.1.2
    Change: 20/08/2026 - Documentation only: updated the paired-script
                         version reference below (Install-OnBase.ps1 moved
                         logging to the current IME-rooted path standard
                         and several other fixes, v1.1.8). No detection
                         logic changed -- ver. 1.1.3

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect.ps1
      Run script as 32-bit process on 64-bit clients: No

    Paired script: Install-OnBase.ps1 v1.1.8
#>

$script:ClientExePath = 'C:\Program Files\OnBase Client 16\obclnt32.exe'
$script:ShortcutPath  = 'C:\Users\Public\Desktop\OnBase 16.lnk'

# Proven directly from the bundled MSI files' own Property tables
# (WindowsInstaller.Installer COM, ProductCode) on 2026-08-17 - see
# AI-Audit-Decisions.md. Not guessed, not pattern-matched. Must stay
# identical to Install-OnBase.ps1's values.
$script:DesktopProductCode     = '{DADFAF01-82CE-43D8-8520-3D7D214F9356}'
$script:UnityClientProductCode = '{18E17873-DC2D-4085-B752-DD127D388EBD}'

$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

function Test-MsiProductRegistered {
    param(
        [string]$ProductCode
    )

    foreach ($RegistryPath in $script:RegistryPaths) {
        $KeyPath = Join-Path -Path $RegistryPath -ChildPath $ProductCode
        if (Test-Path -LiteralPath $KeyPath) {
            return $true
        }
    }

    return $false
}

try {
    if (-not (Test-Path -LiteralPath $script:ClientExePath -PathType Leaf)) {
        exit 1
    }

    if (-not (Test-MsiProductRegistered -ProductCode $script:DesktopProductCode)) {
        exit 1
    }

    if (-not (Test-MsiProductRegistered -ProductCode $script:UnityClientProductCode)) {
        exit 1
    }

    if (-not (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)) {
        exit 1
    }

    Write-Output 'Detected: OnBase Client 16 executable, both Hyland MSI products, and desktop shortcut all present.'
    exit 0
}
catch {
    exit 1
}
