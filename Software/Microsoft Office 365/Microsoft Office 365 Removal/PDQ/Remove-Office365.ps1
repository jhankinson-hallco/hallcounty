#Requires -Version 5.1
param(
    # Internal switch. When set, only AppX removal runs (used by the main
    # execution path to bound AppX cmdlet operations with a hard process timeout).
    # Do NOT pass this switch in the Intune portal install command.
    [switch]$AppXOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes all detected M365 component variants from Windows endpoints prior to
    managed M365 deployment.

.DESCRIPTION
    Iteratively scans for and removes the following installation types in order:

      Type 1 - Click-to-Run (C2R)
               The dominant type on modern OEM and managed machines.
               Detected via HKLM ClickToRun Configuration key (ProductReleaseIds).
               Registry access failures are fatal - only a missing or empty
               ProductReleaseIds value is treated as not installed.
               Removed via ODT setup.exe /configure Remove-C2R-All.xml.
               ODT writes its own diagnostic logs to C:\IntuneAppLogs.
               Covers: Word, Excel, PowerPoint, Outlook (classic), OneNote,
               Publisher, Access, Visio (C2R), Project (C2R), Teams (classic
               C2R bundle).

      Type 2 - Microsoft Store / AppX
               Common on consumer OEM Windows 10/11 builds.
               Detected via Get-AppxPackage / Get-AppxProvisionedPackage.
               Bundle packages are targeted first; standalone Main packages follow.
               AppX cmdlets unavailable on LTSC (CommandNotFoundException) are
               treated as not-installed. All other enumeration failures are fatal.
               Covers: all Microsoft.Office.* packages, Office Hub, new Outlook
               (Microsoft.OutlookForWindows), new Teams (MSTeams), classic Teams
               AppX (MicrosoftTeams), OneDrive Store app (Microsoft.OneDriveSync).

               IMPORTANT: AppX removal runs in a bounded 64-bit child process
               (via -AppXOnly self-invocation). AppX cmdlets have no native timeout;
               the child-process pattern ensures AppX work is hard-bounded by
               $script:AppXTimeoutSeconds, matching the budget-check guarantee
               that applies to C2R, MSI, and OneDrive.

      Type 3 - MSI-based (legacy)
               Older Office 2016/2019 MSI installs. Present on LTSC and long-lived
               devices never migrated to C2R. Hive-level registry failures are fatal.
               Per-key read failures are fatal (fail closed) - any unreadable key
               may be an Office-related entry; declaring clean state with incomplete
               scan data is worse than failing and retrying.
               Product code is the registry key name when it is a GUID, or extracted
               from the UninstallString when not. Entries with no extractable GUID
               are skipped - an invalid msiexec /x argument is worse than skipping.
               Covers: Office suite names, channel editions, standalone app families
               (Outlook, Word, Excel, PowerPoint, OneNote, Access, Publisher),
               Visio, and Project.

      Type 4 - Standalone OneDrive (machine-wide Program Files installs)
               Detected via the OneDrive application binary (OneDrive.exe) under
               Program Files. The Windows built-in OneDriveSetup.exe bootstrapper
               in System32/SysWOW64 is NOT used for detection - it is present on
               virtually all Windows 10/11 machines regardless of installed state
               and would cause a false-positive detection loop.
               Per-user OneDrive in %LOCALAPPDATA% requires user context and is
               not in scope for this device-context package.
               Removed via the registered per-machine OneDrive uninstall command
               when present, otherwise via the versioned OneDriveSetup.exe found
               under the same install root as the detected OneDrive.exe binary.
               Post-removal: re-checks the application binary to verify removal.

    Scan order is fixed: Type 1, Type 2, Type 3, Type 4. After each successful
    removal the scan restarts from Type 1.

    PROCESS PREFLIGHT:
    When $script:KillOfficeProcesses is $true (the default), known Office, Teams,
    Outlook, and OneDrive processes are terminated at the start of each scan
    iteration before removal is attempted. This is appropriate for Autopilot,
    White Glove, and controlled maintenance windows. Set $script:KillOfficeProcesses
    to $false if this package is deployed to live assigned devices where users may
    have unsaved work - active processes can block removal but forced kills can cause
    unsaved work loss.

    REBOOT HANDLING:
    If any removal step returns a reboot-required exit code (3010 or 1641), the
    script exits 3010 IMMEDIATELY without writing the completion marker and without
    continuing to scan. For MSI, this means the first reboot-required result aborts
    the entire MSI batch - remaining entries are not processed in the same run.
    Intune reboots the device and re-runs the app. The marker is only written after
    a clean full-pass scan with no reboot needed. This ensures the dependent Office
    install is not started before removal is fully settled.

    RUNTIME BUDGET:
    A global deadline is set at startup (50 min). The remaining budget is checked
    immediately before each removal type is attempted, recomputing elapsed/remaining
    time at the point of the check. If the budget is insufficient for the type being
    attempted, the script fails with exit 1 rather than launching a child process
    that will eventually time out silently.

    Requires 64-bit PowerShell. AppX cmdlets crash a 32-bit PS host silently.
    Use SysNative in the Intune portal install command (see PORTAL SETTINGS below).
    A hard 64-bit process check at startup enforces this.

.NOTES
    Version:        1.5.15
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/04/2026
    Purpose:        Removes all detected M365 component variants prior to managed M365 deployment

    CHANGE LOG
    Change: 13/04/2026 - Initial release -- ver. 1.0.0
    Change: 13/04/2026 - Audit remediation: propagate reboot exit codes; fix MSI product code
                         extraction; replace blanket AppX catch with CommandNotFoundException
                         handling; bundle-first AppX targeting; reduce timeouts; add Visio/Project
                         to MSI patterns; add provisioned AppX post-removal check; remove C2R
                         secondary file check; version-stamp marker -- ver. 1.1.0
    Change: 13/04/2026 - Audit remediation: exit 3010 immediately on reboot-needed without writing
                         marker; global runtime deadline guard; C2R registry failures now fatal;
                         MSI hive failures fatal, per-key to stderr; AppX HRESULT-only race
                         handling; Type 4 OneDrive; AppX patterns for new Outlook, Teams, OneDrive
                         Store; MaxIterations reduced to 8 -- ver. 1.2.0
    Change: 13/04/2026 - Audit remediation: fixed Type 4 OneDrive detection to use OneDrive.exe
                         application binary (not installer stub); removed System32/SysWOW64 from
                         OneDrive candidates (always-present bootstrapper, not install signal);
                         added OneDrive post-removal verification; made runtime budget action-aware
                         (checks per-type cost before starting each removal); added 64-bit process
                         guard at startup; MSI per-key skips now written to error log not stderr;
                         fixed Type 1 description (new Outlook is AppX Type 2, not C2R); updated
                         package description to reflect full M365 pre-deployment cleanup scope
                         -- ver. 1.3.0
    Change: 13/04/2026 - Audit remediation: MSI loop now exits immediately on first 3010/1641
                         (no continued processing after a reboot-required result); MSI name
                         patterns expanded with standalone app families (Outlook, Word, Excel,
                         PowerPoint, OneNote, Access, Publisher); AppX removal now runs in a
                         bounded 64-bit child process via -AppXOnly self-invocation with hard
                         timeout (AppX cmdlets have no native timeout - child-process pattern
                         closes this gap); unreadable MSI registry keys now fail closed (any
                         unreadable key throws - incomplete scan cannot declare clean state);
                         OneDrive installer path now explicitly derived from the same directory
                         as the detected OneDrive.exe binary (independent candidate list removed);
                         added Stop-OfficeProcesses preflight to kill known Office/Teams/Outlook
                         processes at the start of each scan iteration; renamed AppName to
                         M365 Pre-Cleanup for scope consistency -- ver. 1.4.0
    Change: 13/04/2026 - Audit remediation: fixed throw syntax in Get-MSIOfficeEntries (format
                         operator was outside throw expression - unformatted string was thrown);
                         budget timing now recomputed immediately before every
                         Assert-BudgetSufficient call (previously stale from top of iteration);
                         process preflight gated behind $script:KillOfficeProcesses flag (default
                         $true) to prevent unsaved work loss if deployed to live devices;
                         Write-ErrorLog now explicitly creates log file before appending per
                         logging standard; updated Detect.ps1/Uninstall.ps1 synopses and
                         detection output string from Office 365 Pre-Cleanup to M365 Pre-Cleanup
                         -- ver. 1.5.0
    Change: 13/04/2026 - Renamed log file to M365PreCleanup_Remove.txt and marker file to
                         M365PreCleanup.marker for consistency with M365 Pre-Cleanup package
                         identity; updated Detect.ps1 and Uninstall.ps1 to match -- ver. 1.5.1
    Change: 13/04/2026 - Pre-create C:\IntuneAppLogs before the scan loop so ODT diagnostic
                         output always has a destination even on a clean no-error run where
                         Write-ErrorLog is never called -- ver. 1.5.2
    Change: 14/04/2026 - Added [CmdletBinding()] to Invoke-NativeProcess for deterministic
                         PS 5.1 parameter binding; hardened against P22 re-emergence from
                         future edits -- ver. 1.5.3
    Change: 15/04/2026 - Converted Invoke-NativeProcess to a simple function (removed
                         [CmdletBinding()] and all [Parameter()] attributes). PS 5.1's
                         advanced-function parameter-set resolution engine was throwing
                         ParameterBindingException on every invocation despite all params
                         being consistently decorated. Simple functions bypass that engine
                         entirely; named-parameter calls still bind correctly -- ver. 1.5.4
    Change: 15/04/2026 - Tightened standalone Visio/Project MSI display-name patterns from
                         broad prefix anchors ('^Visio\s', '^Project\s') to edition- and
                         year-qualified forms ('^Visio (Standard|Professional|\d)',
                         '^Project (Standard|Professional|\d)') to reduce false-positive
                         uninstall risk on non-Microsoft products; synced .NOTES version
                         to match $script:AppVersion -- ver. 1.5.5
    Change: 15/04/2026 - Converted ALL remaining functions with [Parameter()] attributes to
                         simple functions (Write-ErrorLog, Exit-Failure, Assert-BudgetSufficient,
                         Get-ExceptionSummary, Invoke-RemoveC2R, Invoke-RemoveMSIOffice).
                         PS 5.1 advanced-function parameter-set resolution was throwing
                         ParameterBindingException on every decorated function regardless of
                         decoration consistency. This is the same engine failure that was
                         isolated in Invoke-NativeProcess (v1.5.4). Removing [Parameter()]
                         from all functions eliminates the failure class entirely -- ver. 1.5.6
    Change: 15/04/2026 - Replaced all 53 em-dash (U+2014) characters with ASCII hyphens.
                         Em-dashes in comments are syntactically safe but introduce encoding
                         ambiguity: PS 5.1 reads UTF-8-no-BOM files as Windows-1252, treating
                         each em-dash as three bytes (0xE2 0x80 0x94 -> a, euro, right-dquote).
                         All were in comments or a single-quoted string so they did not cause
                         failures, but removing them eliminates the class entirely.
                         Moved C:\IntuneAppLogs pre-creation to the first operation in the
                         MAIN block so the log folder exists before any Exit-Failure call,
                         including the 64-bit guard and AppXOnly path -- ver. 1.5.7
    Change: 17/04/2026 - Replaced all Split-Path -LiteralPath ... -Parent calls with
                         [System.IO.Path]::GetDirectoryName() (4 instances: Get-ScriptRoot,
                         Invoke-NativeProcess WorkingDirectory, Invoke-RemoveOneDrive
                         installDir, marker write markerDir). Split-Path -LiteralPath with
                         -Parent throws ParameterBindingException in PS 5.1 under IME/SYSTEM
                         context -- confirmed field failure at line 488 in v1.5.7 White Glove
                         run. GetDirectoryName() is pure .NET with no parameter binding -- ver. 1.5.8
    Change: 20/04/2026 - Wrapped all .Count accesses on Get-AppXOfficePackages,
                         Get-AppXOfficeProvisionedPackages, and Get-MSIOfficeEntries return
                         values with @(). PS pipeline unwraps single-element arrays to scalars;
                         .Count on a bare AppxPackage or PSCustomObject throws
                         PropertyNotFoundException under Set-StrictMode -Version Latest.
                         Affected locations: Test-AppXOfficeInstalled (both checks),
                         Invoke-RemoveAppXOffice post-removal verification, and $msiEntries
                         in the main loop -- confirmed field failure [v1.5.8] line 717 -- ver. 1.5.9
    Change: 21/04/2026 - Added PSObject.Properties existence guards before accessing
                         DisplayName and UninstallString on registry key property objects
                         in Get-MSIOfficeEntries. Set-StrictMode -Version Latest throws
                         PropertyNotFoundException when a registry key has no DisplayName
                         or UninstallString value -- many driver and system uninstall keys
                         omit these values entirely. Confirmed field failure [v1.5.9]
                         line 835 -- ver. 1.5.10
    Change: 22/04/2026 - Invoke-RemoveAppXOffice now handles COMException Access Denied
                         (0x80070005) on Remove-AppxProvisionedPackage gracefully: logs the
                         skipped package and continues instead of throwing. Affected packages
                         (e.g. Microsoft.OfficePushNotificationUtility) are tracked in an
                         $accessDeniedProvisioned HashSet and excluded from the post-removal
                         failure check so only genuinely removable packages cause a failure.
                         Function now returns $true if any protected packages were skipped,
                         $false if fully clean. AppXOnly child exits 2 (instead of 0) when
                         protected packages remain. Main loop uses $appxProtectedSkip flag:
                         set on exit code 2, gates AppX detection block in subsequent
                         iterations so the loop does not exhaust MaxIterations retrying work
                         that cannot succeed. Confirmed field failure [v1.5.10] line 752 --
                         ver. 1.5.11
    Change: 29/04/2026 - Fixed PS 5.1-incompatible AppXOnly exit expression; AppX child now
                         uses statement-form if/exit logic. OneDrive removal now resolves the
                         registered uninstall command or searches versioned install folders
                         instead of assuming OneDriveSetup.exe is beside OneDrive.exe. Added
                         MSI exit code 1614 (product uninstalled) as idempotent success --
                         ver. 1.5.12
    Change: 01/05/2026 - Fixed AppX HRESULT handling to compare signed Int32 HRESULT values
                         directly. v1.5.12 overflowed before the protected-package skip path
                         when Access Denied returned -2147024891 (0x80070005) -- ver. 1.5.13
    Change: 06/05/2026 - Added DISM removal pass for provisioned AppX packages that cannot
                         be removed by Remove-AppxProvisionedPackage in SYSTEM context
                         (confirmed: Microsoft.OfficePushNotificationUtility,
                         Microsoft.OneDriveSync). When the AppX child exits 2,
                         Invoke-DismRemoveProtectedProvisionedPackages re-queries remaining
                         provisioned packages and removes each via
                         DISM /Online /Remove-ProvisionedAppxPackage. Non-fatal: each DISM
                         call is logged on success or failure. Matches the pattern used in
                         System-RemoveBloatwareAppX.ps1 for Clipchamp -- ver. 1.5.14
    Change: 06/05/2026 - DISM AppX cleanup is now fail-closed: the DISM pass returns
                         success only after a clean post-DISM provisioned package re-query.
                         The marker is not written when targeted provisioned AppX packages
                         remain. Added a DISM runtime budget check before DISM starts
                         -- ver. 1.5.15

    PORTAL SETTINGS
    Install command   : %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Remove-Office365.ps1
    Uninstall command : %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall.ps1
    Install behavior  : System
    Install time      : 60 minutes
    Restart behavior  : Determine behavior based on return codes
    Detection         : Custom script - Detect.ps1 / Run as 32-bit: No / Signature check: No

    RUNTIME BUDGET NOTE
    Global deadline is 3000 s (50 min), leaving a 10-min buffer against the 60-min portal limit.
    ODT timeout is 1800 s (30 min) per C2R removal pass - budget guard requires this + 60 s buffer.
    MSI timeout is 300 s (5 min) per product entry - budget guard requires (count * 300) + 60 s.
    AppX timeout is 180 s (3 min) per child-process invocation - budget guard requires 240 s.
    OneDrive timeout is 120 s - budget guard requires 180 s.
    Budget timing is recomputed at the point of each check, not at the top of the loop.
#>

#region ========================= CONFIGURATION =========================

# Application name used in log entries and the completion marker.
$script:AppName = 'M365 Pre-Cleanup'

# Script version written into log entries and the completion marker.
# Detect.ps1 validates this exact value. Bumping this version forces a re-run
# on any device whose marker was written by an older version.
$script:AppVersion = '1.5.15'

# Error-only log settings. Folder and file are created only on first error.
# Note: ODT also writes its own diagnostic logs to this folder.
$script:LogRoot     = 'C:\IntuneAppLogs'
$script:LogFileName = 'M365PreCleanup_Remove.txt'

# Marker file written after a clean full-pass scan with no reboot needed.
# NOT written when exiting 3010.
$script:MarkerFile = 'C:\ProgramData\HallCountyMIS\M365PreCleanup.marker'

# ODT setup.exe file name. Must be in the same folder as this script.
$script:SetupExeName = 'setup.exe'

# ODT removal XML file name. Must be in the same folder as this script.
$script:RemoveXmlName = 'Remove-C2R-All.xml'

# Maximum scan/remove loop iterations per run before giving up.
# Real ceiling with 4 types: 5 iterations (4 removals + 1 clean pass).
# 8 provides margin. A 3010 exit ends the current run; MaxIterations resets
# on each Intune-triggered re-run after reboot.
$script:MaxIterations = 8

# Global runtime deadline in seconds from script start.
# Checked immediately before each removal type is attempted (timing recomputed
# at the check point, not stale from the top of the loop).
# 3000 s (50 min) leaves a 10-min buffer against the 60-min portal limit.
$script:RuntimeDeadlineSeconds = 3000

# Per-process timeout for ODT (setup.exe) in seconds.
$script:ODTTimeoutSeconds = 1800

# Per-process timeout for msiexec in seconds, applied per product code.
$script:MSITimeoutSeconds = 300

# Hard timeout for the AppX child process (-AppXOnly mode) in seconds.
# AppX cmdlets have no native timeout. This bounds the child process via
# Invoke-NativeProcess, mirroring the pattern used for ODT, MSI, and OneDrive.
$script:AppXTimeoutSeconds = 180

# Per-process timeout for OneDriveSetup.exe in seconds.
$script:OneDriveTimeoutSeconds = 120

# Per-package timeout for DISM provisioned package removal in seconds.
$script:DismTimeoutSeconds = 120

# Safety buffer added to each per-type budget estimate (seconds).
# Accounts for process launch, detection re-check, and other overhead.
$script:BudgetBufferSeconds = 60

# Controls whether Office, Teams, Outlook, and OneDrive processes are forcibly
# terminated at the start of each scan iteration before removal is attempted.
# $true  - appropriate for Autopilot, White Glove, and controlled maintenance
#          windows where no interactive user session is present.
# $false - use when deploying to live assigned devices where users may have
#          unsaved work; active processes can delay or block removal, but forced
#          kills can cause data loss. Investigate blocking processes separately.
$script:KillOfficeProcesses = $true

# ODT exit codes treated as success.
$script:ODTSuccessExitCodes = @(0, 3010, 1641)

# msiexec exit codes treated as success.
# 1605 = product not installed (idempotent - treat as already gone).
# 1614 = product uninstalled (idempotent - treat as already gone).
$script:MSISuccessExitCodes = @(0, 1605, 1614, 3010, 1641)

# OneDrive uninstaller exit codes treated as success.
# OneDriveSetup.exe /uninstall returns 0 on success; 1 on "not installed."
# Both are acceptable - post-removal verification confirms actual removal state.
$script:OneDriveSuccessExitCodes = @(0, 1)

# AppX package Name patterns to target (regex against Package.Name).
$script:AppXPatterns = @(
    '^Microsoft\.Office',
    '^Microsoft\.MicrosoftOfficeHub$',
    '^Microsoft\.OutlookForWindows$',
    '^MSTeams$',
    '^MicrosoftTeams$',
    '^Microsoft\.OneDriveSync$'
)

# MSI DisplayName regex patterns. Entries whose UninstallString contains
# 'ClickToRun' are always excluded - handled by ODT (Type 1).
# Patterns cover:
#   - Suite / channel edition names (Microsoft Office ..., Microsoft 365 ...)
#   - Standalone Office app families (Outlook, Word, Excel, etc.)
#   - Standalone productivity add-ons (Visio, Project)
$script:MSIDisplayNamePatterns = @(
    # Suite and channel edition names
    '^Microsoft Office\s',
    '^Microsoft 365\s',
    '^Microsoft\s+365\s+Apps',
    # Standalone Office app families - present on legacy MSI installs where
    # individual apps were sold separately (Office 2016/2019 volume).
    '^Microsoft Outlook\s',
    '^Microsoft Word\s',
    '^Microsoft Excel\s',
    '^Microsoft PowerPoint\s',
    '^Microsoft OneNote\s',
    '^Microsoft Access\s',
    '^Microsoft Publisher\s',
    # Standalone productivity add-ons
    '^Microsoft Visio\s',
    '^Microsoft Project\s',
    # Visio/Project MSI products without the "Microsoft" prefix (e.g. "Visio Professional 2016",
    # "Visio Standard 2019", "Project Professional 2016"). Tightened to known Microsoft edition
    # keywords and year-prefixed forms to avoid matching unrelated third-party products whose
    # display names happen to start with "Visio" or "Project".
    '^Visio (Standard|Professional|\d)',
    '^Project (Standard|Professional|\d)'
)

# OneDrive application binary paths (detection signal).
# These are the actual OneDrive application EXEs, not installer stubs.
# System32/SysWOW64 OneDriveSetup.exe is intentionally excluded - it is
# a Windows built-in bootstrapper present on all W10/W11 machines regardless
# of whether OneDrive is installed, and would create a false-positive loop.
# The OneDriveSetup.exe installer used for removal is resolved from the
# registered uninstall command first. If that is absent, the script searches
# under the matched binary's install root for versioned OneDriveSetup.exe files.
$script:OneDriveAppBinaryCandidates = @(
    'C:\Program Files\Microsoft OneDrive\OneDrive.exe',
    'C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe'
)

#endregion =================================================================


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

function Get-ScriptRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }
    return $null
}


