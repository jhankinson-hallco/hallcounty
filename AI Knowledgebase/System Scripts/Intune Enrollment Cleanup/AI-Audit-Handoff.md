# AI-Audit-Handoff.md

## Current State

- Project: Intune Enrollment Cleanup
- Current version: 1.0.1
- Deployment type: Standalone elevated last-resort repair script
- Primary script: `Reset-IntuneEnrollment.ps1`
- Detection: Built-in audit and post-cleanup verification
- Uninstall: Not applicable
- Package artifact: Not applicable

## Active Risks

- The script deliberately removes a specifically identified local Intune MDM
  enrollment, its certificate and TPM key container, its EnterpriseMgmt tasks,
  its provider state, and the Intune Management Extension so a new enrollment
  can be created.
- Microsoft documents Settings > Accounts > Access work or school > Disconnect
  as the supported local unenrollment path. Direct cleanup is a last-resort
  recovery method for the proven corrupted TA-F4798J4 state, not a fleet-wide
  unenrollment method.
- The script does not remove the computer from the on-premises Active Directory
  domain, clear the TPM, remove BitLocker protectors, delete cloud objects, or
  remove per-user Microsoft Entra registration.
- Policy settings that tattoo outside PolicyManager can remain until Group
  Policy or a valid new MDM enrollment reapplies the intended state.

## Recent Changes

- Created `Reset-IntuneEnrollment.ps1` v1.0.0 and its operator `README.md`.
- Added audit-only default behavior, exact device/enrollment/Intune-device-ID/
  certificate/key/provider safety gates, administrator and join-state checks,
  protected evidence backups, targeted EnterpriseMgmt and registry cleanup,
  exact key/certificate removal, IME reset, and post-cleanup verification.
- v1.0.1: Applied a Claude audit's three Medium fixes: replaced a tautological
  self-comparison guard on the IME residual-path move (compared a value to
  itself, could never throw) with a real reparse-point check; restricted the
  backup ROOT directory (`C:\IntuneEnrollmentCleanupBackup`), not just the
  per-run timestamped subfolder, to SYSTEM and local Administrators; replaced
  `Split-Path -Leaf` with `[System.IO.Path]::GetFileName()` per the documented
  P24 Split-Path parameter-binding pitfall and to remove `-Path` wildcard
  interpretation risk.

## Required Validation Before Deployment

- Parse with 64-bit Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only script content.
- Run audit-only mode on TA-F4798J4 and confirm the expected enrollment GUID,
  certificate thumbprint, crypto provider, and key container are matched.
- Confirm the user-level work/school connection is disconnected in the affected
  user's session before execution.
- Confirm the backup directory contains registry exports, certificate metadata,
  scheduled task XML, dsregcmd state, and IME evidence before removal begins.
- Confirm the local AD domain join remains intact after cleanup and reboot.
- Confirm the old key container, certificate, enrollment registry roots, and
  EnterpriseMgmt task folder are absent before attempting reenrollment.
- After reenrollment, confirm a new enrollment GUID, new Intune device ID, new
  MDM certificate/key container, and new EnterpriseMgmt task folder.

## Latest Work Log

### 2026-08-12 - Claude

- Files reviewed: Shared AGENTS.md; project handoff/decisions; README.md;
  `reference_intune_pitfalls.md`, `reference_intune_contexts.md`,
  `reference_intune_paths.md`; the full `Reset-IntuneEnrollment.ps1` v1.0.0
  source (1,150 lines).
- Files changed: `Reset-IntuneEnrollment.ps1` (bumped to v1.0.1, three fixes
  below); this handoff.
