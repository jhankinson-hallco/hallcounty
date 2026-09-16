#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for the Barracuda NAC VPN legacy-removal
    prerequisite Win32 app.

.DESCRIPTION
    Inverted from a typical detection script by design: this app's "install"
    command (Uninstall-BarracudaLegacyVersions.ps1) REMOVES old software, so
    "detected" here means "nothing pre-5.3.8 is present, this app has
    nothing to do" - which is exactly when Intune should skip running it and
    pass straight through to the dependent 5.3.8 install app. "Not detected"
    means an older registration or unresolved legacy evidence was found, so
    Intune should run the removal script.

    No marker is checked or required. Detection performs a complete live
    uninstall-registry scan using the same trust and version rules as
    Uninstall-BarracudaLegacyVersions.ps1. It also checks known executables,
    the service, and approved residual folders when no current registration
    exists. Incomplete scans and unknown/older TRUSTED (MSI-backed) matching
    versions fail closed. A non-MSI matching registration is still version-
    classified: a proven 5.3.8-or-later entry is protected as current, while
    an older or unknown entry does NOT fail closed - the remover has no
    verified silent uninstall method for it either way, and gating detection
    on an unresolvable case would make this app report "not detected"
    forever with no way to ever clear, permanently blocking the dependent
    5.3.8 install. Surfaced as a STDOUT note instead.

    Exit 0 + STDOUT = detected (nothing pre-5.3.8 present; skip this app).
    Exit 1 / no STDOUT = not detected (a pre-5.3.8 version exists; Intune
    runs the removal script).

.NOTES
    Version:        1.0.5
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        Detect whether any pre-5.3.8 Barracuda NAC Client registration exists

    ERROR CODES
      0 - Detected; no removable legacy or orphaned evidence exists (requires STDOUT)
      1 - Not detected; removal is required or the endpoint state could not be proven

    CHANGE LOG
    Change: 09/09/2026 - Initial release -- ver. 1.0.0
    Change: 09/09/2026 - Fail closed on incomplete registry scans and unknown
                         versions; support nonzero fourth version components;
                         and include service plus approved residual folders in
                         orphaned-evidence detection -- ver. 1.0.1
    Change: 09/09/2026 - Per Jeremy's explicit instruction (nothing in Hall
                         County's environment carries Barracuda-like
                         branding; maximum removal is acceptable), dropped
                         the Publisher requirement from the trust gate to
                         match Uninstall-BarracudaLegacyVersions.ps1 v1.0.4 -
                         a DisplayName-matching entry with WindowsInstaller=1
                         is now trusted regardless of Publisher, so this
                         script correctly reports "not detected" only while
                         the removal script still has real work to do, not
                         merely because a publisher string did not match
                         -- ver. 1.0.2
    Change: 09/09/2026 - Stopped gating detection on HasUntrustedMatchingEntry
                         (a DisplayName-matching entry with no MSI product
                         code). Uninstall-BarracudaLegacyVersions.ps1 v1.0.4
                         logs and skips this case rather than removing it, so
                         it can never actually clear - leaving detection
                         gated on it would have made this app report "not
                         detected" forever and Intune re-run the removal app
                         every check-in with no way to resolve. Now surfaced
                         as a note in STDOUT instead -- ver. 1.0.3
    Change: 09/09/2026 - Classify non-MSI registrations by version instead
                         of ignoring all of them: proven 5.3.8+ entries now
                         satisfy and protect the current installation, while
                         older/unknown entries fail closed. Also defer local
                         profile-enumeration failure until residual-folder
                         detection is actually needed -- ver. 1.0.4
    Change: 09/09/2026 - Independent audit finding: v1.0.4's fail-closed
                         handling of an older/unknown non-MSI matching entry
                         permanently blocked this app - and, since it is a
                         hard dependency, the 5.3.8 install too - on any
                         machine that ever has one, with no automatic
                         recovery, for a case that has never once occurred in
                         this project. Per Jeremy's direct instruction
                         ("handle it the way you think is best"), reverted to
                         non-blocking: HasNonMsiUnknownVersion/
                         HasNonMsiPreExpectedVersion no longer gate the exit
                         code, only add a STDOUT note. The genuinely good
                         v1.0.4 addition - a proven 5.3.8-or-later non-MSI
                         entry protects the current installation - is
                         unaffected and kept -- ver. 1.0.5

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect-BarracudaLegacyVersions.ps1
      Run script as 32-bit process on 64-bit clients: No

    Paired script: Uninstall-BarracudaLegacyVersions.ps1 v1.0.6
