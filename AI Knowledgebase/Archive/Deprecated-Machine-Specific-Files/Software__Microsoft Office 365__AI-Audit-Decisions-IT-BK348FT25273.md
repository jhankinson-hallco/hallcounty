# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-25 - Emergency WG Reliability: AppX Cleanup Is Fail-Forward

- Decision: For the M365 Pre-Cleanup prerequisite, targeted AppX cleanup is
  attempt-and-log, not a blocker. The script attempts `Remove-AppxProvisionedPackage`,
  `Remove-AppxPackage`, and DISM for remaining provisioned packages when possible, but
  AppX detection failures, AppX child failures/timeouts, API failures, DISM failures,
  and remaining AppX packages do not prevent the cleanup marker from being written.
- Status: Accepted - applied v1.5.20; AppX DISM budget branch corrected in
  v1.5.21 and AppX phase budget branch corrected in v1.5.22 so AppX-only
  budget shortfalls log and continue instead of exiting.
- Evidence type: Multiple White Glove cascades on fresh Windows 11 devices where
  protected inbox Office-related AppX packages caused or likely caused the Office
  removal prerequisite to exit 1. Latest WGDevice02 copied logs prove the root app
  failure was `Microsoft Office 365 - Removal - White Glove` content version 4, but
  the script-authored log was missing, preventing a narrower branch-level fix.
- Rationale: This prerequisite exists to clear known blockers before managed Microsoft
  365 Apps deployment. On fresh Windows 11 White Glove devices, protected inbox AppX
  packages can be impossible to remove in SYSTEM context and may not block the
  downstream Office install. Blocking ESP on those packages is worse operationally
  than accepting AppX leftovers after making removal attempts. C2R, MSI, standalone
  OneDrive, package-file validation, reboot handling, and marker-write failures remain
  blocking.
- Source: F:\Logs\WGDevice02 AppWorkload/AppActionProcessor logs from 2026-06-25;
  Remove-Office365.ps1 v1.5.22 `Test-AppXOfficeInstalled`, `Invoke-RemoveAppXOffice`,
  and main AppX loop.
- Recommended action: Keep this decision until a field run proves a specific AppX
  package left behind by v1.5.20 directly blocks the managed Office, Outlook, or Teams
  install. If that happens, add targeted handling for that package without returning
  the entire AppX phase to broad fail-closed behavior.

### 2026-07-15 - AppX DISM Runtime Budget Is Fail-Forward Scope

- Decision: The DISM AppX runtime-budget check is part of the AppX cleanup
  fail-forward scope. If there is not enough remaining script budget to attempt
  the DISM AppX removal pass, the script must log that AppX cleanup could not
  be attempted within budget and continue toward marker write. It must not call
  `Assert-BudgetSufficient`, because that helper exits the process and cannot
  be caught by a surrounding `try/catch`.
- Status: Accepted - applied v1.5.21 (DISM branch); completed in v1.5.22
  (AppX phase branch). PDQ tandem synced in `Remove-Office365-PDQ.ps1` v1.1.2.
  All remaining `Assert-BudgetSufficient` call sites are blocking phases only:
  C2R, MSI, and OneDrive.
- Evidence type: Source audit
- Rationale: The v1.5.20 White Glove reliability decision intentionally made
  AppX cleanup attempt-and-log, while keeping C2R, MSI, standalone OneDrive,
  package-file validation, non-AppX runtime-budget failures, reboot handling,
  and marker-write failures blocking. A blocking DISM AppX budget exit could
  still cascade ESP late in the run even though the only unresolved work was
  AppX cleanup. That contradicts the fail-forward AppX decision.
- Source: Remove-Office365.ps1 v1.5.22 main AppX loop; PDQ\Remove-Office365-PDQ.ps1
  v1.1.2 main AppX loop.
- Recommended action: Keep `Assert-BudgetSufficient` for blocking phases only.
  AppX-only budget shortfalls should be explicit logs, not process exits.

### 2026-06-23 - Known Windows Inbox Office Support AppX: Non-Blocking

