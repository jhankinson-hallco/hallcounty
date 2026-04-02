#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Sets the corporate default wallpaper for new user profiles and enforces the
    corporate lock screen background for all users on this device.

.DESCRIPTION
    Designed for Intune Win32 app execution as SYSTEM during Autopilot pre-provisioning
    (White Glove / technician phase).

    TWO ACTIONS ARE PERFORMED:

      1. LOCK SCREEN — enforced, retroactive, all users (existing and future)
         Writes Group Policy-equivalent registry values to HKLM that set the
         Hall County lock screen image and prevent users from changing it.
         These values are machine-wide and take effect on the next lock screen
         display for all user sessions — no restart required, no user interaction
         needed. Applies to pre-existing accounts immediately.

         Keys written:
           HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization
             LockScreenImage      (REG_SZ)   = C:\IntuneDeploymentFiles\Images\HCLockScreen.jpg
             NoChangingLockScreen (REG_DWORD) = 1

         NOTE: The PersonalizationCSP registry path is intentionally NOT used here.
         That path is only effective on Windows Enterprise/Education SKUs or devices
         in Shared PC mode. For Windows Pro (Hall County fleet), the ADMX-backed
         Policies path above is the only supported and reliable mechanism.

      2. DEFAULT WALLPAPER — new user profiles only, user-changeable
         Uses a two-layer approach for maximum reliability across Windows 10 and 11:

         LAYER 1 — Control Panel\Desktop registry values (Default User hive)
           The classic enterprise method. Sets Wallpaper, WallpaperStyle, and
           TileWallpaper in C:\Users\Default\NTUSER.DAT. Reliable on Windows 10
           LTSC 1809. May be overridden by Windows 11's first-login theme
           provisioning on some builds — Layer 2 addresses this.

         LAYER 2 — Custom theme file + CurrentTheme registry value (Default User hive)
           Generates C:\IntuneDeploymentFiles\HallCounty.theme, a minimal .theme
           file that declares the Hall County wallpaper path and display style.
           Sets HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\CurrentTheme
           in the Default User hive to point to this file. When a new user logs
           in, Windows Explorer reads CurrentTheme and applies the specified theme,
           including the wallpaper — this fires AFTER the default OS theme and
           takes precedence. Together, both layers cover all known Windows 10 and
           11 first-login scenarios.

         Either layer alone is sufficient to set the wallpaper on most builds.
         Both layers together ensure the setting survives the Windows 11 first-login
         provisioning sequence regardless of which default theme the OS attempts to
         apply. Users may change their wallpaper freely at any time after first login.
         Existing profiles are not modified by either layer.

    IMAGES:
         Both images are copied from the package directory ($PSScriptRoot) to the
         durable machine-wide path C:\IntuneDeploymentFiles\Images\ before any
         registry values are written. Registry paths reference this destination.

    DEPLOYMENT PHASE:
         Run as a Win32 app in the Device Setup phase (White Glove / Autopilot
         pre-provisioning, SYSTEM context). No logged-on user is required.
         All operations are White Glove safe: HKLM writes, Default User hive
         modification, and local file creation — no user profiles, no network.

    MARKER BEHAVIOR:
         Marker is written on Success or CompletedWithWarnings.
         Marker is NOT written on unhandled exception — allows Intune to retry.

    Always exits 0 — branding is non-critical and must not block the Autopilot /
    White Glove ESP dependency chain.

.NOTES
    Author:         Jeremy Hankinson
    Script Version: 1.0.2
    Revision Date:  2026-03-27 (1.0.0); 2026-03-27 (1.0.1 — added theme-file layer for Windows 11 wallpaper reliability); 2026-03-27 (1.0.2 — pre-emptive hive unload guard; explicit CRLF theme content; removed [Slideshow] section)
    Script Name:    System-Device_Branding.ps1

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\System-Device_Branding.ps1

      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-Device_Branding.ps1

      Install behavior:    System
      Restart behavior:    No specific action

    DETECTION
      Custom detection script:
        Script file:                                     Detect.ps1
        Run script as 32-bit process on 64-bit clients:  No
        Enforce script signature check / run silently:   No

    RETURN CODES
      0    = Success, completed with warnings, or non-fatal error
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppVersion = '1.0.2'

