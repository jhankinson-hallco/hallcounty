# AI-Audit-Handoff.md

## Current State

- Project: Print Management Console (Windows Capability Win32 app plus PDQ tandem)
- Deployment and detection script version: 1.0.3
- PDQ marker companion version: 1.0.0
- Deployment type: Win32 app, device context, SYSTEM install behavior
- Capability identity: resolved at runtime by name prefix `Print.Management.Console*`, requiring exactly one match (not a hardcoded exact revision suffix - see 2026-09-10 decision)
- Intune install: `Install-PrintManagementConsole.ps1`
- Intune uninstall: `Uninstall-PrintManagementConsole.ps1`
- Intune detection: `Detect.ps1`, matches by name prefix and requires `State -eq 'Installed'` on the single match
- PDQ install: `PDQ\Install-PrintManagementConsole-PDQ.ps1`, followed by `PDQ\Set-PrintManagementConsoleMarker-PDQ.ps1`
- PDQ uninstall: `PDQ\Uninstall-PrintManagementConsole-PDQ.ps1`
- Package artifact: not built; packaging remains a fully manual step (no packaging-staging utility - see 2026-09-10 decision)

## Active Risks

- Confirmed in production (2026-09-10): a real target device failed `Add-WindowsCapability` with DISM `0x800f0954`. Root cause per `Windows Update Source Diagnostics` (proven on a different Hall County endpoint, `TA-PF47WVTR`): domain-joined devices here are under a `WSUS - Internal (TC18)` GPO with `UseWUServer=1`, and WSUS deployments typically do not carry Features-on-Demand content, so `Add-WindowsCapability` cannot locate the package through the WSUS-registered source. This project's install scripts now retry via a bundled offline `.\Source\` folder (see 2026-09-10 decision below), but that folder is currently empty - a WSUS-managed device still fails until Jeremy stages the matching Features on Demand content for its Windows build. Changing the WSUS/optional-content GPO was explicitly ruled out by Jeremy as a fix path for now.
- The apparent prior success on a target device may not be real evidence the online path works: if the capability was already present on that device's image, the install script's idempotent "already Installed" fast path never exercises `Add-WindowsCapability` at all (Jeremy's own observation, 2026-09-10, confirmed as sound reasoning). Do not treat an observed success as proof a given device can pull the capability fresh until it has actually been watched through the true `NotPresent` -> `Installed` path.
- A real add/remove cycle was not run on this workstation because it would change it. The install and uninstall branches were instead exercised with controlled mocks (Codex, 2026-09-09) plus live idempotent-path runs (Claude, 2026-09-10) - neither has exercised the true "not yet installed" path or the new offline-source fallback for real, since this workstation is not WSUS-restricted and both capabilities are already installed here.
- Capability installation can depend on Windows build, edition, servicing policy, and source availability. Validate under SYSTEM on representative target devices before broad deployment.
- The Intune portal package and PDQ package definitions were not changed. Their commands, execution context, success codes, and PDQ step order must be configured from the script headers.

## Recent Changes

### 2026-09-10 - WSUS/Features-on-Demand fallback (Claude)

- Root cause confirmed: a real deployment to a target device failed with `Add-WindowsCapability failed. Error code = 0x800f0954` at the `Add-WindowsCapability` call. This is a known DISM failure mode on WSUS-managed devices, where WSUS is the enforced optional-content source (per `UseWUServer=1`) but does not carry Features-on-Demand payloads. This workspace already has proven local evidence (`Windows Update Source Diagnostics` project) that Hall County domain devices are WSUS-managed via GPO.
- Jeremy ruled out changing the WSUS/optional-content GPO as a fix path for now (broader-than-this-project policy change, not currently actionable).
- Fixed (`Install-PrintManagementConsole.ps1` and `PDQ\Install-PrintManagementConsole-PDQ.ps1`, bumped to 1.0.3): added `Add-CapabilityWithFallback`. It first tries `Add-WindowsCapability` exactly as before (unchanged behavior for any device that can already reach Features-on-Demand content online). Only if that call fails does it look for offline source folders under `.\Source\` (one subfolder per Windows build, e.g. `.\Source\Win11-24H2\`) and, if any exist, retry with `-Source <all subfolders> -LimitAccess`. If `.\Source\` is empty or absent, the exception from the first attempt propagates unchanged - today's behavior is preserved until content is staged.
- `.\Source\` is currently empty in both projects. Staging its content (obtaining the matching Features on Demand content per Windows build from the Microsoft Volume Licensing Service Center / admin center, or a matching Windows ISO's `\sources\sxs` folder) is a manual step, same as packaging - not something done from this session.
- Uninstall scripts and `Detect.ps1` needed no logic change (removing an already-installed capability, and reading its live state, never require external source content) - bumped to 1.0.3 only for cross-file version-number consistency with the Install scripts, per this project's established lockstep-versioning convention.
- Also fixed version drift: both `Set-*Marker-PDQ.ps1` companions still referenced their paired PDQ install script as `v1.0.1` after it had already been bumped to `v1.0.2` last turn. Corrected to `v1.0.3`.

### 2026-09-10 - Follow-up audit and fixes (Claude)

- Read every script on disk directly (not the prior handoff's summary) and independently re-ran the encoding/parse/alias checks Codex's pass claimed; all confirmed accurate.
- Fixed: Install scripts (`Install-*.ps1` and `PDQ\Install-*-PDQ.ps1`, both apps) no longer treat an initial `UninstallPending` state as a completed reboot-pending install. Per Microsoft's `DismPackageFeatureState` documentation, `UninstallPending` means a removal is in progress, not an install - the prior code exited 3010 and (on the Intune side) wrote a `Status=RebootRequired` marker without ever calling `Add-WindowsCapability`, which is wrong if the true post-reboot end state is `NotPresent`. `UninstallPending` now falls through to the existing unexpected-state `throw` (exit 1) so Intune/PDQ retries once the pending removal settles.
- Fixed: cross-channel marker cleanup (`Remove-StalePdqMarker` in Install scripts; the marker loop in `Remove-AllAppMarkers` in Uninstall scripts, Intune and PDQ) is now best-effort - it logs a warning on failure instead of throwing. Previously a locked/AV-scanned marker file could turn an already-successful capability install or removal into a reported `exit 1`, which per this workspace's White Glove/ESP notes could fail an entire blocking ESP phase over a housekeeping failure, even though `Detect.ps1` is marker-independent so no functional harm would have resulted. The channel's own primary marker write (`Write-AppMarker`) stays mandatory/throwing, since that is the record this run is actually responsible for. As a side effect, `Remove-AllAppMarkers` now attempts both marker tiers independently instead of aborting after the first failure.
- Fixed: capability identity is now resolved at runtime via `Get-WindowsCapability -Online -Name 'Print.Management.Console*'` (name-prefix match, asserting exactly one result) instead of a hardcoded exact string including the revision suffix (`~~~~0.0.1.0`). This workspace's fleet spans Windows 11 Pro down to Windows 10 LTSC 1809; if that suffix ever differs on an older build, the prior hardcoded-exact approach would find zero matches and fail closed on every run for that build. The resolved name is reused for the rest of each script's run (state checks, the actual Add/Remove call) instead of re-hardcoding it. Verified against Microsoft's own `DismPackageFeatureState` documentation and confirmed live via `[Enum]::GetNames()` against this workstation's actual DISM module, not from memory.
- Removed: `New-PrintManagementConsoleIntuneSource.ps1`. Per Jeremy's direction, it was unneeded scope - packaging is already documented as a fully manual step in this workspace, and "copy three named files into a temp folder" does not need a hash-verifying utility script to do safely by hand.
- Live-verified (not mocked) on this workstation: `Detect.ps1` and the idempotent "already Installed" branch of `Install-PrintManagementConsole.ps1` both ran for real (both capabilities are already `Installed` on this machine, so this is a safe, non-mutating path) and produced the expected exit codes, STDOUT, and marker content. Did not run any uninstall script live, since that would actually remove the capability from this workstation.
- All 12 remaining scripts (5 in the project root/PDQ folder, this project; PDQ marker companion untouched) re-verified: 0 parse errors, UTF-8 BOM present, 0 non-ASCII characters, 0 aliases.

### 2026-09-09 - Corrective audit

- Corrected restart handling so a successful DISM result with `RestartNeeded = True` accepts the corresponding pending state and exits 3010 instead of failing the final-state check first.
- Added explicit handling for `InstallPending` and `UninstallPending` at script start, while retaining strict failures for unexpected states.
- Changed all capability queries from wildcard filters to the exact capability identity and require exactly one result.
- Made marker replacement and removal verifiable operations. Both uninstall channels remove both Intune and PDQ marker tiers, including already-absent and reboot-pending branches.
- Split the PDQ marker write into `Set-PrintManagementConsoleMarker-PDQ.ps1`, to be run as the final PDQ install step.
- Renamed PDQ scripts to the standard `*-PDQ.ps1` form.
- Added `New-PrintManagementConsoleIntuneSource.ps1`, which creates a clean, versioned staging folder containing only the install, uninstall, and detection scripts and verifies their hashes.
- Simplified helper functions, standardized logging, corrected comments, and raised deployment script headers to version 1.0.1.

## Required Validation Before Deployment

- Windows PowerShell 5.1 parsing: done, zero errors across all seven scripts.
- UTF-8 BOM and ASCII-only verification: done after final edits.
- Static alias scan: done, no aliases found.
- Live detection check on this workstation: done, exact capability returned Installed and both detection scripts exited 0 with output.
- Mocked install branch tests: done for Intune and PDQ scripts; 16 of 16 scenarios passed across both projects.
- Mocked uninstall branch tests: done for Intune and PDQ scripts; 16 of 16 scenarios passed across both projects.
- Mocked PDQ marker and cleanup-failure tests (Codex, 2026-09-09): done; all expected exit paths passed.
- Independent re-verification (Claude, 2026-09-10): PS 5.1 parse, UTF-8 BOM/ASCII, and alias-free claims all re-run from scratch and confirmed accurate, not just re-stated. Live (non-mocked) run of `Detect.ps1` and the idempotent install path on this workstation, confirmed correct.
- Before production, perform a real add/remove/reboot cycle under SYSTEM on representative target builds - this still has not been done live, only the already-installed idempotent path has been exercised for real.
- Stage `.\Source\<build>\` content for at least the Windows build that hit `0x800f0954`, rebuild the package, and redeploy to that same device (or an equivalent one) to confirm the fallback actually resolves it - the fallback code has been parse-checked and reasoned through but not exercised against a real DISM failure, since this workstation cannot reproduce the WSUS-restricted condition.
- Configure PDQ install with the capability install script first and the marker companion last. Treat 0 and 3010 as success codes for the capability step.
- When building the `.intunewin`, copy only `Install-PrintManagementConsole.ps1`, `Uninstall-PrintManagementConsole.ps1`, `Detect.ps1`, and (once populated) `.\Source\` into a clean folder by hand first. Do not package the project root or the `PDQ` subfolder directly - `IntuneWinAppUtil.exe` sweeps the entire source folder it is pointed at.
- Confirm Intune uses the 64-bit PowerShell commands in the script headers and configures detection to run as 64-bit.

## Latest Work Log

### 2026-09-10 - Claude - WSUS/Features-on-Demand fallback

- Files reviewed: real production error report (`Add-WindowsCapability failed. Error code = 0x800f0954` at line 142 of `Install-PrintFaxScan.ps1`), this project's own `Install-PrintManagementConsole.ps1`/`PDQ\Install-PrintManagementConsole-PDQ.ps1`, and the sibling `Windows Update Source Diagnostics` project's proven WSUS findings for Hall County domain devices.
- Files changed: `Install-PrintManagementConsole.ps1`, `PDQ\Install-PrintManagementConsole-PDQ.ps1` (added `Add-CapabilityWithFallback`, bumped to 1.0.3); `Detect.ps1`, `Uninstall-PrintManagementConsole.ps1`, `PDQ\Uninstall-PrintManagementConsole-PDQ.ps1` (version-only bump to 1.0.3, no logic change); `PDQ\Set-PrintManagementConsoleMarker-PDQ.ps1` (corrected stale `v1.0.1` cross-reference to `v1.0.3`, no logic change).
- Findings accepted: WSUS enforcement (proven elsewhere in this workspace) is the credible cause; Jeremy's own observation that an apparent prior "success" on this app may just reflect the idempotent already-installed path, not a proven working download path, is sound and the fix must cover both apps identically.
- Decision made with Jeremy: no GPO change (explicitly ruled out for now); fix via a local offline-source retry instead.
- Tests/validation performed: PS 5.1 parse (0 errors), UTF-8 BOM + ASCII-only (all 12 scripts), live re-run of the idempotent install path and `Detect.ps1` for both apps on this workstation to confirm no regression. Did NOT live-test the fallback path itself - this workstation has no WSUS restriction to reproduce against, and no destructive uninstall was performed to force the untested path.
- Remaining risks or human decisions: `.\Source\` is empty - Jeremy needs to obtain and stage the matching Features on Demand content per Windows build (Microsoft VLSC/admin center, or a matching ISO's `\sources\sxs`), then rebuild and redeploy to the originally-failing device to actually confirm the fix. Until then, any WSUS-restricted device attempting a fresh install of either app will still fail with the same `0x800f0954`.

### 2026-09-10 - Claude follow-up audit and fixes

- Files reviewed: all 7 scripts in this project as they exist on disk (not the prior handoff's summary), plus this workspace's `reference_intune_code_patterns.md` (mandatory-vs-best-effort marker cleanup guidance) and Microsoft's `DismPackageFeatureState` documentation.
- Files changed: `Detect.ps1`, `Install-PrintManagementConsole.ps1`, `Uninstall-PrintManagementConsole.ps1`, `PDQ\Install-PrintManagementConsole-PDQ.ps1`, `PDQ\Uninstall-PrintManagementConsole-PDQ.ps1` (all bumped to 1.0.2). `Set-PrintManagementConsoleMarker-PDQ.ps1` unchanged.
- Files removed: `New-PrintManagementConsoleIntuneSource.ps1`, per Jeremy's direction that it was unneeded automation.
- Findings accepted (from my own audit, confirmed with Jeremy): `UninstallPending` no longer misread as a completed install; cross-channel marker cleanup is now best-effort instead of failing an already-successful run; capability identity resolved by name prefix instead of a hardcoded exact revision suffix; unneeded packaging-staging utility removed.
- Findings from Codex's 2026-09-09 pass that were reaffirmed as correct: reboot/pending-state sequencing in general, verifying a single capability match, marker-independent detection, dedicated PDQ marker companion step, standard `*-PDQ.ps1` naming (kept as-is per Jeremy - "the name change is fine").
- Tests/validation performed: PS 5.1 parse (0 errors), UTF-8 BOM + ASCII-only (all 12 remaining scripts), AST alias scan (none), live (non-mocked) execution of `Detect.ps1` and the idempotent "already Installed" branch of `Install-PrintManagementConsole.ps1` on this workstation with real marker output inspected.
- Remaining risks or human decisions: still no live add/remove/reboot cycle on a non-idempotent path; still no confirmation that the capability's revision suffix is stable across Hall County's actual Windows 10 LTSC 1809 fleet (the name-prefix fix removes the failure mode but the underlying suffix-stability question itself remains unverified); PDQ package configuration, Intune packaging, and portal configuration are all still outstanding.

