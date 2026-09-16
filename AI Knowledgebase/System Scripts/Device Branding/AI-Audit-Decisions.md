# AI-Audit-Decisions.md

## Durable Decisions

### 2026-04-30 - Set-ItemProperty -Type Is Valid In PS 5.1 Registry Provider

- Decision: Rejected finding that `Set-ItemProperty -Type` is unavailable in Windows PowerShell 5.1.
- Status: Rejected
- Evidence type: proven from local runtime
- Rationale: `-Type` is a dynamic parameter exposed by the registry provider when the command is bound against a registry path.
- Source or local evidence: `Get-Command Set-ItemProperty -ArgumentList 'HKLM:\Software'`
- Recommended action: Do not flag this again unless local target runtime evidence contradicts it.

### 2026-04-30 - LockScreenImageStatus Must Not Be Written

- Decision: Do not write `LockScreenImageStatus`.
- Status: Accepted
- Evidence type: proven from Microsoft documentation and prior audit
- Rationale: `LockScreenImageStatus` is a readback/status node. Install scripts should not write it.
- Source or local evidence: `AI Knowledgebase\reference_personalization_csp.md`
- Recommended action: Keep detection focused on staged path value only, unless using a supported CSP/channel with documented status handling.

### 2026-04-30 - Lock Screen Registry Staging Is A Workaround

- Decision: Direct writes to the PersonalizationCSP registry location are treated as a Windows Pro workaround, not supported CSP policy delivery.
- Status: Accepted
- Evidence type: proven from Microsoft documentation plus practical deployment constraint
- Rationale: Microsoft CSP support and SKU rules do not make direct registry writes equivalent to supported MDM CSP policy application.
- Source or local evidence: `AI Knowledgebase\reference_personalization_csp.md`
- Recommended action: Comments and detection must avoid claiming guaranteed OS policy consumption.

### 2026-04-30 - Start/Taskbar JSON Needs Target-Build Proof

- Decision: `pinnedList` JSON is a real Windows 11 layout schema, but Shell-folder file placement and `taskbar.pinnedList` behavior must be proven on target builds.
- Status: Partially accepted
- Evidence type: Microsoft documentation plus implementation inference
- Rationale: Microsoft documents managed JSON layout and separate OEM file-placement mechanisms. The current package uses a pragmatic hybrid path.
- Source or local evidence: `AI Knowledgebase\reference_start_layout_win11.md`
- Recommended action: Do not overclaim. Use assignment filters and pilot testing on exact production builds.

### 2026-05-06 - Start/Taskbar Delivery Is A Best-Effort Hybrid, Not Proven Policy Delivery

- Decision: Keep the current `LayoutModification.json` best-effort approach, but document that it is not equivalent to supported Start/Taskbar policy delivery.
- Status: Accepted
- Evidence type: proven from Microsoft documentation plus local package review
- Rationale: Microsoft documents OEM Windows 11 Start image customization through `LayoutModification.json` in `%LOCALAPPDATA%\Microsoft\Windows\Shell` using OEM members such as `primaryOEMPins` / `secondaryOEMPins`. Microsoft documents managed Start pin replacement through `pinnedList` JSON via `ConfigureStartPins` policy/CSP/GPO. Microsoft taskbar documentation describes XML/policy/image-time mechanisms, not `taskbar.pinnedList` in Start JSON as an offline post-OOBE mechanism. The Device Branding package deliberately uses a local/offline hybrid to avoid Intune or network dependency after White Glove, so field proof is required.
- Source or local evidence:
  - Microsoft Learn: `https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/customize-the-windows-11-start-menu`
  - Microsoft Learn: `https://learn.microsoft.com/en-us/windows/configuration/start/layout`
  - Microsoft Learn: `https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/customize-the-windows-11-taskbar`
  - Local file: `System Scripts\Device Branding\LayoutModification.json`
- Recommended action: Treat Start pins as likely but unproven until first-logon testing on target Windows 11 builds. Treat taskbar pins as higher risk than Start pins. Do not let detection claim visual shell consumption.