- Decision: Exclude `Microsoft.OfficePushNotificationUtility` and
  `Microsoft.OneDriveSync` from M365 pre-cleanup AppX detection/removal. These package
  names are known protected/inbox Windows 11 support components and must not count as an
  Office install that blocks the managed Microsoft 365 Apps deployment.
- Status: Accepted - applied v1.5.16
- Evidence type: WGDevice02 fresh Windows 11 White Glove failure plus prior protected
  AppX field evidence; exact WGDevice02 script log was not included in the copied logs.
- Rationale: A fresh Windows 11 device may contain these provisioned AppX components even
  when Microsoft 365 Apps Click-to-Run is not installed. Treating them as hard blockers
  contradicts the prerequisite app's role: if no removable Office install is present, the
  cleanup should write its marker so the dependent Office deployment can proceed.
- Source: F:\Logs\WGDevice02 AppWorkload/AppActionProcessor logs;
  Remove-Office365.ps1 v1.5.16 `NonBlockingAppXNamePatterns`
- Recommended action: Keep C2R, MSI, Outlook/Teams/OfficeHub AppX, and unexpected AppX
  removal failures fail-closed. Only these explicitly listed protected/inbox package names
  are non-blocking. Add new names to the allowlist only with field evidence that they are
  Windows inbox support packages and do not block the downstream Office install.

### 2026-06-25 - New Outlook AppX: Best-Effort Removal, Not Non-Blocking

- Decision: `Microsoft.OutlookForWindows` belongs in `$script:BestEffortRemovalPatterns`,
  not in `NonBlockingAppXNamePatterns` and not as a hard blocking target. The script
  actively attempts removal via both the AppX API and DISM. If both fail, the failure is
  logged and the run continues without blocking the cleanup marker.
- Status: Superseded by v1.5.20 broad AppX fail-forward decision. The narrower
  New Outlook classification remains historically correct, but all targeted AppX
  packages now follow the same attempt-and-log behavior.
- Evidence type: WGDevice01 and WGDevice02 White Glove failures; field-proven inability to
  remove this provisioned inbox app in SYSTEM context on Windows 11 24H2; no user session
  exists on WG devices at the time of cleanup so both API and DISM paths fail.
- Rationale: Three-way classification is needed: NonBlocking (skip entirely, not a removal
  target), BestEffortRemoval (attempt removal, fail forward on all errors), and Blocking
  (attempt removal, fail the run on any unresolved error). New Outlook falls into BestEffort
  because (a) removal is desirable when an installed user copy is present (OEM devices), and
  (b) removal is impossible when only the OS-provisioned copy exists (clean WG images).
  Treating it as NonBlocking silently skips OEM installs; treating it as Blocking cascades
  the entire Office deployment chain on clean WG images.
- Source: WGDevice01/WGDevice02 AppWorkload.log + AppActionProcessor.log cascade evidence;
  Remove-Office365.ps1 v1.5.19 `BestEffortRemovalPatterns`, `Test-BestEffortRemovalPackageName`,
  updated `Invoke-RemoveAppXOffice`, updated main loop AppX block.
- Recommended action: Add future packages to `BestEffortRemovalPatterns` only when both
  conditions are confirmed: (a) removal is blocked in SYSTEM context on at least one
  realistic device configuration, AND (b) the package's presence does not prevent the
  downstream managed Office install from succeeding.

### 2026-06-24 - New Outlook AppX Remains A Removal Target

- Decision: Keep `Microsoft.OutlookForWindows` in the AppX removal target list and do not
  include it in `NonBlockingAppXNamePatterns` unless Jeremy explicitly accepts New Outlook
  remaining after the prerequisite cleanup.
