#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detection script for Device Branding Win32 app (v2 architecture).

.DESCRIPTION
    Validates the version-stamped marker AND the functional installed state.
    All of the following must be true for detection to succeed:

      1.  Marker file exists and contains the required ScriptVersion line.
      2.  Wallpaper and lock screen images present at the expected machine paths.
      3.  Direct-registry lock screen staging value exists and path is correct.
      4.  C:\Users\Default\NTUSER.DAT exists (post hive-replacement evidence).
      5.  Default User hive backup manifest exists and references a valid backup.
      6.  LayoutModification.json present in the Default User shell folder.
      7.  LayoutModification.json present in the staged Shell files folder.
      8.  TaskbarLayoutModification.xml present in the staged Shell files folder.
      9.  Legacy per-user ONLOGON helper scheduled task is absent.

    Detection does NOT validate visual Start/taskbar consumption. That happens
    inside Windows shell during user profile creation and must be field-tested.

    Exit 0 + STDOUT = detected.
    Exit 1 / no STDOUT = not detected.

.NOTES
    Version:        2.2.1
    Script Type:    Microsoft Intune Win32 App (Detection)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  22/04/2026
    Purpose:        Detects successful Device Branding install at the required version

    CHANGE LOG
    Change: 22/04/2026 - Initial release -- ver. 1.0.0
    Change: 22/04/2026 - Version sync and expanded functional checks -- ver. 1.1.0 through 1.1.5
    Change: 27/04/2026 - Rebuilt for v2.0.0: removed BGInfo checks; added Default
                         NTUSER.DAT existence, Default User shell LayoutModification.json,
                         staged Shell files (JSON + XML), helper script, and ONLOGON
                         task checks -- ver. 2.0.0
    Change: 28/04/2026 - Version sync to 2.0.1 -- ver. 2.0.1
    Change: 28/04/2026 - Clarified staged XML check comment: reference artifact only,
                         not active apply mechanism; version sync to 2.0.2 -- ver. 2.0.2
    Change: 29/04/2026 - Version sync to 2.0.3 -- ver. 2.0.3
    Change: 29/04/2026 - Version sync to 2.0.4 -- ver. 2.0.4
    Change: 29/04/2026 - Version sync to 2.0.5 -- ver. 2.0.5
    Change: 30/04/2026 - Removed LockScreenImageStatus property and value checks;
                         LockScreenImageStatus is a Get-only CSP readback node and
                         is no longer written by the install script -- ver. 2.0.6
    Change: 30/04/2026 - Version sync to 2.0.7; added Default User hive backup
                         manifest validation, helper version validation, and deeper
                         scheduled task configuration checks -- ver. 2.0.7
    Change: 30/04/2026 - Removed helper file content version check (hardcoded version
                         string breaks detection on every helper bump; file existence +
                         task action reference is sufficient); removed SHA256 hash
                         verification from detection (expensive on every check-in cycle;
                         hash check retained in uninstall where it runs once) -- ver. 2.0.8
    Change: 30/04/2026 - Version sync to 2.0.9; removed [Parameter(Mandatory)] from
                         Read-KeyValueFile and Test-PathUnderRoot per P22 field-confirmed
                         risk -- simple function pattern -- ver. 2.0.9
    Change: 06/05/2026 - Version sync to 2.1.0; lock state is validated at the installer
                         level and recorded in the marker; detection validates the version
                         stamp only, not the lock state -- ver. 2.1.0
    Change: 06/05/2026 - Version sync to 2.2.0; helper/task checks replaced with
                         absence check for the retired ONLOGON scheduled task -- ver. 2.2.0
    Change: 07/05/2026 - Version sync to 2.2.1 after Intune launcher command fix;
                         no detection behavior changes -- ver. 2.2.1
#>

$script:RequiredScriptVersion = '2.2.1'
$script:MarkerFile            = 'C:\ProgramData\HallCountyMIS\DeviceBranding.marker'
$script:WallpaperPath         = 'C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg'
$script:LockScreenPath        = 'C:\IntuneDeploymentFiles\Images\HCLockScreen.jpg'
$script:LockScreenCSPKey      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$script:DefaultHiveFile       = 'C:\Users\Default\NTUSER.DAT'
$script:DefaultHiveBackupRoot = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding'
$script:DefaultHiveBackupManifest = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding\DefaultHiveBackup.marker'
$script:DefaultShellLayout    = 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json'
$script:StagedLayoutJson      = 'C:\IntuneDeploymentFiles\Shell\LayoutModification.json'
$script:StagedTaskbarXml      = 'C:\IntuneDeploymentFiles\Shell\TaskbarLayoutModification.xml'
$script:UserBrandingTaskName  = 'Hall County - Device Branding User Apply'

