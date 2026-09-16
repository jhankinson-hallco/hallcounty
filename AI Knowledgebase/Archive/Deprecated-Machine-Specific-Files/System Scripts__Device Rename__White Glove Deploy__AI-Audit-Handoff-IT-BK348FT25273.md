# AI-Audit-Handoff.md

## Current State

- Project: Device Rename - White Glove Deploy
- Current version: 1.0.5
- Deployment type: Intune Win32 App, device context, SYSTEM, ESP-blocking
- Primary install script: `Rename-Device-System.ps1`
- Detection: `Detect.ps1` v1.0.3; name-based detection, no version marker gate
- Uninstall: Not reviewed
- Package artifact: no `.intunewin` remains in the active source folder

## Active Risks

- **RESOLVED - PS 5.1 scalar unwrap in Autopilot enrollment check:** v1.0.3 captures
  enrollment subkeys with `@(...)` before reading `.Count`.

- **RESOLVED - DC reachability is checked before rename:** v1.0.3 adds a bounded
  domain readiness gate before `Rename-Computer`: local domain join,
  `nltest /dsgetdc:<domain>`, and `nltest /sc_verify:<domain>`. If not ready within
  300 seconds, the script exits 2107 so Intune retries instead of reaching the hard
  rename failure path.

- **RESOLVED - Stale `.intunewin` artifact moved out of source folder:** The March
  2026 package was moved to
  `AI Knowledgebase\System Scripts\Device Rename\White Glove Deploy\Archive\Stale-Package-Artifacts\`.

- **SUPERSEDED - Detection stale prefix-file false pass:** v1.0.2 hardcoded
  `$script:PrefixOverride = 'TD'`. v1.0.4/v1.0.3 switched to DevicePrefixApp as the
  source of truth, with the prefix file stored at
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.

- **RESOLVED - Logging path convention updated:** v1.0.4 writes error logs to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_Rename-Device-System_Install.txt`.

- **RESOLVED - Autopilot retry path lacked custom log:** v1.0.5 writes the IME
  script error log before exiting 2107 when Autopilot provisioning is not complete.

- **RESOLVED - Detect.ps1 reviewed and fixed:** P22 hardening applied (Get-TargetName
  simple function). .NOTES updated. Detect.ps1 bumped to v1.0.1. Paths and
  SerialTakeFromEnd confirmed aligned with install script. Detection is name-based
  (no version marker gate), so version numbers in .NOTES are informational only.

- **RESOLVED - DC reachability / 2103 exit code:** 2103 stays as Fail. Rationale: by
  the time the script reaches `Rename-Computer`, domain readiness has already been
  verified. A 2103 almost always means a real config problem (delegation, collision,
  locked object) that will not self-resolve on retry. Retry would mask failures and
  risk WG timeout.

- **ACCEPTED - Service account is personal account:** `$script:DomainUser = 'hallcounty\jhankinson'`.
  Jeremy accepted this risk; not changing.

- **RESOLVED - Portal retry code 2107:** Confirmed registered as Retry in Intune portal.

## Recent Changes

- 2026-06-10: Bumped install script to v1.0.3. Fixed scalar `.Count` risk. Added
  bounded domain/DC readiness check before rename. Bumped `Detect.ps1` to v1.0.2
  and set `PrefixOverride = 'TD'`. Moved stale `.intunewin` artifact to archive.

- 2026-06-10: Bumped install script to v1.0.4 and `Detect.ps1` to v1.0.3. Moved
  script-authored logs under IME Logs. Changed prefix source to the DevicePrefixApp
  file under IME IntuneFiles. `PrefixOverride` is blank again by default.

- 2026-06-11: Bumped install script to v1.0.5. Added custom log entry for the
  Autopilot-not-complete retry path so a 2107 from that guard leaves evidence in
  `SCRIPT_Rename-Device-System_Install.txt`.

- 2026-06-10: Bumped to v1.0.2. Removed `[Parameter(Mandatory)]` from `Write-ErrorLog`
  and `Get-TargetName` (P22 hardening). Added inline null guards to both functions.
  Updated `.NOTES` to required format.

## Required Validation Before Deployment

- Jeremy manually rebuilds the `.intunewin` package from the active source folder.
- Confirm portal settings: SysNative 64-bit install command, `-NonInteractive`,
  custom detection runs 64-bit, 2107 = Retry, 3010 = Soft reboot/success.
- Configure DevicePrefixApp as a dependency or otherwise ensure it completes before
  this rename app runs. Missing prefix file exits 2107 for retry.
- Run one White Glove pilot to verify domain readiness timing and rename behavior
  on the target network.

