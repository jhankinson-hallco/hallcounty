# Hall County Device Branding - Settings Reference

**Package**: System Scripts / Device Branding
**Current version**: 2.2.1
**Last updated**: 07/05/2026 (Intune launcher commands hardened after White Glove failure)

This file documents every setting applied by the Device Branding package. It is a
reference for both human administrators and AI assistants. It does NOT control the
scripts; it describes what the scripts do. Use it to audit compliance, plan changes,
and brief AI assistants on the current state of branding without requiring a full
script read.

To add, remove, or modify a setting: update this file first to record the intent,
then implement the change in the appropriate script and asset file.

---

## Deployment Commands

| Field | Value |
|-------|-------|
| **Install command** | `%SystemRoot%\System32\cmd.exe /d /c .\Install-Device_Branding.cmd` |
| **Uninstall command** | `%SystemRoot%\System32\cmd.exe /d /c .\Uninstall-Device_Branding.cmd` |
| **Install behavior** | System |
| **Restart behavior** | No specific action |
| **Detection** | Custom script: `Detect.ps1`; Run as 32-bit: No; Signature check: No |

Do not call `SysNative\WindowsPowerShell\v1.0\powershell.exe` directly from the
Win32 app install/uninstall command. White Glove logs from 07/05/2026 showed IME
launching the installer from a 64-bit context, where `SysNative` does not exist,
causing `CreateProcess` error 2 / `0x80070002` before the PowerShell script ran.
The package CMD launchers choose `SysNative` when available and fall back to
`System32` when IME is already 64-bit.

---

## Applied Settings

### 1. Desktop Wallpaper