- Status: Superseded by 2026-06-25 BestEffortRemovalPatterns decision (v1.5.19)
- Evidence type: Source audit and policy confirmation from current remediation request.
- Rationale: New Outlook is part of the requested Office/Outlook cleanup scope. The
  non-blocking check runs before AppX target matching and removal, so putting
  `Microsoft.OutlookForWindows` in `NonBlockingAppXNamePatterns` causes the script to leave
  it behind and still write the completion marker. A narrower approach (BestEffortRemoval)
  was introduced in v1.5.19 to handle the clean-WG case without silencing OEM installs.
- Source: Remove-Office365.ps1 v1.5.18 `AppXPatterns` and `NonBlockingAppXNamePatterns`.
- Recommended action: See the 2026-06-25 BestEffortRemovalPatterns decision.

### 2026-05-06 - Protected Provisioned Office AppX: DISM Must Prove Cleanup

- Decision: When the AppX child exits 2 because protected provisioned Office-related AppX
  packages remain, the parent must run the DISM provisioned-package cleanup pass and fail
  the run unless a post-DISM provisioned-package re-query is clean.
- Status: Superseded in part by v1.5.16 for NonBlocking inbox support packages, and further
  superseded in part by v1.5.19 for BestEffortRemoval packages (DISM is still attempted, but
  if it fails and only best-effort packages remain, the run continues rather than failing).
  Still applies in full to all Blocking (default) AppX targets.
- Evidence type: Proven from WGDevice01 logs plus source audit
- Rationale: WGDevice01 v1.5.13 logged Access Denied for
  `Microsoft.OfficePushNotificationUtility` and `Microsoft.OneDriveSync`, then wrote the
  marker through the old non-blocking protected-package path. v1.5.14 added DISM but still
  set the skip flag regardless of DISM outcome, so marker-only detection could still report
  success with the same targeted provisioned packages remaining. Since the current goal is
  to remove those leftovers with DISM, the marker must only be written after DISM proves
  the targeted provisioned AppX state is clean.
- Source: F:\Logs\WGDevice01\M365PreCleanup_Remove.txt; Remove-Office365.ps1 v1.5.15
  `Invoke-DismRemoveProtectedProvisionedPackages`
- Recommended action: Keep DISM cleanup fail-closed for Office pre-cleanup. If a future
  package intentionally accepts protected provisioned packages remaining, document that as
  a new exception with field evidence that the downstream M365 install is not blocked.

### 2026-05-01 - HRESULT Handling: Do Not Cast Negative HRESULTs To UInt32

- Decision: Keep `Exception.HResult` comparisons in signed Int32 form. Do not cast negative
  HRESULT values to `[uint32]` for branch logic.
- Status: Accepted - applied v1.5.13
- Evidence type: Proven from WGDevice02 field failure log and local Windows PowerShell 5.1 tests
- Rationale: `Exception.HResult` is signed Int32 in PowerShell/.NET. In v1.5.12, the AppX
  protected-package handler attempted `[uint32]($_.Exception.HResult -band 0xFFFFFFFF)`.
  Access Denied returned `-2147024891` (`0x80070005`), and that explicit cast overflowed before
  the intended non-blocking skip logic could run. Local Windows PowerShell 5.1 confirms
  `0x80070005` and `0x80073CF1` are signed Int32 literals, but signed decimal constants are
  preferred in this script because they make the intended comparison type unambiguous.
- Common HRESULTs as signed Int32: 0x80070005 (E_ACCESSDENIED) = -2147024891;
  0x80073CF1 (ERROR_PACKAGE_NOT_FOUND) = -2147009295.
- Source: F:\Logs\WGDevice02\M365PreCleanup_Remove.txt; Remove-Office365.ps1 lines 797, 819
- Recommended action: For HRESULT branch logic, compare signed values directly. Use unsigned
  conversion only for display formatting, and only with a field-tested helper or expression.

### 2026-04-30 - Simple Functions Required: No [Parameter()] Attributes

- Decision: All helper functions must be simple functions with no `[Parameter()]` or
  `[CmdletBinding()]` attributes. Type constraints (`[string]`, `[int]`, `[object[]]`) remain
  permitted on simple function params.
