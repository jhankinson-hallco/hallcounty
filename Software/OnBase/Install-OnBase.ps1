#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Installs OnBase Client 16 (Full) by running the site's existing
    OnBase16InstallFULL batch, adapted to run from the Intune package.

.DESCRIPTION
    Intune Win32 App installation script. Thin wrapper around
    Auto\OnBase16InstallFULL-Intune.bat - the install LOGIC is exactly the
    site's existing PDQ batch (Auto\OnBase16InstallFULL.bat), not
    reimplemented here. The only changes made to produce the "-Intune" batch
    variants were:
      1. \\hallcounty\filestore\... UNC paths replaced with %~dp0-relative
         paths, since Intune Win32 apps must run entirely from files bundled
         in the .intunewin package (see shared AGENTS.md Channel Boundaries).
      2. The two msiexec calls that were missing /q in the PDQ original
         (Hyland Desktop.msi, Hyland Unity Client.msi) now have it - without
         it, an unattended SYSTEM-context run would hang indefinitely waiting
         for UI that never appears.
    See Auto\OnBase16InstallFULL-Intune.bat's own header comment for full
    detail. The PDQ-original batch files are untouched, in the Auto\ folder.

    This script lives at the project root (Software\OnBase\), one level
    above Auto\, which holds the batch files and all their referenced
    payload (MSIs, transforms, the raw-copied client folder, etc.). All
    batch/payload references below are Auto\-relative for that reason.

    The batch itself performs (in order): kill any running OnBase 13/16
    processes and remove OnBase 13 (OB13Uninstall-Intune.bat), install the
    VC++ 2013 x86 runtime prerequisite (confirmed from the bundled
    installer's own signed version metadata - an earlier draft of this
    project incorrectly called this VC++ 2010), install SQL Native Client
    ODBC (x86 and x64), import ODBC registry settings, install the Hyland
    Desktop and Hyland Unity Client MSI products, copy the OnBase Client 16
    application folder to Program Files, deploy the Public Desktop shortcut
    and onbase32.ini, unblock obclnt32.exe, and import the desktop server
    location registry file.

    IMPORTANT: the batch has no internal error checking between steps (this
    was true of the PDQ original too and was not changed here, per the
    "don't reinvent the install logic" scope of this work) - its own exit
    code is not a reliable pass/fail signal on its own. This script treats
    the batch's exit code as diagnostic only and determines real success by
    directly verifying part of the installed end state afterward: the
    OnBase Client 16 executable exists, both Hyland MSI products are
    registered by their known (bundled-MSI-derived) product codes, and the
    desktop shortcut exists - the same evidence Detect.ps1 checks. This is
    NOT a complete verification of every step the batch performs (the VC++
    prerequisite, SQL Native Client, and ODBC/registry imports are not
    checked) - see project AI-Audit-Handoff.md for the full, still-open list
    of gaps in this verification.

    After a successful install, this script also writes a DPI compatibility
    flag for the raw-copied client executable (AppCompatFlags\Layers =
    "~ GDIDPISCALING DPIUNAWARE"). This is a confirmed fix (live-tested
    2026-08-19, not theoretical) for a rendering regression that
    clips/shifts the Application Enabler login dialog off-center - the
    dialog itself is compiled into the client's own DLLs
    (endocdst.dll/mzengrc.dll), not any editable local file. CONFIRMED VIA A
    CONTROLLED LIVE TEST (same machine, same value, hive as the only
    variable) that this AppCompat shim only works from HKCU for this
    application - an identical HKLM entry does nothing.

    This fix is applied two ways: (1) directly to every EXISTING real user
    profile already on the device (if any), writing into the already-loaded
    hive for anyone currently logged in, or mounting their NTUSER.DAT
    temporarily for anyone who is not - immediate coverage at install time,
    and (2) a SYSTEM-context scheduled task, registered here and by the PDQ
    counterpart, that fires at every logon (any user) and writes the value
    directly into the logging-on user's own HKCU via
    Set-OnBaseDpiCompatibilityLogon.ps1 - covering both White Glove/Autopilot
    (no profile exists at install time) and any future new profile on an
    already-enrolled device. A THIRD approach - writing into the Default
    User hive so new profiles inherit the value automatically on creation -
    was used from v1.1.4 through v1.1.8 and is CONFIRMED NOT TO WORK: Jeremy
    tested this on multiple fresh-imaged endpoints and the fix never reached
    new profiles, and separately confirmed that a PDQ run against an
    already-provisioned device (writing to the Default hive there too)
    showed the identical failure for any profile created after that PDQ
    run - ruling out both an IME-token-restriction theory and an
    OOBE/White-Glove timing theory, since PDQ runs in neither context. See
    AI-Audit-Decisions.md for the full root-cause evidence chain. An empty
    existing-profile list (the normal case on a fresh device with no
    profile yet) is not an error - every write is best-effort and
    per-profile: one failure or one missing profile never fails the install
    or blocks any other profile.

    After a successful install, this script also copies the packaged
    "Hyland Software" folder's contents to C:\ProgramData\Hyland Software,
    overwriting the batch's own onbase32.ini copy (from
    Auto\OnBase Client 16\onbase32.ini). That batch-bundled copy was found
    to contain stale, captured session/UI state (a hardcoded screen
    resolution, saved toolbar docking positions, partial login username
    fragments) rather than a clean install template - confirmed via direct
    comparison against the live file on a real endpoint. The packaged
    replacement was confirmed to contain no machine-specific information
    before being added here (blank Logon/company fields, generic default
    paths) - see AI-Audit-Decisions.md. Best-effort: failure is logged but
    does not fail the install, since the batch's own copy still leaves a
    functional (if imperfect) config file in place either way.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_OnBase_Install.txt
    (IME-rooted per the current shop standard - C:\IntuneAppLogs is the
    legacy fallback path). The batch's own msiexec /lv logs land in
    C:\ob_install_logs\ (that location is the site's existing convention,
    unchanged here).

    Exit Codes:
        0 = Success (batch ran and the checked portion of the installed end
            state was verified)
        1 = Failure (batch failed to launch, or verification found missing
            evidence; Intune will retry)

