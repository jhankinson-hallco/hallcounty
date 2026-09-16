# AI-Audit-Handoff.md

## Current State

- Project: System Scripts / Device Branding
- Current package script version: 2.2.1
- Current companion script versions: installer, detection, and uninstall are at 2.2.1 as of 2026-05-07.
- Deployment type: Microsoft Intune Win32 app, device context
- Primary install script: `System Scripts\Device Branding\System-Device_Branding.ps1`
- Helper script: retired in v2.2.0 and archived at `AI Knowledgebase\System Scripts\Device Branding\Archive\Retired-Runtime-Files\Set-UserBranding_v2.1.0_retired.ps1`
- Detection script: `System Scripts\Device Branding\Detect.ps1`
- Uninstall script: `System Scripts\Device Branding\Uninstall-Device_Branding.ps1`
- Settings reference: `System Scripts\Device Branding\Device-Branding-Settings.md` (current at 2.2.1)
- Current package artifact: no `.intunewin` remains in the source folder. The failed 2026-05-07 package artifact was moved to `AI Knowledgebase\System Scripts\Device Branding\Archive\Stale-Package-Artifacts\System-Device_Branding_2026-05-07_failed-SysNative.intunewin`; Jeremy will build manually when ready.
- Primary behaviors:
  - Copies wallpaper and lock screen images to `C:\IntuneDeploymentFiles\Images`.
  - Stages lock screen path by direct registry write to the PersonalizationCSP registry location. This is a Windows Pro workaround, not confirmed CSP policy delivery.
  - Optionally enforces wallpaper via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop` when `$script:LockWallpaper = $true` (default: `$false`).
  - Optionally enforces lock screen via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` when `$script:LockLockScreen = $true` (default: `$false`).
  - Replaces `C:\Users\Default\NTUSER.DAT` with packaged `DefaultUser.NTUSER.DAT`.
  - Backs up the original Default User hive to `C:\ProgramData\HallCountyMIS\Backups\DeviceBranding`.
  - Writes `DefaultHiveBackup.marker` with backup path, hash, source, origin, timestamp, script version, and lock state.
  - Stages `LayoutModification.json` in Default User Shell and `C:\IntuneDeploymentFiles\Shell`.
  - Does not install any recurring logon helper. Future users inherit the branded hive and Shell-folder files when Windows creates the profile from `C:\Users\Default`.
  - Removes the retired `Hall County - Device Branding User Apply` ONLOGON scheduled task, `C:\IntuneScripts\DeviceBranding`, and `C:\ProgramData\HallCountyMIS\BrandingApplied` if present from older v2.x installs.

## Active Risks

- Lock screen CSP staging (`PersonalizationCSP` key) is a Windows Pro workaround. Field test on one Hall County Pro device is still required to confirm the OS actually honors the value and changes the lock screen. If it fails, `$script:LockLockScreen = $true` applies the Group Policy path (`HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` / `LockScreenImage`) which is a documented Pro-compatible alternative — but this also prevents users from changing the lock screen.
- `LayoutModification.json` Shell-folder file placement with managed/exported `pinnedList` JSON is a best-effort hybrid. Microsoft documents the Shell folder for OEM Start customization and `pinnedList` for managed Start policy, but not this exact combination. It must be proven on exact target Windows builds.
- `taskbar.pinnedList` inside `LayoutModification.json` is higher risk than Start pins. Microsoft taskbar documentation describes XML/policy/image-time mechanisms, not this JSON Shell-folder path as a supported offline post-OOBE mechanism.
- `applyOnce` requires Windows 11 24H2 with KB5062660 or newer documented support. Older Windows 11 builds may ignore it if Windows consumes the inherited JSON.
- App IDs for Company Portal, packaged Notepad, packaged Calculator, and Office apps (`.15` suffix) must be validated on a freshly provisioned Hall County target image.
- Packaged `DefaultUser.NTUSER.DAT` was mounted and fully inventoried on 2026-05-06. `Device-Branding-Settings.md` now documents the wallpaper values plus the additional Start/taskbar/system toast/BrowserCore values carried by the packaged hive.
- Existing user profiles are intentionally not reprocessed by the current package. If Start/taskbar pins do not materialize for new users from Default User staging alone, a new true one-shot mechanism must be designed and tested before any logon-time process is reintroduced.
- No `.intunewin` artifact is currently present in the source folder. Packaging is a manual Jeremy step per shared `AGENTS.md`; assistants must not run `IntuneWinAppUtil.exe`.
- White Glove testing on 2026-05-07 proved direct `SysNative\WindowsPowerShell` Win32 app commands can fail before PowerShell starts when IME launches from a 64-bit context. v2.2.1 requires the documented CMD launcher commands.

## Recent Changes

