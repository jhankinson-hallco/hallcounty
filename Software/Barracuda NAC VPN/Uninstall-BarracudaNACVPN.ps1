#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstalls Barracuda Network Access Client (NAC VPN): removes the Hall
    County VPN profile, the Public Desktop shortcut, and the MSI product.

.DESCRIPTION
    Intune Win32 App uninstallation script. Counterpart to
    Install-BarracudaNACVPN.ps1.

    Order of operations (deliberate - see AI-Audit-Decisions.md):
      1. Best-effort VPN profile removal, WHILE the software is still
         present and functional (Remove-VPNProfile requires the Barracuda
         module and the cudanacsvc service). Never blocks the uninstall.
      2. MSI product removal, by product code resolved from the uninstall
         registry (display name + publisher + WindowsInstaller=1 match).
         Unlike the PDQ counterpart's earlier revisions, this script does
         NOT fall back to a hardcoded product code when no trusted registry
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
         every marker tier for this app removed. This ordering prevents
         Detect-BarracudaNACVPN.ps1 from ever reporting "not installed"
         while a failed uninstall has left the real software still present.
      5. At every exit point (success or failure), sweeps and stops every
         msiexec.exe process running on the machine, system-wide, verifying
         none remain. This is a deliberate final safety net against a
         leftover/zombie msiexec.exe holding the systemwide _MSIExecute
         mutex and blocking the very next install step - it is NOT scoped to
         this script's own transaction and will also stop an unrelated
         concurrent msiexec.exe (e.g. Windows Update). Best-effort only;
         never blocks or changes the uninstall's own result.

    Idempotent: if the client is already absent, the script cleans up any
    orphaned residual folders, shortcut, and markers. Residual-folder cleanup
    is mandatory and verified. The uninstall-registry scan must complete
    successfully before absence can be proven.

    Marker removal (2026-08-20 policy) clears ALL THREE marker tiers, not
    just this script's own Intune marker: the current Intune marker
    (C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker),
    the PDQ marker (C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker),
    and the legacy marker (C:\IntuneAppMarkers\BarracudaNACVPN.tag) - a real
    uninstall must not leave any marker behind that could falsely satisfy a
    future detection run, regardless of which channel originally wrote it.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_BarracudaNACVPN_Uninstall.txt
    (IME-rooted per the current shop standard - C:\IntuneAppLogs is the
    legacy fallback path). Verbose MSI logs are written to TEMP, copied into
    the log root on any failed run, and removed from TEMP after a fully
    verified success.

    Exit Codes:
        0    = Success (client removed or already absent)
        1605 = Success (MSI product is not installed and detection is absent)
        1614 = Success (MSI product uninstalled and detection is absent)
        3010 = Success (soft reboot required; only lingering known executables,
               the service, or their executable folder are tolerated)
        1641 = Success (installer initiated reboot; same tolerance as 3010)
        1    = Failure

