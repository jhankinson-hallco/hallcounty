#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for HC-RemoveWin32Bloatware.

.DESCRIPTION
    Marker-only detection. The install script writes a version-stamped marker
    file on success; this script checks for that marker and nothing else.

    Exit 0 + STDOUT = detected (marker present — install ran successfully).
    Exit 1 / no STDOUT = not detected (marker absent — install needs to run).

    On unhandled exception: exits 1 so Intune retries the install.

    Previous versions used a multi-fallback profile-state check to suppress
    post-OOBE runs. That logic was replaced because all three fallback methods
    (CIM Win32_UserProfile, C:\Users filesystem, HKLM ProfileList registry)
    consistently fail during White Glove provisioning, causing the fail-closed
    path to fire and permanently skip the install.

    Post-OOBE suppression is now handled by the install script itself.

.NOTES
    Author:         Jeremy Hankinson
    Script Version: 1.1.1
    Revision Date:  2026-03-26 (1.1.0 — replaced profile-state detection with marker-only); 2026-03-26 (1.1.1 — AppVersion bump to match install script v1.0.14)
    Script Name:    Detect.ps1
    Paired script:  System-RemoveBloatwareWin32.ps1 v1.0.14
#>

# ============================
# CONFIG — must match System-RemoveBloatwareWin32.ps1 exactly
# ============================
$script:AppVersion = '1.0.14'
$script:AppName    = 'HC-RemoveWin32Bloatware'

$SafeVersionForMarker    = ($script:AppVersion -replace '[^\w.\-]', '_')
$MarkerFileName          = '{0}_{1}.tag' -f $script:AppName, $SafeVersionForMarker
$script:MarkerPath       = Join-Path 'C:\IntuneAppMarkers' $MarkerFileName
# ============================
# END CONFIG
# ============================

try {
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Write-Output "Detected: marker present"
        exit 0
    }

    exit 1
}
catch {
    # Detection exception — treat as not detected so Intune retries the install.
    exit 1
}
