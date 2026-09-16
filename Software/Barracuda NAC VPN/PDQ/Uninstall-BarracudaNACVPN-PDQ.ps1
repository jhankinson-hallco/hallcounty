#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: uninstalls Barracuda Network Access Client (NAC VPN).

.DESCRIPTION
    PDQ Deploy uninstallation script. Intune Win32 counterpart:
    Uninstall-BarracudaNACVPN.ps1 (project root). Both scripts are kept in
    tandem per the shared AGENTS.md PDQ/Intune Tandem Deployment Standard -
    they must leave the device in an identical state.

    Order of operations (deliberate - see AI-Audit-Decisions.md):
      1. Best-effort VPN profile removal, WHILE the software is still
         present and functional (Remove-VPNProfile requires the Barracuda
         module and the cudanacsvc service). Never blocks the uninstall.
      2. Removes Barracuda Network Access Client MSI products by product
         code. The script discovers installed MSI product codes from HKLM
         uninstall registry entries that match both the expected product
         name and publisher. Unlike earlier revisions, this script does NOT
         fall back to a hardcoded product code when no trusted registry
         entry can be found - the only previously-known code
         ({9056E8A6-FE50-459B-835F-9153F2F0D70F}) belongs to the OLD 5.1.2
         MSI and would be actively wrong to use against a 5.3.8 install; a
         missing product code now fails loudly instead of guessing.
      3. Stops known Barracuda client processes and recursively removes only
         explicitly approved Network Access Client residual folders under
         Program Files, Program Files (x86), ProgramData (including the
         ngclient working directory), and every local user profile's
         AppData\Roaming\Barracuda\Network Access Client folder. Shared
         Barracuda parent folders are removed only when empty.
      4. Only after the MSI removal and residual cleanup are confirmed clean
         (or tolerated as reboot-pending) are the Public Desktop shortcut and
         every marker tier removed. This ordering matches the Intune
         counterpart's detection-safety design.
      5. At every exit point (success or failure), sweeps and stops every
         msiexec.exe process running on the machine, system-wide, verifying
         none remain. This is a deliberate final safety net against a
         leftover/zombie msiexec.exe holding the systemwide _MSIExecute
         mutex and blocking the very next PDQ install step - it is NOT
         scoped to this script's own transaction and will also stop an
         unrelated concurrent msiexec.exe (e.g. Windows Update). Best-effort
         only; never blocks or changes the uninstall's own result.

    Marker removal (2026-08-20 policy) clears ALL THREE marker tiers, not
    just markers this PDQ channel itself might have written: the current
    Intune marker
    (C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker),
    the PDQ marker (C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker,
    written by Set-BarracudaNACVPNMarker-PDQ.ps1), and the legacy marker
    (C:\IntuneAppMarkers\BarracudaNACVPN.tag) - a real uninstall must not
    leave any marker behind that could falsely satisfy a future detection
    run, regardless of which channel originally wrote it.

    The uninstall is idempotent: if the client is already absent, the script
    cleans up any orphaned residual folders, shortcut, and markers. Residual
    folder cleanup is mandatory and verified. After successful MSI exit codes,
    the script verifies that the uninstall registration is gone. Remaining
    known executables, the service, or their executable folder are tolerated
    only when Windows Installer explicitly requires a restart. The uninstall-
    registry scan must complete successfully before absence can be proven.
    Entries that share the product name but fail the publisher/MSI-registration
    trust check are deliberately left untouched and are logged as a warning
    rather than treated as blocking evidence.

    Script-authored logging is error-only, to
    <LogRoot>\APP_BarracudaNACVPN_Uninstall.txt,
    where <LogRoot> is:
      - C:\ProgramData\Microsoft\IntuneManagementExtension\Logs, if that folder
        already exists (i.e. Intune Management Extension is present on this
        endpoint) -- no Intune-specific service/registry check is performed,
        only a folder existence check; or
      - C:\BarracudaUninstallLogs, if it does not (e.g. PDQ-only endpoints
        that have never run an Intune Win32 app or script).

    MSI verbose logging is written to the process TEMP folder. Logs are copied
    into <LogRoot> (with the product code and timestamp in the file name) on
    any failed run and removed from TEMP after a fully verified success.

    Exit Codes:
        0    = Success (client removed or already absent)
        1605 = Success (MSI product is not installed and detection is absent)
        1614 = Success (MSI product uninstalled and detection is absent)
        3010 = Success (soft reboot required; only lingering known executables,
               the service, or their executable folder are tolerated)
        1641 = Success (installer initiated reboot; same tolerance as 3010)
        1    = Failure