.NOTES
    Version:        1.1.9
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Install OnBase Client 16 (Full) via the site's existing install batch, adapted for Intune

    CHANGE LOG
    Change: 17/08/2026 - Initial release as Install-OnBase16.ps1, located in
                         Auto\ -- ver. 1.0.0
    Change: 18/08/2026 - Relocated to the project root (Software\OnBase\) and
                         renamed to Install-OnBase.ps1; batch path reference
                         updated to Auto\OnBase16InstallFULL-Intune.bat;
                         $script:AppName shortened to 'OnBase' (log files are
                         now OnBase_Install.txt, matching the new script
                         name); corrected prerequisite documentation from
                         VC++ 2010 to VC++ 2013 (proven from the bundled
                         installer's own signed version metadata - see
                         AI-Audit-Decisions.md); removed the diagnostic
                         Write-ErrorLog call that fired unconditionally on
                         every run, which contradicted this script's own
                         documented error-only logging -- ver. 1.1.0
    Change: 18/08/2026 - Documentation only: recorded that the VC++ 2013 x86
                         prerequisite is intentionally covered by a separate,
                         required Intune Win32 app dependency (Jeremy's
                         direction), not by this app's own verification -
                         see the Dependency note under INTUNE CONFIGURATION.
                         No detection/verification logic changed - it never
                         checked VC++ to begin with -- ver. 1.1.1
    Change: 19/08/2026 - Added Set-OnBaseDpiCompatibility: writes an HKLM
                         AppCompatFlags\Layers entry for the raw-copied
                         client exe after a successful install, fixing a
                         confirmed Windows 11 rendering regression that
                         clips/shifts the Application Enabler login dialog
                         (root cause and fix live-tested 2026-08-19 - not
                         reproducible on Windows 10, not related to any
                         local file). HKLM-scoped so it applies during
                         White Glove/Autopilot and to every future user of
                         the device. Best-effort: logged on failure, does
                         not fail the install -- ver. 1.1.2
    Change: 19/08/2026 - Added Copy-OnBaseConfigFolder: copies the packaged
                         "Hyland Software" folder's contents to
                         C:\ProgramData\Hyland Software after a successful
                         install, overwriting the batch's own onbase32.ini
                         copy. Confirmed via direct comparison that the
                         batch's bundled onbase32.ini (Auto\OnBase Client
                         16\onbase32.ini) contains stale captured session/UI
                         state, not a clean template, and confirmed the
                         packaged replacement contains no machine-specific
                         information before adding this step. Best-effort:
                         logged on failure, does not fail the install --
                         ver. 1.1.3
    Change: 19/08/2026 - CORRECTED v1.1.2: Set-OnBaseDpiCompatibility no
                         longer writes an HKLM AppCompatFlags\Layers entry.
                         A controlled live test (same machine, same value,
                         only the hive changed) proved the HKLM entry does
                         nothing for this application - only HKCU was ever
                         confirmed to work. Now writes the same value into
                         the Default User hive (C:\Users\Default\NTUSER.DAT)
                         instead, using the shop's established mount/
                         unmount pattern (reg.exe, not the PS Registry
                         provider), so every NEW profile inherits it
                         automatically - covering White Glove/Autopilot,
                         which was the original requirement HKLM was
                         (incorrectly) chosen to satisfy. Does NOT
                         retroactively cover profiles that already existed
                         on a device before this install ran - open gap,
                         see AI-Audit-Handoff.md -- ver. 1.1.4
    Change: 19/08/2026 - Extended Set-OnBaseDpiCompatibility to also loop
                         over every EXISTING real user profile on the
                         device (Get-RealUserProfiles, filtered to
                         S-1-5-21-*/S-1-12-1-* SIDs), writing directly into
                         the already-loaded hive for anyone currently
                         logged in or mounting NTUSER.DAT temporarily for
                         anyone who is not - the Default User hive from
                         v1.1.4 only ever covered future profiles, which
                         would miss existing users if this app is ever
                         assigned to an already-enrolled device rather than
                         a fresh White Glove/Autopilot enrollment. An empty
                         existing-profile list (normal on a fresh device)
                         is explicitly not an error - each profile write is
                         independent and best-effort, matching the parallel
                         Software\OnBase\PDQ\Set-OnBaseDpiCompatibility-PDQ.ps1
                         script's same logic, built first for PDQ's
                         already-provisioned-device use case -- ver. 1.1.5
    Change: 20/08/2026 - Reordered MAIN: Copy-OnBaseConfigFolder now runs
                         BEFORE Set-OnBaseDpiCompatibility (was after) -
                         Jeremy requested this after a fresh-imaged
                         endpoint installed OnBase successfully but did not
                         pick up the DPI fix, while running the PDQ script
                         after login confirmed the fix mechanism itself
                         works. No confirmed technical link between the two
                         steps was identified (different registry hive vs.
                         different filesystem path, no shared resource) -
                         this is a precautionary reorder, not a proven fix;
                         the real cause remains open, see
                         AI-Audit-Handoff.md. Also renamed the
                         Set-OnBaseDpiCompatibilityForExistingProfile
                         parameter from $Profile to $UserProfile (in both
                         this script and the parallel PDQ script) - $Profile
                         shadows PowerShell's own automatic $PROFILE
                         variable, flagged by IDE lint -- ver. 1.1.6
    Change: 20/08/2026 - CONFIRMED ROOT CAUSE via a real install log from a
                         fresh-imaged endpoint: Set-OnBaseDpiCompatibility's
                         reg.exe load/add calls were failing with
                         "ERROR: The parameter is incorrect." on every
                         attempt (Default hive and all existing profiles) -
                         IME's SYSTEM-context execution leaves
                         SeBackupPrivilege/SeRestorePrivilege present but
                         not enabled on the process token, which reg.exe
                         surfaces as this error rather than a plain
                         privilege-denied message. Added
                         Enable-HiveMountPrivileges (P/Invoke
                         AdjustTokenPrivileges) called once before any hive
                         mount is attempted, explicitly enabling both
                         privileges for the rest of the process. Confirmed
                         via isolated testing that the underlying Win32 call
                         correctly distinguishes "privilege absent"
                         (ERROR_NOT_ALL_ASSIGNED, 1300) from success:
                         proven on this project's own unelevated session
                         (both privileges correctly report 1300, as
                         expected for a standard user token) - the actual
                         SYSTEM-context success path still requires
                         confirmation on a real endpoint -- ver. 1.1.7
    Change: 20/08/2026 - Moved script-authored logging from the legacy
                         C:\IntuneAppLogs to the current IME-rooted
                         standard, C:\ProgramData\Microsoft\
                         IntuneManagementExtension\Logs, and renamed the
                         log file from OnBase_Install.txt to
                         APP_OnBase_Install.txt to match the shop's
                         current naming convention (see the
                         machine-specific AGENTS.md/reference_intune_paths.md
                         - C:\IntuneAppLogs is now documented as a legacy
                         fallback path only) -- ver. 1.1.8
    Change: 21/08/2026 - REPLACED the Default User hive injection
                         (Set-OnBaseDpiCompatibilityForDefaultUser, v1.1.4-
                         v1.1.8) with a SYSTEM-context scheduled task
                         (Register-OnBaseDpiCompatibilityLogonTask). Jeremy
                         confirmed on multiple fresh-imaged endpoints that
                         the Default-hive fix never reached new profiles,
                         and separately confirmed that a PDQ run against an
                         already-provisioned device showed the identical
                         failure for any profile created after that PDQ run
                         - ruling out both the IME-token-restriction theory
                         and an OOBE/White-Glove timing theory, since PDQ
                         runs in neither context. The new task fires at
                         every logon (any user, SYSTEM principal - end users
                         have no administrative rights) and writes the
                         compatibility value directly into the logging-on
                         user's own HKCU via the new
                         Set-OnBaseDpiCompatibilityLogon.ps1 helper, staged
                         to C:\ProgramData\Microsoft\
                         IntuneManagementExtension\ScriptFiles\OnBase at
                         install time - reusing the exact HKCU-direct-write
                         mechanism already proven for existing profiles,
                         rather than depending on Default-hive-to-new-
                         profile inheritance. The existing-profile loop
                         (Get-RealUserProfiles /
                         Set-OnBaseDpiCompatibilityForExistingProfile) is
                         unchanged - it still gives immediate coverage at
                         install time; the scheduled task covers every
                         subsequent and future logon. See
                         AI-Audit-Decisions.md for the full evidence chain
                         -- ver. 1.1.9

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-OnBase.ps1
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-OnBase.ps1
      Install behavior: System
      Device restart behavior: No specific action (every install step in the
        batch is run with /norestart / /passive /norestart)
      Detection rule: custom detection script Detect.ps1
        Run script as 32-bit process on 64-bit clients: No
      SysNative is required here for a concrete reason, not just convention:
        this script launches cmd.exe, which inherits the calling process's
        bitness. The batch copies files into the native "C:\Program Files"
        path; if the calling PowerShell (and therefore cmd.exe) were 32-bit,
        WOW64 file redirection would silently send that copy to
        "C:\Program Files (x86)" instead.
      Dependency: per Jeremy's direction (2026-08-18), the VC++ 2013 x86
        prerequisite the batch installs (PreReq\vcredist_x86.exe) is intended
        to be covered by a SEPARATE, required Intune Win32 app dependency
        configured in the portal (Properties > Dependencies), not by this
        app's own detection. Configure that dependency before assigning this
        app. This script's batch still runs the bundled vcredist_x86.exe
        itself regardless (unchanged install logic, per project scope) -
        that is expected to be a harmless no-op repeat install if the
        separate dependency app already satisfied it.

    PDQ COUNTERPART
      PDQ package runs: cmd.exe /s /c ""OnBase16InstallFULL.bat" "
      against the PDQ-original batch (Auto\ folder, untouched). This script
      reproduces the identical cmd.exe invocation pattern against the
      "-Intune" batch variant instead.

    KNOWN RISKS (see project AI-Audit-Handoff.md for full detail - a fresh
    audit on 2026-08-17 found several open findings not yet acted on)
      - The batch has no internal error propagation between steps; this
        script's post-run verification is the real success signal, not the
        batch's raw exit code - but that verification covers only four
        artifacts, not the batch's complete required end state (SQL Native
        Client, ODBC/registry imports, and onbase32.ini are not checked).
        The VC++ 2013 prerequisite is deliberately not part of this
        verification - see the Dependency note above.
      - No preflight verifies the complete new-version payload is present
        and trusted before the batch's destructive OnBase 13 removal step
        runs.
      - Reboot-required results (3010/1641) from any installer inside the
        batch are not captured or propagated - this script always reports
        plain success (0) once its partial verification passes.
      - ob16odbc-Intune.bat imports files literally named ob13x64odbc.reg /
        ob13x86odbc.reg (preserved exactly from the PDQ original - see that
        file's own header comment).
      - Force-killing obunity.exe/DMDesktop.exe/obclnt32.exe has no
        user-notification or grace period.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion = '1.1.9'
$script:AppName       = 'OnBase'

$script:InstallBatchRelativePath = Join-Path -Path 'Auto' -ChildPath 'OnBase16InstallFULL-Intune.bat'
$script:InstallTimeoutSeconds    = 900

$script:ClientExePath = 'C:\Program Files\OnBase Client 16\obclnt32.exe'
$script:ShortcutPath  = 'C:\Users\Public\Desktop\OnBase 16.lnk'

# Confirmed fix (live-tested 2026-08-19) for a rendering regression that
# clips/shifts the AE-mode login dialog (compiled into the client's own
# DLLs, not any local file - see AI-Audit-Decisions.md). CONFIRMED VIA
# CONTROLLED TEST that this AppCompat shim only takes effect from HKCU for
# this application - an identical HKLM entry (same machine, same value) was
# proven NOT to work. Since HKCU cannot be written for a user who does not
# exist yet (White Glove/Autopilot), this is applied via the Default User
# hive instead (Set-OnBaseDpiCompatibility below), which every NEW profile
# inherits automatically on creation - not written to HKLM or HKCU directly.
$script:DpiCompatSubKeyPath      = 'Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$script:DpiCompatLayerValue      = '~ GDIDPISCALING DPIUNAWARE'
$script:TempProfileMountPointBase = 'HKU\OnBaseTempProfile'
$script:RegExePath               = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'

# Default User hive injection (v1.1.4-v1.1.8) is confirmed NOT to work:
# fresh-imaged endpoints never picked up the fix on new profiles, and a PDQ
# run against an already-provisioned device showed the identical failure for
# any profile created after that PDQ run - ruling out an IME-token theory and
# an OOBE/White-Glove timing theory (PDQ runs nowhere near either). Replaced
# with a SYSTEM-context scheduled task that writes directly into each user's
# own HKCU at logon - the same mechanism already proven for existing
# profiles below, just applied at logon time instead of at install time. See
# AI-Audit-Decisions.md for the full evidence chain.
$script:LogonHelperSourceFileName = 'Set-OnBaseDpiCompatibilityLogon.ps1'
$script:LogonHelperFolder         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\OnBase'
$script:LogonHelperPath           = Join-Path -Path $script:LogonHelperFolder -ChildPath $script:LogonHelperSourceFileName
$script:LogonTaskName             = 'Hall County MIS - OnBase DPI Compatibility Logon Fix'

# Confirmed (2026-08-19) to contain no machine-specific information -
# overwrites the batch's own onbase32.ini copy, which was found to carry
# stale captured session/UI state instead of a clean template. See
# AI-Audit-Decisions.md.
$script:ConfigSourceRelativePath = 'Hyland Software'
$script:ConfigDestinationPath    = 'C:\ProgramData\Hyland Software'

# Proven directly from the bundled MSI files' own Property tables
# (WindowsInstaller.Installer COM, ProductCode) on 2026-08-17 - see
# AI-Audit-Decisions.md. Not guessed, not pattern-matched.
$script:DesktopProductCode      = '{DADFAF01-82CE-43D8-8520-3D7D214F9356}'
$script:UnityClientProductCode  = '{18E17873-DC2D-4085-B752-DD127D388EBD}'

$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# IME-rooted per the current shop standard (reference_intune_paths.md /
# AGENTS.md "IME Runtime Paths") - C:\IntuneAppLogs is the legacy fallback,
# not used by new work.
$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Install.txt')

# =============================================================================
# FUNCTIONS
# =============================================================================

# "reg load"/"reg unload" (used by the DPI compatibility fix below) require
# SeBackupPrivilege/SeRestorePrivilege to be ENABLED on the process token,
# not merely present. SYSTEM's token normally holds both, but some
# service/agent-launched execution contexts (confirmed 2026-08-19: IME on a
# real endpoint) leave them present-but-disabled, which reg.exe surfaces as
# "ERROR: The parameter is incorrect." rather than a plain privilege error -
# this is what caused the Default User hive fix to silently fail on a real
# fresh-imaged endpoint despite working when tested via the PDQ script
# against an existing, already-elevated interactive session. See
# AI-Audit-Decisions.md for the evidence.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class OnBaseTokenPrivilege {
    [StructLayout(LayoutKind.Sequential)]
    public struct LUID {
        public uint LowPart;
        public int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public uint PrivilegeCount;
        public LUID Luid;
        public uint Attributes;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out LUID lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, uint BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    private const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
    private const uint TOKEN_QUERY = 0x0008;
    private const uint SE_PRIVILEGE_ENABLED = 0x00000002;
    private const int ERROR_NOT_ALL_ASSIGNED = 1300;

    // Returns 0 on confirmed success, ERROR_NOT_ALL_ASSIGNED (1300) if the
    // privilege is not present in the token at all, or another Win32 error
    // code for any other failure.
    public static int EnablePrivilege(string privilegeName) {
        IntPtr tokenHandle = IntPtr.Zero;
        try {
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out tokenHandle)) {
                return Marshal.GetLastWin32Error();
            }

            LUID luid;
            if (!LookupPrivilegeValue(null, privilegeName, out luid)) {
                return Marshal.GetLastWin32Error();
            }

            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Luid = luid;
            tp.Attributes = SE_PRIVILEGE_ENABLED;

            if (!AdjustTokenPrivileges(tokenHandle, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) {
                return Marshal.GetLastWin32Error();
            }

            int lastError = Marshal.GetLastWin32Error();
            return lastError == ERROR_NOT_ALL_ASSIGNED ? ERROR_NOT_ALL_ASSIGNED : 0;
        }
        finally {
            if (tokenHandle != IntPtr.Zero) {
                CloseHandle(tokenHandle);
            }
        }
    }
}
'@ -ErrorAction SilentlyContinue

