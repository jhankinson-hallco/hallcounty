# AI-Audit-Handoff.md

## Current State

- Project: Device Rename - All_In_One
- Current install script version: 1.0.4
- Department detection script version: 1.0.1 (unchanged - see 2026-08-27 entry)
- Deployment type: Intune Win32 App, device context, SYSTEM, ESP-blocking
- Primary install script: `Rename-Device-System.ps1`
- Detection: department-specific files under `Detect\Detect-<prefix>.ps1`;
  authoritative name-first safety gate followed by the legacy prefix-file check
  only when the name is not already correct. Not aware of, and not changed
  for, the new Serial Marker write below.
- Department source list: `Inventory\Departments.csv`
- Uninstall: Not implemented; device rename is not automatically reversed. The
  v1.0.4 Serial Marker write below has no corresponding cleanup for the same
  reason - nothing currently reverses any part of this app.
- Package artifact: `Rename-Device-System.intunewin` is currently present in the
  active source folder and is now stale against v1.0.4. Treat it as a
  packaging artifact, not source content, before any rebuild.

## Active Risks

- **HIGH - already-correct devices never receive the merged Serial Marker
  output:** All 31 v1.0.1 detectors return installed as soon as the current
  name matches `<PREFIX>-<SERIAL>`. If the installer is launched independently,
  its own already-correct branch at lines 586-587 also exits before the new
  STEP 10 writer. Therefore the merge does not backfill the serial text file or
  marker onto the existing correctly named fleet. Keep rename-only detection if
  the files are intentionally best-effort, but call a shared marker-write helper
  from both the already-correct success branch and the post-rename success path
  if the merged app is expected to replace the standalone Serial Marker app.

- **HIGH - rename serial normalization is not compatible with the Serial Marker
  contract:** v1.0.4 writes the rename flow's `$Serial` into the serial file and
  marker. Rename strips hyphens and accepts known placeholders/all-zero values;
  Serial Marker v1.0.5 preserves hyphens, rejects those values, and then tries
  `Win32_ComputerSystemProduct`. Windows PowerShell 5.1 tests proved three
  mismatches: `ABC-1234` became `ABC1234`; `To Be Filled By O.E.M.` prevented a
  valid product fallback; and `0000-0000` prevented a valid product fallback.
  Preserve the rename `$Serial` for `$TargetName`, but compute a separate marker
  serial with the standalone project's normalization/resolution rules.

- **HIGH / PRE-EXISTING - recoverable domain credential is embedded in the
  source:** the script stores an encrypted password and its AES key together and
  reconstructs the credential locally. Anyone who obtains the source/package
  can recover the password. This was not introduced by the Serial Marker merge,
  but it remains material because the configured account is a personal domain
  account. Rotate the credential and replace the embedded-secret design, or
  document explicit risk acceptance and compensating controls.

- **MEDIUM - Serial Marker version is now duplicated across projects:** the
  combined script hardcodes marker version 1.0.5. If the standalone project is
  upgraded independently, either app can overwrite the shared marker with a
  different version and cause the standalone detector to disagree. Retire one
  writer or maintain an explicit cross-project synchronization requirement.

