#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: resets M365 Pre-Cleanup detection state.

.DESCRIPTION
    PDQ Deploy uninstall/reset script. Tandem counterpart of the Intune Win32
    uninstall script Uninstall.ps1 (v1.5.22).

    Removes the completion marker written by Remove-Office365-PDQ.ps1 or the
    Intune Remove-Office365.ps1. This causes Detect.ps1 to report "not detected,"
    which allows Intune or PDQ to re-run the cleanup if the app is redeployed or
    the device is reprovisioned.

    This script does NOT re-install Office. It only resets the detection state.

    Always exits 0 - uninstall failures are non-critical and should not cause
    PDQ or Intune to retry the uninstall/reset in a loop.

.NOTES
    Version:        1.0.3
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/04/2026
    Purpose:        Resets M365 Pre-Cleanup detection state by removing the marker file

    CHANGE LOG
    Change: 13/04/2026 - Initial release -- ver. 1.0.0
    Change: 13/04/2026 - Version sync to 1.2.0 for package consistency -- ver. 1.2.0
    Change: 13/04/2026 - Version sync to 1.3.0 for package consistency -- ver. 1.3.0
    Change: 13/04/2026 - Version sync to 1.4.0 for package consistency -- ver. 1.4.0
    Change: 13/04/2026 - Version sync to 1.5.0; updated synopsis from Office 365 Pre-Cleanup
                         to M365 Pre-Cleanup for scope consistency -- ver. 1.5.0
    Change: 13/04/2026 - Updated marker file path to M365PreCleanup.marker; version sync
                         to 1.5.1 -- ver. 1.5.1
    Change: 13/04/2026 - Version sync to 1.5.2 for package consistency -- ver. 1.5.2
    Change: 14/04/2026 - Version sync to 1.5.3 for package consistency -- ver. 1.5.3
    Change: 15/04/2026 - Version sync to 1.5.4 for package consistency -- ver. 1.5.4
    Change: 15/04/2026 - Version sync to 1.5.5 for package consistency -- ver. 1.5.5
    Change: 15/04/2026 - Version sync to 1.5.6 for package consistency -- ver. 1.5.6
    Change: 15/04/2026 - Version sync to 1.5.7 for package consistency -- ver. 1.5.7
    Change: 17/04/2026 - Version sync to 1.5.8 for package consistency -- ver. 1.5.8
    Change: 20/04/2026 - Version sync to 1.5.9 for package consistency -- ver. 1.5.9
    Change: 21/04/2026 - Version sync to 1.5.10 for package consistency -- ver. 1.5.10
    Change: 22/04/2026 - Version sync to 1.5.11 for package consistency -- ver. 1.5.11
    Change: 29/04/2026 - Version sync to 1.5.12 for package consistency -- ver. 1.5.12
    Change: 01/05/2026 - Version sync to 1.5.13 for package consistency -- ver. 1.5.13
    Change: 06/05/2026 - Version sync to 1.5.14 for package consistency -- ver. 1.5.14
    Change: 06/05/2026 - Version sync to 1.5.15 for package consistency -- ver. 1.5.15
    Change: 15/07/2026 - Initial PDQ release; resets the same marker used by
                         the Intune counterpart -- ver. 1.0.0
    Change: 15/07/2026 - Synced with recovered Intune Uninstall.ps1 v1.5.20:
                         removes the marker from the current IME AppMarkers path
                         AND the legacy HallCountyMIS path -- ver. 1.0.1
    Change: 15/07/2026 - Updated Intune counterpart reference to Uninstall.ps1
                         v1.5.21; reset marker behavior unchanged -- ver. 1.0.2
    Change: 15/07/2026 - Updated Intune counterpart reference to Uninstall.ps1
                         v1.5.22; reset marker behavior unchanged -- ver. 1.0.3

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-M365PreCleanup-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      Success codes: 0
#>

# Must match Intune Uninstall.ps1 (v1.5.22) exactly: current IME AppMarkers
# path first, then the pre-v1.5.18 legacy path.
$script:MarkerFiles = @(
    'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\M365PreCleanup.marker',
    'C:\ProgramData\HallCountyMIS\M365PreCleanup.marker'
)

try {
    foreach ($markerFile in $script:MarkerFiles) {
        if (Test-Path -LiteralPath $markerFile -PathType Leaf) {
            Remove-Item -LiteralPath $markerFile -Force -ErrorAction Stop
        }
    }

    exit 0
}
catch {
    # Uninstall failures are non-critical. Always exit 0 so PDQ/Intune does not
    # retry the uninstall indefinitely for a marker file that may already be gone.
    exit 0
}
