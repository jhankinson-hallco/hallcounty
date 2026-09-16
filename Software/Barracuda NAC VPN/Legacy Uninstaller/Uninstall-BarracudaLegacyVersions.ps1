#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Standalone Intune Win32 App prerequisite: removes any Barracuda Network
    Access Client version older than 5.3.8, then requests an Intune-managed
    hard restart.

.DESCRIPTION
    Deployed as a separate Win32 app, assigned as a DEPENDENCY of the main
    Barracuda NAC VPN 5.3.8 install app (Install-BarracudaNACVPN.ps1) - not
    directly assigned to any device/user group itself. Detect-BarracudaLegacyVersions.ps1
    is this app's detection script: if no removable older Barracuda NAC
    evidence exists, detection reports "already satisfied" and Intune passes
    straight through to evaluate/install the dependent 5.3.8 app. If removable
    legacy evidence is found, this script removes it and requests the required
    hard restart. An older/unknown non-MSI registration cannot be removed (no
    ProductCode exists, and no generic UninstallString is safe to invoke
    unattended) - it is logged and does not block the rest of this script,
    since blocking here would also skip completely unrelated, safe cleanup
    work and would permanently block the dependent 5.3.8 install over a case
    that has never once occurred in this project. A proven 5.3.8-or-later
    non-MSI registration is still protected as current.

    After a real removal is verified, the script exits 1641. The Intune app
    maps 1641 to Hard reboot and uses "Determine behavior based on return
    codes," so Intune immediately restarts the device and holds the dependent
    5.3.8 app until reboot completes. The script does not call shutdown.exe
    directly; using one authoritative restart mechanism avoids native-command
    quoting failures and competing restart signals.

    Confirmed live, 2026-09-09: Intune applies no restart grace period or
    user-facing warning to a DEPENDENCY app's 1641 specifically - it
    force-reboots as soon as IME processes the code, with nothing shown to
    the user. An earlier revision waited 3 minutes before returning 1641
    specifically to warn the user; since that wait was never actually
    visible to anyone, it was removed outright rather than kept as a
    pointless delay. Intune initiates the hard restart as soon as it processes
    the mapped 1641 result. Clean/no-op systems exit 0 immediately without
    any restart.

    Root cause this exists to work around (confirmed live, 2026-09-08 - see
    AI-Audit-Decisions.md): BarracudaNAC-SAML.exe (5.3.8) silently completes
    a leftover/incomplete prior Windows Installer transaction for an older
    version during its own install, when run silently. Jeremy confirmed live
    that a REAL machine restart between removing an old version and running
    the 5.3.8 installer reliably prevents the old version from reappearing -
    this script's whole purpose is to guarantee that restart happens as a
    required, tracked prerequisite step, rather than relying on an
    in-script process sweep (which turned out to plausibly be part of the
    problem, not the fix - see the same decision entry).

    Order of operations, reusing this project's already-proven uninstall
    machinery (see Uninstall-BarracudaNACVPN.ps1 for the shared design
    rationale of each step):
      1. Scans the uninstall registry for every entry matching the exact
         Barracuda NAC DisplayName family (Publisher is deliberately not
         required - see below), computes each entry's comparable version,
         and refuses destructive action when a TRUSTED (MSI-backed) version
         cannot be classified. An older/unknown non-MSI entry has no
         resolvable ProductCode and is logged rather than blocking the run.
      2. For a proven legacy-only installation, removes Machine-context VPN
         profiles while the software still works. Profiles are preserved when
         5.3.8 or later is also registered.
      3. Removes via msiexec /x every MSI-backed product whose version is
         older than 5.3.8. An entry at 5.3.8 or later is left alone (should
         normally not be encountered
         in practice, since detection prevents this script from running
         when one exists - this is a defensive exclusion, not the primary
         mechanism).
      4. Stops known client processes and removes the same explicit,
         whitelisted residual folders (Program Files, Program Files (x86),
         ProgramData, and every local user profile's roaming AppData
         folder) as the main uninstall script, with the same retry-on-
         transient-lock behavior.
      5. Removes the Public Desktop shortcut and every marker tier for this
         app (current Intune, PDQ, legacy) - not because THIS script uses
         markers, but because a stale marker from a PREVIOUS deployment
         must not be left behind to confuse Detect-BarracudaNACVPN.ps1
         once 5.3.8 installs.
      6. Only if a real removal happened (not on the already-nothing-to-do
         idempotent path): exits 1641 so Intune performs the hard restart
         and waits for the reboot before continuing the dependency chain.

    Deliberately does NOT run the msiexec-process-sweep pattern used
    elsewhere in this project (see Uninstall-BarracudaNACVPN.ps1's own
    2026-09-08 diagnostic history) - live evidence points to that sweep
    interrupting a still-finishing background msiexec.exe belonging to the
    SAME transaction it was trying to protect, leaving an incomplete
    transaction behind. A real restart is the confirmed fix; a process
    sweep is not.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_BarracudaNACVPNLegacyRemoval_Install.txt

    Exit Codes:
        0    = Success (nothing needed removing)
        1    = Failure (removal or verification did not complete safely)
        1641 = Success; removal completed or Windows Installer requires a
               reboot, and Intune must hard-restart before continuing