#>

$script:ExpectedProductVersion = '9.3.8012'
$script:DisplayNamePattern     = '^Barracuda Network Access Client(?:\s+\d+(?:[.\-]\d+)*)?$'
$script:RegistryPaths          = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:ServiceName = 'cudanacsvc'
$script:ProgramFilesX86 = ${env:ProgramFiles(x86)}
if ([string]::IsNullOrWhiteSpace($script:ProgramFilesX86)) {
    $script:ProgramFilesX86 = $env:ProgramFiles
}

$script:DetectionPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\nacvpn.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\nacfw.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\cudanacsvc.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\nacvpn.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\nacfw.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\cudanacsvc.exe')
)

$script:ResidualFolderPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda\Network Access Client'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda Networks\Network Access Client'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda\NAC'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda Networks\NAC'),
    (Join-Path -Path $env:ProgramData -ChildPath 'ngclient')
)

$script:PathDiscoveryComplete = $true
$script:ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0')
try {
    $UserProfileDirs = @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction Stop |
        Where-Object { ($script:ExcludedProfileNames -notcontains $_.Name) -and ((([string]$_.Attributes) -split ', ') -notcontains 'ReparsePoint') })
}
catch {
    $UserProfileDirs = @()
    $script:PathDiscoveryComplete = $false
}

foreach ($ProfileDir in $UserProfileDirs) {
    $script:ResidualFolderPaths += (Join-Path -Path $ProfileDir.FullName -ChildPath 'AppData\Roaming\Barracuda\Network Access Client')
}

