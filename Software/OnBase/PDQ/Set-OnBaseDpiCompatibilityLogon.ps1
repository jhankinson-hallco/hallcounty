#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Scheduled-task action script: writes the OnBase AE-mode login dialog DPI
    compatibility flag directly into the currently logging-on user's own
    HKCU hive.

.DESCRIPTION
    Registered by both Install-OnBase.ps1 and Set-OnBaseDpiCompatibility-PDQ.ps1
    as a SYSTEM-context scheduled task (trigger: AtLogOn, any user). Replaces
    the earlier Default User hive injection approach (Install-OnBase.ps1
    through v1.1.8, Set-OnBaseDpiCompatibility-PDQ.ps1 through v1.0.2), which
    was confirmed NOT to work: fresh-imaged endpoints never picked up the fix
    on new profiles, and a PDQ run against an already-provisioned device with
    an already-loaded Default hive write showed the identical failure for any
    profile created afterward - ruling out both an IME-token-restriction
    theory and an OOBE/White-Glove timing theory (PDQ runs nowhere near
    either). See AI-Audit-Decisions.md for the full evidence chain.

    This script sidesteps the Default-hive-inheritance question entirely by
    writing directly into the logging-on user's own HKCU the moment they log
    on - the exact mechanism already confirmed to work for existing profiles
    throughout this project. End users have no administrative rights, so this
    must run under the SYSTEM principal (not "run only when user is logged
    on"/as the interactive user) - the scheduled task registration in both
    calling scripts uses -LogonType ServiceAccount with UserId 'SYSTEM'.

    Identifies the logging-on user via Win32_ComputerSystem.UserName - already
    a sanctioned pattern in this workspace for standard single-user endpoints
    (see shared AGENTS.md "Durable Lessons Already Learned"; Hall County's
    fleet is not RDS/VDI). Translates that account name to a SID, then writes
    directly into "Registry::HKEY_USERS\<Sid>" if already loaded (expected -
    Windows loads the user's hive before AtLogOn-triggered tasks fire), with a
    short retry loop for the rare case this task fires slightly ahead of hive
    load, falling back to a temporary NTUSER.DAT mount (same proven reg.exe
    load/unload pattern used elsewhere in this project) if the hive still
    is not visible under HKEY_USERS after retrying.

    Fire-and-forget: runs every logon, always exits 0. Errors are logged, not
    surfaced to any caller - there is no Intune/PDQ success signal tied to a
    scheduled task's own exit code.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_OnBase_DpiCompatLogon.txt

.NOTES
    Version:        1.0.0
    Script Type:    Scheduled Task Action (registered by Install-OnBase.ps1 and Set-OnBaseDpiCompatibility-PDQ.ps1)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  21/08/2026
    Purpose:        Apply the OnBase AE-mode DPI compatibility fix directly to each user's HKCU at every logon

    CHANGE LOG
    Change: 21/08/2026 - Initial release -- ver. 1.0.0
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion  = '1.0.0'
$script:ClientExePath  = 'C:\Program Files\OnBase Client 16\obclnt32.exe'
$script:CompatSubKey   = 'Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$script:CompatValue    = '~ GDIDPISCALING DPIUNAWARE'
$script:RegExePath     = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
$script:MountPointBase = 'HKU\OnBaseLogonFix'

$script:HiveLoadRetryCount   = 5
$script:HiveLoadRetryDelayMs = 1000

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath 'APP_OnBase_DpiCompatLogon.txt'

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw; all I/O uses SilentlyContinue.
    param(
        [string]$Message,
        [string]$Category = 'Compatibility'
    )
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = '[{0}] [v{1}] [{2}] {3}' -f $Timestamp, $script:ScriptVersion, $Category, $Message
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    $Message = $ErrorRecord.Exception.Message
    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $ErrorRecord.Exception.GetType().FullName
    }
    return ($Message -replace '(\r\n|\n|\r)+', ' ').Trim()
}

function Get-LoggedOnUserSid {
    # Win32_ComputerSystem.UserName is acceptable for standard single-user
    # endpoint scenarios (this fleet), not a general RDS/VDI/multi-session
    # solution - see shared AGENTS.md Durable Lessons Already Learned.
    try {
        $UserName = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
        if ([string]::IsNullOrWhiteSpace($UserName)) {
            return $null
        }
        $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $UserName
        return $Account.Translate([System.Security.Principal.SecurityIdentifier]).Value
    }
    catch {
        return $null
    }
}

function Set-CompatValueInMountedHive {
    param(
        [string]$MountPoint
    )
    $TargetKey = "$MountPoint\$script:CompatSubKey"
    $AddOutput = & $script:RegExePath add $TargetKey /v $script:ClientExePath /t REG_SZ /d $script:CompatValue /f 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "reg add failed (exit $LASTEXITCODE): $AddOutput"
    }
}

function Set-CompatValueForLoadedHive {
    param(
        [string]$Sid
    )
    for ($Attempt = 1; $Attempt -le $script:HiveLoadRetryCount; $Attempt++) {
        if (Test-Path -LiteralPath "Registry::HKEY_USERS\$Sid") {
            Set-CompatValueInMountedHive -MountPoint "HKU\$Sid"
            return $true
        }
        Start-Sleep -Milliseconds $script:HiveLoadRetryDelayMs
    }
    return $false
}

function Set-CompatValueForUnloadedProfile {
    param(
        [string]$Sid
    )
    $ProfileKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Sid"
    $ImagePathProperty = Get-ItemProperty -LiteralPath $ProfileKeyPath -Name 'ProfileImagePath' -ErrorAction SilentlyContinue
    if ($null -eq $ImagePathProperty -or [string]::IsNullOrWhiteSpace($ImagePathProperty.ProfileImagePath)) {
        throw "No ProfileList entry (or empty ProfileImagePath) found for SID '$Sid'."
    }

    $NtUserDatPath = Join-Path -Path $ImagePathProperty.ProfileImagePath -ChildPath 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $NtUserDatPath -PathType Leaf)) {
        throw "NTUSER.DAT not found at '$NtUserDatPath'."
    }

    $MountPoint = "$script:MountPointBase-$($Sid.Substring($Sid.Length - 8))"
    $HiveLoaded = $false
    try {
        & $script:RegExePath unload $MountPoint 2>&1 | Out-Null

        $LoadOutput = & $script:RegExePath load $MountPoint $NtUserDatPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed (exit $LASTEXITCODE): $LoadOutput"
        }
        $HiveLoaded = $true

        Set-CompatValueInMountedHive -MountPoint $MountPoint
    }
    finally {
        if ($HiveLoaded) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $UnloadOutput = & $script:RegExePath unload $MountPoint 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog -Message "reg unload warning for SID '$Sid' (exit $LASTEXITCODE): $UnloadOutput"
            }
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

try {
    $Sid = Get-LoggedOnUserSid
    if ([string]::IsNullOrWhiteSpace($Sid)) {
        Write-ErrorLog -Message 'Could not resolve a logged-on user SID via Win32_ComputerSystem.UserName - skipped this logon.'
        exit 0
    }

    if (-not (Set-CompatValueForLoadedHive -Sid $Sid)) {
        Set-CompatValueForUnloadedProfile -Sid $Sid
    }
}
catch {
    Write-ErrorLog -Message "Failed to set DPI compatibility flag for the logging-on user: $(Get-ExceptionSummary -ErrorRecord $_)"
}

exit 0