- 2026-05-07: **v2.2.1** — White Glove triage found Device Branding failed before script launch: IME downloaded/extracted content, set the IMECache working directory, then `CreateProcess` failed with Win32 error 2 / `0x80070002` on direct `C:\WINDOWS\SysNative\WindowsPowerShell\v1.0\powershell.exe`. Added `Install-Device_Branding.cmd` and `Uninstall-Device_Branding.cmd`; updated portal commands to call the launchers through `%SystemRoot%\System32\cmd.exe`; moved the failed `.intunewin` artifact out of source.
- 2026-05-06: **Settings reference full hive inventory** — Updated `Device-Branding-Settings.md` to document every non-wallpaper value found in packaged `DefaultUser.NTUSER.DAT`, resolving the prior mismatch between "settings left at default" language and whole-hive replacement behavior.
- 2026-05-06: **v2.2.0** — Retired the recurring SYSTEM ONLOGON helper model. Installer no longer requires or deploys `Set-UserBranding.ps1`; it removes the old scheduled task/helper/marker folders if present. Detection now requires the retired task to be absent. The helper file was moved from package source to the project archive.
- 2026-05-06: **Codex fresh audit** — Rechecked v2.1.0 after Claude's pass. No script code changes made. Moved stale `.intunewin` out of the source folder; corrected stale `LockScreenImageStatus` guidance in `reference_intune_paths.md`; tightened Start/taskbar documentation to avoid overclaiming `pinnedList` Shell-folder and `taskbar.pinnedList` delivery; added a durable decision documenting the best-effort hybrid Start/taskbar approach.
- 2026-05-06: **v2.1.0** — Full design audit against 12 project requirements. Two hard gaps identified and implemented: (1) REQ-9: created `Device-Branding-Settings.md` settings reference file; (2) REQ-11: added `$script:LockWallpaper` and `$script:LockLockScreen` toggle flags with `Set-WallpaperPolicyLock` and `Set-LockScreenPolicyLock` helper functions writing to standard Group Policy registry paths; uninstall cleans up policy values unconditionally; lock state stored in marker file. Stale `LockScreenImageStatus` description corrected in `reference_personalization_csp.md`.
- 2026-04-30: **v2.0.9** — All five `New-Item -LiteralPath` replaced with `New-Item -Path` (P22+AGENTS.md confirmed blockers); all `[Parameter(Mandatory = $true)]` removed from every helper function per P22 extended finding (simple function pattern eliminates PS 5.1 advanced-function binding failures in SYSTEM/SysNative context); type constraints (`[string]`) retained on `Get-FileSha256` and `Write-DefaultHiveBackupManifest`.
- 2026-04-30: **v2.0.8** — `Write-ErrorLog` I/O switched to `SilentlyContinue`; `New-Item` standardized to `-LiteralPath` in all helper functions (incorrect — subsequently fixed in v2.0.9); `[Parameter(Mandatory = $true)]` added to helper functions (reverted in v2.0.9); `Detect.ps1` removed hardcoded helper version content check; `Detect.ps1` removed SHA256 hash from detection cycle.
- 2026-04-30: **v2.0.7** — Updated install, helper, detection, and uninstall scripts to v2.0.7.
- 2026-04-30: Added app-specific Default User hive backup folder and manifest with SHA256.
- 2026-04-30: Installer now adopts the oldest legacy backup from the prior broad backup folder during upgrade instead of backing up a potentially already-branded hive.
- 2026-04-30: Uninstall now restores the manifest-recorded app-specific backup and validates SHA256 before restore.
- 2026-04-30: Detection now validates backup manifest, helper version, scheduled task principal, AtLogOn trigger, action executable, and helper arguments.
- 2026-04-30: Comments softened for lock screen registry staging, taskbar JSON, and `applyOnce` version dependency.

## Required Validation Before Deployment