function Enable-HiveMountPrivileges {
    # Best-effort: if this fails, the subsequent reg load/unload calls will
    # fail with their own clear error, which is already logged by the
    # caller - this helper itself must never throw.
    foreach ($PrivilegeName in @('SeBackupPrivilege', 'SeRestorePrivilege')) {
        try {
            $Result = [OnBaseTokenPrivilege]::EnablePrivilege($PrivilegeName)
            if ($Result -ne 0) {
                Write-ErrorLog -Message "Could not enable $PrivilegeName (Win32 error $Result) - reg load/unload may fail." -Category 'Compatibility'
            }
        }
        catch {
            Write-ErrorLog -Message "Enable-HiveMountPrivileges failed for $PrivilegeName`: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
        }
    }
}

function Write-ErrorLog {
    # Logging helper must never throw; all I/O uses SilentlyContinue.
    param(
        [string]$Message,
        [string]$Category = 'App'
    )
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = '[{0}] [v{1}] [{2}] {3}' -f $Timestamp, $script:ScriptVersion, $Category, $Message
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Stop-WithFailure {
    param(
        [string]$Message,
        [string]$Category = 'App'
    )
    Write-ErrorLog -Message $Message -Category $Category
    Write-Output $Message
    exit 1
}

function Get-ScriptRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }
    return $null
}