# Source images — must exist alongside this script in the package directory.
# These are copied to a durable machine-wide path before any registry values
# are written. Registry keys reference the destination, not the source.
$script:WallpaperSource  = Join-Path -Path $PSScriptRoot -ChildPath 'HCWallpaper.jpg'
$script:LockScreenSource = Join-Path -Path $PSScriptRoot -ChildPath 'HCLockScreen.jpg'

# Destination — standard Intune deployment image path, readable by all users.
# Inherits NTFS ACLs from C:\ which grants Authenticated Users Read & Execute.
$script:ImageDest      = 'C:\IntuneDeploymentFiles\Images'
$script:WallpaperDest  = Join-Path -Path $script:ImageDest -ChildPath 'HCWallpaper.jpg'
$script:LockScreenDest = Join-Path -Path $script:ImageDest -ChildPath 'HCLockScreen.jpg'

# Theme file — generated by this script at install time. Referenced by the
# CurrentTheme registry value in the Default User hive (Layer 2 wallpaper method).
# Stored under IntuneDeploymentFiles (not Images) as it is a config asset.
$script:ThemeFilePath = 'C:\IntuneDeploymentFiles\HallCounty.theme'

# Lock screen policy — ADMX-backed HKLM path, equivalent to applying the
# "Force a specific default lock screen and logon image" Group Policy setting.
# This is the correct path for Windows Pro; PersonalizationCSP is not used.
$script:PersonalizationPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

# Default User profile hive — wallpaper values and CurrentTheme are written here
# so that new user profiles inherit them on first login.
$script:DefaultHivePath    = 'C:\Users\Default\NTUSER.DAT'
$script:TempHiveMountPoint = 'HKU\TempDefault'

# Explicit 64-bit path to reg.exe. When this script is launched via SysNative
# PowerShell, $env:SystemRoot\System32 correctly resolves to the 64-bit System32.
# reg.exe is used for hive operations (not the PS Registry provider) to ensure
# no provider handles are held against the mounted hive during reg unload.
$script:RegExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'

# Marker and error log
$script:MarkerRoot = 'C:\IntuneAppMarkers'
$script:MarkerPath = Join-Path -Path $script:MarkerRoot -ChildPath 'System-Device_Branding.tag'
$script:LogRoot    = 'C:\IntuneAppLogs'
$script:LogFile    = Join-Path -Path $script:LogRoot    -ChildPath 'DeviceBranding_Install.txt'

# =============================================================================
# END CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# Logging — error-only, buffered. Log file is created only when warnings or
# errors occur. Appends across runs so prior output is preserved.
# -----------------------------------------------------------------------------
$script:LogBuffer   = [System.Collections.Generic.List[string]]::new()
$script:HasWarnings = $false
$script:HasErrors   = $false

function Add-LogLine {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    try {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        [void]$script:LogBuffer.Add("$Timestamp [$Level] $Message")
    }
    catch { }
    if ($Level -eq 'WARN')  { $script:HasWarnings = $true }
    if ($Level -eq 'ERROR') { $script:HasErrors   = $true }
}

function Initialize-LogPath {
    try   { [System.IO.Directory]::CreateDirectory($script:LogRoot) | Out-Null; return $true }
    catch { return $false }
}

function Write-LogIfNeeded {
    try {
        if (-not ($script:HasWarnings -or $script:HasErrors)) { return }
        if (-not (Initialize-LogPath)) { return }
        try   { $RunHeader = "=== Run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') v$($script:AppVersion) ===" }
        catch { $RunHeader = '=== Run (timestamp unavailable) ===' }
        $Lines = (@('', $RunHeader) + $script:LogBuffer.ToArray()) -join [System.Environment]::NewLine
        [System.IO.File]::AppendAllText($script:LogFile, $Lines + [System.Environment]::NewLine,
            [System.Text.Encoding]::UTF8)
    }
    catch { }
}

# -----------------------------------------------------------------------------
# Marker Handling
# -----------------------------------------------------------------------------
function Write-Marker {
    param([Parameter(Mandatory)][string[]]$Lines)
    try {
        [System.IO.Directory]::CreateDirectory($script:MarkerRoot) | Out-Null
        [System.IO.File]::WriteAllLines($script:MarkerPath, $Lines, [System.Text.Encoding]::UTF8)
    }
    catch {
        Add-LogLine -Message "Failed to write marker file: $($_.Exception.Message)" -Level 'WARN'
    }
}

