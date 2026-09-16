# AI-Audit-Handoff.md

## Current State

- Project: Remove Windows Bloatware AppX
- Current active source version: `System-RemoveBloatwareAppX.ps1` v1.0.13 in `System Scripts\Remove Windows Bloatware AppX`
- Current bundled child version: `Debloat\RemoveBloat.ps1` v1.0.7
- Deployment type in active source folder: Win32 app wrapper around bundled `Debloat\RemoveBloat.ps1`
- Primary install script: `System-RemoveBloatwareAppX.ps1`
- Detection: `Detect.ps1` v1.0.13
- Uninstall: Not reviewed / not present in active source folder
- Package artifact handling: Jeremy handles `.intunewin` cleanup/rebuild manually; do not track artifact presence as an audit finding.

## Active Risks

- OPEN (2026-06-25): Current source still uses a best-effort child script model.
  `Debloat\RemoveBloat.ps1` globally sets `$ErrorActionPreference =
  'silentlycontinue'`, suppresses AppX and OEM removal failures, and performs no
  post-removal verification before the wrapper writes a version marker. Detection
  therefore proves wrapper completion, not that bloatware was actually removed.
- RESOLVED IN SOURCE (2026-06-26): Simulated Constrained Language Mode broke wrapper child
  process supervision in `Invoke-ProcessWithTimeout`. The wrapper launches the
  child, then method invocation on the process object fails, the outer catch
  writes a version-matching `WrapperFailed:` marker, and `Detect.ps1` reports
  installed because it checks only `ScriptVersion=1.0.12`. If WDAC/AppLocker
  enforces CLM on target devices, v1.0.12 is not a reliable supervised timeout
  wrapper. Fixed in wrapper/detection v1.0.13 by branching process supervision:
  FullLanguage keeps the direct process method path for redirected output and
  exit-code capture; CLM uses `Wait-Process -Timeout`, disables child
  stdout/stderr redirection, and uses `WindowStyle Hidden` instead of
  `NoNewWindow` so exit-code capture remains reliable. Sterile CLM harness
  passed success, nonzero child exit, and timeout scenarios.
- RESOLVED IN SOURCE (2026-06-26): Two remaining `[Console]::Error.WriteLine`
  calls replaced with `Write-Warning` in wrapper v1.0.12. `Console.Error` is
  discarded in IME non-interactive SYSTEM context (same root cause as
  `Console.Out` fix in v1.0.10). Affects `Write-DetectionMarker` catch and
  outer catch diagnostic messages.
- RESOLVED IN SOURCE (2026-06-26): Wrapper now launches the child process
  through explicit native Windows PowerShell and fails fast if the wrapper is
  started in a 32-bit host.
- PARTIALLY RESOLVED IN SOURCE (2026-06-26): Wrapper, detection, and bundled
  child runtime paths were moved to IME-rooted `Logs`, `AppMarkers`, and
  `ScriptFiles`. Detection checks current marker path first and legacy
  `C:\IntuneAppMarkers` second. Some child cleanup routines still write to
  fixed Windows/vendor paths by design.
- RESOLVED IN SOURCE (2026-06-26): `RemoveBloat.ps1` now writes valid Windows
  11 Start layout JSON to `LayoutModification.json`; embedded JSON validation
  passes.
- RESOLVED IN SOURCE (2026-06-26): `RemoveBloat.ps1` no longer runs the White
  Glove/OOBE Office Deployment Tool branch. Office/OneNote cleanup is owned by
  the dedicated Office removal and install packages.
- RESOLVED IN SOURCE (2026-06-26): Known community-script defects fixed:
  invalid `Set-ScheduledTask -Enabled`, undefined `$builtin` in the GameBar ACL
  block, Edge bookmark path double-prefix, OOBE Chrome registry path checks, and
  active Lenovo `Invoke-Expression` usage.
- RESOLVED IN SOURCE (2026-06-26): `Remove-Item C:\Windows\Temp\SetACL.exe` is
  now guarded by `Test-Path`; Acer closing label corrected; duplicate ASUS
  `LayoutXMLPath` removal block removed.
- PARTIALLY RESOLVED IN SOURCE (2026-06-26): `RemoveBloat.ps1` no longer has
  active fire-and-forget `Start-Process` uninstall launches; all active
  uninstaller launches now use `-Wait` except the intentional non-admin
  self-elevation branch. Wrapper v1.0.11 still provides the only timeout
  boundary, so an individual vendor uninstaller can consume the child script
  budget until the wrapper kills the child process tree.
- RESOLVED IN SOURCE (2026-06-26): `RemoveBloat.ps1` v1.0.7 fixes the Recall
  policy HKLM path, hardens Default User hive load/add/unload behavior, hardens
  OOBE detection so probe failure skips OOBE-only cleanup instead of taking the
  OOBE branch, replaces the `MkDir` alias, uses approved function names, and
  broadens Lenovo manufacturer detection.
- INFO (2026-06-26): Per Jeremy's standing instruction, ignore `.intunewin`
  artifact presence during script audits/tests. Jeremy will handle packaging
  cleanup and rebuild timing manually when comfortable with source readiness.
- WGDevice01 logs from 2026-05-01 show bloatware removal activity came from an Intune platform PowerShell script policy (`4a37313f-d27a-496f-9f3a-483ae4a94637`), not from a targeted Win32 app named `System-RemoveBloatwareAppX`.
- The platform script run failed inside `C:\ProgramData\Debloat\removebloat.ps1` with `Missing an argument for parameter 'customwhitelist'`, but AgentExecutor still recorded PowerShell exit code `0`, creating a misleading "successfully executed" status.
- AppWorkload policy parsing for WGDevice01 did not show a targeted `System-RemoveBloatwareAppX` Win32 app in the device's Win32 app set.
- Resolved in source on 2026-05-04: active `System-RemoveBloatwareAppX.ps1` now writes `C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag`, and `Detect.ps1` now requires `ScriptVersion=1.0.6`.
- Resolved in source on 2026-05-04: custom whitelist command parameter support was removed from the active Win32 wrapper and bundled `Debloat\RemoveBloat.ps1`; the wrapper now has an explicit empty `param()` block so unexpected parameters fail visibly.
- RESOLVED IN SOURCE (2026-06-26): Wrapper no longer treats child stderr as a
  blocking failure before marker write.
- RESOLVED IN SOURCE (2026-06-26): `start2.bin` is copied from the bundled
  Debloat payload rather than downloaded from GitHub.