.NOTES
    Version:            1.0.6
    Script Type:        Microsoft Intune Win32 App (dependency/prerequisite)
    Author:             Jeremy Hankinson
    Owner:              Hall County Georgia MIS
    WWW:                https://github.com/jhankinson-hallco/hallcounty
    Creation Date:      09/09/2026
    Purpose:            Remove any removable pre-5.3.8 Barracuda NAC VPN installation and request an Intune hard restart before the 5.3.8 install app

    ERROR CODES
      0    - Success; nothing requires removal
      1    - Failure; removal or verification did not complete safely
      1641 - Success; Intune must perform a Hard reboot before continuing

    Detection script:   Detect-BarracudaLegacyVersions.ps1 v1.0.5

    CHANGE LOG
    Change: 09/09/2026 - Initial release. Split out of the combined
                         "uninstall then install" flow per Jeremy's direct
                         instruction, after live testing confirmed a real
                         restart between removing an old version and
                         installing 5.3.8 prevents the old version from
                         reappearing -- ver. 1.0.0
    Change: 09/09/2026 - Added a three-minute post-removal wait followed by
                         Intune Hard reboot exit 1641 so the dependent app
                         cannot start before reboot; fail-safe version handling;
                         complete registry-scan, residual-folder, service, and
                         marker/shortcut verification; protected current VPN
                         profiles; removed direct shutdown.exe control; and
                         CLM-safe exception formatting -- ver. 1.0.1
    Change: 09/09/2026 - Independent audit finding, confirmed live: Intune
                         applies no restart grace period or user-facing
                         warning to a DEPENDENCY app's 1641 - the v1.0.1
                         three-minute wait was never actually visible to the
                         user, so the warning it was meant to provide never
                         happened. Removed the wait per Jeremy's direct
                         instruction ("if there is no visible warning, then
                         the timer is pointless - remove it and just
                         shutdown when ready"). Briefly dropped to exit 0
                         entirely, then corrected the same day: exit 1641 is
                         still valuable independent of the warning question,
                         since it is what makes Intune's own dependency-
                         chain logic wait for the actual reboot before
                         starting the 5.3.8 app - conflating "the warning
                         never shows" with "the exit code is pointless" was
                         a mistake caught before shipping. Final design:
                         direct shutdown.exe call (guarantees the restart
                         regardless of Intune) AND exit 1641 (also gets
                         Intune's dependency-wait behavior), deliberately
                         redundant rather than relying on only one -- ver. 1.0.3
    Change: 09/09/2026 - Per Jeremy's explicit instruction ("we have nothing
                         in our environment that is remotely close to
                         Barracuda in branding... I want the machine to be
                         as scrubbed of barracuda as possible"), dropped the
                         Publisher requirement from the registry trust gate -
                         any DisplayName-matching entry with WindowsInstaller=1
                         is now removed via msiexec /x regardless of its
                         Publisher string, rather than permanently blocking
                         the whole run (Stop-WithFailure) whenever a
                         publisher-mismatched entry was found. A remaining,
                         much narrower case - a DisplayName-matching entry
                         that is NOT WindowsInstaller=1, so no ProductCode
                         exists to remove it by - is now logged and skipped
                         rather than blocking, since no real entry in this
                         environment has ever been non-MSI and blocking
                         forever on it would recreate the same deadlock this
                         change is meant to fix -- ver. 1.0.4
    Change: 09/09/2026 - Removed the direct shutdown.exe call and made the
                         Intune-mapped 1641 Hard reboot the only restart
                         mechanism; branch immediately when child msiexec
                         returns 3010/1641 so reboot-pending evidence is not
                         misclassified as a failure; fail closed on older or
                         unknown non-MSI registrations while allowing proven
                         5.3.8+ registrations to protect the current install;
                         and defer user-profile enumeration errors until
                         residual cleanup is actually required -- ver. 1.0.5
    Change: 09/09/2026 - Independent audit finding: v1.0.5's fail-closed
                         handling of an older/unknown non-MSI matching entry
                         (Stop-WithFailure) also skipped ALL other cleanup in
                         the same run (file/service/shortcut/marker removal
                         has nothing to do with that one unresolved registry
                         entry) and, since this app is a hard dependency,
                         permanently blocked the dependent 5.3.8 install on
                         that machine with no automatic recovery - for a case
                         that has never once occurred in this project. Per
                         Jeremy's direct instruction ("handle it the way you
                         think is best"), reverted to non-blocking: logged via
                         Write-ErrorLog, does not Stop-WithFailure, and no
                         longer re-trips post-removal verification
                         (Test-AnyLegacyBarracudaRemains and the
                         5.3.8-protected post-removal scan now only count
                         TRUSTED/MSI-backed Older-or-Unknown entries). Kept
                         Codex's genuinely good addition: a non-MSI entry
                         proven 5.3.8-or-later still protects the current
                         installation, unaffected by this change -- ver. 1.0.6

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-BarracudaLegacyVersions.ps1
      Uninstall command:
        This app is never assigned for uninstall - it exists only as a
        dependency evaluated ahead of the 5.3.8 install app. Set the
        uninstall command to the same as the install command (Intune
        requires a value) with no expectation it will ever be invoked.
      Install behavior: System
      Device restart behavior: Determine behavior based on return codes
      Return-code mappings:
        0 = Success
        1 = Failed
        1641 = Hard reboot
      Detection rule: custom detection script Detect-BarracudaLegacyVersions.ps1
        Run script as 32-bit process on 64-bit clients: No
      Assignment: do NOT assign this app directly to any group. Instead,
        add it as a Dependency of the main Barracuda NAC VPN Win32 app
        (Install-BarracudaNACVPN.ps1), in that app's Dependencies tab, so
        Intune evaluates and (if needed) installs this app automatically
        before attempting the 5.3.8 install - only the main app needs to be
        assigned to device/user groups.

    RESTART DESIGN: after verified removal, or immediately when child
    msiexec reports 3010/1641, the wrapper exits 1641. The Intune app maps
    1641 to Hard reboot and uses "Determine behavior based on return codes."
    Intune therefore owns both the restart and dependency-chain boundary.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName            = 'BarracudaNACVPNLegacyRemoval'
$script:ScriptVersion      = '1.0.6'
$script:ServiceName        = 'cudanacsvc'
$script:TimeoutSeconds     = 600
$script:OrdinarySuccessCodes = @(0, 1605, 1614)
$script:RebootSuccessCodes   = @(3010, 1641)
$script:SuccessCodes         = @($script:OrdinarySuccessCodes + $script:RebootSuccessCodes)
$script:DisplayNamePattern = '^Barracuda Network Access Client(?:\s+\d+(?:[.\-]\d+)*)?$'
$script:ExpectedProductVersion = '9.3.8012'

$script:ModulePath                 = 'C:\Program Files\Barracuda\Network Access Client\Modules\BarracudaNetworkAccessClient\BarracudaNetworkAccessClient.psd1'
$script:ProfileContext             = 'Machine'
$script:ServiceStartTimeoutSeconds = 30
$script:ClientProcessNames         = @('clrhlpr', 'nacadmin', 'nacfw', 'nacuserctx', 'nacvpn')
$script:ResidualDeleteRetryCount        = 5
$script:ResidualDeleteRetryDelaySeconds = 1

$script:ShortcutFileName  = 'Barracuda VPN Client.lnk'
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:DestShortcutPath  = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName

$script:ProgramFilesX86 = ${env:ProgramFiles(x86)}
if ([string]::IsNullOrWhiteSpace($script:ProgramFilesX86)) {
    $script:ProgramFilesX86 = $env:ProgramFiles
}

# Recursive deletion is restricted to this exact, application-specific list.
# Never delete a Barracuda vendor root recursively because another Barracuda
# product could share it. Parent roots are removed separately only when empty.
$script:ExecutableFolderPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client')
)

$script:ResidualFolderPaths = @(
    $script:ExecutableFolderPaths[0],
    $script:ExecutableFolderPaths[1],
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda\Network Access Client'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda Networks\Network Access Client'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda\NAC'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda Networks\NAC'),
    (Join-Path -Path $env:ProgramData -ChildPath 'ngclient')
)