.NOTES
    Version:        1.1.8
    Script Type:    PDQ Deploy Package (Intune counterpart: Uninstall-BarracudaNACVPN.ps1 v1.1.7)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/08/2026
    Purpose:        Complete silent PDQ uninstall of Barracuda NAC VPN, including verified residual-folder cleanup

    CHANGE LOG
    Change: 13/08/2026 - Initial PDQ uninstall release -- ver. 1.0.0
    Change: 13/08/2026 - Hardened product matching, multi-version removal,
                         persistent MSI logging, service verification, and
                         reboot-state validation -- ver. 1.0.1
    Change: 13/08/2026 - Replaced [Guid]::Parse product-code validation with an
                         explicit canonical product-code regex check;
                         post-uninstall verification now only treats trusted
                         (publisher/MSI-matched) registry entries as blocking
                         evidence, logging untouched lookalikes as a warning
                         instead of failing forever; MSI verbose logs write to
                         TEMP and are only persisted to the resolved log root on
                         failure; registry hive enumeration failures now log a
                         warning and continue with the other hive instead of
                         aborting the run; uninstall registry entries are read
                         once per phase instead of redundantly re-queried --
                         ver. 1.0.2
    Change: 13/08/2026 - Moved script-authored and on-failure MSI logging off
                         C:\IntuneAppLogs (this app has no Intune counterpart).
                         Logs now go to the IME-rooted
                         C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
                         folder when that folder already exists (a plain folder
                         existence check, not an Intune service/registry check),
                         falling back to C:\BarracudaUninstallLogs on endpoints
                         where it does not -- ver. 1.0.3
    Change: 13/08/2026 - Tandem-parity update now that an Intune counterpart
                         exists: added best-effort VPN profile removal (before
                         MSI removal, while the module/service still work) and
                         Public Desktop shortcut removal (only after MSI
                         removal is confirmed clean/tolerated, matching the
                         Intune script's detection-safety ordering). Also
                         removed the hardcoded $script:KnownProductCode
                         fallback ({9056E8A6-FE50-459B-835F-9153F2F0D70F}):
                         that code belongs to the OLD 5.1.2 MSI and would be
                         actively wrong against the current 5.3.8 install (a
                         msiexec /x call against a code that was never
                         installed on this machine returns 1605 "not
                         installed", which this script treats as SUCCESS -
                         silently leaving a real 5.3.8 install fully in place
                         while reporting a clean uninstall). The no-trusted-
                         product-code case now fails loudly instead -- ver. 1.0.4
    Change: 21/08/2026 - Synchronize counterpart metadata with Intune
                         uninstall v1.0.3; runtime uninstall behavior is
                         unchanged -- ver. 1.0.5
    Change: 21/08/2026 - Added Remove-BarracudaMarkerBestEffort: removes all
                         three marker tiers (current Intune, PDQ, and legacy)
                         at both the already-absent and post-MSI-removal
                         points, matching the existing best-effort shortcut-
                         cleanup style. Synchronized counterpart metadata
                         with Intune uninstall v1.0.4 -- ver. 1.0.6
    Change: 03/09/2026 - Added known-client-process shutdown and verified,
                         explicitly whitelisted residual-folder cleanup under
                         Program Files, Program Files (x86), and ProgramData;
                         aligned post-removal shortcut/marker cleanup with the
                         mandatory Intune behavior; corrected MSI reboot
                         suppression to ReallySuppress; and aligned the PDQ log
                         filename with the Intune counterpart -- ver. 1.1.0
    Change: 04/09/2026 - Fresh-audit fixes: MSI-uninstall failures now exit 1
                         (was propagating the raw msiexec.exe code, which
                         contradicted the documented Exit Codes table and
                         every other failure path in this script); the 64-bit
                         relaunch now captures and relays the child process's
                         STDOUT/STDERR instead of silently discarding it;
                         DisplayNamePattern now accepts a hyphenated version
                         suffix (e.g. "5.3.8-12") in addition to dot-separated
                         forms; the MSI uninstall timeout path now kills the
                         full process tree via taskkill /T /F instead of a
                         plain Kill() that could orphan msiexec child
                         processes; removed a redundant duplicate
                         Stop-BarracudaClientProcessesBestEffort call on the
                         already-absent path; and removed dead,
                         always-true whitelist re-validation code in
                         Remove-BarracudaResidualFolders (the real protection -
                          directory-type and reparse-point checks - is
                          unchanged) along with the now-unused
                          Test-IsApprovedResidualFolder function -- ver. 1.1.1
    Change: 04/09/2026 - Fail closed when an uninstall-registry scan is
                         incomplete; distinguish durable residual/configuration
                         evidence from restart-removable executable/service
                         evidence; make logging, elevation checks, service
                         polling, collection handling, and MSI process control
                         safe under Constrained Language Mode; verify taskkill
                         results and fall back to Stop-Process; clean relaunch
                         and successful MSI TEMP logs while preserving every MSI
                         log on any later failure; synchronized the Intune
                         counterpart -- ver. 1.1.2
    Change: 04/09/2026 - Fresh-audit follow-up fix: Write-ErrorLog now detects
                         a total logging failure (via -ErrorVariable on its
                         otherwise-SilentlyContinue I/O) and surfaces it with a
                         Constrained-Language-Mode-safe Write-Warning instead of
                         failing completely silently; synchronized the Intune
                         counterpart's elevation check and log line format --
                         ver. 1.1.3
    Change: 04/09/2026 - Live field fix: when installation evidence exists
                         (binaries or service) but zero uninstall registry
                         entries of any kind can be found (not the same as
                         entries existing but failing the trust check, which
                         still fails loudly as before), the script now
                         attempts orphaned-install cleanup directly - stopping
                         and deleting the service, stopping known processes,
                         and removing residual folders - then verifies the
                         evidence is actually gone before reporting success,
                         instead of only reporting the problem with no
                         cleanup. Reproduced live: repeated killed/hung
                         install attempts left files and the service
                         registered with no MSI product registration to
                         resolve a product code from -- ver. 1.1.4
    Change: 08/09/2026 - Live field fix: residual-folder cleanup never
                         covered per-user roaming data or the client's
                         ProgramData working directory, so
                         %APPDATA%\Barracuda\Network Access Client survived
                         every uninstall - confirmed live on a production
                         endpoint. Added C:\ProgramData\ngclient (Barracuda's
                         documented NAC working directory) to the
                         machine-wide residual list. Because this script runs
                         as SYSTEM or the PDQ Deploy User, $env:APPDATA
                         resolves to that run-as account's own profile, never
                         a real end user's, so every local user profile under
                         C:\Users is now enumerated directly (excluding
                         Public/Default/Default User/All Users/defaultuser0
                         and reparse points) to build each profile's
                         AppData\Roaming\Barracuda\Network Access Client
                         target path -- ver. 1.1.5
    Change: 08/09/2026 - Added a final safety net at every exit point
                         (success and failure alike): Stop-AllMsiexecProcessesBestEffort
                         sweeps every msiexec.exe process on the machine,
                         stops all of them (reusing the existing
                         Stop-ProcessTreeBestEffort kill-and-verify helper),
                         and verifies none remain. Deliberately system-wide,
                         not scoped to this script's own transaction, per
                         Jeremy's explicit direction - guards against a
                         leftover/zombie msiexec.exe blocking the next PDQ
                         install step's _MSIExecute mutex, at the accepted
                         cost of also stopping an unrelated concurrent
                         msiexec.exe if one happens to be running at that
                         moment -- ver. 1.1.6
    Change: 08/09/2026 - Live field fix: residual-folder deletion now retries
                         up to 5 times, 1 second apart, before giving up.
                         Root cause confirmed live: an uninstall run failed
                         with "Access to the path 'BarracudaNAC.dll' is
                         denied" while removing the Network Access Client
                         folder, but a Process Explorer Find Handle/DLL check
                         run immediately afterward found no process holding
                         it - the lock was transient (most likely a brief
                         AV/EDR on-access scan), not a live process or
                         service (the cudanacsvc service was already absent
                         before this run even started, so nothing this
                         script itself needed to stop was still holding it).
                         The prior code attempted the delete exactly once and
                         treated any failure as durable evidence. Retry
                         parameters and behavior were isolate-tested against
                         real timed file locks: a transient lock recovers on
                         a later attempt, a durable lock still correctly
                         exhausts all retries and fails within about 4
                         seconds -- ver. 1.1.7
    Change: 08/09/2026 - DIAGNOSTIC: temporarily disabled
                         Stop-AllMsiexecProcessesBestEffort (early return,
                         function body otherwise unchanged) to test a live
                         theory: after this sweep runs, C:\Config.Msi
                         accumulates fresh Windows Installer rollback files
                         (.rbs/.rbf) matching the uninstall run's own
                         timestamps, meaning the msiexec /x transaction that
                         removed 5.1.2 never committed cleanly - and the
                         5.1.2 registration later reappears during the next
                         install. Working theory: the sweep kills a still-
                         finishing background/elevated msiexec.exe belonging
                         to THIS SAME transaction before it can delete its
                         own rollback data, leaving an incomplete transaction
                         Windows Installer resumes later - restoring the
                         just-removed old version from the rollback data our
                         own kill left intact. See AI-Audit-Decisions.md for
                         the full evidence chain. Re-enable by removing the
                         early return once the test result is known --
                         ver. 1.1.8

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-BarracudaNACVPN-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      Success codes: 0, 1605, 1614, 3010, 1641
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName             = 'BarracudaNACVPN'
$script:AppVersion          = '1.1.8'
$script:ServiceName         = 'cudanacsvc'
$script:TimeoutSeconds      = 600
$script:SuccessCodes        = @(0, 1605, 1614, 3010, 1641)
$script:DisplayNamePattern  = '^Barracuda Network Access Client(?:\s+\d+(?:[.\-]\d+)*)?$'
$script:PublisherPattern    = 'Barracuda Networks*'

$script:ModulePath                 = 'C:\Program Files\Barracuda\Network Access Client\Modules\BarracudaNetworkAccessClient\BarracudaNetworkAccessClient.psd1'
$script:ProfileContext             = 'Machine'
$script:ServiceStartTimeoutSeconds = 30
$script:ClientProcessNames         = @('clrhlpr', 'nacadmin', 'nacfw', 'nacuserctx', 'nacvpn')
$script:ResidualDeleteRetryCount        = 5
$script:ResidualDeleteRetryDelaySeconds = 1

$script:ShortcutFileName  = 'Barracuda VPN Client.lnk'
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:DestShortcutPath  = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName

# Marker parity (2026-08-20 policy): uninstall removes ALL THREE marker
# tiers, not just whichever channel wrote them - a real uninstall must not
# leave any marker behind that could falsely satisfy a future detection run.
$script:IntuneMarkerPath = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker'
$script:PdqMarkerPath    = 'C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker'
$script:LegacyMarkerPath = 'C:\IntuneAppMarkers\BarracudaNACVPN.tag'

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
# %APPDATA%\Barracuda\Network Access Client (confirmed via official Barracuda
# documentation and third-party uninstall records, 2026-09-04 field
# investigation). This script runs as SYSTEM or the PDQ Deploy User, so
# $env:APPDATA resolves to that run-as account's own profile, never a real
# end user's - every local profile under C:\Users must be enumerated
# directly instead of relying on $env:APPDATA.
$script:ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0')
try {
    $userProfileDirs = @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction Stop |
        Where-Object { ($script:ExcludedProfileNames -notcontains $_.Name) -and ((([string]$_.Attributes) -split ', ') -notcontains 'ReparsePoint') })
}
catch {
    $userProfileDirs = @()
}

