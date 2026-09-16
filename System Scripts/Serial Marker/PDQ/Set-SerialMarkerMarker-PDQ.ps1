#Requires -Version 5.1

<#
.SYNOPSIS
    Writes/updates the PDQ deployment marker for SerialMarker.

.DESCRIPTION
    Standalone PDQ Deploy package step 2 of 2. Sole job: record that PDQ
    has installed SerialMarker at the current device serial number, so
    Intune detection recognizes the existing install and does not
    reinstall it. Run as the LAST step of the PDQ package, after
    Install-SerialMarker-PDQ.ps1 succeeds. Verifies the exact current serial
    file before creating marker evidence. After the temporary marker is
    complete and verified, removes any pre-existing PDQ marker immediately
    before finalizing the new one.

.NOTES
    Version:            1.0.5
    Script Type:        PDQ Deploy PowerShell Step
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      26/08/2026
    Purpose:            Write/update the PDQ marker for SerialMarker.
    Intune counterpart: Install-SerialMarker.ps1 v1.0.5

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0
    Change: 26/08/2026 - Corrected invalid-BIOS fallback handling and added
                         marker-content verification -- ver. 1.0.1
    Change: 26/08/2026 - Removed the pre-deletion of the current marker and the
                         leftover .tmp file. Set-Content -Force and
                         Move-Item -Force already overwrite them atomically, so
                         the pre-deletion only added a window where a transient
                         failure destroyed a still-valid marker for no benefit
                         -- ver. 1.0.2
    Change: 26/08/2026 - Added exact serial-file prerequisite validation,
                         hardened placeholder rejection, and restored explicit
                         final-marker pre-removal after temp verification -- ver. 1.0.3
    Change: 26/08/2026 - Test-SerialFileCurrent now compares the matched file's
                         Name against the expected filename instead of comparing
                         full paths (Get-ChildItem's FullName vs. a Join-Path
                         string is not guaranteed to match byte-for-byte across
                         environments, e.g. 8.3 short-path aliasing) -- ver. 1.0.4
    Change: 27/08/2026 - Install-SerialMarker.ps1 v1.0.5 added an informational
                         hostname line below the serial in the serial file.
                         Test-SerialFileCurrent now validates only line 1
                         (the serial) instead of the entire file content -- ver. 1.0.5

    Keep $script:AppVersion in sync with the Intune counterpart's version
    every time this PDQ package is updated - same discipline as Intune's
    Install/Detect version sync.

    RETURN CODES
      0    = Success
      1    = Failed to write or verify the PDQ marker
      1601 = Could not determine a valid device serial number
      1602 = Current serial identification file is missing or invalid
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName    = 'SerialMarker'
$script:AppVersion = '1.0.5'
$script:TargetDir  = 'C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles'
$script:MarkerRoot = 'C:\ProgramData\PDQ\AppMarkers'
$script:MarkerPath = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')

function ConvertTo-NormalizedSerial {
    param(
        [object]$Candidate
    )

    $KnownPlaceholders = @(
        'TOBEFILLEDBYOEM'
        'SYSTEMSERIALNUMBER'
        'DEFAULTSTRING'
        'NOTAPPLICABLE'
        'NOTSPECIFIED'
        'INVALID'
        'NONE'
        'NA'
        'SERIALNUMBER'
        'CHASSISSERIALNUMBER'
    )

    if ($null -eq $Candidate) { return $null }
    $Serial = $Candidate -as [string]
    if ([string]::IsNullOrWhiteSpace($Serial)) { return $null }

    $Serial = $Serial.Trim()
    $Serial = ($Serial -replace '\s+', '')
    $Serial = $Serial.ToUpperInvariant()
    $Serial = ($Serial -replace '[^A-Z0-9\-]', '')

    if ([string]::IsNullOrWhiteSpace($Serial)) { return $null }
    $ComparableValue = $Serial -replace '[^A-Z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($ComparableValue)) { return $null }
    if ($KnownPlaceholders -contains $ComparableValue) { return $null }
    if ($ComparableValue -match '^0+$') { return $null }
    if ($ComparableValue.Length -lt 4) { return $null }

    return $Serial
}