- **OPEN QUESTION - standalone Serial Marker app coexistence:** v1.0.4 of this
  script now writes the same `Serial - <SERIAL>.txt` file and
  `AppMarkers\SerialMarker.marker` that the standalone Serial Marker Win32 app
  (`System Scripts\Serial Marker\`) also writes. If both apps are assigned to
  the same White Glove technician-phase device set, whichever runs LAST
  overwrites the other's content - and since Serial Marker's own install
  reads live `$env:COMPUTERNAME` while this script writes the true
  post-rename `$TargetName`, the two can legitimately disagree on line 2
  depending on install order. Not resolved as part of this merge - Jeremy
  should decide whether to stop deploying the standalone Serial Marker app
  during White Glove now that this script covers the same need more
  accurately.

- **OPERATIONAL - Install command and detection must match:** Each department app
  must pass the matching install command prefix and use the matching
  `Detect\Detect-<prefix>.ps1` custom detection script.

- **CONFIRMED INCIDENT - WGDevice01 PZ app used old prefix-app entrypoint:** The
  2026-06-22 WGDevice01 logs show `Device Rename - PZ - White Glove` v3 running
  `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`.
  The All_In_One source package is `Rename-Device-System.ps1`; it does not
  contain `Set-DevicePrefix.ps1`. PowerShell exited immediately with
  `lpExitCode 4294770688` (`0xFFFD0000`, signed `-196608`), matching the local
  missing `-File` target signature. The All_In_One rename script did not execute.

- **OPERATIONAL - Deployed return-code mapping incomplete in WGDevice01 logs:**
  The PZ app policy in the 2026-06-22 logs mapped only `0`, `1707`, `3010`,
  `1641`, and `1618`. It did not include `2107 = Retry`, so a legitimate
  temporary Autopilot/domain-not-ready condition would hard-fail after the
  entrypoint is corrected.

- **OPERATIONAL - One app object per department is still required:** This design
  removes the prefix-app dependency ordering problem, but Intune still needs a
  separate app assignment per department prefix.

- **OPERATIONAL - Department app assignments must be mutually exclusive:** If more
  than one department rename app applies to the same device, the apps can compete
  by writing different prefix files and attempting different target names.

- **ACCEPTED - Service account is personal account:** The inherited credential
  configuration still uses `$script:DomainUser = 'hallcounty\jhankinson'`.

- **OPERATIONAL - White Glove domain timing still matters:** Domain join, DC
  discovery, and secure channel readiness are still checked before
  `Rename-Computer`. Temporary not-ready conditions exit 2107 for Intune retry.

## Recent Changes

- 2026-08-27: Codex independently audited Claude's v1.0.4 merge. No deployment
  scripts were changed. Confirmed clean Windows PowerShell 5.1 parsing/encoding
  for the installer and all 31 detectors, but found that already-correct devices
  bypass the new writer and that rename serial normalization diverges from the
  standalone Serial Marker v1.0.5 contract. Also recorded the pre-existing
  recoverable embedded credential and cross-project marker-version coupling.
  Per Jeremy's instruction, `.intunewin` artifacts were excluded from review.

- 2026-08-27: Merged the Serial Marker project's identification-file/marker
  write into `Rename-Device-System.ps1` as v1.0.4 (Jeremy's explicit
  request). New STEP 10, added between the existing Rename-Computer call and
  the reboot-required exit, writes "Serial - <SERIAL>.txt" (serial on line
  1, the new $TargetName on line 2) and a versioned
  AppMarkers\SerialMarker.marker, reusing the rename flow's own $Serial and
  $TargetName rather than a fresh BIOS read or $env:COMPUTERNAME. Wrapped in
  its own non-fatal try/catch - verified via isolated execution that a
  failure there cannot change this script's exit code. No existing rename
  variable, function, exit code, or the 31 department detection scripts
  were touched; see AI-Audit-Decisions.md for full rationale and the open
  question about standalone Serial Marker app coexistence.
- 2026-07-01: Codex added an authoritative name-first safety gate to all 31
  department detection scripts. A device whose current name exactly matches the
  detector's `<PREFIX>-<SERIAL>` result now returns exit 0 plus STDOUT before
  `DevicePrefix.txt` is tested or read. The install script was bumped to v1.0.3
  and its own already-correct exit was moved before prefix-file writes and all
  Autopilot, domain, credential, and rename work.

- 2026-06-15: Codex bumped install script to v1.0.2. Removed top-level
  `[Parameter(Mandatory)]` and `[ValidatePattern()]` from `-Prefix` so invalid
  install command prefixes flow through the script-authored 2105 logging path.
  Synchronized `.NOTES Version` and `$script:AppVersion`. Restored custom log
  output before the Autopilot-not-complete 2107 retry exit. Clarified the
  Autopilot guard wording in the help block.

- 2026-06-15: Claude changed the install script to v1.0.1 in `$script:AppVersion`,
  moved comment help before `param()`, removed the unused `ERR_DOMAIN_FAILED`
  constant, and silenced the Autopilot-not-complete custom log path. Runtime
  version metadata is partially out of sync because `.NOTES Version` remains
  1.0.0.

- 2026-06-12: Created `All_In_One` package source folder. Copied the White Glove
  `Rename-Device-System.ps1` v1.0.5 flow, changed prefix source to mandatory
  `-Prefix`, merged Set-DevicePrefix-style prefix-file creation/verification, and
  generated 31 combined detection scripts from `Inventory\Departments.csv`.

## Required Validation Before Deployment

- Jeremy manually rebuilds the `.intunewin` package from the active source folder
  (current artifact is stale against v1.0.4).
- Run one real White Glove rename end-to-end and confirm both
  "Serial - <SERIAL>.txt" and AppMarkers\SerialMarker.marker appear with the
  post-reboot target computer name on line 2, and with the normalized hardware
  serial in the marker's `Serial=` field, matching what was only verified in an
  isolated harness so far - not yet on a real
  Autopilot/White Glove device with the actual Rename-Computer path exercised.
- Test an already-correct device and confirm the intended policy: either the
  serial artifacts are backfilled before exit 0, or the artifacts are formally
  classified as optional and the standalone Serial Marker app remains assigned.
- Test hyphenated, known-placeholder, and all-zero BIOS serials with a valid
  `Win32_ComputerSystemProduct.IdentifyingNumber` fallback before treating the
  merged output as compatible with Serial Marker v1.0.5 detection.
- Confirm install command uses SysNative 64-bit PowerShell, `-NoProfile`,
  `-NonInteractive`, and the matching `-Prefix "<prefix>"`.
- For each department app, upload/select the matching
  `Detect\Detect-<prefix>.ps1` custom detection script.
- Replace previously uploaded v1.0.0 detection scripts with v1.0.1. Local source
  edits do not change an existing Intune app detection rule.
- Confirm custom detection runs 64-bit.
- Confirm return codes: 3010 = Soft reboot/success, 2107 = Retry, 2103 = Fail.
- Run one White Glove pilot to verify prefix write, rename, restart handling, and
  combined detection behavior.

## Latest Work Log

### 2026-08-27 - Codex Independent Audit Of Claude Serial Marker Merge

- Files reviewed: `Rename-Device-System.ps1` v1.0.4, all 31
  `Detect\Detect-*.ps1` files, Serial Marker v1.0.5 install/detection behavior,
  and this project's handoff/decisions. Per Jeremy's direction, no `.intunewin`
  artifact was inspected.
- Files changed: this handoff and `AI-Audit-Decisions.md` only. No deployment
  script was modified.
- Findings accepted: the new writer is correctly placed after a successful
  `Rename-Computer`, uses `$TargetName` instead of the stale live hostname, and
  is deliberately non-fatal. The 31 detectors were unchanged.
- New findings: already-correct devices bypass the writer; the reused rename
  serial is incompatible with Serial Marker normalization/fallback behavior;
  marker versioning is duplicated across two writers; and the pre-existing
  colocated AES key/ciphertext remains a recoverable embedded credential.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: installer plus 31 detectors, zero errors.
  - Encoding: all 32 files retain UTF-8 BOM; PSScriptAnalyzer was unavailable.
  - Structural inspection: 31 of 31 detectors have the exact-name success gate;
    zero of 31 inspect the serial file or Serial Marker marker.
  - Executed the actual serial-resolution function bodies with mocked CIM data.
    Ordinary BIOS serials matched, but hyphenated, known-placeholder, and
    all-zero cases produced different rename and Serial Marker serials.
- Remaining action: correct the two merge defects before relying on this script
  as a replacement for the standalone Serial Marker deployment; separately
  remediate or explicitly accept the embedded credential risk.

### 2026-08-27 - Claude (Sonnet 5) Serial Marker merge

- Files reviewed: `Rename-Device-System.ps1` (fresh read, full file, before
  editing), `Install-SerialMarker.ps1` v1.0.5 (Serial Marker project), one
  representative department detector (`Detect\Detect-MIS.ps1`, to confirm no
  detection script references the marker/serial-file at all), this
  project's and the top-level Device Rename handoff/decisions.
- Files changed:
  - `Rename-Device-System.ps1` -> v1.0.4: added a new STEP 10 (serial
    identification file + marker write, best-effort, non-fatal) between the
    existing Rename-Computer call and the reboot-required exit; added
    `SerialMarker`-prefixed config variables and four new functions
    (`Remove-ExistingSerialMarkerFiles`, `Write-SerialMarkerFile`,
    `Write-SerialMarkerIntuneMarker`, `Remove-SerialMarkerMarkerFile`) in a
    clearly separated block; updated `.SYNOPSIS`/`.DESCRIPTION`/`.NOTES`.
    STEPS 1-9 and all existing config/functions/exit codes are otherwise
    byte-for-byte unchanged - confirmed by direct comparison against the
    pre-edit read.
  - This handoff and `AI-Audit-Decisions.md`.
- Findings accepted: none carried over from a prior audit - this is new
  work, not a remediation pass.
- Rationale: see the new AI-Audit-Decisions.md entry for the full
  request/design rationale, including why detection was deliberately left
  untouched (Jeremy's explicit call: low failure probability for a text/file
  write, and adding it as a second or third detection criterion for one app
  increases false-negative risk for the whole - including the disruptive
  rename+reboot).
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: `Rename-Device-System.ps1` v1.0.4 parses
    clean.
  - Encoding: UTF-8 BOM present, zero non-ASCII characters.
  - Direct line-by-line comparison of STEPS 1-9 against the pre-edit read -
    no differences beyond the STEP 10->11 comment renumbering necessitated
    by the insertion.
  - Isolated Windows PowerShell 5.1 reproduction of the injected STEP 10
    functions (not the real script, to avoid any AD/Rename-Computer risk):
    confirmed the written file's line 2 is the simulated $TargetName
    ('MIS-25273PJ'), not the live $env:COMPUTERNAME ('IT-BK348FT25273') -
    proving the core fix (use the target name, not a stale live read)
    actually works; confirmed the marker writes correctly with
    Version=1.0.5; confirmed a stale PDQ marker is removed; confirmed a
    simulated failure inside the injected try/catch (blocked marker
    directory) does not propagate past that block, so the surrounding
    script structure would still reach `exit 3010` unconditionally.
- Remaining risks or human decisions: see Active Risks - the standalone
  Serial Marker Win32 app coexistence question is unresolved; no real
  Autopilot/White Glove device has exercised this yet (isolated harness
  only, per Required Validation above); `.intunewin` is stale and needs a
  manual rebuild.

### 2026-07-01 - Claude Verification Audit Of Name-First Detection Safety Fix

- Files reviewed: `Detect\Detect-SO.ps1` in full, all 31 `Detect\Detect-*.ps1`
  headers/hard-gate blocks, `Rename-Device-System.ps1`, this handoff and
  decisions.
- Files changed: this handoff only. No script changes were needed.
- Findings accepted:
  - Codex's 2026-07-01 name-first hard gate is present, structurally identical,
    and correctly ordered (before any `DevicePrefix.txt` access) in all 31
    detection scripts.
  - `Get-TargetName` in the detection scripts never throws (returns `$null` on
    invalid input), so the hard gate cannot be bypassed by an exception path
    into the outer `catch { exit 1 }`.
- Findings rejected: None.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 31 of 31 detection scripts, zero errors.
  - Encoding: 31 of 31 have UTF-8 BOM and zero non-ASCII characters.
  - Structural diff: all 31 files are 141 lines with the hard-gate block at
    identical line numbers and each file's own hardcoded `$script:ExpectedPrefix`.
  - Unit-tested `Get-TargetName` in isolation with `$script:SerialTakeFromEnd =
    $true`: confirmed correct rightmost-character truncation for oversized
    serials, correct handling of numeric (`911`) and 3-char (`EMA`) prefixes,
    exact 15-char boundary case, and `$null` (not throw) return for an empty
    serial.
  - Confirmed no `Write-Host` usage anywhere in the Detect folder; all exit-0
    paths call `Write-Output` first, all exit-1 paths are silent.
- Remaining risks or human decisions: unchanged from the 2026-07-01 Codex entry
  below - portal detection rules still need the v1.0.1 files uploaded, and the
  `.intunewin` artifact is still stale pending manual rebuild.

### 2026-07-01 - Codex Emergency Name-First Detection Safety Fix

- Files reviewed: `Rename-Device-System.ps1`, all 31
  `Detect\Detect-*.ps1` files, this handoff and decisions.
- Files changed:
  - `Rename-Device-System.ps1` v1.0.3
  - all 31 department detection scripts v1.0.1
  - this handoff
  - `AI-Audit-Decisions.md`
- Findings accepted:
  - All 31 prior detectors checked `DevicePrefix.txt` before checking the
    hostname. A missing or mismatched prefix file therefore returned not
    detected even when the computer name was already exactly correct.
  - Exact hostname equality with the normalized and length-limited
    `<PREFIX>-<SERIAL>` target is the authoritative no-run state.
  - The installer needs the same guard before its first prefix-file write as
    defense in depth.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: all 32 scripts parse with zero errors.
  - Encoding: all 32 scripts retain UTF-8 BOM and zero non-ASCII characters.
  - Structure: 31 of 31 detectors contain the hard gate before the prefix-file
    test.
  - Simulated `SO-A1B2C3D4` with serial `A1B2C3D4`: detector returned STDOUT and
    exit 0 while mocked prefix-file access was configured to throw.
  - Simulated mismatched hostname: detector returned exit 1.
  - Simulated already-correct installer run: returned exit 0 while mocked
    `Set-Content` and `Rename-Computer` were configured to throw if reached.
- Remaining risks or human decisions:
  - Upload the revised v1.0.1 detection file to each existing Intune app object;
    source changes alone do not update portal detection.
  - The active `Rename-Device-System.intunewin` artifact predates v1.0.3 and is
    stale. Jeremy must manually rebuild before deploying the installer-side
    defense-in-depth change.
  - Detection cannot cancel an install process that was already running before
    the revised detection rule was evaluated.

### 2026-06-22 - Codex WGDevice01 PZ Entrypoint Audit

- Files reviewed: `Rename-Device-System.ps1`, `Detect\Detect-PZ.ps1`,
  `F:\Logs\WGDevice01\AppWorkload.log`, this handoff and decisions.
- Files changed:
  - this handoff
  - `AI-Audit-Decisions.md`
- Findings accepted:
  - The All_In_One install script expects `-Prefix` on
    `Rename-Device-System.ps1`; it writes the prefix file itself and then
    performs the rename flow.
  - The deployed PZ Win32 app command was the old DevicePrefixApp command:
    `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`.
  - The All_In_One source folder contains `Rename-Device-System.ps1` and
    `Detect\Detect-PZ.ps1`, but not `Set-DevicePrefix.ps1`.
  - The WG process exited with `lpExitCode 4294770688`, reproduced locally as
    the Windows PowerShell missing `-File` target exit code.
  - The deployed PZ app return-code table lacked `2107 = Retry`.
  - `Rename-Device-System.ps1` parses under Windows PowerShell 5.1 and remains
    UTF-8 BOM / ASCII-only.
- Findings rejected:
  - None.
- Rationale: This was not a runtime failure in `Rename-Device-System.ps1`; the
  script never started because the portal/package entrypoint targeted the wrong
  file.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: `Rename-Device-System.ps1` parse OK.
  - Encoding: `Rename-Device-System.ps1` has UTF-8 BOM and zero non-ASCII
    characters excluding the BOM.
  - Windows PowerShell 5.1 parser: `Detect\Detect-PZ.ps1` parse OK.
  - Local missing-file reproduction produced exit code `-196608`
    (`0xFFFD0000`), matching IME unsigned `4294770688`.
- Remaining risks or human decisions:
  - Update the PZ app install command to the All_In_One command:
    `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Rename-Device-System.ps1 -Prefix "PZ"`.
  - Re-upload/rebuild from the correct All_In_One source if the portal setup file
    still shows `Set-DevicePrefix.ps1`.
  - Add return code `2107 = Retry`; keep `3010 = Soft reboot/success` and
    `2103 = Fail`.
  - Remove or move `Rename-Device-System.intunewin` out of the active source
    folder before any future package rebuild.

### 2026-06-15 - Codex Audit Fixes

- Files reviewed: All_In_One install script, generated All_In_One detection set,
  `Inventory\Departments.csv`, this handoff and decisions.
- Files changed:
  - `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`
  - this handoff
- Findings accepted:
  - Prefix validation must happen inside the script body so invalid or missing
    portal arguments produce the custom 2105 log and exit path.
  - Install script `.NOTES Version` and `$script:AppVersion` must match.
  - Autopilot-not-complete retry should leave a custom log entry for easier
    White Glove triage.
- Findings rejected:
  - None.
- Rationale: These changes preserve the All_In_One architecture while removing
  pre-body parameter-binding failure and restoring deterministic troubleshooting
  evidence.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 32 All_In_One files parse OK.
  - Encoding: 32 All_In_One files have UTF-8 BOM and zero non-ASCII characters
    excluding the BOM.
  - Version sync: install `.NOTES Version` and `$script:AppVersion` both 1.0.2.
  - Prefix binding check: no top-level `[Parameter(Mandatory)]` or
    `[ValidatePattern()]` remains on `-Prefix`.
  - CSV coverage: 31 department rows, 31 generated All_In_One detection files.
  - Prefix validation: all 31 detection scripts contain the expected
    `$script:ExpectedPrefix`.
  - No `.intunewin` artifact exists under the All_In_One source folder.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Portal app creation still needs one department-specific install command and
    one matching detection script per department.

### 2026-06-15 - Codex First-Look Audit After Claude

- Files reviewed: All_In_One install script, sample All_In_One detection scripts,
  generated detection set, `Inventory\Departments.csv`, legacy White Glove and
  DevicePrefixApp scripts for adjacent validation, project handoff and decisions,
  targeted Intune/PowerShell audit references.
- Files changed: updated this handoff only.
- Findings accepted:
  - All_In_One source parses under Windows PowerShell 5.1.
  - All_In_One source is UTF-8 BOM and ASCII-only.
  - The install script no longer reads the prefix file as an input source; its
    `Get-Content` use is post-write verification only.
  - Detection scripts correctly require both expected prefix-file content and the
    computed `<PREFIX>-<SERIAL>` computer name.
  - Credential values still match the White Glove source script.
  - Claude's v1.0.1 metadata is inconsistent: `$script:AppVersion` is 1.0.1 but
    `.NOTES Version` is 1.0.0.
  - Top-level mandatory/validation attributes on `-Prefix` can fail before custom
    logging and custom exit codes run.
- Findings rejected:
  - None.
- Rationale: The combined architecture remains sound, but pre-body parameter
  binding and version drift should be corrected before packaging.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 32 All_In_One files parse OK.
  - Parser: 34 adjacent White Glove/DevicePrefixApp scripts parse OK.
  - Encoding: 32 All_In_One files have UTF-8 BOM and zero non-ASCII characters
    excluding the BOM.
  - Encoding: 34 adjacent White Glove/DevicePrefixApp scripts have UTF-8 BOM and
    zero non-ASCII characters excluding the BOM.
  - CSV coverage: 31 department rows, 31 generated All_In_One detection files.
  - Prefix validation: all 31 All_In_One detection scripts contain the expected
    `$script:ExpectedPrefix`.
  - Local Windows PowerShell language mode: FullLanguage.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - Decide whether to keep the silent 2107 Autopilot guard behavior or restore a
    custom log line for that retry path.
  - Correct install script version metadata before packaging.
  - Consider removing top-level mandatory/ValidatePattern binding and doing all
    prefix validation inside the main try/catch.
  - No `.intunewin` package was built by AI.

### 2026-06-12 - Codex All_In_One Build

- Files reviewed: White Glove `Rename-Device-System.ps1`, White Glove
  `Detect.ps1`, DevicePrefixApp `Set-DevicePrefix.ps1`,
  `Inventory\Departments.csv`, existing DevicePrefixApp and White Glove handoffs
  and decisions.
- Files changed:
  - added `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`
  - added 31 files under `System Scripts\Device Rename\All_In_One\Detect`
  - added this handoff and decisions
- Findings accepted:
  - AD OU-derived prefix is not viable during White Glove because devices land in
    a holding OU before manual final OU placement.
  - A single rename app depending on any one of 30 prefix apps is not viable
    because Intune dependencies do not provide OR semantics.
  - The all-in-one design should receive the prefix from the install command,
    write `DevicePrefix.txt` for detection, and use the same prefix directly for
    target-name construction.
- Findings rejected:
  - Keeping DevicePrefixApp as a separate White Glove dependency for this flow.
- Rationale: The new package removes cross-app ordering ambiguity while reusing
  the tested rename flow, credential block, domain readiness checks, logging, and
  prefix-file format.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 32 files parse OK (install plus 31 detection).
  - Encoding: all 32 files have UTF-8 BOM and zero non-ASCII characters excluding
    the BOM.
  - CSV coverage: 31 department rows, 31 generated detection files, no missing or
    extra files.
  - Prefix validation: all 31 detection scripts contain the expected
    `$script:ExpectedPrefix`.
  - Credential preservation: `DomainUser`, `AesKeyBase64`, and
    `EncryptedPassword` match the White Glove source script exactly.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - Portal app creation still needs one department-specific install command and
    one matching detection script per department.