function New-MarkerLines {
    param(
        [Parameter(Mandatory)][string]$Status,
        [string[]]$AdditionalLines = @()
    )
    try { $Ts = Get-Date -Format 'o' } catch { $Ts = '(unavailable)' }
    return [string[]](@(
        "Status=$Status"
        "ScriptVersion=$($script:AppVersion)"
        "Timestamp=$Ts"
    ) + $AdditionalLines)
}

# -----------------------------------------------------------------------------
# Copy-BrandingImages
#
# Copies HCWallpaper.jpg and HCLockScreen.jpg from the package directory to the
# durable machine-wide destination. Creates the destination folder if needed.
# Both image files must be present in the package before packaging.
# -----------------------------------------------------------------------------
function Copy-BrandingImages {
    # [SYSTEM/PERMISSIONS] — Creates C:\IntuneDeploymentFiles\Images if absent.
    # NTFS ACL inheritance from C:\ grants Authenticated Users read access.
    [System.IO.Directory]::CreateDirectory($script:ImageDest) | Out-Null

    # A missing source image is a packaging error. Throw so the outer catch
    # logs it and exits 0 without a marker, allowing Intune to retry.
    if (-not (Test-Path -LiteralPath $script:WallpaperSource -PathType Leaf)) {
        throw "Wallpaper image not found in package at '$($script:WallpaperSource)' — check package contents."
    }
    if (-not (Test-Path -LiteralPath $script:LockScreenSource -PathType Leaf)) {
        throw "Lock screen image not found in package at '$($script:LockScreenSource)' — check package contents."
    }

    # -Force overwrites existing files. Script is safe to re-run (idempotent).
    Copy-Item -LiteralPath $script:WallpaperSource  -Destination $script:WallpaperDest  -Force -ErrorAction Stop
    Copy-Item -LiteralPath $script:LockScreenSource -Destination $script:LockScreenDest -Force -ErrorAction Stop
}

# -----------------------------------------------------------------------------
# Set-LockScreenPolicy
#
# Writes ADMX-backed Group Policy-equivalent registry values to HKLM that
# enforce the Hall County lock screen on every user session on this machine.
#
# LockScreenImage:      Path to the lock screen image. Windows reads this from
#                       HKLM, so it applies to all users without per-user config.
#
# NoChangingLockScreen: DWORD 1. Grays out and disables the lock screen section
#                       in Settings > Personalization > Lock screen for all users.
#
# These values are retroactive — existing user accounts see the change on their
# next lock screen display. No restart or logoff is required.
# -----------------------------------------------------------------------------
function Set-LockScreenPolicy {
    # [SYSTEM] — HKLM writes require elevation. Win32 app SYSTEM context provides this.
    if (-not (Test-Path -LiteralPath $script:PersonalizationPolicyKey)) {
        New-Item -Path $script:PersonalizationPolicyKey -Force -ErrorAction Stop | Out-Null
    }

    Set-ItemProperty -Path  $script:PersonalizationPolicyKey `
                     -Name  'LockScreenImage' `
                     -Value $script:LockScreenDest `
                     -Type  String `
                     -Force -ErrorAction Stop

    Set-ItemProperty -Path  $script:PersonalizationPolicyKey `
                     -Name  'NoChangingLockScreen' `
                     -Value 1 `
                     -Type  DWord `
                     -Force -ErrorAction Stop
}