function Write-ErrorLog {
    # Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    # $Category valid values: App, System, Network, Permissions, Intune
    param(
        [string]$Message,
        [string]$Category = 'App'
    )

    try {
        # Create folder, then file, then append - per logging standard.
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        $logPath   = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        if (-not [System.IO.File]::Exists($logPath)) {
            [System.IO.File]::WriteAllText($logPath, '', $utf8NoBom)
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line      = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try { [Console]::Error.WriteLine('{0} log failed: {1}' -f $script:AppName, $Message) } catch { }
    }
}


function Exit-Failure {
    # Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    # $Category valid values: App, System, Network, Permissions, Intune
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}


function Exit-RebootRequired {
    <#
        Called when any removal step signals reboot-needed (3010 or 1641).
        Does NOT write the completion marker. Intune will reboot the device
        and re-run this app. The marker is only written after a clean
        post-reboot full-pass scan confirms all types are absent.
    #>
    exit 3010
}


function Assert-BudgetSufficient {
    <#
        Checks that enough runtime remains to attempt a removal of the given type.
        Exits 1 with a log entry if the budget is too small.
        Called immediately before each removal type, with freshly recomputed
        elapsed/remaining values - not stale values from the top of the loop.
        Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    #>
    param(
        [string]$TypeName,
        [int]$EstimatedCostSeconds,
        [int]$RemainingSeconds,
        [int]$ElapsedSeconds
    )

    $required = $EstimatedCostSeconds + $script:BudgetBufferSeconds

    if ($RemainingSeconds -lt $required) {
        Exit-Failure -Code 1 -Message (
            'Insufficient runtime budget to attempt {0} removal. Required: {1} s (estimated {2} s + {3} s buffer). Remaining: {4} s. Elapsed: {5} s.' -f
            $TypeName, $required, $EstimatedCostSeconds, $script:BudgetBufferSeconds, $RemainingSeconds, $ElapsedSeconds
        ) -Category 'App'
    }
}


function Get-ExceptionSummary {
    # Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $ex    = $ErrorRecord.Exception

    while ($null -ne $ex) {
        $msg = if ([string]::IsNullOrWhiteSpace($ex.Message)) {
            '(no message)'
        } else {
            ($ex.Message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }
        [void]$parts.Add(('{0}: {1}' -f $ex.GetType().FullName, $msg))
        $ex = $ex.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
    }

    return ($parts -join ' | ')
}


function Invoke-NativeProcess {
    <#
        Runs an external executable with an explicit timeout.
        Returns the integer exit code.
        Throws on process launch failure or timeout.

        Implemented as a SIMPLE function (no [CmdletBinding()], no [Parameter()]
        attributes on any parameter). This bypasses PS 5.1's advanced-function
        parameter-set resolution engine, which was producing
        "Parameter set cannot be resolved using the specified named parameters"
        regardless of decoration strategy. Simple functions bind named parameters
        by name match only - no parameter-set disambiguation occurs.
        All callers use explicit named parameters so positional binding is not needed.
    #>
    param(
        [string]$FilePath,
        [string]$Arguments = '',
        [int]$TimeoutSeconds
    )

    $startInfo                  = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName         = $FilePath
    $startInfo.Arguments        = $Arguments
    $startInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($FilePath)
    $startInfo.UseShellExecute  = $false
    $startInfo.CreateNoWindow   = $true

    $process           = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()

        if (-not $started) {
            throw ('Process.Start() returned False for ''{0}''.' -f $FilePath)
        }

        $hasExited = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $hasExited) {
            try { $null = & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 } catch { }
            try { $null = $process.WaitForExit(5000) } catch { }
            throw ('Process timed out after {0} seconds: ''{1}''.' -f $TimeoutSeconds, $FilePath)
        }

        return [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}


function Stop-OfficeProcesses {
    <#
        Terminates known Office, Teams, Outlook, and OneDrive processes before
        removal attempts. Active processes can block uninstallers, prolong removal,
        or force reboot-needed paths.

        Only called when $script:KillOfficeProcesses is $true. Set that flag to
        $false if deploying to live assigned devices where unsaved work loss is
        unacceptable. See configuration section for details.

        Errors are silently ignored - the target processes may not be running.
        This function is best-effort and does not affect script success/failure.
    #>
    $targets = @(
        # Classic Office suite executables
        'WINWORD', 'EXCEL', 'POWERPNT', 'OUTLOOK', 'ONENOTE',
        'MSACCESS', 'MSPUB', 'VISIO', 'WINPROJ',
        # Classic Teams
        'Teams',
        # New Teams (Store version)
        'ms-teams',
        # New Outlook
        'olk',
        # OneDrive (also explicitly terminated inside Invoke-RemoveOneDrive;
        # killing it here early reduces lock contention across Types 1-3)
        'OneDrive', 'OneDriveSetup',
        # Office C2R background host
        'OfficeClickToRun'
    )

    $killed = $false
    foreach ($name in $targets) {
        try {
            $null = & "$env:SystemRoot\System32\taskkill.exe" /IM "$name.exe" /F 2>&1
            if ($LASTEXITCODE -eq 0) { $killed = $true }
        }
        catch { }
    }

    # Brief wait after any successful kills to allow file handle release.
    if ($killed) {
        Start-Sleep -Seconds 3
    }
}


# ---------------------------------------------------------------------------
# Type 1 - Click-to-Run (C2R)
# ---------------------------------------------------------------------------

function Test-C2RInstalled {
    <#
        Returns $true if a C2R Office installation is detected.

        Detection is registry-only: HKLM ClickToRun Configuration key with a
        non-empty ProductReleaseIds value. This value is absent or empty after
        a clean ODT removal.

        Real registry access failures are NOT suppressed - they propagate to the
        caller and are treated as fatal. Only two non-error outcomes exist:
          - Key does not exist -> not installed.
          - Key exists, ProductReleaseIds property absent or empty -> not installed.
    #>

    $configKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'

    if (-not (Test-Path -LiteralPath $configKey)) {
        return $false
    }

    $props = Get-ItemProperty -LiteralPath $configKey -ErrorAction Stop

    if (-not $props.PSObject.Properties['ProductReleaseIds']) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace($props.ProductReleaseIds))
}


function Invoke-RemoveC2R {
    <#
        Runs ODT removal. Returns $true if a reboot was signalled (3010/1641),
        $false if removal completed without a reboot requirement.
        Throws on unexpected exit codes.
    #>
    # Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    param(
        [string]$SetupExePath,
        [string]$RemoveXmlPath
    )

    $arguments = '/configure "{0}"' -f $RemoveXmlPath

    $exitCode = Invoke-NativeProcess `
        -FilePath       $SetupExePath `
        -Arguments      $arguments `
        -TimeoutSeconds $script:ODTTimeoutSeconds

    if ($script:ODTSuccessExitCodes -notcontains $exitCode) {
        throw ('ODT removal exited with unexpected code {0}. Review ODT logs in C:\IntuneAppLogs.' -f $exitCode)
    }

    return ($exitCode -in @(3010, 1641))
}


# ---------------------------------------------------------------------------
# Type 2 - Microsoft Store / AppX
# ---------------------------------------------------------------------------

function Get-AppXOfficePackages {
    <#
        Returns AppxPackage objects matching M365-related patterns.
        Bundle packages first (one removal handles all sub-packages).
        Standalone Main packages follow for any family not covered by a bundle.
        CommandNotFoundException = LTSC, treat as not-installed.
        All other exceptions propagate.
    #>

    $found     = New-Object 'System.Collections.Generic.List[object]'
    $seenNames = New-Object 'System.Collections.Generic.HashSet[string]'

    try {
        $bundlePackages = Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -ErrorAction Stop
        foreach ($pkg in $bundlePackages) {
            foreach ($pattern in $script:AppXPatterns) {
                if ($pkg.Name -match $pattern) {
                    [void]$seenNames.Add($pkg.PackageFamilyName)
                    [void]$found.Add($pkg)
                    break
                }
            }
        }

        $mainPackages = Get-AppxPackage -AllUsers -PackageTypeFilter Main -ErrorAction Stop
        foreach ($pkg in $mainPackages) {
            foreach ($pattern in $script:AppXPatterns) {
                if ($pkg.Name -match $pattern) {
                    if ($seenNames.Add($pkg.PackageFamilyName)) {
                        [void]$found.Add($pkg)
                    }
                    break
                }
            }
        }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        return $found.ToArray()
    }
    catch {
        throw
    }

    return $found.ToArray()
}


function Get-AppXOfficeProvisionedPackages {
    <#
        Returns provisioned AppX M365 packages.
        CommandNotFoundException = LTSC, treat as not-installed.
        All other exceptions propagate.
    #>

    $found = New-Object 'System.Collections.Generic.List[object]'

    try {
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction Stop

        foreach ($pkg in $provisioned) {
            $namePrefix = ($pkg.PackageName -split '_')[0]
            foreach ($pattern in $script:AppXPatterns) {
                if ($namePrefix -match $pattern) {
                    [void]$found.Add($pkg)
                    break
                }
            }
        }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        return $found.ToArray()
    }
    catch {
        throw
    }

    return $found.ToArray()
}


function Test-AppXOfficeInstalled {
    # @() forces the pipeline return into a real array regardless of element count.
    # Without it, a single-element return is unwrapped to a scalar by the PS pipeline,
    # and .Count does not exist on AppxPackage/AppxProvisionedPackage objects.
    # Set-StrictMode -Version Latest throws PropertyNotFoundException in that case.
    if (@(Get-AppXOfficePackages).Count -gt 0)            { return $true }
    if (@(Get-AppXOfficeProvisionedPackages).Count -gt 0) { return $true }
    return $false
}


function Invoke-RemoveAppXOffice {
    <#
        Removes all matching provisioned and per-user AppX packages.
        Invoked in a child process via -AppXOnly to enforce a hard timeout.
        AppX removal does not produce reboot-required exit codes.

        Returns $true if any provisioned packages were skipped due to Access Denied
        (0x80070005 - protected system components that cannot be removed in SYSTEM
        context). Returns $false if all packages were fully removed.

        The caller uses the return value to exit with code 2 (protected packages
        remain but nothing more can be done) vs. code 0 (fully clean). The parent
        process uses exit code 2 to stop re-triggering AppX detection in subsequent
        iterations - without this, the loop would retry and hit MaxIterations.
    #>

    # Track provisioned packages that failed with Access Denied. These are protected
    # system components - retrying will not help. They are logged but not thrown.
    $accessDeniedProvisioned = New-Object 'System.Collections.Generic.HashSet[string]'

    $provisioned = Get-AppXOfficeProvisionedPackages

    foreach ($pkg in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
        }
        catch {
            # 0x80070005 = E_ACCESSDENIED - package is protected from removal in SYSTEM
            # context (e.g. Microsoft.OfficePushNotificationUtility on newer OEM builds).
            # Log it and continue - retrying will not change the outcome.
            # All other HRESULTs are re-thrown as genuine failures.
            $hResult = [int]$_.Exception.HResult
            if ($hResult -eq -2147024891) {   # 0x80070005 = E_ACCESSDENIED (signed Int32)
                $summary = Get-ExceptionSummary -ErrorRecord $_
                Write-ErrorLog -Message ('AppX provisioned package ''{0}'' skipped - Access Denied (protected system component, cannot be removed in SYSTEM context): {1}' -f $pkg.PackageName, $summary) -Category 'App'
                [void]$accessDeniedProvisioned.Add($pkg.PackageName)
            }
            else {
                $summary = Get-ExceptionSummary -ErrorRecord $_
                throw ('Failed to remove provisioned AppX package ''{0}'': {1}' -f $pkg.PackageName, $summary)
            }
        }
    }

    $packages = Get-AppXOfficePackages

    foreach ($pkg in $packages) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        }
        catch {
            # 0x80073CF1 = ERROR_PACKAGE_NOT_FOUND - race condition, already removed.
            # No other HRESULT is silenced.
            $hResult = [int]$_.Exception.HResult
            if ($hResult -ne -2147009295) {   # 0x80073CF1 = ERROR_PACKAGE_NOT_FOUND (signed Int32)
                $summary = Get-ExceptionSummary -ErrorRecord $_
                throw ('Failed to remove AppX package ''{0}'': {1}' -f $pkg.PackageFullName, $summary)
            }
        }
    }

    # @() ensures .Count is safe even if exactly one package remains (scalar unwrap - see Test-AppXOfficeInstalled).
    $remainingInstalled   = @(Get-AppXOfficePackages)
    $remainingProvisioned = @(Get-AppXOfficeProvisionedPackages)

    # Exclude access-denied provisioned packages from the failure check - they were
    # already logged and cannot be removed. Only fail if unhandled packages remain.
    $blockingProvisioned = @($remainingProvisioned | Where-Object { -not $accessDeniedProvisioned.Contains($_.PackageName) })

    if ($remainingInstalled.Count -gt 0 -or $blockingProvisioned.Count -gt 0) {
        $installedNames   = $remainingInstalled    | ForEach-Object { $_.Name }
        $provisionedNames = $blockingProvisioned   | ForEach-Object { ($_.PackageName -split '_')[0] }
        $allNames         = ($installedNames + $provisionedNames) -join ', '
        throw ('AppX removal completed but packages are still present: {0}' -f $allNames)
    }

    # Return $true if protected packages were skipped, $false if fully clean.
    return ($accessDeniedProvisioned.Count -gt 0)
}


# ---------------------------------------------------------------------------
# Type 2 supplement - DISM removal for protected provisioned AppX packages
# ---------------------------------------------------------------------------

function Invoke-DismRemoveProtectedProvisionedPackages {
    <#
        Removes provisioned AppX packages that are protected from removal via
        Remove-AppxProvisionedPackage in SYSTEM context (0x80070005 Access Denied).
        DISM retains the authority to remove these packages via
        /Remove-ProvisionedAppxPackage.

        Called when the AppX child process exits 2. Re-queries remaining provisioned
        packages matching $script:AppXPatterns and removes each via DISM.

        Returns $true only when no matching provisioned packages remain after DISM.
        Returns $false when DISM is unavailable, package enumeration fails, DISM
        fails to remove a package, or the post-DISM re-query still finds targeted
        provisioned packages. The parent fails the run on $false so the completion
        marker cannot be written over a known dirty AppX state.

        Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for
        rationale.
    #>

    # Resolve DISM. From a 64-bit process (enforced at startup), System32 is the
    # real 64-bit path and SysNative does not exist. Check SysNative first for
    # defensive consistency with non-standard invocation paths.
    $dismExe = Join-Path -Path $env:SystemRoot -ChildPath 'SysNative\dism.exe'
    if (-not (Test-Path -LiteralPath $dismExe -PathType Leaf)) {
        $dismExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dism.exe'
    }

    if (-not (Test-Path -LiteralPath $dismExe -PathType Leaf)) {
        Write-ErrorLog -Message 'DISM pass skipped: dism.exe not found under System32 or SysNative.' -Category 'System'
        return $false
    }

    $remainingProvisioned = @()
    try {
        $remainingProvisioned = @(Get-AppXOfficeProvisionedPackages)
    }
    catch {
        Write-ErrorLog -Message ('DISM pass: provisioned package query failed - {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
        return $false
    }

    if ($remainingProvisioned.Count -eq 0) {
        return $true
    }

    foreach ($pkg in $remainingProvisioned) {
        $dismArgs = '/Online /Remove-ProvisionedAppxPackage "/PackageName:{0}" /Quiet /NoRestart' -f $pkg.PackageName
        try {
            $exitCode = Invoke-NativeProcess `
                -FilePath       $dismExe `
                -Arguments      $dismArgs `
                -TimeoutSeconds $script:DismTimeoutSeconds
            if ($exitCode -eq 0) {
                Write-ErrorLog -Message ('DISM removed provisioned package ''{0}''.' -f $pkg.PackageName) -Category 'App'
            }
            else {
                Write-ErrorLog -Message ('DISM removal of ''{0}'' exited {1}.' -f $pkg.PackageName, $exitCode) -Category 'App'
            }
        }
        catch {
            Write-ErrorLog -Message ('DISM removal of ''{0}'' failed: {1}' -f $pkg.PackageName, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
        }
    }

    $remainingAfterDism = @()
    try {
        $remainingAfterDism = @(Get-AppXOfficeProvisionedPackages)
    }
    catch {
        Write-ErrorLog -Message ('DISM pass: post-DISM provisioned package query failed - {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
        return $false
    }

    if ($remainingAfterDism.Count -gt 0) {
        $remainingNames = ($remainingAfterDism | ForEach-Object { $_.PackageName }) -join ', '
        Write-ErrorLog -Message ('DISM pass completed but targeted provisioned packages remain: {0}' -f $remainingNames) -Category 'App'
        return $false
    }

    return $true
}