| Field | Value |
|-------|-------|
| **Source file** | `HCWallpaper.jpg` (in package) |
| **Deployed to** | `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` |
| **Storage mechanism** | NTUSER.DAT (Default User hive replacement) |
| **Registry location (inside hive)** | `HKCU\Control Panel\Desktop` |
| **Registry values (inside hive)** | `Wallpaper` = `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg`; `WallpaperStyle` = `10` (Fill); `TileWallpaper` = `0` |
| **Scope** | New user profiles only -- profiles created AFTER this package installs |
| **Existing profiles** | NOT affected -- wallpaper is baked into the Default User hive only |
| **Lock mechanism** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop` |
| **Lock values** | `Wallpaper` (REG_SZ path); `WallpaperStyle` (REG_SZ `10`) |
| **Lock toggle** | `$script:LockWallpaper` in `System-Device_Branding.ps1` CONFIGURATION region |
| **Default lock state** | `$false` (unlocked -- user can change freely after first logon) |

**Notes**: The wallpaper path baked into `DefaultUser.NTUSER.DAT` must match the
deployed destination path `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` exactly.
Verify this is correct any time the image destination path changes.

**Hive verification**: Mounted inspection on 06/05/2026 confirmed the packaged
`DefaultUser.NTUSER.DAT` contains `Wallpaper`, `WallpaperStyle`, and `TileWallpaper`
values matching the table above.

---

### 2. Lock Screen Image

| Field | Value |
|-------|-------|
| **Source file** | `HCLockScreen.jpg` (in package) |
| **Deployed to** | `C:\IntuneDeploymentFiles\Images\HCLockScreen.jpg` |
| **Storage mechanism** | Registry (machine-wide, direct write) |
| **Registry location** | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP` |
| **Registry value** | `LockScreenImagePath` (REG_SZ) = `C:\IntuneDeploymentFiles\Images\HCLockScreen.jpg` |
| **Scope** | Machine-wide; applies to all users immediately after install |
| **Lock mechanism** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` |
| **Lock value** | `LockScreenImage` (REG_SZ path) |
| **Lock toggle** | `$script:LockLockScreen` in `System-Device_Branding.ps1` CONFIGURATION region |
| **Default lock state** | `$false` (unlocked -- user can change via Windows Settings) |

**Notes**: PersonalizationCSP is officially supported on Enterprise/Education SKUs only.
On Windows 11 Pro (non-Shared PC) the CSP path is a pragmatic registry workaround.
Whether Windows 11 Pro honors the CSP registry values is unconfirmed without field
testing on a Hall County Pro device. The lock mechanism uses the Group Policy path
(`HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization`), which is documented
as a Pro-compatible alternative. Field test required before declaring either path
reliable on the Hall County fleet.

---

### 3. Start Menu Pinned Apps

| Field | Value |
|-------|-------|
| **Storage mechanism** | JSON file (`LayoutModification.json`) |
| **Deployed to (Default User)** | `C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json` |
| **Deployed to (staged)** | `C:\IntuneDeploymentFiles\Shell\LayoutModification.json` |
| **Per-user materialization** | Inherited from the Default User profile at profile creation; no logon helper is installed |
| **JSON schema key** | `pinnedList` |
| **Apply behavior** | Intended replace-mode when Windows consumes the JSON: the Start pin list should match the entries below |
| **Missing apps** | Intended to be skipped silently -- if an app in the list is not installed, its slot should be omitted |
| **Unlisted apps** | Intended to be removed from Start if the JSON is consumed |
| **applyOnce** | `true` -- honored on Windows 11 24H2 with KB5062660+; silently ignored on older builds |
| **Lock mechanism** | None -- Start pin locking requires an Intune policy profile (OMA-URI or CSP) |
| **Windows compatibility** | Best-effort on Windows 11; Windows 10 does not consume this JSON layout path. Exact behavior must be proven on target Windows 11 builds. |

**Pinned apps (in order)**:

| Position | App | ID type | App ID |
|----------|-----|---------|--------|
| 1 | Company Portal | packagedAppId | `Microsoft.CompanyPortal_8wekyb3d8bbwe!App` |
| 2 | OneDrive | desktopAppId | `Microsoft.SkyDrive.Desktop` |
| 3 | Word | desktopAppId | `Microsoft.Office.WINWORD.EXE.15` |
| 4 | Excel | desktopAppId | `Microsoft.Office.EXCEL.EXE.15` |
| 5 | PowerPoint | desktopAppId | `Microsoft.Office.POWERPNT.EXE.15` |
| 6 | Microsoft Edge | desktopAppId | `MSEdge` |
| 7 | File Explorer | desktopAppId | `Microsoft.Windows.Explorer` |
| 8 | Settings | packagedAppId | `windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel` |
| 9 | Notepad | packagedAppId | `Microsoft.WindowsNotepad_8wekyb3d8bbwe!App` |
| 10 | Calculator | packagedAppId | `Microsoft.WindowsCalculator_8wekyb3d8bbwe!App` |

**Notes**: This package uses the managed/exported `pinnedList` schema in the Default
User Shell folder. Microsoft documents the Shell folder for OEM image customization,
and documents `pinnedList` for managed Start pin policy. This hybrid must be
field-tested on the exact Hall County Windows builds before declaring Start pin
replacement reliable.

Office `desktopAppId` values use the `.15` suffix. Validate these IDs
match the actual installed Office/M365 version on the Hall County image. Per the
missing-app behavior (REQ-7), a wrong ID silently results in no pin -- not a failure.
LinkedIn and other OEM-pinned shortcuts not in this list will be removed from Start.

---

### 4. Taskbar Pinned Apps

| Field | Value |
|-------|-------|
| **Storage mechanism** | JSON file (`LayoutModification.json` taskbar section) |
| **JSON schema key** | `taskbar.pinnedList` |
| **Apply behavior** | Intended preferred taskbar list only; not guaranteed by Microsoft documentation for this JSON placement |
| **Missing apps** | Intended to be skipped silently if the mechanism is honored |
| **Unlisted apps** | Intended to be removed only if the mechanism is honored |
| **Lock mechanism** | None -- taskbar pin locking requires an Intune policy profile |
| **Windows compatibility** | Best-effort only. Microsoft documents taskbar pinning through XML/policy/image-time methods, not this JSON Shell-folder path. Behavior must be proven on target builds. |

**Pinned apps (in order)**:

| Position | App | ID type | App ID |
|----------|-----|---------|--------|
| 1 | Company Portal | packagedAppId | `Microsoft.CompanyPortal_8wekyb3d8bbwe!App` |
| 2 | OneDrive | desktopAppId | `Microsoft.SkyDrive.Desktop` |
| 3 | Microsoft Edge | desktopAppId | `MSEdge` |
| 4 | File Explorer | desktopAppId | `Microsoft.Windows.Explorer` |

**Reference file (NOT active)**: `TaskbarLayoutModification.xml` is staged at
`C:\IntuneDeploymentFiles\Shell\TaskbarLayoutModification.xml` as a reference artifact
only. The XML-based `LayoutXMLPath` mechanism is image-time only and is not a supported
post-OOBE taskbar apply path. It is NOT copied or activated at runtime.

---

### 5. Additional Default User Hive Values

The values below are present inside the packaged `DefaultUser.NTUSER.DAT`.
`System-Device_Branding.ps1` does not write these values one by one; however, the
script replaces `C:\Users\Default\NTUSER.DAT` with the packaged hive, so these
values become defaults for every new profile created after install.

If any value below is not intended, rebuild or minimize `DefaultUser.NTUSER.DAT`.
Do not assume an undocumented value is harmless just because the installer does not
touch that key directly.

#### 5.1 Explorer / Start Defaults

| Registry location | Value | Kind | Data | Notes |
|-------------------|-------|------|------|-------|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_IrisRecommendations` | REG_DWORD | `0` | Start recommendations-related shell value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_Layout` | REG_DWORD | `1` | Start layout mode shell value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_SearchFiles` | REG_DWORD | `2` | Windows Search / Start search shell value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_TrackDocs` | REG_DWORD | `0` | Recent documents tracking shell value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Start` | `ShowFrequentList` | REG_DWORD | `0` | Start frequent-list value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Start` | `ShowRecentList` | REG_DWORD | `0` | Start recent-list value |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Start` | `Config` | REG_BINARY | Binary payload | Exact binary captured in the hive audit inventory |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Start` | `VisiblePlaces` | REG_BINARY | Binary payload | Exact binary captured in the hive audit inventory |

#### 5.2 Taskbar Shell Defaults

These are Windows shell `SystemSettings_*` values stored under subkeys of
`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`. They are
documented here as raw hive payload values; exact interpretation may vary across
Windows 10/11 builds.

| Registry location | Value | Kind | Data |
|-------------------|-------|------|------|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\MMTaskbarGl` | `SystemSettings_DesktopTaskbar_GroupingMode` | REG_SZ | `2` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton` | `SystemSettings_DesktopTaskbar_TaskView` | REG_SZ | `0` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAl` | `SystemSettings_DesktopTaskbar_Al` | REG_SZ | `0` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa` | `SystemSettings_DesktopTaskbar_Da` | REG_SZ | Empty string |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlom` | `SystemSettings_DesktopTaskbar_GroupingMode` | REG_SZ | `2` |