function Test-IsAdministrator {
    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        if ($null -ne $Identity.User -and [string]$Identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $Principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList (,$Identity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
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

function Test-MsiProductRegistered {
    param(
        [string]$ProductCode
    )

    foreach ($RegistryPath in $script:RegistryPaths) {
        $KeyPath = Join-Path -Path $RegistryPath -ChildPath $ProductCode
        if (Test-Path -LiteralPath $KeyPath) {
            return $true
        }
    }

    return $false
}

function Stop-ProcessTree {
    param(
        [int]$ProcessId
    )
    $TaskKillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'
    if (Test-Path -LiteralPath $TaskKillPath -PathType Leaf) {
        try {
            $null = & $TaskKillPath /PID $ProcessId /T /F 2>&1
            if ($LASTEXITCODE -in @(0, 128)) {
                return
            }
        }
        catch { }
    }
    try {
        $Process = [System.Diagnostics.Process]::GetProcessById($ProcessId)
        try {
            $Process.Kill()
            $null = $Process.WaitForExit(5000)
        }
        finally {
            $Process.Dispose()
        }
    }
    catch { }
}

function Invoke-OnBaseInstallBatch {
    param(
        [string]$BatchPath,
        [int]$TimeoutSeconds
    )

    # Reproduces the exact PDQ invocation pattern:
    #   cmd.exe /s /c ""OnBase16InstallFULL.bat" "
    # /s plus the doubled leading quote is the documented cmd.exe technique
    # for correctly handling a quoted path that itself contains spaces.
    $ComSpecPath = if (-not [string]::IsNullOrWhiteSpace($env:ComSpec)) { $env:ComSpec } else { Join-Path -Path $env:SystemRoot -ChildPath 'System32\cmd.exe' }
    $ArgumentString = '/s /c ""{0}" "' -f $BatchPath

    $StartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $ComSpecPath
    $StartInfo.Arguments = $ArgumentString
    $StartInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($BatchPath)
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true

    $Process = New-Object -TypeName System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        $Started = $Process.Start()
        if (-not $Started) {
            throw 'Process.Start() returned False for cmd.exe without throwing.'
        }

        $HasExited = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $HasExited) {
            Stop-ProcessTree -ProcessId $Process.Id
            try { $null = $Process.WaitForExit(5000) } catch { }
            throw ('OnBase install batch timed out after {0} seconds and was terminated.' -f $TimeoutSeconds)
        }

        return [int]$Process.ExitCode
    }
    finally {
        $Process.Dispose()
    }
}

function Test-OnBase16Installed {
    # Returns a single psobject (not a positional tuple) so the result can
    # never be ambiguous across PowerShell's pipeline array-enumeration
    # behavior regardless of how many fields this ever grows to.
    if (-not (Test-Path -LiteralPath $script:ClientExePath -PathType Leaf)) {
        return New-Object -TypeName psobject -Property @{ IsInstalled = $false; Reason = 'OnBase Client 16 executable not found' }
    }
    if (-not (Test-MsiProductRegistered -ProductCode $script:DesktopProductCode)) {
        return New-Object -TypeName psobject -Property @{ IsInstalled = $false; Reason = 'Hyland Desktop MSI product not registered' }
    }
    if (-not (Test-MsiProductRegistered -ProductCode $script:UnityClientProductCode)) {
        return New-Object -TypeName psobject -Property @{ IsInstalled = $false; Reason = 'Hyland Unity Client MSI product not registered' }
    }
    if (-not (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf)) {
        return New-Object -TypeName psobject -Property @{ IsInstalled = $false; Reason = 'Public Desktop shortcut not found' }
    }

    return New-Object -TypeName psobject -Property @{ IsInstalled = $true; Reason = '' }
}

function Set-DpiCompatValueInMountedHive {
    param(
        [string]$MountPoint
    )
    $TargetKey = "$MountPoint\$script:DpiCompatSubKeyPath"
    $AddOutput = & $script:RegExePath add $TargetKey /v $script:ClientExePath /t REG_SZ /d $script:DpiCompatLayerValue /f 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "reg add failed (exit $LASTEXITCODE): $AddOutput"
    }
}

