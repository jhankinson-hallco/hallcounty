# AI-Audit-Handoff.md

## Current State

- Project:          M365 Pre-Cleanup (Microsoft Office 365 removal prior to managed deployment)
- Current version:  1.5.22
- Deployment type:  Win32 app (device context, 64-bit)
- Primary install:  Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Detection:        Detect.ps1 (audited 2026-04-30; marker/version only)
- Uninstall:        Uninstall.ps1 (audited 2026-04-30; marker reset only)
- Package artifact: Jeremy packages manually. `Remove-Office365.intunewin` is
  present in the active removal source and was built 2026-06-25 from the
  recovered v1.5.20 source; it is stale relative to the current loose v1.5.22
  scripts and must not be uploaded as v1.5.22 content.

## Active Risks

- **Mitigated in source 2026-06-25; pending field validation**: Latest copied IME logs prove
  `Microsoft Office 365 - Removal - White Glove`
  (`1e072da2-8a83-4fee-b331-4c6c02225aeb`, Intune content version 4) was the
  root app install failure. IME launched `Remove-Office365.ps1` from
  `C:\WINDOWS\IMECache\1e072da2-8a83-4fee-b331-4c6c02225aeb_4`, the script
  returned exit code 1 after about 93 seconds, and IME mapped it to
  `-2147024895`. Dependent apps, including Microsoft Office 365 Hall County
  Default, Microsoft Outlook, Microsoft Teams, and SentinelOne, were blocked by
  this failed dependency. The copied folder did not include the script-authored
  `APP_M365PreCleanup_Install.txt` or legacy `M365PreCleanup_Remove.txt`, so the
  exact internal branch/exception is not proven from this copy. If content
  version 4 was built before v1.5.19, this matches the known protected New
  Outlook/AppX failure. If content version 4 was built from v1.5.19 source, the
  script-authored log is required before further root-cause work. v1.5.20 was
  applied as an emergency WG reliability fix: AppX cleanup is now fully
  fail-forward after attempting AppX API and DISM cleanup, so AppX leftovers
  cannot block the marker or cascade dependent apps.

- **Resolved in source 2026-06-25**: v1.5.19 best-effort AppX
  bookkeeping only marks `Microsoft.OutlookForWindows` as best-effort when a
  removal cmdlet throws. If `Remove-AppxProvisionedPackage` or
  `Remove-AppxPackage` returns without throwing but a post-removal re-query still
  shows New Outlook present, the script can still fail or retry until
  `MaxIterations` instead of treating the remaining package as best-effort.
  v1.5.20 removes the post-query hard failure for AppX entirely: remaining
  installed/provisioned AppX packages are logged and accepted after removal
  attempts.

- **Known tradeoff in source 2026-06-25**: v1.5.20 can write the cleanup marker
  while targeted AppX packages remain. This is intentional to stop fresh Windows
  11 WG protected inbox AppX packages from blocking the managed Office install
  chain. C2R, MSI, standalone OneDrive, required package-file checks,
  runtime-budget checks outside the AppX child path, and marker-write failures
  remain blocking. v1.5.21 confirms the AppX DISM insufficient-runtime-budget
  branch is also fail-forward, and v1.5.22 confirms the AppX phase budget
  branch is fail-forward. Both AppX-only budget branches must log/continue
  instead of exiting.

- **Resolved in source 2026-06-24**: v1.5.17 added `Microsoft.OutlookForWindows`
  to `NonBlockingAppXNamePatterns`, making New Outlook invisible to AppX
  detection/removal. v1.5.18 removed New Outlook from the non-blocking allowlist,
  so it remains an AppX removal target.

- **Superseded in source 2026-06-25 by v1.5.20**: `Microsoft.OutlookForWindows`
  on Windows 11 24H2 is a protected provisioned inbox app. The AppX API returns
  E_ACCESSDENIED (0x80070005) in SYSTEM context, and DISM also fails to remove it
  on fresh WG images. v1.5.18 kept it as a hard blocking target, which caused both the
  AppX pass and the DISM pass to fail, exiting 1 and cascading all dependent apps.
  v1.5.19 places New Outlook in `$script:BestEffortRemovalPatterns`: the script actively
  attempts both the AppX API and DISM passes, but if both fail, the failure is logged
  and the run continues. The cleanup marker is written and downstream Office deployment
  is not blocked. Removal is still attempted on every device - it will succeed on OEM
  devices where New Outlook was user-installed. v1.5.20 expands this behavior to
  all targeted AppX cleanup because field failures continued without a
  script-authored log proving the exact AppX branch.