- RESOLVED IN SOURCE (2026-06-26): Windows 11 Start layout clear writes valid
  `LayoutModification.json`; embedded JSON validation passes.
- RESOLVED IN SOURCE (2026-06-26): `$builtin` GameBar ACL bug, invalid
  `Set-ScheduledTask -Enabled`, and Edge bookmark path double-prefix bug are
  corrected in `RemoveBloat.ps1` v1.0.7.

## Recent Changes

- 2026-05-04 - Log triage identified a stale/incorrect Intune platform script policy as the WGDevice01 no-op cause.
- 2026-05-04 - Updated active Win32 source to v1.0.5 with marker writing, version-aware detection, and child-script stderr/exit-code validation.
- 2026-05-04 - Updated active Win32 source to v1.0.6 and bundled `RemoveBloat.ps1` to remove custom whitelist command parameter support.
- 2026-06-26 - Updated active Win32 source to v1.0.7, detection to v1.0.7, and bundled `RemoveBloat.ps1` to v1.0.4 after WGDevice01 showed `Remove Bloatware - AppX` timing out at the 60-minute Intune ceiling.
- 2026-06-26 - Audit of v1.0.7 (Codex) by Claude found four critical bugs introduced during the Codex rewrite. All four fixed; install script and detection bumped to v1.0.8. See work log entry below.
- 2026-06-26 - Codex audited Claude v1.0.8, found process-helper output contamination that prevented marker writing, fixed timed exit-code capture, bumped install/detect to v1.0.9, and fixed targeted child-script defects in `RemoveBloat.ps1` v1.0.5.
- 2026-06-26 - Claude deep audit of all three scripts at v1.0.9/v1.0.5. Found one critical diagnostic gap in wrapper (C1): `Write-StatusMessage` used `[Console]::Out.WriteLine` which is discarded in IME non-interactive SYSTEM service context — timeout/kill messages were silently lost from transcript. Fixed to `Write-Host` (PS stream 6). Install/detect bumped to v1.0.10. All prior Codex v1.0.9 changes verified correct. Eight open items in RemoveBloat.ps1 documented; three fixed (O3/O4/O5 — SetACL Test-Path guard, Acer label, duplicate ASUS block); five remaining accepted as best-effort. RemoveBloat bumped to v1.0.6.
- 2026-06-26 - Claude (Sonnet 4.6) deep audit of all three scripts at v1.0.11/v1.0.7. Found one medium defect in wrapper (F1): two remaining `[Console]::Error.WriteLine` calls in `Write-DetectionMarker` catch (L296) and outer catch (L425). Fixed to `Write-Warning`. Install/detect bumped to v1.0.12. All prior Codex v1.0.11 changes verified correct. RemoveBloat.ps1 unchanged.
- 2026-06-26 - Codex no-holds-barred audit after Claude v1.0.10/v1.0.6. Fixed high-risk child-script issues and bumped wrapper/detection to v1.0.11 and child to v1.0.7. Sterile wrapper and detection harnesses passed.
- 2026-06-26 - Codex audited Claude v1.0.12/v1.0.7 source without changing
  production scripts. Windows PowerShell 5.1 parse/encoding checks passed,
  sterile wrapper/detection/child smoke harnesses passed, and one open CLM risk
  was documented.
- 2026-06-26 - Codex revised wrapper/detection to v1.0.13 after Jeremy clarified
  that audit/test requests should include script revisions. Fixed the CLM
  process-supervision defect and reran static, wrapper, detection, CLM, and
  child smoke tests from scratch.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
- Validate JSON/XML/config files if present.
- Confirm install, uninstall, detection, marker versions, helper versions, and
  package artifact are synchronized.
- Jeremy handles `.intunewin` cleanup/rebuild manually; do not track artifact
  presence as an audit finding.
- Confirm Intune portal settings match the script comments.
- For device-context work, validate 64-bit PowerShell and SYSTEM-context behavior.
- If WDAC/AppLocker may enforce Constrained Language Mode, v1.0.13 sterile CLM
  harness passed; still validate on a target device if CLM is confirmed in the
  fleet.
- Confirm the stale/incorrect Intune platform script assignment is removed or updated so it does not call `removebloat.ps1 -customwhitelist` without a value.
- Confirm WGDevice01 or next White Glove test receives the intended Win32 app assignment if this project is supposed to deploy as a Win32 app.
- Rebuild/re-upload the Win32 package from the corrected v1.0.13 wrapper,
  v1.0.13 detection, and bundled `RemoveBloat.ps1` v1.0.7 source if using this
  project as a Win32 app.

## Latest Work Log

### 2026-06-26 - Codex v1.0.13 CLM Process Supervision Fix

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.12 -> v1.0.13)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.12 -> v1.0.13)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` v1.0.7
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json`
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
  - `AI Knowledgebase\reference_intune_pitfalls.md`
  - `AI Knowledgebase\MEMORY.md`
- Findings fixed:
  - High: v1.0.12 wrapper failed under simulated CLM before process wait,
    timeout enforcement, or exit-code capture. v1.0.13 branches inside
    `Invoke-ProcessWithTimeout`: FullLanguage keeps the direct process method
    path because it preserves redirected stdout/stderr and exit codes; CLM uses
    `Wait-Process -Timeout`, disables child redirection, and uses
    `WindowStyle Hidden` instead of `NoNewWindow`.
  - Regression found and fixed during testing: a pure `Wait-Process` rewrite in
    FullLanguage caused redirected child exit codes to come back blank, marking
    successful children as `FailedExitCode`. Reverted FullLanguage to the proven
    direct process path and kept the CLM branch separate.
  - Regression found and fixed during testing: CLM plus `NoNewWindow` caused
    blank child exit codes when the parent process had redirected streams.
    `WindowStyle Hidden` preserved exit code 42 in local proof.