# ---------------------------------------------------------------------------
# Type 3 - MSI-based (legacy)
# ---------------------------------------------------------------------------

function Get-MSIOfficeEntries {
    <#
        Scans 64-bit and 32-bit uninstall registry hives for MSI Office entries.
        Excludes C2R entries (UninstallString contains 'ClickToRun').

        Hive-level read failures are fatal.

        Per-key read failures are ALSO fatal (fail closed). Any unreadable key
        might be an Office-related MSI entry. Declaring clean state when the scan
        is incomplete is worse than failing - caller will log and exit 1, allowing
        Intune to retry. The key name is logged before throwing so the offending
        entry is visible for triage.

        Product code: registry key name if GUID, else extracted from UninstallString.
        Entries with no extractable GUID are skipped.
    #>

    $uninstallHives = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    $guidPattern    = '^\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}$'
    $guidSearch     = '\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}'

    $found          = New-Object 'System.Collections.Generic.List[object]'
    $seenCodes      = New-Object 'System.Collections.Generic.HashSet[string]'
    $unreadableKeys = New-Object 'System.Collections.Generic.List[string]'

    foreach ($hive in $uninstallHives) {
        if (-not (Test-Path -LiteralPath $hive)) { continue }

        # Hive-level failure is fatal - SYSTEM should always be able to read HKLM.
        $keys = Get-ChildItem -LiteralPath $hive -ErrorAction Stop

        foreach ($key in $keys) {
            try {
                $props = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            }
            catch {
                # Per-key failure: log the key name and collect it.
                # We do NOT skip silently - see function header.
                $msg = 'MSI scan: cannot read uninstall key {0}: {1}' -f $key.PSChildName, $_.Exception.Message
                Write-ErrorLog -Message $msg -Category 'System'
                [void]$unreadableKeys.Add($key.PSChildName)
                continue
            }

            # Guard both property accesses with PSObject.Properties checks.
            # Set-StrictMode -Version Latest throws PropertyNotFoundException when
            # accessing a property that does not exist on the object directly - many
            # uninstall registry keys have no DisplayName or UninstallString value.
            # Casting to [string] is not sufficient; the property must exist first.
            if (-not $props.PSObject.Properties['DisplayName'])     { continue }
            if (-not $props.PSObject.Properties['UninstallString']) { continue }

            $displayName     = [string]$props.DisplayName
            $uninstallString = [string]$props.UninstallString

            if ([string]::IsNullOrWhiteSpace($displayName))     { continue }
            if ([string]::IsNullOrWhiteSpace($uninstallString)) { continue }

            if ($uninstallString -match 'ClickToRun') { continue }

            $isMsi = ($uninstallString -match 'msiexec') -or
                     ($key.PSChildName -match $guidPattern)
            if (-not $isMsi) { continue }

            $matched = $false
            foreach ($pattern in $script:MSIDisplayNamePatterns) {
                if ($displayName -match $pattern) { $matched = $true; break }
            }
            if (-not $matched) { continue }

            if ($key.PSChildName -match $guidPattern) {
                $productCode = $key.PSChildName
            }
            elseif ($uninstallString -match $guidSearch) {
                $productCode = $Matches[0]
            }
            else {
                continue
            }

            if (-not $seenCodes.Add($productCode)) { continue }

            [void]$found.Add([PSCustomObject]@{
                ProductCode = $productCode
                DisplayName = $displayName
            })
        }
    }

    # Fail closed: any unreadable key during the scan means we cannot guarantee
    # the scan was complete. The key names are already in the error log.
    if ($unreadableKeys.Count -gt 0) {
        throw ((
            '{0} uninstall registry key(s) could not be read during MSI scan. ' +
            'Failing closed - cannot confirm whether any are Office-related. ' +
            'See error log: {1}. Offending keys: {2}.'
        ) -f
            $unreadableKeys.Count,
            (Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName),
            ($unreadableKeys -join ', '))
    }

    return $found.ToArray()
}


