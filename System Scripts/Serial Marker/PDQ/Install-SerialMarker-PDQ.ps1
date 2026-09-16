#Requires -Version 5.1

<#
.SYNOPSIS
    Writes the serial identification file for this device (PDQ Deploy step).

.DESCRIPTION
    PDQ Deploy package step 1 of 2. Mirrors Install-SerialMarker.ps1 (Intune
    counterpart v1.0.4) exactly for the on-disk artifact so Intune detection
    cannot tell whether Intune or PDQ performed the install (tandem parity).

    - Retrieves the device serial number the same way as the Intune
      counterpart: Win32_BIOS.SerialNumber, falling back to
      Win32_ComputerSystemProduct.IdentifyingNumber, rejecting common OEM
      placeholder values across the mixed-manufacturer fleet.
    - Removes any pre-existing "Serial - *.txt" file(s), then writes
      "Serial - <SERIAL>.txt" containing the current serial number on line 1
      and the current hostname on line 2 (informational only - not part of
      detection):
      C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\Serial - <SERIAL>.txt
    - Does NOT touch the Intune marker tier. Run
      Set-SerialMarkerMarker-PDQ.ps1 as the LAST step of this PDQ package
      to record the PDQ marker after this step succeeds.
    - Logs only on error to the shared log file, tagged [PDQ]:
      C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_SerialMarker_Install.txt.

.NOTES
    Version:            1.0.5
    Script Type:        PDQ Deploy PowerShell Step
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      26/08/2026
    Purpose:            Writes the per-device serial identification file (PDQ install step).
    Intune counterpart: Install-SerialMarker.ps1 v1.0.5

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0
    Change: 26/08/2026 - Corrected invalid-BIOS fallback handling, made stale
                         serial cleanup mandatory and verified, and removed
                         advanced-function parameter decorations -- ver. 1.0.1
    Change: 26/08/2026 - Version sync only - this step never touched the
                         marker tier, so no logic changed here. Bumped to
                         match the Intune counterpart's v1.0.2 -- ver. 1.0.2
    Change: 26/08/2026 - Hardened punctuation-variant placeholder rejection and
                         corrected unexpected-error logging -- ver. 1.0.3
    Change: 26/08/2026 - Version sync only - this step never touched the
                         marker tier, so no logic changed here. Bumped to
                         match the Intune counterpart's v1.0.4 -- ver. 1.0.4
    Change: 27/08/2026 - Added the current hostname as an informational second
                         line in the serial file, mirroring the Intune
                         counterpart -- ver. 1.0.5

    RETURN CODES
      0    = Success
      1601 = Could not determine a valid device serial number
      1602 = Failed to write or verify the serial identification file
      1699 = Unexpected error
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName    = 'SerialMarker'
$script:AppVersion = '1.0.5'
$script:ScriptName = 'SerialMarker'

$script:TargetDir  = 'C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles'

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_{0}_Install.txt' -f $script:ScriptName)

$EXIT_SUCCESS      = 0
$ERR_SERIAL_FAILED = 1601
$ERR_FILE_WRITE    = 1602
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

function Remove-ExistingSerialFiles {
    param(
        [string]$FolderPath
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }
    $Existing = @(Get-ChildItem -LiteralPath $FolderPath -Filter 'Serial - *.txt' -File -ErrorAction Stop)
    foreach ($File in $Existing) {
        Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $File.FullName -PathType Leaf) {
            throw "Serial file remains after removal: '$($File.FullName)'."
        }
    }
}

function Write-SerialFile {
    param(
        [string]$Serial
    )
    New-Item -ItemType Directory -Path $script:TargetDir -Force -ErrorAction Stop | Out-Null

    Remove-ExistingSerialFiles -FolderPath $script:TargetDir

    $HostName = $env:COMPUTERNAME
    $TargetPath = Join-Path -Path $script:TargetDir -ChildPath ('Serial - {0}.txt' -f $Serial)
    @($Serial, $HostName) | Set-Content -LiteralPath $TargetPath -Encoding ASCII -Force -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        throw "Failed to create serial file '$TargetPath'."
    }

    $WrittenLines = @(Get-Content -LiteralPath $TargetPath -ErrorAction Stop)
    if ($WrittenLines.Count -lt 2) {
        throw "Serial file verification failed. Expected 2 lines (serial and hostname), got $($WrittenLines.Count)."
    }
    if ($WrittenLines[0].Trim() -ne $Serial) {
        throw "Serial file verification failed. Expected serial '$Serial' on line 1, got '$($WrittenLines[0].Trim())'."
    }
    if ($WrittenLines[1].Trim() -ne $HostName) {
        throw "Serial file verification failed. Expected hostname '$HostName' on line 2, got '$($WrittenLines[1].Trim())'."
    }
}

try {
    $Serial = Get-DeviceSerialNumber
    if ([string]::IsNullOrWhiteSpace($Serial)) {
        Write-ErrorLog -ErrorMessage 'Could not retrieve a valid serial number from Win32_BIOS or Win32_ComputerSystemProduct.' -ErrorCode $ERR_SERIAL_FAILED
        exit $ERR_SERIAL_FAILED
    }

    try {
        Write-SerialFile -Serial $Serial
    }
    catch {
        Write-ErrorLog -ErrorMessage "Failed to write serial identification file. Serial='$Serial'. Error: $($_.Exception.Message)" -ErrorCode $ERR_FILE_WRITE
        exit $ERR_FILE_WRITE
    }

    Write-Output ('Serial file written: Serial - {0}.txt' -f $Serial)
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -ErrorMessage "Unhandled exception: $($_.Exception.Message)" -ErrorCode $ERR_UNEXPECTED
    exit $ERR_UNEXPECTED
}
