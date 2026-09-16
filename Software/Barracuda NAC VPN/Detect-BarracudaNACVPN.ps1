#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for the Barracuda NAC VPN Win32 app.

.DESCRIPTION
    Detected only when ALL of the following are true:
      1. nacvpn.exe exists at the expected 64-bit Program Files install path.
      2. A trusted Barracuda MSI registration has the expected product version.
      3. The cudanacsvc service exists.
      4. The Public Desktop shortcut exists with the expected target and icon.
      5. A marker satisfies the version requirement, checked in this order
         (2026-08-20 policy - see reference_intune_detection.md):
           a. Current Intune marker
              (C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker):
              requires Version= to match $script:RequiredScriptVersion
              (version-gated so a future install script bump forces
              reinstall/reconfiguration), ProductVersion= to match the
              expected software version, and Status=Success. If this marker
              exists but fails any of those checks, detection fails
              immediately - it does NOT fall through to PDQ/legacy, since
              an authoritative-but-stale marker means a real
              reinstall/reconfiguration is needed.
           b. PDQ marker (C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker,
              checked only if the Intune marker is absent): requires
              ProductVersion= to match the expected software version. Exists
              only to stop Intune from reinstalling a version PDQ already
              deployed.
           c. Legacy marker (C:\IntuneAppMarkers\BarracudaNACVPN.tag,
              checked only if both above are absent): existence only, no
              version distinction - temporary compatibility with
              already-deployed packages, to be phased out.

    The marker is the only evidence that the VPN profile step actually ran
    and succeeded; there is no lightweight, reliable way to confirm the
    Barracuda machine VPN profile state without importing the vendor
    PowerShell module, which is too heavy for a detection script that Intune
    runs on every sync cycle (see reference_intune_pitfalls.md P16).

    Exit 0 + STDOUT = detected. Exit 1 / no STDOUT = not detected (Intune
    retries the install).

.NOTES
    Version:        1.0.4
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/08/2026
    Purpose:        Detect Barracuda NAC VPN install, profile marker, and desktop shortcut

    ERROR CODES
      0 - Detected; writes one STDOUT line
      1 - Not detected; writes no STDOUT

    CHANGE LOG
    Change: 13/08/2026 - Initial release -- ver. 1.0.0
    Change: 17/08/2026 - Add trusted installed-version, marker-status/product-version, and shortcut target/icon validation -- ver. 1.0.1
    Change: 21/08/2026 - Require the VPN-only install-script revision -- ver. 1.0.2
    Change: 21/08/2026 - Moved the Intune marker check to the current
                         IME-rooted path (was C:\IntuneAppMarkers, a .tag
                         file - now C:\ProgramData\Microsoft\
                         IntuneManagementExtension\AppMarkers, a .marker
                         file); added a PDQ marker tier (ProductVersion=
                         only) checked when the Intune marker is absent; the
                         old location is now checked last as a temporary,
                         existence-only legacy fallback. Required script
                         version updated to match Install v1.0.3 -- ver. 1.0.3
    Change: 09/09/2026 - Updated the authoritative Intune-marker requirement
                         to Install v1.0.6 after legacy removal moved to a
                         separate hard-reboot dependency app -- ver. 1.0.4

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect-BarracudaNACVPN.ps1
      Run script as 32-bit process on 64-bit clients: No

    Paired script: Install-BarracudaNACVPN.ps1 v1.0.6
#>

$script:RequiredScriptVersion = '1.0.6'
$script:ExpectedProductVersion = '9.3.8012'
$script:DisplayNamePattern     = '^Barracuda Network Access Client(?:\s+\d+(?:[.-]\d+)*)?$'
$script:PublisherPattern       = 'Barracuda Networks*'
$script:RegistryPaths          = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:NacvpnExePath = 'C:\Program Files\Barracuda\Network Access Client\nacvpn.exe'
$script:ServiceName   = 'cudanacsvc'
$script:ShortcutPath  = 'C:\Users\Public\Desktop\Barracuda VPN Client.lnk'

# Marker check order (2026-08-20 policy): current Intune marker (full
# Version=/ProductVersion=/Status= validation), then PDQ marker
# (ProductVersion= only - PDQ's marker only exists to stop Intune from
# reinstalling a version PDQ already deployed), then the legacy path
# (existence only, temporary compatibility). See
# reference_intune_detection.md and AGENTS.md "IME Runtime Paths".
$script:IntuneMarkerPath = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker'
$script:PdqMarkerPath    = 'C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker'
$script:LegacyMarkerPath = 'C:\IntuneAppMarkers\BarracudaNACVPN.tag'

function ConvertTo-ComparableVersion {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    if ($Value.Trim() -notmatch '^0*(\d+)\.0*(\d+)\.0*(\d+)(?:\.0+)?$') {
        return ''
    }

    return ('{0}.{1}.{2}' -f ([int]$Matches[1]), ([int]$Matches[2]), ([int]$Matches[3]))
}

