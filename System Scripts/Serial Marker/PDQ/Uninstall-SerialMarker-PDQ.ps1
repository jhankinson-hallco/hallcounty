#Requires -Version 5.1

<#
.SYNOPSIS
    Removes the serial identification file and all marker tiers (PDQ Deploy step).

.DESCRIPTION
    PDQ Deploy uninstall package step. Mirrors Uninstall-SerialMarker.ps1
    (Intune counterpart v1.0.4): removes any "Serial - *.txt" file(s) and
    all marker tiers (Intune, PDQ, and legacy), per the 2026-08-20 policy that
    every uninstall script removes all marker tiers for its app regardless
    of which channel wrote them or which channel performs the removal.
    Attempts every cleanup tier, verifies removal, and returns a non-zero code
    if an intended artifact remains.

.NOTES
    Version:            1.0.5
    Script Type:        PDQ Deploy PowerShell Step
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      26/08/2026
    Purpose:            Removes the serial identification file and all marker tiers.
    Intune counterpart: Uninstall-SerialMarker.ps1 v1.0.5

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0
    Change: 26/08/2026 - Added verified cleanup and failure exit codes so a
                         leftover marker cannot be reported as a successful
                         uninstall -- ver. 1.0.1
    Change: 26/08/2026 - Added a distinct exit code for when both cleanup
                         tiers fail in the same run, and switched internal
                         logging to the named exit-code constants instead of
                         hardcoded string literals -- ver. 1.0.2
    Change: 26/08/2026 - Added legacy .tag/.marker tier cleanup required by the
                         all-marker-tier uninstall policy -- ver. 1.0.3
    Change: 26/08/2026 - Version sync only - no logic changed here. Bumped to
                         match the Intune counterpart's v1.0.4 -- ver. 1.0.4
    Change: 27/08/2026 - Version sync only - no logic changed here. Cleanup
                         matches by filename pattern regardless of content, so
                         the v1.0.5 hostname-line addition does not affect this
                         script -- ver. 1.0.5

    RETURN CODES
      0    = Success or already absent
      1602 = Failed to remove one or more serial identification files
      1603 = Failed to remove one or more marker tiers
      1604 = Failed to remove both serial identification files and marker tiers
      1699 = Unexpected error
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName    = 'SerialMarker'
$script:AppVersion = '1.0.5'
$script:ScriptName = 'SerialMarker'

$script:TargetDir        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles'
$script:IntuneMarkerPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\$($script:AppName).marker"
$script:PdqMarkerPath    = "C:\ProgramData\PDQ\AppMarkers\$($script:AppName).marker"
$script:LegacyMarkerPaths = @(
    "C:\IntuneAppMarkers\$($script:AppName).tag"
    "C:\IntuneAppMarkers\$($script:AppName).tag.tmp"
    "C:\IntuneAppMarkers\$($script:AppName).marker"
    "C:\IntuneAppMarkers\$($script:AppName).marker.tmp"
)

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_{0}_Uninstall.txt' -f $script:ScriptName)

$EXIT_SUCCESS      = 0
$ERR_FILE_REMOVE   = 1602
$ERR_MARKER_REMOVE = 1603
$ERR_BOTH_FAILED   = 1604
$ERR_UNEXPECTED    = 1699

function Write-ErrorLog {
    param(
        [string]$ErrorMessage,
        [string]$ErrorCode = 'N/A'
    )
    if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { return }
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        try { $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } catch { $ts = '(unavailable)' }
        $line = "[$ts] [PDQ] [v$script:AppVersion] [$ErrorCode] $ErrorMessage"
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Remove-SerialFiles {
    $Succeeded = $true
    try {
        if (-not (Test-Path -LiteralPath $script:TargetDir -PathType Container)) { return $true }
        $Existing = @(Get-ChildItem -LiteralPath $script:TargetDir -Filter 'Serial - *.txt' -File -ErrorAction Stop)
    }
    catch {
        Write-ErrorLog -ErrorMessage "Failed to enumerate serial files in '$script:TargetDir': $($_.Exception.Message)" -ErrorCode $ERR_FILE_REMOVE
        return $false
    }

    foreach ($File in $Existing) {
        try {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
            if (Test-Path -LiteralPath $File.FullName -PathType Leaf) {
                throw "File remains after removal: '$($File.FullName)'."
            }
        }
        catch {
            $Succeeded = $false
            Write-ErrorLog -ErrorMessage "Failed to remove serial file '$($File.FullName)': $($_.Exception.Message)" -ErrorCode $ERR_FILE_REMOVE
        }
    }

    try {
        $Remaining = @(Get-ChildItem -LiteralPath $script:TargetDir -Filter 'Serial - *.txt' -File -ErrorAction Stop)
        if ($Remaining.Count -gt 0) {
            $Succeeded = $false
            Write-ErrorLog -ErrorMessage "Serial-file cleanup verification found $($Remaining.Count) remaining file(s) in '$script:TargetDir'." -ErrorCode $ERR_FILE_REMOVE
        }
    }
    catch {
        $Succeeded = $false
        Write-ErrorLog -ErrorMessage "Failed to verify serial-file cleanup in '$script:TargetDir': $($_.Exception.Message)" -ErrorCode $ERR_FILE_REMOVE
    }

    return $Succeeded
}

function Remove-AllMarkerTiers {
    $Succeeded = $true
    $MarkerPaths = @(
        $script:IntuneMarkerPath
        ($script:IntuneMarkerPath + '.tmp')
        $script:PdqMarkerPath
        ($script:PdqMarkerPath + '.tmp')
    ) + $script:LegacyMarkerPaths
    foreach ($MarkerPath in $MarkerPaths) {
        try {
            if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
                Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
                throw "Marker remains after removal: '$MarkerPath'."
            }
        }
        catch {
            $Succeeded = $false
            Write-ErrorLog -ErrorMessage "Failed to remove marker '$MarkerPath': $($_.Exception.Message)" -ErrorCode $ERR_MARKER_REMOVE
        }
    }

    return $Succeeded
}

try {
    $FileCleanupSucceeded = Remove-SerialFiles
    $MarkerCleanupSucceeded = Remove-AllMarkerTiers

    if (-not $MarkerCleanupSucceeded -and -not $FileCleanupSucceeded) {
        Write-Output 'SerialMarker removal failed: both serial files and marker tiers remain.'
        exit $ERR_BOTH_FAILED
    }
    if (-not $MarkerCleanupSucceeded) {
        Write-Output 'SerialMarker removal failed: one or more marker tiers remain.'
        exit $ERR_MARKER_REMOVE
    }
    if (-not $FileCleanupSucceeded) {
        Write-Output 'SerialMarker removal failed: one or more serial files remain.'
        exit $ERR_FILE_REMOVE
    }

    Write-Output 'SerialMarker removed (files and all marker tiers).'
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -ErrorMessage "Unhandled exception: $($_.Exception.Message)" -ErrorCode $ERR_UNEXPECTED
    Write-Output ('SerialMarker removal failed: {0}' -f $_.Exception.Message)
    exit $ERR_UNEXPECTED
}
