# AI-Audit-Handoff.md

## Current State

- Project: Device Rename - Rename_by_User
- Current install script version: 1.0.4
- Current detection script version: 1.0.2
- Current uninstall script version: 1.0.1
- Deployment type: Intune Win32 App, Company Portal, user context, interactive
- Primary install script: `Set-DeviceNameInteractive.ps1`
- Detection: `Detect.ps1` v1.0.1; validates
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DetectionMarkers\DeviceRenameInteractive.txt`
  plus active or pending `<PREFIX>-<SERIAL>` computer name
- Uninstall: `Uninstall.ps1`; removes only the detection marker and does not
  rename the device back
- Local test helper: `Run-LocalTest.cmd`; runs the install script locally from
  an elevated command prompt with process-scoped `-ExecutionPolicy Bypass`
- Package artifact: no `.intunewin` exists in the active source folder

## Active Risks

- **ACCEPTED - Interactive Win32 app:** This tool is intentionally interactive.
  Intune and Company Portal are used only as distribution platforms.

- **REQUIRED - User install behavior:** The Company Portal app must be configured
  with Win32 app Install behavior `User`. System install behavior launches in
  the machine session and cannot display the department picker or credential UI.

- **ACCEPTED - Local admin required:** The app is intentionally assigned only to
  administrators. Non-admin users should not see it in Company Portal.

- **OPERATIONAL - Detection marker is cleared on each launch:** If a user starts
  the tool and cancels or fails the rename, the previous marker is removed and
  detection should fall back to not detected.

- **OPERATIONAL - Detection checks pending rename state:** `Detect.ps1` accepts
  either the active computer name or the pending registry computer name so
  detection can pass before the forced restart completes.

- **OPERATIONAL - Uninstall is marker cleanup only:** Removing the Company Portal
  app does not and should not reverse the device rename.

- **OPERATIONAL - Interactive admin elevation may still require pilot proof:**
  After switching from System to User install behavior, confirm that Company
  Portal launches the script with sufficient local administrator rights for
  `Rename-Computer`. If it runs unelevated, a separate elevation/launcher design
  will be required.

## Recent Changes

- 2026-06-15: Claude created the initial `Rename_by_User`
  `Set-DeviceNameInteractive.ps1` script based on the All_In_One rename logic.

- 2026-06-15: Codex updated `Set-DeviceNameInteractive.ps1` to v1.0.1, added
  marker lifecycle handling, added native Windows credential UI, added local
  admin/domain preflight checks, moved forced restart after the success dialog,
  and separated access-denied handling from bad-password retry logic. Added
  `Detect.ps1` for marker plus active/pending hostname detection.

- 2026-06-15: Claude (claude-sonnet-4-6) audited v1.0.1 and corrected three
  bugs; bumped install script to v1.0.2 and updated `Detect.ps1` paired script
  reference.

- 2026-06-15: Codex updated `Set-DeviceNameInteractive.ps1` to v1.0.3,
  hardened credential memory cleanup, removed file-only detection guidance,
  added `Uninstall.ps1`, and updated `Detect.ps1` metadata to v1.0.1 paired
  with install script v1.0.3.

- 2026-06-15: Codex added `Run-LocalTest.cmd` for authorized local elevated
  testing outside Company Portal.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
- Confirm Intune portal settings match the script comments.
- Confirm the app is configured as user context.
- Confirm the app is assigned only to authorized local administrators.
- Configure custom detection with `Detect.ps1`.
- Configure uninstall command to run `Uninstall.ps1`.
- Exclude `Run-LocalTest.cmd` from the Intune payload unless intentionally
  packaging local test helpers.
- Manually rebuild the `.intunewin` package from a clean source folder.

## Latest Work Log

### 2026-06-15 - Codex First-Look Audit

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `Inventory\Departments.csv`
  - All_In_One handoff and decisions
  - Shared Intune/PowerShell audit references
- Files changed:
  - Added this handoff.
  - Added `AI-Audit-Decisions.md`.
- Findings accepted:
  - Script parses under Windows PowerShell 5.1.
  - Script is UTF-8 BOM and ASCII-only.
  - Hardcoded department table matches `Inventory\Departments.csv` when the
    CSV is read with explicit `Department,Prefix` headers.
  - No duplicate `Set-DeviceNameInteractive.ps1` source copy was found under
    `System Scripts\Device Rename`.
  - No `.intunewin` artifact exists under the active source folder.
  - Deployment/design risks remain around Intune interactive-app support, local
    admin, detection, credential UI, restart ordering, and auth-error
    classification.
- Findings rejected:
  - None.
- Rationale: The script is mechanically valid, but Company Portal user-context
  rename behavior depends on local admin rights and a detection design that are
  not yet solved in the source.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: `Set-DeviceNameInteractive.ps1` parses OK.
  - Encoding: UTF-8 BOM present; non-ASCII count is 0.
  - Department coverage: 31 script entries and 31 CSV rows; no differences.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - Decide whether normal Company Portal users will be local admins.
  - Decide whether to accept the Microsoft-documented unsupported interactive
    Win32 app model, or move the UI outside Win32 install execution.
  - Decide whether to add a marker-file detection model, a custom detection
    script, or intentionally keep the app re-runnable with a different status
    strategy.
  - Decide whether to keep custom credential UI or replace it with a more
    Windows-native credential prompt design.

### 2026-06-15 - Codex Implementation Update

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1`
  - `Inventory\Departments.csv`