$script:ResidualParentPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Barracuda Networks')
)

# Network Access Client also writes per-user roaming data under
# %APPDATA%\Barracuda\Network Access Client. This script runs as SYSTEM, so
# $env:APPDATA resolves to the SYSTEM profile, never a real end user's -
# every local profile under C:\Users must be enumerated directly instead.
$script:ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0')
$script:UserProfileDiscoveryError = ''
try {
    $UserProfileDirs = @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction Stop |
        Where-Object { ($script:ExcludedProfileNames -notcontains $_.Name) -and ((([string]$_.Attributes) -split ', ') -notcontains 'ReparsePoint') })
}
catch {
    $UserProfileDirs = @()
    $script:UserProfileDiscoveryError = [string]$_.Exception.Message
}

foreach ($ProfileDir in $UserProfileDirs) {
    $script:ResidualFolderPaths += (Join-Path -Path $ProfileDir.FullName -ChildPath 'AppData\Roaming\Barracuda\Network Access Client')
    $script:ResidualParentPaths += (Join-Path -Path $ProfileDir.FullName -ChildPath 'AppData\Roaming\Barracuda')
}

$script:DetectionPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\nacvpn.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\nacfw.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Barracuda\Network Access Client\cudanacsvc.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\nacvpn.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\nacfw.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Barracuda\Network Access Client\cudanacsvc.exe')
)

$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Install.txt')
$script:MsiLogFiles = @()

# Stale deployment-channel markers must be removed after legacy cleanup
# so they cannot confuse Detect-BarracudaNACVPN.ps1 once 5.3.8 installs.
$script:MainAppName      = 'BarracudaNACVPN'
$script:IntuneMarkerFile = Join-Path -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers' -ChildPath ($script:MainAppName + '.marker')
$script:PdqMarkerPath    = Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath ($script:MainAppName + '.marker')
$script:LegacyMarkerPath = Join-Path -Path 'C:\IntuneAppMarkers' -ChildPath ($script:MainAppName + '.tag')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$Category = 'App'
    )
    try {
        $WriteError = $null
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue -ErrorVariable +WriteError | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = '[{0}] [v{1}] [Intune] [{2}] {3}' -f $Timestamp, $script:ScriptVersion, $Category, $Message
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue -ErrorVariable +WriteError

        if ($WriteError.Count -gt 0) {
            Write-Warning -Message ('Barracuda NAC VPN legacy-removal logging failed for log root ''{0}'': {1}' -f $script:LogRoot, $Message)
        }
    }
    catch {
        Write-Warning -Message ('Barracuda NAC VPN legacy-removal logging threw unexpectedly: {0}' -f $Message)
    }
}

function Stop-WithFailure {
    param(
        [int]$ExitCode = 1,
        [string]$Message,
        [string]$Category = 'App'
    )
    Save-AllMsiLogsOnFailure
    Write-ErrorLog -Message $Message -Category $Category
    Write-Output $Message
    exit $ExitCode
}

function Test-IsAdministrator {
    $FltmcPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\fltmc.exe'
    if (-not (Test-Path -LiteralPath $FltmcPath -PathType Leaf)) {
        return $false
    }

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $FltmcPath 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
}

function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $Parts = @()
    $CurrentException = $ErrorRecord.Exception

    while ($null -ne $CurrentException) {
        $Message = $CurrentException.Message
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = '(no message provided)'
        }
        else {
            $Message = ($Message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }
        $Parts += ('Exception: {0}' -f $Message)
        $CurrentException = $CurrentException.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        $Parts += ('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber)
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.FullyQualifiedErrorId)) {
        $Parts += ('ErrorId: {0}' -f $ErrorRecord.FullyQualifiedErrorId)
    }

    return ($Parts -join ' | ')
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

function Remove-BarracudaVpnProfileBestEffort {
    if (-not (Test-Path -LiteralPath $script:ModulePath -PathType Leaf)) {
        Write-ErrorLog -Message "Barracuda PowerShell module not found at '$($script:ModulePath)'; skipping VPN profile removal (software likely already absent)." -Category 'App'
        return
    }

    try {
        Import-Module -Name $script:ModulePath -Force -ErrorAction Stop
        $null = Get-Command -Name 'Remove-VPNProfile' -ErrorAction Stop

        $Service = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $Service) {
            Write-ErrorLog -Message "Service '$($script:ServiceName)' not found; skipping VPN profile removal." -Category 'App'
            return
        }

        if ($Service.Status -ne 'Running') {
            Start-Service -Name $script:ServiceName -ErrorAction Stop
            $Service = Get-Service -Name $script:ServiceName -ErrorAction Stop
            $Service.WaitForStatus('Running', [TimeSpan]::FromSeconds($script:ServiceStartTimeoutSeconds))
        }

        Remove-VPNProfile -All -Context $script:ProfileContext -ErrorAction Stop | Out-Null
    }
    catch {
        Write-ErrorLog -Message "VPN profile removal did not complete cleanly (continuing with uninstall): $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
    }
}

