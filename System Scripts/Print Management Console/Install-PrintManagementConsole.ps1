#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Installs the Print Management Console Windows Capability.

.DESCRIPTION
    Resolves the exact Print.Management.Console Windows Capability by name
    prefix (tolerant of a revision-suffix change across Windows builds),
    adds it when needed, validates its resulting DISM state, writes the
    Intune marker, and best-effort removes any stale PDQ marker so it does
    not survive an Intune takeover. Reboot-pending success returns 3010
    instead of being treated as a failure. A capability state of
    UninstallPending means a removal is in progress, not an install, so it
    is treated as an unexpected precondition rather than a completed
    install. Logs only on error.

    If the default online source (Windows Update or, on WSUS-managed
    devices, WSUS - which typically does not carry Features-on-Demand
    content) fails to provide the capability, e.g. DISM error 0x800f0954,
    the script retries once against any offline source folders bundled
    under .\Source\ in the package, using -LimitAccess so that retry does
    not also depend on WSUS/Windows Update. Staging that content is a
    manual step - see the Source folder note below. If no offline source is
    bundled yet, behavior is unchanged from before this fallback existed.

.NOTES
    Version:        1.0.3
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        Install the Print Management Console Windows Capability

    ERROR CODES
      0    = Success
      3010 = Success, reboot required
      1    = Capability operation, state validation, or marker handling failed

    CHANGE LOG
    Change: 10/09/2026 - Retry a failed Add-WindowsCapability against a bundled offline source (.\Source\<build>\) with -LimitAccess, for WSUS-managed devices where WSUS does not carry Features-on-Demand content (DISM 0x800f0954) -- ver. 1.0.3
    Change: 10/09/2026 - Resolve the capability by name prefix instead of a hardcoded exact revision suffix; no longer treat UninstallPending as a completed install; stale PDQ marker removal is best-effort and logs a warning instead of failing the run -- ver. 1.0.2
    Change: 09/09/2026 - Correct reboot-state, marker, logging, and idempotency handling -- ver. 1.0.1
    Change: 09/09/2026 - Initial release -- ver. 1.0.0

    OFFLINE SOURCE (Source FOLDER)
      Optional. If present, .\Source\ may contain one subfolder per Windows
      build/edition whose sxs (or Features-on-Demand ISO) content applies to
      that build, e.g. .\Source\Win11-24H2\, .\Source\Win10-22H2\,
      .\Source\Win10-LTSC-1809\. Every immediate subfolder is passed to
      Add-WindowsCapability -Source as an array; DISM uses whichever one
      matches the running device. Obtain the matching Features on Demand
      content for each build from the Microsoft Volume Licensing Service
      Center / admin center (or a matching Windows installation ISO's
      \sources\sxs folder), and stage it here before packaging. This folder
      is empty by default - until content is staged for a given build, a
      device on that build that cannot reach Features-on-Demand content via
      its default online source will still fail exactly as before this
      fallback existed.

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-PrintManagementConsole.ps1

      Install behavior: System
      Device restart behavior: Determine behavior based on return codes
      Additional return code: 3010 = Soft reboot
      Detection script: Detect.ps1
      Run detection as 32-bit process on 64-bit clients: No
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName           = 'PrintManagementConsole'
$script:AppVersion        = '1.0.3'
$script:CapabilityFilter  = 'Print.Management.Console*'
$script:MarkerVersion     = '0.0.1.0'
$script:MarkerRoot        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:MarkerPath        = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')
$script:PdqMarkerPath     = Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath ($script:AppName + '.marker')
$script:LogRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile           = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_' + $script:AppName + '_Install.txt')
$script:SourceRoot        = Join-Path -Path $PSScriptRoot -ChildPath 'Source'

# =============================================================================
# END CONFIGURATION
# =============================================================================

function Write-ErrorLog {
    param(
        [string]$Message
    )

    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = "$Timestamp [v$($script:AppVersion)] [System] $Message"
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

function Write-AppMarker {
    param(
        [string]$Status
    )

    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
    }

    @(
        "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Version=$($script:MarkerVersion)"
        "Status=$Status"
    ) | Set-Content -LiteralPath $script:MarkerPath -Encoding UTF8 -ErrorAction Stop
}

function Remove-StalePdqMarker {
    try {
        if (Test-Path -LiteralPath $script:PdqMarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $script:PdqMarkerPath -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Could not remove stale PDQ marker at '$($script:PdqMarkerPath)': $($_.Exception.Message)"
    }
}

try {
    $Capability = Get-CapabilityInfo -Name $script:CapabilityFilter
    $script:CapabilityName = $Capability.Name
    $InitialState = [string]$Capability.State

    if ($InitialState -eq 'Installed') {
        Write-AppMarker -Status 'Success'
        Remove-StalePdqMarker
        exit 0
    }
    if ($InitialState -eq 'InstallPending') {
        Write-AppMarker -Status 'RebootRequired'
        Remove-StalePdqMarker
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

        Write-AppMarker -Status 'RebootRequired'
        Remove-StalePdqMarker
        exit 3010
    }

    if ($State -ne 'Installed') {
        throw "Capability state after install is '$State'; expected 'Installed'."
    }

    Write-AppMarker -Status 'Success'
    Remove-StalePdqMarker
    exit 0
}
catch {
    Write-ErrorLog -Message "Install failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    exit 1
}
