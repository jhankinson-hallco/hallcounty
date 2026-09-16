#Requires -Version 5.1

<#
.SYNOPSIS
    Intune detection script for System-RemoveBloatwareAppX.ps1.

.DESCRIPTION
    Custom Intune Win32 app detection script. Marker-only detection - the
    install script writes a versioned marker file on success; this script
    checks for that marker and the required script version.

    Exit 0 + STDOUT = detected (marker present, version satisfies, and
                       Status=Success).
    Exit 1 / no STDOUT = not detected (marker absent, stale, or unhandled
                       exception - fail-open so Intune retries the install).

    Detection order:
      1. Intune marker (authoritative once present). If present but stale,
         detection fails without falling through - a reinstall is needed.
      2. PDQ marker (only consulted if the Intune marker is absent). Exists
         to stop Intune from reinstalling a version PDQ already installed;
         this project has no PDQ counterpart yet, so this branch is
         expected to always be Absent for now.
      3. Legacy marker location (existence only - temporary migration
         leniency for devices that received the pre-1.1.0 wrapper before
         the marker moved under the IME root).

    Previous versions used a multi-fallback profile-state check to suppress
    post-OOBE runs. That logic was replaced because all three fallback methods
    (CIM Win32_UserProfile, C:\Users filesystem, HKLM ProfileList registry)
    consistently fail during White Glove provisioning, causing the fail-closed
    path to fire and permanently skip the install. Post-OOBE suppression is
    handled by the install script itself.

.NOTES
    Version:        1.1.0
    Script Type:    Microsoft Intune Win32 App - Custom Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  26/03/2026
    Purpose:        Detect successful bloatware AppX removal wrapper execution
    Paired script:  System-RemoveBloatwareAppX.ps1 v1.1.0

    ERROR CODES
      0 = Detected
      1 = Not detected (marker absent, stale, or unhandled exception)

    CHANGE LOG
    Change: 26/03/2026 - Replaced profile-state detection with marker-only detection -- ver. 1.0.0
    Change: 04/05/2026 - Added marker version check for System-RemoveBloatwareAppX.ps1 v1.0.5 -- ver. 1.0.5
    Change: 04/05/2026 - Updated required marker version for System-RemoveBloatwareAppX.ps1 v1.0.6 -- ver. 1.0.6
    Change: 08/09/2026 - Moved to the current IME-rooted marker location
                         (AppMarkers\System-RemoveBloatwareAppX.marker),
                         added Version=/Status= field checking and a PDQ
                         marker tier, kept the legacy C:\IntuneAppMarkers
                         tag as a temporary existence-only fallback, and
                         relocated the ERROR CODES block ahead of
                         CHANGE LOG per the new campus-wide .NOTES
                         standard -- ver. 1.1.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configuration - must match System-RemoveBloatwareAppX.ps1 exactly
$script:AppName          = 'System-RemoveBloatwareAppX'
$script:RequiredVersion  = '1.1.0'
$script:IntuneMarkerPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\$($script:AppName).marker"
$script:PdqMarkerPath    = "C:\ProgramData\PDQ\AppMarkers\$($script:AppName).marker"
$script:LegacyMarkerPath = 'C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag'

function Get-MarkerFields {
    param(
        [string]$MarkerPath
    )
    if (-not (Test-Path -LiteralPath $MarkerPath -PathType Leaf)) { return $null }

    $VersionValue = $null
    $StatusValue  = $null
    $Content = Get-Content -LiteralPath $MarkerPath -ErrorAction Stop
    foreach ($Line in $Content) {
        if ($Line -match '^Version=(.*)$') { $VersionValue = $Matches[1].Trim() }
        if ($Line -match '^Status=(.*)$')  { $StatusValue  = $Matches[1].Trim() }
    }

    return New-Object -TypeName psobject -Property @{
        Version = $VersionValue
        Status  = $StatusValue
    }
}

function Test-MarkerCurrent {
    param(
        [string]$MarkerPath,
        [string]$RequiredVersion
    )
    # Returns 'Detected', 'NotDetected', or 'Absent'.
    $Fields = Get-MarkerFields -MarkerPath $MarkerPath
    if ($null -eq $Fields) { return 'Absent' }

    if ([string]::IsNullOrWhiteSpace($Fields.Version)) { return 'NotDetected' }
    if ($Fields.Status -ne 'Success') { return 'NotDetected' }

    try {
        if (([version]$Fields.Version) -lt ([version]$RequiredVersion)) { return 'NotDetected' }
    }
    catch {
        return 'NotDetected'
    }

    return 'Detected'
}

try {
    $IntuneResult = Test-MarkerCurrent -MarkerPath $script:IntuneMarkerPath -RequiredVersion $script:RequiredVersion
    if ($IntuneResult -eq 'Detected') {
        Write-Output "Detected: current Intune marker satisfies required version $($script:RequiredVersion)"
        exit 0
    }
    if ($IntuneResult -eq 'NotDetected') {
        exit 1
    }

    $PdqResult = Test-MarkerCurrent -MarkerPath $script:PdqMarkerPath -RequiredVersion $script:RequiredVersion
    if ($PdqResult -eq 'Detected') {
        Write-Output "Detected: PDQ marker satisfies required version $($script:RequiredVersion)"
        exit 0
    }

    if (Test-Path -LiteralPath $script:LegacyMarkerPath -PathType Leaf) {
        Write-Output 'Detected: legacy marker present (temporary compatibility, no version distinction)'
        exit 0
    }

    exit 1
}
catch {
    # Detection exception - treat as not detected so Intune retries the install.
    exit 1
}