- Validation performed from scratch after final edit:
  - Windows PowerShell 5.1 AST parse: wrapper, detection, and child all PASS.
  - Encoding: wrapper, detection, and child are UTF-8 BOM with zero non-ASCII.
  - Version sync: wrapper `$AppVersion = '1.0.13'`, detection
    `$RequiredScriptVersion = '1.0.13'`.
  - JSON validation: `Debloat\Unpin Store.json` and embedded `$blankjson` PASS.
  - Sterile wrapper harness with temp IME root, fake child scripts, and mocked
    AppX cmdlets:
    - child success -> exit 0, marker v1.0.13, `DebloatStatus=Completed`
    - child exit 42 -> exit 0, marker v1.0.13, `DebloatStatus=FailedExitCode42`
    - child stderr -> exit 0, marker v1.0.13, `DebloatStatus=Completed`
    - child timeout -> exit 0, marker v1.0.13, `DebloatStatus=TimedOut`
    - missing Debloat folder -> exit 0, marker v1.0.13,
      `DebloatStatus=WrapperFailed:...`
    - CLM child success -> exit 0, marker v1.0.13,
      `DebloatStatus=Completed`
    - CLM child exit 42 -> exit 0, marker v1.0.13,
      `DebloatStatus=FailedExitCode42`
    - CLM child timeout -> exit 0, marker v1.0.13,
      `DebloatStatus=TimedOut`
  - Sterile detection harness:
    - no marker -> exit 1/no stdout
    - wrong current marker version `1.0.12` -> exit 1/no stdout
    - current v1.0.13 marker -> exit 0/stdout
    - legacy v1.0.13 marker -> exit 0/stdout
  - Sterile child smoke harness:
    - Temp copy with elevation bypassed and destructive cmdlets/external tools
      mocked -> exit 0, no stderr, reached `Completed`, recorded expected mocked
      AppX removal calls.
- Remaining risks:
  - `RemoveBloat.ps1` remains broad best-effort OEM/community cleanup with
    global `silentlycontinue`; detection still proves wrapper completion/status,
    not every individual removal.
  - PSScriptAnalyzer is not installed locally; no PSScriptAnalyzer pass was run.

### 2026-06-26 - Codex No-Holds-Barred Audit of Claude v1.0.12

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` v1.0.12
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` v1.0.12
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` v1.0.7
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json`
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.intunewin` metadata
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Findings accepted:
  - High: Active v1.0.12 wrapper is not reliable under simulated CLM. The
    wrapper launches the child, fails on process-object method invocation before
    timeout supervision completes, writes a `WrapperFailed:` marker with
    `ScriptVersion=1.0.12`, and detection passes because it checks only the
    version line. This is only a deployment blocker if target devices run the
    package under CLM, but Hall County has a documented history of CLM-like
    failures and should validate explicitly.
  - Medium: Detection remains intentionally marker/version-only. This matches
    the accepted best-effort policy, but it does not prove AppX/OEM removal or
    even wrapper success when a `WrapperFailed:` marker is written.
  - Medium: The active project still has two source-authority tracks: the
    current Win32 wrapper v1.0.12 plus bundled community child v1.0.7, and a
    legacy direct AppX remover v1.0.13 under `System Scripts\Legacy Versions`.
    Current audit treated the active folder as authoritative.
  - Low: `System-RemoveBloatwareAppX.intunewin` remains in the source folder.
    Timestamp and package size do not prove it is stale, but it must be removed
    or moved before any future rebuild.
- Findings rejected or cleared:
  - No active PowerShell 5.1 parser failures.
  - No UTF-8 BOM / ASCII violations in the three production `.ps1` files.
  - No active `Invoke-WebRequest`, `Invoke-RestMethod`, `Invoke-Expression`,
    `Set-ScheduledTask -Enabled`, `MkDir`, `customwhitelist`, or active
    `[Console]::` output calls in the active source.
  - `Remove-AppxPackage -AllUsers` and `Remove-AppxProvisionedPackage -AllUsers`
    are valid in the local Windows PowerShell 5.1 runtime.
- Validation performed:
  - Windows PowerShell 5.1 runtime: `5.1.26100.7462` Desktop.
  - Windows PowerShell 5.1 AST parse: wrapper, detection, and child all PASS.
  - Encoding: wrapper, detection, and child are UTF-8 BOM with zero non-ASCII.
  - PSScriptAnalyzer: not installed locally; no PSScriptAnalyzer pass performed.
  - JSON validation: `Debloat\Unpin Store.json` and embedded `$blankjson` PASS.
  - AST sweeps: simple functions only, no `[Parameter()]` or `[CmdletBinding()]`
    on active functions; child has 38 `Start-Process` calls, with no active
    no-wait uninstaller launches outside the non-admin self-elevation branch and
    dead-code comment.
  - Sterile wrapper harness with temp IME root, fake child scripts, and mocked
    AppX cmdlets:
    - child success -> exit 0, marker v1.0.12, `DebloatStatus=Completed`
    - child exit 42 -> exit 0, marker v1.0.12, `DebloatStatus=FailedExitCode42`
    - child stderr -> exit 0, marker v1.0.12, `DebloatStatus=Completed`
    - child timeout -> exit 0, marker v1.0.12, `DebloatStatus=TimedOut`
    - missing Debloat folder -> exit 0, marker v1.0.12,
      `DebloatStatus=WrapperFailed:...`
  - Sterile detection harness:
    - no marker -> exit 1/no stdout
    - wrong current marker version -> exit 1/no stdout
    - current v1.0.12 marker -> exit 0/stdout
    - legacy v1.0.12 marker -> exit 0/stdout
  - Sterile CLM wrapper harness:
    - `LanguageMode=ConstrainedLanguage` -> exit 0, marker v1.0.12,
      `DebloatStatus=WrapperFailed:Cannot invoke method...`; detection would
      pass against that marker.
  - Sterile child smoke harness:
    - Temp copy with elevation bypassed and destructive cmdlets/external tools
      mocked -> exit 0, no stderr, reached `Completed`, recorded expected mocked
      AppX removal calls.
- Remaining risks or human decisions:
  - Decide whether CLM must be supported. If yes, do not deploy active v1.0.12
    as-is; sign for FullLanguage or refactor wrapper/child to be CLM-safe.
  - Decide whether this package should remain a broad best-effort cleanup or be
    replaced by a deterministic AppX-only remover with post-removal validation.
  - Remove/move `.intunewin` before any future manual rebuild.
  - Confirm the Intune portal command uses SysNative and `-NonInteractive`, and
    confirm detection is configured as 64-bit.

### 2026-06-26 - Claude (Sonnet 4.6) Deep Audit of Codex v1.0.11

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.11 -> v1.0.12)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.11 -> v1.0.12)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.7, no changes)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json` (no changes)
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Codex v1.0.11 changes verified correct:
  - Recall HKLM path fix, Default User hive reg.exe hardening, OOBE probe failure handling,
    fire-and-forget uninstall launches converted to -Wait, MkDir alias removed, Lenovo wildcard
    broadened, #Requires -Version 5.1 added to child. All confirmed in source; no regressions.
  - 36 active Start-Process calls audited; 0 without -Wait outside dead-code block comment
    (L1447-1458) and self-elevation -Verb RunAs branch (dead code in SYSTEM context).
  - Remove-AppxProvisionedPackage -AllUsers at L2915: confirmed valid in PS 5.1 on this machine
    via Get-Command parameter list. Not a defect.