function Register-OnBaseDpiCompatibilityLogonTask {
    param(
        [string]$ScriptRoot
    )
    # Best-effort only: a failure here must not fail the install. Stages the
    # logon-helper script to a persistent IME-rooted location (the .intunewin
    # extraction folder is cleaned up after this script exits, so the
    # scheduled task cannot point at $ScriptRoot directly), then registers a
    # SYSTEM-context scheduled task that fires at every logon (any user) and
    # writes the DPI compatibility value directly into that user's own HKCU -
    # replacing the Default User hive injection this project confirmed does
    # not work. -Force on Register-ScheduledTask makes this idempotent: PDQ
    # registers the identical task name/action, so whichever channel runs
    # last simply refreshes the same task.
    try {
        $SourcePath = Join-Path -Path $ScriptRoot -ChildPath $script:LogonHelperSourceFileName
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "Logon helper script not found in package at '$SourcePath'."
        }

        New-Item -ItemType Directory -Path $script:LogonHelperFolder -Force -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $SourcePath -Destination $script:LogonHelperPath -Force -ErrorAction Stop

        $Action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $script:LogonHelperPath)
        $Trigger   = New-ScheduledTaskTrigger -AtLogOn
        $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $Settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        Register-ScheduledTask -TaskName $script:LogonTaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-ErrorLog -Message "Failed to register the DPI compatibility logon task: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
    }
}