#### 5.3 System Toast Notification Defaults

Each listed system toast application key contains the same three values:
`ApplicationType` = `1073741824` (REG_DWORD), `Capabilities` = `9471`
(REG_DWORD), and `PackageMoniker` = `System` (REG_SZ).

| Registry base path |
|--------------------|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.CloudExperienceHostLauncherCustom` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.DisplaySettings` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.FodHelper` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.MobilityExperience` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.Suggested` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Applications\Windows.SystemToast.WindowsTip` |

#### 5.4 BrowserCore Native Messaging Host

| Registry location | Value | Kind | Data | Notes |
|-------------------|-------|------|------|-------|
| `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.microsoft.browsercore` | `(Default)` | REG_SZ | `C:\Windows\BrowserCore\manifest.json` | Microsoft BrowserCore native messaging registration for Chrome |

#### 5.5 Hive Inventory Artifacts

Full key/value inventory from the 06/05/2026 mounted-copy audit is archived under:

```text
AI Knowledgebase\System Scripts\Device Branding\Archive\Hive-Audits\
```

Primary files:

- `DefaultUserHiveInventory_20260506T203621Z.csv` -- all registry values
- `DefaultUserHiveKeys_20260506T203621Z.csv` -- all registry keys
- `DefaultUserHiveExport_20260506T203621Z.reg` -- complete REG export
- `DefaultUserHiveAudit_20260506T203621Z.md` -- audit summary

The audit confirmed no HKCU `Run` values, no HKCU policy values, and no
user/environment-specific paths in the packaged hive.

---

## Settings Left at System Default

The following are explicitly NOT altered by this package. Any future change to these
areas requires a new entry above and corresponding script changes.

- Windows theme (colors, sounds, fonts, cursor)
- Desktop icon visibility and arrangement
- Screensaver settings
- Power plan / sleep settings
- Privacy and diagnostic settings
- UAC settings
- Network and VPN settings
- Microsoft Edge browser configuration
- Accessibility settings
- Regional and language settings
- Taskbar position, size, or autohide behavior
- Notification settings beyond the system toast application defaults listed in Section 5
- Start menu behavior beyond the pinned app list and raw hive values listed in Section 5
- Search bar visibility beyond raw hive values listed in Section 5
- Widgets behavior beyond raw hive values listed in Section 5
- Virtual desktop settings
- Any per-user settings for users whose profiles existed before this package installed
  (existing profiles are intentionally left alone)

---

## Asset Files in This Package

