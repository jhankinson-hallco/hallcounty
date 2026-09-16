#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Per-user first-logon branding helper for Hall County Device Branding.

.DESCRIPTION
    Runs as SYSTEM via an ONLOGON scheduled task registered by
    System-Device_Branding.ps1. This task fires at every logon; the helper
    itself does real work only once per user SID.

    On each logon:
      1. Identifies the logged-on user via Win32_ComputerSystem.UserName.
      2. Resolves the user's SID and profile path from the registry.
      3. Checks for a per-SID marker at C:\ProgramData\HallCountyMIS\BrandingApplied\.
      4. If the marker exists, exits immediately (no-op for all subsequent logons).
      5. If not: copies LayoutModification.json into the user's local Shell folder
         and writes the SID marker.

    Note on taskbar pins: TaskbarLayoutModification.xml is NOT copied by this
    helper. The XML-based taskbar mechanism (LayoutXMLPath) is image-time only
    and is not a supported post-OOBE apply path. Taskbar pins are targeted via
    the taskbar.pinnedList section in LayoutModification.json; this Shell-folder
    taskbar JSON path is not consistently documented as a managed post-OOBE
    channel, so behavior must be proven on target Windows builds. The helper's
    JSON copy also ensures the correct version reaches users whose profiles
    already existed before this package was installed.

    Source file (staged by System-Device_Branding.ps1):
      C:\IntuneDeploymentFiles\Shell\LayoutModification.json

    Per-SID markers:
      C:\ProgramData\HallCountyMIS\BrandingApplied\<SID>.marker

.NOTES
    Version:        2.1.0
    Script Type:    Microsoft Intune Win32 App (ONLOGON helper)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  27/04/2026
    Purpose:        Applies LayoutModification.json to each user profile on first logon

    CHANGE LOG
    Change: 27/04/2026 - Initial release -- ver. 2.0.0
    Change: 28/04/2026 - Replaced fragile explorer.exe process-owner user detection
                         with Win32_ComputerSystem.UserName; removed XML active-copy
                         (XML taskbar mechanism is image-time only, not post-OOBE);
                         clarified recurring-trigger / one-time-work semantics in
                         comments -- ver. 2.0.1
    Change: 28/04/2026 - Helper now fails and exits without writing the SID marker if
                         staged LayoutModification.json is missing; ensures retry on
                         next logon instead of permanently skipping the SID -- ver. 2.0.2
    Change: 29/04/2026 - Version sync to 2.0.3 -- ver. 2.0.3
    Change: 29/04/2026 - Version sync to 2.0.4 -- ver. 2.0.4
    Change: 29/04/2026 - Softened taskbar.pinnedList description to reflect
                         documentation uncertainty rather than asserting delivery -- ver. 2.0.5
    Change: 30/04/2026 - Version sync to 2.0.7; corrected applyOnce comment to
                         reflect Windows 11 24H2 + KB5062660 dependency; added
                         ProfileImagePath property guard for malformed profile
                         registry entries -- ver. 2.0.7
    Change: 30/04/2026 - Version sync to 2.0.8 -- ver. 2.0.8
    Change: 30/04/2026 - Version sync to 2.0.9 -- ver. 2.0.9
    Change: 06/05/2026 - Version sync to 2.1.0; no functional changes -- ver. 2.1.0
#>

#region ========================= CONFIGURATION =========================

$script:HelperVersion    = '2.1.0'

# Staged source file written by the Win32 app install.
$script:ShellFilesFolder = 'C:\IntuneDeploymentFiles\Shell'
$script:LayoutJsonFile   = 'LayoutModification.json'

# A <SID>.marker file is written here after first-time processing.
# The task checks this on every logon and exits immediately if the marker exists.
# This is what makes a recurring ONLOGON trigger behave as one-time-per-user work.
$script:MarkerFolder     = 'C:\ProgramData\HallCountyMIS\BrandingApplied'

# Error log root. Log file is named per-SID to isolate each user's errors.
# Created only on failure; success produces no log output.
$script:LogRoot          = 'C:\IntuneAppLogs'

#endregion

#region ========================= HELPERS =========================

