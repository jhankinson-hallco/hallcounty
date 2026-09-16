# AI-Audit-Handoff.md

## Current State

- Project: Remove Windows Bloatware AppX
- Current active source version: `System-RemoveBloatwareAppX.ps1` v1.1.0 in `System Scripts\Remove Windows Bloatware AppX`
- Deployment type in active source folder: Win32 app wrapper around bundled `Debloat\RemoveBloat.ps1`
- Primary install script: `System-RemoveBloatwareAppX.ps1`
- Detection: `Detect.ps1` v1.1.0 (paired to wrapper v1.1.0)
- Uninstall: Not reviewed / not present in active source folder
- Package artifact: `System-RemoveBloatwareAppX.intunewin` (stale - not yet rebuilt for v1.1.0; packaging is Jeremy's manual step)
- Marker: `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\System-RemoveBloatwareAppX.marker` (moved off the legacy `C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag` path in v1.1.0; legacy path still checked by `Detect.ps1` as a temporary existence-only fallback for already-deployed v1.0.x devices)
- Error log: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_RemoveBloatwareAppX_Install.txt` (error-only; new in v1.1.0, replaces the old ad hoc `C:\IntuneAppLogs\RemoveBloatwareAppX_Install.txt` DISM-failure note)

## Active Risks

- WGDevice01 logs from 2026-05-01 show bloatware removal activity came from an Intune platform PowerShell script policy (`4a37313f-d27a-496f-9f3a-483ae4a94637`), not from a targeted Win32 app named `System-RemoveBloatwareAppX`.
- The platform script run failed inside `C:\ProgramData\Debloat\removebloat.ps1` with `Missing an argument for parameter 'customwhitelist'`, but AgentExecutor still recorded PowerShell exit code `0`, creating a misleading "successfully executed" status.
- AppWorkload policy parsing for WGDevice01 did not show a targeted `System-RemoveBloatwareAppX` Win32 app in the device's Win32 app set.
- Resolved in source on 2026-05-04: active `System-RemoveBloatwareAppX.ps1` now writes `C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag`, and `Detect.ps1` now requires `ScriptVersion=1.0.6`.
- Resolved in source on 2026-05-04: custom whitelist command parameter support was removed from the active Win32 wrapper and bundled `Debloat\RemoveBloat.ps1`; the wrapper now has an explicit empty `param()` block so unexpected parameters fail visibly.
- OPEN (2026-05-04): Wrapper stderr check (lines 140-142) throws and suppresses marker write if RemoveBloat.ps1 produces any stderr. RemoveBloat.ps1 uses silentlycontinue globally so this is dormant, but fragile. Fix before next package build.
- OPEN (2026-05-04): RemoveBloat.ps1 downloads start2.bin from third-party GitHub repo (line 1122) during White Glove on Windows 11. Runs unconditionally when no user is logged on. Network dependency + supply chain risk.
- OPEN (2026-05-04): Windows 11 start layout JSON in RemoveBloat.ps1 is malformed (invalid JSON at line 1100) and written to LayoutModification.xml (should be .json for Win11). Start layout clearing silently does nothing on Win11.
- OPEN (2026-05-04): $builtin undefined in Xbox Gaming ACL block (line 1148); GameBarPresenceWriter.exe ownership/removal silently fails. Set-ScheduledTask -Enabled $false invalid (line 1139); Xbox task disable silently fails (redundant with working earlier code at lines 841-863).
- OPEN (2026-05-04): Bookmarks removal uses $user.FullName as path fragment, producing double C:\Users\ prefix (line 2711). Edge bookmark removal silently fails on all devices.

## Recent Changes

- 2026-05-04 - Log triage identified a stale/incorrect Intune platform script policy as the WGDevice01 no-op cause.
- 2026-05-04 - Updated active Win32 source to v1.0.5 with marker writing, version-aware detection, and child-script stderr/exit-code validation.
- 2026-05-04 - Updated active Win32 source to v1.0.6 and bundled `RemoveBloat.ps1` to remove custom whitelist command parameter support.
- 2026-09-08 - Wrapper and Detect.ps1 bumped to v1.1.0: marker and error log moved to the current IME-rooted standard, generic throw/exit-1 failure handling replaced with distinct numbered error codes (1701-1799 range) and error-only logging, PDQ marker handoff and legacy marker cleanup added, child PowerShell host switched to an explicit SysNative path (closes M6), and the new campus-wide `ERROR CODES` `.NOTES` section added ahead of `CHANGE LOG`. `Debloat\RemoveBloat.ps1` got a header-only update (current `.NOTES` format + honest `ERROR CODES` section) at Jeremy's direction - its body (removal logic, global `silentlycontinue`, self-elevation) is intentionally untouched, still best-effort third-party code per the 2026-05-04 decision.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
- Validate JSON/XML/config files if present.
- Confirm install, uninstall, detection, marker versions, helper versions, and
  package artifact are synchronized.
- Confirm `.intunewin` is rebuilt from a clean source folder with no stale
  `.intunewin`, logs, AI notes, or archives inside the payload.
- Confirm Intune portal settings match the script comments.
- For device-context work, validate 64-bit PowerShell and SYSTEM-context behavior.
- Confirm the stale/incorrect Intune platform script assignment is removed or updated so it does not call `removebloat.ps1 -customwhitelist` without a value.
- Confirm WGDevice01 or next White Glove test receives the intended Win32 app assignment if this project is supposed to deploy as a Win32 app.
- Rebuild/re-upload the Win32 package from the corrected v1.0.6 source if using this project as a Win32 app.
- BEFORE REBUILD: Fix wrapper stderr check (M1) -- the throw-on-stderr behavior is unchanged in v1.1.0 (now exit code 1705, still fragile because RemoveBloat.ps1 runs globally `silentlycontinue`). Disposition still open; not touched in the 2026-09-08 pass since it changes pass/fail semantics rather than logging/marker placement.
- BEFORE REBUILD: Decide disposition of start2.bin GitHub download (H1) and malformed Win11 start layout (H2) -- remove/replace or leave as best-effort. Unchanged in this pass (RemoveBloat.ps1 body was explicitly kept header-only at Jeremy's direction).
- RESOLVED 2026-09-08: M6 ($PSHOME to explicit SysNative path) fixed in wrapper v1.1.0 `Invoke-RemoveBloatScript`.
- Rebuild/re-upload the Win32 package from v1.1.0 source before the next deployment test - the current `.intunewin` still reflects v1.0.6.

## Latest Work Log

### 2026-09-08 - Claude (Sonnet 5) - IME Standard Alignment + Campus-Wide ERROR CODES Policy

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` (v1.0.3, header only)
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\reference_script_dev_methodology.md`
  - `AI Knowledgebase\reference_intune_code_patterns.md`
  - `AI Knowledgebase\reference_intune_detection.md`
  - `System Scripts\Serial Marker\Install-SerialMarker.ps1` and `Detect.ps1` (used as the current real-world implementation reference for the Write-ErrorLog / numbered-$ERR_* / marker-tmp-then-Move-Item pattern)
- Files changed:
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` - bumped to v1.1.0
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` - bumped to v1.1.0
  - `System Scripts\Remove Windows Bloatware AppX\Debloat\RemoveBloat.ps1` - header only, version unchanged (1.0.3)
  - `AI Knowledgebase\AGENTS.md` - `.NOTES Standard` section: added campus-wide `ERROR CODES` section policy (between `Purpose` and `CHANGE LOG`), superseding the old post-`CHANGE LOG` `RETURN CODES` placement; documented as an incremental policy (apply next time a script is touched, not a mass retrofit)
  - `AI Knowledgebase\reference_intune_code_patterns.md` - Script Header Template updated to match
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md` (this file)
- Findings accepted:
  - Marker and error-log locations were still on legacy paths (`C:\IntuneAppMarkers\*.tag`, ad hoc `C:\IntuneAppLogs\*.txt` for one DISM failure line) rather than the current IME-rooted standard. Moved to `AppMarkers\System-RemoveBloatwareAppX.marker` and `Logs\SCRIPT_RemoveBloatwareAppX_Install.txt`.
  - Wrapper had no top-level try/catch and no distinct failure codes - any failure fell through to PowerShell's default unhandled-exception exit code 1. Replaced with per-stage try/catch and a dedicated 1701-1799 numeric range (mirrors the pattern already in production in `Install-SerialMarker.ps1`, which uses 1601-1699).
  - M6 (bare `$PSHOME` for child PowerShell host) fixed as part of rewriting the launch function - now explicit SysNative-first path, matching methodology.
  - Jeremy directed (via question) that `Debloat\RemoveBloat.ps1` gets header-only treatment: `.NOTES` format and an honest `ERROR CODES` section (it defines no real distinct codes of its own - documented as such), with its body, global `silentlycontinue`, and self-elevation left untouched.
  - Per Jeremy's mid-task correction, the new `ERROR CODES` `.NOTES` placement/content requirement was written into `AGENTS.md` and `reference_intune_code_patterns.md` as a campus-wide standard, not scoped to this one project.
- Findings rejected: None.
- Explicitly NOT changed (out of scope for this pass, left for a future decision):
  - M1 (throw-on-any-stderr from RemoveBloat.ps1) - behavior preserved, now just has its own error code (1705) and log line. Still fragile per the existing OPEN risk.
  - H1 (start2.bin/bundled-file handling) and H2 (malformed Win11 start layout) in `RemoveBloat.ps1` - untouched, per the header-only scope decision.
  - `RemoveBloat.ps1` community-script issues (M2-M5, L-series) - untouched, per the header-only scope decision.
- Tests/validation performed (all proven, not inferred):
  - Windows PowerShell 5.1 parser check on all three edited `.ps1` files: zero errors.
  - Encoding check on all three: BOM=True, NonASCII=0 (the two fully-rewritten files needed an explicit UTF-8-with-BOM re-save after initial Write; `RemoveBloat.ps1`, edited in place, kept its existing BOM).
  - Runtime dry run of `Detect.ps1` with no marker present: exit 1, no STDOUT (correct not-detected).
  - Runtime dry run of `Detect.ps1` with a synthetic `Version=1.1.0, Status=Success` marker: exit 0 with the expected "Detected" STDOUT line.
  - Runtime dry run of `Detect.ps1` with a synthetic stale `Version=1.0.9` marker: exit 1 (confirms the Intune-marker-stale path fails closed and does not fall through to PDQ/legacy, per the reference detection template).
  - Version sync cross-check: wrapper `$script:AppVersion='1.1.0'`, Detect.ps1 `$script:RequiredVersion='1.1.0'`, both `.NOTES Version` and `Paired script` references match.
- Remaining risks or human decisions:
  - All previously OPEN risks in `RemoveBloat.ps1` (M1, H1, H2, M2-M5, L-series) remain open and undecided - this pass did not touch its body.
  - `.intunewin` package is stale (still v1.0.6 content) and must be rebuilt from the v1.1.0 source before the next deployment test - packaging remains Jeremy's manual step.
  - No PDQ counterpart currently exists for this app; the PDQ marker read/remove calls added to the wrapper and `Detect.ps1` are safe no-ops today and only become meaningful if a PDQ package is added later.

### 2026-07-13 - Claude (Fable 5) - Detect.ps1 Blind Audit

- Files reviewed:
  - `System Scripts\Remove Windows Bloatware AppX\Detect.ps1` (v1.0.6)
  - `System Scripts\Remove Windows Bloatware AppX\System-RemoveBloatwareAppX.ps1` (marker-write block and `$AppVersion` only, for contract cross-check)
- Files changed:
  - `AI Knowledgebase\System Scripts\Remove Windows Bloatware AppX\AI-Audit-Handoff.md` (this file)
- Findings accepted: None. Detect.ps1 passed all checks; no code changes made.
- Findings rejected: None.
- Low-severity observations (no action required):
  - `-ceq` case-sensitive marker match is safe because the wrapper is the sole producer of the marker line.
  - Silent `catch { exit 1 }` is intentional and matches the sanctioned marker detection template (side-effect free, fail-open to retry).
  - Marker detection proves "wrapper ran to completion," not per-app AppX removal success; previously accepted trade-off.
- Tests/validation performed (all proven, not inferred):
  - Windows PowerShell 5.1 (5.1.26100.8655) parser check: zero errors.
  - Encoding check: BOM=True, NonASCII=0.
  - Runtime smoke test under PS 5.1 with marker absent: exit 1, no STDOUT (correct not-detected signal per Intune custom detection semantics).
  - Version sync cross-check: wrapper `$AppVersion='1.0.6'`, detect `$script:RequiredScriptVersion='1.0.6'`, both `.NOTES` at 1.0.6; wrapper writes literal `ScriptVersion=1.0.6` at line 212, matched exactly by detection.
  - StrictMode/edge simulation: empty marker, blank lines, unreadable marker, marker-path-is-directory all resolve to exit 1 or catch -> exit 1; `@()` guards Get-Content scalar unwrap.
  - Architecture: `C:\IntuneAppMarkers` is not WOW64-redirected; identical behavior in 32-bit and 64-bit hosts.
- Remaining risks or human decisions:
  - No changes to Detect.ps1 needed. All OPEN risks in Active Risks remain in the wrapper and `Debloat\RemoveBloat.ps1`, not in Detect.ps1.

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
