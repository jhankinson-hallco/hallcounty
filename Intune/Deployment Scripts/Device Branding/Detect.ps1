#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for System-Device_Branding.ps1.

.DESCRIPTION
    Marker-only detection. The install script writes a marker file on success
    or completion with warnings. This script checks for that marker.

    Exit 0 + STDOUT = detected (marker present — install completed successfully).
    Exit 1 / no STDOUT = not detected (marker absent — install needs to run).

    On unhandled exception: exits 1 so Intune retries the install.

.NOTES
    Author:         Jeremy Hankinson
    Script Version: 1.0.1
    Revision Date:  2026-03-27 (1.0.0); 2026-03-27 (1.0.1 — synced paired script version reference)
    Script Name:    Detect.ps1
    Paired script:  System-Device_Branding.ps1 v1.0.2
#>

# =============================================================================
# CONFIGURATION — must match System-Device_Branding.ps1 exactly
# =============================================================================
$script:MarkerPath = 'C:\IntuneAppMarkers\System-Device_Branding.tag'
# =============================================================================
# END CONFIGURATION
# =============================================================================

try {
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Write-Output 'Detected: marker present'
        exit 0
    }
    exit 1
}
catch {
    exit 1
}
