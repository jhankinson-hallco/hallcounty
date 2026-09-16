#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Applies the OnBase AE-mode login dialog DPI compatibility fix to every
    user profile on this device - existing profiles and future ones.

.DESCRIPTION
    PDQ Deploy companion to Install-OnBase.ps1's Set-OnBaseDpiCompatibility.
    Both fix the same confirmed rendering defect (the AE-mode login dialog
    clips/shifts at any display scaling other than 100%) using the same
    confirmed-working mechanism (an HKCU-scoped AppCompatFlags\Layers entry -
    CONFIRMED VIA CONTROLLED LIVE TESTING 2026-08-19 that the equivalent
    HKLM entry does not work for this application at all). Both channels now
    use the identical two-part approach:
      - Every profile that ALREADY exists on the device gets the fix
        immediately, whether currently logged in (written directly via the
        already-mounted HKEY_USERS hive) or not (mounted temporarily via
        reg.exe load/unload).
      - A SYSTEM-context scheduled task (Register-OnBaseDpiCompatibilityLogonTask,
        AtLogOn, any user) writes the value directly into each user's own
        HKCU at every future logon - covering both a fresh White
        Glove/Autopilot enrollment (no profile exists yet) and any new user
        who logs into an already-provisioned device after this script runs.
        A third approach - writing into the Default User hive so new
        profiles inherit the value automatically - was used through v1.0.2
        and is CONFIRMED NOT TO WORK: running this exact script against an
        already-provisioned device showed the identical failure as
        Install-OnBase.ps1's own Default-hive write (any profile created
        afterward still lacked the fix), which is what motivated the
        scheduled-task replacement. See AI-Audit-Decisions.md.

    Only real user profiles are touched - SIDs are filtered to S-1-5-21-*
    (local/domain accounts) and S-1-12-1-* (Azure AD accounts). Service,
    SYSTEM, and well-known SIDs are skipped.

    Uses reg.exe (not the PowerShell Registry provider) for every write to
    a mounted hive - the provider holds open handles that make "reg unload"
    fail with access-denied. See reference_intune_code_patterns.md,
    "Default User Hive Mount/Unmount Pattern" - this script extends that
    same proven pattern to loop over existing profiles too.

    Must run elevated (SYSTEM or local Administrator) - reg.exe load/unload
    requires SeRestorePrivilege/SeBackupPrivilege.

    Exit Codes:
        0 = Completed (per-profile failures are logged, not fatal - one
            locked or corrupt profile hive should not block the rest)
        1 = Fatal failure before any profile could be processed (e.g. not
            elevated, reg.exe not found)

