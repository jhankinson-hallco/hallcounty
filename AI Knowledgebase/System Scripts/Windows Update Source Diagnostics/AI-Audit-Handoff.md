# AI-Audit-Handoff.md

## Current State

- Project: Windows Update Source Diagnostics
- Current version: 1.0.0
- Deployment type: Standalone elevated diagnostic collection script
- Primary script: `Collect-WindowsUpdateSourceDiagnostics.ps1`
- Detection: Not applicable
- Uninstall: Not applicable
- Package artifact: Not applicable

## Active Risks

- The first validation capture from freshly imaged `TA-PF47WVTR` is complete.
- A second capture after moving the computer object to the Tax Assessors
  Computers OU remains optional validation of OU equivalence; it is no longer
  needed to prove why Microsoft Update is registered and queried.
- Some evidence sources depend on local administrator rights, domain-controller
  connectivity, enabled event logs, and available Windows inbox tools.

## Recent Changes

- Created `Collect-WindowsUpdateSourceDiagnostics.ps1` v1.0.0 and its operator
  `README.md`.
- The collector now produces an automated source-decision matrix and diagnosis,
  GPO/RSoP evidence, AD OU/link/security/SYSVOL evidence, effective and raw
  update policy, PolicyManager provenance, Update Agent service registration,
  network/WSUS reachability, event logs, endpoint setup logs, an MDM diagnostics
  CAB, a converted WindowsUpdate.log, a file inventory, and a ZIP archive.
- Clarified the required two-capture workflow: first in the default
  `CN=Computers` staging container before manual policy actions, then in the Tax
  Assessors Computers OU after a deliberate computer Group Policy refresh.

## Required Validation Before Deployment

- Parse with 64-bit Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only script content.
- Run in an elevated 64-bit Windows PowerShell session on a test endpoint.
- Confirm the script makes no policy, update-service, scan, or Group Policy
  changes.
- Confirm the generated summary, registry exports, GPO evidence, MDM evidence,
  update-service inventory, and event-log exports are present in the ZIP.

## Latest Work Log

### 2026-08-12 - Codex - Fresh post-reenrollment findings

- Files reviewed:
  - `TA-F4798J4_PostReEnroll_20260812-113907.zip` (12,015,792 bytes,
    SHA-256 `7F223FB7F6E3A87FB41A15F3373481345A3E00489F8C93C81BACC56F9479025B`)
  - `TA-F4798J4_jtsmith_dsregcmd.txt`, captured non-elevated as
    `HALLCOUNTY\jtsmith` at 11:40 local time.
- Proven successful change: At 09:01:29, `jtsmith@hallcounty.org` completed a
  new Microsoft Entra workplace registration. The current user-context device
  ID is `b0b8a35f-f276-4f5b-a7a4-68c097f8c20a`; its TPM-backed certificate
  thumbprint is `4EE7474AEE31682AA63D21F360CE56199BD2AA67` and is valid through
  2036. The machine remains domain joined and not Entra/hybrid joined, as
  expected without the AD SCP/Connect configuration.
- Proven failed change: The old machine-level Intune enrollment was not
  removed. The fresh report still contains enrollment GUID
  `7BB62591-9BE5-4C3B-9475-3EA0D2E486F7`, old `ecarney` UPN, old Intune device
  ID `db4670d7-de5d-4496-bdc7-652cb38c3a0b`, old MDM certificate thumbprint
  `45330198FA983C78A09574F469DA3B373F404F69`, its OMADM account/session,
  PolicyManager provider, and 16 EnterpriseMgmt scheduled tasks. Schedule #3
  and OMADM client tasks ran on August 12 against that old GUID.
- Enrollment failure: At 09:02:27 and 09:07:44, Windows sent MDM certificate
  enrollment requests in recovery mode. Intune returned `MessageFormat` with
  `Device not found during recovery`, producing `0x80180001`. This is
  consistent with deleting the old Intune cloud object while leaving its local
  recovery-enabled enrollment record.
- Cryptographic evidence: The old `ConfigMgrEnrollment0` key continued to fail
  open with `0x80090016`; a new enrollment attempt then failed to create the
  same container with `0x8009000F` (object already exists). IME continued using
  the old device ID and old certificate and failed its TLS connection.
- WAM evidence: The non-elevated user capture shows `WorkplaceJoined=YES` but
  `WamDefaultSet=NO`. AAD Operational logged repeated WAM token-operation
  failures `0x80048904` after the new registration. The new workplace
  registration alone therefore did not repair the Microsoft 365 sign-in state.
- Conclusion: A clean Intune reenrollment has not yet been tested. The action
  completed a new user-level Entra registration on top of the broken old
  machine-level MDM enrollment. Do not interpret this as proof that a valid new
  Intune enrollment recreated the original defect.