function Get-RealUserProfiles {
    # Returns Sid + ProfileImagePath for genuine local/domain/Azure AD user
    # accounts only - filters out SYSTEM, service, and other well-known
    # SIDs. Returns an empty array (never $null, never throws) when no real
    # user profile exists yet - the expected, normal case during White
    # Glove/Autopilot, where this must not be treated as an error.
    $ProfileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $Results = @()

    foreach ($ProfileKey in @(Get-ChildItem -LiteralPath $ProfileListPath -ErrorAction SilentlyContinue)) {
        $Sid = $ProfileKey.PSChildName
        if ($Sid -notmatch '^S-1-5-21-' -and $Sid -notmatch '^S-1-12-1-') {
            continue
        }

        $ImagePathProperty = Get-ItemProperty -LiteralPath $ProfileKey.PSPath -Name 'ProfileImagePath' -ErrorAction SilentlyContinue
        if ($null -eq $ImagePathProperty -or [string]::IsNullOrWhiteSpace($ImagePathProperty.ProfileImagePath)) {
            continue
        }

        $Results += New-Object -TypeName psobject -Property @{
            Sid              = $Sid
            ProfileImagePath = $ImagePathProperty.ProfileImagePath
        }
    }

    return ,$Results
}

function Set-OnBaseDpiCompatibilityForExistingProfile {
    param(
        [psobject]$UserProfile
    )
    # Best-effort, per-profile: one profile's hive being locked, corrupt, or
    # otherwise unreachable must not block any other profile, and must not
    # fail the install. Parameter deliberately not named $Profile - that
    # shadows PowerShell's own automatic $PROFILE variable.
    $AlreadyLoaded = Test-Path -LiteralPath "Registry::HKEY_USERS\$($UserProfile.Sid)"

    if ($AlreadyLoaded) {
        try {
            Set-DpiCompatValueInMountedHive -MountPoint "HKU\$($UserProfile.Sid)"
        }
        catch {
            Write-ErrorLog -Message "Failed to set DPI compatibility flag for currently-loaded profile '$($UserProfile.ProfileImagePath)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
        }
        return
    }

    $NtUserDatPath = Join-Path -Path $UserProfile.ProfileImagePath -ChildPath 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $NtUserDatPath -PathType Leaf)) {
        return
    }

    $MountPoint = "$script:TempProfileMountPointBase-$($UserProfile.Sid.Substring($UserProfile.Sid.Length - 8))"
    $HiveLoaded = $false
    try {
        & $script:RegExePath unload $MountPoint 2>&1 | Out-Null

        $LoadOutput = & $script:RegExePath load $MountPoint $NtUserDatPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed (exit $LASTEXITCODE): $LoadOutput"
        }
        $HiveLoaded = $true

        Set-DpiCompatValueInMountedHive -MountPoint $MountPoint
    }
    catch {
        Write-ErrorLog -Message "Failed to set DPI compatibility flag for profile '$($UserProfile.ProfileImagePath)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
    }
    finally {
        if ($HiveLoaded) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $UnloadOutput = & $script:RegExePath unload $MountPoint 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog -Message "reg unload warning for profile '$($UserProfile.ProfileImagePath)' (exit $LASTEXITCODE): $UnloadOutput" -Category 'Compatibility'
            }
        }
    }
}