function Write-ErrorLog {
    param ($Message, $SID)
    $logFile = Join-Path $script:LogRoot "DeviceBrandingHelper_$SID.txt"
    if (-not (Test-Path -LiteralPath $script:LogRoot -PathType Container)) {
        New-Item -Path $script:LogRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $ts   = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [v$($script:HelperVersion)] $Message"
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-ExceptionSummary {
    param ($ErrorRecord)
    $type = $ErrorRecord.Exception.GetType().Name
    $msg  = $ErrorRecord.Exception.Message
    $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
    return "$type`: $msg | Line: $line"
}

#endregion

#region ========================= MAIN =========================

# Initialize variables that the catch block references regardless of where the
# try block throws. Required by Set-StrictMode -Version Latest.
$userSID    = $null
$userName   = $null
$userDomain = $null

try {
    # Identify the interactively-logged-on user via Win32_ComputerSystem.UserName.
    # This is the documented SYSTEM-context method for resolving the primary
    # interactive user. It returns DOMAIN\username for domain accounts or
    # COMPUTERNAME\username for local accounts, and empty string when no
    # interactive user is present (e.g., during boot or pre-logon phase).
    $csInfo       = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $fullUserName = $csInfo.UserName

    if ([string]::IsNullOrEmpty($fullUserName)) {
        # No interactive user session active; nothing to process.
        exit 0
    }

    # Split into domain and username components. The format is always DOMAIN\user.
    $parts      = $fullUserName.Split('\', 2)
    $userDomain = $parts[0]
    $userName   = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }

    # Translate the domain\user account name to its SID.
    # NTAccount.Translate is the standard PS 5.1 method and works for both
    # domain accounts (via cached credentials) and local accounts.
    $ntAccount = New-Object System.Security.Principal.NTAccount("$userDomain\$userName")
    $userSID   = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value

    # Per-SID marker check. If the marker file exists this SID has already been
    # processed; exit immediately. This is what makes the recurring ONLOGON
    # trigger behave as one-time-per-user work. The task overhead on already-
    # processed logons is: one CimInstance query + one file existence check.
    $markerFile = Join-Path $script:MarkerFolder "$userSID.marker"
    if (Test-Path -LiteralPath $markerFile -PathType Leaf) {
        exit 0
    }

    # Resolve the user's profile path from the registry ProfileList.
    # Preferred over environment variables in SYSTEM context; env vars for the
    # logged-on user are not available to a SYSTEM-context process.
    $profileListKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID"
    if (-not (Test-Path -LiteralPath $profileListKey)) {
        # Profile entry not yet registered; Windows may still be creating it.
        # Exit without writing the marker so the next logon retries.
        exit 0
    }
    $profileProps    = Get-ItemProperty -LiteralPath $profileListKey -ErrorAction Stop
    if (-not $profileProps.PSObject.Properties['ProfileImagePath']) {
        # Malformed or incomplete profile entry; allow retry on next logon.
        exit 0
    }
    $userProfilePath = $profileProps.ProfileImagePath

    if ([string]::IsNullOrEmpty($userProfilePath) -or
        -not (Test-Path -LiteralPath $userProfilePath -PathType Container)) {
        # Profile path not yet usable; allow retry on next logon.
        exit 0
    }

    # Ensure the user's local Shell folder exists.
    # It may be absent if this helper fires before Explorer has fully initialized
    # the profile structure, or if the Default profile copy did not include it.
    $userShellFolder = Join-Path $userProfilePath 'AppData\Local\Microsoft\Windows\Shell'
    if (-not (Test-Path -LiteralPath $userShellFolder -PathType Container)) {
        New-Item -Path $userShellFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    # Verify the staged source exists before proceeding. If it is missing the
    # helper exits without writing the SID marker so the next logon retries.
    # Writing the marker on a failed copy would permanently skip this SID.
    # Potential failure category: Intune (staged file removed or deploy failed).
    $srcJson = Join-Path $script:ShellFilesFolder $script:LayoutJsonFile
    if (-not (Test-Path -LiteralPath $srcJson -PathType Leaf)) {
        Write-ErrorLog `
            -Message "Staged LayoutModification.json not found at '$srcJson'. Marker not written; will retry on next logon." `
            -SID $userSID
        exit 1
    }

    # Copy LayoutModification.json into the user's shell folder.
    # This JSON contains both Start pinnedList and taskbar.pinnedList. The file is
    # targeted at Windows 11 22H2+ builds that consume shell-folder layout JSON.
    # applyOnce:true is only honored on Windows 11 24H2 with KB5062660; older
    # Windows 11 builds may silently ignore it. Placing the JSON here ensures the
    # correct version is present for users whose profiles existed before install.
    $dstJson = Join-Path $userShellFolder $script:LayoutJsonFile
    Copy-Item -LiteralPath $srcJson -Destination $dstJson -Force -ErrorAction Stop

    # Write the per-SID marker. All future logons for this SID will hit the
    # marker check above and exit before doing any other work.
    if (-not (Test-Path -LiteralPath $script:MarkerFolder -PathType Container)) {
        New-Item -Path $script:MarkerFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $markerLines = @(
        "SID=$userSID",
        "User=$userDomain\$userName",
        "Timestamp=$([datetime]::UtcNow.ToString('o'))",
        "HelperVersion=$($script:HelperVersion)"
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($markerFile, ($markerLines -join "`n"), $utf8NoBom)

    exit 0
}
catch {
    # Log under the SID if it was resolved before the exception; otherwise use
    # 'unknown' so the log file is still created and findable.
    $sid = if (-not [string]::IsNullOrEmpty($userSID)) { $userSID } else { 'unknown' }
    Write-ErrorLog -Message "Unhandled exception: $(Get-ExceptionSummary $_)" -SID $sid
    # Do NOT write the per-SID marker on failure; the next logon will retry.
    exit 1
}

#endregion