### 2026-08-12 - Codex - Post-reenrollment archive validation

- File reviewed: `C:\Users\jhankinson\Downloads\MDMDiagReport (1).zip`,
  supplied after removal and attempted reenrollment of `TA-F4798J4`.
- Finding: This is not a post-reenrollment capture. It is byte-for-byte
  identical to the original August 11 report: 7,205,017 bytes with SHA-256
  `9042F9BFFBA0B129CEEE7CB4C63580959B6FCFEE88F260804DB32B4DE404CB68`.
- Embedded evidence: The collector ran on 2026-08-11 at 16:36:16, the reported
  last failed sync was 16:33:46, and the archive still contains old enrollment
  GUID `7BB62591-9BE5-4C3B-9475-3EA0D2E486F7`, old Intune device ID
  `db4670d7-de5d-4496-bdc7-652cb38c3a0b`, and the old MDM certificate.
- Conclusion: The renamed `(1)` archive cannot prove anything about the cleanup
  or reenrollment. Generate a new uniquely named MDM diagnostics archive after
  reproducing the current failure, and capture `dsregcmd /status` in the
  affected user's non-elevated session.

### 2026-08-12 - Codex

- Files reviewed: `MDMDiagReport.zip` for `TA-F4798J4` (63 files; report
  generated 2026-08-11 16:36), including the MDM HTML/XML and registry dump,
  Intune Management Extension logs, AAD/WAM, device-registration, MDM sync,
  NCrypt, Application, and System event logs.
- Source validation: SHA-256
  `9042F9BFFBA0B129CEEE7CB4C63580959B6FCFEE88F260804DB32B4DE404CB68`;
  archive size 7,205,017 bytes.
- Files changed: Updated the project handoff and durable decisions only; no
  endpoint, tenant, policy, certificate, or enrollment state was changed.
- Findings accepted:
  - The captured endpoint has a real broken Intune device-authentication state.
    Its MDM certificate remains in the computer certificate store, but the
    referenced TPM-backed private-key container `ConfigMgrEnrollment0` cannot
    be opened. NCrypt logged 258 failures (`0x80090016`, keyset does not exist)
    between 15:19:58 and 16:36:14 from the Intune agent, OMA-DM client, and
    Intune health processes.
  - Native MDM sync failed with `0x80072f9a`, and the Intune Management
    Extension independently failed mutual-TLS discovery with
    `SecureChannelFailure`. The certificate was not expired; its private key
    was missing or inaccessible.
  - The device is domain joined but not Microsoft Entra joined or hybrid
    joined. Automatic registration repeatedly failed with `0x801c001d` because
    Windows could not read Microsoft Entra tenant/SCP information from AD.
    Device-token recovery then failed with `0x801c0450`.
  - WAM/AAD recorded key and token-broker failures, including `0x80090016`,
    `0x8029040E`, `0x80048904`, and PRT renewal failures. This directly supports
    the reported Microsoft 365/work-account sign-in loop.
  - The enrollment record is still owned by `ecarney@hallcounty.org` and named
    `ecarney_Windows_6/24/2026_8:16 PM`, while the active user is
    `HALLCOUNTY\jtsmith`. The report records six workplace unjoins and five
    rejoins during the technician session and ends after the final unjoin.
  - Intune certificate authentication still succeeded at 14:47, and native MDM
    recorded a last successful session at 15:03. The first missing-key event
    followed the 15:18 reboot. Therefore the fatal broken-enrollment state was
    introduced or exposed during the intervention and cannot safely be treated
    as the proven cause of the original ticket.
  - The endpoint entered Modern Standby repeatedly on idle. No Ethernet
    link-down/link-up events were recorded during those idle sessions, and the
    local SQL service recorded clean starts and stops around deliberate reboots,
    not a runtime SQL failure. The archive does not prove the WINGAP connection
    error was caused by Intune, Entra, or physical Ethernet power management.
  - A separate application fault is proven: OneDrive crashed repeatedly, 15
    times with `GovRMHook64.dll` as the faulting module on 2026-08-11.
  - TPM AIK enrollment also failed because the Microsoft attestation endpoint
    rejected the device's ECC P-384 AIK request. This is separate from the
    missing Intune MDM private key and can affect enrollment-attestation status.
- Findings rejected: An expired MDM certificate, general Internet outage,
  physical Ethernet link loss during the captured idle sessions, or a proven
  causal relationship between the WINGAP, Google-account, and Microsoft device
  identity symptoms.
- Remaining risks or human decisions: Do not continue Office reinstalls or WAM
  cache deletion as the primary remediation. Verify current `dsregcmd /status`,
  certificate/private-key access, and tenant device records; then use a clean,
  supported re-enrollment or reprovisioning path appropriate to the intended
  device identity. Investigate WINGAP separately with an exact occurrence time,
  application/SQL connection details, and a Modern Standby power report.

