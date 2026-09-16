# AI-Audit-Handoff.md

## Current State

- Project: Device Rename - DevicePrefixApp
- Install script version: 1.0.1
- Department detection script version: 1.0.3
- Deployment type: Intune Win32 App, device context, SYSTEM
- Primary install script: `Set-DevicePrefix.ps1`
- Detection: department-specific files under `Detect\Detect-<prefix>.ps1`;
  exact prefix-file content check
- Department source list: `Inventory\Departments.csv`
- Uninstall: portal command removes the prefix file; no uninstall script present
- Package artifact: `Set-DevicePrefix.intunewin` is currently present in the
  active source folder. Treat it as a packaging artifact, not source content,
  before rebuilding any department package.

## Active Risks

- **OPERATIONAL - Intune detection upload must match install prefix:** Each
  department app must use the matching `Detect\Detect-<prefix>.ps1` file. The
  detection file prefix must match the package install command `-Prefix` value,
  including the trailing hyphen after normalization.

- **OPERATIONAL - Root Detect.ps1 is legacy/single-prefix source:** The root
  `Detect.ps1` currently exists from the earlier workflow and should not be used
  for new department app uploads unless its expected prefix is intentionally
  reviewed first.

- **CONFIRMED INCIDENT - FM package failed with stale TA detection:** The
  2026-06-11 White Glove failure was caused by portal app `Device Rename -
  Prefix: FM` installing with `-Prefix "FM"` while its deployed detection script
  still expected `TA-`. Install returned 0, post-install detection stayed
  NotDetected, and ESP failed the app with `0x87d1041c`.

- **CONFIRMED INCIDENT - PZ package failed before Set-DevicePrefix ran:** The
  2026-06-22 WGDevice01 White Glove failure was app
  `f27099f8-7ce3-4e9f-a251-60333e598a6d`, `Device Rename - PZ - White Glove`
  v3. IME launched `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`
  from the extracted IMECache folder, but PowerShell exited immediately with
  `lpExitCode 4294770688` (`0xFFFD0000`, signed `-196608`). A local PowerShell
  check showed this is the same exit code returned when the `-File` target is
  missing. The script-authored log was not present in the copied logs, which is
  consistent with PowerShell failing before the script body could execute.

- **OPERATIONAL - Rename app dependency:** Packages that consume the prefix file
  must depend on this app or otherwise run after it. The prefix file path is:
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.

## Recent Changes

- 2026-06-11: Aligned `.SYNOPSIS`, `.DESCRIPTION`, and `.NOTES` sections in
  all department detection scripts to the `Detect-AD.ps1` wording pattern. No
  version bump; runtime logic unchanged.