# -----------------------------------------------------------------------------
# New-BrandingThemeFile
#
# Generates C:\IntuneDeploymentFiles\HallCounty.theme — a minimal Windows theme
# file that declares the Hall County wallpaper path and display style.
#
# This file is referenced by the CurrentTheme registry value written into the
# Default User hive by Set-DefaultUserWallpaper. When a new user logs in,
# Windows Explorer reads CurrentTheme, loads this file, and applies the theme
# (including the wallpaper). This fires after the OS's default theme provisioning
# and takes precedence, ensuring the wallpaper survives the Windows 11 first-
# login experience on all known builds.
#
# The [VisualStyles] section uses %SystemRoot% (expanded by the theme engine,
# not by PowerShell) and references Aero.msstyles, which is present on both
# Windows 10 LTSC 1809 and Windows 11 Pro. A missing or incorrect VisualStyles
# entry would prevent the theme from applying at all, so the standard Aero path
# is used rather than leaving this section empty.
#
# Written UTF-8 without BOM for broadest compatibility with the Windows theme
# engine across all target OS versions.
# -----------------------------------------------------------------------------
function New-BrandingThemeFile {
    # IntuneDeploymentFiles root must exist before writing the theme file.
    # Images subfolder was already created by Copy-BrandingImages, so the
    # parent folder exists — this call is a safe guard.
    [System.IO.Directory]::CreateDirectory(
        [System.IO.Path]::GetDirectoryName($script:ThemeFilePath)
    ) | Out-Null

    # Build the theme file content as a string array joined with explicit CRLF.
    # A here-string was avoided here: its line endings match the .ps1 source file's
    # line endings, meaning a script saved with LF-only endings (Unix/Git LF mode)
    # would produce a theme file with LF-only line endings. While the Windows INI
    # parser accepts both, explicit CRLF matches what the OS writes for .theme files
    # and eliminates any source-file dependency.
    #
    # %SystemRoot% in the [VisualStyles] path is a literal string — the Windows
    # theme engine expands it at apply time. PowerShell does NOT expand it here.
    #
    # [Slideshow] is intentionally omitted. Specifying the section without supplying
    # image items (Item0Path, ImagesRootPath, etc.) causes Explorer to configure a
    # slideshow with zero images on some Windows 11 builds, which renders a black
    # desktop background instead of the intended wallpaper.
    $ThemeLines = @(
        '[Theme]'
        'DisplayName=Hall County'
        ''
        '[Control Panel\Desktop]'
        "Wallpaper=$($script:WallpaperDest)"
        'TileWallpaper=0'
        'WallpaperStyle=10'
        'Pattern='
        ''
        '[VisualStyles]'
        'Path=%SystemRoot%\Resources\Themes\Aero\Aero.msstyles'
        'ColorStyle=NormalColor'
        'Size=NormalSize'
        'AutoColorization=0'
    )
    $ThemeContent = ($ThemeLines -join "`r`n") + "`r`n"

    # UTF-8 without BOM — use explicit UTF8Encoding constructor to suppress the BOM
    # that [System.Text.Encoding]::UTF8 would otherwise include.
    $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($script:ThemeFilePath, $ThemeContent, $Utf8NoBom)
}

