#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Installs the Print Management Console capability through PDQ Deploy.

.DESCRIPTION
    PDQ counterpart to Install-PrintManagementConsole.ps1. Resolves the
    exact capability by name prefix (tolerant of a revision-suffix change
    across Windows builds), adds it when needed, validates its resulting
    DISM state, and returns 3010 for reboot-pending success. A capability
    state of UninstallPending means a removal is in progress, not an
    install, so it is treated as an unexpected precondition rather than a
    completed install. The separate marker companion must run as the last
    PDQ package step. No filestore payload is required, so Local System is
    appropriate. Logs only on error to the Intune counterpart log with
    [PDQ].

    If the default online source (Windows Update or, on WSUS-managed
    devices, WSUS - which typically does not carry Features-on-Demand
    content) fails to provide the capability, e.g. DISM error 0x800f0954,
    the script retries once against any offline source folders bundled
    under .\Source\ next to this script, using -LimitAccess so that retry
    does not also depend on WSUS/Windows Update. Staging that content is a
    manual step - see the Source folder note below. If no offline source is
    bundled yet, behavior is unchanged from before this fallback existed.

.NOTES
    Version:        1.0.3
    Script Type:    PDQ Deploy PowerShell Step
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        PDQ install step for the Print Management Console capability

    ERROR CODES
      0    = Success or capability already installed
      3010 = Success, reboot required
      1    = Capability operation or state validation failed

    CHANGE LOG
    Change: 10/09/2026 - Retry a failed Add-WindowsCapability against a bundled offline source (.\Source\<build>\) with -LimitAccess, for WSUS-managed devices where WSUS does not carry Features-on-Demand content (DISM 0x800f0954) -- ver. 1.0.3
    Change: 10/09/2026 - Resolve the capability by name prefix instead of a hardcoded exact revision suffix; no longer treat UninstallPending as a completed install -- ver. 1.0.2
    Change: 09/09/2026 - Correct reboot handling and split marker creation into its required step -- ver. 1.0.1
    Change: 09/09/2026 - Initial release -- ver. 1.0.0

    OFFLINE SOURCE (Source FOLDER)
      Optional. If present, .\Source\ (next to this script, inside the PDQ
      package) may contain one subfolder per Windows build/edition whose
      sxs (or Features-on-Demand ISO) content applies to that build, e.g.
      .\Source\Win11-24H2\, .\Source\Win10-22H2\, .\Source\Win10-LTSC-1809\.
      Every immediate subfolder is passed to Add-WindowsCapability -Source
      as an array; DISM uses whichever one matches the running device.
      Obtain the matching Features on Demand content for each build from
      the Microsoft Volume Licensing Service Center / admin center (or a
      matching Windows installation ISO's \sources\sxs folder), and stage
      it here before repackaging. This folder is empty by default - until
      content is staged for a given build, a device on that build that
      cannot reach Features-on-Demand content via its default online
      source will still fail exactly as before this fallback existed.

    PDQ CONFIGURATION
      Run as: Local System
      Success codes: 0, 3010
      Final step: Set-PrintManagementConsoleMarker-PDQ.ps1

    INTUNE COUNTERPART
      Install-PrintManagementConsole.ps1 v1.0.3
#>

$script:AppVersion       = '1.0.3'
$script:CapabilityFilter = 'Print.Management.Console*'
$script:LogRoot          = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile          = Join-Path -Path $script:LogRoot -ChildPath 'SCRIPT_PrintManagementConsole_Install.txt'
$script:SourceRoot       = Join-Path -Path $PSScriptRoot -ChildPath 'Source'

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

function Add-CapabilityWithFallback {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    try {
        return @(Add-WindowsCapability -Online -Name $Name -ErrorAction Stop)
    }
    catch {
        $PrimaryError = $_
        $FallbackSources = @()
        if (Test-Path -LiteralPath $script:SourceRoot -PathType Container) {
            $FallbackSources = @(Get-ChildItem -LiteralPath $script:SourceRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        }
        if ($FallbackSources.Count -eq 0) {
            throw $PrimaryError
        }

        Write-ErrorLog -Message "Add-WindowsCapability failed via the default online source ($($PrimaryError.Exception.Message)); retrying against bundled offline source(s): $($FallbackSources -join ', ')"
        return @(Add-WindowsCapability -Online -Name $Name -Source $FallbackSources -LimitAccess -ErrorAction Stop)
    }
}

try {
    $Capability = Get-CapabilityInfo -Name $script:CapabilityFilter
    $script:CapabilityName = $Capability.Name
    $InitialState = [string]$Capability.State

    if ($InitialState -eq 'Installed') {
        exit 0
    }
    if ($InitialState -eq 'InstallPending') {
        exit 3010
    }
    if ($InitialState -notin @('NotPresent', 'Removed', 'Staged')) {
        throw "Capability state before install is '$InitialState'; installation was not attempted."
    }

    $Results = Add-CapabilityWithFallback -Name $script:CapabilityName
    if ($Results.Count -ne 1 -or $null -eq $Results[0].PSObject.Properties['RestartNeeded']) {
        throw 'Add-WindowsCapability returned an unexpected result object.'
    }

    $State = [string](Get-CapabilityInfo -Name $script:CapabilityName).State
    $RestartNeeded = [bool]$Results[0].RestartNeeded
    if ($RestartNeeded) {
        if ($State -notin @('Installed', 'InstallPending')) {
            throw "Capability state after reboot-required install is '$State'; expected 'Installed' or 'InstallPending'."
        }
        exit 3010
    }

    if ($State -ne 'Installed') {
        throw "Capability state after install is '$State'; expected 'Installed'."
    }

    exit 0
}
catch {
    Write-ErrorLog -Message "PDQ install failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    exit 1
}