.NOTES
    Version:        1.1.7
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/08/2026
    Purpose:        Complete uninstall of Barracuda NAC VPN, including verified residual-folder cleanup

    CHANGE LOG
    Change: 13/08/2026 - Initial release -- ver. 1.0.0
    Change: 17/08/2026 - Fix comma-return caller nesting, enforce shortcut/marker cleanup, and use consistent reboot suppression -- ver. 1.0.1
    Change: 17/08/2026 - Shortcut/marker cleanup on the already-absent
                         idempotent path is best-effort again (log a warning,
                         never fail the run); mandatory verified cleanup is
                         retained for the path where this run just performed
                         a real MSI removal, where it protects against
                         reporting false success -- ver. 1.0.2
    Change: 21/08/2026 - Synchronize paired-install metadata with the VPN-only
                         Install-BarracudaNACVPN.ps1 v1.0.2 revision; runtime
                         uninstall behavior is unchanged -- ver. 1.0.3
    Change: 21/08/2026 - Moved logging and the Intune marker to the current
                         IME-rooted paths (was C:\IntuneAppLogs /
                         C:\IntuneAppMarkers); Remove-BarracudaMarker now
                         removes ALL THREE marker tiers (current Intune, PDQ,
                         and legacy), not just the Intune one, so a real
                         uninstall never leaves a marker behind that could
                         falsely satisfy a future detection run -- ver. 1.0.4
    Change: 03/09/2026 - Added known-client-process shutdown and verified,
                         explicitly whitelisted residual-folder cleanup under
                         Program Files, Program Files (x86), and ProgramData;
                         synchronized the PDQ counterpart -- ver. 1.1.0
    Change: 04/09/2026 - Fail closed when an uninstall-registry scan is
                         incomplete; distinguish durable residual/configuration
                         evidence from restart-removable executable/service
                         evidence; verify MSI timeout termination; and clean
                         successful MSI TEMP logs while preserving every MSI
                         log on any later failure; synchronized PDQ uninstall
                         v1.1.2 -- ver. 1.1.1
    Change: 04/09/2026 - Fresh-audit follow-up fix: Test-IsAdministrator now
                         uses the same Constrained-Language-Mode-safe
                         fltmc.exe check as the PDQ counterpart instead of the
                         confirmed-CLM-blocked WindowsIdentity/WindowsPrincipal
                         pattern (tandem CLM-risk consistency); Write-ErrorLog
                         now detects a total logging failure via -ErrorVariable
                         and surfaces it with Write-Warning instead of failing
                         completely silently; log lines now carry an [Intune]
                         channel tag matching the PDQ counterpart's [PDQ] tag,
                         since both scripts share one physical log file --
                         ver. 1.1.2
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
                         resolve a product code from; synchronized PDQ
                         uninstall v1.1.4 -- ver. 1.1.3
    Change: 08/09/2026 - Live field fix: residual-folder cleanup never
                         covered per-user roaming data or the client's
                         ProgramData working directory, so
                         %APPDATA%\Barracuda\Network Access Client survived
                         every uninstall - confirmed live on a production
                         endpoint. Added C:\ProgramData\ngclient (Barracuda's
                         documented NAC working directory) to the
                         machine-wide residual list. Because this script runs
                         as SYSTEM (the default Intune Win32 install
                         behavior), $env:APPDATA resolves to the SYSTEM
                         profile, never a real end user's, so every local
                         user profile under C:\Users is now enumerated
                         directly (excluding Public/Default/Default
                         User/All Users/defaultuser0 and reparse points) to
                         build each profile's
                         AppData\Roaming\Barracuda\Network Access Client
                         target path; synchronized PDQ uninstall v1.1.5 --
                         ver. 1.1.4
    Change: 08/09/2026 - Added a final safety net at every exit point
                         (success and failure alike): Stop-AllMsiexecProcessesBestEffort
                         sweeps every msiexec.exe process on the machine,
                         stops all of them (reusing the existing
                         Stop-ProcessTreeBestEffort kill-and-verify helper),
                         and verifies none remain. Deliberately system-wide,
                         not scoped to this script's own transaction, per
                         Jeremy's explicit direction - guards against a
                         leftover/zombie msiexec.exe blocking the next
                         install step's _MSIExecute mutex, at the accepted
                         cost of also stopping an unrelated concurrent
                         msiexec.exe if one happens to be running at that
                         moment; synchronized PDQ uninstall v1.1.6 -- ver. 1.1.5
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
                         seconds; synchronized PDQ uninstall v1.1.7 --
                         ver. 1.1.6
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
                         early return once the test result is known;
                         synchronized PDQ uninstall v1.1.8 -- ver. 1.1.7

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-BarracudaNACVPN.ps1
      Install behavior: System
      Additional return codes: 1605 = Success, 1614 = Success, 3010 = Success (reboot), 1641 = Success (reboot)

    PDQ COUNTERPART
      PDQ\Uninstall-BarracudaNACVPN-PDQ.ps1 v1.1.8 (kept updated in tandem - see that
      script's own CHANGE LOG for the matching profile/shortcut removal added
      alongside this script).

    Paired install script: Install-BarracudaNACVPN.ps1 v1.0.3
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName            = 'BarracudaNACVPN'
$script:ScriptVersion      = '1.1.7'
$script:ServiceName        = 'cudanacsvc'
$script:TimeoutSeconds     = 600
$script:SuccessCodes       = @(0, 1605, 1614, 3010, 1641)
$script:DisplayNamePattern = '^Barracuda Network Access Client(?:\s+\d+(?:[.\-]\d+)*)?$'
$script:PublisherPattern   = 'Barracuda Networks*'

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
# %APPDATA%\Barracuda\Network Access Client (confirmed via official Barracuda
# documentation and third-party uninstall records, 2026-09-04 field
# investigation). This script runs as SYSTEM (Intune Win32 apps run in the
# System context by default), so $env:APPDATA resolves to the SYSTEM
# profile, never a real end user's - every local profile under C:\Users must
# be enumerated directly instead of relying on $env:APPDATA.
$script:ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0')
try {
    $UserProfileDirs = @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction Stop |
        Where-Object { ($script:ExcludedProfileNames -notcontains $_.Name) -and ((([string]$_.Attributes) -split ', ') -notcontains 'ReparsePoint') })
}
catch {
    $UserProfileDirs = @()
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

# IME-rooted per the current shop standard (2026-08-20) - C:\IntuneAppLogs
# and C:\IntuneAppMarkers are legacy fallback paths only, not used by new
# writes. See reference_intune_paths.md / AGENTS.md "IME Runtime Paths".
$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Uninstall.txt')
$script:MsiLogFiles = @()

$script:MarkerRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:MarkerFile = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')

# Uninstall removes every marker tier for this app, not just its own
# channel's (2026-08-20 policy) - a real uninstall must not leave any
# marker behind that could falsely satisfy a future detection run.
$script:PdqMarkerPath    = Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath ($script:AppName + '.marker')
$script:LegacyMarkerPath = Join-Path -Path 'C:\IntuneAppMarkers' -ChildPath ($script:AppName + '.tag')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw. -ErrorAction SilentlyContinue on the
    # I/O calls guarantees that; -ErrorVariable still captures a failure so a
    # total logging outage (e.g. an unwritable log root) is not completely
    # silent. Write-Warning is Constrained Language Mode safe. The [Intune]
    # channel tag matches the PDQ counterpart's [PDQ] tag, since both scripts
    # write to the same physical log file by design and a shared file should
    # let a reader tell the two channels' lines apart at a glance.
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
            Write-Warning -Message ('Barracuda NAC VPN Intune uninstall logging failed for log root ''{0}'': {1}' -f $script:LogRoot, $Message)
        }
    }
    catch {
        Write-Warning -Message ('Barracuda NAC VPN Intune uninstall logging threw unexpectedly: {0}' -f $Message)
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
    Stop-AllMsiexecProcessesBestEffort
    Write-Output $Message
    exit $ExitCode
}