### 2026-04-30 - applyOnce Requires Newer Windows 11 Support

- Decision: `applyOnce` cannot be assumed on all Windows 11 builds.
- Status: Accepted
- Evidence type: Microsoft documentation
- Rationale: Current documentation limits `applyOnce` support to Windows 11 24H2 with KB5062660 or newer documented support.
- Source or local evidence: `AI Knowledgebase\reference_start_layout_win11.md`
- Recommended action: Treat `applyOnce` as ignored on older builds unless proven otherwise.

### 2026-04-30 - Win32_ComputerSystem.UserName Is Acceptable For This Fleet

- Decision: Keep `Win32_ComputerSystem.UserName` for standard single-user endpoints.
- Status: Accepted
- Evidence type: environment assumption
- Rationale: Hall County fleet is standard desktops/laptops/GETAC devices, not RDS/VDI/multi-session.
- Source or local evidence: User-provided recurring technical context.
- Recommended action: Revisit only if RDS, VDI, or multi-session endpoints enter scope.

### 2026-05-06 - AtLogOn Helper Is One-Time Work, Not One-Time Trigger

- Decision: Document the current helper accurately as a recurring AtLogOn trigger with one-time-per-SID substantive work.
- Status: Accepted as current implementation; open if Jeremy requires zero later process launch
- Evidence type: proven from code review
- Rationale: The scheduled task fires at every logon, but `Set-UserBranding.ps1` exits immediately when `C:\ProgramData\HallCountyMIS\BrandingApplied\<SID>.marker` exists. This satisfies "do not reapply settings after first processing" but does not literally satisfy "no script launches on subsequent logons."
- Source or local evidence: `System Scripts\Device Branding\System-Device_Branding.ps1`; `System Scripts\Device Branding\Set-UserBranding.ps1`
- Recommended action: If zero later helper launch is mandatory, remove the scheduled task/helper pattern and rely only on Default User profile staging, or redesign with a true once-per-user mechanism such as Active Setup after separate validation.

### 2026-05-06 - Retire AtLogOn Helper To Match No Recurring Logon Script Requirement

- Decision: Remove the recurring SYSTEM AtLogOn helper architecture from the active package.
- Status: Accepted - Implemented v2.2.0
- Supersedes: `2026-05-06 - AtLogOn Helper Is One-Time Work, Not One-Time Trigger`
- Evidence type: user requirement clarification plus code review
- Rationale: Jeremy's requirement is literal enough that even an immediate-exit helper launching at every logon is the wrong shape. v2.2.0 relies on `DefaultUser.NTUSER.DAT` replacement and Default User Shell-folder staging for future profile creation, matching the OEM-style "set defaults before the user exists" model. Existing user profiles are not reprocessed. The installer removes the legacy scheduled task/helper/marker infrastructure if present.
- Source or local evidence:
  - `System Scripts\Device Branding\System-Device_Branding.ps1`
  - `System Scripts\Device Branding\Detect.ps1`
  - `System Scripts\Device Branding\Device-Branding-Settings.md`
  - Archived helper: `AI Knowledgebase\System Scripts\Device Branding\Archive\Retired-Runtime-Files\Set-UserBranding_v2.1.0_retired.ps1`
- Recommended action: Field-test first new-user logon on target Windows 11 builds. If Start/taskbar pins do not materialize from Default User staging alone, redesign using an actually one-shot mechanism and document the tradeoff before reintroducing any logon-time process.

### 2026-04-30 - Detection Validates Infrastructure, Not Shell Consumption

- Decision: Detection should validate package infrastructure and versioned state, not whether Windows shell consumed Start/taskbar layout.
- Status: Accepted
- Evidence type: practical implementation limit
- Rationale: Reliable SYSTEM-context detection of per-user shell database consumption is not available before/at user initialization.
- Source or local evidence: Prior audit discussion and script behavior.
- Recommended action: Keep comments precise. Validate visual pin results during pilot deployment, not in Win32 detection.