- Files changed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1`
  - this handoff
  - `AI-Audit-Decisions.md`
- Findings accepted:
  - Interactive Company Portal execution is intentional.
  - Local admin requirement is intentional and should be enforced by assignment
    and by script preflight.
  - Marker-based detection is needed for the interactive one-shot app.
  - Credentials should use native Windows credential UI instead of a custom
    WinForms password textbox.
  - `Access is denied` should not be treated as bad username/password.
  - Restart scheduling should happen after the success dialog closes.
- Findings rejected:
  - None.
- Rationale: These changes keep the requested interactive workflow while making
  the Intune detection state deterministic and reducing credential-handling risk.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install and detection scripts parse OK.
  - Encoding: install and detection scripts have UTF-8 BOM and zero non-ASCII
    characters.
  - Department coverage: 31 script entries and 31 CSV rows; no differences.
  - Native credential prompt C# wrapper compiles locally.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Portal detection must use the new `Detect.ps1`.
  - Pilot test is still needed on a domain-joined admin workstation.

### 2026-06-15 - Claude (claude-sonnet-4-6) Audit

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1` v1.0.1
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1` v1.0.0
  - `AI Knowledgebase\System Scripts\Device Rename\Rename_by_User\AI-Audit-Handoff.md`
  - `AI Knowledgebase\AGENTS.md`
- Files changed:
  - `Set-DeviceNameInteractive.ps1` v1.0.1 -> v1.0.2
  - `Detect.ps1` paired script reference updated to v1.0.2
  - this handoff
- Findings fixed:
  - C1: `CredUnPackAuthenticationBuffer` called with `dwFlags = 0` instead of
    `1` (CRED_PACK_PROTECTED_CREDENTIALS). The buffer from
    `CredUIPromptForWindowsCredentials(CREDUIWIN_GENERIC)` is DPAPI-protected;
    passing 0 caused `CredUnPackAuthenticationBuffer` to return false on every
    attempt, producing an infinite "Unable to read the supplied credentials"
    loop. Fixed: changed argument from 0 to 1 on line 510 (pre-fix).
  - M1: `Start-Process shutdown.exe` was inside the same `try` block as
    `Rename-Computer`. A shutdown scheduling failure after a successful rename
    would trigger the outer catch with "Failed to rename this device... name
    already exists in AD" -- completely wrong about every fact. Fixed: shutdown
    scheduling moved to its own `try/catch` that logs and shows an accurate
    "rename succeeded, please restart manually" message and still exits 3010.
  - L1: The `return $null` (user cancelled) and `throw` (CredUI Win32 error)
    paths in `Show-CredentialForm` were outside the `try/finally` block, so
    `CoTaskMemFree` was never called on those paths. Fixed: moved both checks
    inside the `try` so the `finally` always runs and `CoTaskMemFree` is always
    called (safe to call on NULL per Windows docs).
- Findings accepted (not changed):
  - `Clear-StringBuilder` indexer assignment: valid in PS 5.1 under StrictMode.
  - `Get-PendingComputerName` registry path: correct for pending rename state.
  - Detection dual-check (current OR pending name): correct design.
  - Already-named path writes marker and exits 0 without restart: correct.
  - `access is denied` separated from auth failure retry: correct design.
  - Marker cleared on cancel: documented accepted behavior.
- Findings rejected:
  - None.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: both scripts parse OK after edits.
  - Encoding: both scripts BOM=True, NonASCII=0 after edits.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Pilot test needed on a domain-joined admin workstation to confirm
    CredUI unpack behavior and full rename flow end-to-end.

### 2026-06-15 - Codex First-Look Audit After Claude

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1` v1.0.2
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1` v1.0.0
  - `Inventory\Departments.csv`
  - project handoff and decisions
  - targeted shared Intune/PowerShell references
- Files changed:
  - this handoff only
- Findings accepted:
  - Claude's v1.0.2 functional changes are present: credential unpack flag is
    `1`, buffer cleanup paths are under `finally`, shutdown scheduling has its
    own try/catch, and detection references paired script v1.0.2.
  - Install and detection scripts parse under Windows PowerShell 5.1.
  - Install and detection scripts are UTF-8 BOM and ASCII-only.
  - Native credential C# wrapper compiles locally.
  - Department table still matches `Inventory\Departments.csv`.
  - `Detect.ps1` returns exit 1 on this workstation when no marker exists.
- Findings requiring attention:
  - Credential memory hygiene is incomplete. The native credential blob is freed
    with `CoTaskMemFree` but is not zeroed first, and the password is copied into
    an immutable .NET string before conversion to `SecureString`.
  - The install script header says a native file-existence detection rule can be
    used, but file-only detection proves only marker existence and does not prove
    the active or pending hostname still matches the marker prefix.
  - The header lists uninstall as not applicable, but the Intune Win32 app
    metadata still needs a concrete uninstall command value when the app is
    created.
  - User cancel after marker cleanup exits 0 while detection fails, which may be
    operationally acceptable for a rerunnable tool but can appear as a failed or
    not-installed run in Company Portal.
- Findings rejected:
  - None.
- Rationale: Claude's fixes addressed the immediate functional bugs, but the
  remaining concerns are security hardening and Intune portal metadata clarity.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install and detection scripts parse OK.
  - Encoding: install and detection scripts have UTF-8 BOM and zero non-ASCII
    characters.
  - Department coverage: 31 script entries and 31 CSV rows; no differences.
  - Native credential prompt C# wrapper compiles under Windows PowerShell 5.1.
  - Simulated CredPack/CredUnPack test: unpack succeeds with flags 0 and 1 for a
    packed username/password buffer.
  - `Detect.ps1` no-marker run exits 1 as expected.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - Decide whether to harden credential memory handling before pilot.
  - Confirm the portal uses custom detection with `Detect.ps1`, not native file
    existence only.
  - Choose a harmless uninstall command for the Win32 app metadata.
  - Pilot test still needed on a domain-joined admin workstation.

### 2026-06-15 - Codex Hardening Update

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Uninstall.ps1`
  - `Inventory\Departments.csv`