### 2026-08-06 - Codex

- Files reviewed: Complete first-capture archive
  `TA-PF47WVTR_WindowsUpdateSourceDiagnostics_20260806-091646.zip` (106 files,
  collector steps 15/15 successful), including RSoP, AD/GPO scope, registry,
  PolicyManager provenance, update-service inventory, event logs,
  WindowsUpdate.log, and WSUS network tests.
- Files changed: Updated project handoff and durable decisions with the first
  endpoint findings; no endpoint policy or service registration was changed.
- Findings accepted:
  - The device object was in `CN=Computers,DC=hallcounty,DC=org` during the
    capture.
  - `WSUS - Internal (TC18)` was in scope and applied. Effective policy named
    `http://core-wsus-01.hallcounty.org:8530`, and `UseWUServer=1`.
  - DNS, TCP 8530, the WSUS ClientWebService HTTP endpoint, domain secure
    channel, and SYSVOL access all succeeded.
  - Intune MDM set `Update/AllowMUUpdateService=1` through enrollment provider
    `9615DFA6-1B1F-4DD0-9646-650366E0CA8D`. This conflicts with the WSUS GPO's
    disabled setting and registers Microsoft Update as the default AU service.
  - WindowsUpdate.log proves a three-service federated scan. Microsoft Update
    offered MSRT KB890830, Windows Security platform KB5007651, and Defender
    intelligence KB2267602. DCat Flighting offered driver/firmware content and
    a .NET flight update. WSUS completed successfully and offered zero updates.
  - The evidence does not show a Windows cumulative quality update bypassing
    WSUS. It shows Microsoft Update and DCat being permitted as additional
    sources while WSUS remains active.
  - Two earlier `0x80244010` events indicate an exceeded-server-round-trip
    condition, but later successful WSUS scans and connectivity disprove a
    current inability to reach or use WSUS.
- Findings rejected: Missing Entra Connect Sync, wrong staging location, blocked
  inheritance, an unapplied WSUS GPO, DNS failure, port failure, proxy failure,
  or an unavailable WSUS web service as the cause of Microsoft Update being the
  default service on this endpoint.
- Rationale: Local PolicyManager event 813 and provider provenance identify the
  setting and winning MDM enrollment directly; WindowsUpdate.log identifies
  the actual service GUID, endpoint URL, results, and update titles for each
  scan.
- Tests/validation performed:
  - Source ZIP and local working copy SHA-256 matched:
    `F54E6F6E02A2F71E05B890D5851F0054F43FF3191328B8D02099B6595D132DC9`.
  - Collector status: 15 completed steps, zero failures.
  - Correlated GPO application, effective registry, MDM event 813, update-agent
    service GUIDs, WSUS reachability, scan endpoints, and returned update titles.
- Remaining risks or human decisions: Identify the assigned Intune update ring
  or settings-catalog profile whose **Microsoft product updates** setting is
  **Allow**. If the desired state is strict WSUS-only, change the assignment or
  setting first, allow MDM to refresh, and then remove the sticky Microsoft
  Update service registration using Microsoft's documented method.

### 2026-08-05 - Codex

- Files reviewed: Shared `AGENTS.md`, `MEMORY.md`, PowerShell 5.1 reference,
  PowerShell audit standard, encoding standard, script methodology, and targeted
  Intune pitfalls.
- Files changed: Created project handoff and decision records.
- Findings accepted: Update-source diagnosis must preserve initial state and
  distinguish WSUS registration, effective WSUS policy, Microsoft Update
  registration, and per-update-class scan-source policy.
- Findings rejected: None.
- Rationale: The Update Agent default-service flag alone cannot prove the source
  used for each update class.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: passed.
  - Approved function verbs: passed.
  - Forbidden/PowerShell 7-only syntax scan: passed.
  - UTF-8 BOM and ASCII-only verification: passed before final handoff; repeat
    after the final edit as required.
  - Non-elevated prerequisite test: correctly rejected with exit code 1.
  - Windows PowerShell 5.1 unit execution: policy snapshot, four class-source
    rows, Update Agent COM inventory, PolicyManager provider inventory, AD/GPO
    scope, GPO SYSVOL access, native command capture and exit codes all passed.
  - Diagnosis generation, raw registry export, and filtered CSV/EVTX event-log
    export all passed.
  - Full elevated main-path run, MDM CAB generation, and WindowsUpdate.log
    conversion remain target-device tests because the development session is
    not elevated.
- Remaining risks or human decisions: Run the completed collector elevated on
  `TA-PF47WVTR` before any manual `gpupdate`, Intune sync, OU move, or Windows
  Update scan, then return the complete ZIP.
