---
name: Intune Paths Reference - IME Runtime Folders, Logs, Registry Keys
description: Current IME-rooted runtime folders, legacy fallback paths, diagnostic log locations, and key registry paths for Intune/Autopilot work
type: reference
---
## Current IME-Rooted Runtime Routes

All new script-created Intune runtime files belong under:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension
```

| Path | Purpose |
|---|---|
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` | All script-authored Intune deployment logs, alongside IME logs |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Images` | Images, icons, wallpapers, lock screen files, and background images |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers` | Marker `.tag`/`.marker` files used for Win32 app custom detection |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles` | Durable script data, helper scripts, config files, shell layout files, and similar non-image runtime files |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles` | Device-identification text files read directly by a paired Detect.ps1 (e.g. `DevicePrefix.txt` for Device Rename, `Serial - <SERIAL>.txt` for Serial Marker) - see correction note below |

PDQ-deployed apps additionally get their own marker root, separate from Intune's:

```text
C:\ProgramData\PDQ\AppMarkers
```

Use package-specific subfolders under `Images` or `ScriptFiles` when multiple
files are staged or when file names could collide.

## Legacy Fallback Routes

New scripts should not write to these locations unless a specific migration task
requires it. Detection scripts may check them after the current IME-rooted path
to remain compatible with already deployed packages.

| Legacy Path | Current Replacement |
|---|---|
| `C:\IntuneAppMarkers` | `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers` |
| `C:\IntuneDeploymentFiles` | `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles` |
| `C:\IntuneDeploymentFiles\Images` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Images` |
| `C:\IntuneScripts` | `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles` |
| `C:\ProgramData\HallCountyMIS` | Use the matching current `AppMarkers`, `Images`, or `ScriptFiles` folder |
| `C:\IntuneAppLogs` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` |
| `C:\IntuneScriptLogs` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` |

**Correction (2026-08-26):** this file previously listed
`C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles` as a legacy
path replaced by `ScriptFiles`. That was wrong - it is still actively used
by current, in-production scripts (`Rename-Device-System.ps1` v1.0.3, last
revised 2026-07-01, writes `DevicePrefix.txt` there) as the standard
location for a plain-text identification file that a paired `Detect.ps1`
reads directly. `ScriptFiles` remains correct for durable script data,
helper scripts, config files, and shell layout files - `IntuneFiles` is the
right location specifically for simple per-device identification text
files consumed by that same package's own detection script. Do not
classify `IntuneFiles` as legacy without new evidence it has actually been
migrated away from.

**Log naming conventions:**
- Scripts under workspace `Software`: `APP_<AppName>_Install.txt`
- Software uninstall logs: `APP_<AppName>_Uninstall.txt`
- Scripts under workspace `System Scripts`: `SCRIPT_<ScriptName>_Install.txt`
- System script uninstall logs: `SCRIPT_<ScriptName>_Uninstall.txt`
- All of the above live under
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

**Marker naming and versioning convention (2026-08-20 policy):**
- Intune marker: `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\<AppName>.marker`
- PDQ marker (separate root, secondary authority): `C:\ProgramData\PDQ\AppMarkers\<AppName>.marker`
- Every marker written by a new or remediated script must contain a
  `Version=` line - the real software version, or the file's download date
  (`yyyy-MM-dd`) if no real version is available.
- Detection compares the marker's `Version=` against the script's required
  version, not just existence. A marker with no `Version=` line at all
  (pre-policy or legacy) is accepted as detected for now - temporary
  migration leniency, phased out once all scripts are remediated.
- A PDQ marker only satisfies detection if its version is at least the
  required version - its sole purpose is preventing Intune from
  reinstalling a version PDQ already deployed. Once an Intune install
  completes, the install script must delete any PDQ marker for that same
  app - Intune is authoritative from that point on.
- Full templates, comparison functions, and the detection check order:
  `reference_intune_detection.md`, `reference_intune_code_patterns.md`.

---

## IME Diagnostic Log Locations

| Log File | What It Covers |
|---|---|
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` | Policy/check-in flow, app assignment, general IME activity |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log` | Platform PowerShell script execution (script results, exit codes) |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log` | Win32 app workflow: detection, install, uninstall, exit codes, durations |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppActionProcessor.log` | Applicability evaluation, detection logic selection |
| `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthScripts.log` | Remediation scripts, custom compliance, health script execution |

**Key AppWorkload.log fields for diagnosis:**
- `lpExitCode` — the exit code from the install/uninstall/detection process
- `DetectionType` — `1`=MSI, `2`=File, `3`=Registry/custom PS, varies by version
- Process duration in milliseconds — sub-1-second duration = crash before script logic

---

## Registry Key Reference

### Lock Screen Staging - PersonalizationCSP Registry Store

```
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP
  LockScreenImagePath    REG_SZ    C:\ProgramData\Microsoft\IntuneManagementExtension\Images\HCLockScreen.jpg
