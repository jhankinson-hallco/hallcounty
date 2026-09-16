#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Read-only safety-net check: confirms only the expected 5.3.8 Barracuda
    NAC version is registered after install. Removes nothing.

.DESCRIPTION
    Standalone PDQ Deploy package step. Run this as a step AFTER the
    BarracudaNAC-SAML.exe install step in the PDQ package (the install step
    itself is a raw "Install" step type in PDQ, not a PowerShell script, so
    it cannot run this logic inline).

    PDQ's package already runs PDQ\Uninstall-BarracudaNACVPN-PDQ.ps1 (twice)
    before this install step, so the machine is expected to be clean of any
    prior Barracuda NAC registration before the installer ever runs - see
    the separate Intune legacy-removal dependency app for the equivalent
    Intune-side pre-install cleanup.

    This script performs NO removal and calls msiexec for nothing. It exists
    only because pre-install cleanup is a defense against BarracudaNAC-SAML.exe
    being a chained/multi-package InstallShield transaction (/clone_wait)
    confirmed live, 2026-09-08, to leave an old version registered alongside
    the new one - if the installer turns out to bundle an old version even
    when starting from a clean machine, this check fails loudly instead of
    silently shipping both versions again.

    Script-authored logging is error-only, to
    <LogRoot>\APP_BarracudaNACVPN_LegacyCheck.txt, where <LogRoot> is:
      - C:\ProgramData\Microsoft\IntuneManagementExtension\Logs, if that
        folder already exists (a plain folder existence check only); or
      - C:\BarracudaInstallLogs, if it does not.

.NOTES
    Version:            1.0.1
    Script Type:        PDQ Deploy PowerShell Step
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      08/09/2026
    Purpose:            Fail loudly if any Barracuda NAC version other than the expected one is registered after install

    ERROR CODES
      0 - Only the expected Barracuda version is registered
      1 - The expected state could not be proven

    Intune counterpart: Install-BarracudaNACVPN.ps1 v1.0.6 (Get-UnexpectedBarracudaVersions)

    CHANGE LOG
    Change: 08/09/2026 - Initial release. Supersedes the same-day
                         Remove-BarracudaLegacyVersions-PDQ.ps1 v1.0.0 (never
                         wired into a live PDQ package), per Jeremy's direct
                         follow-up: "rather than uninstall after installing
                         the correct one, I want all versions of barracuda
                         removed from the machine so that the 5.3.8 install
                         is fresh. Once 5.3.8 is installed, it should be
                         done." Cleanup now happens BEFORE install (already
                         PDQ's architecture via the existing double-uninstall
                         step); this script is a read-only check only, kept
                         as an explicit, confirmed choice so a still-possible
                         "installer bundles the old version unconditionally"
                         scenario fails loudly instead of shipping silently
                         -- ver. 1.0.0
    Change: 09/09/2026 - Updated Intune architecture references after legacy
                         cleanup moved to a dependency app -- ver. 1.0.1

    Keep $script:ExpectedProductVersion synchronized with
    Install-BarracudaNACVPN.ps1 and Set-BarracudaNACVPNMarker-PDQ.ps1
    whenever the deployed installer changes.

    PDQ CONFIGURATION
      Package step:  PowerShell step running this script, placed AFTER the
                      BarracudaNAC-SAML.exe install step (and before the PDQ
                      marker step, if used)
      Run As:        Deploy User or Local System with local administrator rights

    RETURN CODES
      0 = Only the expected version is registered
      1 = Failure (not elevated, or one or more other versions are present)
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName               = 'BarracudaNACVPN'
$script:ScriptVersion         = '1.0.1'
$script:ExpectedProductVersion = '9.3.8012'
$script:DisplayNamePattern    = '^Barracuda Network Access Client(?:\s+\d+(?:[.\-]\d+)*)?$'
$script:PublisherPattern      = 'Barracuda Networks*'
$script:RegistryPaths         = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# Log root resolution: prefer the IME-rooted Logs folder when it already
# exists on this endpoint (a plain folder existence check -- deliberately not
# an Intune service/registry/enrollment check), otherwise fall back to a
# dedicated local folder so PDQ-only endpoints still get a durable log.
$script:ImeLogRoot      = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:FallbackLogRoot = 'C:\BarracudaInstallLogs'
$script:LogRoot = if (Test-Path -LiteralPath $script:ImeLogRoot -PathType Container) {
    $script:ImeLogRoot
}
else {
    $script:FallbackLogRoot
}
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_LegacyCheck.txt')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw. -ErrorAction SilentlyContinue on the
    # I/O calls guarantees that; -ErrorVariable still captures a failure so a
    # total logging outage (e.g. an unwritable log root) is not completely
    # silent.
    param(
        [string]$Message,
        [string]$ErrorCode = 'N/A'
    )

    try {
        $writeError = $null
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue -ErrorVariable +writeError | Out-Null
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:ScriptVersion, $ErrorCode, $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -ErrorVariable +writeError

        if ($writeError.Count -gt 0) {
            Write-Warning -Message ('Barracuda NAC VPN legacy-check logging failed for log root ''{0}'': {1}' -f $script:LogRoot, $Message)
        }
    }
    catch {
        Write-Warning -Message ('Barracuda NAC VPN legacy-check logging threw unexpectedly: {0}' -f $Message)
    }
}