- Status: Accepted (applied through v1.5.4 - v1.5.6)
- Evidence type: Proven from field failure logs and PS 5.1 runtime behavior
- Rationale: PS 5.1 advanced-function parameter-set resolution throws
  ParameterBindingException ("Parameter set cannot be resolved using the specified named
  parameters") on decorated functions in IME/SYSTEM context, regardless of decoration
  consistency. Simple functions bypass the resolution engine entirely. Named-parameter
  calls still bind correctly by name match.
- Source: v1.5.4 - v1.5.6 changelog; field failures in White Glove runs; pitfall P22 in
  AGENTS.md reference_intune_pitfalls.md
- Recommended action: Do not re-add [Parameter()] or [CmdletBinding()] to any function
  without a field-proven justification specific to this runtime context.

### 2026-04-30 - Split-Path -LiteralPath -Parent: Use GetDirectoryName() Instead

- Decision: All parent-directory resolution must use `[System.IO.Path]::GetDirectoryName()`
  instead of `Split-Path -LiteralPath ... -Parent`.
- Status: Accepted (applied v1.5.8)
- Evidence type: Proven from field failure at line 488 in v1.5.7 White Glove run
- Rationale: `Split-Path -LiteralPath` with `-Parent` throws ParameterBindingException in
  PS 5.1 under IME/SYSTEM context. `.GetDirectoryName()` is pure .NET with no parameter
  binding and no runtime context dependency.
- Source: v1.5.8 changelog; pitfall P24 in reference_intune_pitfalls.md
- Recommended action: Never use Split-Path -LiteralPath -Parent in any Intune-deployed script.

### 2026-04-30 - Pipeline Scalar Unwrap: Wrap All Function Returns With @()

- Decision: All pipeline-returning functions (Get-AppXOfficePackages,
  Get-AppXOfficeProvisionedPackages, Get-MSIOfficeEntries) must be wrapped with `@()` at every
  call site where `.Count` is accessed.
- Status: Accepted (applied v1.5.9)
- Evidence type: Proven from field failure at line 717 in v1.5.8
- Rationale: PS pipeline unwraps single-element returns to scalars. `.Count` on an
  AppxPackage or PSCustomObject throws PropertyNotFoundException under
  Set-StrictMode -Version Latest.
- Source: v1.5.9 changelog; pitfall P25 in reference_intune_pitfalls.md
- Recommended action: @()-wrap any function that returns pipeline output when .Count
  is needed on the result.

### 2026-04-30 - Registry Property Access: Guard With PSObject.Properties

- Decision: All access to registry key properties (DisplayName, UninstallString, etc.)
  must be guarded with `$props.PSObject.Properties['PropertyName']` before accessing
  the property value.
- Status: Accepted (applied v1.5.10)
- Evidence type: Proven from field failure at line 835 in v1.5.9
- Rationale: Many uninstall registry keys have no DisplayName or UninstallString value.
  Set-StrictMode -Version Latest throws PropertyNotFoundException on direct access to
  a non-existent property. PSObject.Properties check is the safe guard pattern.
- Source: v1.5.10 changelog; pitfall P26 in reference_intune_pitfalls.md
- Recommended action: Always guard registry property access; never assume properties
  exist on Get-ItemProperty results.

### 2026-04-30 - AppX Protected Packages: Write Marker, Treat As Non-Blocking

- Decision: When provisioned AppX packages fail with Access Denied (0x80070005) during
  removal, log them, skip them, and treat the result as non-blocking. The child exits 2,
  the parent sets `$appxProtectedSkip = $true`, and the completion marker is written after
  a clean pass on all other types.
- Status: Accepted (applied v1.5.11)
- Evidence type: Proven from field failure at line 752 in v1.5.10 (COMException 0x80070005
  on Microsoft.OfficePushNotificationUtility)
- Rationale: Protected system components cannot be removed in SYSTEM context. Retrying
  will not change the outcome. The loop must terminate rather than exhaust MaxIterations.
  Whether these packages actually block the M365 managed install is a separate question
  that requires Detect.ps1 review and field validation.
- Source: v1.5.11 changelog
- Recommended action: Before production deployment, confirm that Detect.ps1 criteria and
  the M365 install package tolerate protected AppX packages remaining.

### 2026-04-30 - Fail Closed MSI Scan: Unreadable Keys Throw

- Decision: Any unreadable registry key during MSI scan causes a throw (fail closed), not
  a silent skip. The script exits 1 and Intune retries.
- Status: Accepted (established in v1.4.0 design)
- Evidence type: Proven design decision (documented in function header)
- Rationale: An unreadable key might be an Office-related MSI entry. Declaring clean state
  with incomplete scan data is worse than failing - Intune will retry on the next cycle.
  Per-key key names are written to the error log before throwing for triage.
- Source: Get-MSIOfficeEntries function header comment; v1.4.0 changelog
- Recommended action: Do not soften this to a skip without a specific field justification.

### 2026-07-15 - PDQ Conversion Uses Active Local Source Until Version Drift Is Reconciled

- Decision: The initial Office 365 PDQ conversion is based on the active local scripts present in
  the workspace, not on later handoff-only history.
- Status: Accepted for PDQ v1.0.0 conversion
- Rationale: The IT-BK348FT25273 handoff references later M365 Pre-Cleanup v1.5.20 work, but the
  local `Software\Microsoft Office 365\Microsoft Office 365 Removal\Remove-Office365.ps1` inspected
  during PDQ conversion was v1.5.15. Porting unseen v1.5.20 behavior into PDQ would be inventing
  source state. The correct near-term action is to preserve current local parity and document the
  drift for a follow-up reconcile.
- Recommended action: Before creating a new Intune package or revising PDQ beyond v1.0.0, compare
  the active local removal script against the v1.5.20 handoff notes and decide whether to restore,
  port, or discard those later changes.

### 2026-07-15 - PDQ Office Scripts Requiring Elevation Must Fail Fast On Non-Admin Context

- Decision: PDQ Office scripts that require local administrator rights must include an explicit
  local administrator preflight before payload staging or destructive cleanup/install work.
- Status: Accepted - applied to Office uninstall and M365 Pre-Cleanup PDQ scripts
- Rationale: A misconfigured PDQ run-as account should fail with a direct `Permissions` category
  before touching protected local staging paths or running ODT/AppX/MSI cleanup.
- Recommended action: Keep this check in future PDQ Office revisions unless the package is
  intentionally redesigned for a non-admin user context.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### 2026-06-24 - v1.5.17 New Outlook Non-Blocking Allowlist Conflict

- Prior finding: The 2026-06-23 decision accepted only
  `Microsoft.OfficePushNotificationUtility` and `Microsoft.OneDriveSync` as
  known non-blocking Windows inbox Office support AppX packages and recommended
  keeping Outlook/Teams/OfficeHub AppX fail-closed unless new field evidence
  justified a documented exception.
- Disagreement: v1.5.17 added `Microsoft.OutlookForWindows` to
  `NonBlockingAppXNamePatterns`. This is not equivalent to the prior support
  package allowlist because New Outlook is explicitly documented in
  `Remove-Office365.ps1` as an AppX component covered by this cleanup.
- Evidence type: Proven from source code and changelog; deployment impact is a
  recommendation pending Jeremy's policy decision.
- Supporting evidence: `Remove-Office365.ps1` v1.5.17 lines 36-38 and 367
  identify `Microsoft.OutlookForWindows` as a target; line 379 adds it to
  `NonBlockingAppXNamePatterns`; lines 747, 759, and 795 skip non-blocking
  names before matching/removal. Effective behavior: New Outlook is not removed.
- Recommended action: Remove `Microsoft.OutlookForWindows` from the non-blocking
  allowlist unless Jeremy explicitly accepts New Outlook remaining on fresh
  Windows 11 24H2 devices. If the 24H2 issue is only with the provisioned inbox
  package, consider a narrower implementation that does not suppress installed
  New Outlook package detection/removal.