```

- `LockScreenImageStatus` is a CSP readback/status node. Do not write it in install scripts.
- Microsoft documents PersonalizationCSP as Enterprise/Education-supported, with Pro support only under specific Shared PC / BootToCloudPC conditions.
- Direct registry writes to this key are a workaround, not proof that supported MDM CSP policy delivery occurred.
- For Device Branding, detection may verify that `LockScreenImagePath` was staged, but it must not claim the OS consumed the value.
- If lock enforcement is required on Windows Pro, Device Branding uses the Group Policy path:

```
HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization
  LockScreenImage    REG_SZ    C:\ProgramData\Microsoft\IntuneManagementExtension\Images\HCLockScreen.jpg
```

### Default User Wallpaper (New Profiles Only)

Written via `reg.exe` to mounted hive at `HKU\TempDefault`:

```
HKU\TempDefault\Control Panel\Desktop
  Wallpaper       REG_SZ   C:\ProgramData\Microsoft\IntuneManagementExtension\Images\HCWallpaper.jpg
  WallpaperStyle  REG_SZ   10       (10 = Fill/Fit; 2 = Stretch; 0 = Center; 6 = Fit; 22 = Span)
  TileWallpaper   REG_SZ   0

HKU\TempDefault\Software\Microsoft\Windows\CurrentVersion\Themes
  CurrentTheme    REG_SZ   C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\DeviceBranding\HallCounty.theme
```

- `WallpaperStyle` values: `0`=Center, `2`=Stretch, `6`=Fit, `10`=Fill, `22`=Span
- `TileWallpaper` `0`=no tile, `1`=tile
- `CurrentTheme` value points to the `.theme` file for Windows 11 first-login theme layer

### Theme File Deployment Path

```
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\DeviceBranding\HallCounty.theme
```

File format: INI-format, UTF-8 no BOM, explicit CRLF line endings

### Default User Hive

```
C:\Users\Default\NTUSER.DAT
```

Mount point (temporary, during script): `HKU\TempDefault`

### Legacy Intune Marker Path (Device Branding)

```
C:\ProgramData\HallCountyMIS\DeviceBranding.marker
```

Contains `ScriptVersion=X.X.X` line. Detect.ps1 validates version match (not just existence).
Note: this is a legacy Device Branding-specific path. New markers should use
`C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers` with the
`Version=` line convention documented above.

---

## WallpaperStyle Values Quick Reference

| Value | Meaning |
|---|---|
| `0` | Center |
| `2` | Stretch |
| `6` | Fit (letterbox) |
| `10` | Fill (crop to fill) |
| `22` | Span (multi-monitor) |

---

## Key Package-Relative Paths (from `$PSScriptRoot`)

When files are bundled in the Intune `.intunewin` package alongside the main script:

```powershell
$script:WallpaperSource   = Join-Path -Path $PSScriptRoot -ChildPath 'HCWallpaper.jpg'
$script:LockScreenSource  = Join-Path -Path $PSScriptRoot -ChildPath 'HCLockScreen.jpg'
```

`$PSScriptRoot` is the directory of the currently executing `.ps1` file. In Intune Win32 context, this is the extracted package directory. Never hardcode this path.

---

## Intune App Packaging — `IntuneWinAppUtil.exe`

Packaging tool: `IntuneWinAppUtil.exe`

```
IntuneWinAppUtil.exe -c <source_folder> -s <setup_file.ps1> -o <output_folder>
```

- `-c` = folder containing the script and all supporting files
- `-s` = the primary script file (e.g., `System-Device_Branding.ps1`)
- `-o` = output folder for the `.intunewin` file

All files in `-c` folder are bundled. The `-s` script becomes the extractable root. Supporting files (images, configs) placed in the same folder are accessible via `$PSScriptRoot` at runtime.