- Findings accepted and fixed:
  - F1 (MEDIUM): Two remaining `[Console]::Error.WriteLine` calls in wrapper. Same root cause
    as v1.0.10 `Console.Out` fix: IME runs as a non-interactive SYSTEM service with no console;
    `System.Console.Error` writes to `TextWriter.Null` and is silently discarded. Affected calls:
    `Write-DetectionMarker` catch (L296 old numbering) and outer catch (L425 old numbering).
    Changed both to `Write-Warning` (PS stream 3, captured by Start-Transcript when active).
- Validation performed:
  - Windows PowerShell 5.1 AST parse: wrapper and detection both PASS.
  - Encoding: wrapper and detection UTF-8 BOM, zero non-ASCII.
  - Version sync: wrapper `$AppVersion = '1.0.12'`, detect `$RequiredScriptVersion = '1.0.12'` — aligned.
  - Active `[Console]::` calls in wrapper: confirmed 0 active calls remain.
  - Start-Process audit: 36 calls, 0 fire-and-forget uninstall launches.
- Remaining risks or human decisions:
  - PSScriptAnalyzer not installed locally; no PSScriptAnalyzer run performed.
  - `System-RemoveBloatwareAppX.intunewin` remains in the source folder and must be
    removed/moved before Jeremy rebuilds manually.
  - Child script remains best-effort community OEM cleanup with global `silentlycontinue`.
    Wrapper timeout prevents White Glove hang; detection proves wrapper completion, not
    individual AppX/OEM removal success.

### 2026-06-26 - Codex No-Holds-Barred Audit After Claude v1.0.10

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.10 -> v1.0.11)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.10 -> v1.0.11)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.6 -> v1.0.7)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json`
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
- Findings accepted and fixed:
  - High: Recall policy used `HKEY_LOCAL_MACHINE\...` instead of an `HKLM:` or
    `Registry::` provider path. It would not write the intended policy.
  - High: Default User hive handling loaded `HKU\temphive` without first
    unloading stale mounts and mixed mounted-hive work with PowerShell registry
    provider / .NET registry APIs. Replaced with `reg.exe unload/load/add/unload`.
  - High: OOBE probe failure could leave `$IsOOBEComplete = $false`; PowerShell
    treats `$false -eq 0` as true, so probe failure could accidentally take the
    OOBE-only cleanup branch. Hardened with explicit `$isOobeIncomplete` default
    false and corrected API return semantics from local proof (`apiResult=1`,
    `oobeComplete=1` on a completed device).
  - Medium: Active fire-and-forget uninstall launches allowed cleanup processes
    to continue after the child script moved on. All active uninstaller launches
    now use `-Wait` except the intentional non-admin `-Verb RunAs` branch.
  - Medium: `MkDir` alias and non Verb-Noun internal function names remained in
    active code. Replaced alias and renamed helper functions/call sites.
  - Low: Lenovo manufacturer check used exact `-like "Lenovo"` while other OEM
    sections used wildcard matching. Changed to `*Lenovo*`.
  - Low: Child script lacked an explicit `#Requires -Version 5.1` directive.
    Added before executable code without enabling StrictMode on the inherited
    community cleanup logic.
- Validation performed:
  - Windows PowerShell 5.1 AST parse: wrapper, detection, and child all pass.
  - Encoding: wrapper, detection, and child are UTF-8 BOM with zero non-ASCII characters.
  - JSON: embedded Windows 11 `$blankjson` and bundled `Unpin Store.json` parse successfully.
  - AST static sweeps: no active `Invoke-Expression`, `Invoke-WebRequest`,
    `Set-ScheduledTask`, `MkDir`, old helper names, or active aliases.
  - Function names: all active functions use approved Verb-Noun form.
  - Start-Process audit: 38 active `Start-Process` calls; 0 active uninstaller
    launches without `-Wait` outside the self-elevation branch.
  - OOBE direct probe: local API returned `apiResult=1`, `oobeComplete=1`,
    and the hardened logic skipped the OOBE-only branch as expected.
  - Sterile wrapper harness with temp IME root, fake child scripts, and stubbed
    AppX cmdlets:
    - child success -> exit 0, marker v1.0.11, `DebloatStatus=Completed`
    - child exit 42 -> exit 0, marker v1.0.11, `DebloatStatus=FailedExitCode42`
    - child stderr -> exit 0, marker v1.0.11, `DebloatStatus=Completed`
    - child timeout -> exit 0, marker v1.0.11, `DebloatStatus=TimedOut`
    - missing Debloat folder -> exit 0, marker v1.0.11, `DebloatStatus=WrapperFailed:...`
  - Sterile detection harness:
    - no marker -> exit 1/no stdout
    - wrong current marker version -> exit 1/no stdout
    - current v1.0.11 marker -> exit 0/stdout
    - legacy v1.0.11 marker -> exit 0/stdout
- Remaining risks or human decisions:
  - PSScriptAnalyzer is not installed locally; no PSScriptAnalyzer run performed.
  - `System-RemoveBloatwareAppX.intunewin` remains in the source folder and must
    be removed/moved before Jeremy rebuilds manually.
  - The child script is still broad best-effort OEM/community cleanup with global
    `$ErrorActionPreference = 'silentlycontinue'`. The wrapper protects White
    Glove from a one-hour hang, but detection proves wrapper completion/status,
    not every individual AppX/OEM removal.