- **Resolved in source 2026-06-24**: Office removal used legacy runtime paths:
  `C:\IntuneAppLogs` for logs and `C:\ProgramData\HallCountyMIS` for the marker.
  v1.5.18 now writes logs to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`, writes the marker
  to `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers`, and has
  Detect.ps1 check the current marker first with legacy marker fallback.

- **Mitigated in source 2026-06-23; pending field retry**: Fresh WGDevice02 log copy proves
  `Microsoft Office 365 - Removal - White Glove` app
  `1e072da2-8a83-4fee-b331-4c6c02225aeb` launched
  `Remove-Office365.ps1` successfully from IMECache, then returned exit code 1 after about
  seven seconds. IME mapped that to `-2147024895` and ESP state 4, cascading dependent
  apps. The copied log folder did not include the script-authored
  `C:\IntuneAppLogs\M365PreCleanup_Remove.txt`, so the exact script branch or exception
  could not be proven from the copied logs. Based on the fresh Windows 11 scenario and
  prior protected AppX evidence, v1.5.16 now excludes known protected inbox support
  packages `Microsoft.OfficePushNotificationUtility` and `Microsoft.OneDriveSync` from
  cleanup detection/removal so they cannot block the marker.

- **Resolved 2026-05-06**: Stale packaging artifacts were present in the active removal
  source folder. `Remove-Office365.intunewin` was last modified 2026-05-01 and predates the
  v1.5.14 source change on 2026-05-06. `Remove-Office365.ps1.bak` is also present in the
  same folder. Codex moved the Office removal artifacts to
  `AI Knowledgebase\Software\Microsoft Office 365\Archive\PackageArtifacts-20260506`.
  Assistants must not build the package.

- **Resolved in source 2026-05-01; pending field retry**: WGDevice02 failed on v1.5.12 because
  AppX HRESULT handling cast Access Denied `-2147024891` to `[uint32]`, causing an overflow
  before the protected-package skip logic could run. v1.5.13 compares signed Int32 HRESULT
  values directly.

- **Medium - Pending field validation 2026-06-23**: v1.5.16 treats
  `Microsoft.OfficePushNotificationUtility` and `Microsoft.OneDriveSync` as non-blocking
  Windows inbox support packages. Field retry should confirm a fresh Windows 11 White
  Glove device writes the marker and proceeds to managed Office install when no removable
  Office install exists.

- **Resolved 2026-05-06**: v1.5.14 added a DISM pass after AppX child exit 2, but the
  parent still sets `$appxProtectedSkip = $true` regardless of DISM outcome and does not
  re-query before marker write. If DISM fails or times out, marker-only detection can still
  report success with provisioned Office/OneDrive AppX packages remaining. v1.5.15 now
  fails the run when DISM cannot prove cleanup.

- **Resolved 2026-06-24**: ODT log path claim is accurate. Remove-C2R-All.xml now
  specifies
  `<Logging Level="Standard" Path="C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" />`.

- **Low - Informational**: The `Test-Path -PathType Leaf` check inside the `versionedSetups` loop
  (Get-OneDriveUninstallCommand, ~line 1157) is redundant - `Get-ChildItem -File` already returns
  only files. Belt-and-suspenders TOCTOU guard; harmless.

## Recent Changes

### 2026-06-24 - Codex - v1.5.18 Outlook And IME Runtime Path Fix

- Bumped Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1 to v1.5.18.
- Removed `Microsoft.OutlookForWindows` from `NonBlockingAppXNamePatterns`; New
  Outlook remains in `AppXPatterns` and is again targeted for AppX removal.
- Moved script error log path to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_M365PreCleanup_Install.txt`.
- Moved ODT logging path in Remove-C2R-All.xml to the IME Logs folder.
- Moved completion marker path to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\M365PreCleanup.marker`.
- Updated Detect.ps1 to check the current IME marker first, then the legacy
  `C:\ProgramData\HallCountyMIS\M365PreCleanup.marker` marker.
- Updated Uninstall.ps1 to remove both current and legacy marker paths.

### 2026-06-24 - Codex - v1.5.17 Full Script Audit

- Audited `Remove-Office365.ps1` after changelog showed
  `Microsoft.OutlookForWindows` added to `NonBlockingAppXNamePatterns`.
- Confirmed script, Detect.ps1, and Uninstall.ps1 are version-synced at 1.5.17.
- Confirmed parse and encoding validation pass.
- Identified high-risk behavior change: New Outlook is now skipped before AppX
  matching/removal and can remain while the cleanup marker is written.
- Identified stale active `.intunewin` artifact in the source folder.

### 2026-05-01 - Claude (claude-sonnet-4-6) - WGDevice02 HRESULT Fix

- Changed the two AppX catch block comparisons from HRESULT hex literals to signed decimal
  values for clarity and to avoid reintroducing unsigned-cast confusion.
- Fixed line 797: `$hResult -eq 0x80070005` -> `$hResult -eq -2147024891`
- Fixed line 819: `$hResult -ne 0x80073CF1` -> `$hResult -ne -2147009295`
- Parse: PARSE OK. Encoding: BOM=True NonASCII=0. Version remains 1.5.13 (already bumped by Codex).

### 2026-04-30 - Claude (claude-sonnet-4-6)

- Fixed cosmetic indentation: `$msiEntries = @(Get-MSIOfficeEntries)` was de-indented 4 spaces
  relative to the body of its containing `try {}` block. No runtime impact; corrected for readability.

## Required Validation Before Deployment

- [x] Parse check: PARSE OK (Windows PowerShell 5.1 parser, verified 2026-07-16 for v1.5.22 / PDQ v1.1.2 and v1.0.3)
- [x] Encoding: BOM=True, content NonASCII=0 (verified 2026-07-16 for v1.5.22 / PDQ v1.1.2 and v1.0.3)
- [x] Companion scripts (Detect.ps1, Uninstall.ps1): version sync to 1.5.22 verified 2026-07-16
- [x] Remove-C2R-All.xml: ODT removal config and IME log path verified 2026-07-16
- [ ] End-to-end field test v1.5.22 on a disposable fresh Windows 11 24H2 White Glove device
- [ ] Confirm AppX fail-forward path writes marker and does not cascade ESP
- [ ] Confirm allowlisted inbox AppX packages do not block marker write or downstream Office install
- [ ] Delete or move stale `.intunewin` artifacts out of the source folder before manual packaging
- [ ] Create .intunewin only when ready (manual - Jeremy only)

## Latest Work Log

### 2026-07-16 - Codex - Blind first-look audit of Office removal PDQ scripts

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\Remove-Office365-PDQ.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\Uninstall-M365PreCleanup-PDQ.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\PDQ-Deployment-Guide.md
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1

**Findings:**

- Proven: Claude's v1.5.22 / PDQ v1.1.2 AppX phase budget behavior is correct
  and matches the durable decision. AppX-only budget shortfalls log and continue;
  the remaining `Assert-BudgetSufficient` call sites are blocking phases only:
  C2R, MSI, and OneDrive.
- Proven: PDQ/Intune parity constants match for AppVersion/marker/log paths.
  The only common function body differences are expected PDQ deltas:
  `[PDQ]` log tagging, staged payload cleanup, and PDQ reboot messaging.
- Low documentation issue fixed: PDQ script headers were at v1.1.2 and v1.0.3,
  but their change logs stopped at v1.1.1 and v1.0.2. Added the missing entries
  and corrected runtime-budget wording so AppX budget behavior is documented
  accurately.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365-PDQ.ps1,
  Uninstall-M365PreCleanup-PDQ.ps1, Remove-Office365.ps1, Detect.ps1, and
  Uninstall.ps1.
- Encoding: BOM=True and NonASCII=0 for all five PowerShell scripts.
- Remove-C2R-All.xml parses as XML.
- AST check: no active `[Parameter()]`, `[CmdletBinding()]`, `Invoke-Expression`,
  `Write-Host`, `Get-WmiObject`, `New-Item -LiteralPath`, or
  `Split-Path -LiteralPath` usages.
- Call-site audit: `Assert-BudgetSufficient` appears only for C2R, MSI, and
  OneDrive in both Intune and PDQ scripts.

**Still open:**

- Live White Glove and live PDQ execution tests were not run.
- `Remove-Office365.intunewin` remains in the active removal source and is stale
  relative to the current loose v1.5.22 scripts.

### 2026-07-15 - Codex - v1.5.21 Blind Audit: DISM AppX Budget Fail-Forward Fix

**Files changed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\Remove-Office365-PDQ.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\Uninstall-M365PreCleanup-PDQ.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\PDQ\PDQ-Deployment-Guide.md
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff.md
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Decisions.md
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff-IT-BK348FT25273.md
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Decisions-IT-BK348FT25273.md

**Finding fixed:**

- The AppX DISM insufficient-runtime-budget path still called
  `Assert-BudgetSufficient`, which exits the process and cannot be caught. That
  made one AppX cleanup branch fail-closed despite the v1.5.20 decision that AppX
  cleanup must be attempt-and-log for White Glove reliability. v1.5.21 replaces
  that call with an inline budget comparison that logs and continues without
  blocking marker write.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365.ps1,
  Detect.ps1, Uninstall.ps1, Remove-Office365-PDQ.ps1, and
  Uninstall-M365PreCleanup-PDQ.ps1.
- Encoding: BOM=True and NonASCII=0 for all five PowerShell scripts.
- Remove-C2R-All.xml parses as XML.
- Static check: no active AppX DISM budget branch calls
  `Assert-BudgetSufficient`.

**Still open:**

- Live White Glove and live PDQ execution tests were not run.
- `Remove-Office365.intunewin` remains in the active removal source and is stale
  relative to the current loose v1.5.21 scripts.

### 2026-06-25 - Codex Emergency WG Reliability Fix v1.5.20

**Files changed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff.md
- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Decisions.md

**Behavior change:**

- Bumped package scripts to v1.5.20.
- AppX cleanup is now fully fail-forward for White Glove reliability. The script
  still attempts `Remove-AppxProvisionedPackage`, `Remove-AppxPackage`, and DISM
  where applicable, and logs any leftovers to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_M365PreCleanup_Install.txt`.
  AppX detection failures, child failures/timeouts, API failures, DISM failures,
  and remaining AppX packages no longer cause exit 1.