.NOTES
    Version:        1.0.3
    Script Type:    PDQ Deploy PowerShell Step
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  19/08/2026
    Purpose:        Apply the OnBase AE-mode DPI compatibility fix to every existing and future user profile on a device

    CHANGE LOG
    Change: 19/08/2026 - Initial release -- ver. 1.0.0
    Change: 20/08/2026 - Renamed the Set-CompatValueForExistingProfile
                         parameter from $Profile to $UserProfile - $Profile
                         shadows PowerShell's own automatic $PROFILE
                         variable, flagged by IDE lint. No behavior change
                         -- ver. 1.0.1
    Change: 20/08/2026 - Added Enable-HiveMountPrivileges (P/Invoke
                         AdjustTokenPrivileges), called once in MAIN before
                         any hive mount, explicitly enabling
                         SeBackupPrivilege/SeRestorePrivilege on the
                         process token. Root cause confirmed via a real
                         install log: Install-OnBase.ps1's identical
                         reg.exe load/add calls failed with "ERROR: The
                         parameter is incorrect." when run by IME under
                         SYSTEM - the privileges were present but not
                         enabled on the token, which reg.exe surfaces as
                         this error rather than a plain privilege-denied
                         message. Added defensively here too, since PDQ's
                         agent could plausibly hit the same issue depending
                         on how it launches child processes -- ver. 1.0.2
    Change: 21/08/2026 - REPLACED Set-CompatValueForDefaultUser (Default
                         User hive injection) with
                         Register-OnBaseDpiCompatibilityLogonTask, a
                         SYSTEM-context scheduled task (AtLogOn, any user)
                         that writes the compatibility value directly into
                         the logging-on user's own HKCU via the new
                         Set-OnBaseDpiCompatibilityLogon.ps1 helper
                         (bundled alongside this script, staged to
                         C:\ProgramData\Microsoft\
                         IntuneManagementExtension\ScriptFiles\OnBase at
                         run time). Jeremy confirmed running THIS script
                         against an already-provisioned device showed the
                         identical failure as Install-OnBase.ps1's own
                         Default-hive write: any profile created after
                         this script ran still did not have the fix, even
                         though the existing-profile writes below
                         succeeded normally - ruling out an IME-token
                         theory (this isn't IME) and an OOBE/White-Glove
                         timing theory (this runs nowhere near either).
                         The existing-profile loop below is unchanged - it
                         still gives immediate coverage; the scheduled
                         task now covers every future logon instead of the
                         Default hive. See AI-Audit-Decisions.md for the
                         full evidence chain -- ver. 1.0.3

    PDQ CONFIGURATION
      Add as a PowerShell step, running as SYSTEM (or an account with local
      Administrator rights). Intended to run after the existing OnBase
      install/update batch step completes. Must run as a saved .ps1 file
      from disk (not pasted inline) with
      Set-OnBaseDpiCompatibilityLogon.ps1 present alongside it in the same
      folder - Register-OnBaseDpiCompatibilityLogonTask stages that sibling
      file to the scheduled task's persistent location.

    Paired Intune script: Install-OnBase.ps1 (Set-OnBaseDpiCompatibility) -
      keep the target exe path and compatibility value identical between
      both if either is ever changed. Both scripts register the identical
      scheduled task name/action, so whichever channel runs last simply
      refreshes it.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion   = '1.0.3'
$script:TargetExePath   = 'C:\Program Files\OnBase Client 16\obclnt32.exe'
$script:CompatSubKey    = 'Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$script:CompatValue     = '~ GDIDPISCALING DPIUNAWARE'
$script:RegExePath      = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
$script:MountPointBase  = 'HKU\OnBaseDpiFix'

# Default User hive injection (v1.0.0-v1.0.2) is confirmed NOT to work: a
# run of this exact script against an already-provisioned device showed the
# identical failure as Install-OnBase.ps1's own Default-hive write - any
# profile created after this script ran still did not have the fix, even
# though the existing-profile writes below succeeded normally. Replaced with
# a SYSTEM-context scheduled task that writes directly into each user's own
# HKCU at logon - see AI-Audit-Decisions.md for the full evidence chain.
$script:LogonHelperSourceFileName = 'Set-OnBaseDpiCompatibilityLogon.ps1'
$script:LogonHelperFolder         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\OnBase'
$script:LogonHelperPath           = Join-Path -Path $script:LogonHelperFolder -ChildPath $script:LogonHelperSourceFileName
$script:LogonTaskName             = 'Hall County MIS - OnBase DPI Compatibility Logon Fix'

# =============================================================================
# FUNCTIONS
# =============================================================================

# "reg load"/"reg unload" require SeBackupPrivilege/SeRestorePrivilege to be
# ENABLED on the process token, not merely present. Confirmed 2026-08-19 on
# a real endpoint: IME's SYSTEM-context execution left these
# present-but-disabled, which reg.exe surfaced as "ERROR: The parameter is
# incorrect." on every load/add attempt. PDQ typically runs elevated too,
# and could hit the identical issue depending on how its agent launches
# child processes - enabling both privileges explicitly up front removes
# the ambiguity regardless of host.
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
    param([string]$LogPrefix = '')
    foreach ($PrivilegeName in @('SeBackupPrivilege', 'SeRestorePrivilege')) {
        try {
            $Result = [OnBaseTokenPrivilege]::EnablePrivilege($PrivilegeName)
            if ($Result -eq 0) {
                Write-Log "$LogPrefix$PrivilegeName enabled."
            }
            else {
                Write-Log "$LogPrefix$PrivilegeName could NOT be enabled (Win32 error $Result) - subsequent reg load/unload may fail."
            }
        }
        catch {
            Write-Log "$LogPrefix$PrivilegeName enable attempt threw: $($_.Exception.Message)"
        }
    }
}

function Write-Log {
    param([string]$Message)
    Write-Output ('[{0}] [PDQ] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
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

function Set-CompatValueInMountedHive {
    param(
        [string]$MountPoint
    )
    $TargetKey = "$MountPoint\$script:CompatSubKey"
    $Output = & $script:RegExePath add $TargetKey /v $script:TargetExePath /t REG_SZ /d $script:CompatValue /f 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "reg add failed (exit $LASTEXITCODE): $Output"
    }
}

function Register-OnBaseDpiCompatibilityLogonTask {
    param(
        [string]$ScriptRoot
    )
    # Stages the logon-helper script (bundled alongside this PDQ script) to
    # the same persistent IME-rooted location Install-OnBase.ps1 uses, then
    # registers the identical SYSTEM-context AtLogOn scheduled task. -Force
    # makes this idempotent with the Intune side - whichever channel runs
    # last simply refreshes the same task name/action.
    try {
        $SourcePath = Join-Path -Path $ScriptRoot -ChildPath $script:LogonHelperSourceFileName
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "Logon helper script not found alongside this script at '$SourcePath'."
        }

        New-Item -ItemType Directory -Path $script:LogonHelperFolder -Force -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $SourcePath -Destination $script:LogonHelperPath -Force -ErrorAction Stop

        $Action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $script:LogonHelperPath)
        $Trigger   = New-ScheduledTaskTrigger -AtLogOn
        $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $Settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        Register-ScheduledTask -TaskName $script:LogonTaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force -ErrorAction Stop | Out-Null
        Write-Log 'Logon scheduled task registered/refreshed (covers future and existing users at next logon).'
    }
    catch {
        Write-Log "Logon scheduled task registration: FAILED - $($_.Exception.Message)"
    }
}

