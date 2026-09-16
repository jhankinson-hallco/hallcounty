#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Writes the PDQ marker for the Print Fax Scan capability.

.DESCRIPTION
    Dedicated final PDQ package step. Removes any existing PDQ marker and
    writes a clean versioned marker after the capability install step has
    succeeded. This script does not install or validate the capability.

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy PowerShell Step
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        Write the PDQ marker for the Print Fax Scan capability

    ERROR CODES
      0 = Marker written successfully
      1 = Marker creation failed

    CHANGE LOG
    Change: 09/09/2026 - Initial release -- ver. 1.0.0

    PDQ CONFIGURATION
      Run as the final install-package step after
      Install-PrintFaxScan-PDQ.ps1 v1.0.3.
      Marker version must remain synchronized with the capability version.
#>

$script:MarkerVersion = '0.0.1.0'
$script:MarkerRoot    = 'C:\ProgramData\PDQ\AppMarkers'
$script:MarkerPath    = Join-Path -Path $script:MarkerRoot -ChildPath 'PrintFaxScan.marker'

try {
    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
    }

    @(
        "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Version=$($script:MarkerVersion)"
        'Status=Success'
    ) | Set-Content -LiteralPath $script:MarkerPath -Encoding UTF8 -ErrorAction Stop

    Write-Output "PDQ marker updated: $($script:MarkerPath)"
    exit 0
}
catch {
    Write-Output "Failed to write PDQ marker: $($_.Exception.Message)"
    exit 1
}
