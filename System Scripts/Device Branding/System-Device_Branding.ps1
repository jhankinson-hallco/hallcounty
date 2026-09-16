#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Sets Hall County desktop wallpaper, lock screen, Start layout, and taskbar
    branding for all newly provisioned devices.

.DESCRIPTION
    Applies device branding in a fully local, offline-safe Win32 package. No
    internet access, Intune connectivity, or network paths are required at runtime.

      Layer 1 - Default User hive replacement (new profiles)
        The packaged DefaultUser.NTUSER.DAT is deployed over the live Default User
        hive. Every new profile created on the device inherits wallpaper settings
        and any other preferences already baked into the packaged hive. The hive
        is never mounted and edited in place; the existing file is backed up to
        C:\ProgramData\HallCountyMIS\Backups\DeviceBranding\ and replaced on
        disk directly.

      Layer 2 - Lock screen (machine-wide, direct registry staging)
        Writes LockScreenImagePath to the HKLM PersonalizationCSP key. The
        PersonalizationCSP is officially supported on Enterprise/Education SKUs
        only; on Windows 11 Pro (non-Shared PC) the MDM CSP API path is
        unsupported, so this script uses a pragmatic direct-registry workaround
        rather than claiming supported CSP policy delivery. LockScreenImageStatus
        is a Get-only readback node and is not written. Detection verifies local
        staging, not guaranteed OS policy consumption.

      Layer 3 - Start layout (new profiles, file-staged)
        LayoutModification.json is copied into the Default User profile's Shell
        folder. When Windows creates a new user profile from the Default profile,
        this file is inherited. Supported Windows 11 builds may consume it during
        shell initialization; older or unsupported builds may simply leave it
        staged without applying the layout.

      Layer 4 - Legacy per-user helper cleanup
        Earlier v2.x builds staged Set-UserBranding.ps1 and registered a
        SYSTEM-context ONLOGON scheduled task. This version does not install a
        logon helper. It removes any legacy task, helper files, and per-SID
        marker folder from older installs so no script launches on later logons.
        Note: TaskbarLayoutModification.xml is staged locally as a reference
        artifact only. The XML-based LayoutXMLPath mechanism is image-time only
        and is not used post-OOBE; taskbar pins are targeted via the
        taskbar.pinnedList section in LayoutModification.json (this Shell-folder
        taskbar JSON path is not consistently documented as a managed post-OOBE
        channel, so behavior must be proven on target Windows builds).

    Safe to run in White Glove / Autopilot technician phase. Also safe to deploy
    via Company Portal on already-provisioned devices. For existing user profiles,
    Layer 1 (Default hive) only affects profiles created after this script runs.

    PACKAGE REQUIREMENTS
    All files must be present in the same folder as this script:
      DefaultUser.NTUSER.DAT        Pre-configured Default User hive
      HCWallpaper.jpg               Hall County wallpaper image
      HCLockScreen.jpg              Hall County lock screen image
      LayoutModification.json       Windows 11 Start layout definition (UTF-8)
      TaskbarLayoutModification.xml Taskbar pin definition