- Findings accepted (fixed, now v1.0.1):
  - Dead/tautological safety check in `Uninstall-IntuneManagementExtension`
    (`$resolvedSource -cne $allowedSource` compared a value computed from the
    same expression against itself; could never throw). Replaced with a real
    reparse-point check via `.Attributes -band [System.IO.FileAttributes]::ReparsePoint`.
  - Backup ROOT directory (`C:\IntuneEnrollmentCleanupBackup`) was created
    implicitly by `[System.IO.Directory]::CreateDirectory()` but never
    ACL-restricted itself -- only the per-run timestamped child was. Added an
    idempotent `icacls` restriction on the root, applied before the child.
  - `Split-Path -Path $residualPath -Leaf` replaced with
    `[System.IO.Path]::GetFileName($residualPath)` per the documented P24
    Split-Path pitfall and to drop `-Path` wildcard-interpretation risk.
- Findings rejected / not implemented: Moving the `#region CONFIGURATION`
  block inside the main try/catch (Low severity -- interactive execution
  means an unhandled failure there would still print to console; restructuring
  risk judged not worth it for a low-likelihood, low-impact gap).
- Rationale: All three fixed items have zero live-input dependency (hardcoded
  source paths, not operator-controlled), so pre-fix risk was low, but the
  fixes are free and close gaps the script's own stated design goals claim to
  already cover (real reparse-point safety, full backup-tree ACL restriction,
  no reliance on `Split-Path` edge cases).
- Tests/validation performed: Re-ran the Windows PowerShell 5.1 parser after
  every edit (0 errors throughout); re-verified UTF-8 BOM + ASCII-only after
  edits (`BOM=True NonASCII=0`); manually traced identity-gate behavior across
  partial-failure re-run scenarios; empirically verified in a live PS 5.1
  session that (a) `@()` wrapping a function/pipeline CALL (not a bare
  variable) correctly collects 0/1/N emitted objects without collapse, which
  is the pattern used at every call site in this script for P25/P27/P29-class
  safety, and (b) `Invoke-NativeCommand`'s `2>&1 | ForEach-Object { $_.ToString() }`
  pattern does not trigger early termination under
  `$ErrorActionPreference = 'Stop'` and `$LASTEXITCODE` is read correctly
  afterward. Target-device audit and execute modes remain pending (unchanged
  from prior entry).
- Remaining risks or human decisions: README does not yet document what to do
  if `-Execute` fails AFTER the key-container deletion succeeds but before
  registry cleanup completes -- the script's own identity pre-checks will
  correctly refuse a naive re-run in that state, but the operator isn't told
  what to do next (unlike the already-documented "stop and reimage" guidance
  for key-deletion failure itself). Recommend adding one sentence to
  README.md's post-enrollment-proof section covering this gap; not yet done.

### 2026-08-12 - Codex

- Files reviewed: Shared instructions and PowerShell references; Windows Update
  Source Diagnostics handoff/decisions; TA-F4798J4 post-reenrollment registry
  evidence; current Microsoft unenrollment, Entra registration, IME, and
  certutil documentation.
- Files changed: Created `Reset-IntuneEnrollment.ps1`, `README.md`, project
  handoff, and project decisions.
- Findings accepted: A cleanup tool must target only the proven old enrollment
  and preserve the AD domain join and TPM.
- Findings rejected: Broad deletion of all enrollment GUIDs, clearing the TPM,
  or treating direct registry deletion as the normal supported unenrollment
  workflow.
- Rationale: TA-F4798J4 retains the exact old MDM enrollment and orphaned key
  container after a supported disconnect/reconnect attempt.
- Tests/validation performed: Windows PowerShell 5.1 parser passed; all command
  names resolved in Windows PowerShell 5.1; function verbs are approved; static
  scan found no prohibited PowerShell 7 syntax, aliases, `Invoke-Expression`,
  `Get-WmiObject`, or `Write-Host`. A local certutil read-only test proved that
  `-key` can return exit code 0 while reporting `NTE_BAD_KEYSET`, and verification
  was corrected to inspect output rather than exit code alone. PSScriptAnalyzer
  was unavailable locally. Target-device audit and execute modes remain pending.
- Remaining risks or human decisions: If certutil cannot delete the exact
  orphaned platform key container, stop and reimage rather than deleting TPM
  storage files manually.