function Test-IsAdministrator {
    # fltmc requires an elevated token and remains callable in Constrained
    # Language Mode, unlike the WindowsPrincipal .NET methods commonly used
    # for this check.
    $fltmcPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\fltmc.exe'
    if (-not (Test-Path -LiteralPath $fltmcPath -PathType Leaf)) {
        return $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $fltmcPath 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}


function ConvertTo-ComparableVersion {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    if ($Value.Trim() -notmatch '^0*(\d+)\.0*(\d+)\.0*(\d+)(?:\.0+)?$') {
        return ''
    }

    return ('{0}.{1}.{2}' -f ([int]$Matches[1]), ([int]$Matches[2]), ([int]$Matches[3]))
}


function Get-TrustedBarracudaEntries {
    # Read-only. Returns every uninstall-registry entry matching this
    # project's established Barracuda NAC trust rules (DisplayName pattern,
    # Publisher, WindowsInstaller=1), regardless of version.
    #
    # IMPORTANT (proven live, 2026-09-08 - see AI-Audit-Decisions.md): this
    # function comma-protects its return (return ,$entries) so 0/1/N-element
    # results all survive the function boundary correctly. That contract
    # only holds for a DIRECT assignment at the call site
    # ($result = Get-TrustedBarracudaEntries). Wrapping the call in @(...)
    # or iterating it inline via "foreach (... in Get-TrustedBarracudaEntries)"
    # both double-wrap the result and silently collapse multi-element
    # results to a single iteration. Always assign to a variable first, then
    # count or enumerate that variable.
    $entries = @()

    foreach ($registryPath in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $registryPath)) {
            continue
        }

        try {
            $subKeys = @(Get-ChildItem -LiteralPath $registryPath -ErrorAction Stop)
        }
        catch {
            continue
        }

        foreach ($subKey in $subKeys) {
            try {
                $properties = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
                $displayNameProperty = $properties.PSObject.Properties['DisplayName']
                $publisherProperty = $properties.PSObject.Properties['Publisher']
                $windowsInstallerProperty = $properties.PSObject.Properties['WindowsInstaller']
                $displayVersionProperty = $properties.PSObject.Properties['DisplayVersion']

                if ($null -eq $displayNameProperty -or $null -eq $publisherProperty -or $null -eq $windowsInstallerProperty) {
                    continue
                }
                if ([string]$displayNameProperty.Value -notmatch $script:DisplayNamePattern) {
                    continue
                }
                if ([string]$publisherProperty.Value -notlike $script:PublisherPattern) {
                    continue
                }
                if ([string]$windowsInstallerProperty.Value -ne '1') {
                    continue
                }

                $comparableVersion = ''
                if ($null -ne $displayVersionProperty) {
                    $comparableVersion = ConvertTo-ComparableVersion -Value ([string]$displayVersionProperty.Value)
                }

                $entries += New-Object -TypeName psobject -Property @{
                    DisplayName       = [string]$displayNameProperty.Value
                    ProductCode       = [string]$subKey.PSChildName
                    ComparableVersion = $comparableVersion
                    RegistryPath      = [string]$subKey.PSPath
                }
            }
            catch {
                continue
            }
        }
    }

    return ,$entries
}


function Get-UnexpectedBarracudaVersions {
    # Read-only. Returns descriptions of any trusted Barracuda NAC entry
    # that is NOT the expected version. An empty array means only the
    # expected version is present. Never calls msiexec and never modifies
    # anything.
    $unexpected = @()
    $entries = Get-TrustedBarracudaEntries
    foreach ($entry in $entries) {
        if ($entry.ComparableVersion -ne $script:ExpectedProductVersion) {
            $unexpected += ('''{0}'' ({1}), version ''{2}''' -f $entry.DisplayName, $entry.ProductCode, $entry.ComparableVersion)
        }
    }
    return ,$unexpected
}

# =============================================================================
# MAIN
# =============================================================================

try {
    if (-not (Test-IsAdministrator)) {
        Write-ErrorLog -Message 'This script requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -ErrorCode 'PERMISSIONS'
        Write-Output 'This script requires an elevated administrative token.'
        exit 1
    }

    $entries = Get-TrustedBarracudaEntries
    $expectedFound = $false
    foreach ($entry in $entries) {
        if ($entry.ComparableVersion -eq $script:ExpectedProductVersion) {
            $expectedFound = $true
            break
        }
    }

    if (-not $expectedFound) {
        Write-ErrorLog -Message ('No trusted Barracuda NAC registration with expected product version ''{0}'' was found.' -f $script:ExpectedProductVersion) -ErrorCode 'EXPECTED_MISSING'
        Write-Output ('Failed: no trusted Barracuda NAC registration with expected product version ''{0}'' was found.' -f $script:ExpectedProductVersion)
        exit 1
    }

    $unexpectedVersions = Get-UnexpectedBarracudaVersions
    if ($unexpectedVersions.Count -gt 0) {
        $unexpectedText = [string]::Join('; ', $unexpectedVersions)
        Write-ErrorLog -Message ('Expected version is registered, but one or more OTHER Barracuda NAC versions are ALSO present: {0}' -f $unexpectedText) -ErrorCode 'LEGACY_PRESENT'
        Write-Output ('Failed: expected version is registered, but one or more other Barracuda NAC versions are ALSO present: {0}' -f $unexpectedText)
        exit 1
    }

    Write-Output ('Barracuda NAC legacy-version check v{0} passed: only the expected version ({1}) is registered.' -f $script:ScriptVersion, $script:ExpectedProductVersion)
    exit 0
}
catch {
    Write-ErrorLog -Message ('Unexpected legacy-check error: {0}' -f $_.Exception.Message) -ErrorCode 'UNEXPECTED'
    Write-Output ('Unexpected legacy-check error: {0}' -f $_.Exception.Message)
    exit 1
}