.NOTES
    Version:        2.2.1
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  22/04/2026
    Purpose:        Sets Hall County device branding: wallpaper, lock screen, Start and taskbar layout

    CHANGE LOG
    Change: 22/04/2026 - Initial release -- ver. 1.0.0
    Change: 22/04/2026 - Added BGInfo overlay via scheduled task -- ver. 1.1.0
    Change: 22/04/2026 - Switched lock screen to PersonalizationCSP -- ver. 1.1.1
    Change: 22/04/2026 - Description corrections -- ver. 1.1.2
    Change: 22/04/2026 - .bgi validation added and corrected -- ver. 1.1.3 / 1.1.4 / 1.1.5
    Change: 27/04/2026 - Major redesign: removed BGInfo; replaced live Default User hive
                         mount/edit with packaged hive deployment; added LayoutModification.json
                         to Default User shell folder; SYSTEM ONLOGON per-user helper for
                         Start/taskbar apply; XML staged as reference only -- ver. 2.0.0
    Change: 28/04/2026 - Added taskbar.pinnedList to LayoutModification.json (correct
                         post-OOBE taskbar mechanism); removed BGInfo.exe and HCBGInfo.bgi
                         from package; helper user detection switched to
                         Win32_ComputerSystem.UserName; helper XML active-copy removed
                         -- ver. 2.0.1
    Change: 28/04/2026 - Corrected stale Layer 4 description (helper copies JSON only,
                         not XML); deleted stale .intunewin from source folder -- ver. 2.0.2
    Change: 29/04/2026 - Removed -DisallowStartIfOnBatteries and -StopIfGoingOnBatteries
                         from New-ScheduledTaskSettingsSet; parameters are irrelevant for
                         SYSTEM-account tasks and caused ParameterBindingException on older
                         ScheduledTasks module versions during White Glove -- ver. 2.0.3
    Change: 29/04/2026 - Standardized Set-LockScreenMachineWide to use -LiteralPath on
                         New-Item and Set-ItemProperty; consistent with rest of script and
                         guards against wildcard expansion on registry key names -- ver. 2.0.4
    Change: 29/04/2026 - Backup logic now skips on reinstall if a backup already exists,
                         preserving the pre-branding original across reinstall cycles;
                         softened Step 4 comment to reflect OS version dependency -- ver. 2.0.5
    Change: 30/04/2026 - Removed LockScreenImageStatus write from Set-LockScreenMachineWide;
                         LockScreenImageStatus is a Get-only CSP readback node and should not
                         be written by install scripts; updated Layer 2 description to document
                         the Pro SKU CSP API restriction and the direct registry write approach;
                         added applyOnce pre-24H2 note to Step 4 comment -- ver. 2.0.6
    Change: 30/04/2026 - Added app-specific Default User hive backup folder and manifest;
                         installer now adopts the oldest legacy backup on upgrade instead
                         of creating a new backup from a potentially already-branded hive;
                         clarified lock-screen registry staging as a workaround; improved
                         detection expectations for helper and scheduled task -- ver. 2.0.7
    Change: 30/04/2026 - Write-ErrorLog I/O changed to SilentlyContinue to prevent
                         logging failures from masking original errors (matching uninstall
                         pattern); New-Item changed to -LiteralPath in Write-ErrorLog,
                         New-FolderIfMissing, and Write-Marker; added Parameter(Mandatory)
                         annotations to all helper functions -- ver. 2.0.8
    Change: 30/04/2026 - Replaced New-Item -LiteralPath with New-Item -Path in Write-ErrorLog,
                         Set-LockScreenMachineWide, New-FolderIfMissing, and Write-Marker;
                         -LiteralPath is not valid for New-Item in Windows PowerShell 5.1 and
                         throws ParameterBindingException on any first-run path; removed all
                         [Parameter(Mandatory)] attributes from helper functions per P22 field-
                         confirmed risk -- simple function pattern eliminates PS 5.1 advanced-
                         function parameter-binding failures in SYSTEM/SysNative context;
                         type constraints retained where present -- ver. 2.0.9
    Change: 06/05/2026 - Added toggleable policy lock support for wallpaper and lock screen
                         (REQ-11); $script:LockWallpaper and $script:LockLockScreen flags at
                         top of config; when true, enforces setting via Group Policy registry
                         keys and removes it on uninstall; when false, explicitly removes any
                         previously applied lock; lock state stored in marker file; added
                         Device-Branding-Settings.md reference document to package -- ver. 2.1.0
    Change: 06/05/2026 - Retired SYSTEM ONLOGON helper to satisfy the no recurring logon
                         script requirement; installer now removes legacy helper task/files
                         and relies on Default User profile staging for future users -- ver. 2.2.0
    Change: 07/05/2026 - Added package CMD launchers and updated portal commands so Intune
                         resolves 64-bit PowerShell from either 32-bit or 64-bit IME
                         launcher contexts; direct SysNative failed CreateProcess in
                         White Glove logs when launched from 64-bit IME -- ver. 2.2.1

    PORTAL SETTINGS
    Install command   : %SystemRoot%\System32\cmd.exe /d /c .\Install-Device_Branding.cmd
    Uninstall command : %SystemRoot%\System32\cmd.exe /d /c .\Uninstall-Device_Branding.cmd
    Install behavior  : System
    Install time      : 10 minutes
    Restart behavior  : No specific action
    Detection         : Custom script - Detect.ps1 / Run as 32-bit: No / Signature check: No
