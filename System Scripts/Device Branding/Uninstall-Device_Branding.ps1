#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstall script for Device Branding Win32 app.

.DESCRIPTION
    Reverses changes made by System-Device_Branding.ps1 v2.2.1:

      - Removes the completion marker (causes Detect.ps1 to report not-detected).
      - Removes the machine-wide lock screen PersonalizationCSP registry values.
      - Unregisters the retired SYSTEM ONLOGON scheduled task if present.
      - Removes the retired per-user helper script folder if present.
      - Removes the retired per-SID marker folder if present.
      - Removes LayoutModification.json from the Default User shell folder so
        future new profiles no longer inherit the branded Start layout.
      - Optionally restores the manifest-recorded DefaultUser.NTUSER.DAT backup
        from C:\ProgramData\HallCountyMIS\Backups\DeviceBranding\ if
        RestoreDefaultHive is $true.

    Does NOT remove images from C:\IntuneDeploymentFiles\Images\ (shared folder)
    or staged shell files from C:\IntuneDeploymentFiles\Shell\ (may be referenced
    by other deployments).

    Always exits 0. Non-critical cleanup failures are logged but do not block
    completion; an uninstall that logs errors is still better than one that loops.

.NOTES
    Version:        2.2.1
    Script Type:    Microsoft Intune Win32 App (Uninstall)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  22/04/2026
    Purpose:        Resets Device Branding detection state and removes applied settings

    CHANGE LOG
    Change: 22/04/2026 - Initial release -- ver. 1.0.0
    Change: 22/04/2026 - Added BGInfo task and folder removal -- ver. 1.1.0
    Change: 22/04/2026 - Switched lock screen removal to PersonalizationCSP -- ver. 1.1.1
    Change: 22/04/2026 - Version syncs -- ver. 1.1.2 / 1.1.3 / 1.1.4 / 1.1.5
    Change: 27/04/2026 - Rebuilt for v2.0.0: removed BGInfo cleanup; removed Default
                         hive mount/edit rollback; added ONLOGON task removal, helper
                         folder removal, per-SID marker folder removal, and optional
                         Default hive restore from backup -- ver. 2.0.0
    Change: 28/04/2026 - Version sync to 2.0.1 -- ver. 2.0.1
    Change: 28/04/2026 - Version sync to 2.0.2 -- ver. 2.0.2
    Change: 29/04/2026 - Version sync to 2.0.3 -- ver. 2.0.3
    Change: 29/04/2026 - Version sync to 2.0.4 -- ver. 2.0.4
    Change: 29/04/2026 - Added removal of Default User shell LayoutModification.json
                         so uninstall fully undoes the new-user Start layout inheritance
                         path; added DefaultShellLayout config variable -- ver. 2.0.5
    Change: 30/04/2026 - Version sync to 2.0.6 -- ver. 2.0.6
    Change: 30/04/2026 - Version sync to 2.0.7; Default User hive restore now
                         uses the app-specific backup manifest and SHA256
                         validation instead of restoring the newest file from
                         the broad HallCountyMIS backup folder -- ver. 2.0.7
    Change: 30/04/2026 - Version sync to 2.0.8 -- ver. 2.0.8
    Change: 30/04/2026 - Version sync to 2.0.9; removed [Parameter(Mandatory)] from
                         Read-KeyValueFile and Test-PathUnderRoot per P22 field-confirmed
                         risk -- simple function pattern -- ver. 2.0.9
    Change: 06/05/2026 - Version sync to 2.1.0; added cleanup of wallpaper and lock screen
                         Group Policy policy registry values applied when lock toggles were
                         enabled; uninstall always removes these values regardless of current
                         lock state -- ver. 2.1.0
    Change: 06/05/2026 - Version sync to 2.2.0; retained cleanup of retired ONLOGON
                         helper task/files after installer stopped deploying them -- ver. 2.2.0
    Change: 07/05/2026 - Version sync to 2.2.1 after Intune launcher command fix;
                         no uninstall behavior changes -- ver. 2.2.1
#>

#region ========================= CONFIGURATION =========================

