#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detection script for RingCentral Desktop Application (machine-wide MSI deployment).

.DESCRIPTION
    Detects RingCentral Desktop by checking for all required end-state items:
    - RingCentral.exe at the machine-wide install location:
      C:\Program Files\RingCentral\RingCentral.exe, at the required version or newer.
    - Machine-wide inbound firewall allow rule for that executable.
    - A version marker file containing the exact expected version stamp. This is what actually
      forces Intune to reinstall fleet-wide when a new MSI is uploaded under the same package
      name -- Intune only re-runs install when detection fails, not merely because a new package
      was uploaded, so bumping this marker's expected value (kept in sync with
      Install-RingCentral.ps1) is what flips already-"detected" devices back to "not installed."

    Runs in System context (Intune install behavior: System). The install location is
    fixed (C:\Program Files\RingCentral\) and does not depend on any user profile, so
    no user-resolution logic is required. Safe to run before any user has signed in
    (White Glove / Autopilot technician phase).

    Exit 0 + STDOUT = detected (installed).
    Exit 1 / no STDOUT = not detected (not installed).

    On unhandled exception: exits 1 (not detected) so Intune retries the install.

.NOTES
    Version:        4.5.0
    Script Type:    Microsoft Intune Win32 App
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  08/04/2026
    Purpose:        Detect machine-wide RingCentral install plus firewall rule plus version marker

    CHANGE LOG
    Change: 08/04/2026 - Initial release (marker-file-based) -- ver. 1.0.0
    Change: 09/04/2026 - Updated marker path after install script correction -- ver. 1.0.1
    Change: 09/04/2026 - Added RequiredScriptVersion guard -- ver. 1.0.2
    Change: 09/04/2026 - Removed RequiredScriptVersion guard -- ver. 1.0.3
    Change: 28/04/2026 - Replaced marker-file detection with file-based detection at MSI install path -- ver. 1.1.0
    Change: 28/04/2026 - Switched to User context; detection checks %APPDATA%\RingCentral folder -- ver. 1.2.0
    Change: 28/04/2026 - Corrected install path to %LOCALAPPDATA%\Programs\RingCentral\RingCentral.exe -- ver. 1.3.0
    Change: 28/04/2026 - Switched to System context; resolves logged-on user via WMI/ProfileList; checks exe in resolved user profile path -- ver. 2.0.0
    Change: 28/04/2026 - MSI confirmed machine-wide; simplified to direct file check at C:\Program Files\RingCentral\RingCentral.exe; removed user-resolution logic -- ver. 3.0.0
    Change: 07/07/2026 - Relocated from "RingCentral User" to "RingCentral System" alongside Install-RingCentral.ps1
                         and Uninstall-RingCentral.ps1; no logic change -- ver. 4.0.0
    Change: 07/07/2026 - Codex audit: custom detection now verifies the required machine-wide
                         firewall rule as well as RingCentral.exe -- ver. 4.1.0
    Change: 07/07/2026 - Codex audit remediation: require RingCentral.exe product/file version
                         26.2.3013.1602 or newer before reporting detection -- ver. 4.2.0
    Change: 07/07/2026 - Audit follow-up: added cross-reference comments noting the version-check
                         constant and helper functions here are duplicated verbatim from
                         Install-RingCentral.ps1 and must be kept in sync -- no logic change -- ver. 4.3.0
    Change: 08/07/2026 - Added a version marker file AND condition
                         (C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt
                         must exist and contain exactly the expected version stamp). This is what
                         actually forces Intune to reinstall fleet-wide when a new MSI is uploaded
                         under the same package name -- the FileVersionInfo check alone only
                         re-triggers install on devices where the real installed exe version is
                         genuinely below the new threshold; the marker gives an independent,
                         manually-controlled signal that does not depend on the vendor's own PE
                         version resource -- ver. 4.4.0
    Change: 08/07/2026 - Codex remediation: changed the required marker value to the full
                         MSI-backed version 26.2.3013.1602, matching Install-RingCentral.ps1 -- ver. 4.5.0
