#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstalls the Print Management Console capability through PDQ Deploy.

.DESCRIPTION
    PDQ counterpart to Uninstall-PrintManagementConsole.ps1. Resolves the
    exact capability by name prefix (tolerant of a revision-suffix change
    across Windows builds), removes it when present, validates its
    resulting DISM state, and best-effort removes both Intune and PDQ
    marker tiers, logging a warning rather than failing the run if a marker
    cannot be removed - the capability removal itself is what this script
    is responsible for proving. Reboot-pending success returns 3010. No
    filestore payload is required, so Local System is appropriate. Logs
    only on error to the Intune counterpart log with [PDQ].

.NOTES
    Version:        1.0.3
    Script Type:    PDQ Deploy PowerShell Step
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        PDQ uninstall step for the Print Management Console capability

    ERROR CODES
      0    = Success or capability already absent
      3010 = Success, reboot required
      1    = Capability operation or state validation failed

    CHANGE LOG
    Change: 10/09/2026 - No functional change; version bumped for cross-file version-number consistency with Uninstall-PrintManagementConsole.ps1 v1.0.3 -- ver. 1.0.3
    Change: 10/09/2026 - Resolve the capability by name prefix instead of a hardcoded exact revision suffix; marker tier cleanup is best-effort per marker and logs a warning instead of failing the run -- ver. 1.0.2
    Change: 09/09/2026 - Correct reboot, marker, logging, naming, and idempotency handling -- ver. 1.0.1
    Change: 09/09/2026 - Initial release -- ver. 1.0.0

    PDQ CONFIGURATION
      Run as: Local System
      Success codes: 0, 3010

    INTUNE COUNTERPART
      Uninstall-PrintManagementConsole.ps1 v1.0.3
#>

$script:AppName          = 'PrintManagementConsole'
$script:AppVersion       = '1.0.2'
$script:CapabilityFilter = 'Print.Management.Console*'
$script:IntuneMarkerPath = Join-Path -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers' -ChildPath ($script:AppName + '.marker')
$script:PdqMarkerPath    = Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath ($script:AppName + '.marker')
$script:LogRoot          = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile          = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_' + $script:AppName + '_Uninstall.txt')

function Write-ErrorLog {
    param(
        [string]$Message
    )

    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = "$Timestamp [v$($script:AppVersion)] [System] [PDQ] $Message"
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Get-CapabilityInfo {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $Capabilities = @(Get-WindowsCapability -Online -Name $Name -ErrorAction Stop)
    if ($Capabilities.Count -ne 1) {
        throw "Expected one capability matching '$Name'; found $($Capabilities.Count)."
    }

    return $Capabilities[0]
}

function Remove-AllAppMarkers {
    foreach ($MarkerPath in @($script:IntuneMarkerPath, $script:PdqMarkerPath)) {
        try {
            if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
                Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction Stop
            }
        }
        catch {
            Write-ErrorLog -Message "Could not remove marker at '$MarkerPath': $($_.Exception.Message)"
        }
    }
}

try {
    $Capability = Get-CapabilityInfo -Name $script:CapabilityFilter
    $script:CapabilityName = $Capability.Name
    $InitialState = [string]$Capability.State

    if ($InitialState -in @('NotPresent', 'Removed')) {
        Remove-AllAppMarkers
        exit 0
    }
    if ($InitialState -eq 'UninstallPending') {
        Remove-AllAppMarkers
        exit 3010
    }

    $Results = @(Remove-WindowsCapability -Online -Name $script:CapabilityName -ErrorAction Stop)
    if ($Results.Count -ne 1 -or $null -eq $Results[0].PSObject.Properties['RestartNeeded']) {
        throw 'Remove-WindowsCapability returned an unexpected result object.'
    }

    $State = [string](Get-CapabilityInfo -Name $script:CapabilityName).State
    $RestartNeeded = [bool]$Results[0].RestartNeeded
    if ($RestartNeeded) {
        if ($State -notin @('NotPresent', 'Removed', 'UninstallPending')) {
            throw "Capability state after reboot-required uninstall is '$State'; expected 'NotPresent', 'Removed', or 'UninstallPending'."
        }

        Remove-AllAppMarkers
        exit 3010
    }

    if ($State -notin @('NotPresent', 'Removed')) {
        throw "Capability state after uninstall is '$State'; expected 'NotPresent' or 'Removed'."
    }

    Remove-AllAppMarkers
    exit 0
}
catch {
    Write-ErrorLog -Message "PDQ uninstall failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    exit 1
}