$script:AppVersion            = '2.2.1'
$script:LogRoot               = 'C:\IntuneAppLogs'
$script:LogFileName           = 'DeviceBranding_Uninstall.txt'
$script:MarkerFile            = 'C:\ProgramData\HallCountyMIS\DeviceBranding.marker'
$script:LockScreenCSPKey      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$script:UserBrandingTaskName  = 'Hall County - Device Branding User Apply'
$script:HelperFolder          = 'C:\IntuneScripts\DeviceBranding'
$script:PerSIDMarkerFolder    = 'C:\ProgramData\HallCountyMIS\BrandingApplied'
$script:DefaultShellLayout    = 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json'
$script:DefaultHiveFile       = 'C:\Users\Default\NTUSER.DAT'
$script:DefaultHiveBackupRoot = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding'
$script:DefaultHiveBackupManifest = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding\DefaultHiveBackup.marker'

# Set to $true to restore the most recent DefaultUser.NTUSER.DAT backup when
# uninstalling. Set to $false to leave the deployed hive in place.
$script:RestoreDefaultHive    = $true

# Group Policy registry paths written when lock toggles were enabled at install
# time. Uninstall always attempts to remove the named values from these keys
# regardless of the current toggle state; if they were never written the
# removal is a safe no-op. The keys themselves are not deleted.
$script:WallpaperPolicyKey    = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'
$script:LockScreenPolicyKey   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

#endregion

#region ========================= HELPERS =========================

