#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detection script for M365 Pre-Cleanup.

.DESCRIPTION
    Checks for the version-stamped marker file written by Remove-Office365.ps1
    upon successful clean completion.

    Detection requires:
      1. The marker file exists at the configured path.
      2. The marker file contains a line that is exactly 'ScriptVersion=<version>',
         parsed line-by-line. Substring matches and partial-version matches are
         rejected - only an exact key=value match on the correct line passes.

    This ensures a new package version forces a re-run on any device whose marker
    was written by a prior version, without relying on brittle regex matching.

    Detection design: confirms the cleanup completed successfully at the required
    version. Does not re-scan for Office presence. The cleanup is a one-time
    pre-provisioning step, not an ongoing drift-correction tool.

    Exit 0 + STDOUT = detected (cleanup completed at required version).
    Exit 1 / no STDOUT = not detected.

    On exception: exits 1 and writes to stderr so the error is visible in
    Intune diagnostic captures without blocking detection retry.

.NOTES
    Version:        1.5.22
    Script Type:    Microsoft Intune Win32 App (Detection)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/04/2026
    Purpose:        Detects successful completion of M365 Pre-Cleanup at the required script version

    CHANGE LOG
    Change: 13/04/2026 - Initial release -- ver. 1.0.0
    Change: 13/04/2026 - Added ScriptVersion content validation; stderr on exception -- ver. 1.1.0
    Change: 13/04/2026 - Changed version check from regex substring match to exact line-by-line
                         key=value parse to prevent false positives on partial version strings
                         or unexpected file content -- ver. 1.2.0
    Change: 13/04/2026 - Bumped RequiredScriptVersion to 1.3.0 to match Remove-Office365.ps1 v1.3.0;
                         forces re-run on devices where marker was written by prior version -- ver. 1.3.0
    Change: 13/04/2026 - Bumped RequiredScriptVersion to 1.4.0 to match Remove-Office365.ps1 v1.4.0;
                         forces re-run on devices where marker was written by prior version -- ver. 1.4.0
    Change: 13/04/2026 - Bumped RequiredScriptVersion to 1.5.0 to match Remove-Office365.ps1 v1.5.0;
                         updated synopsis and detection output from Office 365 Pre-Cleanup to
                         M365 Pre-Cleanup for scope consistency -- ver. 1.5.0
    Change: 13/04/2026 - Updated marker file path to M365PreCleanup.marker; bumped
                         RequiredScriptVersion to 1.5.1 -- ver. 1.5.1
    Change: 13/04/2026 - Version sync to 1.5.2 for package consistency -- ver. 1.5.2
    Change: 14/04/2026 - Version sync to 1.5.3; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.3 -- ver. 1.5.3
    Change: 15/04/2026 - Version sync to 1.5.4 for package consistency -- ver. 1.5.4
    Change: 15/04/2026 - Version sync to 1.5.5 for package consistency -- ver. 1.5.5
    Change: 15/04/2026 - Version sync to 1.5.6; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.6 -- ver. 1.5.6
    Change: 15/04/2026 - Version sync to 1.5.7; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.7 -- ver. 1.5.7
    Change: 17/04/2026 - Version sync to 1.5.8; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.8 -- ver. 1.5.8
    Change: 20/04/2026 - Version sync to 1.5.9; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.9 -- ver. 1.5.9
    Change: 21/04/2026 - Version sync to 1.5.10; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.10 -- ver. 1.5.10
    Change: 22/04/2026 - Version sync to 1.5.11; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.11 -- ver. 1.5.11
    Change: 29/04/2026 - Version sync to 1.5.12; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.12 -- ver. 1.5.12
    Change: 01/05/2026 - Version sync to 1.5.13; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.13 -- ver. 1.5.13
    Change: 06/05/2026 - Version sync to 1.5.14; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.14 -- ver. 1.5.14
    Change: 06/05/2026 - Version sync to 1.5.15; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.15 -- ver. 1.5.15
    Change: 23/06/2026 - Version sync to 1.5.16; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.16 -- ver. 1.5.16
    Change: 24/06/2026 - Version sync to 1.5.17; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.17 -- ver. 1.5.17
    Change: 24/06/2026 - Version sync to 1.5.18; moved primary marker detection to
                         the IME AppMarkers folder with legacy HallCountyMIS marker
                         fallback -- ver. 1.5.18
    Change: 25/06/2026 - Version sync to 1.5.19; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.19 (best-effort OutlookForWindows
                         removal, $appxBestEffortDone guard) -- ver. 1.5.19
    Change: 25/06/2026 - Version sync to 1.5.20; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.20 AppX fail-forward hardening
                         -- ver. 1.5.20
    Change: 15/07/2026 - Version sync to 1.5.21; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.21 DISM AppX budget
                         fail-forward fix -- ver. 1.5.21
    Change: 15/07/2026 - Version sync to 1.5.22; bumped RequiredScriptVersion to match
                         Remove-Office365.ps1 v1.5.22 AppX phase budget
                         fail-forward fix -- ver. 1.5.22
#>

# Primary marker path must match the marker written by Remove-Office365.ps1.
# Legacy marker path is checked second for migration compatibility only.
$script:MarkerFiles = @(
    'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\M365PreCleanup.marker',
    'C:\ProgramData\HallCountyMIS\M365PreCleanup.marker'
)

# Must match $script:AppVersion in Remove-Office365.ps1.
# When Remove-Office365.ps1 is updated to a new version, set this value to match
# so devices with an older marker are re-detected as not installed and re-run.
$script:RequiredScriptVersion = '1.5.22'

try {
    $expectedLine  = 'ScriptVersion={0}' -f $script:RequiredScriptVersion
    $utf8NoBom     = New-Object System.Text.UTF8Encoding($false)

    foreach ($markerFile in $script:MarkerFiles) {
        if (-not (Test-Path -LiteralPath $markerFile -PathType Leaf)) {
            continue
        }

        $content = [System.IO.File]::ReadAllText($markerFile, $utf8NoBom)

        foreach ($line in ($content -split '\r?\n')) {
            # Trim whitespace only - require exact key=value content after trimming.
            if ($line.Trim() -ceq $expectedLine) {
                Write-Output ('M365 Pre-Cleanup v{0} detected.' -f $script:RequiredScriptVersion)
                exit 0
            }
        }
    }

    # No marker exists, or marker exists but version does not match.
    exit 1
}
catch {
    [Console]::Error.WriteLine('Detect.ps1 exception: ' + $_.Exception.Message)
    exit 1
}