| File | Purpose | Deployed to |
|------|---------|-------------|
| `HCWallpaper.jpg` | Desktop wallpaper image | `C:\IntuneDeploymentFiles\Images\` |
| `HCLockScreen.jpg` | Lock screen image | `C:\IntuneDeploymentFiles\Images\` |
| `DefaultUser.NTUSER.DAT` | Pre-configured Default User hive | Replaces `C:\Users\Default\NTUSER.DAT` |
| `LayoutModification.json` | Start + taskbar pin layout | Default User shell folder + staged machine reference copy |
| `TaskbarLayoutModification.xml` | Taskbar layout reference (NOT active post-OOBE) | `C:\IntuneDeploymentFiles\Shell\` (reference only) |
| `Install-Device_Branding.cmd` | Intune-safe installer launcher | Runs package PowerShell installer through 64-bit PowerShell |
| `Uninstall-Device_Branding.cmd` | Intune-safe uninstall launcher | Runs package PowerShell uninstaller through 64-bit PowerShell |
| `System-Device_Branding.ps1` | Main installer | Runs once at install time via Intune |
| `Detect.ps1` | Intune detection script | Runs on every Intune check-in cycle |
| `Uninstall-Device_Branding.ps1` | Uninstall script | Runs on demand via Intune |
| `Device-Branding-Settings.md` | This file -- settings reference | Bundled in .intunewin for reference; no runtime role |

---

## Package Architecture Summary

This package uses three active layers plus legacy cleanup:

**Layer 1 - Default User hive replacement** (`DefaultUser.NTUSER.DAT`)
- Replaces `C:\Users\Default\NTUSER.DAT` with a pre-configured hive
- Every new user profile created on the device inherits wallpaper and preferences
- Does NOT affect profiles that already existed before install

**Layer 2 - Lock screen (machine-wide)**
- Writes `LockScreenImagePath` to the PersonalizationCSP registry key
- Optionally writes to the Group Policy path for enforcement when `LockLockScreen = $true`

**Layer 3 - Start layout (new profiles, file-staged)**
- Places `LayoutModification.json` in the Default User shell folder
- New profiles inherit this file; Windows 11 22H2+ may consume it at shell init

**Legacy cleanup - retired per-user first-logon helper**
- The current package does NOT install `Set-UserBranding.ps1`
- The current package removes the old `Hall County - Device Branding User Apply` ONLOGON task if present
- The current package removes the old `C:\IntuneScripts\DeviceBranding` helper folder and
  `C:\ProgramData\HallCountyMIS\BrandingApplied` marker folder if present
- Future user handling is provided only by Default User hive/profile staging, matching
  the OEM-style requirement that no package script launches at every logon

---

## Design Rules

These rules govern this package and all future changes to it. They were established
by Jeremy Hankinson and are preserved here as the authoritative reference.

1. The package is installed during White Glove / Autopilot and continues to operate
   from there without further Intune input for each new local user account creation.

2. The package should not install a recurring logon script. New local users receive
   branding through the Default User profile contents copied by Windows at profile
   creation. Existing profiles are not reprocessed by a logon helper.

3. The effect mimics an OEM OOBE experience (Lenovo, Dell, HP style): set as default,
   then leave the user alone. We do not have a sysprep / imaging option, so we
   manipulate the manufacturer image to achieve the desired defaults.

4. The package must work regardless of hardware manufacturer. Hall County fleet includes
   Lenovo, Dell, Getac, and others. No manufacturer-specific logic is permitted.

5. The package must be as backwards-compatible with Windows 10 and older Windows 11 as
   possible. Where a feature cannot work on older builds, it must fail gracefully and
   silently, allowing the rest of the package to continue.

6. NTUSER.DAT manipulation is acceptable and expected. The packaged hive is the primary
   vehicle for applying new-user defaults. It is treated as an opaque payload; the
   reference for what is inside it is this file (Section 1 and the 'Settings Left at
   System Default' section).

7. The Start and taskbar pin lists are preferred, not absolute. Apps in the list that
   are not installed on the machine are silently skipped. Apps NOT in the list that
   are currently pinned (e.g., OEM additions like LinkedIn) are removed.

8. Any setting not explicitly listed in this file is left at whatever the system
   default is. Do not touch what is not listed.

9. This file (Device-Branding-Settings.md) is the canonical settings reference. It is
   bundled in the .intunewin package and is updated in sync with every settings change.
   It is both human-readable and AI-readable. It is not connected to the script logic;
   it is documentation only.

10. No settings are locked by default. The OEM model applies: settings are established
    as user defaults and users may change any of them freely after first login.

11. A toggleable lock mechanism exists for the lock screen image and desktop wallpaper.
    The flags `$script:LockWallpaper` and `$script:LockLockScreen` are in the
    CONFIGURATION region of `System-Device_Branding.ps1`. Both default to `$false`.
    When set to `$true`, the corresponding Group Policy registry values are written to
    enforce the setting and gray out the option in Windows Settings. When `$false`,
    any previously written policy values are explicitly removed (cleaned up).

12. Changing only the lock flags (`$script:LockWallpaper`, `$script:LockLockScreen`)
    does NOT constitute a version bump. A version bump is required only for functional
    changes to the scripts, layout files, or image assets.