function ConvertTo-ComparableVersion {
    param(
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    if ($Value.Trim() -notmatch '^0*(\d+)\.0*(\d+)\.0*(\d+)(?:\.0*(\d+))?$') {
        return ''
    }

    $ComparableVersion = '{0}.{1}.{2}' -f ([int]$Matches[1]), ([int]$Matches[2]), ([int]$Matches[3])
    if (-not [string]::IsNullOrWhiteSpace([string]$Matches[4]) -and [int]$Matches[4] -gt 0) {
        $ComparableVersion += '.{0}' -f [int]$Matches[4]
    }
    return $ComparableVersion
}

function Get-VersionState {
    param(
        [string]$ComparableVersion
    )

    if ([string]::IsNullOrWhiteSpace($ComparableVersion)) {
        return 'Unknown'
    }

    try {
        if ([version]$ComparableVersion -lt [version]$script:ExpectedProductVersion) {
            return 'Older'
        }
        return 'ExpectedOrLater'
    }
    catch {
        return 'Unknown'
    }
}

function Get-BarracudaRegistryScanSummary {
    $HasPreExpectedVersion = $false
    $HasExpectedOrLaterVersion = $false
    $HasUnknownVersion = $false
    $HasNonMsiPreExpectedVersion = $false
    $HasNonMsiExpectedOrLaterVersion = $false
    $HasNonMsiUnknownVersion = $false
    $ScanErrors = @()

    foreach ($RegistryPath in $script:RegistryPaths) {
        try {
            if (-not (Test-Path -LiteralPath $RegistryPath)) {
                continue
            }
            $SubKeys = @(Get-ChildItem -LiteralPath $RegistryPath -ErrorAction Stop)
        }
        catch {
            $ScanErrors += "Unable to enumerate uninstall registry path '$RegistryPath'."
            continue
        }

        foreach ($SubKey in $SubKeys) {
            try {
                $Properties = Get-ItemProperty -LiteralPath $SubKey.PSPath -ErrorAction Stop
                $DisplayNameProperty = $Properties.PSObject.Properties['DisplayName']
                $WindowsInstallerProperty = $Properties.PSObject.Properties['WindowsInstaller']
                $DisplayVersionProperty = $Properties.PSObject.Properties['DisplayVersion']

                if ($null -eq $DisplayNameProperty) {
                    continue
                }
                if ([string]$DisplayNameProperty.Value -notmatch $script:DisplayNamePattern) {
                    continue
                }

                $ComparableVersion = ''
                if ($null -ne $DisplayVersionProperty) {
                    $ComparableVersion = ConvertTo-ComparableVersion -Value ([string]$DisplayVersionProperty.Value)
                }

                $VersionState = Get-VersionState -ComparableVersion $ComparableVersion
                # Publisher is deliberately NOT part of this trust gate,
                # unlike every other script in this project. A non-MSI entry
                # cannot be removed safely through msiexec, but its version
                # still determines whether this legacy prerequisite is met.
                if ($null -eq $WindowsInstallerProperty -or
                    [string]$WindowsInstallerProperty.Value -ne '1') {
                    switch ($VersionState) {
                        'Older' { $HasNonMsiPreExpectedVersion = $true }
                        'ExpectedOrLater' { $HasNonMsiExpectedOrLaterVersion = $true }
                        default { $HasNonMsiUnknownVersion = $true }
                    }
                    continue
                }

                switch ($VersionState) {
                    'Older' { $HasPreExpectedVersion = $true }
                    'ExpectedOrLater' { $HasExpectedOrLaterVersion = $true }
                    default { $HasUnknownVersion = $true }
                }
            }
            catch {
                $ScanErrors += "Unable to inspect uninstall registry entry '$($SubKey.PSPath)'."
                continue
            }
        }
    }

    return New-Object -TypeName psobject -Property @{
        HasPreExpectedVersion             = $HasPreExpectedVersion
        HasExpectedOrLaterVersion         = $HasExpectedOrLaterVersion
        HasUnknownVersion                 = $HasUnknownVersion
        HasNonMsiPreExpectedVersion       = $HasNonMsiPreExpectedVersion
        HasNonMsiExpectedOrLaterVersion   = $HasNonMsiExpectedOrLaterVersion
        HasNonMsiUnknownVersion           = $HasNonMsiUnknownVersion
        Errors                            = @($ScanErrors)
        IsComplete                        = ($ScanErrors.Count -eq 0)
    }
}

try {
    $RegistryScanSummary = Get-BarracudaRegistryScanSummary

    if (-not [bool]$RegistryScanSummary.IsComplete -or
        [bool]$RegistryScanSummary.HasUnknownVersion -or
        [bool]$RegistryScanSummary.HasPreExpectedVersion) {
        exit 1
    }

    # HasNonMsiUnknownVersion/HasNonMsiPreExpectedVersion do NOT gate
    # detection - reverted from a same-day fail-closed attempt (see the
    # 2026-09-09 decision on this exact case). The removal script can never
    # resolve that case either (no ProductCode, and no generic UninstallString
    # is safe to invoke unattended), so gating detection on it would make
    # this app report "not detected" forever with no way to ever clear, and -
    # since this app is a hard dependency - permanently block the 5.3.8
    # install on that machine over a case that has never once occurred in
    # this project. Surfaced as a note in STDOUT for visibility instead.
    $NonMsiNote = ''
    if ([bool]$RegistryScanSummary.HasNonMsiExpectedOrLaterVersion) {
        $NonMsiNote += ' At least one qualifying 5.3.8-or-later registration is non-MSI and is protected as a current-version installation.'
    }
    if ([bool]$RegistryScanSummary.HasNonMsiPreExpectedVersion -or [bool]$RegistryScanSummary.HasNonMsiUnknownVersion) {
        $NonMsiNote += ' A Barracuda NAC Client-named entry with no MSI product code was also found and could not be resolved; see the removal app''s log if it runs.'
    }

    if ([bool]$RegistryScanSummary.HasExpectedOrLaterVersion -or
        [bool]$RegistryScanSummary.HasNonMsiExpectedOrLaterVersion) {
        Write-Output ('Detected: Barracuda NAC Client 5.3.8 or later is registered and no older or unclassifiable trusted version was found; nothing for the legacy-removal app to do.' + $NonMsiNote)
        exit 0
    }

    if (-not $script:PathDiscoveryComplete) {
        exit 1
    }

    foreach ($Path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            exit 1
        }
    }

    if ($null -ne (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)) {
        exit 1
    }

    foreach ($Path in @($script:ResidualFolderPaths | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $Path) {
            exit 1
        }
    }

    Write-Output ('Detected: no pre-5.3.8 Barracuda NAC Client registration, executable, service, or residual folder found; nothing for the legacy-removal app to do.' + $NonMsiNote)
    exit 0
}
catch {
    exit 1
}