#>

# ============================
# CONFIG
# ============================
$script:AppVersion = '4.5.0'
$script:RequiredProductVersion = '26.2.3013.1602'

# Machine-wide install location confirmed from MSI verbose log (APPLICATIONFOLDER property).
$script:RingCentralExe = 'C:\Program Files\RingCentral\RingCentral.exe'
$script:FirewallRuleName = 'Hall County RingCentral - Machine'
$script:FirewallProfiles = @('Domain', 'Private')

# Must match Install-RingCentral.ps1's $script:VersionMarkerPath and
# $script:RequiredMarkerVersion exactly -- same duplication constraint as RequiredProductVersion
# above (Detect.ps1 cannot dot-source Install-RingCentral.ps1).
$script:VersionMarkerPath     = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt'
$script:RequiredMarkerVersion = '26.2.3013.1602'
# ============================
# END CONFIG
# ============================


function Test-RingCentralFirewallRule {
    param(
        [string]$DisplayName,
        [string]$Program
    )

    try {
        $rules = @(Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue)
        if ($rules.Count -ne 1) { return $false }

        $rule = $rules[0]
        if ([string]$rule.Enabled -ne 'True') { return $false }
        if ([string]$rule.Direction -ne 'Inbound') { return $false }
        if ([string]$rule.Action -ne 'Allow') { return $false }

        $profileText = [string]$rule.Profile
        if ($profileText -notmatch 'Any') {
            foreach ($firewallProfile in $script:FirewallProfiles) {
                if ($profileText -notmatch $firewallProfile) {
                    return $false
                }
            }
        }

        $filters = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction Stop)
        if ($filters.Count -ne 1) { return $false }

        return ([string]$filters[0].Program -ieq $Program)
    }
    catch {
        return $false
    }
}


function ConvertTo-VersionOrNull {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $match = [regex]::Match($Value, '\d+(\.\d+){1,3}')
    if (-not $match.Success) {
        return $null
    }

    try { return (New-Object System.Version($match.Value)) }
    catch { return $null }
}


function Get-RingCentralInstalledVersion {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop

        $productVersion = ConvertTo-VersionOrNull -Value ([string]$item.VersionInfo.ProductVersion)
        if ($null -ne $productVersion) {
            return $productVersion
        }

        return (ConvertTo-VersionOrNull -Value ([string]$item.VersionInfo.FileVersion))
    }
    catch {
        return $null
    }
}


function Test-RingCentralInstalledVersionAtLeast {
    param(
        [string]$Path,

        [string]$MinimumVersion
    )

    $installedVersion = Get-RingCentralInstalledVersion -Path $Path
    $minimum = ConvertTo-VersionOrNull -Value $MinimumVersion

    if ($null -eq $installedVersion -or $null -eq $minimum) {
        return $false
    }

    return ($installedVersion -ge $minimum)
}

function Test-VersionMarker {
    param(
        [string]$Path,
        [string]$ExpectedVersion
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        $content = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
        return ($content -eq $ExpectedVersion)
    }
    catch {
        return $false
    }
}

try {
    if ((Test-Path -LiteralPath $script:RingCentralExe -PathType Leaf) -and
        (Test-RingCentralInstalledVersionAtLeast -Path $script:RingCentralExe -MinimumVersion $script:RequiredProductVersion) -and
        (Test-RingCentralFirewallRule -DisplayName $script:FirewallRuleName -Program $script:RingCentralExe) -and
        (Test-VersionMarker -Path $script:VersionMarkerPath -ExpectedVersion $script:RequiredMarkerVersion)) {
        Write-Output ('RingCentral {0} or newer detected with machine firewall rule and version marker {1}: {2}' -f $script:RequiredProductVersion, $script:RequiredMarkerVersion, $script:RingCentralExe)
        exit 0
    }

    exit 1
}
catch {
    exit 1
}