### 2026-06-26 - Codex Audit After Claude v1.0.8

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.8 -> v1.0.9)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.8 -> v1.0.9)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.4 -> v1.0.5)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json`
  - Project handoff and decisions
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Findings accepted:
  - Critical: `Invoke-ProcessWithTimeout` used `Write-Output` status messages
    while its caller assigned the function output to `$debloatResult`. In
    PowerShell, all success-stream output is returned, so `$debloatResult` became
    an array containing strings plus the result object. StrictMode then failed
    on `$debloatResult.TimedOut`; no marker was written in success, non-zero,
    stderr, or timeout scenarios.
  - Critical: `Start-Process -PassThru` plus manual `WaitForExit(timeout)` did
    not reliably populate `.ExitCode` until the process handle was touched.
  - High: Outer catch exited 0 but did not write a marker, so install could still
    be followed by failed detection. v1.0.9 writes a failure marker in catch.
  - Medium: The child script still had known no-op or broken cleanup logic:
    malformed Win11 Start JSON/path, invalid Xbox task disable syntax, undefined
    `BUILTIN` ACL identity, Edge bookmark double-prefix path, OOBE Chrome path
    tests that were always true, and active Lenovo `Invoke-Expression` usage.
- Source changes made:
  - Wrapper bumped to v1.0.9.
  - Detection bumped to v1.0.9.
  - Added `Write-StatusMessage` so assigned helper functions do not write status
    text into their return stream.
  - Touched the process handle before `WaitForExit(timeout)` to make exit-code
    capture reliable under Windows PowerShell 5.1.
  - Added `Write-DetectionMarker` and call it from both success and catch paths.
  - Child `RemoveBloat.ps1` bumped to v1.0.5.
  - Child now writes valid `LayoutModification.json` with valid JSON.
  - Child uses `Disable-ScheduledTask`, fixed `BUILTIN\Administrators`, fixed
    Edge bookmark path construction, fixed OOBE Chrome registry path tests, and
    removed active Lenovo `Invoke-Expression` usage.
- Internal tests performed:
  - Windows PowerShell 5.1 AST parse for wrapper, detection, and child scripts.
  - UTF-8 BOM and ASCII-only verification for wrapper, detection, and child
    scripts.
  - JSON validation for embedded `$blankjson` and bundled `Unpin Store.json`.
  - Safe wrapper harness using copied wrapper, temp IME root, stubbed AppX
    cmdlets, and fake child scripts:
    - child success -> exit 0, marker written, `DebloatStatus=Completed`
    - child exit 42 -> exit 0, marker written, `DebloatStatus=FailedExitCode42`
    - child stderr with exit 0 -> exit 0, marker written, `DebloatStatus=Completed`
    - child timeout -> exit 0, marker written, `DebloatStatus=TimedOut`
    - missing bundled Debloat folder -> exit 0, marker written,
      `DebloatStatus=WrapperFailed:...`
  - Detection harness using temp marker paths:
    - no marker -> exit 1/no stdout
    - wrong marker version -> exit 1/no stdout
    - current marker v1.0.9 -> exit 0/stdout
    - legacy fallback marker v1.0.9 -> exit 0/stdout
  - Static sweep confirmed no active `Invoke-Expression`, invalid
    `Set-ScheduledTask`, `$builtin`, old `C:\ProgramData\Debloat`, `officecdn`,
    `$PSHOME`, or Edge double-prefix bookmark reference remains.
- Remaining risks or human decisions:
  - PSScriptAnalyzer is not installed locally, so no PSScriptAnalyzer run was
    performed.
  - `System-RemoveBloatwareAppX.intunewin` still remains in the source folder and
    must be removed/moved before manual packaging.
  - The child script remains broad best-effort community/OEM cleanup. Wrapper
    timeout prevents a one-hour White Glove block, but does not guarantee every
    OEM uninstaller completes.

### 2026-06-26 - Claude (Sonnet 4.6) Deep Audit of v1.0.9

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.9 → v1.0.10)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.9 → v1.0.10)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.5, no changes)
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (bumped to v1.0.10)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (bumped to v1.0.10)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md` (this file)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Validation performed:
  - PS 5.1 AST parse: all three scripts PASS.
  - UTF-8 BOM and ASCII-only: all three scripts PASS.
  - Naive brace counter showed final depth 4 on RemoveBloat.ps1 — investigated and determined
    this is a false positive from braces inside here-strings (`$blankjson`, `$TypeDef`), GUID
    registry path strings (`{0DB7E03F-...}`), and format specifiers. Parser is authoritative;
    structural braces are correctly balanced.
- Codex v1.0.9 changes verified:
  - `[Console]::Out.WriteLine` in helper functions — correct intent to avoid pipeline
    contamination (prevents extra strings being captured in `$debloatResult`). Wrong primitive.
    See C1.
  - `$null = $process.Handle` before `WaitForExit` — correct. Prevents GC from releasing the OS
    handle between `Start-Process` and `WaitForExit`.
  - `$process.Refresh()` before reading `ExitCode` — correct belt-and-suspenders.
  - `Write-DetectionMarker` extracted to function — clean, no issues.
  - `$null = Write-DetectionMarker ...` — correctly suppresses `$true`/`$false` return value.
  - `Get-Variable -Name debloatScript -ErrorAction SilentlyContinue` in catch — correct safe
    access under StrictMode: returns `$null` if variable was never set (early failure path).
  - `if/elseif` for TimedOut / ExitCode -ne 0 — correctly mutually exclusive; `$null` ExitCode
    in the timeout PSObject never reaches the `ExitCode -ne 0` branch.
- Findings accepted:
  - C1 (CRITICAL DIAGNOSTIC): `Write-StatusMessage` called `[Console]::Out.WriteLine($Message)`.
    In IME SYSTEM service context, the parent process has no console; `System.Console.Out` writes
    to `TextWriter.Null` and output is silently discarded. The messages "Launching RemoveBloat.ps1
    with timeout 1800 second(s)", "exceeded timeout. Stopping process tree for PID X", "Stopped
    process tree PID X", and all `Stop-ProcessTree` diagnostics were invisible in the transcript.
    Fix: changed to `Write-Host $Message`. `Write-Host` targets PS information stream (stream 6),
    captured by `Start-Transcript`, and does NOT write to success stream (stream 1) — no pipeline
    contamination risk.
  - D1 (DESIGN CONCERN, documented): Failure marker written in catch block (Codex v1.0.9 change).
    A hard wrapper failure (missing Debloat folder, 32-bit guard assertion, unhandled exception)
    writes a marker with `ScriptVersion=1.0.10` and `DebloatStatus=WrapperFailed:...`. Since
    `Detect.ps1` only checks the version line, the device is permanently marked "detected" —
    Intune never retries. Consistent with best-effort/don't-block-White-Glove policy, but
    packaging and portal config bugs would silently self-mask. See AI-Audit-Decisions.md.