### 2026-04-30 - Default Hive Backup Requires Provenance

- Decision: Default User hive rollback must use app-specific backup manifest/hash.
- Status: Accepted
- Evidence type: code audit finding
- Rationale: Restoring the newest `DefaultHive_*.DAT` from a broad shared backup folder can restore the wrong file.
- Source or local evidence: v2.0.7 implementation in `System-Device_Branding.ps1` and `Uninstall-Device_Branding.ps1`.
- Recommended action: Preserve manifest-based restore pattern for future hive-modifying packages.

### 2026-04-30 - Production PowerShell Scripts Need BOM And ASCII

- Decision: Intune-deployed PowerShell scripts should be UTF-8 with BOM and ASCII-only.
- Status: Accepted
- Evidence type: field failure lesson
- Rationale: Windows PowerShell 5.1 can misread BOM-less UTF-8 with non-ASCII characters under IME, causing pre-execution failure with no script-authored logs.
- Source or local evidence: `AI Knowledgebase\feedback_script_encoding.md`
- Recommended action: Verify BOM and non-ASCII before packaging.

### 2026-04-30 - Write-ErrorLog I/O Must Use SilentlyContinue

- Decision: All I/O inside `Write-ErrorLog` must use `-ErrorAction SilentlyContinue`.
- Status: Accepted — Implemented v2.0.8
- Evidence type: Logic defect (install/uninstall inconsistency confirmed by code review)
- Rationale: Install's `Write-ErrorLog` used `-ErrorAction Stop` on `New-Item` and `Add-Content`. If logging fails, the exception propagates and masks the original error that triggered the log call. Uninstall already used `SilentlyContinue`. Install standardized to match. **General rule: logging helpers must never throw.**
- Source or local evidence: Code comparison of `Write-ErrorLog` in install vs uninstall

---

### 2026-04-30 - New-Item Must Use -LiteralPath For Variable Inputs

- Decision: Use `-LiteralPath` on `New-Item` wherever the path comes from a variable.
- Status: Superseded - incorrect for Windows PowerShell 5.1
- Evidence type: Code review (standards violation)
- Rationale: `-Path` on `New-Item` interprets brackets as wildcards. While current paths have no brackets, `New-FolderIfMissing` accepts arbitrary inputs. Standardized to `-LiteralPath` in `Write-ErrorLog`, `New-FolderIfMissing`, and `Write-Marker`.
- Superseded by: 2026-04-30 - New-Item -LiteralPath Is Invalid In Windows PowerShell 5.1

---

### 2026-04-30 - New-Item -LiteralPath Is Invalid In Windows PowerShell 5.1

- Decision: Do not use `New-Item -LiteralPath` in Windows PowerShell 5.1 deployment scripts.
- Status: Accepted - current v2.0.8 blocker
- Evidence type: proven from local Windows PowerShell 5.1 runtime and Microsoft Learn
- Rationale: `New-Item` in Windows PowerShell 5.1 does not expose a `-LiteralPath` parameter. The current v2.0.8 installer uses `New-Item -LiteralPath` in multiple first-run code paths, which will throw `ParameterBindingException` when the script tries to create missing folders or registry keys. Microsoft documents `New-Item -Path`; for this cmdlet, `Path` behaves like `LiteralPath` and wildcards are not interpreted.
- Source or local evidence:
  - `powershell.exe -NoProfile -Command "Get-Command New-Item -Syntax"`
  - `powershell.exe -NoProfile -Command "New-Item -LiteralPath $env:TEMP\Test -ItemType Directory"`
  - Microsoft Learn `New-Item` PS 5.1 syntax
- Recommended action: Replace `New-Item -LiteralPath` with `New-Item -Path` or .NET directory creation as appropriate. Rebuild `.intunewin` after correcting scripts.

---

### 2026-04-30 - Remove Hardcoded Helper Version Check From Detect.ps1