#>

#region ========================= CONFIGURATION =========================

$script:AppVersion          = '2.2.1'
$script:AppName             = 'Device Branding'

# Error-only log. File and folder are created on the first error only.
$script:LogRoot             = 'C:\IntuneAppLogs'
$script:LogFileName         = 'DeviceBranding_Install.txt'

# Marker file written on clean success. Detect.ps1 validates this.
$script:MarkerFile          = 'C:\ProgramData\HallCountyMIS\DeviceBranding.marker'

# Stable destination for wallpaper and lock screen images.
# Must survive reboots and profile creation; never a temp or user-profile path.
$script:ImagesFolder        = 'C:\IntuneDeploymentFiles\Images'
$script:WallpaperFileName   = 'HCWallpaper.jpg'
$script:LockScreenFileName  = 'HCLockScreen.jpg'

# Machine-wide lock screen direct-registry staging.
# This targets the PersonalizationCSP registry location as a pragmatic Windows Pro
# workaround. It is not the same thing as supported CSP policy delivery.
$script:LockScreenCSPKey    = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

# Default User profile. The packaged hive is deployed here; the existing file
# is backed up with a UTC timestamp before it is replaced.
$script:DefaultHiveFile          = 'C:\Users\Default\NTUSER.DAT'
$script:DefaultHiveBackupRoot    = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding'
$script:DefaultHiveLegacyBackupRoot = 'C:\ProgramData\HallCountyMIS\Backups'
$script:DefaultHiveBackupManifest = 'C:\ProgramData\HallCountyMIS\Backups\DeviceBranding\DefaultHiveBackup.marker'
$script:PackagedHiveFileName     = 'DefaultUser.NTUSER.DAT'

# Default User AppData shell folder.
# LayoutModification.json placed here is inherited by new user profiles when
# Windows copies the Default profile at first logon.
$script:DefaultShellFolder  = 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell'

# Stable staging location for shell layout files and human/AI reference.
$script:ShellFilesFolder    = 'C:\IntuneDeploymentFiles\Shell'
$script:LayoutJsonFileName  = 'LayoutModification.json'
$script:TaskbarXmlFileName  = 'TaskbarLayoutModification.xml'

# Legacy per-user ONLOGON helper cleanup. v2.2.0 no longer installs this task.
$script:LegacyHelperFolder        = 'C:\IntuneScripts\DeviceBranding'
$script:LegacyUserBrandingTaskName = 'Hall County - Device Branding User Apply'
$script:LegacyPerSIDMarkerFolder  = 'C:\ProgramData\HallCountyMIS\BrandingApplied'

# -----------------------------------------------------------------------
# LOCK CONFIGURATION
# Set $true to enforce a setting via machine-wide Group Policy registry
# values, preventing users from changing it after branding is applied.
# Set $false (default) for an OEM-style experience: the setting is applied
# as the user default but users can freely override it afterward.
#
# IMPORTANT: Changing only these flags does NOT require a version bump.
# The installer always writes or removes the policy values on each run,
# so a new version must be deployed via Intune for a lock state change to
# take effect on an already-provisioned device.
# -----------------------------------------------------------------------
$script:LockWallpaper       = $false
$script:LockLockScreen      = $false

# Machine-wide Group Policy registry paths used when locking is enabled.
# These are standard GP paths honored on Windows Pro without MDM/Intune
# policy profiles and are cleaned up on uninstall.
$script:WallpaperPolicyKey   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'
$script:LockScreenPolicyKey  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

#endregion

#region ========================= HELPERS =========================

function Write-ErrorLog {
    param (
        $Message,
        $Category
    )
    # All I/O in this function uses SilentlyContinue. A logging failure must never
    # propagate and mask the original error that triggered the log call.
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
    param (
        $ErrorRecord
    )
    $type = $ErrorRecord.Exception.GetType().Name
    $msg  = $ErrorRecord.Exception.Message
    $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
    return "$type`: $msg | Line: $line"
}

