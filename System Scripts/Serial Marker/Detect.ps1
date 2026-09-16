#Requires -Version 5.1

<#
.SYNOPSIS
    Detects whether the current device's serial marker is present and current.

.DESCRIPTION
    Custom Intune Win32 app detection script. Recomputes the device's
    current serial number, verifies the exact serial identification file,
    and checks it against the versioned marker
    written by Install-SerialMarker.ps1 (or its PDQ counterpart). Detection
    fails, forcing reinstall, if the marker is missing, its recorded
    version is stale, or its recorded serial no longer matches the
    device's current serial (e.g. after a motherboard replacement or
    re-image) - this keeps the on-disk "Serial - <SERIAL>.txt" file and
    the marker self-correcting rather than trusting a possibly stale file.

    Detection order:
      1. Intune marker (authoritative once present).
      2. PDQ marker (only consulted if the Intune marker is absent).

.NOTES
    Version:        1.0.5
    Script Type:    Microsoft Intune Win32 App - Custom Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  26/08/2026
    Purpose:        Custom detection for the SerialMarker app.
    Paired script:  Install-SerialMarker.ps1 v1.0.5

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0
    Change: 26/08/2026 - Corrected invalid-BIOS fallback handling and removed
                         advanced-function parameter decorations -- ver. 1.0.1
    Change: 26/08/2026 - Version sync only - no detection logic changed. Bumped
                         to match Install-SerialMarker.ps1 v1.0.2, which removed
                         an unnecessary marker pre-deletion step -- ver. 1.0.2
    Change: 26/08/2026 - Added exact serial-file and content validation, required
                         Status=Success in markers, and hardened punctuation-
                         variant placeholder rejection -- ver. 1.0.3
    Change: 26/08/2026 - Test-SerialFileCurrent now compares the matched file's
                         Name against the expected filename instead of comparing
                         full paths (Get-ChildItem's FullName vs. a Join-Path
                         string is not guaranteed to match byte-for-byte across
                         environments, e.g. 8.3 short-path aliasing) -- ver. 1.0.4
    Change: 27/08/2026 - Install-SerialMarker.ps1 v1.0.5 added an informational
                         hostname line below the serial in the serial file.
                         Test-SerialFileCurrent now validates only line 1
                         (the serial) instead of the entire file content, since
                         the file legitimately has more than one line now -
                         detection criteria are otherwise unchanged -- ver. 1.0.5
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName          = 'SerialMarker'
$script:RequiredVersion  = '1.0.5'
$script:TargetDir        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles'
$script:IntuneMarkerPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\$($script:AppName).marker"
$script:PdqMarkerPath    = "C:\ProgramData\PDQ\AppMarkers\$($script:AppName).marker"

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

function Get-MarkerFields {
    param(
        [string]$MarkerPath
    )
    if (-not (Test-Path -LiteralPath $MarkerPath -PathType Leaf)) { return $null }

    $VersionValue = $null
    $SerialValue  = $null
    $StatusValue  = $null
    $Content = Get-Content -LiteralPath $MarkerPath -ErrorAction Stop
    foreach ($Line in $Content) {
        if ($Line -match '^Version=(.*)$') { $VersionValue = $Matches[1].Trim() }
        if ($Line -match '^Serial=(.*)$')  { $SerialValue  = $Matches[1].Trim() }
        if ($Line -match '^Status=(.*)$')  { $StatusValue  = $Matches[1].Trim() }
    }

    return New-Object -TypeName psobject -Property @{
        Version = $VersionValue
        Serial  = $SerialValue
        Status  = $StatusValue
    }
}

function Test-MarkerCurrent {
    param(
        [string]$MarkerPath,
        [string]$RequiredVersion,
        [string]$CurrentSerial
    )
    # Returns 'Detected', 'NotDetected', or 'Absent'.
    $Fields = Get-MarkerFields -MarkerPath $MarkerPath
    if ($null -eq $Fields) { return 'Absent' }

    if ([string]::IsNullOrWhiteSpace($Fields.Version)) { return 'NotDetected' }
    if ([string]::IsNullOrWhiteSpace($Fields.Serial))  { return 'NotDetected' }
    if ($Fields.Status -ne 'Success')                  { return 'NotDetected' }

    try {
        if (([version]$Fields.Version) -lt ([version]$RequiredVersion)) { return 'NotDetected' }
    }
    catch {
        return 'NotDetected'
    }

    if ($Fields.Serial -ne $CurrentSerial) { return 'NotDetected' }

    return 'Detected'
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
    $CurrentSerial = Get-DeviceSerialNumber
    if ([string]::IsNullOrWhiteSpace($CurrentSerial)) {
        exit 1
    }

    if (-not (Test-SerialFileCurrent -CurrentSerial $CurrentSerial)) {
        exit 1
    }

    $IntuneResult = Test-MarkerCurrent -MarkerPath $script:IntuneMarkerPath -RequiredVersion $script:RequiredVersion -CurrentSerial $CurrentSerial
    if ($IntuneResult -eq 'Detected') {
        Write-Output 'Detected: current Intune marker matches this device serial'
        exit 0
    }
    if ($IntuneResult -eq 'NotDetected') {
        exit 1
    }

    $PdqResult = Test-MarkerCurrent -MarkerPath $script:PdqMarkerPath -RequiredVersion $script:RequiredVersion -CurrentSerial $CurrentSerial
    if ($PdqResult -eq 'Detected') {
        Write-Output 'Detected: PDQ marker matches this device serial'
        exit 0
    }

    exit 1
}
catch {
    exit 1
}