- C2R, MSI, standalone OneDrive, missing package files, runtime-budget failures
  outside the AppX child path, reboot-required returns, and marker-write failures
  remain blocking.
- Detect.ps1 now requires marker `ScriptVersion=1.5.20`, forcing fixed content to
  rerun on devices with older markers.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365.ps1,
  Detect.ps1, and Uninstall.ps1.
- Encoding: BOM=True and NonASCII=0 for all three PowerShell scripts.
- Static check: no active `[Parameter()]`, `[CmdletBinding()]`, `Invoke-Expression`,
  `Write-Host`, `Get-WmiObject`, `New-Item -LiteralPath`,
  `Split-Path -LiteralPath`, or PS7-only syntax patterns found in active code.

### 2026-06-25 - Codex WGDevice02 Field Log Triage

**Files reviewed:**

- F:\Logs\WGDevice02\AppWorkload.log
- F:\Logs\WGDevice02\AppActionProcessor.log
- F:\Logs\WGDevice02\AgentExecutor.log
- F:\Logs\WGDevice02\IntuneManagementExtension.log

**Finding:**

- Root failure was not Teams. `Microsoft Office 365 - Removal - White Glove`
  (`1e072da2-8a83-4fee-b331-4c6c02225aeb`, content version 4) launched
  `Remove-Office365.ps1` and returned exit code 1. IME reported
  `EnforcementState=5000` and `EnforcementErrorCode=-2147024895`.
- `Microsoft Teams - White Glove` (`7be4925e-3345-4a42-9993-f94895a8a0a6`) was
  blocked because its dependency chain depends on Office removal through Office
  install and Outlook. No Teams installer failure was present in the copied logs.
- AgentExecutor detected `Microsoft.OutlookForWindows 1.2026.609.400` during the
  run, consistent with the protected New Outlook AppX scenario, but the copied
  log folder did not include the Office removal script-authored log needed to
  prove the exact branch.

**Recommended next evidence:**

- Collect `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_M365PreCleanup_Install.txt`
  from the failed device, plus legacy `C:\IntuneAppLogs\M365PreCleanup_Remove.txt`
  if present.
- Confirm whether Intune content version 4 was packaged from v1.5.19 source or
  from an older source version.

### 2026-06-25 - Codex Audit After Claude v1.5.19 Changes

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Files changed:**

- AI-Audit-Handoff.md only.

**Findings:**

- Medium: v1.5.19 best-effort AppX state is only set when the AppX removal cmdlet
  throws. If a best-effort package remains after a nominally successful cmdlet
  call, the post-removal checks can still fail or loop instead of fail-forwarding
  as intended.