foreach ($profileDir in $userProfileDirs) {
    $script:ResidualFolderPaths += (Join-Path -Path $profileDir.FullName -ChildPath 'AppData\Roaming\Barracuda\Network Access Client')
    $script:ResidualParentPaths += (Join-Path -Path $profileDir.FullName -ChildPath 'AppData\Roaming\Barracuda')
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

# Log root resolution: prefer the IME-rooted Logs folder when it already
# exists on this endpoint (a plain folder existence check -- deliberately not
# an Intune service/registry/enrollment check), otherwise fall back to a
# dedicated local folder so PDQ-only endpoints still get a durable log.
$script:ImeLogRoot      = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:FallbackLogRoot = 'C:\BarracudaUninstallLogs'
$script:LogRoot = if (Test-Path -LiteralPath $script:ImeLogRoot -PathType Container) {
    $script:ImeLogRoot
}
else {
    $script:FallbackLogRoot
}
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Uninstall.txt')
$script:MsiLogFiles = @()

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw. -ErrorAction SilentlyContinue on the
    # I/O calls guarantees that; -ErrorVariable still captures a failure so a
    # total logging outage (e.g. an unwritable log root) is not completely
    # silent. Write-Warning is Constrained Language Mode safe (unlike the
    # [Console]::Error fallback this replaced), and on the PDQ 64-bit relaunch
    # path it is relayed back through the parent's own STDERR capture.
    param(
        [string]$Message,
        [string]$ErrorCode = 'N/A'
    )

    try {
        $writeError = $null
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue -ErrorVariable +writeError | Out-Null
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $ErrorCode, $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -ErrorVariable +writeError

        if ($writeError.Count -gt 0) {
            Write-Warning -Message ('Barracuda NAC VPN PDQ uninstall logging failed for log root ''{0}'': {1}' -f $script:LogRoot, $Message)
        }
    }
    catch {
        Write-Warning -Message ('Barracuda NAC VPN PDQ uninstall logging threw unexpectedly: {0}' -f $Message)
    }
}


function Stop-WithFailure {
    param(
        [int]$ExitCode,
        [string]$Message,
        [string]$ErrorCode = 'FAILURE'
    )

    Save-AllMsiLogsOnFailure
    Write-ErrorLog -Message $Message -ErrorCode $ErrorCode
    Stop-AllMsiexecProcessesBestEffort
    Write-Output -InputObject $Message
    exit $ExitCode
}


function Get-ExceptionMessageChain {
    param(
        [object]$Exception
    )

    $messages = @()
    $current = $Exception

    while ($null -ne $current) {
        $message = $current.Message
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
            if ($messages.Count -eq 0 -or $messages[$messages.Count - 1] -ne $message) {
                $messages += $message
            }
        }
        $current = $current.InnerException
    }

    if ($messages.Count -eq 0) {
        return 'Unknown exception (no message provided).'
    }

    $chain = $messages[0]
    for ($i = 1; $i -lt $messages.Count; $i++) {
        $chain += ' [Inner: {0}]' -f $messages[$i]
    }

    return $chain
}


function Restart-In64BitPowerShellIfNeeded {
    if (-not [Environment]::Is64BitOperatingSystem) {
        return
    }

    if ([Environment]::Is64BitProcess) {
        return
    }

    $sysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $sysNativePowerShell -PathType Leaf)) {
        Stop-WithFailure -ExitCode 1 -Message ('Unable to relaunch in 64-bit Windows PowerShell. SysNative path not found: {0}' -f $sysNativePowerShell) -ErrorCode 'PDQ_64BIT_RELAUNCH'
    }

    $arguments = '-NoProfile -ExecutionPolicy Bypass -NonInteractive -File "{0}"' -f $PSCommandPath
    $relaunchId = [guid]::NewGuid().ToString('N')
    $stdOutFile = Join-Path -Path $env:TEMP -ChildPath ('BarracudaNACVPN_Relaunch_{0}_out.txt' -f $relaunchId)
    $stdErrFile = Join-Path -Path $env:TEMP -ChildPath ('BarracudaNACVPN_Relaunch_{0}_err.txt' -f $relaunchId)

    # -RedirectStandardOutput/-RedirectStandardError capture the relaunched
    # child's output so it can be relayed back through THIS process's own
    # output stream. Without this, Start-Process launches a fully separate
    # process and only the exit code would reach whatever captured this
    # script's own console output (e.g. PDQ's step result) - every
    # Write-Output message the child produces would otherwise be silently
    # lost.
    $relaunchExitCode = 1
    try {
        $process = Start-Process -FilePath $sysNativePowerShell -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdOutFile -RedirectStandardError $stdErrFile -ErrorAction Stop
        $relaunchExitCode = [int]$process.ExitCode

        if (Test-Path -LiteralPath $stdOutFile -PathType Leaf) {
            foreach ($line in (Get-Content -LiteralPath $stdOutFile -ErrorAction SilentlyContinue)) {
                Write-Output -InputObject $line
            }
        }

        if (Test-Path -LiteralPath $stdErrFile -PathType Leaf) {
            foreach ($line in (Get-Content -LiteralPath $stdErrFile -ErrorAction SilentlyContinue)) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-ErrorLog -Message ('[64-bit relaunch STDERR] {0}' -f $line) -ErrorCode 'PDQ_64BIT_RELAUNCH_STDERR'
                }
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $stdOutFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stdErrFile -Force -ErrorAction SilentlyContinue
    }

    exit $relaunchExitCode
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