function Set-OnBaseDpiCompatibility {
    param(
        [string]$ScriptRoot
    )
    # Applies the confirmed DPI compatibility fix (see AI-Audit-Decisions.md
    # for the full root-cause evidence chain) to (1) every EXISTING real user
    # profile already on the device, if any, giving immediate coverage
    # without waiting for a future logon, and (2) registers a SYSTEM-context
    # scheduled task (Register-OnBaseDpiCompatibilityLogonTask) that writes
    # the value into each user's own HKCU at every logon - this is what
    # covers White Glove/Autopilot (no profile exists yet at install time)
    # AND any future new profile on an already-enrolled device, since the
    # Default User hive injection this used before v1.1.9 is confirmed not
    # to reach new profiles at all. An empty existing-profile list is the
    # expected, normal outcome on a fresh device, not a failure condition -
    # the foreach loop below simply does nothing in that case.
    #
    # Enable SeBackupPrivilege/SeRestorePrivilege once, up front - covers the
    # existing-profile hive mounts below. Kept even though this specific
    # theory was disproven as the root cause of the original failure (see
    # AI-Audit-Handoff.md) - it is harmless and remains useful diagnostic
    # logging for the existing-profile mount path.
    Enable-HiveMountPrivileges

    Register-OnBaseDpiCompatibilityLogonTask -ScriptRoot $ScriptRoot

    $ExistingProfiles = Get-RealUserProfiles
    foreach ($UserProfile in $ExistingProfiles) {
        Set-OnBaseDpiCompatibilityForExistingProfile -UserProfile $UserProfile
    }
}

