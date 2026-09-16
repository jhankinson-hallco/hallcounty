#Requires -Version 5.1

<#
.SYNOPSIS
    Writes a serial-number identification file and marker for this device.

.DESCRIPTION
    Intune Win32 app install script. Runs as SYSTEM in device context via IME.

    - Retrieves the device serial number from Win32_BIOS, falling back to
      Win32_ComputerSystemProduct when BIOS does not report a usable value. Rejects
      common OEM placeholder values (blank BIOS fields, "To Be Filled By
      O.E.M.", all-zero strings, etc.) so the script behaves consistently
      across the mixed-manufacturer fleet (Dell, HP, Lenovo, Panasonic,
      Getac, virtual machines, and others).
    - Removes any pre-existing "Serial - *.txt" file(s) in the target
      folder, then writes "Serial - <SERIAL>.txt" containing the current
      serial number on line 1 and the current hostname on line 2
      (informational only - not part of detection):
      C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\Serial - <SERIAL>.txt
    - Writes a versioned Intune marker recording the current serial:
      C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\SerialMarker.marker
    - Removes any stale PDQ marker for this app, since a successful Intune
      install makes Intune authoritative going forward.
    - Logs only on error to
      C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_SerialMarker_Install.txt.

.NOTES
    Version:        1.0.5
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  26/08/2026
    Purpose:        Writes a per-device serial-number identification file and marker.

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0
    Change: 26/08/2026 - Corrected serial fallback validation, made cleanup
                         mandatory and verified, and removed advanced-function
                         parameter decorations -- ver. 1.0.1
    Change: 26/08/2026 - Removed the pre-deletion of the current Intune marker
                         that ran before the serial file write. Write-IntuneMarker
                         already replaces it atomically via Move-Item -Force, so
                         the pre-deletion only added a window where a transient
                         failure in an unrelated step destroyed a still-valid
                         marker for no benefit (confirmed via simulation) -- ver. 1.0.2
    Change: 26/08/2026 - Hardened known-placeholder matching against punctuation
                         variants and synchronized with exact-file detection -- ver. 1.0.3
    Change: 26/08/2026 - Version sync only - no logic changed here. Bumped to
                         match Detect.ps1 v1.0.4, which hardened its serial-file
                         comparison -- ver. 1.0.4
    Change: 27/08/2026 - Added the current hostname as an informational second
                         line in the serial file. Not used by detection -- ver. 1.0.5

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-SerialMarker.ps1

      Install behavior: System
      Detection: custom PowerShell (Detect.ps1)

    RETURN CODES
      0    = Success
      1601 = Could not determine a valid device serial number
      1602 = Failed to write or verify the serial identification file
      1603 = Failed to finalize the Intune marker and PDQ handoff
      1699 = Unexpected error
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName    = 'SerialMarker'
$script:AppVersion = '1.0.5'
$script:ScriptName = 'SerialMarker'

$script:TargetDir  = 'C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles'

$script:IntuneMarkerRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:IntuneMarkerPath = Join-Path -Path $script:IntuneMarkerRoot -ChildPath ($script:AppName + '.marker')
$script:PdqMarkerRoot    = 'C:\ProgramData\PDQ\AppMarkers'
$script:PdqMarkerPath    = Join-Path -Path $script:PdqMarkerRoot -ChildPath ($script:AppName + '.marker')

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_{0}_Install.txt' -f $script:ScriptName)

# =============================================================================
# END CONFIGURATION
# =============================================================================

$EXIT_SUCCESS      = 0
$ERR_SERIAL_FAILED = 1601
$ERR_FILE_WRITE    = 1602
$ERR_MARKER_WRITE  = 1603
$ERR_UNEXPECTED    = 1699

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    param(
        [string]$ErrorMessage,
        [string]$ErrorCode = 'N/A'
    )
    if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { return }
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        try { $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } catch { $ts = '(unavailable)' }
        $line = "[$ts] [v$script:AppVersion] [$ErrorCode] $ErrorMessage"
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
    # Primary:  Win32_BIOS.SerialNumber
    # Fallback: Win32_ComputerSystemProduct.IdentifyingNumber
    # Each candidate is normalized and validated independently so an invalid
    # BIOS placeholder cannot prevent a valid fallback from being used.
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

function Write-IntuneMarker {
    param(
        [string]$Serial
    )
    New-Item -ItemType Directory -Path $script:IntuneMarkerRoot -Force -ErrorAction Stop | Out-Null
    $TempMarkerPath = $script:IntuneMarkerPath + '.tmp'
    if (Test-Path -LiteralPath $TempMarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $TempMarkerPath -Force -ErrorAction Stop
    }

    $Lines = @()
    try { $Lines += "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" } catch { $Lines += 'Timestamp=Unavailable' }
    $Lines += "Version=$($script:AppVersion)"
    $Lines += "Serial=$Serial"
    $Lines += 'Status=Success'

    $Lines | Set-Content -LiteralPath $TempMarkerPath -Encoding UTF8 -Force -ErrorAction Stop

    $WrittenLines = @(Get-Content -LiteralPath $TempMarkerPath -ErrorAction Stop)
    if (-not ($WrittenLines -contains "Version=$($script:AppVersion)")) {
        throw "Temporary Intune marker verification did not find Version=$($script:AppVersion)."
    }
    if (-not ($WrittenLines -contains "Serial=$Serial")) {
        throw "Temporary Intune marker verification did not find Serial=$Serial."
    }
    if (-not ($WrittenLines -contains 'Status=Success')) {
        throw 'Temporary Intune marker verification did not find Status=Success.'
    }

    Move-Item -LiteralPath $TempMarkerPath -Destination $script:IntuneMarkerPath -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $script:IntuneMarkerPath -PathType Leaf)) {
        throw "Intune marker was not finalized at '$script:IntuneMarkerPath'."
    }
}