- Files changed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1`
  - added `System Scripts\Device Rename\Rename_by_User\Uninstall.ps1`
  - this handoff
- Findings accepted:
  - CredUI credential blob should be zeroed before `CoTaskMemFree`.
  - Password should be moved from the mutable unpack buffer directly into a
    `SecureString` instead of first creating a plaintext .NET string.
  - Detection guidance should require custom `Detect.ps1`, not native file-only
    marker detection.
  - The Win32 app should have a concrete uninstall command, even though uninstall
    only removes marker state.
- Findings rejected:
  - None.
- Rationale: These changes reduce credential-memory exposure and remove portal
  metadata ambiguity without changing the accepted interactive/admin-only design.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install, detection, and uninstall scripts
    parse OK.
  - Encoding: install, detection, and uninstall scripts have UTF-8 BOM and zero
    non-ASCII characters.
  - Native credential prompt C# wrapper compiles under Windows PowerShell 5.1.
  - Department coverage: 31 script entries and 31 CSV rows; no differences.
  - `Detect.ps1` no-marker run exits 1 as expected.
  - No `.intunewin` artifact exists in the active source folder.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Pilot test still needed on a domain-joined admin workstation.

### 2026-06-15 - Codex Local Test Launcher

- Files reviewed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - project handoff and decisions
- Files changed:
  - added `System Scripts\Device Rename\Rename_by_User\Run-LocalTest.cmd`
  - this handoff
- Findings accepted:
  - Local testing needs a launcher that uses Windows PowerShell 5.1 with
    process-scoped execution-policy bypass.
  - The launcher should require elevation before calling the interactive rename
    script.
- Findings rejected:
  - None.
- Rationale: This provides an authorized local test path that mirrors the script
  runtime without requiring Company Portal.
- Tests/validation performed:
  - `Run-LocalTest.cmd` contains zero non-ASCII characters.
  - Non-elevated launch path was tested and correctly refused to run.
- Remaining risks or human decisions:
  - This helper does not bypass WDAC/AppLocker or enforced script-blocking GPO.
  - Do not include `Run-LocalTest.cmd` in the Intune package unless that is an
    intentional payload decision.

### 2026-06-17 - Codex Company Portal Failure Triage

- Files/logs reviewed:
  - `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_Set-DeviceNameInteractive_Install.txt`
  - `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log`
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1`
  - `System Scripts\Device Rename\Rename_by_User\Uninstall.ps1`
  - project handoff and decisions
  - shared log triage, Intune context, architecture, and pitfalls references