function Remove-BarracudaVpnProfileBestEffort {
    # Never throws. Must run BEFORE MSI removal - Remove-VPNProfile requires
    # the vendor module and the cudanacsvc service, both of which the MSI
    # removal step is about to take away.
    if (-not (Test-Path -LiteralPath $script:ModulePath -PathType Leaf)) {
        Write-ErrorLog -Message ('Barracuda PowerShell module not found at ''{0}''; skipping VPN profile removal (software likely already absent).' -f $script:ModulePath) -ErrorCode 'PROFILE_SKIP'
        return
    }

    try {
        Import-Module -Name $script:ModulePath -Force -ErrorAction Stop
        $null = Get-Command -Name 'Remove-VPNProfile' -ErrorAction Stop

        $service = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-ErrorLog -Message ('Service ''{0}'' not found; skipping VPN profile removal.' -f $script:ServiceName) -ErrorCode 'PROFILE_SKIP'
            return
        }

        if ($service.Status -ne 'Running') {
            Start-Service -Name $script:ServiceName -ErrorAction Stop
            $serviceIsRunning = $false
            for ($elapsedSeconds = 0; $elapsedSeconds -lt $script:ServiceStartTimeoutSeconds; $elapsedSeconds++) {
                $service = Get-Service -Name $script:ServiceName -ErrorAction Stop
                if ($service.Status -eq 'Running') {
                    $serviceIsRunning = $true
                    break
                }
                Start-Sleep -Seconds 1
            }
            if (-not $serviceIsRunning) {
                throw ('Service ''{0}'' did not reach Running within {1} seconds.' -f $script:ServiceName, $script:ServiceStartTimeoutSeconds)
            }
        }

        Remove-VPNProfile -All -Context $script:ProfileContext -ErrorAction Stop | Out-Null
    }
    catch {
        Write-ErrorLog -Message ('VPN profile removal did not complete cleanly (continuing with uninstall): {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'PROFILE_WARN'
    }
}