function Get-DeviceSerialNumber {
    $BiosCandidate = $null
    try {
        $BiosCandidate = (Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber
    }
    catch { $BiosCandidate = $null }

    $Serial = ConvertTo-NormalizedSerial -Candidate $BiosCandidate
    if (-not [string]::IsNullOrWhiteSpace($Serial)) { return $Serial }

    $ProductCandidate = $null
    try {
        $ProductCandidate = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop).IdentifyingNumber
    }
    catch { $ProductCandidate = $null }

    return ConvertTo-NormalizedSerial -Candidate $ProductCandidate
}

function Test-SerialFileCurrent {
    param(
        [string]$CurrentSerial
    )
    if ([string]::IsNullOrWhiteSpace($CurrentSerial)) { return $false }
    if (-not (Test-Path -LiteralPath $script:TargetDir -PathType Container)) { return $false }

    $ExpectedPath = Join-Path -Path $script:TargetDir -ChildPath ('Serial - {0}.txt' -f $CurrentSerial)
    if (-not (Test-Path -LiteralPath $ExpectedPath -PathType Leaf)) { return $false }

    $SerialFiles = @(Get-ChildItem -LiteralPath $script:TargetDir -Filter 'Serial - *.txt' -File -ErrorAction Stop)
    if ($SerialFiles.Count -ne 1) { return $false }
    if ($SerialFiles[0].Name -ne (Split-Path -Path $ExpectedPath -Leaf)) { return $false }

    # Line 2 (hostname) is informational only and is not validated here -
    # only line 1 (the serial) is part of detection.
    $ContentLines = @(Get-Content -LiteralPath $ExpectedPath -ErrorAction Stop)
    if ($ContentLines.Count -lt 1) { return $false }
    return ($ContentLines[0].Trim() -eq $CurrentSerial)
}

try {
    $Serial = Get-DeviceSerialNumber
    if ([string]::IsNullOrWhiteSpace($Serial)) {
        Write-Output 'Failed to write PDQ marker: could not determine a valid device serial number.'
        exit 1601
    }

    if (-not (Test-SerialFileCurrent -CurrentSerial $Serial)) {
        Write-Output 'Failed to write PDQ marker: the exact current serial file is missing, duplicated, or invalid.'
        exit 1602
    }

    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction Stop | Out-Null
    $TempMarkerPath = $script:MarkerPath + '.tmp'

    $Lines = @()
    try { $Lines += "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" } catch { $Lines += 'Timestamp=Unavailable' }
    $Lines += "Version=$($script:AppVersion)"
    $Lines += "Serial=$Serial"
    $Lines += 'Status=Success'

    # The temporary marker is written and verified before the current final
    # marker is touched. Final-marker pre-removal is deferred until immediately
    # before the move, minimizing the no-marker window while satisfying the
    # PDQ companion-marker clean-write policy.
    $Lines | Set-Content -LiteralPath $TempMarkerPath -Encoding UTF8 -Force -ErrorAction Stop

    $WrittenLines = @(Get-Content -LiteralPath $TempMarkerPath -ErrorAction Stop)
    if (-not ($WrittenLines -contains "Version=$($script:AppVersion)")) {
        throw "Temporary PDQ marker verification did not find Version=$($script:AppVersion)."
    }
    if (-not ($WrittenLines -contains "Serial=$Serial")) {
        throw "Temporary PDQ marker verification did not find Serial=$Serial."
    }
    if (-not ($WrittenLines -contains 'Status=Success')) {
        throw 'Temporary PDQ marker verification did not find Status=Success.'
    }

    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
            throw "Existing PDQ marker remains after removal: '$script:MarkerPath'."
        }
    }

    Move-Item -LiteralPath $TempMarkerPath -Destination $script:MarkerPath -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf)) {
        throw "PDQ marker was not finalized at '$script:MarkerPath'."
    }

    Write-Output ('PDQ marker updated: {0} -> Version={1} Serial={2}' -f $script:MarkerPath, $script:AppVersion, $Serial)
    exit 0
}
catch {
    Write-Output ('Failed to write PDQ marker: {0}' -f $_.Exception.Message)
    exit 1
}