function Write-ErrorLog {
    param ($Message, $Category)
    if (-not (Test-Path -LiteralPath $script:LogRoot -PathType Container)) {
        New-Item -Path $script:LogRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $logFile = Join-Path $script:LogRoot $script:LogFileName
    if (-not (Test-Path -LiteralPath $logFile -PathType Leaf)) {
        New-Item -Path $logFile -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $ts   = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [v$($script:AppVersion)] [$Category] $Message"
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-ExceptionSummary {
    param ($ErrorRecord)
    $type = $ErrorRecord.Exception.GetType().Name
    $msg  = $ErrorRecord.Exception.Message
    $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
    return "$type`: $msg | Line: $line"
}

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

function Get-DefaultHiveBackupToRestore {
    if (Test-Path -LiteralPath $script:DefaultHiveBackupManifest -PathType Leaf) {
        $manifest = Read-KeyValueFile -Path $script:DefaultHiveBackupManifest
        if (-not $manifest.ContainsKey('BackupHivePath')) {
            throw "Backup manifest '$($script:DefaultHiveBackupManifest)' does not contain BackupHivePath."
        }

        $backupPath = $manifest['BackupHivePath']
        if ([string]::IsNullOrWhiteSpace($backupPath)) {
            throw "Backup manifest '$($script:DefaultHiveBackupManifest)' contains an empty BackupHivePath."
        }
        if (-not (Test-PathUnderRoot -Path $backupPath -Root $script:DefaultHiveBackupRoot)) {
            throw "Backup path '$backupPath' is outside expected root '$($script:DefaultHiveBackupRoot)'."
        }
        if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            throw "Backup file recorded in manifest was not found: '$backupPath'."
        }
        if ($manifest.ContainsKey('BackupSha256') -and
            -not [string]::IsNullOrWhiteSpace($manifest['BackupSha256'])) {
            $actualHash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($actualHash -ne $manifest['BackupSha256']) {
                throw "Backup hash mismatch for '$backupPath'. Refusing to restore a file that does not match the recorded SHA256."
            }
        }

        return $backupPath
    }

    if (Test-Path -LiteralPath $script:DefaultHiveBackupRoot -PathType Container) {
        $backups = @(
            Get-ChildItem -LiteralPath $script:DefaultHiveBackupRoot `
                -Filter 'DefaultHive_*.DAT' `
                -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc
        )
        if ($backups.Count -gt 0) {
            return $backups[0].FullName
        }
    }

    return $null
}

#endregion

#region ========================= MAIN =========================

# Step 1: Remove the completion marker.
# This is the minimum required for Detect.ps1 to report not-detected on next check.
try {
    if (Test-Path -LiteralPath $script:MarkerFile -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerFile -Force -ErrorAction Stop
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove marker file: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 2: Remove the lock screen PersonalizationCSP registry values.
# Removing these clears the enforced lock screen; Windows reverts to default.
try {
    if (Test-Path -LiteralPath $script:LockScreenCSPKey) {
        $prop = Get-ItemProperty -LiteralPath $script:LockScreenCSPKey -ErrorAction SilentlyContinue
        if ($null -ne $prop) {
            foreach ($valueName in @('LockScreenImagePath', 'LockScreenImageStatus')) {
                if ($prop.PSObject.Properties[$valueName]) {
                    Remove-ItemProperty -LiteralPath $script:LockScreenCSPKey `
                                        -Name $valueName `
                                        -Force -ErrorAction Stop
                }
            }
        }
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove lock screen CSP registry values: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 2b: Remove wallpaper Group Policy lock values if present.
# These are only written when $script:LockWallpaper was $true at install time,
# but uninstall always cleans them to leave no stale enforcement behind.
try {
    if (Test-Path -LiteralPath $script:WallpaperPolicyKey) {
        $prop = Get-ItemProperty -LiteralPath $script:WallpaperPolicyKey -ErrorAction SilentlyContinue
        if ($null -ne $prop) {
            foreach ($valueName in @('Wallpaper', 'WallpaperStyle')) {
                if ($prop.PSObject.Properties[$valueName]) {
                    Remove-ItemProperty -LiteralPath $script:WallpaperPolicyKey `
                                        -Name $valueName `
                                        -Force -ErrorAction Stop
                }
            }
        }
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove wallpaper policy lock values: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 2c: Remove lock screen Group Policy lock value if present.
# Written only when $script:LockLockScreen was $true at install time.
try {
    if (Test-Path -LiteralPath $script:LockScreenPolicyKey) {
        $prop = Get-ItemProperty -LiteralPath $script:LockScreenPolicyKey -ErrorAction SilentlyContinue
        if ($null -ne $prop -and $prop.PSObject.Properties['LockScreenImage']) {
            Remove-ItemProperty -LiteralPath $script:LockScreenPolicyKey `
                                -Name 'LockScreenImage' `
                                -Force -ErrorAction Stop
        }
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove lock screen policy lock value: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 3: Unregister the retired SYSTEM ONLOGON scheduled task if present.
try {
    $tasks = @(Get-ScheduledTask -TaskName $script:UserBrandingTaskName -ErrorAction SilentlyContinue)
    foreach ($task in $tasks) {
        Unregister-ScheduledTask -InputObject $task -Confirm:$false -ErrorAction Stop
    }
}
catch {
    Write-ErrorLog -Message "Failed to unregister scheduled task '$($script:UserBrandingTaskName)': $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 4: Remove the retired per-user helper script and its containing folder.
try {
    if (Test-Path -LiteralPath $script:HelperFolder -PathType Container) {
        Remove-Item -LiteralPath $script:HelperFolder -Recurse -Force -ErrorAction Stop
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove helper folder '$($script:HelperFolder)': $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 5: Remove the retired per-SID marker folder.
# Current installs no longer create per-SID markers, but older v2.x deployments did.
try {
    if (Test-Path -LiteralPath $script:PerSIDMarkerFolder -PathType Container) {
        Remove-Item -LiteralPath $script:PerSIDMarkerFolder -Recurse -Force -ErrorAction Stop
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove per-SID marker folder: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 6: Remove LayoutModification.json from the Default User shell folder.
# Without this removal, future new user profiles would still inherit the branded
# Start layout even after a full uninstall, because Windows copies the entire
# Default profile tree at first logon.
try {
    if (Test-Path -LiteralPath $script:DefaultShellLayout -PathType Leaf) {
        Remove-Item -LiteralPath $script:DefaultShellLayout -Force -ErrorAction Stop
    }
}
catch {
    Write-ErrorLog -Message "Failed to remove Default User shell layout file: $(Get-ExceptionSummary $_)" -Category 'System'
}

# Step 7: Optionally restore the Default User hive from the recorded backup.
# Restoring the original hive undoes the packaged hive deployment for any profiles
# not yet created since the install. Profiles already created from the deployed
# hive are not affected (their own NTUSER.DAT is already in their profile folder).
if ($script:RestoreDefaultHive) {
    try {
        $backupToRestore = Get-DefaultHiveBackupToRestore
        if (-not [string]::IsNullOrWhiteSpace($backupToRestore)) {
            Copy-Item -LiteralPath $backupToRestore `
                      -Destination $script:DefaultHiveFile `
                      -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to restore Default User hive from backup: $(Get-ExceptionSummary $_)" -Category 'System'
    }
}

# Always exit 0. Non-critical cleanup failures must not trigger Intune retry loops.
exit 0

#endregion