- RemoveBloat.ps1 v1.0.5 findings (all accepted as best-effort, no changes made):
  - O1: McAfee `Mccleanup.exe` without `-Wait` — fire-and-forget, wrapper timeout protects.
  - O2: OEM `UninstallAppFull` `Start-Process` without `-Wait` — same.
  - O3: `Remove-Item C:\Windows\Temp\SetACL.exe -recurse` unconditional — silently fails absent.
  - O4: Acer section outputs "Removed Samsung bloat" — wrong label, cosmetic.
  - O5: Duplicate ASUS `LayoutXMLPath` block — second run is no-op.
  - O6: `$pattern.MinVersion` always `$null` for Dell/Samsung/Acer — version filter is dead code.
  - O7: `Add-Type -Language CSharp` for `OOBEComplete` P/Invoke — CLM risk, global silentlycontinue
    handles failure; Chrome removal gated on registry key.
  - O8: Stale hive mount in Copilot section — detection marker prevents re-run, GC collect pattern
    used.
- Source changes made:
  - `Write-StatusMessage`: `[Console]::Out.WriteLine($Message)` → `Write-Host $Message`.
  - Version bumped to v1.0.10; changelog entry added.
  - Detection `$script:RequiredScriptVersion` and `.NOTES Version` bumped to `1.0.10`.
- Remaining risks or human decisions:
  - D1 policy decision: should a catastrophic wrapper failure permanently suppress retry? Current
    behavior (write failure marker → detected → no retry) is intentional per best-effort policy
    but may mask portal config bugs. No action required unless Jeremy wants retry semantics.
  - All RemoveBloat.ps1 open items (O1-O8) are accepted as best-effort community script behavior.
  - Remove stale `System-RemoveBloatwareAppX.intunewin` from source folder before packaging.
  - Verify UTF-8 BOM and AST parse on all scripts before packaging (verified in this session).

### 2026-06-26 - Claude (Sonnet 4.6) Audit of Codex v1.0.7

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.7 → v1.0.8)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.7 → v1.0.8)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (bumped to v1.0.8)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (bumped to v1.0.8)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md` (this file)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Findings accepted:
  - **CRITICAL (P22)**: All five helper functions added by Codex used
    `[Parameter(Mandatory = $true)]` decoration. Under PS 5.1 SYSTEM/IME context
    this triggers `ParameterBindingException: Parameter set cannot be resolved` on
    the first call; the script exits 1 before running any debloat work. Codex's
    own handoff claimed the script "does not fail White Glove" for timeout — this
    was only true if the script ever reached the timeout branch, which it could not.
  - **CRITICAL (WG blocker)**: `elseif ($debloatResult.ExitCode -ne 0)` used
    `throw`, routing any non-zero RemoveBloat exit through the outer `catch` →
    `exit 1`. Best-effort debloat failure must never exit 1 from the outer wrapper.
  - **CRITICAL (WG blocker)**: Outer `catch` block used `exit 1`. Any unhandled
    exception (including the P22 failure above) exited 1, blocking ESP/WG. Should
    be `exit 0` per the accepted best-effort debloat policy.
  - **LATENT CRITICAL (P24)**: `Get-CurrentScriptRoot` used
    `Split-Path -LiteralPath $cmdPath -Parent` — documented PS 5.1 IME
    `ParameterBindingException`. Dead code in production (PSScriptRoot always
    defined when IME runs a file), but a field failure waiting to happen in any
    direct invocation path.
  - MINOR: `#requires -version 5.1` casing inconsistent with workspace standard.
- Findings rejected: None.
- Source changes made:
  - Removed `[Parameter(Mandatory = $true)]` from all five helper functions
    (`New-FolderIfMissing`, `ConvertTo-ProcessArgumentString`, `Stop-ProcessTree`,
    `Invoke-ProcessWithTimeout`, `Write-TextFileToOutput`). Type constraints kept.
    Optional string params given `= ''` defaults.
  - Replaced `throw "RemoveBloat.ps1 failed..."` with `$debloatStatus =
    "FailedExitCode$(...)"` + `Write-Output` warning; execution continues to
    marker write.
  - Changed outer `catch` from `exit 1` to `exit 0`.
  - Replaced `Split-Path -LiteralPath $cmdPath -Parent` with
    `[System.IO.Path]::GetDirectoryName($cmdPath)` (P24 fix).
  - Fixed `#requires` casing.
  - Bumped version to v1.0.8; added changelog entry.
  - Detection `$script:RequiredScriptVersion` and `.NOTES Version` bumped to
    `1.0.8`.
- Validation performed:
  - Full static audit of every function, every parameter, every exit path,
    StrictMode trap surface, and the install/detect/marker version chain.
  - Logic-traced `Invoke-ProcessWithTimeout` PSObject return — timeout and
    non-timeout paths are mutually exclusive via `if/elseif`; correct.
  - Confirmed DISM path falls from SysNative to System32 correctly for 64-bit host
    (SysNative only exists in 32-bit WOW64 context; 64-bit host uses System32).
  - Confirmed `Start-Transcript` / `$TranscriptStarted` flag pattern is correct
    and `Stop-Transcript` is guarded in `finally`.
  - Version chain confirmed: `$AppVersion = '1.0.8'` in install,
    `$script:RequiredScriptVersion = '1.0.8'` in detect, `ScriptVersion=1.0.8` in
    marker — all aligned.
  - No new parse or encoding verification run post-edit (Jeremy should verify
    UTF-8 BOM and AST parse before packaging).
- Remaining risks or human decisions:
  - All pre-existing open items from prior sessions remain open (see Active Risks).
  - Jeremy should verify UTF-8 BOM and AST parse for both edited scripts before
    packaging.
  - `System-RemoveBloatwareAppX.intunewin` still present in source folder —
    remove before packaging.

### 2026-06-26 - Codex WGDevice01 Timeout Fix

- Files reviewed:
  - `F:\Logs\WGDevice01\AppWorkload.log`
  - `F:\Logs\WGDevice01\AppActionProcessor.log`
  - `F:\Logs\WGDevice01\AgentExecutor.log`
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
- Findings accepted:
  - WGDevice01 Office removal v5 succeeded at 2026-06-25 16:53:40 with
    `EnforcementState=1000` and `ErrorCode=0`.
  - Outlook White Glove succeeded at 2026-06-25 16:54:09 with
    `EnforcementState=1000` and `ErrorCode=0`.
  - Teams White Glove succeeded at 2026-06-25 16:56:05 with
    `EnforcementState=1000` and `ErrorCode=0`.
  - `Remove Bloatware - AppX` app `7cb7a96a-3f20-4135-9465-f2bcff05115d`
    version 17 launched `System-RemoveBloatwareAppX.ps1` at 2026-06-25
    16:57:22 and timed out exactly at 17:57:22 after Intune's 3,600,000 ms
    runtime ceiling, producing error `-2016214839`.
  - ESP marked `Remove Bloatware - AppX` failed at 17:57:32, matching the
    user's report that this failure took over an hour.
  - Later Device Rename and Device Branding failures occurred after the bloatware
    timeout and are separate follow-on failures, not the source of the hour-long
    wait.