- Files changed:
  - `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1` v1.0.3 -> v1.0.4
  - `System Scripts\Device Rename\Rename_by_User\Detect.ps1` v1.0.1 -> v1.0.2 metadata sync
  - `System Scripts\Device Rename\Rename_by_User\Uninstall.ps1` v1.0.0 -> v1.0.1 metadata sync
  - `System Scripts\Device Rename\Rename_by_User\Run-LocalTest.cmd`
  - this handoff
- Findings accepted:
  - The Intune-authored script log showed the script failed at WinForms
    `ShowDialog()` because the process was not running in UserInteractive mode.
  - `AppWorkload.log` showed the app `Device Rename` application id
    `aa0d246a-1715-462e-baea-898a567688af` ran with install context `System`
    and launched `Win32AppInstaller in machine session`.
  - The portal install command used the expected SysNative PowerShell host, so
    this was not a 32-bit PowerShell problem.
  - Local testing with `-NonInteractive` alone still reported
    `SystemInformation.UserInteractive=True`; the root cause was session/context,
    not that switch by itself.
- Changes made:
  - Added exit code `2111` for non-interactive user session failures.
  - Added an early `Test-IsInteractiveSession` guard before marker cleanup or any
    GUI call so a System-context run logs a clear portal configuration failure.
  - Updated the documented install command to use `-STA` and omit
    `-NonInteractive` for this GUI-based exception.
  - Updated the local test launcher to use `-STA`.
- Required portal correction:
  - Configure the Win32 app Install behavior as `User`, not `System`.
  - Install command:
    `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -STA -File ".\Set-DeviceNameInteractive.ps1"`
  - Uninstall command:
    `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File ".\Uninstall.ps1"`
  - Add return code `2111` as Failed.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install, detection, and uninstall scripts
    parse OK.
  - Encoding: install, detection, and uninstall scripts have UTF-8 BOM and zero
    non-ASCII characters.
  - `powershell.exe -STA` confirmed STA apartment state and interactive WinForms
    availability in a local interactive session.
  - `Run-LocalTest.cmd` remains ASCII-only.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Existing `Set-DeviceNameInteractive.intunewin` in the source folder predates
    this v1.0.4 fix and must be manually rebuilt/reuploaded before retesting.
  - Pilot Company Portal again after switching Install behavior to `User`. If
    the script then fails local admin elevation, redesign around an approved
    elevation launcher or scheduled task handoff.