## Latest Work Log

### 2026-06-11 - Codex Prefix Path And Runtime Check

- Files reviewed: `Rename-Device-System.ps1`, `Detect.ps1`, this handoff and
  decisions, shared memory index.
- Files changed:
  - `Rename-Device-System.ps1` v1.0.4 -> v1.0.5
  - updated this handoff
- Findings accepted:
  - `Rename-Device-System.ps1` reads
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.
  - Paired `Detect.ps1` uses the same prefix file path with blank
    `$script:PrefixOverride`.
  - One retry path could exit 2107 without creating
    `SCRIPT_Rename-Device-System_Install.txt`: Autopilot provisioning not complete.
- Findings rejected: none.
- Rationale: Missing custom log does not prove the script cannot run. It can also
  mean the rename app never ran, it exited success, or it hit an unlogged retry
  path. The unlogged retry path was corrected.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: `Rename-Device-System.ps1` parse OK.
  - Parser: paired `Detect.ps1` parse OK.
  - Encoding: `Rename-Device-System.ps1` has UTF-8 BOM and zero non-ASCII
    characters excluding the BOM.
  - Confirmed required local cmdlets are present: `Rename-Computer`,
    `Get-CimInstance`, `ConvertTo-SecureString`, `New-Object`.
- Remaining risks or human decisions:
  - No `.intunewin` package was built by AI.
  - A missing custom log can still mean Intune never launched the rename app, for
    example because a dependency failed first.

### 2026-06-11 - Codex Failed White Glove Log Triage

- Files reviewed: pulled `Logs\Autopilot.cab`,
  `Logs\Fail_20260611-142426.zip`, extracted IME logs, DevicePrefixApp
  `Detect.ps1` and `Set-DevicePrefix.ps1`, this handoff and DevicePrefixApp
  handoff/decisions.
- Files changed:
  - DevicePrefixApp `Detect.ps1` v1.0.1 -> v1.0.2, expected prefix `FM-`
  - DevicePrefixApp and White Glove project handoffs/decisions
- Findings accepted:
  - The captured White Glove failure happened before `Rename-Device-System.ps1`
    ran. No `Rename-Device-System` execution or `SCRIPT_Rename-Device-System_Install.txt`
    was present in the pulled logs.
  - ESP tracked two Win32 apps: `Device Rename - Prefix: FM` and
    `Shortcut - Default Shortcut Pack`.
  - `Device Rename - Prefix: FM` installed successfully but failed post-install
    detection because its deployed detection script expected `TA-` instead of
    the `FM-` prefix produced by `-Prefix "FM"`.
- Findings rejected: none.
- Rationale: The rename script remained untested in this failed run because the
  prefix app blocked ESP first.
- Tests/validation performed:
  - Correlated `AppWorkload.log`, `AppActionProcessor.log`,
    `AgentExecutor.log`, and `EnrollmentStatusTracking.reg`.
  - Windows PowerShell 5.1 parser: DevicePrefixApp install/detect and White Glove
    install/detect scripts parse OK after the FM detection update.
  - Encoding: all four related runtime scripts have UTF-8 BOM and zero non-ASCII
    characters excluding the BOM.
- Remaining risks or human decisions:
  - Rebuild/re-upload the FM DevicePrefixApp package with matching detection.
  - Confirm the rename app is assigned as an ESP-blocking/dependent app once the
    prefix app detects correctly, otherwise the next run may still not exercise
    `Rename-Device-System.ps1`.

### 2026-06-10 - Codex Recheck After Claude

- Files reviewed: `Rename-Device-System.ps1`, `Detect.ps1`, DevicePrefixApp
  `Set-DevicePrefix.ps1`, DevicePrefixApp `Detect.ps1`, both project handoffs
  and decisions.
- Files changed: no runtime script changes.
- Findings accepted:
  - Active runtime scripts still parse under Windows PowerShell 5.1.
  - Active runtime scripts are UTF-8 BOM with zero non-ASCII characters.
  - Prefix file paths align across rename install, rename detection, prefix install,
    and prefix detection:
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.
  - Rename install logging follows new IME Logs convention:
    `SCRIPT_Rename-Device-System_Install.txt`.
- Findings rejected: none.
- Rationale: No code defect was found in the rename script itself during this pass,
  but successful deployment still depends on DevicePrefixApp ordering and exact
  prefix detection configuration.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: all four reviewed `.ps1` files parse OK.
  - Encoding: all four reviewed `.ps1` files have UTF-8 BOM and zero non-ASCII
    characters.
  - PS 5.1 syntax check confirmed `Set-Content -LiteralPath`,
    `Get-Content -LiteralPath`, and `Test-Path -LiteralPath` are valid.
  - PSScriptAnalyzer not installed locally.