- Informational: The v1.5.19 design intentionally means New Outlook may remain
  on fresh Windows 11 24H2 White Glove devices. This is aligned with the
  `BestEffortRemovalPatterns` decision, but field validation is still required
  to confirm downstream Office install is not blocked.
- Informational/package hygiene: `Remove-Office365.intunewin` remains in the
  active source folder and is older than the v1.5.19 source scripts. Jeremy
  packages manually; do not use this artifact as proof of deployed content.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365.ps1,
  Detect.ps1, and Uninstall.ps1.
- Encoding: BOM=True and NonASCII=0 for all three PowerShell scripts.
- Remove-C2R-All.xml parse: OK; `Remove All="TRUE"` and logging path verified as
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- Version sync: Remove-Office365.ps1 `.NOTES` and `$script:AppVersion`,
  Detect.ps1 `.NOTES` and `$script:RequiredScriptVersion`, and Uninstall.ps1
  `.NOTES` all at 1.5.19.
- Static sweeps: no active aliases, invalid cmdlet parameters, decorated
  functions (`[Parameter()]` / `[CmdletBinding()]`), `Invoke-Expression`,
  `Write-Host`, `Get-WmiObject`, `New-Item -LiteralPath`, or PS7-only syntax
  found in active code.
- PSScriptAnalyzer is not installed locally, so no PSScriptAnalyzer pass was run.

**Remaining risks or human decisions:**

- Fix the best-effort post-query edge case before packaging if the desired
  behavior is that New Outlook never blocks marker write after removal attempts.
- Field-test v1.5.19 on fresh Windows 11 24H2 White Glove hardware.
- Move/delete the stale `.intunewin` before Jeremy manually packages a new build.

### 2026-06-25 - Claude (claude-sonnet-4-6) - v1.5.19 OutlookForWindows Best-Effort Fix

**Context:**

Fresh Windows 11 24H2 WG devices have `Microsoft.OutlookForWindows` as a protected
provisioned inbox app. The AppX API returns E_ACCESSDENIED (0x80070005) in SYSTEM context
and DISM also fails to remove it. v1.5.18 kept New Outlook as a hard blocking target; both
passes failed, the script exited 1, and the entire Office deployment chain cascaded (Office
365 Hall County Default, Outlook, Teams, SentinelOne all marked Error).

The root problem: on a clean WG image with no prior Office install, there is no way to
remove this package at runtime. Blocking the cleanup marker on its failure blocks everything.

**Design: three-way AppX classification:**

- **NonBlockingAppXNamePatterns**: inbox support packages (OfficePushNotificationUtility,
  OneDriveSync) that are NOT removal targets. Skip entirely — neither the API nor DISM is
  attempted.
- **BestEffortRemovalPatterns** (new): packages that ARE removal targets but whose failure
  must not block the cleanup marker. Both the AppX API and DISM are attempted. If both fail,
  the failure is logged and the run continues. Current member: `Microsoft.OutlookForWindows`.
- **Blocking** (default): all other AppX targets. API failure throws; DISM failure
  fails the run. Unchanged.

**Files changed:**

- `Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1` — v1.5.19
- `Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1` — v1.5.19
- `Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1` — v1.5.19
- `AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff.md`
- `AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Decisions.md`

**Specific code changes in Remove-Office365.ps1:**

1. Added `$script:BestEffortRemovalPatterns` constant (after NonBlockingAppXNamePatterns).
2. Added `Test-BestEffortRemovalPackageName` function (mirrors Test-NonBlockingAppXPackageName,
   checks against BestEffortRemovalPatterns).
3. `Invoke-RemoveAppXOffice`: Added `$bestEffortProvisionedSkipped` and
   `$bestEffortInstalledFailed` HashSets. Provisioned removal: catches any non-AD HRESULT
   for best-effort packages (logs + continues) in addition to the existing 0x80070005
   path. Installed removal: catches any non-NOT_FOUND HRESULT for best-effort packages
   (logs + continues). Post-removal check: `$blockingProvisioned` and `$blockingInstalled`
   now exclude both access-denied and best-effort packages from the failure throw. Return
   type changed from `[bool]` to `[PSCustomObject]` with two fields:
   `HasNonBlockingProvisioned` (triggers exit 2, DISM pass) and
   `HasBestEffortInstalledFailed` (triggers exit 3, no DISM needed).
4. `$AppXOnly` child block: updated comment and code to handle the PSCustomObject return.
   Added exit code 3 for best-effort installed copies.
5. Main loop: added `$appxBestEffortDone = $false` before the while loop. Changed AppX
   detection condition to `-not $appxBestEffortDone -and (Test-AppXOfficeInstalled)` so
   the full package enumeration is skipped via `-and` short-circuit once best-effort work
   is done. AppX block restructured from if/if/if to if/elseif/elseif/else for correct
   fall-through. Exit 2 + DISM fail path now queries remaining packages post-DISM, checks
   if all are best-effort, logs and sets `$appxBestEffortDone = $true` if so (instead of
   calling Exit-Failure). Exit 3 path logs and sets `$appxBestEffortDone = $true`.

**Three scenarios handled correctly:**

| Scenario | AppX API | DISM | Outcome |
| --- | --- | --- | --- |
| Fresh WG 24H2 (provisioned only, no user install) | E_ACCESSDENIED | Fails | Log + continue, marker written |
| OEM device (user-installed copy present) | Remove-AppxPackage -AllUsers succeeds | N/A | Removed, marker written |
| OEM device (user-installed + provisioned) | Installed removed; provisioned AD | DISM succeeds | Removed, marker written |

**Validation:**

- v1.5.19 adds new functions and control-flow using constructs confirmed safe in v1.5.18:
  simple functions (no `[Parameter()]`), `@()` wraps, `.NET` methods, PSCustomObject
  property access on explicitly-constructed objects (StrictMode-safe), `Where-Object`
  scriptblock with `$_` (no direct property access on unguarded objects).
