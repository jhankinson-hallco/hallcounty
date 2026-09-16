#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Writes or updates the PDQ deployment marker for Barracuda NAC VPN.

.DESCRIPTION
    Standalone PDQ Deploy package step. Its sole job is to record that PDQ
    installed the expected Barracuda NAC VPN product version so Intune
    detection recognizes the existing installation and does not reinstall it.

    Run this as the last step of the PDQ install package, after all required
    Barracuda installation and configuration steps succeed. The script removes
    any existing PDQ marker before writing and verifying the current marker.

.NOTES
    Version:            1.0.1
    Script Type:        PDQ Deploy PowerShell Step
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      21/08/2026
    Purpose:            Write/update the PDQ marker for Barracuda NAC VPN.
    Intune counterpart: Install-BarracudaNACVPN.ps1 v1.0.3

    CHANGE LOG
    Change: 21/08/2026 - Initial release -- ver. 1.0.0
    Change: 03/09/2026 - Restored the Barracuda marker writer after the file
                         was accidentally overwritten with unrelated,
                         non-PowerShell content -- ver. 1.0.1

    Keep $script:ProductVersion synchronized with
    $script:ExpectedProductVersion in Install-BarracudaNACVPN.ps1 and
    Detect-BarracudaNACVPN.ps1 whenever the deployed installer changes.

    RETURN CODES
      0 = Marker written and verified successfully
      1 = Marker creation or verification failed
#>

$script:AppName        = 'BarracudaNACVPN'
$script:ScriptVersion  = '1.0.1'
$script:ProductVersion = '9.3.8012'
$script:MarkerRoot     = 'C:\ProgramData\PDQ\AppMarkers'
$script:MarkerPath     = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')

try {
    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction Stop | Out-Null

    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
            throw "Existing PDQ marker remains after removal: '$script:MarkerPath'."
        }
    }

    $ExpectedLine = 'ProductVersion=' + $script:ProductVersion
    Set-Content -LiteralPath $script:MarkerPath -Value $ExpectedLine -Encoding UTF8 -Force -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf)) {
        throw "PDQ marker was not created at '$script:MarkerPath'."
    }

    $WrittenLines = @(Get-Content -LiteralPath $script:MarkerPath -ErrorAction Stop)
    if (($WrittenLines.Count -ne 1) -or ($WrittenLines[0].Trim() -ne $ExpectedLine)) {
        throw "PDQ marker verification failed at '$script:MarkerPath'."
    }

    Write-Output ('PDQ marker updated by script v{0}: {1} -> ProductVersion={2}' -f $script:ScriptVersion, $script:MarkerPath, $script:ProductVersion)
    exit 0
}
catch {
    Write-Output ('Failed to write PDQ marker: {0}' -f $_.Exception.Message)
    exit 1
}