# -----------------------------------------------------------------------------
# Set-DefaultUserWallpaper
#
# Mounts C:\Users\Default\NTUSER.DAT to a temporary registry mount point, writes
# all wallpaper-related registry values, then unmounts. New user profiles created
# after this runs will inherit the Hall County wallpaper as their starting desktop
# background. Existing profiles are not modified. Users may change freely.
#
# TWO SETS OF VALUES ARE WRITTEN (both inside the single hive load/unload cycle):
#
#   Layer 1 — Control Panel\Desktop
#     Wallpaper, WallpaperStyle, TileWallpaper
#     Classic registry method; reliable on Windows 10 LTSC 1809.
#
#   Layer 2 — Software\Microsoft\Windows\CurrentVersion\Themes
#     CurrentTheme = path to HallCounty.theme
#     Modern theme method; ensures the wallpaper survives Windows 11's
#     first-login theme provisioning. New-BrandingThemeFile must be called
#     before this function so the theme file exists at the referenced path.
#
# reg.exe is used for all hive operations. The PowerShell Registry provider is
# intentionally not used — provider objects hold handles against the mounted hive
# and prevent reg unload from succeeding.
#
# WallpaperStyle values (REG_SZ strings):
#   "0" = Center  "2" = Stretch  "6" = Fit  "10" = Fill  "22" = Span
# -----------------------------------------------------------------------------
function Set-DefaultUserWallpaper {
    $HiveLoaded = $false

    try {
        # Pre-emptive unload: if a previous run was terminated after 'reg load' but
        # before 'reg unload' (process killed, machine rebooted mid-script, power loss),
        # the HKU\TempDefault mount point persists in HKEY_USERS across reboots as a
        # stale registration. A subsequent 'reg load' to the same name fails with exit
        # code 1 (the mount point already exists), so no marker is ever written and
        # Intune retries indefinitely. Attempting an unload first clears any stale
        # mount. If nothing is loaded, reg unload fails silently — we discard the result.
        & $script:RegExe unload $script:TempHiveMountPoint 2>&1 | Out-Null

        if (-not (Test-Path -LiteralPath $script:DefaultHivePath -PathType Leaf)) {
            throw "Default User hive not found at '$($script:DefaultHivePath)'."
        }

        # Load the Default User hive to a temporary mount point.
        # [SYSTEM/PERMISSIONS] — reg load requires SYSTEM or local Administrator.
        # During White Glove technician phase this hive is never actively loaded,
        # so the load operation reliably succeeds.
        $LoadOutput = & $script:RegExe load $script:TempHiveMountPoint $script:DefaultHivePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed (exit $LASTEXITCODE): $LoadOutput"
        }
        $HiveLoaded = $true

        # --- Layer 1: Control Panel\Desktop ---
        $DesktopKey = "$script:TempHiveMountPoint\Control Panel\Desktop"

        $Out1 = & $script:RegExe add $DesktopKey /v 'Wallpaper'      /t REG_SZ /d $script:WallpaperDest /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to set Wallpaper value (exit $LASTEXITCODE): $Out1" }

        # "10" = Fill: proportional scale to cover the screen, cropping as needed.
        $Out2 = & $script:RegExe add $DesktopKey /v 'WallpaperStyle' /t REG_SZ /d '10' /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to set WallpaperStyle value (exit $LASTEXITCODE): $Out2" }

        # TileWallpaper must be "0" when WallpaperStyle is set to any non-tiled value.
        $Out3 = & $script:RegExe add $DesktopKey /v 'TileWallpaper'  /t REG_SZ /d '0'  /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to set TileWallpaper value (exit $LASTEXITCODE): $Out3" }

        # --- Layer 2: CurrentTheme ---
        # Points the new user's starting theme at HallCounty.theme. Windows Explorer
        # reads this on first login and applies the theme, including the wallpaper.
        # reg.exe creates the Themes key if it does not already exist in the hive.
        $ThemeKey = "$script:TempHiveMountPoint\Software\Microsoft\Windows\CurrentVersion\Themes"

        $Out4 = & $script:RegExe add $ThemeKey /v 'CurrentTheme' /t REG_SZ /d $script:ThemeFilePath /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to set CurrentTheme value (exit $LASTEXITCODE): $Out4" }
    }
    finally {
        if ($HiveLoaded) {
            # Collect any residual .NET handles before issuing reg unload.
            # Even though the PS Registry provider was not used, this is a safe
            # precaution to avoid access-denied failures on unload.
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            $UnloadOutput = & $script:RegExe unload $script:TempHiveMountPoint 2>&1
            if ($LASTEXITCODE -ne 0) {
                # [SYSTEM] — Unload failure is uncommon. The hive will eventually be
                # released by the OS. Log a warning but do not throw — all registry
                # values were already written successfully before this point.
                Add-LogLine -Message "reg unload warning (exit $LASTEXITCODE): $UnloadOutput" -Level 'WARN'
            }
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================
try {
    # Step 1 — Copy branding images from the package to C:\IntuneDeploymentFiles\Images\
    Copy-BrandingImages

    # Step 2 — Apply enforced lock screen policy (HKLM, retroactive for all users)
    Set-LockScreenPolicy

    # Step 3 — Generate the Hall County theme file at C:\IntuneDeploymentFiles\HallCounty.theme
    #           Must run before Set-DefaultUserWallpaper so the file exists when its
    #           path is written into the Default User hive as CurrentTheme.
    New-BrandingThemeFile

    # Step 4 — Set default wallpaper for new user profiles (Layer 1 + Layer 2)
    Set-DefaultUserWallpaper

    $FinalStatus = if ($script:HasWarnings) { 'CompletedWithWarnings' } else { 'Success' }

    Write-Marker -Lines (New-MarkerLines -Status $FinalStatus -AdditionalLines @(
        "WallpaperDest=$($script:WallpaperDest)"
        "LockScreenDest=$($script:LockScreenDest)"
        "ThemeFilePath=$($script:ThemeFilePath)"
    ))
    Write-LogIfNeeded
    exit 0
}
catch {
    # Unhandled exception — log the error and exit 0 WITHOUT writing the marker.
    # Omitting the marker allows Intune to retry on the next detection cycle.
    # Branding failures must not block the ESP dependency chain.
    try { Add-LogLine -Message "Installation failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Level 'ERROR' } catch { }
    try { Write-LogIfNeeded } catch { }
    exit 0
}