function Get-FileSha256 {
    param (
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Cannot calculate SHA256. File not found: '$Path'."
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Write-DefaultHiveBackupManifest {
    param (
        [string] $BackupPath,
        [string] $BackupOrigin
    )

    $backupHash = Get-FileSha256 -Path $BackupPath
    $manifestLines = @(
        "AppName=$($script:AppName)",
        "ScriptVersion=$($script:AppVersion)",
        "Timestamp=$([datetime]::UtcNow.ToString('o'))",
        "SourceHivePath=$($script:DefaultHiveFile)",
        "BackupHivePath=$BackupPath",
        "BackupSha256=$backupHash",
        "BackupOrigin=$BackupOrigin"
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        $script:DefaultHiveBackupManifest,
        ($manifestLines -join [System.Environment]::NewLine),
        $utf8NoBom
    )
}

function Exit-Failure {
    param (
        $Code,
        $Message,
        $Category
    )
    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}

function Set-LockScreenMachineWide {
    param (
        $ImagePath
    )
    # PersonalizationCSP is officially supported on Enterprise/Education SKUs only.
    # On Windows 11 Pro (non-Shared PC) the MDM CSP API is unsupported, so this
    # function stages the local path directly in the registry as a workaround.
    # Only LockScreenImagePath is written; LockScreenImageStatus is a Get-only
    # readback node populated by Windows after CSP policy processing and must not
    # be written by install scripts. Detection confirms the staged value only.
    if (-not (Test-Path -LiteralPath $script:LockScreenCSPKey)) {
        New-Item -Path $script:LockScreenCSPKey -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -LiteralPath $script:LockScreenCSPKey -Name 'LockScreenImagePath' -Value $ImagePath -Type String -Force -ErrorAction Stop
}

function New-FolderIfMissing {
    param (
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}

function Set-WallpaperPolicyLock {
    param (
        $ImagePath,
        $Lock
    )
    # When Lock is $true: write Group Policy registry values that enforce the
    # wallpaper machine-wide and prevent users from changing it via Settings.
    # WallpaperStyle '10' = Fill. Both values use REG_SZ per GP documentation.
    # When Lock is $false: remove the enforced values if they exist from a
    # previous locked installation, restoring user freedom to change wallpaper.
    # Only named values are removed; the key itself is not deleted in case other
    # Group Policy components have written to it.
    if ($Lock) {
        if (-not (Test-Path -LiteralPath $script:WallpaperPolicyKey)) {
            New-Item -Path $script:WallpaperPolicyKey -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -LiteralPath $script:WallpaperPolicyKey -Name 'Wallpaper'      -Value $ImagePath -Type String -Force -ErrorAction Stop
        Set-ItemProperty -LiteralPath $script:WallpaperPolicyKey -Name 'WallpaperStyle' -Value '10'       -Type String -Force -ErrorAction Stop
    }
    else {
        if (Test-Path -LiteralPath $script:WallpaperPolicyKey) {
            $existing = Get-ItemProperty -LiteralPath $script:WallpaperPolicyKey -ErrorAction SilentlyContinue
            if ($null -ne $existing) {
                foreach ($name in @('Wallpaper', 'WallpaperStyle')) {
                    if ($existing.PSObject.Properties[$name]) {
                        Remove-ItemProperty -LiteralPath $script:WallpaperPolicyKey -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}

function Set-LockScreenPolicyLock {
    param (
        $ImagePath,
        $Lock
    )
    # When Lock is $true: write the Group Policy registry value that enforces
    # the lock screen image on Windows Pro (documented alternative to the
    # PersonalizationCSP MDM path). This grays out the lock screen setting in
    # the Windows Settings app. The CSP staging in Step 2 is still written
    # alongside this for defense in depth; both point to the same image file.
    # When Lock is $false: remove the policy value if present from a prior
    # locked installation. The key itself is not deleted.
    if ($Lock) {
        if (-not (Test-Path -LiteralPath $script:LockScreenPolicyKey)) {
            New-Item -Path $script:LockScreenPolicyKey -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -LiteralPath $script:LockScreenPolicyKey -Name 'LockScreenImage' -Value $ImagePath -Type String -Force -ErrorAction Stop
    }
    else {
        if (Test-Path -LiteralPath $script:LockScreenPolicyKey) {
            $existing = Get-ItemProperty -LiteralPath $script:LockScreenPolicyKey -ErrorAction SilentlyContinue
            if ($null -ne $existing -and $existing.PSObject.Properties['LockScreenImage']) {
                Remove-ItemProperty -LiteralPath $script:LockScreenPolicyKey -Name 'LockScreenImage' -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Write-Marker {
    $markerDir = [System.IO.Path]::GetDirectoryName($script:MarkerFile)
    if (-not (Test-Path -LiteralPath $markerDir -PathType Container)) {
        New-Item -Path $markerDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $lines = @(
        "AppName=$($script:AppName)",
        "ScriptVersion=$($script:AppVersion)",
        "Timestamp=$([datetime]::UtcNow.ToString('o'))",
        "DefaultHiveBackupManifest=$($script:DefaultHiveBackupManifest)",
        "LockWallpaper=$($script:LockWallpaper)",
        "LockLockScreen=$($script:LockLockScreen)"
    )
    $content   = $lines -join [System.Environment]::NewLine
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($script:MarkerFile, $content, $utf8NoBom)
}

#endregion

#region ========================= MAIN =========================

try {
    # 64-bit guard. The registry provider must run from a 64-bit host to avoid
    # WOW64 path redirection. The package launcher resolves the correct host.
    if (-not [System.Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message '64-bit PowerShell required. Verify the Intune command uses the documented CMD launcher.' -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Exit-Failure -Code 1 -Message 'Cannot resolve $PSCommandPath. Run as a saved .ps1 file from disk.' -Category 'Intune'
    }
    $scriptRoot = [System.IO.Path]::GetDirectoryName($PSCommandPath)

    # Build source paths for every required package file.
    $wallpaperSrc   = Join-Path $scriptRoot $script:WallpaperFileName
    $lockScreenSrc  = Join-Path $scriptRoot $script:LockScreenFileName
    $hiveSrc        = Join-Path $scriptRoot $script:PackagedHiveFileName
    $layoutJsonSrc  = Join-Path $scriptRoot $script:LayoutJsonFileName
    $taskbarXmlSrc  = Join-Path $scriptRoot $script:TaskbarXmlFileName

    # Verify all package files are present before touching the device.
    # A missing file at this point means an incomplete .intunewin package.
    foreach ($file in @(
        @{ Path = $wallpaperSrc;  Label = 'Wallpaper image'              },
        @{ Path = $lockScreenSrc; Label = 'Lock screen image'            },
        @{ Path = $hiveSrc;       Label = 'DefaultUser.NTUSER.DAT'       },
        @{ Path = $layoutJsonSrc; Label = 'LayoutModification.json'      },
        @{ Path = $taskbarXmlSrc; Label = 'TaskbarLayoutModification.xml'}
    )) {
        if (-not (Test-Path -LiteralPath $file.Path -PathType Leaf)) {
            Exit-Failure -Code 1 `
                -Message "$($file.Label) not found at '$($file.Path)'. Verify package contents." `
                -Category 'Intune'
        }
    }

    # Derived destination paths used across multiple steps.
    $wallpaperDest    = Join-Path $script:ImagesFolder    $script:WallpaperFileName
    $lockScreenDest   = Join-Path $script:ImagesFolder    $script:LockScreenFileName
    $defaultLayoutDst = Join-Path $script:DefaultShellFolder $script:LayoutJsonFileName
    $stagedLayoutJson = Join-Path $script:ShellFilesFolder   $script:LayoutJsonFileName
    $stagedTaskbarXml = Join-Path $script:ShellFilesFolder   $script:TaskbarXmlFileName

    # -------------------------------------------------------------------------
    # Step 1: Copy wallpaper and lock screen images to a stable machine path.
    # C:\IntuneDeploymentFiles\Images\ is machine-wide and survives reboots.
    # This path is written to the PersonalizationCSP registry key; it must exist
    # when the lock screen is first displayed after install.
    # -------------------------------------------------------------------------
    try {
        New-FolderIfMissing -Path $script:ImagesFolder
        Copy-Item -LiteralPath $wallpaperSrc  -Destination $wallpaperDest  -Force -ErrorAction Stop
        Copy-Item -LiteralPath $lockScreenSrc -Destination $lockScreenDest -Force -ErrorAction Stop
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to copy image files: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 2: Stage the machine-wide lock screen registry value.
    # Writes LockScreenImagePath directly to the PersonalizationCSP registry key.
    # This is a Windows Pro workaround; it is not supported CSP policy delivery.
    # See Set-LockScreenMachineWide for notes on the Pro SKU CSP restriction.
    # -------------------------------------------------------------------------
    try {
        Set-LockScreenMachineWide -ImagePath $lockScreenDest
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to set lock screen registry key: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 2.5: Apply or remove machine-wide Group Policy locks for wallpaper
    # and lock screen. Controlled by $script:LockWallpaper and
    # $script:LockLockScreen in the CONFIGURATION region above.
    # When $true: writes policy registry values that enforce the setting and
    # gray out the corresponding option in Windows Settings.
    # When $false: explicitly removes any previously written policy values so
    # a prior locked installation does not leave stale enforcement behind.
    # -------------------------------------------------------------------------
    try {
        Set-WallpaperPolicyLock  -ImagePath $wallpaperDest  -Lock $script:LockWallpaper
        Set-LockScreenPolicyLock -ImagePath $lockScreenDest -Lock $script:LockLockScreen
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to apply policy lock settings: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 3: Backup and replace the Default User hive.
    # The packaged DefaultUser.NTUSER.DAT already contains wallpaper settings
    # and other preferences baked in. Replacing the hive file on disk means every
    # new profile created on this device inherits those settings automatically.
    # The live hive is NOT mounted; we copy the file directly while it is not in
    # use. A timestamped backup is kept so uninstall can restore the original.
    # Potential failure category: System (file locked by another process or
    # access denied to C:\Users\Default\).
    # -------------------------------------------------------------------------
    try {
        New-FolderIfMissing -Path $script:DefaultHiveBackupRoot
        # Only take a baseline backup if this package has no app-specific backup.
        # On upgrade from older package versions, adopt the oldest legacy backup
        # from the previous shared backup folder. That is more likely to be the
        # true pre-branding hive than the current C:\Users\Default\NTUSER.DAT,
        # which may already be branded by an earlier install.
        $existingAppBackups = @(
            Get-ChildItem -LiteralPath $script:DefaultHiveBackupRoot `
                -Filter 'DefaultHive_*.DAT' -File -ErrorAction SilentlyContinue
        )
        if ($existingAppBackups.Count -gt 0) {
            $baselineBackup = @($existingAppBackups | Sort-Object LastWriteTimeUtc)[0]
            Write-DefaultHiveBackupManifest -BackupPath $baselineBackup.FullName -BackupOrigin 'ExistingAppSpecificBackup'
        }
        else {
            $legacyBackups = @()
            if (Test-Path -LiteralPath $script:DefaultHiveLegacyBackupRoot -PathType Container) {
                $legacyBackups = @(
                    Get-ChildItem -LiteralPath $script:DefaultHiveLegacyBackupRoot `
                        -Filter 'DefaultHive_*.DAT' -File -ErrorAction SilentlyContinue
                )
            }

            $timestamp  = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
            $backupPath = Join-Path $script:DefaultHiveBackupRoot "DefaultHive_$timestamp.DAT"

            if ($legacyBackups.Count -gt 0) {
                $legacyBackup = @($legacyBackups | Sort-Object LastWriteTimeUtc)[0]
                Copy-Item -LiteralPath $legacyBackup.FullName -Destination $backupPath -Force -ErrorAction Stop
                Write-DefaultHiveBackupManifest -BackupPath $backupPath -BackupOrigin "LegacyBackup:$($legacyBackup.FullName)"
            }
            else {
                if (-not (Test-Path -LiteralPath $script:DefaultHiveFile -PathType Leaf)) {
                    throw "Default User hive not found at '$($script:DefaultHiveFile)'. Refusing to replace it without a baseline backup."
                }
                Copy-Item -LiteralPath $script:DefaultHiveFile -Destination $backupPath -Force -ErrorAction Stop
                Write-DefaultHiveBackupManifest -BackupPath $backupPath -BackupOrigin 'CurrentDefaultHive'
            }
        }
        Copy-Item -LiteralPath $hiveSrc -Destination $script:DefaultHiveFile -Force -ErrorAction Stop
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to deploy Default User hive: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 4: Copy LayoutModification.json to the Default User shell folder.
    # When Windows creates a new user profile it copies the entire Default profile
    # directory tree. Placing the JSON here provides Start layout configuration for
    # new users at profile creation; Windows processes the file if the OS version
    # supports the file-placement mechanism (Windows 11 22H2+). On older builds
    # the file is staged but may not be consumed.
    # Note: the applyOnce field inside the JSON is only honored on Windows 11 24H2
    # with KB5062660; on earlier Windows 11 builds it is silently ignored, meaning
    # Windows may re-apply the layout on subsequent logons rather than deferring to
    # user customizations.
    # The parent folder may not exist in the Default profile on a factory image
    # that has never had shell customization applied.
    # -------------------------------------------------------------------------
    try {
        New-FolderIfMissing -Path $script:DefaultShellFolder
        Copy-Item -LiteralPath $layoutJsonSrc -Destination $defaultLayoutDst -Force -ErrorAction Stop
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to stage LayoutModification.json to Default User shell folder: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 5: Stage both shell layout files to the permanent machine location.
    # LayoutModification.json is the same source copied into the Default User
    # shell folder. TaskbarLayoutModification.xml remains a reference artifact.
    # -------------------------------------------------------------------------
    try {
        New-FolderIfMissing -Path $script:ShellFilesFolder
        Copy-Item -LiteralPath $layoutJsonSrc -Destination $stagedLayoutJson -Force -ErrorAction Stop
        Copy-Item -LiteralPath $taskbarXmlSrc -Destination $stagedTaskbarXml -Force -ErrorAction Stop
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to stage shell layout files: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 6: Remove legacy per-user ONLOGON helper infrastructure.
    # Older v2.x installs registered a SYSTEM AtLogOn task that launched a helper
    # at every logon. The OEM-style model now relies on Default User profile
    # staging only, so any leftover recurring task must be removed.
    # -------------------------------------------------------------------------
    try {
        $legacyTasks = @(Get-ScheduledTask -TaskName $script:LegacyUserBrandingTaskName -ErrorAction SilentlyContinue)
        foreach ($legacyTask in $legacyTasks) {
            Unregister-ScheduledTask -InputObject $legacyTask -Confirm:$false -ErrorAction Stop
        }
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to remove legacy ONLOGON scheduled task: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 7: Remove legacy helper files and per-SID markers from older installs.
    # This cleanup is best effort after the task is gone; stale files do not
    # affect current behavior, but removing them keeps detection and source state
    # aligned with the no-recurring-logon-script design.
    # -------------------------------------------------------------------------
    try {
        foreach ($legacyFolder in @($script:LegacyHelperFolder, $script:LegacyPerSIDMarkerFolder)) {
            if (Test-Path -LiteralPath $legacyFolder -PathType Container) {
                Remove-Item -LiteralPath $legacyFolder -Recurse -Force -ErrorAction Stop
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Non-critical legacy helper file cleanup failed: $(Get-ExceptionSummary $_)" -Category 'System'
    }

    # -------------------------------------------------------------------------
    # Step 8: Write the completion marker.
    # Detect.ps1 validates both the file existence and the version line inside.
    # -------------------------------------------------------------------------
    try {
        Write-Marker
    }
    catch {
        Exit-Failure -Code 1 `
            -Message "Failed to write completion marker: $(Get-ExceptionSummary $_)" `
            -Category 'System'
    }

    exit 0
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    Exit-Failure -Code 1 -Message "Unhandled exception: $summary" -Category 'App'
}

#endregion