function Invoke-RemoveMSIOffice {
    <#
        Removes all provided MSI Office entries.
        On the first reboot-required exit code (3010 or 1641), calls
        Exit-RebootRequired immediately - remaining entries in the batch are
        NOT processed. Continuing MSI removals after a reboot-required signal
        makes state less predictable and contradicts the package's design.
        Throws on unexpected exit codes.
        Returns when the batch completes with no reboot needed.
    #>
    # Simple function - no [Parameter()] attributes. See Invoke-NativeProcess for rationale.
    param(
        [object[]]$Entries
    )

    $msiExec = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'

    foreach ($entry in $Entries) {
        $arguments = '/x "{0}" /qn /norestart REBOOT=ReallySuppress' -f $entry.ProductCode

        $exitCode = Invoke-NativeProcess `
            -FilePath       $msiExec `
            -Arguments      $arguments `
            -TimeoutSeconds $script:MSITimeoutSeconds

        if ($script:MSISuccessExitCodes -notcontains $exitCode) {
            throw ('msiexec removal of ''{0}'' ({1}) exited with code {2}.' -f $entry.DisplayName, $entry.ProductCode, $exitCode)
        }

        if ($exitCode -in @(3010, 1641)) {
            # Immediate exit - do not continue processing the remaining MSI batch.
            Exit-RebootRequired
        }
    }
}


# ---------------------------------------------------------------------------
# Type 4 - Standalone OneDrive (machine-wide Program Files installs)
# ---------------------------------------------------------------------------

function Get-OneDriveInstalledBinaryPath {
    <#
        Returns the path of the OneDrive application binary if a machine-wide
        installation is detected, or $null if not installed.

        Detection uses the application binary (OneDrive.exe), NOT the
        installer stub (OneDriveSetup.exe). The installer stub exists as a
        Windows built-in bootstrapper in System32/SysWOW64 on virtually all
        Windows 10/11 machines and is not a reliable installed-state signal.

        The returned path is used by Invoke-RemoveOneDrive to identify the
        machine-wide install root. The actual OneDriveSetup.exe is normally in a
        versioned subfolder, and the registered uninstall command is preferred.
    #>

    foreach ($path in $script:OneDriveAppBinaryCandidates) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return $null
}


function Split-OneDriveUninstallString {
    <#
        Parses a registered OneDrive UninstallString into FilePath + Arguments.
        Handles the normal quoted path form:
          "C:\Program Files\Microsoft OneDrive\<version>\OneDriveSetup.exe" /uninstall /allusers
        Returns $null if no executable path can be extracted.
    #>
    param(
        [string]$UninstallString
    )

    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        return $null
    }

    $trimmed   = $UninstallString.Trim()
    $filePath  = $null
    $arguments = ''

    if ($trimmed.StartsWith('"')) {
        $endQuote = $trimmed.IndexOf('"', 1)
        if ($endQuote -le 1) {
            return $null
        }

        $filePath = $trimmed.Substring(1, ($endQuote - 1))

        if ($trimmed.Length -gt ($endQuote + 1)) {
            $arguments = $trimmed.Substring($endQuote + 1).Trim()
        }
    }
    elseif ($trimmed -match '(?i)^(.+?\.exe)(.*)$') {
        $filePath  = $Matches[1].Trim()
        $arguments = $Matches[2].Trim()
    }

    if ([string]::IsNullOrWhiteSpace($filePath)) {
        return $null
    }

    return [PSCustomObject]@{
        FilePath  = $filePath
        Arguments = $arguments
    }
}


function Get-OneDriveUninstallCommand {
    <#
        Resolves the OneDriveSetup.exe command used to remove a per-machine
        OneDrive install.

        Resolution order:
          1. HKLM uninstall registry entry, which points to the current versioned
             OneDriveSetup.exe path on modern per-machine installs.
          2. OneDriveSetup.exe beside OneDrive.exe, for older/atypical layouts.
          3. Newest versioned OneDriveSetup.exe under the detected install root.

        Returns an object with FilePath, Arguments, and Source, or $null if no
        usable uninstaller can be found.
    #>
    param(
        [string]$BinaryPath
    )

    $defaultArguments = '/uninstall /allusers'
    $registryKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
    )

    foreach ($key in $registryKeys) {
        try {
            if (-not (Test-Path -LiteralPath $key)) {
                continue
            }

            $props = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            if (-not $props.PSObject.Properties['UninstallString']) {
                continue
            }

            $parsed = Split-OneDriveUninstallString -UninstallString ([string]$props.UninstallString)
            if ($null -eq $parsed) {
                continue
            }

            if (-not (Test-Path -LiteralPath $parsed.FilePath -PathType Leaf)) {
                continue
            }

            $arguments = $parsed.Arguments
            if ([string]::IsNullOrWhiteSpace($arguments)) {
                $arguments = $defaultArguments
            }

            return [PSCustomObject]@{
                FilePath  = $parsed.FilePath
                Arguments = $arguments
                Source    = $key
            }
        }
        catch {
            Write-ErrorLog -Message ('OneDrive uninstall registry key ''{0}'' could not be read. Falling back to install-root search: {1}' -f $key, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
        }
    }

    if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
        return $null
    }

    $installRoot = [System.IO.Path]::GetDirectoryName($BinaryPath)
    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        return $null
    }

    $sameDirectorySetup = Join-Path -Path $installRoot -ChildPath 'OneDriveSetup.exe'
    if (Test-Path -LiteralPath $sameDirectorySetup -PathType Leaf) {
        return [PSCustomObject]@{
            FilePath  = $sameDirectorySetup
            Arguments = $defaultArguments
            Source    = 'InstallRoot'
        }
    }

    $versionedSetups = @(
        Get-ChildItem -LiteralPath $installRoot `
            -Filter 'OneDriveSetup.exe' `
            -Recurse `
            -File `
            -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending
    )

    foreach ($setup in $versionedSetups) {
        if (Test-Path -LiteralPath $setup.FullName -PathType Leaf) {
            return [PSCustomObject]@{
                FilePath  = $setup.FullName
                Arguments = $defaultArguments
                Source    = 'VersionedInstallRoot'
            }
        }
    }

    return $null
}


function Invoke-RemoveOneDrive {
    <#
        Stops OneDrive processes, runs the resolved installer with /uninstall,
        and verifies removal by re-checking the application binary.
        Returns $false - OneDrive removal does not produce reboot exit codes.
        Throws if the uninstaller exits with an unexpected code, or if the
        application binary is still present after a reported-success exit.

        The uninstaller is resolved from the registered uninstall command first,
        then from the detected install root. Modern per-machine OneDrive installs
        normally place OneDriveSetup.exe in a versioned child folder, not beside
        OneDrive.exe.
    #>

    $binaryPath = Get-OneDriveInstalledBinaryPath

    if ($null -eq $binaryPath) {
        # Binary gone between the detection check and now (race or already removed).
        return $false
    }

    $uninstaller = Get-OneDriveUninstallCommand -BinaryPath $binaryPath

    if ($null -eq $uninstaller) {
        throw (
            'OneDrive binary present at ''{0}'' but no registered or versioned OneDriveSetup.exe uninstaller could be found. Manual removal may be required.' -f
            $binaryPath
        )
    }

    # Kill OneDrive processes immediately before uninstalling to release locks.
    # Stop-OfficeProcesses may have already run this iteration, but OneDrive
    # can restart itself. Kill again immediately before the uninstall call.
    foreach ($procName in @('OneDrive', 'OneDriveSetup')) {
        try {
            $null = & "$env:SystemRoot\System32\taskkill.exe" /IM "$procName.exe" /F 2>&1
        }
        catch { }
    }

    Start-Sleep -Seconds 3

    $exitCode = Invoke-NativeProcess `
        -FilePath       $uninstaller.FilePath `
        -Arguments      $uninstaller.Arguments `
        -TimeoutSeconds $script:OneDriveTimeoutSeconds

    if ($script:OneDriveSuccessExitCodes -notcontains $exitCode) {
        throw ('OneDrive uninstaller at ''{0}'' ({1}) exited with unexpected code {2}.' -f $uninstaller.FilePath, $uninstaller.Source, $exitCode)
    }

    # Post-removal verification: confirm the application binary is gone.
    # If still present, the uninstaller reported success without actually removing it.
    if ($null -ne (Get-OneDriveInstalledBinaryPath)) {
        throw (
            'OneDrive uninstaller exited {0} but OneDrive.exe is still present. Removal may require a reboot or manual intervention.' -f
            $exitCode
        )
    }

    return $false
}


# ==========================================================================
# MAIN
# ==========================================================================

try {
    # Pre-create the log root as the very first operation so the folder exists
    # for any Exit-Failure call that follows - including the 64-bit guard, the
    # AppXOnly path, and the package-file checks. Write-ErrorLog also creates it
    # on demand, but having it guaranteed here means ODT diagnostic output
    # (written directly to this folder) is never lost, even on a clean run where
    # Write-ErrorLog is never called.
    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
    }
    catch {
        # Cannot log the failure - the log folder itself cannot be created.
        # Write to stderr so the error is visible in IME diagnostic captures,
        # then exit 1 so Intune retries.
        try { [Console]::Error.WriteLine('Cannot create log folder ''{0}''' -f $script:LogRoot) } catch { }
        exit 1
    }

    # 64-bit process guard. AppX cmdlets crash a 32-bit PS host silently (P1).
    # This must use SysNative in the portal install command. Fail fast with a
    # clear message if the wrong host was used.
    if (-not [Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message 'This script requires 64-bit PowerShell. Use %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe in the Intune portal install command.' -Category 'Intune'
    }

    # -AppXOnly execution path - child-process mode.
    # Spawned by the main loop (below) to run AppX removal with a hard timeout.
    # AppX cmdlets have no native timeout; running them in a bounded child process
    # matches the timeout guarantee that Invoke-NativeProcess provides for ODT,
    # msiexec, and OneDriveSetup. The child runs the same script with this switch,
    # performs only AppX work, and exits:
    #   0 - all packages fully removed (clean)
    #   1 - genuine failure (throw from Invoke-RemoveAppXOffice)
    #   2 - protected packages remain (Access Denied on provisioned removal),
    #       but nothing more can be done; parent uses this to stop re-triggering
    #       AppX detection in subsequent iterations.
    if ($AppXOnly) {
        try {
            $hasProtected = Invoke-RemoveAppXOffice
            if ($hasProtected) {
                exit 2
            }
            exit 0
        }
        catch {
            $summary = Get-ExceptionSummary -ErrorRecord $_
            Exit-Failure -Code 1 -Message ('AppX child process failed: {0}' -f $summary) -Category 'App'
        }
    }

    # ---- Normal (non-AppXOnly) execution path ----

    $scriptRoot = Get-ScriptRoot

    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Exit-Failure -Code 1 -Message 'Cannot resolve script directory. Run as a saved .ps1 file from disk.' -Category 'Intune'
    }

    $setupExePath  = Join-Path -Path $scriptRoot -ChildPath $script:SetupExeName
    $removeXmlPath = Join-Path -Path $scriptRoot -ChildPath $script:RemoveXmlName

    if (-not (Test-Path -LiteralPath $setupExePath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('setup.exe not found at ''{0}''. Verify the package.' -f $setupExePath) -Category 'Intune'
    }

    if (-not (Test-Path -LiteralPath $removeXmlPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Removal XML not found at ''{0}''. Verify the package.' -f $removeXmlPath) -Category 'Intune'
    }

    # Verify script path is resolvable before the loop - required to spawn the
    # AppX child process. $PSCommandPath is set by PowerShell when run as a file.
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Exit-Failure -Code 1 -Message 'Cannot resolve $PSCommandPath. AppX child process cannot be spawned. Run as a saved .ps1 file from disk.' -Category 'Intune'
    }

    # 64-bit PowerShell path for spawning the AppX child process.
    # From a 64-bit process, System32 is the real System32 (no WOW64 redirection),
    # so this resolves to the 64-bit host. SysNative is a 32-bit-process-only alias
    # and does not exist from a 64-bit process.
    $ps64 = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'

    $startTime = [datetime]::UtcNow
    $iteration = 0

    while ($true) {
        $iteration++

        if ($iteration -gt $script:MaxIterations) {
            Exit-Failure -Code 1 -Message ('Exceeded {0} iterations without reaching a clean state. Check {1} for prior errors.' -f $script:MaxIterations, (Join-Path $script:LogRoot $script:LogFileName)) -Category 'App'
        }

        # Baseline timing check at the top of the loop.
        # Each type recomputes elapsed/remaining at its own check point (below)
        # to avoid acting on stale values after detection or enumeration work.
        $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
        $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds

        if ($remainingSeconds -lt $script:BudgetBufferSeconds) {
            Exit-Failure -Code 1 -Message ('Runtime budget exhausted after {0} seconds ({1} iterations). Remaining: {2} s.' -f $elapsedSeconds, ($iteration - 1), $remainingSeconds) -Category 'App'
        }

        # Preflight: terminate known Office, Teams, Outlook, and OneDrive processes
        # before scanning and removing. Gated by $script:KillOfficeProcesses -
        # set to $false if deploying to live devices where unsaved work loss is
        # unacceptable. See configuration section for details.
        if ($script:KillOfficeProcesses) { Stop-OfficeProcesses }

        # --- Type 1: Click-to-Run ---
        if (Test-C2RInstalled) {
            # Recompute timing immediately before the budget check.
            $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
            $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds
            Assert-BudgetSufficient -TypeName 'C2R' -EstimatedCostSeconds $script:ODTTimeoutSeconds -RemainingSeconds $remainingSeconds -ElapsedSeconds $elapsedSeconds

            try {
                $reboot = Invoke-RemoveC2R -SetupExePath $setupExePath -RemoveXmlPath $removeXmlPath
            }
            catch {
                $summary = Get-ExceptionSummary -ErrorRecord $_
                Exit-Failure -Code 1 -Message ('Iteration {0} - C2R removal failed. {1}' -f $iteration, $summary) -Category 'App'
            }

            if ($reboot) { Exit-RebootRequired }
            continue
        }

        # --- Type 2: AppX / Microsoft Store ---
        # AppX removal runs in a bounded 64-bit child process. AppX cmdlets have no
        # native timeout; the child-process pattern gives the budget guard the same
        # hard enforcement it has for ODT, msiexec, and OneDriveSetup.
        # If the child exits 2, the parent attempts DISM and requires a clean
        # provisioned-package re-query before continuing. The marker is never
        # written over a known dirty AppX provisioned state.
        if (Test-AppXOfficeInstalled) {
            # Recompute timing - AppX detection (Get-AppxPackage enumeration) can
            # take noticeable time, so the top-of-loop values may already be stale.
            $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
            $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds
            Assert-BudgetSufficient -TypeName 'AppX' -EstimatedCostSeconds $script:AppXTimeoutSeconds -RemainingSeconds $remainingSeconds -ElapsedSeconds $elapsedSeconds

            $appxArgs = '-ExecutionPolicy Bypass -NoProfile -NonInteractive -File "{0}" -AppXOnly' -f $PSCommandPath

            try {
                $appxExitCode = Invoke-NativeProcess `
                    -FilePath       $ps64 `
                    -Arguments      $appxArgs `
                    -TimeoutSeconds $script:AppXTimeoutSeconds
            }
            catch {
                $summary = Get-ExceptionSummary -ErrorRecord $_
                Exit-Failure -Code 1 -Message ('Iteration {0} - AppX child process failed. {1}' -f $iteration, $summary) -Category 'App'
            }

            if ($appxExitCode -eq 2) {
                # Child removed all it could but one or more provisioned packages were
                # Access Denied (protected system components). Attempt DISM removal,
                # which retains authority over provisioned packages the AppX API cannot
                # touch in SYSTEM context. Fail the run if DISM cannot prove cleanup.
                Write-ErrorLog -Message ('Iteration {0} - AppX child exited 2: protected provisioned packages remain. Attempting DISM removal pass.' -f $iteration) -Category 'App'

                $dismPackageCount = 0
                try {
                    $dismPackageCount = @(Get-AppXOfficeProvisionedPackages).Count
                }
                catch {
                    $summary = Get-ExceptionSummary -ErrorRecord $_
                    Exit-Failure -Code 1 -Message ('Iteration {0} - DISM budget package query failed. {1}' -f $iteration, $summary) -Category 'App'
                }

                if ($dismPackageCount -gt 0) {
                    $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
                    $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds
                    $dismEstimate     = $dismPackageCount * $script:DismTimeoutSeconds
                    Assert-BudgetSufficient -TypeName 'DISM AppX' -EstimatedCostSeconds $dismEstimate -RemainingSeconds $remainingSeconds -ElapsedSeconds $elapsedSeconds
                }

                $dismClean = Invoke-DismRemoveProtectedProvisionedPackages
                if (-not $dismClean) {
                    Exit-Failure -Code 1 -Message ('Iteration {0} - DISM could not remove all targeted provisioned AppX packages. See {1} for package details.' -f $iteration, (Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName)) -Category 'App'
                }

                continue
            }

            if ($appxExitCode -ne 0) {
                Exit-Failure -Code 1 -Message ('Iteration {0} - AppX child process exited {1}. See error log for details.' -f $iteration, $appxExitCode) -Category 'App'
            }

            continue
        }

        # --- Type 3: MSI-based ---
        # Fetch entries once and reuse for both budget estimation and removal.
        # Get-MSIOfficeEntries throws (fails closed) if any registry key is unreadable.
        try {
            # @() ensures .Count is safe if exactly one MSI entry is returned (scalar unwrap - see Test-AppXOfficeInstalled).
            $msiEntries = @(Get-MSIOfficeEntries)
        }
        catch {
            $summary = Get-ExceptionSummary -ErrorRecord $_
            Exit-Failure -Code 1 -Message ('Iteration {0} - MSI registry scan failed. {1}' -f $iteration, $summary) -Category 'System'
        }

        if ($msiEntries.Count -gt 0) {
            # Recompute timing after the registry scan - enumeration across large
            # uninstall hives can take time, so values from before the scan are stale.
            $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
            $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds
            $msiEstimate      = $msiEntries.Count * $script:MSITimeoutSeconds
            Assert-BudgetSufficient -TypeName 'MSI' -EstimatedCostSeconds $msiEstimate -RemainingSeconds $remainingSeconds -ElapsedSeconds $elapsedSeconds

            try {
                # Invoke-RemoveMSIOffice calls Exit-RebootRequired directly on the
                # first 3010/1641 - it does not return in that case. If it returns
                # normally, the batch completed with no reboot needed.
                Invoke-RemoveMSIOffice -Entries $msiEntries
            }
            catch {
                $summary = Get-ExceptionSummary -ErrorRecord $_
                Exit-Failure -Code 1 -Message ('Iteration {0} - MSI removal failed. {1}' -f $iteration, $summary) -Category 'App'
            }

            continue
        }

        # --- Type 4: Standalone OneDrive ---
        if ($null -ne (Get-OneDriveInstalledBinaryPath)) {
            # Recompute timing - OneDrive detection follows all three prior checks
            # and may be reached after noticeable elapsed work within this iteration.
            $elapsedSeconds   = [int]([datetime]::UtcNow - $startTime).TotalSeconds
            $remainingSeconds = $script:RuntimeDeadlineSeconds - $elapsedSeconds
            Assert-BudgetSufficient -TypeName 'OneDrive' -EstimatedCostSeconds $script:OneDriveTimeoutSeconds -RemainingSeconds $remainingSeconds -ElapsedSeconds $elapsedSeconds

            try {
                $reboot = Invoke-RemoveOneDrive
            }
            catch {
                $summary = Get-ExceptionSummary -ErrorRecord $_
                Exit-Failure -Code 1 -Message ('Iteration {0} - OneDrive removal failed. {1}' -f $iteration, $summary) -Category 'App'
            }

            if ($reboot) { Exit-RebootRequired }
            continue
        }

        # All four types absent on the same pass - clean state confirmed.
        break
    }

    # Write the version-stamped completion marker.
    # Only reached on a clean pass with no reboot needed - marker is valid.
    # Marker write failure is hard exit 1 (P23 - without marker Intune retries forever).
    try {
        $markerDir = [System.IO.Path]::GetDirectoryName($script:MarkerFile)
        [void][System.IO.Directory]::CreateDirectory($markerDir)

        $elapsed     = [int]([datetime]::UtcNow - $startTime).TotalSeconds
        $markerLines = @(
            'ScriptVersion={0}'  -f $script:AppVersion,
            'AppName={0}'        -f $script:AppName,
            'Iterations={0}'     -f $iteration,
            'ElapsedSeconds={0}' -f $elapsed,
            'Timestamp={0}'      -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        )
        $markerContent = ($markerLines -join [System.Environment]::NewLine) + [System.Environment]::NewLine

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($script:MarkerFile, $markerContent, $utf8NoBom)
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Exit-Failure -Code 1 -Message ('All types removed but marker could not be written to ''{0}'': {1}' -f $script:MarkerFile, $summary) -Category 'System'
    }

    exit 0
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category 'System'
}
