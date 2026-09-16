# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### YYYY-MM-DD - <Decision Title>

- Decision:
- Status: Accepted / Rejected / Partially accepted / Superseded
- Evidence type: proven from code/docs/logs / likely inference / recommendation
- Rationale:
- Source or local evidence:
- Recommended action:

### 2026-06-10 - Use 2107 For Temporary Domain Not-Ready, Keep 2103 As Hard Rename Failure

- Decision: v1.0.3 checks domain readiness before rename. If domain join, DC
  discovery, or secure channel is not ready within the bounded wait, the script
  exits 2107 so Intune retries. If `Rename-Computer` itself fails after readiness
  is proven, the script exits 2103 as a hard failure.
- Status: Accepted
- Evidence type: recommendation based on code and Intune retry configuration
- Rationale: Domain/DC availability can be transient during White Glove. Delegation,
  collision, or locked-object failures after readiness is proven are usually real
  configuration issues and should fail visibly.
- Source or local evidence: `Rename-Device-System.ps1` v1.0.3 `Wait-DomainReady`
  and `Rename-Computer` catch paths.
- Recommended action: Keep portal return code 2107 configured as Retry and 2103
  configured as Fail.

### 2026-06-10 - Hardcode Detect Prefix For This Package

- Decision: `Detect.ps1` v1.0.2 sets `$script:PrefixOverride = 'TD'` to match the
  install script prefix.
- Status: Superseded
- Evidence type: recommendation based on detection semantics
- Rationale: This prevents false-positive detection from stale
  `C:\IntuneDeploymentFiles\DevicePrefix.txt` content on reused or repurposed
  devices. The tradeoff is that any future prefix change must update both scripts.
- Source or local evidence: `Detect.ps1` v1.0.2 configuration block.
- Recommended action: On every department/prefix clone, update both
  `Rename-Device-System.ps1` `$script:DevicePrefix` and `Detect.ps1`
  `$script:PrefixOverride`.
- Superseded by: 2026-06-10 - DevicePrefixApp Prefix File Is Source Of Truth.

### 2026-06-10 - DevicePrefixApp Prefix File Is Source Of Truth

- Decision: v1.0.4 reads the prefix from
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`
  by default. `Detect.ps1` v1.0.3 also uses this file with blank `PrefixOverride`.
- Status: Accepted
- Evidence type: recommendation based on user request and code changes
- Rationale: DevicePrefixApp is the department-specific source of truth, so the
  rename package should not need a per-department hardcoded prefix. The IME
  `IntuneFiles` path is machine-wide and usable in White Glove SYSTEM context.
- Source or local evidence: `Rename-Device-System.ps1` v1.0.4 and `Detect.ps1`
  v1.0.3.
- Recommended action: Make DevicePrefixApp a dependency or ensure it completes
  before the rename app. Keep 2107 configured as Retry for missing prefix file.

### 2026-06-10 - Script Logs Use IME Logs Folder

- Decision: System Scripts write install logs as
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<ScriptName>_Install.txt`
  and uninstall logs as `SCRIPT_<ScriptName>_Uninstall.txt`.
- Status: Accepted
- Evidence type: user direction
- Rationale: Co-locating custom deployment logs with IME logs simplifies collection
  and triage.
- Source or local evidence: Shared `AGENTS.md`, `reference_intune_paths.md`, and
  `Rename-Device-System.ps1` v1.0.4.
- Recommended action: Apply this convention to future System Scripts edits and use
  `APP_<AppName>_Install.txt` / `_Uninstall.txt` for scripts under `Software`.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:

### 2026-06-10 - Not Ready To Package Until Scalar Count Is Fixed Or Waived

- Prior finding: 2026-06-10 handoff stated all pre-packaging checks were complete
  and scripts were ready to package.
- Disagreement: `Rename-Device-System.ps1` still has a PS 5.1 StrictMode scalar
  unwrap failure path at the Autopilot enrollment subkey count check.
- Evidence type: proven from local Windows PowerShell 5.1 behavior and code review.
- Supporting evidence: Under `Set-StrictMode -Version Latest`, a scalar registry key
  object from `Get-Item HKLM:\SOFTWARE` throws `PropertyNotFoundException` when
  `.Count` is read. The script assigns `Get-ChildItem HKLM:\SOFTWARE\Microsoft\Enrollments`
  directly to `$Subkeys` and then reads `$Subkeys.Count`, so a target with exactly
  one enrollment subkey can fail before reaching rename.
- Recommended action: Change the assignment to array capture, for example
  `$Subkeys = @(Get-ChildItem -LiteralPath $EnrollmentsPath -ErrorAction SilentlyContinue)`,
  then re-run PS 5.1 parse and encoding checks before packaging.
- Follow-up: Implemented in `Rename-Device-System.ps1` v1.0.3 and revalidated with
  Windows PowerShell 5.1 parser plus BOM/ASCII checks.