- Decision: Do not check helper file content for a version string in detection.
- Status: Accepted — Implemented v2.0.8
- Evidence type: Design defect
- Rationale: Detect.ps1 v2.0.7 added a regex content check for `$script:HelperVersion = '2.0.7'` in the deployed helper file. This breaks detection on every helper version bump without a simultaneous Detect.ps1 update — adding a hidden three-file coordination requirement. File existence (already checked) plus task action reference (check 10) proves the correct helper is deployed. Version gating is handled by the marker `ScriptVersion` check.

---

### 2026-04-30 - Remove SHA256 Hash Verification From Detect.ps1

- Decision: Do not compute SHA256 of the hive backup file in detection.
- Status: Accepted — Implemented v2.0.8
- Evidence type: Performance concern
- Rationale: Detect.ps1 v2.0.7 hashed `NTUSER.DAT` (5-30 MB) on every Intune check-in cycle (~every 8 hours). This adds unnecessary I/O load with no meaningful security benefit at detection time. SHA256 validation is retained in `Uninstall-Device_Branding.ps1` where it runs once before restoring the file. File existence + path-under-root check is sufficient in detection.

---

### 2026-04-29 - Remove -DisallowStartIfOnBatteries and -StopIfGoingOnBatteries

- Decision: Remove both parameters from `New-ScheduledTaskSettingsSet`.
- Status: Accepted — Implemented v2.0.3
- Evidence type: Proven from production log + live Microsoft docs
- Rationale: WG device log showed `ParameterBindingException: A parameter cannot be found that matches parameter name 'DisallowStartIfOnBatteries'`. Microsoft Learn `New-ScheduledTaskSettingsSet` docs confirm neither parameter exists. Correct battery parameters are `-AllowStartIfOnBatteries` (switch) and `-DontStopIfGoingOnBatteries` (switch). Both removed parameters are irrelevant for SYSTEM account tasks regardless.
- Source or local evidence: `F:\Logs\WGDevice01\DeviceBranding_Install.txt`; `reference_scheduledtasks_module.md`

---

### 2026-04-30 - DOCUMENTED RISK: PersonalizationCSP Not Officially Supported On Windows 11 Pro

- Decision: Document as unresolved risk; field test required before claiming lock screen works.
- Status: Open risk — field test pending
- Evidence type: Proven from live Microsoft documentation
- Rationale: Microsoft Learn states PersonalizationCSP is supported on Enterprise/Education SKUs only; on Windows 11 Pro it requires Shared PC mode. Hall County fleet is Windows 11 Pro (non-Shared PC). Current approach uses direct registry write as a workaround. Whether Windows 11 Pro honors these values at the OS level is not documented. Direct registry write bypasses the CSP API restriction but OS consumption is unconfirmed.
- Required action: Deploy package to one Hall County Pro device, reboot, confirm lock screen image changes.
- If field test fails: Evaluate Intune Device Restrictions > Lock Screen profile (different MDM channel) as alternative.
- Source or local evidence: Live Microsoft Learn PersonalizationCSP page; `reference_personalization_csp.md`

---

### 2026-04-30 - Simple Functions Required: No [Parameter()] Attributes In Helper Functions

- Decision: All helper functions in deployment scripts must be simple functions — no `[Parameter()]` attributes, no `[CmdletBinding()]`.
- Status: Accepted — Implemented v2.0.9
- Evidence type: Field-confirmed production failure (P22 extended finding)
- Rationale: Even consistently-decorated advanced functions threw `ParameterBindingException` in PS 5.1 SYSTEM/SysNative context on Windows 11 22H2 (Remove-Office365.ps1 v1.5.2–v1.5.5, April 2026 White Glove). Converting all functions to simple functions eliminated the failure. Simple functions use a minimal binding path with no parameter-set resolution. Named-parameter calls still bind correctly by name. Type constraints (`[string]`, `[int]`, etc.) are compatible with simple functions and may be retained.
- Source or local evidence: `reference_intune_pitfalls.md` P22 extended finding; Remove-Office365.ps1 v1.5.6 commit.
- Recommended action: Remove `[Parameter()]` attributes from all helper functions in all production scripts. Never re-add `[CmdletBinding()]` or `[Parameter()]` to internal helpers without explicit justification and testing.

