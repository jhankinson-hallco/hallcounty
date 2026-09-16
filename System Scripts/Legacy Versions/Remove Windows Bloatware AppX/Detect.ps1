#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for System-RemoveBloatwareAppX.ps1.

.DESCRIPTION
    Marker-only detection. The install script writes a marker file on success;
    this script checks for that marker and nothing else.

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
    Script Version: 1.1.0
    Revision Date:  2026-03-26 (1.1.0 — replaced profile-state detection with marker-only)
    Script Name:    Detect.ps1
    Paired script:  System-RemoveBloatwareAppX.ps1 v1.0.10
#>

# =============================================================================
# CONFIGURATION — must match System-RemoveBloatwareAppX.ps1 exactly
# =============================================================================
$script:MarkerPath = 'C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag'
# =============================================================================
# END CONFIGURATION
# =============================================================================

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