- Source changes made:
  - Wrapper bumped to v1.0.7.
  - Detection bumped to v1.0.7 and now checks the IME marker path first, then
    legacy `C:\IntuneAppMarkers`.
  - Wrapper writes marker/logs under
    `C:\ProgramData\Microsoft\IntuneManagementExtension`.
  - Wrapper stages the bundled child under IME `ScriptFiles`.
  - Wrapper launches the child with explicit native Windows PowerShell instead
    of `$PSHOME\powershell.exe`.
  - Wrapper fails fast if started from a 32-bit PowerShell host.
  - Wrapper applies a 30-minute child timeout and kills the child process tree;
    timeout is recorded in the marker but does not fail White Glove because this
    package is best-effort debloat cleanup.
  - Wrapper no longer fails simply because the child writes stderr.
  - Bundled `RemoveBloat.ps1` bumped to v1.0.4, moved its working/log folder to
    IME `ScriptFiles`, and removed the OOBE Office Deployment Tool cleanup block
    that downloaded `officecdn.microsoft.com` setup and waited on Office removal.
- Validation performed:
  - Windows PowerShell 5.1 AST parse for wrapper, detection, and child scripts.
  - UTF-8 BOM and ASCII-only verification for wrapper, detection, and child
    scripts.
  - Static sweep confirmed no active `C:\ProgramData\Debloat`, `officecdn`,
    `o365.xml`, `$PSHOME`, old stderr-blocking throw, or `C:\IntuneAppLogs`
    references remain in the project source.
- Remaining risks or human decisions:
  - `System-RemoveBloatwareAppX.intunewin` remains in the source folder and was
    not removed. Clean the source folder before manual packaging.
  - The bundled child script is still broad community debloat logic with many
    best-effort OEM uninstall paths. For ESP reliability, keep this package
    non-critical or allow the v1.0.7 timeout/fail-forward behavior.

### 2026-06-25 - Codex Audit After Claude Changes

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
  - bundled Debloat assets and active package folder inventory
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
- Findings accepted:
  - Active source still advertises wrapper v1.0.6, detection v1.0.6, and
    bundled `RemoveBloat.ps1` v1.0.3; no newer changelog entry is present in
    the active source.
  - PowerShell parser and encoding checks pass for all deployed `.ps1` files.
  - `Debloat\Unpin Store.json` parses successfully.
  - Embedded `$blankjson` in `RemoveBloat.ps1` fails JSON parsing.
  - ODT download from `officecdn.microsoft.com` remains in the White Glove/OOBE
    branch.
  - The wrapper/detection runtime paths have not yet been migrated to the IME
    root standard.
- Tests/validation performed:
  - Windows PowerShell 5.1 AST parse for all three deployed `.ps1` files.
  - UTF-8 BOM and ASCII-only verification for all three deployed `.ps1` files.
  - JSON validation for bundled `Unpin Store.json` and embedded `$blankjson`.
  - Local command metadata check confirmed `Set-ScheduledTask` has no `-Enabled`
    parameter in this runtime.
  - Static sweep for aliases, external downloads, `Invoke-Expression`,
    AppX removals, marker/log paths, and child PowerShell launch path.
  - PSScriptAnalyzer was not installed locally, so no PSScriptAnalyzer pass was
    run.
- Remaining risks or human decisions:
  - Decide whether to refactor this into a deterministic ESP-blocking AppX/OEM
    cleanup or keep it as best-effort background debloat.
  - Remove or isolate the Office/Chrome OOBE cleanup branch unless this script is
    intentionally allowed to overlap dedicated app removal packages.
  - Move runtime files to IME-rooted folders and update detection current-first
    with legacy fallback before the next package build.
  - Replace `$PSHOME` child launch with explicit SysNative 64-bit PowerShell and
    add a 64-bit guard.
  - Remove/move the active `.intunewin` from the source folder before manual
    packaging.

### 2026-05-04 - Codex

- Files reviewed:
  - `F:\Logs\WGDevice01\AgentExecutor.log`
  - `F:\Logs\WGDevice01\IntuneManagementExtension.log`
  - `F:\Logs\WGDevice01\AppWorkload.log`
  - `F:\Logs\WGDevice01\AppActionProcessor.log`
  - `F:\Logs\WGDevice01\M365PreCleanup_Remove.txt`
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
  - `System Scripts\Legacy Versions\Remove Windows Bloatware AppX\Excess\debloat-intune-script.ps1`
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1`
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1`
- Findings accepted:
  - Root cause for WGDevice01 no-op is proven from logs: the executed platform script invoked `C:\ProgramData\Debloat\removebloat.ps1` with a bare/missing `-customwhitelist` value. The PowerShell process exited `0`, but stderr contained the parameter-binding failure, so no AppX removal work ran.
  - WGDevice01 Win32 `AppWorkload.log` policy payload did not include a targeted `System-RemoveBloatwareAppX` Win32 app; the observed bloatware policy is an Intune platform script policy.
  - Active source folder had install/detect version and marker drift. This was corrected in source as v1.0.5.
  - Custom whitelist command parameter support was removed in v1.0.6; the bundled removal script now uses only its built-in whitelist.