function Test-IsAdministrator {
    # fltmc requires an elevated token and remains callable in Constrained
    # Language Mode, unlike the WindowsIdentity/WindowsPrincipal .NET methods
    # this check previously used - independently confirmed blocked under CLM
    # via an isolated runspace test (see AI-Audit-Decisions.md). Matches the
    # PDQ counterpart's elevation check for tandem CLM-risk consistency: CLM
    # enforcement, if ever active, is a machine-level policy that would apply
    # to a script IME launches exactly as it would to one PDQ launches.
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
        $TypeName = $CurrentException.GetType().FullName
        $Message = $CurrentException.Message
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = '(no message provided)'
        }
        else {
            $Message = ($Message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }
        $Parts += ('{0}: {1}' -f $TypeName, $Message)
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

function Remove-BarracudaVpnProfileBestEffort {
    # Never throws. Must run BEFORE MSI removal - Remove-VPNProfile requires
    # the vendor module and the cudanacsvc service, both of which the MSI
    # removal step is about to take away.
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
    # Never throws. Closing the known client processes reduces the chance that
    # an otherwise successful MSI uninstall leaves locked files behind. A
    # matching process name is not sufficient by itself: the executable must
    # also run from an approved Network Access Client folder.
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
    # Never throws. Only meaningful for orphaned-install cleanup (see MAIN's
    # zero-registry-entries branch) - a normal msiexec /x removal already
    # takes the service with it via the MSI's own ServiceControl table and
    # never needs this. Live field case (2026-09-04): repeated killed/hung
    # install attempts left cudanacsvc registered with no MSI product
    # registration to remove it via.
    $Service = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $Service) {
        return
    }

    try {
        if ($Service.Status -ne 'Stopped') {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to stop orphaned service '$($script:ServiceName)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
    }

    try {
        $ScPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\sc.exe'
        if (Test-Path -LiteralPath $ScPath -PathType Leaf) {
            & $ScPath delete $script:ServiceName | Out-Null
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to delete orphaned service '$($script:ServiceName)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
    }
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
    # Emits one path for each residual folder that remains. Callers must wrap
    # the result in @() before checking Count. Recursive deletion is allowed
    # only for exact paths in $script:ResidualFolderPaths and never follows a
    # reparse-point root.
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

            # A file inside the tree can be transiently locked (e.g. a brief
            # AV/EDR on-access scan) at the exact moment of deletion even
            # though nothing owns it a moment before or after - confirmed
            # live, 2026-09-08 (Remove-Item failed with "Access to the path
            # 'BarracudaNAC.dll' is denied", but a Process Explorer Find
            # Handle/DLL check immediately afterward found no owning
            # process). Retry a few times with a short pause before treating
            # it as durable evidence.
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

    foreach ($RemainingFolder in $RemainingFolders) {
        Write-Output $RemainingFolder
    }
}

function Remove-BarracudaShortcut {
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:DestShortcutPath -Force -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $script:DestShortcutPath -PathType Leaf) {
        throw "Desktop shortcut still exists after removal: '$($script:DestShortcutPath)'."
    }
}

function Remove-BarracudaMarker {
    # Removes every marker tier for this app - current Intune, PDQ, and
    # legacy - not just this script's own channel. A real uninstall must
    # not leave any marker behind that could falsely satisfy a future
    # detection run (2026-08-20 policy).
    foreach ($MarkerPath in @($script:MarkerFile, $script:PdqMarkerPath, $script:LegacyMarkerPath)) {
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            throw "Marker file still exists after removal: '$MarkerPath'."
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

    $ProductCode = ConvertTo-MsiProductCode -Candidate $KeyName
    if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
        return $ProductCode
    }

    if (-not [string]::IsNullOrWhiteSpace($UninstallString) -and
        $UninstallString -match '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') {
        return (ConvertTo-MsiProductCode -Candidate ([string]$Matches[0]))
    }

    return ''
}

function Get-BarracudaUninstallEntries {
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
                if (-not (Test-DisplayNameMatch -DisplayName $DisplayName)) {
                    continue
                }

                $Publisher = ''
                $PublisherProperty = $Properties.PSObject.Properties['Publisher']
                if ($null -ne $PublisherProperty) {
                    $Publisher = [string]$PublisherProperty.Value
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

                $IsTrustedTarget = ((Test-PublisherMatch -Publisher $Publisher) -and $IsWindowsInstaller)
                $ProductCode = ''
                if ($IsTrustedTarget) {
                    $ProductCode = Get-ProductCodeFromUninstallEntry -KeyName ([string]$SubKey.PSChildName) -UninstallString $UninstallString
                }

                $Entries += New-Object -TypeName psobject -Property @{
                    RegistryPath     = [string]$SubKey.PSPath
                    KeyName          = [string]$SubKey.PSChildName
                    DisplayName      = $DisplayName
                    Publisher        = $Publisher
                    WindowsInstaller = $IsWindowsInstaller
                    IsTrustedTarget  = $IsTrustedTarget
                    UninstallString  = $UninstallString
                    ProductCode      = $ProductCode
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

function Get-BarracudaDetectedPath {
    foreach ($Path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $Path
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

    $ProductCodes = @()

    foreach ($Entry in @($Entries)) {
        if (-not [bool]$Entry.IsTrustedTarget) {
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
        $RemainingProcesses = @(Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue)
        if ($RemainingProcesses.Count -eq 0) {
            return
        }

        Write-ErrorLog -Message ('Final cleanup: {0} msiexec.exe process(es) still running; stopping all of them.' -f $RemainingProcesses.Count) -Category 'MSIEXEC_SWEEP'

        foreach ($MsiexecProcess in $RemainingProcesses) {
            try {
                $Stopped = Stop-ProcessTreeBestEffort -ProcessId $MsiexecProcess.Id
                if (-not $Stopped) {
                    Write-ErrorLog -Message ('Final cleanup: msiexec.exe (PID {0}) could not be confirmed stopped.' -f $MsiexecProcess.Id) -Category 'MSIEXEC_SWEEP_WARN'
                }
            }
            catch {
                Write-ErrorLog -Message ('Final cleanup: stopping msiexec.exe (PID {0}) threw: {1}' -f $MsiexecProcess.Id, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'MSIEXEC_SWEEP_WARN'
            }
        }

        $StillRunning = @(Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue)
        if ($StillRunning.Count -gt 0) {
            $StillRunningIds = [string]::Join(', ', @($StillRunning | ForEach-Object -Process { [string]$_.Id }))
            Write-ErrorLog -Message ('Final cleanup: {0} msiexec.exe process(es) still running after the sweep (PID(s): {1}).' -f $StillRunning.Count, $StillRunningIds) -Category 'MSIEXEC_SWEEP_INCOMPLETE'
        }
        else {
            Write-ErrorLog -Message 'Final cleanup: all msiexec.exe processes confirmed stopped.' -Category 'MSIEXEC_SWEEP_OK'
        }
    }
    catch {
        Write-ErrorLog -Message ('Final msiexec.exe sweep threw unexpectedly: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'MSIEXEC_SWEEP_WARN'
    }
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


function Get-BarracudaRemainingEvidence {
    $DurableEvidence = @()
    $RebootPendingEvidence = @()

    # Must be a fresh read: this runs after the uninstall attempt, so a
    # pre-uninstall entry snapshot would be stale and unsafe to reuse here.
    $RegistryScan = Get-BarracudaUninstallEntries
    if (-not [bool]$RegistryScan.IsComplete) {
        foreach ($ScanError in @($RegistryScan.Errors)) {
            $DurableEvidence += ('uninstall registry scan incomplete: {0}' -f $ScanError)
        }
    }

    foreach ($Entry in @($RegistryScan.Entries)) {
        if ([bool]$Entry.IsTrustedTarget) {
            $DurableEvidence += ('uninstall registry entry still present: {0} ({1})' -f $Entry.DisplayName, $Entry.RegistryPath)
        }
        else {
            # Same product-name family but failed the publisher/MSI trust
            # check: this script never attempted to remove it, so its mere
            # presence must not block success - only report it.
            Write-ErrorLog -Message ('Unmanaged Barracuda-named uninstall registry entry left in place (failed publisher/MSI identity check, not removed by this script): {0} ({1})' -f $Entry.DisplayName, $Entry.RegistryPath) -Category 'App'
        }
    }

    foreach ($Path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $RebootPendingEvidence += ('executable still present: {0}' -f $Path)
        }
    }

    $Services = @(Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)
    $ServicePresent = ($Services.Count -gt 0)

    foreach ($Path in @($script:ResidualFolderPaths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $Path)) {
            continue
        }

        try {
            $ResidualItem = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
            if (-not $ResidualItem.PSIsContainer) {
                $DurableEvidence += ('non-directory exists at approved residual-folder path: {0}' -f $Path)
                continue
            }
            if ((([string]$ResidualItem.Attributes) -split ', ') -contains 'ReparsePoint') {
                $DurableEvidence += ('reparse point exists at approved residual-folder path: {0}' -f $Path)
                continue
            }

            $IsExecutableFolder = $false
            foreach ($ExecutableFolderPath in $script:ExecutableFolderPaths) {
                if ($Path.TrimEnd('\') -ieq $ExecutableFolderPath.TrimEnd('\')) {
                    $IsExecutableFolder = $true
                    break
                }
            }

            $KnownExecutablePresent = $false
            $FolderPrefix = $Path.TrimEnd('\') + '\'
            foreach ($DetectionPath in $script:DetectionPaths) {
                if ($DetectionPath -like ($FolderPrefix + '*') -and (Test-Path -LiteralPath $DetectionPath -PathType Leaf)) {
                    $KnownExecutablePresent = $true
                    break
                }
            }

            if ($IsExecutableFolder -and ($KnownExecutablePresent -or $ServicePresent)) {
                $RebootPendingEvidence += ('executable folder still present pending restart: {0}' -f $Path)
            }
            else {
                $DurableEvidence += ('residual folder still present after cleanup: {0}' -f $Path)
            }
        }
        catch {
            $DurableEvidence += ('unable to verify residual path ''{0}'': {1}' -f $Path, (Get-ExceptionSummary -ErrorRecord $_))
        }
    }

    foreach ($Service in $Services) {
        $RebootPendingEvidence += ('service still present: {0} (status: {1})' -f $Service.Name, $Service.Status)
    }

    return New-Object -TypeName psobject -Property @{
        Durable       = $DurableEvidence
        RebootPending = $RebootPendingEvidence
    }
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

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -ExitCode 1 -Message 'This uninstaller requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

try {
    # Phase 1: best-effort VPN profile removal WHILE the software still
    # works. Never blocks the uninstall - see function comment.
    Remove-BarracudaVpnProfileBestEffort
    Stop-BarracudaClientProcessesBestEffort

    $InitialRegistryScan = Get-BarracudaUninstallEntries
    if (-not [bool]$InitialRegistryScan.IsComplete) {
        $RegistryErrors = [string]::Join('; ', @($InitialRegistryScan.Errors))
        Stop-WithFailure -ExitCode 1 -Message ('Unable to prove the Barracuda uninstall-registry state because the scan was incomplete: {0}' -f $RegistryErrors) -Category 'System'
    }
    $UninstallEntries = @($InitialRegistryScan.Entries)

    if (-not (Test-BarracudaInstalled -Entries $UninstallEntries)) {
        # Idempotent: already absent. Residual folders are explicitly requested
        # cleanup state and therefore remain mandatory even on this path.
        $RemainingFolders = @(Remove-BarracudaResidualFolders)
        if ($RemainingFolders.Count -gt 0) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client is not registered, but residual folders could not be removed: {0}' -f ([string]::Join('; ', $RemainingFolders))) -Category 'System'
        }

        # Shortcut/marker cleanup here is best-effort only - a transient lock
        # on an orphaned shortcut/marker must not turn an
        # already-resolved state (software genuinely gone) into a failure
        # Intune retries indefinitely. Contrast with the MANDATORY cleanup
        # after a real removal below, where verification protects against
        # reporting false success for a removal this run actually performed.
        try {
            Remove-BarracudaShortcut
        }
        catch {
            Write-ErrorLog -Message "Best-effort shortcut cleanup failed on already-absent path: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
        }
        try {
            Remove-BarracudaMarker
        }
        catch {
            Write-ErrorLog -Message "Best-effort marker cleanup failed on already-absent path: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
        }
        Write-Output 'Barracuda Network Access Client is already absent.'
        Stop-AllMsiexecProcessesBestEffort
        exit 0
    }

    # Direct assignment is required because the helper comma-protects its
    # array result so the zero/one/many shapes remain stable in PS 5.1.
    $ProductCodes = Get-BarracudaProductCodes -Entries $UninstallEntries

    if ($UninstallEntries.Count -gt 0 -and $ProductCodes.Count -eq 0) {
        $EntryPaths = [string]::Join('; ', @($UninstallEntries | ForEach-Object { [string]$_.RegistryPath }))
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client registry entries were found, but none passed the publisher/MSI-registration trust check, so no product code could be resolved: {0}' -f $EntryPaths) -Category 'App'
    }

    if ($ProductCodes.Count -eq 0) {
        # Deliberately NOT falling back to a hardcoded product code here.
        # The only previously-known code belongs to the OLD 5.1.2 MSI and
        # would be actively wrong against a 5.3.8 install - see .DESCRIPTION.
        # Reaching this point means $UninstallEntries.Count is exactly 0 (the
        # UninstallEntries.Count -gt 0 branch above already handled the
        # "untrusted entries exist" case and exits before here) - i.e. there
        # is no registry entry of ANY kind, trusted or not. That removes the
        # ambiguity a real-but-untrusted entry would carry: this is not "an
        # identity we refuse to touch," it is "no registration exists at
        # all," most plausibly orphaned debris from an interrupted install
        # (live field case, 2026-09-04: repeated killed/hung install attempts
        # left files and the service registered without ever reaching
        # RegisterProduct). Attempt orphaned-install cleanup directly rather
        # than only reporting the problem.
        Write-ErrorLog -Message 'Barracuda Network Access Client installation evidence was found (binaries or service present), but no uninstall registry entry of any kind exists. Attempting orphaned-install cleanup.' -Category 'App'
        Remove-BarracudaServiceBestEffort
        Stop-BarracudaClientProcessesBestEffort
        $RemainingFolders = @(Remove-BarracudaResidualFolders)

        $OrphanEvidence = @()
        $OrphanDetectedPath = Get-BarracudaDetectedPath
        if (-not [string]::IsNullOrWhiteSpace($OrphanDetectedPath)) {
            $OrphanEvidence += ('executable still present: {0}' -f $OrphanDetectedPath)
        }
        if (@(Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue).Count -gt 0) {
            $OrphanEvidence += ('service still present: {0}' -f $script:ServiceName)
        }
        if ($RemainingFolders.Count -gt 0) {
            $OrphanEvidence += @($RemainingFolders | ForEach-Object { 'residual folder still present: {0}' -f $_ })
        }

        if ($OrphanEvidence.Count -gt 0) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client installation evidence was found (binaries or service present), no uninstall registry entry exists, and orphaned-install cleanup could not fully remove the remaining evidence: {0}' -f ([string]::Join('; ', $OrphanEvidence))) -Category 'App'
        }

        try {
            Remove-BarracudaShortcut
        }
        catch {
            Write-ErrorLog -Message "Shortcut cleanup failed after orphaned-install cleanup: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
        }
        try {
            Remove-BarracudaMarker
        }
        catch {
            Write-ErrorLog -Message "Marker cleanup failed after orphaned-install cleanup: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
        }

        Write-Output 'Barracuda Network Access Client had orphaned install evidence with no uninstall registry entry; cleanup completed and verified.'
        Stop-AllMsiexecProcessesBestEffort
        exit 0
    }

    $MsiResults = @()

    foreach ($ProductCode in $ProductCodes) {
        $MsiResult = Invoke-MsiUninstall -ProductCode $ProductCode

        if ($script:SuccessCodes -notcontains $MsiResult.ExitCode) {
            Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall failed for product code {0}. msiexec.exe returned {1}. Check TEMP log {2}; a durable copy is attempted under {3}.' -f $ProductCode, $MsiResult.ExitCode, $MsiResult.LogFile, $script:LogRoot) -Category 'App'
        }

        $MsiResults += $MsiResult
    }

    Start-Sleep -Seconds 5

    # A successful MSI transaction can leave configuration or locked client
    # files behind. Stop the user-facing processes again, then perform the
    # requested explicit residual-folder cleanup before final verification.
    Stop-BarracudaClientProcessesBestEffort
    $null = @(Remove-BarracudaResidualFolders)

    $ExitCodes = @($MsiResults | ForEach-Object { [int]$_.ExitCode })
    $OverallExitCode = Get-OverallSuccessExitCode -ExitCodes $ExitCodes
    $RemainingEvidence = Get-BarracudaRemainingEvidence
    $DurableEvidence = @($RemainingEvidence.Durable)
    $RebootPendingEvidence = @($RemainingEvidence.RebootPending)

    if ($DurableEvidence.Count -gt 0) {
        $DurableEvidenceText = [string]::Join('; ', $DurableEvidence)
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall returned {0}, but durable installation evidence still exists: {1}' -f $OverallExitCode, $DurableEvidenceText) -Category 'App'
    }

    if ($RebootPendingEvidence.Count -gt 0 -and $OverallExitCode -notin @(3010, 1641)) {
        $RebootPendingEvidenceText = [string]::Join('; ', $RebootPendingEvidence)
        Stop-WithFailure -ExitCode 1 -Message ('Barracuda Network Access Client uninstall returned {0}, but executable, service, or residual-folder evidence still exists: {1}' -f $OverallExitCode, $RebootPendingEvidenceText) -Category 'App'
    }

    # Only now - MSI removal and residual cleanup confirmed clean or tolerated
    # as reboot-pending - remove the detection-affecting artifacts this app owns.
    Remove-BarracudaShortcut
    Remove-BarracudaMarker

    if ($RebootPendingEvidence.Count -gt 0) {
        $RebootPendingEvidenceText = [string]::Join('; ', $RebootPendingEvidence)
        Write-ErrorLog -Message ('Barracuda Network Access Client uninstall returned reboot-required exit code {0}; remaining in-use evidence should clear at restart. {1}' -f $OverallExitCode, $RebootPendingEvidenceText) -Category 'App'
    }

    Remove-TemporaryMsiLogsBestEffort
    Stop-AllMsiexecProcessesBestEffort
    $ProductCodeText = [string]::Join(', ', $ProductCodes)
    Write-Output ('Barracuda Network Access Client uninstall completed. ExitCode={0}; product code(s)={1}.' -f $OverallExitCode, $ProductCodeText)
    exit $OverallExitCode
}
catch {
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected Barracuda Network Access Client uninstall error: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
}