function Copy-OnBaseConfigFolder {
    param(
        [string]$ScriptRoot
    )
    # Best-effort only: a failure here must not fail the install - the
    # batch's own onbase32.ini copy still leaves a functional (if
    # imperfect) config file in place either way.
    try {
        $SourcePath = Join-Path -Path $ScriptRoot -ChildPath $script:ConfigSourceRelativePath
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
            Write-ErrorLog -Message "Config source folder not found at '$SourcePath' - skipped." -Category 'Config'
            return
        }
        if (-not (Test-Path -LiteralPath $script:ConfigDestinationPath)) {
            New-Item -ItemType Directory -Path $script:ConfigDestinationPath -Force -ErrorAction Stop | Out-Null
        }
        Get-ChildItem -LiteralPath $SourcePath | Copy-Item -Destination $script:ConfigDestinationPath -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-ErrorLog -Message "Failed to copy config folder to '$($script:ConfigDestinationPath)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Config'
    }
}

# =============================================================================
# MAIN
# =============================================================================

$ScriptRoot = Get-ScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
    Stop-WithFailure -Message 'Unable to resolve script directory. Run this as a saved .ps1 file from disk, not from an unsaved or transient host context.' -Category 'Intune'
}

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -Message 'This installer requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

$BatchPath = Join-Path -Path $ScriptRoot -ChildPath $script:InstallBatchRelativePath
if (-not (Test-Path -LiteralPath $BatchPath -PathType Leaf)) {
    Stop-WithFailure -Message "Install batch not found at '$BatchPath'. Verify the package contains '$($script:InstallBatchRelativePath)' and its referenced subfolders (13Uninstall, PreReq, ODBC, Desktop, AE, OnBase Client 16)." -Category 'Intune'
}

try {
    $BatchExitCode = 0
    try {
        $BatchExitCode = Invoke-OnBaseInstallBatch -BatchPath $BatchPath -TimeoutSeconds $script:InstallTimeoutSeconds
    }
    catch {
        throw "BATCH LAUNCH FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # The batch has no internal error checking between steps (same as the
    # PDQ original), so its raw exit code is not treated as pass/fail on its
    # own. Real success is determined by verifying the installed end state
    # directly below. The raw exit code is surfaced on the success STDOUT
    # line and, on failure, inside the thrown message - not via an
    # unconditional log write, which would contradict this script's
    # error-only logging.
    Start-Sleep -Seconds 5

    $VerifyResult = Test-OnBase16Installed

    if (-not $VerifyResult.IsInstalled) {
        throw "Install batch ran (raw exit code $BatchExitCode) but post-install verification failed: $($VerifyResult.Reason)"
    }

    Copy-OnBaseConfigFolder -ScriptRoot $ScriptRoot
    Set-OnBaseDpiCompatibility -ScriptRoot $ScriptRoot

    Write-Output "OnBase install script v$($script:ScriptVersion) completed successfully: client executable, both MSI products, and desktop shortcut all verified. Batch raw exit code was $BatchExitCode."
    exit 0
}
catch {
    Stop-WithFailure -Message $_.Exception.Message -Category 'App'
}