function Remove-MarkerFile {
    param(
        [string]$MarkerPath
    )
    if ([string]::IsNullOrWhiteSpace($MarkerPath)) {
        throw 'Marker path was empty.'
    }
    if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            throw "Marker remains after removal: '$MarkerPath'."
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

try {
    $Serial = Get-DeviceSerialNumber

    if ([string]::IsNullOrWhiteSpace($Serial)) {
        Write-ErrorLog -ErrorMessage '[System] Could not retrieve a valid serial number from Win32_BIOS or Win32_ComputerSystemProduct. Value was empty, a known OEM placeholder, or too short.' `
                       -ErrorCode $ERR_SERIAL_FAILED
        exit $ERR_SERIAL_FAILED
    }

    try {
        Write-SerialFile -Serial $Serial
    }
    catch {
        Write-ErrorLog -ErrorMessage "[App] Failed to write serial identification file. Serial='$Serial'. Error: $($_.Exception.Message)" `
                       -ErrorCode $ERR_FILE_WRITE
        exit $ERR_FILE_WRITE
    }

    try {
        # Write-IntuneMarker replaces any existing marker via Move-Item -Force
        # (an atomic overwrite), so the old marker is never pre-deleted here -
        # doing so would only open a window where a transient failure in this
        # block destroys a still-valid marker for no benefit.
        Remove-MarkerFile -MarkerPath $script:PdqMarkerPath
        Remove-MarkerFile -MarkerPath ($script:PdqMarkerPath + '.tmp')
        Write-IntuneMarker -Serial $Serial
    }
    catch {
        Write-ErrorLog -ErrorMessage "[App] Failed to finalize Intune marker '$script:IntuneMarkerPath' and PDQ handoff. Serial='$Serial'. Error: $($_.Exception.Message)" `
                       -ErrorCode $ERR_MARKER_WRITE
        exit $ERR_MARKER_WRITE
    }

    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -ErrorMessage "[App] Unhandled exception: $($_.Exception.Message)" `
                   -ErrorCode $ERR_UNEXPECTED
    exit $ERR_UNEXPECTED
}