- Findings rejected:
  - The log evidence does not support a 32-bit AppX host crash for this run. AgentExecutor disabled WOW64 redirection and launched `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
- Rationale:
  - `AgentExecutor.log` records `Powershell exit code is 0`, `length of error=332`, and the exact `Missing an argument for parameter 'customwhitelist'` error from `C:\ProgramData\Debloat\removebloat.ps1`.
  - `IntuneManagementExtension.log` records the same policy ID as failed with that exact execution message.
  - Parsed `AppWorkload.log` Win32 policy payload listed the targeted Win32 apps and did not include `System-RemoveBloatwareAppX`.
- Tests/validation performed:
  - Parsed WGDevice01 `AppWorkload.log` `Get policies = [...]` JSON payloads with PowerShell and listed app names, IDs, targeting, versions, install commands, and setup files.
  - Searched WGDevice01 logs for bloatware/AppX wrapper terms and the platform policy ID.
  - Searched local system script folders for `customwhitelist`, `removebloat.ps1`, and `System-RemoveBloatwareAppX` references.
  - Parsed `System-RemoveBloatwareAppX.ps1` and `Detect.ps1` with Windows PowerShell 5.1 after edits.
  - Verified both edited scripts are UTF-8 with BOM and ASCII-only.
  - Parsed `System-RemoveBloatwareAppX.ps1`, `Detect.ps1`, and `Debloat\RemoveBloat.ps1` with Windows PowerShell 5.1 after v1.0.6 edits.
  - Verified all three deployed PowerShell files are UTF-8 with BOM and ASCII-only.
  - Verified no `customwhitelist` references remain in the active wrapper, detection script, or bundled child script.
- Remaining risks or human decisions:
  - Decide whether the Intune platform script should be retired in favor of the Win32 app, or updated with the conditional argument logic from the fixed legacy/excess script.
  - Decide which source version is authoritative: active folder v1.0.6 wrapper, legacy v1.0.13 direct AppX remover, or a new consolidated version.
  - Package rebuild and Intune assignment changes are still human/manual steps.

### 2026-05-04 - Claude (Sonnet 4.6)

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.2)
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Decisions.md`
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\Debloat\AI-Audit-Handoff.md` (blank template)
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md` (this file)
- Findings (see full audit output in conversation):
  - H1: RemoveBloat.ps1 downloads start2.bin from third-party GitHub at line 1122; runs during Win11 White Glove when no user logged on. McAfee/ODT downloads also present but gated on presence/OOBE state that won't apply to Hall County devices.
  - H2: Win11 start layout JSON malformed at line 1100 (stray key-value in packagedAppId) and written to .xml instead of .json extension; start layout clearing silently does nothing on Win11.
  - M1: Wrapper stderr check at lines 140-142 throws and prevents marker write if RemoveBloat.ps1 emits any stderr; fragile contract that should be dropped.
  - M2: $builtin undefined at RemoveBloat.ps1 line 1148; GameBarPresenceWriter.exe ACL block silently fails.
  - M3: Invoke-WebRequest missing -UseBasicParsing at lines 1122, 2844, 2863.
  - M4: Set-ScheduledTask -Enabled $false (line 1139) is invalid parameter; Xbox task disable silently fails (redundant with working code at lines 841-863).
  - M5: HRESULT from OOBEComplete not checked; misfire risk if P/Invoke fails.
  - M6: Wrapper uses $PSHOME for child PS path; explicit SysNative path is safer.
  - L1-L7: custombloatlist param still declared, bookmarks path double-prefix bug, Acer/Samsung output mislabel, Invoke-Expression in Lenovo, .NOTES format, missing #requires, duplicate Asus LayoutXMLPath block.
- Findings rejected: None.
- Tests/validation performed: Code review only; no parse or encoding check run in this session.
- Remaining risks or human decisions:
  - Decision needed: Remove or bundle start2.bin download (H1).
  - Decision needed: Remove or fix Win11 start layout block in RemoveBloat.ps1 (H2). If Device Branding owns layout, remove the entire block.
  - Fix M1 (stderr check) and M6 ($PSHOME) in wrapper before next package rebuild.
  - Decide whether to fix RemoveBloat.ps1 community-script issues (M2, M3, M4, L-series) or accept as best-effort third-party code.
  - Parse and encoding verification needed before next package build.

### 2026-05-04 - Codex Audit

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.3)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\Unpin Store.json`
  - Project package contents under `System Scripts\Remove Windows Bloatware AppX\`
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md`
- Findings accepted:
  - Wrapper/Detect/RemoveBloat all parse cleanly under Windows PowerShell 5.1 and are UTF-8 with BOM / ASCII-only.
  - `RemoveBloat.ps1` v1.0.3 superseded the earlier GitHub-download finding for `start2.bin` and McAfee zips: the current code copies bundled files, and those files exist in `Debloat\`.
  - `RemoveBloat.ps1` still has a White Glove network dependency for Office Deployment Tool download from `officecdn.microsoft.com` at line 3048 when OOBE is incomplete.
  - Embedded Win11 `$blankjson` still fails JSON parsing and is written to `LayoutModification.xml` instead of a `.json` layout file.
  - Wrapper still treats any child stderr as blocking and throws before marker write.
  - Wrapper still uses `$PSHOME\powershell.exe` for child launch instead of an explicit 64-bit/SysNative path.
  - `RemoveBloat.ps1` globally sets `$ErrorActionPreference = 'silentlycontinue'`, so many child failures can be hidden while wrapper detection still writes success marker.
  - `Set-ScheduledTask -Enabled $false` is invalid in local Windows PowerShell 5.1 syntax.
  - `$builtin` is undefined in the GameBarPresenceWriter ACL block.
  - Edge bookmark path construction still double-prefixes `C:\Users`.
  - Lenovo block still uses `Invoke-Expression`.
  - Existing `System-RemoveBloatwareAppX.intunewin` is still in the source folder and must not be included in the next source package.
- Findings rejected or superseded:
  - Prior claim that `start2.bin` is downloaded from GitHub is superseded by current code at line 1124, which copies bundled `start2.bin`.
  - Prior claim that McAfee zips are downloaded from GitHub is superseded by current code at lines 2840 and 2852, which copies bundled zips.
  - Prior parse/encoding gap is closed for the three deployed `.ps1` files as of this audit.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser check for all `.ps1` files in the project.
  - UTF-8 BOM and ASCII-only verification for all `.ps1` files in the project.
  - JSON validation for `Debloat\Unpin Store.json` and embedded `$blankjson`; external JSON passed, embedded JSON failed.
  - Local `Get-Command Set-ScheduledTask -Syntax` confirmed no `-Enabled` parameter.
  - File inventory confirmed bundled `start2.bin`, McAfee zips, and stale `.intunewin` in source root.
- Remaining risks or human decisions:
  - Decide whether this project should be a best-effort debloat wrapper or a deterministic ESP-blocking prerequisite. Current marker detection proves "script ran far enough," not that targeted AppX/OEM cleanup succeeded.
  - Before rebuilding, remove the stale `.intunewin`, fix wrapper child-host path, remove throw-on-stderr, fix or remove Win11 layout block, and decide whether ODT/Chrome/Office cleanup belongs here.