function Stop-BarracudaClientProcessesBestEffort {
    foreach ($ProcessName in $script:ClientProcessNames) {
        $Processes = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
        foreach ($Process in $Processes) {
            try {
                $ProcessPath = [string]$Process.Path
                $ApprovedProcessPath = $false
                foreach ($FolderPath in $script:ExecutableFolderPaths) {
                    $FolderPrefix = $FolderPath.TrimEnd('\') + '\'
                    if (-not [string]::IsNullOrWhiteSpace($ProcessPath) -and $ProcessPath -like ($FolderPrefix + '*')) {
                        $ApprovedProcessPath = $true
                        break
                    }
                }
                if (-not $ApprovedProcessPath) {
                    Write-ErrorLog -Message "Process '$ProcessName' (PID $($Process.Id)) was not stopped because its executable path is outside the approved Network Access Client folders: $ProcessPath" -Category 'App'
                    continue
                }

                Stop-Process -Id $Process.Id -Force -ErrorAction Stop
            }
            catch {
                Write-ErrorLog -Message ('Failed to stop process ''{0}'' (PID {1}); continuing with uninstall: {2}' -f $ProcessName, $Process.Id, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
            }
        }
    }
}

function Remove-BarracudaServiceBestEffort {
    $Service = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $Service) {
        return $true
    }

    try {
        if ($Service.Status -ne 'Stopped') {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to stop orphaned service '$($script:ServiceName)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
    }

    $ScPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\sc.exe'
    if (-not (Test-Path -LiteralPath $ScPath -PathType Leaf)) {
        throw "sc.exe not found at '$ScPath'."
    }

    try {
        & $ScPath delete $script:ServiceName | Out-Null
        $DeleteExitCode = $LASTEXITCODE
    }
    catch {
        throw "Failed to invoke sc.exe for orphaned service '$($script:ServiceName)': $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    for ($Attempt = 1; $Attempt -le 10; $Attempt++) {
        if ($null -eq (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)) {
            return $true
        }
        Start-Sleep -Seconds 1
    }

    if ($DeleteExitCode -ne 0) {
        throw "sc.exe returned $DeleteExitCode while deleting orphaned service '$($script:ServiceName)'."
    }

    Write-ErrorLog -Message "Service '$($script:ServiceName)' is marked for deletion but remains visible until restart." -Category 'System'
    return $false
}

function Remove-EmptyBarracudaParentFoldersBestEffort {
    foreach ($ParentPath in @($script:ResidualParentPaths | Select-Object -Unique)) {
        try {
            if (-not (Test-Path -LiteralPath $ParentPath -PathType Container)) {
                continue
            }

            $ParentItem = Get-Item -LiteralPath $ParentPath -Force -ErrorAction Stop
            if ((([string]$ParentItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                Write-ErrorLog -Message "Refusing to remove empty vendor parent because it is a reparse point: $ParentPath" -Category 'System'
                continue
            }

            $Children = @(Get-ChildItem -LiteralPath $ParentPath -Force -ErrorAction Stop)
            if ($Children.Count -eq 0) {
                Remove-Item -LiteralPath $ParentPath -Force -ErrorAction Stop
            }
        }
        catch {
            Write-ErrorLog -Message "Unable to remove empty Barracuda parent folder '$ParentPath': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
        }
    }
}

function Remove-BarracudaResidualFolders {
    # Emits one path for each residual folder that remains. Caller must
    # assign the result directly (never wrap in @() or iterate the call
    # inline) - see P37 in reference_intune_pitfalls.md.
    $RemainingFolders = @()

    foreach ($FolderPath in @($script:ResidualFolderPaths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $FolderPath)) {
            continue
        }

        try {
            $FolderItem = Get-Item -LiteralPath $FolderPath -Force -ErrorAction Stop
            if (-not $FolderItem.PSIsContainer) {
                throw "Approved cleanup path exists but is not a directory: $FolderPath"
            }
            if ((([string]$FolderItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                throw "Refusing recursive deletion because the approved cleanup path is a reparse point: $FolderPath"
            }

            for ($DeleteAttempt = 1; $DeleteAttempt -le $script:ResidualDeleteRetryCount; $DeleteAttempt++) {
                try {
                    Remove-Item -LiteralPath $FolderItem.FullName -Recurse -Force -ErrorAction Stop
                    break
                }
                catch {
                    if ($DeleteAttempt -ge $script:ResidualDeleteRetryCount) {
                        throw
                    }
                    Start-Sleep -Seconds $script:ResidualDeleteRetryDelaySeconds
                }
            }
        }
        catch {
            Write-ErrorLog -Message "Residual-folder cleanup failed for '$FolderPath': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
        }

        if (Test-Path -LiteralPath $FolderPath) {
            $RemainingFolders += $FolderPath
        }
    }

    Remove-EmptyBarracudaParentFoldersBestEffort

    return ,$RemainingFolders
}

function Remove-BarracudaShortcut {
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:DestShortcutPath -Force -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        throw "Desktop shortcut still exists after removal: '$($script:DestShortcutPath)'."
    }
}

function Remove-BarracudaLegacyMarkers {
    # This script never writes a marker, but a stale one from a previous
    # deployment channel must not survive to confuse Detect-BarracudaNACVPN.ps1
    # once 5.3.8 installs.
    foreach ($MarkerPath in @($script:IntuneMarkerFile, $script:PdqMarkerPath, $script:LegacyMarkerPath)) {
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            throw "Marker file still exists after removal: '$MarkerPath'."
        }
    }
}

function Get-BarracudaLegacyUninstallEntries {
    # Trust rule is narrower than every other script in this project on
    # purpose (Publisher is not checked here - see IsTrustedTarget below),
    # plus ComparableVersion so callers can distinguish "older than 5.3.8"
    # from "5.3.8 or later." Caller must assign the result directly (never
    # @()-wrap or inline-iterate a call to this function) - P37.
    $Entries = @()
    $ScanErrors = @()

    foreach ($RegistryPath in $script:RegistryPaths) {
        try {
            if (-not (Test-Path -LiteralPath $RegistryPath)) {
                continue
            }
            $SubKeys = @(Get-ChildItem -LiteralPath $RegistryPath -ErrorAction Stop)
        }
        catch {
            $ScanError = 'Unable to enumerate uninstall registry path ''{0}'': {1}' -f $RegistryPath, (Get-ExceptionSummary -ErrorRecord $_)
            $ScanErrors += $ScanError
            Write-ErrorLog -Message $ScanError -Category 'System'
            continue
        }

        foreach ($SubKey in $SubKeys) {
            try {
                $Properties = Get-ItemProperty -LiteralPath $SubKey.PSPath -ErrorAction Stop
                $DisplayNameProperty = $Properties.PSObject.Properties['DisplayName']

                if ($null -eq $DisplayNameProperty) {
                    continue
                }

                $DisplayName = [string]$DisplayNameProperty.Value
                if ([string]::IsNullOrWhiteSpace($DisplayName) -or $DisplayName -notmatch $script:DisplayNamePattern) {
                    continue
                }

                $WindowsInstallerProperty = $Properties.PSObject.Properties['WindowsInstaller']
                $IsWindowsInstaller = $false
                if ($null -ne $WindowsInstallerProperty -and [string]$WindowsInstallerProperty.Value -eq '1') {
                    $IsWindowsInstaller = $true
                }

                $UninstallString = ''
                $UninstallStringProperty = $Properties.PSObject.Properties['UninstallString']
                if ($null -ne $UninstallStringProperty) {
                    $UninstallString = [string]$UninstallStringProperty.Value
                }

                $DisplayVersion = ''
                $DisplayVersionProperty = $Properties.PSObject.Properties['DisplayVersion']
                if ($null -ne $DisplayVersionProperty) {
                    $DisplayVersion = [string]$DisplayVersionProperty.Value
                }

                # Publisher is deliberately NOT part of this trust gate, unlike
                # every other script in this project. Jeremy confirmed live,
                # 2026-09-09, that nothing in Hall County's environment carries
                # Barracuda-like branding, and directed maximum removal of any
                # Barracuda NAC Client-named entry regardless of publisher
                # string. WindowsInstaller=1 is still required because it is
                # what makes a ProductCode-based msiexec /x removal possible
                # at all - Publisher was never protecting anything a real
                # WindowsInstaller=1 entry couldn't already prove on its own.
                $IsTrustedTarget = $IsWindowsInstaller

                $ProductCode = ''
                if ($IsTrustedTarget) {
                    if ($SubKey.PSChildName -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') {
                        $ProductCode = $SubKey.PSChildName.ToUpperInvariant()
                    }
                    elseif ($UninstallString -match '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') {
                        $ProductCode = ([string]$Matches[0]).ToUpperInvariant()
                    }
                }

                $ComparableVersion = ConvertTo-ComparableVersion -Value $DisplayVersion
                $Entries += New-Object -TypeName psobject -Property @{
                    RegistryPath      = [string]$SubKey.PSPath
                    DisplayName       = $DisplayName
                    DisplayVersion    = $DisplayVersion
                    IsTrustedTarget   = $IsTrustedTarget
                    ProductCode       = $ProductCode
                    ComparableVersion = $ComparableVersion
                    VersionState      = (Get-VersionState -ComparableVersion $ComparableVersion)
                }
            }
            catch {
                $ScanError = 'Failed to inspect uninstall registry entry ''{0}'': {1}' -f $SubKey.PSPath, (Get-ExceptionSummary -ErrorRecord $_)
                $ScanErrors += $ScanError
                Write-ErrorLog -Message $ScanError -Category 'System'
            }
        }
    }

    return New-Object -TypeName psobject -Property @{
        Entries    = @($Entries)
        Errors     = @($ScanErrors)
        IsComplete = ($ScanErrors.Count -eq 0)
    }
}

function Get-BarracudaLegacyProductCodes {
    # Trusted entries older than the expected 5.3.8 version only. A trusted
    # entry AT or AFTER 5.3.8 is deliberately excluded - defensive, since
    # detection should already prevent this script from running when one
    # exists.
    param(
        [object[]]$Entries
    )

    $ProductCodes = @()

    foreach ($Entry in @($Entries)) {
        if (-not [bool]$Entry.IsTrustedTarget) {
            continue
        }
        if ([string]$Entry.VersionState -ne 'Older') {
            continue
        }

        $ProductCode = [string]$Entry.ProductCode
        if ([string]::IsNullOrWhiteSpace($ProductCode)) {
            continue
        }

        if ($ProductCodes -notcontains $ProductCode) {
            $ProductCodes += $ProductCode
        }
    }

    return ,$ProductCodes
}

function Test-ExpectedOrLaterVersionExists {
    # Any exactly named entry at or after 5.3.8 fully explains the presence of
    # known executables (5.3.8 uses the exact same install paths this
    # script checks for orphaned-install evidence) - it is NOT orphaned
    # legacy evidence. Without this check, the "zero legacy product codes
    # but a known executable exists" branch below would misfire as soon as
    # 5.3.8 is properly installed, since its own files always match those
    # same paths - defeating detection's whole purpose of letting this
    # script stop running once only 5.3.8 remains.
    param(
        [object[]]$Entries
    )

    foreach ($Entry in @($Entries)) {
        if ([string]$Entry.VersionState -eq 'ExpectedOrLater') {
            return $true
        }
    }

    return $false
}

function Stop-ProcessTreeBestEffort {
    param(
        [int]$ProcessId
    )

    $TaskkillSucceeded = $false
    $TaskkillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'

    if (Test-Path -LiteralPath $TaskkillPath -PathType Leaf) {
        try {
            $TaskkillArguments = '/PID {0} /T /F' -f $ProcessId
            $TaskkillProcess = Start-Process -FilePath $TaskkillPath -ArgumentList $TaskkillArguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            $TaskkillSucceeded = ([int]$TaskkillProcess.ExitCode -eq 0)
        }
        catch {
            $TaskkillSucceeded = $false
        }
    }

    if (-not $TaskkillSucceeded) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Milliseconds 250
    return (@(Get-Process -Id $ProcessId -ErrorAction SilentlyContinue).Count -eq 0)
}

function Invoke-MsiUninstall {
    param(
        [string]$ProductCode
    )

    $ProductCodeForFileName = $ProductCode -replace '[^0-9A-Fa-f]', ''
    $LogTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $MsiLogFileName = '{0}_{1}_{2}_MSI_Uninstall.log' -f $script:AppName, $ProductCodeForFileName, $LogTimestamp
    $MsiLogFile = Join-Path -Path $env:TEMP -ChildPath $MsiLogFileName
    $MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $Arguments = '/x {0} /qn /norestart REBOOT=ReallySuppress /L*v "{1}"' -f $ProductCode, $MsiLogFile
    $script:MsiLogFiles += $MsiLogFile

    $Process = Start-Process -FilePath $MsiExecPath -ArgumentList $Arguments -PassThru -WindowStyle Hidden -ErrorAction Stop
    $WaitError = $null
    try {
        Wait-Process -InputObject $Process -Timeout $script:TimeoutSeconds -ErrorAction Stop
    }
    catch {
        $WaitError = $_
    }

    if ($null -ne $WaitError) {
        $ProcessStillRunning = (@(Get-Process -Id $Process.Id -ErrorAction SilentlyContinue).Count -gt 0)
        if ($ProcessStillRunning) {
            $Terminated = Stop-ProcessTreeBestEffort -ProcessId $Process.Id
            if ($Terminated) {
                throw ('msiexec.exe /x timed out after {0} seconds and its process tree was terminated.' -f $script:TimeoutSeconds)
            }
            throw ('msiexec.exe /x timed out after {0} seconds, but its process could not be confirmed stopped.' -f $script:TimeoutSeconds)
        }
    }

    return New-Object -TypeName psobject -Property @{
        ExitCode    = [int]$Process.ExitCode
        LogFile     = $MsiLogFile
        ProductCode = $ProductCode
    }
}

function Save-MsiLogOnFailure {
    param(
        [string]$SourceLogFile
    )
    try {
        if ([string]::IsNullOrWhiteSpace($SourceLogFile) -or -not (Test-Path -LiteralPath $SourceLogFile -PathType Leaf)) {
            return ''
        }

        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $DestLogFile = Join-Path -Path $script:LogRoot -ChildPath (Split-Path -Path $SourceLogFile -Leaf)
        Copy-Item -LiteralPath $SourceLogFile -Destination $DestLogFile -Force -ErrorAction Stop
        return $DestLogFile
    }
    catch {
        Write-ErrorLog -Message ('Failed to persist MSI log ''{0}'' to ''{1}'': {2}' -f $SourceLogFile, $script:LogRoot, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
        return ''
    }
}

function Save-AllMsiLogsOnFailure {
    foreach ($MsiLogFile in @($script:MsiLogFiles | Select-Object -Unique)) {
        $null = Save-MsiLogOnFailure -SourceLogFile $MsiLogFile
    }
}

function Remove-TemporaryMsiLogsBestEffort {
    foreach ($MsiLogFile in @($script:MsiLogFiles | Select-Object -Unique)) {
        Remove-Item -LiteralPath $MsiLogFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-AnyLegacyBarracudaRemains {
    # Final verification after removal: is there still a TRUSTED (MSI-backed)
    # older or unknown Barracuda NAC registration? Restricted to
    # IsTrustedTarget on purpose - an untrusted/non-MSI entry was never
    # something this script attempts to remove (see the non-blocking
    # UnresolvedNonMsiEntries handling in MAIN), so it must not fail this
    # verification either; doing so would just move the same permanent-block
    # problem here instead of preventing it.
    $RegistryScan = Get-BarracudaLegacyUninstallEntries
    if (-not [bool]$RegistryScan.IsComplete) {
        throw ('uninstall-registry scan was incomplete after removal: {0}' -f ([string]::Join('; ', @($RegistryScan.Errors))))
    }

    foreach ($Entry in @($RegistryScan.Entries)) {
        if ([bool]$Entry.IsTrustedTarget -and ([string]$Entry.VersionState -eq 'Older' -or [string]$Entry.VersionState -eq 'Unknown')) {
            return $true
        }
    }

    foreach ($Path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
    }

    return $false
}

function Exit-WithHardReboot {
    param(
        [string]$Message
    )

    Remove-TemporaryMsiLogsBestEffort
    Write-Output ($Message + ' Exiting 1641 so Intune hard-restarts the device before continuing the dependency chain.')
    exit 1641
}

# =============================================================================
# MAIN
# =============================================================================

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -ExitCode 1 -Message 'This script requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

try {
    $InitialRegistryScan = Get-BarracudaLegacyUninstallEntries
    if (-not [bool]$InitialRegistryScan.IsComplete) {
        $RegistryErrors = [string]::Join('; ', @($InitialRegistryScan.Errors))
        Stop-WithFailure -ExitCode 1 -Message ('Unable to prove the Barracuda uninstall-registry state because the scan was incomplete: {0}' -f $RegistryErrors) -Category 'System'
    }
    $UninstallEntries = @($InitialRegistryScan.Entries)

    $AmbiguousEntries = @()
    $UnresolvedNonMsiEntries = @()
    $CurrentUntrustedEntries = @()
    $UnresolvedLegacyEntries = @()
    foreach ($Entry in $UninstallEntries) {
        if (-not [bool]$Entry.IsTrustedTarget) {
            if ([string]$Entry.VersionState -eq 'ExpectedOrLater') {
                $CurrentUntrustedEntries += $Entry
            }
            else {
                $UnresolvedNonMsiEntries += $Entry
            }
            continue
        }
        if ([string]$Entry.VersionState -eq 'Unknown') {
            $AmbiguousEntries += $Entry
            continue
        }
        if ([string]$Entry.VersionState -eq 'Older' -and [string]::IsNullOrWhiteSpace([string]$Entry.ProductCode)) {
            $UnresolvedLegacyEntries += $Entry
        }
    }

    if ($UnresolvedNonMsiEntries.Count -gt 0) {
        # Non-blocking by design (reverted from a same-day fail-closed
        # attempt - see the 2026-09-09 decision on this exact case): no
        # ProductCode exists here (WindowsInstaller != 1), so there is no
        # generic, verified, safe way to remove these automatically - the
        # same reasoning that keeps this script from ever invoking an
        # arbitrary UninstallString. Blocking the ENTIRE run over this
        # would also skip the file/service/shortcut/marker cleanup below,
        # which has nothing to do with this specific unresolved registry
        # entry and is completely safe regardless - and would permanently
        # block the dependent 5.3.8 install on this machine until someone
        # manually intervenes, over a case that has never once occurred in
        # this project. Logged for visibility; everything else proceeds.
        $EntryText = [string]::Join('; ', @($UnresolvedNonMsiEntries | ForEach-Object { "'$($_.DisplayName)' DisplayVersion='$($_.DisplayVersion)' at '$($_.RegistryPath)'" }))
        Write-ErrorLog -Message ("Older or unclassifiable Barracuda NAC Client entries are not MSI-backed and have no verified noninteractive removal method; left unchanged: $EntryText") -Category 'App'
    }
    if ($CurrentUntrustedEntries.Count -gt 0) {
        $EntryText = [string]::Join('; ', @($CurrentUntrustedEntries | ForEach-Object { "'$($_.DisplayName)' DisplayVersion='$($_.DisplayVersion)' at '$($_.RegistryPath)'" }))
        Write-ErrorLog -Message ("Barracuda NAC Client entries at 5.3.8 or later are not MSI-backed. They are protected as current-version registrations: $EntryText") -Category 'App'
    }
    if ($AmbiguousEntries.Count -gt 0) {
        $EntryText = [string]::Join('; ', @($AmbiguousEntries | ForEach-Object { "'$($_.DisplayName)' DisplayVersion='$($_.DisplayVersion)' at '$($_.RegistryPath)'" }))
        Stop-WithFailure -ExitCode 1 -Message ("Trusted Barracuda entries have missing or unrecognized versions; refusing destructive removal because they are not proven older than 5.3.8: $EntryText") -Category 'App'
    }
    if ($UnresolvedLegacyEntries.Count -gt 0) {
        $EntryText = [string]::Join('; ', @($UnresolvedLegacyEntries | ForEach-Object { "'$($_.DisplayName)' at '$($_.RegistryPath)'" }))
        Stop-WithFailure -ExitCode 1 -Message ("Trusted pre-5.3.8 Barracuda entries have no resolvable MSI product code and were not changed: $EntryText") -Category 'App'
    }

    # Computed once up front. A 5.3.8+ entry can legitimately
    # coexist with a pre-5.3.8 one (e.g. a machine migrating from the old
    # deployment flow, before this prerequisite app existed) - this is NOT
    # assumed to be impossible, and gates shared-path cleanup (residual
    # folders, shortcut, markers) below rather than being treated as a
    # simple either/or with legacy removal. Those shared paths - especially
    # 'C:\Program Files\Barracuda\Network Access Client', which 5.3.8 itself
    # lives in - must never be touched while a 5.3.8+ registration
    # exists, since doing so could damage a working installation. Scoped
    # msiexec /x removal of a SPECIFIC legacy product code is always safe
    # regardless, because Get-BarracudaLegacyProductCodes already excludes
    # any code at or after the expected version.
    $ExpectedOrLaterExists = Test-ExpectedOrLaterVersionExists -Entries $UninstallEntries
    $ProductCodes = Get-BarracudaLegacyProductCodes -Entries $UninstallEntries

    if (-not $ExpectedOrLaterExists -and -not [string]::IsNullOrWhiteSpace($script:UserProfileDiscoveryError)) {
        Stop-WithFailure -ExitCode 1 -Message ("Unable to enumerate local user profiles for complete residual cleanup: $($script:UserProfileDiscoveryError)") -Category 'System'
    }

    $AnyKnownExecutable = $false
    foreach ($Path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $AnyKnownExecutable = $true
            break
        }
    }
    $ServiceExists = ($null -ne (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue))

    if ($ProductCodes.Count -eq 0) {
        if ($ExpectedOrLaterExists) {
            # 5.3.8+ already registered and no older version found. Do NOT
            # touch residual folders/shortcut/markers - they may legitimately
            # belong to the 5.3.8 installation. Detection should already
            # prevent Intune from running this script in this state; reached
            # only via manual invocation or a detection race. No restart -
            # nothing changed.
            Write-Output 'Barracuda NAC Client 5.3.8 or later is already registered and no older version was found; nothing for this prerequisite app to do.'
            exit 0
        }

        if (-not $AnyKnownExecutable -and -not $ServiceExists) {
            $ResidualEvidenceExists = $false
            foreach ($ResidualPath in @($script:ResidualFolderPaths | Select-Object -Unique)) {
                if (Test-Path -LiteralPath $ResidualPath) {
                    $ResidualEvidenceExists = $true
                    break
                }
            }

            $RemainingFolders = Remove-BarracudaResidualFolders
            if ($RemainingFolders.Count -gt 0) {
                Stop-WithFailure -ExitCode 1 -Message ('No Barracuda registration, executable, or service was found, but residual folders could not be removed: {0}' -f ([string]::Join('; ', $RemainingFolders))) -Category 'System'
            }

            Remove-BarracudaShortcut
            Remove-BarracudaLegacyMarkers

            if ($ResidualEvidenceExists) {
                Write-ErrorLog -Message 'Residual pre-5.3.8 Barracuda NAC Client folders removed. Requesting Intune hard restart.' -Category 'App'
                Exit-WithHardReboot -Message 'Residual pre-5.3.8 Barracuda NAC Client folders removed.'
            }

            Write-Output 'No pre-5.3.8 Barracuda NAC Client version found; nothing to do.'
            exit 0
        }

        Remove-BarracudaVpnProfileBestEffort
        Stop-BarracudaClientProcessesBestEffort
        $ServiceRemoved = Remove-BarracudaServiceBestEffort
        Stop-BarracudaClientProcessesBestEffort
        $RemainingFolders = Remove-BarracudaResidualFolders
        if ($RemainingFolders.Count -gt 0) {
            Stop-WithFailure -ExitCode 1 -Message ('Orphaned-install cleanup could not remove residual folders: {0}' -f ([string]::Join('; ', $RemainingFolders))) -Category 'System'
        }

        if (Test-AnyLegacyBarracudaRemains) {
            Stop-WithFailure -ExitCode 1 -Message 'Executable/service evidence was found with no resolvable pre-5.3.8 product code, and orphaned-install cleanup could not fully remove the remaining evidence.' -Category 'App'
        }

        Remove-BarracudaShortcut
        Remove-BarracudaLegacyMarkers

        $ServiceMessage = if ($ServiceRemoved) { 'service removed' } else { 'service deletion pending reboot' }
        Write-ErrorLog -Message ("Orphaned pre-5.3.8 install evidence removed ($ServiceMessage); requesting Intune hard restart.") -Category 'App'
        Exit-WithHardReboot -Message "Orphaned pre-5.3.8 Barracuda NAC Client evidence removed ($ServiceMessage)."
    }

    if (-not $ExpectedOrLaterExists) {
        Remove-BarracudaVpnProfileBestEffort
    }
    Stop-BarracudaClientProcessesBestEffort

    $MsiResults = @()
    $MsiRebootExitCode = 0
    foreach ($ProductCode in $ProductCodes) {
        $MsiResult = Invoke-MsiUninstall -ProductCode $ProductCode
        if ($script:SuccessCodes -notcontains $MsiResult.ExitCode) {
            Stop-WithFailure -ExitCode 1 -Message ('Removal failed for pre-5.3.8 product code {0}. msiexec.exe returned {1}. Check TEMP log {2}; a durable copy is attempted under {3}.' -f $ProductCode, $MsiResult.ExitCode, $MsiResult.LogFile, $script:LogRoot) -Category 'App'
        }
        $MsiResults += $MsiResult
        if ($script:RebootSuccessCodes -contains [int]$MsiResult.ExitCode) {
            $MsiRebootExitCode = [int]$MsiResult.ExitCode
            break
        }
    }

    if ($MsiRebootExitCode -ne 0) {
        $ProcessedProductCodeText = [string]::Join(', ', @($MsiResults | ForEach-Object { [string]$_.ProductCode }))
        Write-ErrorLog -Message ('Windows Installer returned reboot result {0} after processing pre-5.3.8 product code(s) {1}. Deferring remaining removal and verification until detection re-evaluates after restart.' -f $MsiRebootExitCode, $ProcessedProductCodeText) -Category 'App'
        Exit-WithHardReboot -Message ('Windows Installer requires a reboot after processing pre-5.3.8 product code(s) {0}; remaining legacy state will be reevaluated after restart.' -f $ProcessedProductCodeText)
    }

    Start-Sleep -Seconds 5
    Stop-BarracudaClientProcessesBestEffort

    $ProductCodeText = [string]::Join(', ', $ProductCodes)

    if ($ExpectedOrLaterExists) {
        $PostRemovalScan = Get-BarracudaLegacyUninstallEntries
        if (-not [bool]$PostRemovalScan.IsComplete) {
            Stop-WithFailure -ExitCode 1 -Message ('Post-removal registry scan was incomplete: {0}' -f ([string]::Join('; ', @($PostRemovalScan.Errors)))) -Category 'System'
        }
        foreach ($Entry in @($PostRemovalScan.Entries)) {
            if ([bool]$Entry.IsTrustedTarget -and ([string]$Entry.VersionState -eq 'Older' -or [string]$Entry.VersionState -eq 'Unknown')) {
                Stop-WithFailure -ExitCode 1 -Message ("Older or unclassifiable Barracuda entry '$($Entry.DisplayName)' remains after removal; 5.3.8 or later was protected.") -Category 'App'
            }
        }

        Write-ErrorLog -Message ('Pre-5.3.8 Barracuda NAC Client removed (product code(s)={0}); 5.3.8+ remains protected. Requesting Intune hard restart.' -f $ProductCodeText) -Category 'App'
        Exit-WithHardReboot -Message ('Pre-5.3.8 Barracuda NAC Client removed. product code(s)={0}. 5.3.8+ remains protected.' -f $ProductCodeText)
    }

    $ServiceRemoved = Remove-BarracudaServiceBestEffort
    $RemainingFolders = Remove-BarracudaResidualFolders
    if ($RemainingFolders.Count -gt 0) {
        Stop-WithFailure -ExitCode 1 -Message ('Residual folders remain after pre-5.3.8 MSI removal: {0}' -f ([string]::Join('; ', $RemainingFolders))) -Category 'System'
    }

    if (Test-AnyLegacyBarracudaRemains) {
        Stop-WithFailure -ExitCode 1 -Message 'One or more pre-5.3.8 Barracuda NAC Client product codes were processed, but durable evidence of a pre-5.3.8 installation still remains.' -Category 'App'
    }

    Remove-BarracudaShortcut
    Remove-BarracudaLegacyMarkers

    $ServiceMessage = if ($ServiceRemoved) { 'service removed' } else { 'service deletion pending reboot' }
    Write-ErrorLog -Message ('Pre-5.3.8 Barracuda NAC Client removed (product code(s)={0}; {1}). Requesting Intune hard restart.' -f $ProductCodeText, $ServiceMessage) -Category 'App'
    Exit-WithHardReboot -Message ('Pre-5.3.8 Barracuda NAC Client removed. product code(s)={0}; {1}.' -f $ProductCodeText, $ServiceMessage)
}
catch {
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected error during pre-5.3.8 Barracuda NAC Client removal: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
}