- No new functions use `[Parameter()]` or `[CmdletBinding()]`.
- No new non-ASCII characters introduced.
- PSCustomObject properties `HasNonBlockingProvisioned` and `HasBestEffortInstalledFailed`
  are always present on the returned object (constructed with both fields); StrictMode
  PropertyNotFoundException cannot trigger on property access.
- Detect.ps1 `$script:RequiredScriptVersion` bumped to `'1.5.19'`; marker format unchanged.
- Uninstall.ps1 bumped to `1.5.19`; marker removal logic unchanged.

**Parse / encoding:**

- Run `Parser::ParseFile()` against v1.5.19 before packaging to verify clean parse.
- Encoding should remain UTF-8 BOM + ASCII-only; verify `(Get-Content ... -Encoding Byte |
  Where-Object { $_ -gt 127 }).Count -eq 0` if any characters were added manually.

**Remaining:**

- Field-test v1.5.19 on a disposable fresh Windows 11 24H2 White Glove device.
- Confirm log entry `DISM pass: only best-effort provisioned packages remain` appears
  for OutlookForWindows on a clean image (or confirm AppX API succeeds and it's removed).
- Stale `.intunewin` in source folder still needs to be moved/deleted before Jeremy packages.

### 2026-06-24 - Codex - v1.5.18 Fixes Applied

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Files changed:**

- Remove-Office365.ps1
- Detect.ps1
- Uninstall.ps1
- Remove-C2R-All.xml
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Fixes applied:**

- Removed New Outlook from the non-blocking AppX allowlist while keeping it in
  AppX removal targeting.
- Migrated script and ODT logs to the IME Logs folder.
- Migrated the success marker to the IME AppMarkers folder.
- Added Detect.ps1 current-first marker lookup with legacy HallCountyMIS marker
  fallback.
- Updated Uninstall.ps1 to remove current and legacy marker files.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1,
  and Uninstall.ps1.
- Encoding: BOM=True and NonASCII=0 for all three PowerShell scripts.
- Remove-C2R-All.xml parse: OK; `Remove All="TRUE"` and logging path verified as
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- Static sweep: no active `[CmdletBinding()]`, `[Parameter()]`, `[ValidateSet()]`,
  aliases, `Write-Host`, `Invoke-Expression`, `Get-WmiObject`,
  `New-Item -LiteralPath`, or PS7-only syntax found in active code.

**Remaining risks or human decisions:**

- Field-test v1.5.18 on a disposable fresh Windows 11 White Glove device.
- Confirm the remaining non-blocking AppX packages
  (`Microsoft.OfficePushNotificationUtility` and `Microsoft.OneDriveSync`) do not
  block downstream Office deployment.
- Existing `.intunewin` artifact was intentionally left untouched per Jeremy's
  instruction for this fix.

### 2026-06-24 - Codex - v1.5.17 Audit After Recent Changelog Change

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Files changed:**

- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Findings:**

- High: `Microsoft.OutlookForWindows` is both an AppX removal target and a
  non-blocking skip pattern. Because the skip is evaluated first, New Outlook is
  not removed by v1.5.17.
- High: Active `Remove-Office365.intunewin` is stale relative to the v1.5.17
  source scripts and is present in the active source folder.
- Medium: Runtime paths remain legacy and should be migrated to IME-rooted
  paths during the next code change if Jeremy wants the new standard applied to
  this package now.

**Validation performed:**

- Windows PowerShell 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1,
  and Uninstall.ps1.
- Encoding: BOM=True and NonASCII=0 for all three PowerShell scripts.
- Remove-C2R-All.xml parse: OK; `Remove All="TRUE"` and logging path verified.
- Static sweep: no active `[CmdletBinding()]`, `[Parameter()]`, `[ValidateSet()]`,
  aliases, `Write-Host`, `Invoke-Expression`, `Get-WmiObject`,
  `New-Item -LiteralPath`, or PS7-only syntax found in active code.
- PSScriptAnalyzer not installed locally.

**Remaining risks or human decisions:**

- Decide whether to remove `Microsoft.OutlookForWindows` from the non-blocking
  allowlist before packaging, or explicitly accept that New Outlook remains on
  fresh Windows 11 24H2 devices.
- Move/delete stale `.intunewin` before manual packaging.
- Handoff now records v1.5.17; field validation still pending.

### 2026-06-23 - Codex - Fresh Windows 11 AppX Non-Blocking Fix v1.5.16

**Files changed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Changes made:**

- Bumped M365 pre-cleanup scripts to v1.5.16.
- Added `NonBlockingAppXNamePatterns` for `Microsoft.OfficePushNotificationUtility` and
  `Microsoft.OneDriveSync`.
- Excluded those package names from both installed AppX and provisioned AppX detection
  before removal attempts. They can exist on fresh Windows 11 with no Microsoft 365 Apps
  install and should not block dependent Office deployment.
- Kept non-allowlisted AppX, C2R, MSI, OneDrive binary, marker write, and unexpected
  query/removal failures fail-closed.
- Moved stale `Remove-Office365.intunewin` to
  `AI Knowledgebase\Software\Microsoft Office 365\Archive\PackageArtifacts-20260623-v1515-stale\Remove-Office365-v1.5.15-stale-20260622.intunewin`.

**Validation:**

- Parse: PARSE OK for `Remove-Office365.ps1`, `Detect.ps1`, and `Uninstall.ps1`.
- Encoding: BOM=True and content NonASCII=0 for all three scripts.
- Version sync: `Remove-Office365.ps1` `$script:AppVersion` and `Detect.ps1`
  `$script:RequiredScriptVersion` both set to 1.5.16.
- Packaging: no `.intunewin` remains in the active source folder; Jeremy must manually
  build/upload a new package version.

**Remaining:**

- Field retry on fresh Windows 11 White Glove.
- If available, still collect `C:\IntuneAppLogs\M365PreCleanup_Remove.txt` from the
  failed WGDevice02 device to confirm the exact original branch.

### 2026-06-23 - Codex - Fresh WGDevice02 Log Triage

**Files reviewed:**

- F:\Logs\WGDevice02\AppWorkload.log
- F:\Logs\WGDevice02\AppActionProcessor.log
- F:\Logs\WGDevice02\AgentExecutor.log
- F:\Logs\WGDevice02\IntuneManagementExtension.log
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Findings:**

- Root failure is `Microsoft Office 365 - Removal - White Glove`
  (`1e072da2-8a83-4fee-b331-4c6c02225aeb`), not the device rename app.
- IME launched
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Remove-Office365.ps1`
  from `C:\WINDOWS\IMECache\1e072da2-8a83-4fee-b331-4c6c02225aeb_2`.
- Detection ran first and returned 1 / NotDetected as expected, then install returned
  `lpExitCode 1`; IME mapped it to `-2147024895`, EnforcementState 5000, ESP state 4.
- Dependent apps `Microsoft Office 365 - Hall County Default`, `Microsoft Outlook`,
  `Microsoft Teams`, and `SentinelOne Agent` were blocked/cascaded because Office removal
  failed.
- `Device Rename - PZ - White Glove` used the corrected `Rename-Device-System.ps1 -Prefix "PZ"`
  command and reported reboot-required state, not the ESP hard failure.
- The copied folder lacks `C:\IntuneAppLogs\M365PreCleanup_Remove.txt`; without that
  script-authored log, the line-level reason for `Remove-Office365.ps1` exit 1 is not in
  the evidence set.
- Active source folder currently contains `Remove-Office365.intunewin` modified
  2026-06-22, matching the fresh deployment window.
- Follow-up package integrity check decrypted the active `.intunewin` metadata/content
  locally and confirmed the payload includes `Detect.ps1`, `Remove-C2R-All.xml`,
  `Remove-Office365.ps1`, `setup.exe`, and `Uninstall.ps1`; this does not look like a
  missing `setup.exe` or XML packaging failure.

**Remaining validation:**

- Pull `C:\IntuneAppLogs\*` from the failed WGDevice02 device and review
  `M365PreCleanup_Remove.txt` before changing source.

### 2026-05-06 - Codex - DISM Fail-Closed Fix

**Files changed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Preflight\Invoke-M365PackagePreflight.ps1
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Changes made:**

- Bumped Office removal package scripts to v1.5.15.
- Changed `Invoke-DismRemoveProtectedProvisionedPackages` to return `$true` only after
  a clean post-DISM `Get-AppxProvisionedPackage` re-query.
- Changed the parent AppX exit-code-2 path to fail with exit 1 if DISM cannot prove the
  targeted provisioned AppX packages are gone. The marker is no longer written over a
  known dirty DISM result.
- Added a DISM runtime budget check using remaining targeted provisioned package count
  times `$script:DismTimeoutSeconds`.
- Fixed the M365 preflight helper StrictMode scalar unwrap issue and reduced false
  positives by scanning code tokens instead of comments/strings.
- Moved stale Office removal package artifacts to
  `AI Knowledgebase\Software\Microsoft Office 365\Archive\PackageArtifacts-20260506`.

**Validation performed:**

- PS 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1, Uninstall.ps1, and
  Invoke-M365PackagePreflight.ps1
- Encoding: UTF-8 BOM present, NonASCII=0 for all four edited PowerShell scripts
- Version sync: Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1 all at 1.5.15
- Removal source folder now contains only active payload files:
  Detect.ps1, Remove-C2R-All.xml, Remove-Office365.ps1, setup.exe, Uninstall.ps1
- M365 preflight helper runs successfully. Remaining preflight warning is unrelated to
  Office removal: `Hall County Default Office 365\Install-Office365.intunewin` is still
  present in that install app source folder.

### 2026-05-06 - Codex Audit - v1.5.14 DISM Follow-Up

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- Software\Microsoft Office 365\Microsoft Office 365 Preflight\Invoke-M365PackagePreflight.ps1
- F:\Logs\WGDevice01\M365PreCleanup_Remove.txt
- F:\Logs\WGDevice01\AppWorkload.log
- F:\Logs\WGDevice01\AppActionProcessor.log

**Files changed:**

- AI-Audit-Handoff.md only.

**Findings:**

- High: Existing `Remove-Office365.intunewin` in the removal source folder is stale. It
  predates v1.5.14, and WGDevice01 logs show content version 21 ran v1.5.13 on 2026-05-05.
- High: DISM pass is wired after AppX child exit 2, but its outcome is non-fatal and not
  verified before `$appxProtectedSkip` suppresses later AppX checks. Marker-only detection
  can still pass with provisioned packages remaining if DISM fails.
- Medium: DISM runtime is not included in the AppX budget calculation. Each remaining
  package can add up to `$script:DismTimeoutSeconds` beyond the AppX budget.
- Medium: The project preflight helper currently throws under StrictMode in
  `Test-IsIgnoredPath` because `.Count` is used directly on `Where-Object` output.
- Medium: `Remove-Office365.ps1.bak` is present in the active source folder and should not
  be packaged.

**Validation performed:**

- PS 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1
- Encoding: UTF-8 BOM present, NonASCII=0 for all three active PowerShell scripts
- Version sync: Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1 all at 1.5.14
- Remove-C2R-All.xml: XML parse OK
- Local Windows PowerShell 5.1 host: 5.1.26100.7462
- Local AppX cmdlet syntax checked for Get-AppxProvisionedPackage,
  Remove-AppxProvisionedPackage, and Remove-AppxPackage
- PSScriptAnalyzer not installed locally

**Remaining risks or human decisions:**

- Decide whether v1.5.14 DISM failure should remain non-blocking. If the goal is to prove
  removal of the WGDevice01 leftovers, make the DISM pass return success/failure and require
  a clean AppX re-query before writing the marker.
- Remove/move stale package and backup artifacts before manual packaging.
- Field-test v1.5.14 on a disposable White Glove device and confirm the two WGDevice01
  packages are absent after the cleanup.

### 2026-05-01 - Codex - Double Audit After Claude Pass

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- AI-Audit-Handoff.md
- AI-Audit-Decisions.md

**Files changed:**

- AI-Audit-Handoff.md: updated package-artifact state; added this audit note.
- AI-Audit-Decisions.md: corrected the HRESULT decision to match local Windows PowerShell 5.1
  evidence.

**Findings:**

- No blocking script defects found in current v1.5.13 source.
- Current AppX HRESULT handling is safe: the script stores `Exception.HResult` as signed Int32
  and compares to signed decimal HRESULT constants at lines 797 and 819.
- Clarification: local Windows PowerShell 5.1 shows `0x80070005` and `0x80073CF1` are signed
  Int32 literals. The WGDevice02 failure was caused by the explicit `[uint32]` cast in v1.5.12,
  not by the use of bare hex literals alone. Decimal constants remain clearer and are acceptable.
- Source folder currently contains no `.intunewin` artifact.

**Validation performed:**

- PS 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1
- Encoding: UTF-8 BOM present, NonASCII=0 for all three PowerShell scripts
- Version sync: all three scripts remain 1.5.13
- Windows PowerShell 5.1 host check: 5.1.26100.7462, FullLanguage
- ODT XML check: `Remove All="TRUE"`, display level None, logging path `C:\IntuneAppLogs`

**Remaining risks or human decisions:**

- Jeremy must manually package v1.5.13 when ready.
- Field retry still needed to prove protected AppX skip behavior and downstream Office install.

### 2026-05-01 - Claude (claude-sonnet-4-6) - HRESULT Overflow Fix (actual code change)

**Files reviewed:**

- F:\Logs\WGDevice02\M365PreCleanup_Remove.txt
- F:\Logs\WGDevice02\AppWorkload.log (via Explore agent)
- F:\Logs\WGDevice02\AppActionProcessor.log (via Explore agent)
- Remove-Office365.ps1 (lines 780-825)

**Files changed:**

- Remove-Office365.ps1: lines 797 and 819 - changed AppX HRESULT comparisons to signed decimal constants.

**Root cause (proven from logs and code):**

- WGDevice02 log `M365PreCleanup_Remove.txt` line 1: `Cannot convert value "-2147024891" to type "System.UInt32"` at line 793 of the child process script.
- The original v1.5.12 failure was caused by `[uint32]($_.Exception.HResult -band 0xFFFFFFFF)`.
  That explicit cast overflows when `Exception.HResult` is negative.
- The skip path for the protected package never ran. The catch block threw, the child process exited 1,
  and all 5 dependent WG apps (Sentinel One, EV Reach, Freshservice, Default Shortcut Pack, Device Rename)
  cascaded to Error.

**Fix applied:**

- Line 797: `if ($hResult -eq 0x80070005)` -> `if ($hResult -eq -2147024891)` (signed Int32 of 0x80070005)
- Line 819: `if ($hResult -ne 0x80073CF1)` -> `if ($hResult -ne -2147009295)` (signed Int32 of 0x80073CF1)

**Clarification from later Codex double audit:** Local Windows PowerShell 5.1 shows these specific
hex literals are signed Int32 values. The required fix was removing the `[uint32]` cast; the signed
decimal constants are retained because they make the intended type unambiguous.

**Validation performed:**

- PS 5.1 parser: PARSE OK
- Encoding: BOM=True NonASCII=0

**Remaining risks or human decisions:**

- No `.intunewin` is currently present in the source folder.
- Jeremy must manually build the new `.intunewin` for v1.5.13, upload new content version, and retry WG.
- WGDevice02 may need to be reset if Intune GRS is blocking retry on the same enrollment.

### 2026-05-01 - Codex - WGDevice02 Failure Fix

**Files reviewed:**

- F:\Logs\WGDevice02\M365PreCleanup_Remove.txt
- F:\Logs\WGDevice02\AppWorkload.log
- F:\Logs\WGDevice02\AppActionProcessor.log
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1

**Files changed:**

- Remove-Office365.ps1: version 1.5.12 -> 1.5.13; changed AppX catch blocks to compare
  signed Int32 HRESULTs directly instead of casting negative HRESULT values to UInt32.
- Detect.ps1: version and RequiredScriptVersion 1.5.12 -> 1.5.13.
- Uninstall.ps1: version 1.5.12 -> 1.5.13.
- AI-Audit-Handoff.md and AI-Audit-Decisions.md updated.

**Root cause:**

- Proven from WGDevice02 logs. `Microsoft Office 365 - Removal` app id
  `eea39785-086c-4c50-8161-c401a0884ae5`, content version 20, ran
  `Remove-Office365.ps1` v1.5.12 and exited 1.
- Script log: `Cannot convert value "-2147024891" to type "System.UInt32"` at line 793.
  This is Access Denied / `0x80070005`, the protected AppX package case that should have
  been non-blocking.
- AppActionProcessor then marked dependent apps as failed because their child dependency
  `eea39785-086c-4c50-8161-c401a0884ae5` failed processing.

**Validation performed:**

- PS 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1
- Encoding: UTF-8 BOM present, NonASCII=0 for all three PowerShell scripts
- Version sync: all three scripts now 1.5.13
- HRESULT simulation in Windows PowerShell 5.1:
  `-2147024891 -eq 0x80070005` is True when compared as signed Int32; old UInt32 cast fails
  as logged on WGDevice02.

**Remaining risks or human decisions:**

- Existing `Remove-Office365.intunewin` is now stale. Jeremy must delete/move it, manually
  package v1.5.13, and upload a new content version.
- WGDevice02 has a GRS entry for the failed Office removal app after the v1.5.12 failure;
  immediate retry on the same enrollment may be blocked until GRS clears or the device is reset.

### 2026-04-30 - Codex - Remove-Office365.ps1 Follow-Up Audit

**Files reviewed:**

- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Detect.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Uninstall.ps1
- Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-C2R-All.xml
- AI Knowledgebase\AGENTS.md
- MEMORY.md

**Files changed:**

- AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff.md

**Findings:**

- High packaging blocker: stale `.intunewin` artifacts are present in the source folder. Existing
  `Remove-Office365.intunewin` predates `Remove-Office365.ps1`, and the `.bak-*` artifact would be
  included in a future package if the folder is packaged as-is.
- Medium design risk: `Detect.ps1` is marker/version-only, while `Remove-Office365.ps1` can write
  the marker after protected provisioned AppX packages are skipped. This is an accepted design
  decision, but needs field validation against the managed M365 install.
- Resolved informational: Remove-C2R-All.xml does specify ODT logging to `C:\IntuneAppLogs`.

**Validation performed:**

- PS 5.1 parser: PARSE OK for Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1
- Encoding: UTF-8 BOM present, NonASCII=0 for all three PowerShell scripts
- Version sync: Remove-Office365.ps1, Detect.ps1, and Uninstall.ps1 all at 1.5.12
- Remove-C2R-All.xml: XML parse OK; `Remove All="TRUE"` and logging path verified
- Windows PowerShell 5.1 host check: 5.1.26100.7462, FullLanguage; AppX cmdlets available

**Remaining risks or human decisions:**

- Do not upload the existing `.intunewin`; Jeremy must manually repackage only after stale artifacts
  are removed from the source folder.
- Field-test protected AppX skip behavior on disposable hardware before production deployment.

### 2026-04-30 - Claude (claude-sonnet-4-6) - Exhaustive PS 5.1 Audit

**Files reviewed:**

- Remove-Office365.ps1 (v1.5.12, 1505 lines)
- AI Knowledgebase\AGENTS.md

**Files changed:**

- Remove-Office365.ps1: fixed cosmetic indentation at line 1421 ($msiEntries try block body)

**Findings - all prior pitfall remediations confirmed present:**

| Pitfall | Check | Result |
| ------- | ----- | ------ |
| P21 - em-dash non-ASCII | NonASCII=0 | Clean |
| P22 - [Parameter()] attributes | All 19 functions are simple functions | Clean |
| P24 - Split-Path -LiteralPath -Parent | All 4 replaced with GetDirectoryName() | Clean |
| P25 - pipeline scalar .Count | All AppXOffice/MSI returns wrapped @() | Clean |
| P26 - direct registry property access | All guarded with PSObject.Properties | Clean |
| New-Item -LiteralPath | Uses [System.IO.Directory]::CreateDirectory() | Clean |
| exit (if ...) expression | Statement-form if/exit used (fixed v1.5.12) | Clean |
| 64-bit process guard | Present at startup before any AppX work | Clean |
| Budget timing stale values | Recomputed at each Assert-BudgetSufficient call | Clean |
| Marker write only on clean pass | Confirmed - never written on 3010 path | Clean |
| Fail closed MSI scan | Unreadable registry keys throw, not silently skipped | Clean |
| Null comparison side | $null always on left in comparisons | Clean |
| HRESULT masking | [uint32]($_.Exception.HResult -band 0xFFFFFFFF) correct | Clean |

**Findings accepted (fixed):**

- Low cosmetic: line 1421 indentation inconsistency - fixed

**Findings informational (no action required):**

- Redundant Test-Path in versionedSetups loop (~line 1157) - harmless TOCTOU guard
- ODT log path comment accuracy depends on XML content - verify separately

**Open design question (not a defect):**

- $appxProtectedSkip flow writes completion marker with protected AppX remaining.
  Decision: acceptable per v1.5.11 design. Confirm against Detect.ps1 before field deployment.

**Tests/validation performed:**

- PS 5.1 parser: PARSE OK
- Encoding: BOM=True, NonASCII=0
- Manual code review: all execution paths traced (main loop, AppXOnly child, all 4 removal types,
  budget guards, reboot-required paths, marker write, error handling)

**Remaining risks or human decisions:**

- Companion Detect.ps1 and Uninstall.ps1 not reviewed in this session
- $appxProtectedSkip acceptability requires Detect.ps1 review
- Field validation on target hardware required before production deployment
### 2026-07-15 - Codex - PDQ Conversion Cross-Note

Converted the Office 365 PDQ folders under `Software\Microsoft Office 365` using the active local
source files present in the workspace on 2026-07-15.

- `Hall County Default Office 365\PDQ\Install-Office365-PDQ.ps1` was converted from the local
  `Install-Office365.ps1` v1.5.2 source.
- `Hall County Default Office 365\PDQ\Uninstall-Office365-PDQ.ps1` was converted from the local
  `Uninstall.ps1` v1.5.2 source.
- `Microsoft Office 365 Removal\PDQ\Remove-Office365-PDQ.ps1` was converted from the local
  `Remove-Office365.ps1` v1.5.15 source and keeps `ScriptVersion=1.5.15` marker parity.
- `Microsoft Office 365 Removal\PDQ\Uninstall-M365PreCleanup-PDQ.ps1` resets the same marker.
- PDQ scripts stage exact payload files from the filestore to local IME-rooted staging folders
  before executing, then clean staged files on all exit paths.
- PDQ M365 Pre-Cleanup sets `$script:KillOfficeProcesses = $false` to remove the Autopilot /
  White Glove process-kill default for live PDQ deployments.

Important: this handoff includes later v1.5.20 notes, but the active local Office removal source
inspected for the PDQ conversion was still v1.5.15. Reconcile that version drift before making a
new Intune package or porting newer behavior into PDQ.
