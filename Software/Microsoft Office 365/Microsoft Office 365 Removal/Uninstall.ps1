#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstall stub for M365 Pre-Cleanup Win32 app.

.DESCRIPTION
    Removes the completion marker written by Remove-Office365.ps1. This causes
    Detect.ps1 to report "not detected," which allows Intune to re-run the
    cleanup if the app is re-deployed or the device is reprovisioned.

    This script does NOT re-install Office. It only resets the detection state.

    Always exits 0 - uninstall failures are non-critical and should not cause
    Intune to retry the uninstall in a loop.

.NOTES
    Version:        1.5.22
    Script Type:    Microsoft Intune Win32 App (Uninstall)
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
    Change: 23/06/2026 - Version sync to 1.5.16 for package consistency -- ver. 1.5.16
    Change: 24/06/2026 - Version sync to 1.5.17 for package consistency -- ver. 1.5.17
    Change: 24/06/2026 - Version sync to 1.5.18; removes current IME AppMarkers marker
                         and legacy HallCountyMIS marker for migration cleanup -- ver. 1.5.18
    Change: 25/06/2026 - Version sync to 1.5.19 for package consistency -- ver. 1.5.19
    Change: 25/06/2026 - Version sync to 1.5.20 for package consistency -- ver. 1.5.20
    Change: 15/07/2026 - Version sync to 1.5.21 for package consistency -- ver. 1.5.21
    Change: 15/07/2026 - Version sync to 1.5.22 for package consistency -- ver. 1.5.22
#>

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
    # Uninstall failures are non-critical. Always exit 0 so Intune does not
    # retry the uninstall indefinitely for a marker file that may already be gone.
    exit 0
}