function Stop-BarracudaClientProcessesBestEffort {
    # Never throws. Closing the known client processes reduces the chance that
    # an otherwise successful MSI uninstall leaves locked files behind. A
    # matching process name is not sufficient by itself: the executable must
    # also run from an approved Network Access Client folder.
    foreach ($processName in $script:ClientProcessNames) {
        $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
        foreach ($process in $processes) {
            try {
                $processPath = [string]$process.Path
                $approvedProcessPath = $false
                foreach ($folderPath in $script:ExecutableFolderPaths) {
                    $folderPrefix = $folderPath.TrimEnd('\') + '\'
                    if (-not [string]::IsNullOrWhiteSpace($processPath) -and $processPath -like ($folderPrefix + '*')) {
                        $approvedProcessPath = $true
                        break
                    }
                }
                if (-not $approvedProcessPath) {
                    Write-ErrorLog -Message ('Process ''{0}'' (PID {1}) was not stopped because its executable path is outside the approved Network Access Client folders: {2}' -f $processName, $process.Id, $processPath) -ErrorCode 'PROCESS_PATH_SKIP'
                    continue
                }

                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            }
            catch {
                Write-ErrorLog -Message ('Failed to stop process ''{0}'' (PID {1}); continuing with uninstall: {2}' -f $processName, $process.Id, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'PROCESS_WARN'
            }
        }
    }
}


function Remove-BarracudaServiceBestEffort {
    # Never throws. Only meaningful for orphaned-install cleanup (see MAIN's
    # zero-registry-entries branch) - a normal msiexec /x removal already
    # takes the service with it via the MSI's own ServiceControl table and
    # never needs this. Live field case (2026-09-04): repeated killed/hung
    # install attempts left cudanacsvc registered with no MSI product
    # registration to remove it via.
    $service = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        return
    }

    try {
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message ('Failed to stop orphaned service ''{0}'': {1}' -f $script:ServiceName, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'SERVICE_STOP_WARN'
    }

    try {
        $scPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\sc.exe'
        if (Test-Path -LiteralPath $scPath -PathType Leaf) {
            & $scPath delete $script:ServiceName | Out-Null
        }
    }
    catch {
        Write-ErrorLog -Message ('Failed to delete orphaned service ''{0}'': {1}' -f $script:ServiceName, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'SERVICE_DELETE_WARN'
    }
}


function Remove-EmptyBarracudaParentFoldersBestEffort {
    foreach ($parentPath in @($script:ResidualParentPaths | Select-Object -Unique)) {
        try {
            if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
                continue
            }

            $parentItem = Get-Item -LiteralPath $parentPath -Force -ErrorAction Stop
            if ((([string]$parentItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                Write-ErrorLog -Message ('Refusing to remove empty vendor parent because it is a reparse point: {0}' -f $parentPath) -ErrorCode 'PARENT_REPARSE_SKIP'
                continue
            }

            $children = @(Get-ChildItem -LiteralPath $parentPath -Force -ErrorAction Stop)
            if ($children.Count -eq 0) {
                Remove-Item -LiteralPath $parentPath -Force -ErrorAction Stop
            }
        }
        catch {
            Write-ErrorLog -Message ('Unable to remove empty Barracuda parent folder ''{0}'': {1}' -f $parentPath, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'PARENT_CLEANUP_WARN'
        }
    }
}


function Remove-BarracudaResidualFolders {
    # Emits one path for each residual folder that remains. Callers must wrap
    # the result in @() before checking Count. Recursive deletion is allowed
    # only for exact paths in $script:ResidualFolderPaths and never follows a
    # reparse-point root.
    $remainingFolders = @()

    foreach ($folderPath in @($script:ResidualFolderPaths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $folderPath)) {
            continue
        }

        try {
            # $folderPath is drawn directly from $script:ResidualFolderPaths
            # (the loop above iterates that exact list), so no separate
            # whitelist-membership re-check is needed here - only the
            # directory-type and reparse-point safety checks below guard
            # against something unexpected actually sitting at that path.
            $folderItem = Get-Item -LiteralPath $folderPath -Force -ErrorAction Stop
            if (-not $folderItem.PSIsContainer) {
                throw ('Approved cleanup path exists but is not a directory: {0}' -f $folderPath)
            }
            if ((([string]$folderItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                throw ('Refusing recursive deletion because the approved cleanup path is a reparse point: {0}' -f $folderPath)
            }

            # A file inside the tree can be transiently locked (e.g. a brief
            # AV/EDR on-access scan) at the exact moment of deletion even
            # though nothing owns it a moment before or after - confirmed
            # live, 2026-09-08 (Remove-Item failed with "Access to the path
            # 'BarracudaNAC.dll' is denied", but a Process Explorer Find
            # Handle/DLL check immediately afterward found no owning
            # process). Retry a few times with a short pause before treating
            # it as durable evidence.
            for ($deleteAttempt = 1; $deleteAttempt -le $script:ResidualDeleteRetryCount; $deleteAttempt++) {
                try {
                    Remove-Item -LiteralPath $folderItem.FullName -Recurse -Force -ErrorAction Stop
                    break
                }
                catch {
                    if ($deleteAttempt -ge $script:ResidualDeleteRetryCount) {
                        throw
                    }
                    Start-Sleep -Seconds $script:ResidualDeleteRetryDelaySeconds
                }
            }
        }
        catch {
            Write-ErrorLog -Message ('Residual-folder cleanup failed for ''{0}'': {1}' -f $folderPath, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'RESIDUAL_CLEANUP'
        }

        if (Test-Path -LiteralPath $folderPath) {
            $remainingFolders += $folderPath
        }
    }

    Remove-EmptyBarracudaParentFoldersBestEffort

    foreach ($remainingFolder in $remainingFolders) {
        Write-Output -InputObject $remainingFolder
    }
}


function Remove-BarracudaShortcut {
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:DestShortcutPath -Force -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        throw ('Desktop shortcut still exists after removal: {0}' -f $script:DestShortcutPath)
    }
}


function Remove-BarracudaMarker {
    # Removes every marker tier for this app - current Intune, PDQ, and legacy.
    foreach ($markerPath in @($script:IntuneMarkerPath, $script:PdqMarkerPath, $script:LegacyMarkerPath)) {
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
            Remove-Item -LiteralPath $markerPath -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
            throw ('Marker file still exists after removal: {0}' -f $markerPath)
        }
    }
}


function Test-DisplayNameMatch {
    param(
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return $false
    }

    return ($DisplayName -match $script:DisplayNamePattern)
}


function Test-PublisherMatch {
    param(
        [string]$Publisher
    )

    if ([string]::IsNullOrWhiteSpace($Publisher)) {
        return $false
    }

    return ($Publisher -like $script:PublisherPattern)
}


function ConvertTo-MsiProductCode {
    param(
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return ''
    }

    # MSI uninstall-key names and extracted UninstallString GUIDs must already
    # use canonical {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} form. Regex keeps
    # that trust boundary explicit without constructing another object.
    if ($Candidate -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') {
        return $Candidate.ToUpperInvariant()
    }

    return ''
}


function Get-ProductCodeFromUninstallEntry {
    param(
        [string]$KeyName,
        [string]$UninstallString
    )

    $productCode = ConvertTo-MsiProductCode -Candidate $KeyName
    if (-not [string]::IsNullOrWhiteSpace($productCode)) {
        return $productCode
    }

    if (-not [string]::IsNullOrWhiteSpace($UninstallString) -and
        $UninstallString -match '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') {
        return (ConvertTo-MsiProductCode -Candidate ([string]$Matches[0]))
    }

    return ''
}


function Get-BarracudaUninstallEntries {
    $entries = @()
    $scanErrors = @()

    foreach ($registryPath in $script:RegistryPaths) {
        try {
            if (-not (Test-Path -LiteralPath $registryPath)) {
                continue
            }
            $subKeys = @(Get-ChildItem -LiteralPath $registryPath -ErrorAction Stop)
        }
        catch {
            $scanError = 'Unable to enumerate uninstall registry path ''{0}'': {1}' -f $registryPath, (Get-ExceptionMessageChain -Exception $_.Exception)
            $scanErrors += $scanError
            Write-ErrorLog -Message $scanError -ErrorCode 'REGISTRY_ENUM_FAILED'
            continue
        }

        foreach ($subKey in $subKeys) {
            try {
                $properties = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
                $displayNameProperty = $properties.PSObject.Properties['DisplayName']

                if ($null -eq $displayNameProperty) {
                    continue
                }

                $displayName = [string]$displayNameProperty.Value
                if (-not (Test-DisplayNameMatch -DisplayName $displayName)) {
                    continue
                }

                $publisher = ''
                $publisherProperty = $properties.PSObject.Properties['Publisher']
                if ($null -ne $publisherProperty) {
                    $publisher = [string]$publisherProperty.Value
                }

                $windowsInstallerProperty = $properties.PSObject.Properties['WindowsInstaller']
                $isWindowsInstaller = $false
                if ($null -ne $windowsInstallerProperty -and [string]$windowsInstallerProperty.Value -eq '1') {
                    $isWindowsInstaller = $true
                }

                $uninstallString = ''
                $uninstallStringProperty = $properties.PSObject.Properties['UninstallString']
                if ($null -ne $uninstallStringProperty) {
                    $uninstallString = [string]$uninstallStringProperty.Value
                }

                $isTrustedTarget = ((Test-PublisherMatch -Publisher $publisher) -and $isWindowsInstaller)
                $productCode = ''
                if ($isTrustedTarget) {
                    $productCode = Get-ProductCodeFromUninstallEntry -KeyName ([string]$subKey.PSChildName) -UninstallString $uninstallString
                }

                $entries += New-Object -TypeName psobject -Property @{
                    RegistryPath     = [string]$subKey.PSPath
                    KeyName          = [string]$subKey.PSChildName
                    DisplayName      = $displayName
                    Publisher        = $publisher
                    WindowsInstaller = $isWindowsInstaller
                    IsTrustedTarget  = $isTrustedTarget
                    UninstallString  = $uninstallString
                    ProductCode      = $productCode
                }
            }
            catch {
                $scanError = 'Failed to inspect uninstall registry entry ''{0}'': {1}' -f $subKey.PSPath, (Get-ExceptionMessageChain -Exception $_.Exception)
                $scanErrors += $scanError
                Write-ErrorLog -Message $scanError -ErrorCode 'REGISTRY_READ_FAILED'
            }
        }
    }

    return (New-Object -TypeName psobject -Property @{
        Entries    = @($entries)
        Errors     = @($scanErrors)
        IsComplete = ($scanErrors.Count -eq 0)
    })
}


function Get-BarracudaDetectedPath {
    foreach ($path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return ''
}


function Test-BarracudaInstalled {
    param(
        [object[]]$Entries
    )

    if (-not [string]::IsNullOrWhiteSpace((Get-BarracudaDetectedPath))) {
        return $true
    }

    if (@(Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue).Count -gt 0) {
        return $true
    }

    return (@($Entries).Count -gt 0)
}


function Get-BarracudaProductCodes {
    param(
        [object[]]$Entries
    )

    $productCodes = @()

    foreach ($entry in @($Entries)) {
        if (-not [bool]$entry.IsTrustedTarget) {
            continue
        }

        $productCode = [string]$entry.ProductCode
        if ([string]::IsNullOrWhiteSpace($productCode)) {
            continue
        }

        if ($productCodes -notcontains $productCode) {
            $productCodes += $productCode
        }
    }

    return ,$productCodes
}


function Stop-ProcessTreeBestEffort {
    param(
        [int]$ProcessId
    )

    $taskkillSucceeded = $false
    $taskkillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'

    if (Test-Path -LiteralPath $taskkillPath -PathType Leaf) {
        try {
            $taskkillArguments = '/PID {0} /T /F' -f $ProcessId
            $taskkillProcess = Start-Process -FilePath $taskkillPath -ArgumentList $taskkillArguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            $taskkillSucceeded = ([int]$taskkillProcess.ExitCode -eq 0)
        }
        catch {
            $taskkillSucceeded = $false
        }
    }

    if (-not $taskkillSucceeded) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Milliseconds 250
    return (@(Get-Process -Id $ProcessId -ErrorAction SilentlyContinue).Count -eq 0)
}


function Stop-AllMsiexecProcessesBestEffort {
    # TEMPORARILY DISABLED (2026-09-08) for live diagnostic testing - do not
    # remove this early return without reading AI-Audit-Decisions.md first.
    # Live evidence: after this sweep runs, C:\Config.Msi accumulates fresh
    # Windows Installer rollback files (.rbs/.rbf) matching the uninstall
    # run's own timestamps - meaning the msiexec /x transaction that removed
    # 5.1.2 never committed cleanly. Working theory: this sweep is killing a
    # still-finishing background/elevated msiexec.exe belonging to THIS
    # SAME transaction (not an unrelated one) before it deletes its own
    # rollback data, leaving an incomplete transaction that Windows
    # Installer later resumes during the next install - restoring the
    # just-removed old version. Testing whether disabling this sweep
    # prevents both the leftover C:\Config.Msi data and the 5.1.2 phantom
    # re-install. Re-enable by removing the "return" line below once the
    # test result is known either way.
    return

    # Final safety net, called at every exit point in MAIN (success and
    # failure alike): sweep every msiexec.exe process on the machine and
    # verify none remain. Deliberately NOT scoped to this script's own
    # transaction - by design it will also stop an unrelated concurrent
    # msiexec.exe (e.g. Windows Update or another package's install), an
    # accepted trade-off made to guarantee no leftover/zombie msiexec.exe can
    # hold the systemwide _MSIExecute mutex and block the very next PDQ
    # install step (see AI-Audit-Decisions.md, 2026-09-08). Never throws and
    # never blocks or changes the uninstall's own result.
    try {
        $remainingProcesses = @(Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue)
        if ($remainingProcesses.Count -eq 0) {
            return
        }

        Write-ErrorLog -Message ('Final cleanup: {0} msiexec.exe process(es) still running; stopping all of them.' -f $remainingProcesses.Count) -ErrorCode 'MSIEXEC_SWEEP'

        foreach ($msiexecProcess in $remainingProcesses) {
            try {
                $stopped = Stop-ProcessTreeBestEffort -ProcessId $msiexecProcess.Id
                if (-not $stopped) {
                    Write-ErrorLog -Message ('Final cleanup: msiexec.exe (PID {0}) could not be confirmed stopped.' -f $msiexecProcess.Id) -ErrorCode 'MSIEXEC_SWEEP_WARN'
                }
            }
            catch {
                Write-ErrorLog -Message ('Final cleanup: stopping msiexec.exe (PID {0}) threw: {1}' -f $msiexecProcess.Id, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MSIEXEC_SWEEP_WARN'
            }
        }

        $stillRunning = @(Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue)
        if ($stillRunning.Count -gt 0) {
            $stillRunningIds = [string]::Join(', ', @($stillRunning | ForEach-Object -Process { [string]$_.Id }))
            Write-ErrorLog -Message ('Final cleanup: {0} msiexec.exe process(es) still running after the sweep (PID(s): {1}).' -f $stillRunning.Count, $stillRunningIds) -ErrorCode 'MSIEXEC_SWEEP_INCOMPLETE'
        }
        else {
            Write-ErrorLog -Message 'Final cleanup: all msiexec.exe processes confirmed stopped.' -ErrorCode 'MSIEXEC_SWEEP_OK'
        }
    }
    catch {
        Write-ErrorLog -Message ('Final msiexec.exe sweep threw unexpectedly: {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MSIEXEC_SWEEP_WARN'
    }
}


function Invoke-MsiUninstall {
    param(
        [string]$ProductCode
    )

    $productCodeForFileName = $ProductCode -replace '[^0-9A-Fa-f]', ''
    $logTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $msiLogFileName = '{0}_{1}_{2}_MSI_Uninstall.log' -f $script:AppName, $productCodeForFileName, $logTimestamp
    $msiLogFile = Join-Path -Path $env:TEMP -ChildPath $msiLogFileName
    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $arguments = '/x {0} /qn /norestart REBOOT=ReallySuppress /L*v "{1}"' -f $ProductCode, $msiLogFile
    $script:MsiLogFiles += $msiLogFile

    $process = Start-Process -FilePath $msiexecPath -ArgumentList $arguments -PassThru -WindowStyle Hidden -ErrorAction Stop
    $waitError = $null
    try {
        Wait-Process -InputObject $process -Timeout $script:TimeoutSeconds -ErrorAction Stop
    }
    catch {
        $waitError = $_
    }

    if ($null -ne $waitError) {
        $processStillRunning = (@(Get-Process -Id $process.Id -ErrorAction SilentlyContinue).Count -gt 0)
        if ($processStillRunning) {
            $terminated = Stop-ProcessTreeBestEffort -ProcessId $process.Id
            if ($terminated) {
                throw ('msiexec.exe /x timed out after {0} seconds and its process tree was terminated.' -f $script:TimeoutSeconds)
            }
            throw ('msiexec.exe /x timed out after {0} seconds, but its process could not be confirmed stopped.' -f $script:TimeoutSeconds)
        }
    }

    return (New-Object -TypeName psobject -Property @{
        ExitCode    = [int]$process.ExitCode
        LogFile     = $msiLogFile
        ProductCode = $ProductCode
    })
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
        $destLogFile = Join-Path -Path $script:LogRoot -ChildPath (Split-Path -Path $SourceLogFile -Leaf)
        Copy-Item -LiteralPath $SourceLogFile -Destination $destLogFile -Force -ErrorAction Stop
        return $destLogFile
    }
    catch {
        Write-ErrorLog -Message ('Failed to persist MSI log ''{0}'' to ''{1}'': {2}' -f $SourceLogFile, $script:LogRoot, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MSI_LOG_COPY_WARN'
        return ''
    }
}


function Save-AllMsiLogsOnFailure {
    foreach ($msiLogFile in @($script:MsiLogFiles | Select-Object -Unique)) {
        $null = Save-MsiLogOnFailure -SourceLogFile $msiLogFile
    }
}


function Remove-TemporaryMsiLogsBestEffort {
    foreach ($msiLogFile in @($script:MsiLogFiles | Select-Object -Unique)) {
        Remove-Item -LiteralPath $msiLogFile -Force -ErrorAction SilentlyContinue
    }
}


function Get-BarracudaRemainingEvidence {
    $durableEvidence = @()
    $rebootPendingEvidence = @()

    # Must be a fresh read: this runs after the uninstall attempt, so a
    # pre-uninstall entry snapshot would be stale and unsafe to reuse here.
    $registryScan = Get-BarracudaUninstallEntries
    if (-not [bool]$registryScan.IsComplete) {
        foreach ($scanError in @($registryScan.Errors)) {
            $durableEvidence += ('uninstall registry scan incomplete: {0}' -f $scanError)
        }
    }

    foreach ($entry in @($registryScan.Entries)) {
        if ([bool]$entry.IsTrustedTarget) {
            $durableEvidence += ('uninstall registry entry still present: {0} ({1})' -f $entry.DisplayName, $entry.RegistryPath)
        }
        else {
            # Same product-name family but failed the publisher/MSI trust
            # check: this script never attempted to remove it, so its mere
            # presence must not block success -- only report it.
            Write-ErrorLog -Message ('Unmanaged Barracuda-named uninstall registry entry left in place (failed publisher/MSI identity check, not removed by this script): {0} ({1})' -f $entry.DisplayName, $entry.RegistryPath) -ErrorCode 'UNTRUSTED_ENTRY_IGNORED'
        }
    }

    foreach ($path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $rebootPendingEvidence += ('executable still present: {0}' -f $path)
        }
    }

    $services = @(Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)
    $servicePresent = ($services.Count -gt 0)

    foreach ($path in @($script:ResidualFolderPaths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        try {
            $residualItem = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if (-not $residualItem.PSIsContainer) {
                $durableEvidence += ('non-directory exists at approved residual-folder path: {0}' -f $path)
                continue
            }
            if ((([string]$residualItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                $durableEvidence += ('reparse point exists at approved residual-folder path: {0}' -f $path)
                continue
            }

            $isExecutableFolder = $false
            foreach ($executableFolderPath in $script:ExecutableFolderPaths) {
                if ($path.TrimEnd('\') -ieq $executableFolderPath.TrimEnd('\')) {
                    $isExecutableFolder = $true
                    break
                }
            }

            $knownExecutablePresent = $false
            $folderPrefix = $path.TrimEnd('\') + '\'
            foreach ($detectionPath in $script:DetectionPaths) {
                if ($detectionPath -like ($folderPrefix + '*') -and (Test-Path -LiteralPath $detectionPath -PathType Leaf)) {
                    $knownExecutablePresent = $true
                    break
                }
            }

            if ($isExecutableFolder -and ($knownExecutablePresent -or $servicePresent)) {
                $rebootPendingEvidence += ('executable folder still present pending restart: {0}' -f $path)
            }
            else {
                $durableEvidence += ('residual folder still present after cleanup: {0}' -f $path)
            }
        }
        catch {
            $durableEvidence += ('unable to verify residual path ''{0}'': {1}' -f $path, (Get-ExceptionMessageChain -Exception $_.Exception))
        }
    }

    foreach ($service in $services) {
        $rebootPendingEvidence += ('service still present: {0} (status: {1})' -f $service.Name, $service.Status)
    }

    return (New-Object -TypeName psobject -Property @{
        Durable       = @($durableEvidence)
        RebootPending = @($rebootPendingEvidence)
    })
}


function Get-OverallSuccessExitCode {
    param(
        [int[]]$ExitCodes
    )

    if ($ExitCodes -contains 1641) {
        return 1641
    }

    if ($ExitCodes -contains 3010) {
        return 3010
    }

    if ($ExitCodes -contains 0) {
        return 0
    }

    if ($ExitCodes -contains 1614) {
        return 1614
    }

    return 1605
}

# =============================================================================
# MAIN
# =============================================================================

try {
    Restart-In64BitPowerShellIfNeeded

    if (-not (Test-IsAdministrator)) {
        Stop-WithFailure -ExitCode 1 -Message 'This uninstaller requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -ErrorCode 'PERMISSIONS'
    }

    # Best-effort VPN profile removal WHILE the software still works. Never
    # blocks the uninstall - see function comment.
    Remove-BarracudaVpnProfileBestEffort
    Stop-BarracudaClientProcessesBestEffort

    $initialRegistryScan = Get-BarracudaUninstallEntries
    if (-not [bool]$initialRegistryScan.IsComplete) {
        $registryErrors = [string]::Join('; ', @($initialRegistryScan.Errors))
        Stop-WithFailure -ExitCode 1 -Message ('Unable to prove the Barracuda uninstall-registry state because the scan was incomplete: {0}' -f $registryErrors) -ErrorCode 'REGISTRY_SCAN_INCOMPLETE'
    }
    $uninstallEntries = @($initialRegistryScan.Entries)

    if (-not (Test-BarracudaInstalled -Entries $uninstallEntries)) {
        # Idempotent: already absent. Residual folders are explicitly requested
        # cleanup state and therefore remain mandatory even on this path.
        # (Client processes were already stopped once above, before the
        # installed/absent determination.)
        $remainingFolders = @(Remove-BarracudaResidualFolders)
        if ($remainingFolders.Count -gt 0) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client is not registered, but residual folders could not be removed: {0}' -f ([string]::Join('; ', $remainingFolders))) -ErrorCode 'RESIDUAL_CLEANUP'
        }

        # Shortcut/marker cleanup remains best-effort on the already-absent
        # path so an irrelevant orphan cannot cause an endless retry.
        try { Remove-BarracudaShortcut }
        catch { Write-ErrorLog -Message ('Best-effort shortcut cleanup failed on already-absent path: {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'SHORTCUT_WARN' }
        try { Remove-BarracudaMarker }
        catch { Write-ErrorLog -Message ('Best-effort marker cleanup failed on already-absent path: {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MARKER_WARN' }
        Write-Output -InputObject 'Barracuda Network Access Client is already absent.'
        Stop-AllMsiexecProcessesBestEffort
        exit 0
    }

    # Direct assignment is required because the helper comma-protects its
    # array result so the zero/one/many shapes remain stable in PS 5.1.
    $productCodes = Get-BarracudaProductCodes -Entries $uninstallEntries

    if ($uninstallEntries.Count -gt 0 -and $productCodes.Count -eq 0) {
        $entryPaths = [string]::Join('; ', @($uninstallEntries | ForEach-Object -Process { [string]$_.RegistryPath }))
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client registry entries were found, but none passed the publisher/MSI-registration trust check, so no product code could be resolved: {0}' -f $entryPaths) -ErrorCode 'PRODUCT_CODE'
    }

    if ($productCodes.Count -eq 0) {
        # Deliberately NOT falling back to a hardcoded product code here.
        # The only previously-known code belongs to the OLD 5.1.2 MSI and
        # would be actively wrong against a 5.3.8 install - see .DESCRIPTION.
        # Reaching this point means $uninstallEntries.Count is exactly 0 (the
        # uninstallEntries.Count -gt 0 branch above already handled the
        # "untrusted entries exist" case and exits before here) - i.e. there
        # is no registry entry of ANY kind, trusted or not. That removes the
        # ambiguity a real-but-untrusted entry would carry: this is not "an
        # identity we refuse to touch," it is "no registration exists at
        # all," most plausibly orphaned debris from an interrupted install
        # (live field case, 2026-09-04: repeated killed/hung install attempts
        # left files and the service registered without ever reaching
        # RegisterProduct). Attempt orphaned-install cleanup directly rather
        # than only reporting the problem.
        Write-ErrorLog -Message 'Barracuda Network Access Client installation evidence was found (binaries or service present), but no uninstall registry entry of any kind exists. Attempting orphaned-install cleanup.' -ErrorCode 'ORPHANED_INSTALL'
        Remove-BarracudaServiceBestEffort
        Stop-BarracudaClientProcessesBestEffort
        $remainingFolders = @(Remove-BarracudaResidualFolders)

        $orphanEvidence = @()
        $orphanDetectedPath = Get-BarracudaDetectedPath
        if (-not [string]::IsNullOrWhiteSpace($orphanDetectedPath)) {
            $orphanEvidence += ('executable still present: {0}' -f $orphanDetectedPath)
        }
        if (@(Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue).Count -gt 0) {
            $orphanEvidence += ('service still present: {0}' -f $script:ServiceName)
        }
        if ($remainingFolders.Count -gt 0) {
            $orphanEvidence += @($remainingFolders | ForEach-Object -Process { 'residual folder still present: {0}' -f $_ })
        }

        if ($orphanEvidence.Count -gt 0) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client installation evidence was found (binaries or service present), no uninstall registry entry exists, and orphaned-install cleanup could not fully remove the remaining evidence: {0}' -f ([string]::Join('; ', $orphanEvidence))) -ErrorCode 'ORPHANED_INSTALL_INCOMPLETE'
        }

        try { Remove-BarracudaShortcut }
        catch { Write-ErrorLog -Message ('Shortcut cleanup failed after orphaned-install cleanup: {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'SHORTCUT_WARN' }
        try { Remove-BarracudaMarker }
        catch { Write-ErrorLog -Message ('Marker cleanup failed after orphaned-install cleanup: {0}' -f (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MARKER_WARN' }

        Write-Output -InputObject 'Barracuda Network Access Client had orphaned install evidence with no uninstall registry entry; cleanup completed and verified.'
        Stop-AllMsiexecProcessesBestEffort
        exit 0
    }

    $msiResults = @()

    foreach ($productCode in $productCodes) {
        $msiResult = Invoke-MsiUninstall -ProductCode $productCode

        if ($script:SuccessCodes -notcontains $msiResult.ExitCode) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall failed for product code {0}. msiexec.exe returned {1}. Check TEMP log {2}; a durable copy is attempted under {3}.' -f $productCode, $msiResult.ExitCode, $msiResult.LogFile, $script:LogRoot) -ErrorCode 'MSI_UNINSTALL'
        }

        $msiResults += $msiResult
    }

    Start-Sleep -Seconds 5

    # A successful MSI transaction can leave configuration or locked client
    # files behind. Stop the user-facing processes again, then perform the
    # requested explicit residual-folder cleanup before final verification.
    Stop-BarracudaClientProcessesBestEffort
    $null = @(Remove-BarracudaResidualFolders)

    $exitCodes = @($msiResults | ForEach-Object -Process { [int]$_.ExitCode })
    $overallExitCode = Get-OverallSuccessExitCode -ExitCodes $exitCodes
    $remainingEvidence = Get-BarracudaRemainingEvidence
    $durableEvidence = @($remainingEvidence.Durable)
    $rebootPendingEvidence = @($remainingEvidence.RebootPending)

    if ($durableEvidence.Count -gt 0) {
        $durableEvidenceText = [string]::Join('; ', $durableEvidence)
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall returned {0}, but durable installation evidence still exists: {1}' -f $overallExitCode, $durableEvidenceText) -ErrorCode 'DETECTION_STILL_PRESENT'
    }

    if ($rebootPendingEvidence.Count -gt 0 -and $overallExitCode -notin @(3010, 1641)) {
        $rebootPendingEvidenceText = [string]::Join('; ', $rebootPendingEvidence)
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall returned {0}, but executable, service, or residual-folder evidence still exists: {1}' -f $overallExitCode, $rebootPendingEvidenceText) -ErrorCode 'DETECTION_STILL_PRESENT'
    }

    # Only now - MSI removal and residual cleanup confirmed clean or tolerated
    # as reboot-pending - remove detection-affecting artifacts. These removals
    # are mandatory after a real uninstall, matching the Intune counterpart.
    Remove-BarracudaShortcut
    Remove-BarracudaMarker

    if ($rebootPendingEvidence.Count -gt 0) {
        $rebootPendingEvidenceText = [string]::Join('; ', $rebootPendingEvidence)
        Write-ErrorLog -Message ('Barracuda Network Access Client uninstall returned reboot-required exit code {0}; remaining in-use evidence should clear at restart. {1}' -f $overallExitCode, $rebootPendingEvidenceText) -ErrorCode 'DETECTION_PENDING_REBOOT'
    }

    Remove-TemporaryMsiLogsBestEffort
    Stop-AllMsiexecProcessesBestEffort
    $productCodeText = [string]::Join(', ', $productCodes)
    Write-Output -InputObject ('Barracuda Network Access Client uninstall completed by PDQ. ExitCode={0}; product code(s)={1}.' -f $overallExitCode, $productCodeText)
    exit $overallExitCode
}
catch {
    $message = Get-ExceptionMessageChain -Exception $_.Exception
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected Barracuda Network Access Client uninstall error: {0}' -f $message) -ErrorCode 'UNEXPECTED'
}