function Get-RealUserProfiles {
    # Returns Sid + ProfileImagePath for genuine local/domain/Azure AD user
    # accounts only - filters out SYSTEM, service, and other well-known SIDs.
    $UserProfileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $Results = @()

    foreach ($UserProfileKey in @(Get-ChildItem -LiteralPath $UserProfileListPath -ErrorAction SilentlyContinue)) {
        $Sid = $UserProfileKey.PSChildName
        if ($Sid -notmatch '^S-1-5-21-' -and $Sid -notmatch '^S-1-12-1-') {
            continue
        }

        $ImagePathProperty = Get-ItemProperty -LiteralPath $UserProfileKey.PSPath -Name 'ProfileImagePath' -ErrorAction SilentlyContinue
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

function Set-CompatValueForExistingProfile {
    param(
        [psobject]$UserProfile
    )

    $AlreadyLoaded = Test-Path -LiteralPath "Registry::HKEY_USERS\$($UserProfile.Sid)"

    if ($AlreadyLoaded) {
        try {
            Set-CompatValueInMountedHive -MountPoint "HKU\$($UserProfile.Sid)"
            Write-Log "Profile '$($UserProfile.ProfileImagePath)' (currently loaded): value set."
        }
        catch {
            Write-Log "Profile '$($UserProfile.ProfileImagePath)' (currently loaded): FAILED - $($_.Exception.Message)"
        }
        return
    }

    $NtUserDatPath = Join-Path -Path $UserProfile.ProfileImagePath -ChildPath 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $NtUserDatPath -PathType Leaf)) {
        Write-Log "Profile '$($UserProfile.ProfileImagePath)': skipped - NTUSER.DAT not found."
        return
    }

    $MountPoint = "$script:MountPointBase-$($UserProfile.Sid.Substring($UserProfile.Sid.Length - 8))"
    $HiveLoaded = $false
    try {
        & $script:RegExePath unload $MountPoint 2>&1 | Out-Null

        $LoadOutput = & $script:RegExePath load $MountPoint $NtUserDatPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed (exit $LASTEXITCODE): $LoadOutput"
        }
        $HiveLoaded = $true

        Set-CompatValueInMountedHive -MountPoint $MountPoint
        Write-Log "Profile '$($UserProfile.ProfileImagePath)' (not loaded, mounted): value set."
    }
    catch {
        Write-Log "Profile '$($UserProfile.ProfileImagePath)': FAILED - $($_.Exception.Message)"
    }
    finally {
        if ($HiveLoaded) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $UnloadOutput = & $script:RegExePath unload $MountPoint 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Profile '$($UserProfile.ProfileImagePath)': unload warning (exit $LASTEXITCODE): $UnloadOutput"
            }
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Log "Set-OnBaseDpiCompatibility-PDQ v$script:ScriptVersion starting."

if (-not (Test-IsAdministrator)) {
    Write-Log 'FATAL: this script requires an elevated token (SYSTEM or local Administrator).'
    exit 1
}

if (-not (Test-Path -LiteralPath $script:RegExePath -PathType Leaf)) {
    Write-Log "FATAL: reg.exe not found at '$script:RegExePath'."
    exit 1
}

$ScriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { [System.IO.Path]::GetDirectoryName($PSCommandPath) } else { $null }
if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
    Write-Log 'FATAL: unable to resolve script directory - run this as a saved .ps1 file from disk.'
    exit 1
}

Enable-HiveMountPrivileges

Register-OnBaseDpiCompatibilityLogonTask -ScriptRoot $ScriptRoot

$UserProfiles = Get-RealUserProfiles
Write-Log "Found $($UserProfiles.Count) existing real user profile(s)."

foreach ($UserProfile in $UserProfiles) {
    Set-CompatValueForExistingProfile -UserProfile $UserProfile
}

Write-Log 'Completed.'
exit 0