function Test-BarracudaExpectedVersion {
    foreach ($RegistryPath in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $RegistryPath)) {
            continue
        }

        try {
            $SubKeys = @(Get-ChildItem -LiteralPath $RegistryPath -ErrorAction Stop)
        }
        catch {
            continue
        }

        foreach ($SubKey in $SubKeys) {
            try {
                $Properties = Get-ItemProperty -LiteralPath $SubKey.PSPath -ErrorAction Stop
                $DisplayNameProperty = $Properties.PSObject.Properties['DisplayName']
                $PublisherProperty = $Properties.PSObject.Properties['Publisher']
                $WindowsInstallerProperty = $Properties.PSObject.Properties['WindowsInstaller']
                $DisplayVersionProperty = $Properties.PSObject.Properties['DisplayVersion']

                if ($null -eq $DisplayNameProperty -or
                    $null -eq $PublisherProperty -or
                    $null -eq $WindowsInstallerProperty -or
                    $null -eq $DisplayVersionProperty) {
                    continue
                }

                if ([string]$DisplayNameProperty.Value -notmatch $script:DisplayNamePattern) {
                    continue
                }
                if ([string]$PublisherProperty.Value -notlike $script:PublisherPattern) {
                    continue
                }
                if ([string]$WindowsInstallerProperty.Value -ne '1') {
                    continue
                }

                $InstalledVersion = ConvertTo-ComparableVersion -Value ([string]$DisplayVersionProperty.Value)
                if ($InstalledVersion -eq $script:ExpectedProductVersion) {
                    return $true
                }
            }
            catch {
                continue
            }
        }
    }

    return $false
}

function Test-IntuneMarker {
    # Returns 'Detected', 'NotDetected' (present but stale/invalid - do not
    # fall through to PDQ/legacy), or 'Absent'.
    if (-not (Test-Path -LiteralPath $script:IntuneMarkerPath -PathType Leaf)) {
        return 'Absent'
    }

    try {
        $MarkerContent = @(Get-Content -LiteralPath $script:IntuneMarkerPath -ErrorAction Stop)
    }
    catch {
        return 'NotDetected'
    }

    $VersionLine = $MarkerContent | Where-Object { $_ -match '^Version=' } | Select-Object -First 1
    $ProductVersionLine = $MarkerContent | Where-Object { $_ -match '^ProductVersion=' } | Select-Object -First 1
    $StatusLine = $MarkerContent | Where-Object { $_ -match '^Status=' } | Select-Object -First 1
    if ($null -eq $VersionLine -or $null -eq $ProductVersionLine -or $null -eq $StatusLine) {
        return 'NotDetected'
    }

    $MarkerVersion = ([string]$VersionLine -replace '^Version=', '').Trim()
    if ($MarkerVersion -ne $script:RequiredScriptVersion) {
        return 'NotDetected'
    }

    $MarkerProductVersion = ConvertTo-ComparableVersion -Value (([string]$ProductVersionLine -replace '^ProductVersion=', '').Trim())
    if ($MarkerProductVersion -ne $script:ExpectedProductVersion) {
        return 'NotDetected'
    }

    $MarkerStatus = ([string]$StatusLine -replace '^Status=', '').Trim()
    if ($MarkerStatus -ne 'Success') {
        return 'NotDetected'
    }

    return 'Detected'
}

function Test-PdqMarker {
    # Returns 'Detected' or 'NotDetected'. PDQ's marker only carries
    # ProductVersion= (see Set-BarracudaNACVPNMarker-PDQ.ps1, PDQ\) - its
    # sole purpose is stopping Intune from reinstalling a version PDQ
    # already deployed, so it is version-gated the same way but has no
    # Version=/Status= fields to check.
    if (-not (Test-Path -LiteralPath $script:PdqMarkerPath -PathType Leaf)) {
        return 'NotDetected'
    }

    try {
        $MarkerContent = @(Get-Content -LiteralPath $script:PdqMarkerPath -ErrorAction Stop)
    }
    catch {
        return 'NotDetected'
    }

    $ProductVersionLine = $MarkerContent | Where-Object { $_ -match '^ProductVersion=' } | Select-Object -First 1
    if ($null -eq $ProductVersionLine) {
        return 'NotDetected'
    }

    $MarkerProductVersion = ConvertTo-ComparableVersion -Value (([string]$ProductVersionLine -replace '^ProductVersion=', '').Trim())
    if ($MarkerProductVersion -ne $script:ExpectedProductVersion) {
        return 'NotDetected'
    }

    return 'Detected'
}

try {
    if (-not (Test-Path -LiteralPath $script:NacvpnExePath -PathType Leaf)) {
        exit 1
    }

    if (-not (Test-BarracudaExpectedVersion)) {
        exit 1
    }

    if (-not (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)) {
        exit 1
    }

    if (-not (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)) {
        exit 1
    }

    $ExpectedIconLocation = $script:NacvpnExePath + ',0'
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($script:ShortcutPath)
    if ([string]$Shortcut.TargetPath -ne $script:NacvpnExePath) {
        exit 1
    }
    if ([string]$Shortcut.IconLocation -ne $ExpectedIconLocation) {
        exit 1
    }

    $IntuneMarkerState = Test-IntuneMarker
    if ($IntuneMarkerState -eq 'Detected') {
        Write-Output "Detected: Barracuda NAC VPN $($script:ExpectedProductVersion) installed (Intune marker v$($script:RequiredScriptVersion)), corrected shortcut present."
        exit 0
    }
    if ($IntuneMarkerState -eq 'NotDetected') {
        # Authoritative marker present but stale/invalid - do not fall
        # through to PDQ/legacy; a reinstall/reconfiguration is needed.
        exit 1
    }

    if ((Test-PdqMarker) -eq 'Detected') {
        Write-Output "Detected: Barracuda NAC VPN $($script:ExpectedProductVersion) installed (PDQ marker), corrected shortcut present."
        exit 0
    }

    if (Test-Path -LiteralPath $script:LegacyMarkerPath -PathType Leaf) {
        Write-Output 'Detected: Barracuda NAC VPN installed (legacy marker, temporary compatibility, no version distinction).'
        exit 0
    }

    exit 1
}
catch {
    exit 1
}