function Read-KeyValueFile {
    param (
        [string] $Path
    )

    $result = @{}
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $utf8NoBom)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -le 0) { continue }
        $key = $line.Substring(0, $separatorIndex)
        $value = $line.Substring($separatorIndex + 1)
        $result[$key] = $value
    }

    return $result
}

function Test-PathUnderRoot {
    param (
        [string] $Path,
        [string] $Root
    )

    try {
        $rootFull = [System.IO.Path]::GetFullPath($Root.TrimEnd('\') + '\')
        $pathFull = [System.IO.Path]::GetFullPath($Path)
        return $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

try {
    # 1. Marker file exists and contains the required version line.
    if (-not (Test-Path -LiteralPath $script:MarkerFile -PathType Leaf)) { exit 1 }
    $utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
    $content      = [System.IO.File]::ReadAllText($script:MarkerFile, $utf8NoBom)
    $expectedLine = 'ScriptVersion={0}' -f $script:RequiredScriptVersion
    $versionFound = $false
    foreach ($line in ($content -split '\r?\n')) {
        if ($line.Trim() -ceq $expectedLine) { $versionFound = $true; break }
    }
    if (-not $versionFound) { exit 1 }

    # 2. Staged image files.
    if (-not (Test-Path -LiteralPath $script:WallpaperPath  -PathType Leaf)) { exit 1 }
    if (-not (Test-Path -LiteralPath $script:LockScreenPath -PathType Leaf)) { exit 1 }

    # 3. Lock screen CSP registry: key exists, path value matches expected destination.
    # LockScreenImageStatus is a Get-only CSP readback node; it is not written by
    # the install script and is not checked here.
    if (-not (Test-Path -LiteralPath $script:LockScreenCSPKey)) { exit 1 }
    $csp = Get-ItemProperty -LiteralPath $script:LockScreenCSPKey -ErrorAction SilentlyContinue
    if ($null -eq $csp)                                          { exit 1 }
    if (-not $csp.PSObject.Properties['LockScreenImagePath'])    { exit 1 }
    if ($csp.LockScreenImagePath   -ne $script:LockScreenPath)   { exit 1 }

    # 4. Default User NTUSER.DAT exists after hive replacement.
    if (-not (Test-Path -LiteralPath $script:DefaultHiveFile -PathType Leaf)) { exit 1 }

    # 5. Default User hive backup manifest exists and points to a valid backup.
    if (-not (Test-Path -LiteralPath $script:DefaultHiveBackupManifest -PathType Leaf)) { exit 1 }
    $backupManifest = Read-KeyValueFile -Path $script:DefaultHiveBackupManifest
    if (-not $backupManifest.ContainsKey('BackupHivePath')) { exit 1 }
    $backupHivePath = $backupManifest['BackupHivePath']
    if ([string]::IsNullOrWhiteSpace($backupHivePath)) { exit 1 }
    if (-not (Test-PathUnderRoot -Path $backupHivePath -Root $script:DefaultHiveBackupRoot)) { exit 1 }
    if (-not (Test-Path -LiteralPath $backupHivePath -PathType Leaf)) { exit 1 }
    # SHA256 hash verification omitted from detection: hashing NTUSER.DAT on every
    # Intune check-in cycle is expensive. Hash validation is retained in uninstall
    # where it runs once before restoring. File existence is sufficient here.

    # 6. LayoutModification.json staged in the Default User shell folder.
    if (-not (Test-Path -LiteralPath $script:DefaultShellLayout -PathType Leaf)) { exit 1 }

    # 7. LayoutModification.json staged in the permanent machine location.
    # This is a durable machine copy/reference matching the Default User payload.
    if (-not (Test-Path -LiteralPath $script:StagedLayoutJson -PathType Leaf)) { exit 1 }

    # 8. TaskbarLayoutModification.xml staged in the permanent machine location.
    # This file is a reference artifact only; the XML-based LayoutXMLPath mechanism
    # is image-time only and is not used post-OOBE. Taskbar pins are targeted via
    # taskbar.pinnedList in LayoutModification.json, but this check verifies the
    # package contract (the file was staged), not that it is actively applied.
    if (-not (Test-Path -LiteralPath $script:StagedTaskbarXml -PathType Leaf)) { exit 1 }

    # 9. Legacy ONLOGON scheduled task is absent.
    # v2.2.0 retired the recurring logon helper. If this task still exists, the
    # package must rerun so the installer can remove it.
    $legacyTasks = @(Get-ScheduledTask -TaskName $script:UserBrandingTaskName -ErrorAction SilentlyContinue)
    if ($legacyTasks.Count -gt 0) { exit 1 }

    Write-Output ('Device Branding v{0} detected.' -f $script:RequiredScriptVersion)
    exit 0
}
catch {
    [Console]::Error.WriteLine('Detect.ps1 exception: ' + $_.Exception.Message)
    exit 1
}