---

### 2026-05-06 - Lock Toggles Use Group Policy Registry Paths

- Decision: Implement `$script:LockWallpaper` and `$script:LockLockScreen` using standard Group Policy registry paths, not MDM CSP paths.
- Status: Accepted — Implemented v2.1.0
- Evidence type: Design requirement (REQ-11) + documented GP registry paths for Windows Pro
- Rationale: The MDM CSP paths for lock screen (PersonalizationCSP) are unsupported on Windows 11 Pro without Shared PC mode. The Group Policy registry paths (`HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop` for wallpaper; `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` for lock screen) are honored on Windows Pro without MDM/Intune policy profiles and are the standard GP-registry enforcement mechanism. The wallpaper CSP path (`DesktopImagePath`) has the same Pro SKU restriction, making GP registry the only reliable locking option for this fleet.
- Recommended action: Field-test both lock paths on a Hall County Pro device when toggled to `$true`.

### 2026-05-06 - Lock State Does Not Gate Detection

- Decision: `Detect.ps1` does not validate the lock state — it validates infrastructure and version only.
- Status: Accepted — Implemented v2.1.0
- Evidence type: Design intent
- Rationale: Lock state is a behavioral toggle, not evidence of whether the package installed correctly. Adding lock state to detection would make detection conditional on the current toggle values, which would falsely report "not detected" if the lock state changed between install runs. The marker version check is the correct gate; lock state is informational and stored in the marker for transparency only.

---

### 2026-05-06 - Mount Hive Copies For Audit, Not Package Source Hives

- Decision: For audit/inspection, copy packaged `.DAT` hives to a temp folder and mount the copy, not the file in the package source folder.
- Status: Accepted
- Evidence type: local audit behavior
- Rationale: Directly mounting `System Scripts\Device Branding\DefaultUser.NTUSER.dat` created `.LOG1`, `.LOG2`, `.TM.blf`, and `.regtrans-ms` sidecar files beside the package payload. IntuneWinAppUtil packages all files in the source folder, so these generated sidecars can accidentally enter the `.intunewin` unless removed.
- Source or local evidence:
  - Generated files observed in `System Scripts\Device Branding` on 2026-05-06 after direct hive mount.
  - Source cleanup performed and later hive inventory rerun against a temp copy.
- Recommended action: Use temp-copy hive mounting for future inspections. Always check the source folder for `DefaultUser.NTUSER.dat.LOG*`, `.TM.blf`, and `.regtrans-ms` before packaging.

---

### 2026-05-07 - Use CMD Launchers Instead Of Direct SysNative Commands

- Decision: Device Branding Win32 app install/uninstall commands must call the package CMD launchers through `%SystemRoot%\System32\cmd.exe`, not direct `SysNative\WindowsPowerShell` paths.
- Status: Accepted
- Evidence type: White Glove deployment log
- Rationale: `F:\Logs\WGDevice01\AppWorkload.log` showed Device Branding content downloaded and extracted, `SetCurrentDirectory` set to the IME cache folder, then `CreateProcess` failed with Win32 error 2 / HRESULT `0x80070002` for `C:\WINDOWS\SysNative\WindowsPowerShell\v1.0\powershell.exe`. This proves the launcher context could not resolve the `SysNative` virtual alias. The CMD launchers choose `SysNative` only when it exists and otherwise use `System32`.
- Source or local evidence: `AppWorkload.log` lines 2076-2085 from the 2026-05-07 WGDevice01 logs.
- Recommended action: Use `%SystemRoot%\System32\cmd.exe /d /c .\Install-Device_Branding.cmd` and `%SystemRoot%\System32\cmd.exe /d /c .\Uninstall-Device_Branding.cmd` in Intune. Rebuild the `.intunewin` from a clean source folder so both CMD launchers are included.

---

## Disagreements

- No active disagreements recorded.