- 2026-06-11: Generated department-specific detection files under `Detect\`
  from `Inventory\Departments.csv`. Each `Detect-<prefix>.ps1` is v1.0.3, names
  the department in the notes/output, and checks the exact normalized prefix file
  content under IME IntuneFiles.

- 2026-06-10: Bumped `Set-DevicePrefix.ps1` and `Detect.ps1` to v1.0.1. Moved
  prefix file under IME IntuneFiles. Moved script-authored install error log under
  IME Logs as `SCRIPT_Set-DevicePrefix_Install.txt`. Added StrictMode and UTF-8
  BOM to active scripts. Moved stale `.intunewin` and reference template out of
  the active source folder.

## Required Validation Before Deployment

- Jeremy manually rebuilds the `.intunewin` package from the active source folder.
- Confirm install command uses SysNative 64-bit PowerShell, `-NoProfile`, and
  `-NonInteractive`.
- For each department app, upload/select the matching
  `Detect\Detect-<prefix>.ps1` custom detection script.
- Confirm the detection script `$script:ExpectedPrefix` matches the package
  install command `-Prefix` value after normalization, including trailing hyphen.
- Confirm the dependent rename app reads the same IME IntuneFiles prefix path.

## Latest Work Log

### 2026-06-22 - Codex WGDevice01 PZ Prefix Package Triage

- Files reviewed: `F:\Logs\WGDevice01\AppWorkload.log`,
  `AppActionProcessor.log`, `AgentExecutor.log`, `IntuneManagementExtension.log`,
  `Set-DevicePrefix.ps1`, `Detect\Detect-PZ.ps1`, this handoff and decisions.
- Files changed:
  - this handoff
  - `AI-Audit-Decisions.md`
- Findings accepted:
  - White Glove failed in Device Setup because `Device Rename - PZ - White Glove`
    v3 entered ESP install state 4 / enforcement state 5000.
  - The failing app was the prefix package command, not `Rename-Device-System.ps1`:
    `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`.
  - IME downloaded, validated, decrypted, and extracted the package, then changed
    working directory to `C:\windows\IMECache\f27099f8-7ce3-4e9f-a251-60333e598a6d_3`.
    The installer process exited almost immediately with `lpExitCode 4294770688`.
  - `4294770688` is unsigned `0xFFFD0000`, matching signed `-196608`, which
    Windows PowerShell returns when the `-File` script path does not exist.
  - Other selected White Glove apps either succeeded, were already detected, or
    required only a soft reboot. SentinelOne was not the blocking failure.
- Findings rejected: none.
- Rationale: The log pattern points to a package content or portal command/setup
  mismatch where `Set-DevicePrefix.ps1` was not available at the package root
  when the install command ran. The exact uploaded package contents were not
  recoverable from the copied logs because IME cleaned the cache.
- Tests/validation performed:
  - Parsed deployed Win32 policy metadata from `AppWorkload.log`.
  - Correlated detection, download, extraction, execution, result reporting, and
    ESP status lines in `AppWorkload.log`.
  - Reproduced the same PowerShell missing-file exit signature locally.
- Remaining risks or human decisions:
  - Rebuild and re-upload the PZ package from the correct `DevicePrefixApp`
    source root so `Set-DevicePrefix.ps1` is at the package root.
  - Update the portal install command to the documented SysNative command with
    `-NoProfile` and `-NonInteractive`.
  - Upload/select `Detect\Detect-PZ.ps1` for the PZ app.
  - Wait for or clear the app GRS retry state before retesting.

### 2026-06-11 - Codex Detection Header Alignment

- Files reviewed: `Detect\Detect-AD.ps1`, all generated
  `Detect\Detect-*.ps1` files, `Inventory\Departments.csv`.
- Files changed: updated the comment help block only in the 30 non-AD
  department detection scripts.
- Findings accepted:
  - `Detect-AD.ps1` is the canonical wording pattern for `.SYNOPSIS`,
    `.DESCRIPTION`, and `.NOTES`.
  - The other department scripts should differ only by department name and
    generated prefix wording in those sections.
- Findings rejected: none.
- Rationale: This keeps portal-facing script metadata consistent while leaving
  detection behavior and versions untouched.
- Tests/validation performed:
  - Header comparison: 31 checked, 0 mismatches.
  - Windows PowerShell 5.1 parser: all 31 `Detect\Detect-*.ps1` files parse OK.
  - Encoding: all 31 files have UTF-8 BOM and zero non-ASCII characters excluding
    the BOM.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.

### 2026-06-11 - Codex Department Detection Generation

- Files reviewed: `Inventory\Departments.csv`, template
  `Detect\Detect-AD.ps1`, `Set-DevicePrefix.ps1`, project handoff and decisions.
- Files changed:
  - generated/refreshed 31 files under `Detect\Detect-<prefix>.ps1`
  - updated this handoff and decisions
- Findings accepted:
  - Per-department custom detection files reduce manual inline edits while
    preserving exact-prefix detection accuracy.
  - Intune still cannot pass the install command prefix into the detection script,
    so each app must receive the correct detection script file during portal
    configuration.
- Findings rejected: none.
- Rationale: `Inventory\Departments.csv` is now the source list for department
  names and prefixes. Generated detection scripts keep the same runtime logic but
  stamp department-specific synopsis, notes, output, and `$script:ExpectedPrefix`.
- Tests/validation performed:
  - Generated file count matches CSV rows: 31 expected, 31 actual.
  - Windows PowerShell 5.1 parser: all 31 `Detect\Detect-*.ps1` files parse OK.
  - Encoding: all 31 generated detection scripts have UTF-8 BOM and zero
    non-ASCII characters excluding the BOM.
  - Sample inspection confirmed AD, FM, 911, MIS, MO, and PZ metadata/prefixes.
- Remaining risks or human decisions:
  - In Intune, each department app must use the matching
    `Detect\Detect-<prefix>.ps1` file and install command prefix.
  - No `.intunewin` package was built by AI.

### 2026-06-11 - Codex Failed White Glove Log Triage

- Files reviewed: pulled `Logs\Autopilot.cab`,
  `Logs\Fail_20260611-142426.zip`, extracted IME logs, `Detect.ps1`,
  `Set-DevicePrefix.ps1`, project handoffs and decisions.
- Files changed:
  - `Detect.ps1` v1.0.1 -> v1.0.2
  - updated this handoff and decisions
- Findings accepted:
  - Root cause was the DevicePrefixApp detection mismatch, not the install script
    process: `Device Rename - Prefix: FM` ran
    `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "FM"`
    and returned `lpExitCode 0`.
  - The deployed detection script was v1.0.1 and had
    `$script:ExpectedPrefix = "TA-"`, so the prefix file written as `FM-` could
    never satisfy detection.
  - ESP marked app `be328425-2b8c-4d4c-86d5-c2d224178265` as Error with
    `0x87d1041c`; the shortcut pack completed afterward.
- Findings rejected: none.
- Rationale: Exact-prefix detection is correct, but each cloned prefix package must
  carry a matching detection value.
- Tests/validation performed:
  - Decoded the deployed detection script body from `AppWorkload.log`.
  - Correlated `AppWorkload.log`, `AppActionProcessor.log`,
    `AgentExecutor.log`, and `EnrollmentStatusTracking.reg`.
  - Windows PowerShell 5.1 parser: DevicePrefixApp install/detect and White Glove
    install/detect scripts parse OK after the FM detection update.
  - Encoding: all four related runtime scripts have UTF-8 BOM and zero non-ASCII
    characters excluding the BOM.
- Remaining risks or human decisions:
  - Rebuild and re-upload the FM package so Intune receives the matching
    `Detect\Detect-FM.ps1` custom detection script.
  - Portal install command still used bare `powershell.exe` without `-NoProfile`
    or `-NonInteractive`; change it to the SysNative command documented in
    `Set-DevicePrefix.ps1`.

### 2026-06-10 - Codex Recheck After Claude

- Files reviewed: `Set-DevicePrefix.ps1`, `Detect.ps1`, White Glove Deploy
  `Rename-Device-System.ps1`, White Glove Deploy `Detect.ps1`, both project
  handoffs and decisions.
- Files changed: no runtime script changes.
- Findings accepted:
  - Active runtime scripts parse under Windows PowerShell 5.1.
  - Active runtime scripts are UTF-8 BOM with zero non-ASCII characters.
  - Prefix file path aligns with the rename app:
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.
  - Install error logging follows new IME Logs convention:
    `SCRIPT_Set-DevicePrefix_Install.txt`.
- Findings rejected: none.
- Rationale: The script mechanics are sound, but this app is package-specific by
  design. Detection currently expects `TA-`; a different install command prefix
  requires a matching detection edit before packaging.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install and detect scripts parse OK.
  - Encoding: install and detect scripts have UTF-8 BOM and zero non-ASCII
    characters.
  - PS 5.1 syntax check confirmed the content/path cmdlets used are valid.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - Confirm whether the active package should still expect `TA-`.
  - Use custom detection for exact prefix validation; native file-exists detection
    can false-pass if the wrong department prefix is present.

### 2026-06-10 - Codex

- Files reviewed: `Set-DevicePrefix.ps1`, `Detect.ps1`, project handoff/decisions,
  active source folder contents.
- Files changed:
  - `Set-DevicePrefix.ps1` -> v1.0.1
  - `Detect.ps1` -> v1.0.1
  - moved stale `Set-DevicePrefix.intunewin` to project archive
  - moved reference-only description template to project archive
  - updated this handoff
- Findings accepted:
  - Prefix file should move from `C:\IntuneDeploymentFiles` to
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles`.
  - Script-authored logs should move to IME Logs using the new `SCRIPT_...`
    naming convention.
- Findings rejected: none.
- Rationale: The new path is machine-wide, SYSTEM-accessible, and available during
  White Glove. Keeping the prefix app as a dependency gives deterministic ordering.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: install and detect scripts parse OK.
  - Encoding: install and detect scripts have UTF-8 BOM and zero non-ASCII
    characters.
  - Active source folder contains only `Set-DevicePrefix.ps1` and `Detect.ps1`.
- Remaining risks or human decisions:
  - Confirm whether the active package should still expect `TA-`.