- Remaining risks or human decisions:
  - Ensure DevicePrefixApp is a dependency or otherwise completes before rename.
  - Ensure DevicePrefixApp custom detection, not native file-exists detection, is
    used when exact prefix content matters.
  - Confirm DevicePrefixApp `Detect.ps1` expected prefix matches its install
    command for the deployed department package.

### 2026-06-10 - Claude (claude-sonnet-4-6)

- Files reviewed: `Rename-Device-System.ps1` v1.0.1 -> v1.0.2
- Files changed: `Rename-Device-System.ps1`
- Findings fixed: C1 (`Write-ErrorLog` P22), C2 (`Get-TargetName` P22), H1 (.NOTES format)
- Findings accepted/not changed: H2 (personal account - Jeremy accepted risk),
  H3 (2107 Retry - confirmed resolved), M1 (2103 Retry - pending human decision),
  M2 (Detect.ps1 - pending review), L1 (encoding - pre-packaging check required)
- Rationale: P22 fixes match established failure pattern from Remove-Office365 and
  RingCentral deployments. Simple functions eliminate the parameter-set resolution
  engine entirely.
- Tests/validation performed: Windows PowerShell 5.1 parse check - PARSE OK.
- Remaining risks or human decisions:
  - Detect.ps1 version sync to 1.0.2 - provide Detect.ps1 for next session
  - Portal 2103 Retry decision - human step
  - BOM + encoding verification - run before packaging

### 2026-06-10 - Codex

- Files reviewed: `Rename-Device-System.ps1`, `Detect.ps1`, same-folder package
  artifact, related historical Device Rename scripts for domain-readiness context.
- Files changed: no runtime script changes. Updated this handoff only.
- Validation performed:
  - Windows PowerShell 5.1 parser: both active `.ps1` files parse OK.
  - Encoding: both active `.ps1` files have UTF-8 BOM and zero non-ASCII characters.
  - PSScriptAnalyzer: not installed locally.
  - Local PS 5.1 scalar test confirmed `.Count` throws on a scalar registry key under
    StrictMode.
- Findings:
  - Active failure risk: `$Subkeys.Count` can throw if exactly one enrollment subkey
    is returned.
  - Active operational risk: DC reachability is not checked before AD rename.
  - Active packaging risk: stale March `.intunewin` remains next to edited June scripts.
  - Detection risk: blank `PrefixOverride` can false-pass against a stale prefix file
    when repurposing or changing prefixes.

### 2026-06-10 - Codex Implementation

- Files changed:
  - `Rename-Device-System.ps1` v1.0.2 -> v1.0.3
  - `Detect.ps1` v1.0.1 -> v1.0.2
  - moved stale `Rename-Device-System.intunewin` to the project archive
- Fixes implemented:
  - Wrapped enrollment subkey capture in `@(...)` before `.Count`.
  - Added bounded domain readiness check using local domain state, DC discovery,
    and secure channel verification before `Rename-Computer`.
  - Reused already-configured retry exit code 2107 for temporary domain not-ready
    conditions.
  - Set detection `PrefixOverride` to `TD` to avoid stale prefix file false positives.
- Validation performed:
  - Windows PowerShell 5.1 parser: both active `.ps1` files parse OK.
  - Encoding: both active `.ps1` files have UTF-8 BOM and zero non-ASCII characters.
  - Confirmed `C:\Windows\System32\nltest.exe` exists on the local validation host.
  - Confirmed active source folder now contains only `Rename-Device-System.ps1`
    and `Detect.ps1`.

### 2026-06-10 - Codex Logging And Prefix Path Update

- Files changed:
  - `Rename-Device-System.ps1` v1.0.3 -> v1.0.4
  - `Detect.ps1` v1.0.2 -> v1.0.3
  - shared `AGENTS.md` and `reference_intune_paths.md` logging/path standards
- Fixes implemented:
  - Script-authored log path changed to IME Logs with
    `SCRIPT_Rename-Device-System_Install.txt`.
  - Prefix file path changed to
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.
  - Rename script now reads the prefix file as the default source of truth.
  - If the prefix file is missing and no fallback is configured, install exits 2107
    so Intune retries.
- Validation performed:
  - Windows PowerShell 5.1 parser: active install and detect scripts parse OK.
  - Encoding: both active scripts have UTF-8 BOM and zero non-ASCII characters.
  - Active source folder contains only `Rename-Device-System.ps1` and `Detect.ps1`.