- Parse all `.ps1` files with Windows PowerShell 5.1.
- Verify deployed `.ps1` files are UTF-8 with BOM and ASCII-only before packaging.
- Parse `LayoutModification.json` with Windows PowerShell 5.1 `ConvertFrom-Json`.
- Parse `TaskbarLayoutModification.xml` as XML.
- Confirm package source folder does not contain stale `.intunewin` before Jeremy packages manually.
- Jeremy manually builds `.intunewin` after final validation; assistants must not build package artifacts.
- Confirm Intune install/uninstall commands use the v2.2.1 CMD launchers, not direct `SysNative` PowerShell.
- Confirm Intune detection script runs as 64-bit process.
- Confirm install/detect/uninstall versions are synchronized (all are 2.2.1 as of 2026-05-07).
- **OPEN — Field test lock screen on one Hall County Pro device: deploy, reboot, confirm lock screen image actually changes.** (PersonalizationCSP Pro SKU risk — unresolved. Fallback: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` / `LockScreenImage` per P8.)
- Confirm a target device creates `DefaultHiveBackup.marker` and detection passes after install.
- Test uninstall on a disposable target to confirm the manifest-recorded hive backup restores as expected.
- Validate Start/taskbar pins on a freshly provisioned Windows 11 target that matches production build and Store/Company Portal restrictions.

## Latest Work Log

### 2026-05-07 - ChatGPT / Codex White Glove Failure Triage And v2.2.1 Launcher Fix

- Files reviewed:
  - `F:\Logs\WGDevice01\AppWorkload.log`
  - `F:\Logs\WGDevice01\AgentExecutor.log`
  - `F:\Logs\WGDevice01\AppActionProcessor.log`
  - `F:\Logs\WGDevice01\IntuneManagementExtension.log`
  - `F:\Logs\WGDevice01\M365PreCleanup_Remove.txt`
  - `F:\Logs\WGDevice01\HC-RenameDevice_Install.txt`
  - Current Device Branding source files and project documentation
- Files changed:
  - `System Scripts\Device Branding\Install-Device_Branding.cmd` - new 64-bit PowerShell launcher
  - `System Scripts\Device Branding\Uninstall-Device_Branding.cmd` - new 64-bit PowerShell launcher
  - `System Scripts\Device Branding\System-Device_Branding.ps1` - version sync and portal command guidance updated to v2.2.1
  - `System Scripts\Device Branding\Detect.ps1` - version sync to v2.2.1
  - `System Scripts\Device Branding\Uninstall-Device_Branding.ps1` - version sync to v2.2.1
  - `System Scripts\Device Branding\Device-Branding-Settings.md` - deployment commands and asset list updated
  - `AI-Audit-Handoff.md` and `AI-Audit-Decisions.md` - this update and durable launcher decision
  - Moved failed package artifact to `AI Knowledgebase\System Scripts\Device Branding\Archive\Stale-Package-Artifacts\System-Device_Branding_2026-05-07_failed-SysNative.intunewin`
- Findings accepted:
  - Device Rename v2 failed because the AD target name already exists: `TD-MJ0L3BSD` (`HC-RenameDevice_Install.txt`). This is outside Device Branding.
  - Microsoft Office 365 Removal completed successfully from Intune's perspective. Protected AppX provisioned packages were skipped as non-blocking in `M365PreCleanup_Remove.txt`.
  - System: Remove Bloatware - AppX reported success in `AppWorkload.log`.
  - Device Branding failed in ESP before `System-Device_Branding.ps1` ran: `AppWorkload.log` lines 2076-2085 show content extracted, command expanded to `C:\WINDOWS\SysNative\WindowsPowerShell\v1.0\powershell.exe`, and `CreateProcess` failed with Win32 error 2 / `0x80070002`.
- Tests/validation performed:
  - Log-root-cause analysis from copied White Glove logs.
  - Windows PowerShell 5.1 parser: PASS for `System-Device_Branding.ps1`, `Detect.ps1`, and `Uninstall-Device_Branding.ps1`.
  - Encoding: active `.ps1` files retain UTF-8 BOM and have ASCII-only script bodies; CMD launchers are ASCII-only.
  - `LayoutModification.json` parses with Windows PowerShell 5.1 `ConvertFrom-Json`; `TaskbarLayoutModification.xml` parses as XML.
  - Source folder hygiene: PASS. No `.intunewin` and no Default User hive sidecar files remain in package source; both CMD launchers are present.
- Remaining risks or human decisions:
  - Rebuild `.intunewin` manually from the clean source folder and update the Intune app install/uninstall commands to the documented v2.2.1 launcher commands.
  - Re-test White Glove. Rename package will still fail until the existing AD computer account/name collision is resolved.

### 2026-05-06 - ChatGPT / Codex Documented Full Hive Payload

- Files changed:
  - `System Scripts\Device Branding\Device-Branding-Settings.md` - added Section 5 documenting all additional packaged Default User hive values: Explorer/Start defaults, taskbar shell defaults, system toast notification defaults, and BrowserCore native messaging registration.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md` - this update.
- Findings accepted:
  - Documentation was the correct fix for the audit mismatch because the extra values are already present in the approved packaged hive and no script defect required changing runtime behavior.
  - The "Settings Left at System Default" section now excludes/qualifies areas that have raw values in the packaged hive.
- Tests/validation performed:
  - Markdown/source hygiene check only; no active script or hive changes were made.
- Remaining risks or human decisions:
  - If Jeremy decides any documented Section 5 hive value should not be a new-user default, rebuild/minimize `DefaultUser.NTUSER.dat` and rerun the hive inventory.

### 2026-05-06 - ChatGPT / Codex Fresh Audit With Full Hive Inventory

- Files reviewed:
  - `System Scripts\Device Branding\System-Device_Branding.ps1`
  - `System Scripts\Device Branding\Detect.ps1`
  - `System Scripts\Device Branding\Uninstall-Device_Branding.ps1`
  - `System Scripts\Device Branding\Device-Branding-Settings.md`
  - `System Scripts\Device Branding\LayoutModification.json`
  - `System Scripts\Device Branding\TaskbarLayoutModification.xml`
  - `System Scripts\Device Branding\DefaultUser.NTUSER.dat`
  - Project handoff/decisions and targeted references from `MEMORY.md`
- Files changed:
  - Removed generated hive sidecar files from the package source folder: `DefaultUser.NTUSER.dat.LOG1`, `.LOG2`, `.TM.blf`, and `.regtrans-ms` files created by prior direct hive mounting.
  - Created hive audit artifacts under `AI Knowledgebase\System Scripts\Device Branding\Archive\Hive-Audits\`:
    - `DefaultUserHiveInventory_20260506T203621Z.csv` - all registry values in the hive
    - `DefaultUserHiveKeys_20260506T203621Z.csv` - all registry keys in the hive, including empty keys
    - `DefaultUserHiveExport_20260506T203621Z.reg` - complete REG export from mounted audit copy
    - `DefaultUserHiveAudit_20260506T203621Z.md` - summary report
- Findings accepted:
  - Active scripts are PS 5.1 parse-clean, UTF-8 BOM, ASCII-only, and version-synchronized at 2.2.0.
  - Package source folder is clean after cleanup: no `.intunewin`, no active `Set-UserBranding.ps1`, and no hive transaction sidecar files.
  - `DefaultUser.NTUSER.dat` source hash was unchanged by audit: `5A6152601AB907E8E65DB0678FA0EB4559B6269DAAB0A36EB84B56C7BE7D39B3`.
  - Hive was audited by mounting a temp copy, not the source hive. The temp hive was unloaded successfully.
  - Hive contains 27 keys and 35 values. Wallpaper values match documented intent: `Wallpaper=C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg`, `WallpaperStyle=10`, `TileWallpaper=0`.
  - Hive contains no HKCU Run values, no HKCU policy values, and no user/environment-specific paths matching `C:\Users\`, `OneDrive`, `jhankinson`, `Codex`, `Claude`, temp paths, source folder paths, or IME paths.
  - Hive contains additional values not currently listed as applied settings in `Device-Branding-Settings.md`, including Start menu settings under `Explorer\Advanced` and `CurrentVersion\Start`, taskbar-related subkeys under `Explorer\Advanced`, push notification application defaults, and Chrome BrowserCore native messaging registration.
- Audit finding requiring decision:
  - `Device-Branding-Settings.md` said settings not listed are left at system default, but replacing the Default User hive means every value in the packaged hive becomes the new-user default. Resolved later on 2026-05-06 by documenting the extra hive payload values in Section 5 of `Device-Branding-Settings.md`.
- Tests/validation performed:
  - Windows PowerShell 5.1 64-bit parse: PASS for all active `.ps1` files.
  - Encoding: BOM=True and NonASCII=0 for all active `.ps1` files.
  - `LayoutModification.json` parses with PS 5.1 `ConvertFrom-Json`.
  - `TaskbarLayoutModification.xml` parses as XML.
  - Image assets load as JPEG, 3008x2000, 24bpp; wallpaper and lock screen hashes match.
  - Source folder package hygiene check: PASS.
- Remaining risks or human decisions:
  - Decide whether any Section 5 hive values should be removed. If yes, rebuild/minimize `DefaultUser.NTUSER.dat`.
  - First-logon field testing remains required for Start/taskbar layout consumption and lock screen behavior on target Windows builds.

### 2026-05-06 - Claude (claude-sonnet-4-6) — v2.2.0 Fresh Audit

- Files reviewed: `System-Device_Branding.ps1`, `Detect.ps1`, `Uninstall-Device_Branding.ps1`, `Device-Branding-Settings.md`, `AI-Audit-Handoff.md`, `AI-Audit-Decisions.md`; package source folder listing
- Files changed:
  - `System Scripts\Device Branding\Detect.ps1` — description comment corrected: items 2+3 (wallpaper/lock screen images) merged into single item 2 so description count (9) matches code section labels (9). No logic changes.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md` — this update.
- Findings accepted:
  - Parse/encoding/version: all three active scripts PASS (BOM=True NonASCII=0, 2.2.0 everywhere).
  - Package source: `Set-UserBranding.ps1` confirmed absent; no stale `.intunewin` present.
  - Installer variable naming: correct `$script:Legacy*` prefix on installer config vars; uninstall correctly uses `$script:HelperFolder` under its own name space for the same retired path.
  - Step 6 (legacy task removal) is hard-fail (`Exit-Failure`). Correct design: detection requires task to be absent, so if removal fails the install must also fail to avoid detection immediately contradicting the marker.
  - Step 7 (legacy file cleanup) is soft-fail (`Write-ErrorLog`). Correct: stale files have no functional impact on current behavior.
  - Detection logic: absence check for retired task (check 9) is correct; `@(Get-ScheduledTask ... -ErrorAction SilentlyContinue)` returns empty array when task is absent, so `.Count -gt 0` is false and detection passes.
  - NTUSER.dat filename case on disk is `DefaultUser.NTUSER.dat` (lowercase) vs. script reference `DefaultUser.NTUSER.DAT` (uppercase). Windows NTFS is case-insensitive; no runtime impact.
- Findings rejected: None.
- Tests/validation performed:
  - PS 5.1 parse: all three scripts PASS.
  - Encoding: all three scripts BOM=True NonASCII=0.
  - Version: 2.2.0 confirmed in all three scripts.
  - Structural spot-checks: helper absent from source, no stale package, legacy vars correctly named, detection absence-check confirmed present, Step 6 hard-fail confirmed, Step 7 soft-fail confirmed, description count vs. code section count discrepancy identified and fixed.
- Remaining risks or human decisions: (unchanged from previous entry — see Active Risks above)

### 2026-05-06 - ChatGPT / Codex v2.2.0 Helper Retirement

- Files changed:
  - `System Scripts\Device Branding\System-Device_Branding.ps1` - bumped to v2.2.0, removed helper package requirement/deployment/task registration, added legacy helper task/file/marker cleanup.
  - `System Scripts\Device Branding\Detect.ps1` - bumped to v2.2.0, removed positive helper/task checks, added absence check for the retired ONLOGON task.
  - `System Scripts\Device Branding\Uninstall-Device_Branding.ps1` - bumped to v2.2.0, retained legacy helper cleanup with updated comments.
  - `System Scripts\Device Branding\Device-Branding-Settings.md` - updated active architecture and design rules to no recurring logon helper.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Decisions.md` - added durable decision retiring the AtLogOn helper.
  - `AI Knowledgebase\System Scripts\Device Branding\Archive\Retired-Runtime-Files\Set-UserBranding_v2.1.0_retired.ps1` - retired helper moved here from package source.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md` - this update.
- Findings accepted:
  - The prior recurring AtLogOn helper architecture did not meet the literal no-recurring-logon-script requirement.
  - Default User hive/profile staging is now the only future-user mechanism; existing profiles are intentionally not reprocessed.
  - Detection should fail if the retired scheduled task remains, forcing the installer to clean old deployments.
- Validation status:
  - Windows PowerShell 5.1 Desktop 64-bit parse: active `.ps1` files PASS.
  - Encoding: active `.ps1` files BOM=True and NonASCII=0.
  - `LayoutModification.json` parses with PS 5.1 `ConvertFrom-Json`.
  - `TaskbarLayoutModification.xml` parses as XML in PS 5.1.
  - Source folder has no `.intunewin` and no active `Set-UserBranding.ps1`.
  - Registry privilege enablement succeeded for `SeBackupPrivilege` and `SeRestorePrivilege`; packaged `DefaultUser.NTUSER.dat` mounted under `HKU\CodexDeviceBrandingAudit`, wallpaper values were verified, and the hive unloaded successfully.
- Follow-up verification:
  - After Jeremy enabled the required rights, Codex mounted `System Scripts\Device Branding\DefaultUser.NTUSER.dat` and confirmed `HKCU\Control Panel\Desktop\Wallpaper`, `WallpaperStyle`, and `TileWallpaper` match `Device-Branding-Settings.md`.
  - Search inside the mounted hive found the expected `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` path only under `Control Panel\Desktop`.
- Remaining risks or human decisions:
  - First-logon field test is now more important because there is no helper fallback copying JSON into a live user profile.
  - Jeremy must manually build the `.intunewin` after validation.

### 2026-05-06 - ChatGPT / Codex Fresh Audit After Claude v2.1.0

- Files reviewed: all four `.ps1` scripts, `LayoutModification.json`, `TaskbarLayoutModification.xml`, `Device-Branding-Settings.md`, packaged `DefaultUser.NTUSER.dat`, image assets, project handoff/decisions, `reference_intune_paths.md`, `reference_personalization_csp.md`, `reference_start_layout_win11.md`, and current Microsoft Learn pages for PersonalizationCSP, Start layout, and taskbar layout.
- Files changed:
  - `System Scripts\Device Branding\Device-Branding-Settings.md` - clarified Start/taskbar delivery as intended/best-effort rather than guaranteed.
  - `AI Knowledgebase\reference_intune_paths.md` - removed stale guidance saying `LockScreenImageStatus` should be written.
  - `AI Knowledgebase\reference_start_layout_win11.md` - documented the OEM-vs-managed JSON schema distinction and taskbar uncertainty.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Decisions.md` - added durable decision for the best-effort hybrid Start/taskbar approach.
  - `AI Knowledgebase\System Scripts\Device Branding\Archive\Stale-Package-Artifacts\System-Device_Branding_2026-05-01_stale.intunewin` - stale package artifact moved here from the source folder.
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md` - this update.
- Findings accepted:
  - Current `.ps1` source is syntactically clean and PS 5.1-compatible in static validation.
  - Stale `.intunewin` was present in the source folder despite the prior handoff saying it had been removed. Moved out of source to prevent accidental nested packaging.
  - `reference_intune_paths.md` still contradicted the accepted `LockScreenImageStatus` decision. Corrected.
  - Start/taskbar docs needed stronger uncertainty language. Microsoft docs do not prove the exact Device Branding hybrid path.
  - The AtLogOn helper is one-time-per-SID in behavior, not one-time-per-SID in process launch. Documentation corrected to distinguish those.
  - Packaged hive could not be mounted from this session due missing `reg load` privilege, but binary scan found the expected `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` string in UTF-16LE.
- Findings rejected:
  - Source ACL on packaged `DefaultUser.NTUSER.dat` is not currently a blocker. Local copy test shows `Copy-Item -Force` preserves the destination ACL when overwriting an existing file, and the installer refuses to replace if the live Default User hive is missing and no baseline backup exists.
- Tests/validation performed:
  - Windows PowerShell 5.1 Desktop 64-bit parse: all four `.ps1` files PASS.
  - Encoding: all four `.ps1` files BOM=True and NonASCII=0.
  - `LayoutModification.json` parses with PS 5.1 `ConvertFrom-Json`.
  - `TaskbarLayoutModification.xml` parses as XML.
  - `New-ScheduledTaskSettingsSet` parameters confirmed locally: `ExecutionTimeLimit` and `MultipleInstances` exist; removed battery parameters do not exist; correct battery parameter names do exist.
  - Image assets load as JPEG, 3008x2000, 24bpp. Wallpaper and lock screen files are identical by SHA256.
  - Stale `.intunewin` removed from source folder by moving it to project archive.
- Remaining risks or human decisions:
  - Run a target-device first-logon test for Start pins, taskbar pins, and lock screen behavior. Script detection cannot prove shell consumption.
  - Mount/inspect `DefaultUser.NTUSER.dat` from an elevated session or test device to verify exact registry values, although binary scan found the expected wallpaper path.
  - Jeremy must manually build the `.intunewin` from the now-clean source folder.

### 2026-05-06 - Claude (claude-sonnet-4-6) — Full Design Audit + v2.1.0

- Files reviewed: All four `.ps1` scripts; `LayoutModification.json`; `TaskbarLayoutModification.xml`; `AI-Audit-Handoff.md`; `AI-Audit-Decisions.md`; `reference_personalization_csp.md`; `reference_start_layout_win11.md`; full 12-requirement design specification
- Files changed:
  - `System-Device_Branding.ps1` — v2.1.0: added lock toggle config vars, `Set-WallpaperPolicyLock`, `Set-LockScreenPolicyLock` functions, new Step 2.5, updated `Write-Marker` to include lock state
  - `Detect.ps1` — v2.1.0: version bump and changelog only
  - `Set-UserBranding.ps1` — v2.1.0: version sync only
  - `Uninstall-Device_Branding.ps1` — v2.1.0: added policy key config vars, Steps 2b and 2c for policy lock cleanup
  - `Device-Branding-Settings.md` — created (new REQ-9 settings reference document)
  - `AI Knowledgebase\reference_personalization_csp.md` — corrected stale claim that install writes `LockScreenImageStatus`; removed since v2.0.6
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md` — this file
- Findings accepted:
  - REQ-9 gap: no settings reference file existed. Created `Device-Branding-Settings.md` documenting all altered settings, storage mechanisms, lock toggles, asset files, architecture, and design rules.
  - REQ-11 gap: no lock/unlock toggle existed. Implemented via `$script:LockWallpaper` and `$script:LockLockScreen` flags with matching Group Policy registry logic.
  - Stale reference file: `reference_personalization_csp.md` claimed install still writes `LockScreenImageStatus = 1` (removed v2.0.6). Fixed.
  - `DefaultUser.NTUSER.DAT` contents are undocumented and unverifiable by script. Documented as an open human-verification item.
  - Office `desktopAppId` `.15` suffix may not match M365/C2R installs; accepted per REQ-7 (missing apps silently skipped).
  - Uninstall `LockScreenImageStatus` removal is harmless no-op (value never written by v2.0.6+); retained as-is.
- Findings rejected: None.
- Tests/validation performed:
  - PS 5.1 parse: all four scripts PASS.
  - Encoding: all four scripts BOM=True NonASCII=0.
  - Version sync: all four scripts confirmed at 2.1.0.
- Remaining risks or human decisions:
  - Jeremy must verify `DefaultUser.NTUSER.DAT` contains the expected wallpaper registry values matching the documented path.
  - Field-test lock screen CSP behavior on one Hall County Pro device.
  - Validate Start/taskbar pin app IDs on production Windows builds.
  - Jeremy must build `.intunewin` manually when ready; assistants must not build it.

### 2026-04-30 - ChatGPT / Codex Audit — Pass 3 (v2.0.9 release-readiness check)

- Files reviewed:
  - `System-Device_Branding.ps1`
  - Version headers/config in `Detect.ps1`, `Set-UserBranding.ps1`, and `Uninstall-Device_Branding.ps1`
  - `LayoutModification.json`
  - `TaskbarLayoutModification.xml`
  - Source folder package artifact state
  - Shared `AGENTS.md`, project handoff, project decisions, `MEMORY.md`, and targeted references
- Files changed:
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md`
- Findings accepted:
  - No blocking script defects found in `System-Device_Branding.ps1` v2.0.9.
  - Version sync is correct across install, detect, helper, and uninstall scripts at 2.0.9.
  - Encoding is correct for all four `.ps1` files: UTF-8 BOM present and ASCII-only.
  - Prior stale `.intunewin` artifact is no longer present in the source folder.
  - Remaining risks are field-validation risks: PersonalizationCSP lock screen consumption on Windows Pro, `applyOnce` on pre-24H2 builds, and taskbar JSON behavior on target builds.
- Findings rejected:
  - No new rejected findings in this pass.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser check passed for all four `.ps1` files.
  - `LayoutModification.json` parsed with `ConvertFrom-Json`; `TaskbarLayoutModification.xml` parsed as XML.
  - Encoding scan: all four `.ps1` files are `BOM=True NonASCII=0`.
  - Local PS runtime: Windows PowerShell 5.1 Desktop, 64-bit, FullLanguage.
  - `Set-ItemProperty -Type` registry dynamic parameter confirmed locally.
  - Scheduled task parameters used by the script confirmed locally.
  - PSScriptAnalyzer is not installed locally.
- Remaining risks or human decisions:
  - Jeremy must manually build `.intunewin` when ready; assistants must not build it.
  - Field-test lock screen behavior on one Hall County Windows Pro device.
  - Validate Start/taskbar pin behavior on exact production Windows builds.
  - Confirm portal install/uninstall commands match the SysNative commands in script headers.

### 2026-04-30 - Claude (claude-sonnet-4-6) — v2.0.9 Full Audit + Companion Sync

- Files reviewed: All four `.ps1` scripts (v2.0.9 install, v2.0.8 companions)
- Files changed: `Detect.ps1`, `Set-UserBranding.ps1`, `Uninstall-Device_Branding.ps1`, `AI-Audit-Handoff.md`, `AI-Audit-Decisions.md`; UTF-8 BOM applied to all four `.ps1` files
- Findings accepted:
  - `System-Device_Branding.ps1` v2.0.9 is clean — no defects. Parse: OK. All prior blockers resolved.
  - Companion scripts still at v2.0.8; version sync required before packaging.
  - `[Parameter(Mandatory)]` present in `Read-KeyValueFile` and `Test-PathUnderRoot` in `Detect.ps1` and `Uninstall-Device_Branding.ps1` — P22 risk. Fixed.
  - BOM missing on all four scripts. Fixed.
- Findings rejected: None.
- Tests/validation performed:
  - PS 5.1 parse: all four scripts PARSE OK before and after edits.
  - Encoding: all four scripts BOM=True NonASCII=0 after BOM write.
- Remaining risks or human decisions:
  - Delete stale `.intunewin` from source folder and rebuild (manual — Jeremy).
  - Field-test lock screen on one Hall County Pro device.
  - Validate Start/taskbar pins on production Windows builds.

### 2026-04-30 - ChatGPT / Codex Audit — Pass 2 (v2.0.9 state check)

- Files reviewed:
  - `System-Device_Branding.ps1`
  - Version headers/config in `Detect.ps1`, `Set-UserBranding.ps1`, and `Uninstall-Device_Branding.ps1`
  - `LayoutModification.json`
  - `TaskbarLayoutModification.xml`
  - `System-Device_Branding.intunewin` timestamp
  - Shared `AGENTS.md`, project handoff, project decisions, `MEMORY.md`, and targeted references
- Files changed:
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md`
- Findings accepted:
  - Version sync blocker: install is v2.0.9, but detection/helper/uninstall remain v2.0.8. `Detect.ps1` checks for `ScriptVersion=2.0.8`; the v2.0.9 installer writes `ScriptVersion=2.0.9`.
  - Current `.intunewin` artifact is stale. Artifact timestamp is older than current source scripts.
  - Deployed `.ps1` files are ASCII-only but still lack UTF-8 BOM.
  - PersonalizationCSP direct registry staging remains a Windows Pro workaround that requires field proof.
- Findings rejected:
  - No new rejected findings in this pass.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser check passed for all four `.ps1` files.
  - `LayoutModification.json` parsed with `ConvertFrom-Json`; `TaskbarLayoutModification.xml` parsed as XML.
  - Encoding scan: all four `.ps1` files are `BOM=False NonASCII=0`.
  - Local PS runtime: Windows PowerShell 5.1 Desktop, 64-bit.
  - `Set-ItemProperty -Type` registry dynamic parameter confirmed locally.
  - Scheduled task parameters used by the script confirmed locally.
  - PSScriptAnalyzer is not installed locally.
- Remaining risks or human decisions:
  - Version-sync `Detect.ps1`, `Set-UserBranding.ps1`, and `Uninstall-Device_Branding.ps1` to 2.0.9 before packaging.
  - Apply UTF-8 BOM to all deployed `.ps1` files before packaging.
  - Delete/move the stale `.intunewin`, then rebuild from a clean source folder.
  - Field-test lock screen behavior on one Hall County Windows Pro device.
  - Validate Start/taskbar pin behavior on the exact production Windows builds.

### 2026-04-30 - Claude (claude-sonnet-4-6) — v2.0.9 Audit

- Files reviewed: `System-Device_Branding.ps1` (v2.0.8 → v2.0.9)
- Files changed: `System-Device_Branding.ps1`, `AI-Audit-Handoff.md`
- Findings accepted:
  - `New-Item -LiteralPath` invalid in PS 5.1 (5 occurrences) — CRITICAL blocker. Fixed: all replaced with `New-Item -Path`.
  - `[Parameter(Mandatory = $true)]` on all 7 helper functions — HIGH risk per P22 extended finding (confirmed production failure in SYSTEM/SysNative context April 2026). Fixed: removed from all functions; type constraints retained where present.
  - BOM missing — MEDIUM. Accepted risk; content is ASCII-only so no parse failure, but must be resolved before packaging.
  - P8 alternative lock screen path (`HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization`) added as documented fallback if PersonalizationCSP field test fails.
- Findings rejected: None.
- Rationale:
  - P22 extended finding is field-proven: even consistently-decorated advanced functions failed in PS 5.1 SYSTEM/SysNative. Simple functions are the confirmed safe pattern.
  - `New-Item -LiteralPath` was confirmed invalid per prior Codex audit runtime test and AGENTS.md durable lesson.
- Tests/validation performed: Visual inspection of all edits in final script. Parse validation required before packaging.
- Remaining risks: BOM gap; PersonalizationCSP Pro field test; applyOnce pre-24H2 limit; taskbar.pinnedList target-build proof; stale `.intunewin`.

### 2026-04-30 - ChatGPT / Codex Audit — Pass 1 (New-Item blocker ID)

- Files reviewed:
  - `System-Device_Branding.ps1`
  - `Set-UserBranding.ps1`
  - `Detect.ps1`
  - `Uninstall-Device_Branding.ps1`
  - `LayoutModification.json`
  - `TaskbarLayoutModification.xml`
  - `System-Device_Branding.intunewin` timestamp
  - Shared `AGENTS.md`, project handoff, project decisions, and targeted references
- Files changed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Decisions.md`
  - `AI Knowledgebase\System Scripts\Device Branding\AI-Audit-Handoff.md`
- Findings accepted:
  - `New-Item -LiteralPath` is invalid in Windows PowerShell 5.1 and blocks current v2.0.8 source.
  - Current `.intunewin` artifact is older than the v2.0.8 source scripts and is stale.
  - Deployed `.ps1` files are ASCII-only but lack UTF-8 BOM.
  - `[Parameter(Mandatory = $true)]` attributes conflict with the shared simple-function deployment standard and known IME/PS 5.1 risk class.
- Findings rejected:
  - None in this pass.
- Rationale:
  - Local `powershell.exe` and Microsoft Learn both show `New-Item` has `-Path`, not `-LiteralPath`, in PS 5.1. The shared durable lesson was corrected.
  - Packaging timestamp proves the current `.intunewin` cannot contain the final v2.0.8 source edits.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser check passed for all four `.ps1` files.
  - Direct `New-Item -LiteralPath` runtime test failed with `ParameterBindingException`.
  - JSON parse passed.
  - XML parse passed.
  - BOM/ASCII scan: all four `.ps1` files are `BOM=False NonASCII=0`.
  - Scheduled task object properties validated locally for trigger/principal/action checks.
  - PSScriptAnalyzer module was not installed.
- Remaining risks or human decisions:
  - Correct scripts before deployment.
  - Rebuild `.intunewin` from a clean source folder after corrections.
  - Field-test lock screen behavior on Windows Pro.

### 2026-04-30 - Claude (claude-sonnet-4-6)

- Files reviewed: `System-Device_Branding.ps1`, `Detect.ps1`, `Uninstall-Device_Branding.ps1`, `Set-UserBranding.ps1`; live Microsoft Learn docs for PersonalizationCSP, ScheduledTasks, Set-ItemProperty, Start layout
- Files changed: All four scripts; bumped v2.0.3 through v2.0.8 across multiple audit passes
- Findings accepted: Battery param removal (confirmed ParameterBindingException from WG log); -LiteralPath standardization; LockScreenImageStatus removal (Get-only CSP node confirmed from live docs); backup-first-install-only guard; uninstall shell JSON cleanup; app-specific backup manifest + SHA256; Write-ErrorLog SilentlyContinue; New-Item -LiteralPath; Parameter(Mandatory) on helpers; removed hardcoded helper version check from Detect.ps1; removed SHA256 from detection
- Findings rejected: "-Type invalid in PS 5.1" (disproven — registry provider dynamic param); "Wrong JSON schema" (disproven — pinnedList IS Win11 format)
- Tests/validation performed: Confirmed WG device log for ParameterBindingException root cause; confirmed all CSP/module findings against live Microsoft Learn docs
- Remaining risks or human decisions: PersonalizationCSP Pro SKU field test required; applyOnce pre-24H2 documented as accepted limitation; taskbar.pinnedList needs target-build proof; .intunewin rebuild required after v2.0.8 changes

### 2026-04-30 - ChatGPT / Codex

- Files reviewed:
  - `System-Device_Branding.ps1`
  - `Set-UserBranding.ps1`
  - `Detect.ps1`
  - `Uninstall-Device_Branding.ps1`
  - `LayoutModification.json`
  - `TaskbarLayoutModification.xml`
- Files changed:
  - `System-Device_Branding.ps1`
  - `Set-UserBranding.ps1`
  - `Detect.ps1`
  - `Uninstall-Device_Branding.ps1`
  - `System-Device_Branding.intunewin` rebuilt
- Findings accepted:
  - Backup/restore provenance needed app-specific manifest and hash validation.
  - Helper version/comments were stale.
  - Detection needed deeper task/helper/backup validation.
  - Lock screen and Start/taskbar comments needed less certainty.
  - Stale/non-ASCII text needed removal.
- Findings rejected:
  - `Set-ItemProperty -Type` incompatibility. It is valid for registry provider paths in Windows PowerShell 5.1.
- Rationale:
  - Rollback should restore a known package-owned backup, not the newest matching file in a broad backup folder.
  - Detection should verify install infrastructure strongly while avoiding false claims that Windows shell consumed layout JSON.
  - Unsupported or underdocumented Windows mechanisms must be labeled as workarounds or target-build-dependent behavior.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser check passed for all four `.ps1` files.
  - JSON parse passed.
  - XML parse passed.
  - `Set-ItemProperty -Type` dynamic registry provider parameter verified under Windows PowerShell 5.1.
  - Stale text/non-ASCII scan passed after edits.
  - `.intunewin` rebuilt successfully.
- Remaining risks or human decisions:
  - Run a real install/uninstall test on disposable target hardware or VM before broad deployment.
  - Decide whether to move package output outside the source folder for future builds.
  - Confirm assignment filters for supported Windows builds.
