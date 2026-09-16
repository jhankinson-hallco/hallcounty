# AI-Audit-Decisions.md

## Durable Decisions

### 2026-08-12 - Distinguish workplace registration from Intune reenrollment on TA-F4798J4

- Decision: Do not treat the August 12 `jtsmith` Access work or school action as
  a successful Intune reenrollment. Treat it as a successful user-level Entra
  workplace registration followed by a failed recovery of the surviving old
  machine-level MDM enrollment.
- Status: Accepted
- Evidence type: proven from fresh post-action endpoint evidence
- Rationale: `dsregcmd` records a new workplace device and certificate for
  `jtsmith`, but the MDM registry, OMADM account, MDM certificate, PolicyManager
  provider, EnterpriseMgmt task folder, IME client identity, and sync sessions
  all remain tied to the old `ecarney` enrollment. Intune explicitly returned
  `Device not found during recovery` twice with `0x80180001` after its cloud
  device object had been deleted.
- Source or local evidence: Fresh August 12 post-reenrollment MDM diagnostics
  archive and non-elevated `jtsmith` `dsregcmd /status` capture.
- Recommended action: Stop repeated reconnect attempts. Either complete a
  verified removal of the entire old local MDM enrollment before another
  connection attempt, or reimage/reprovision the device. After a truly clean
  attempt, require a new enrollment GUID, new Intune device ID, new MDM client
  certificate/key container, and new EnterpriseMgmt task folder before calling
  the enrollment repaired.

### 2026-08-12 - Treat TA-F4798J4 as having a broken MDM certificate key, not an expired certificate

- Decision: Treat the current Intune enrollment on `TA-F4798J4` as
  cryptographically broken and requiring a supported clean re-enrollment or
  reprovisioning path. Do not treat additional Office reinstalls or WAM cache
  deletion as repairs for the Intune management channel.
- Status: Accepted
- Evidence type: proven from local endpoint evidence
- Rationale: The Intune MDM certificate exists and is valid through 2027, but
  its registered Microsoft Platform Crypto Provider key container
  `ConfigMgrEnrollment0` returns `0x80090016` (keyset does not exist). OMA-DM
  fails with `0x80072f9a`, and the Intune Management Extension fails to create
  the client-certificate TLS channel.
- Source or local evidence: `MDMDiagReport.zip` for `TA-F4798J4`, NCrypt event
  3, MDM sync/operational events, `IntuneManagementExtension.log`, and the MDM
  registry/certificate inventory.
- Recommended action: Validate the live state first, preserve BitLocker and TPM
  recovery material, compare the endpoint with Intune/Entra records, and then
  use the supported enrollment workflow selected for this domain-joined
  environment. Do not manually clear the TPM or delete enrollment registry and
  certificate material without a separately approved recovery procedure.

### 2026-08-12 - Keep the original ticket symptoms as separate causal tracks

- Decision: Do not claim that the broken MDM/Entra identity state caused the
  WINGAP idle connection failure or the Google-account-disabled message.
- Status: Accepted
- Evidence type: mixed; Microsoft identity failure is proven, WINGAP and Google
  causality are unproven
- Rationale: Modern Standby idle transitions are recorded and can suspend a
  desktop application's active SQL session, but the archive contains no WINGAP
  runtime error and no Ethernet link loss during the idle sessions. The archive
  also contains no Google Workspace account-status evidence. Conversely, WAM,
  PRT, device-token, and Intune certificate failures directly prove a Microsoft
  identity/management problem.
- Source or local evidence: `system.evtx`, `application.evtx`, AAD operational,
  User Device Registration, MDM sync, and NCrypt logs in the same report.
- Recommended action: Repair/reprovision Microsoft device identity separately;
  collect a timestamped WINGAP reproduction with the database target and power
  report; have a Google administrator verify the Google account state if that
  message recurs.

### 2026-08-06 - Treat Intune AllowMUUpdateService as the proven cause

- Decision: On `TA-PF47WVTR`, treat the Intune/MDM value
  `Update/AllowMUUpdateService=1` as the cause of Microsoft Update registration
  and the Microsoft Update scan observed alongside WSUS.
- Status: Accepted
- Evidence type: proven from local endpoint evidence and Microsoft documentation
- Rationale: The WSUS GPO applied successfully and WSUS was reachable and
  scanned successfully. PolicyManager event 813 records MDM setting
  `AllowMUUpdateService` to 1, and WindowsUpdate.log records a federated search
  against Microsoft Update, DCat Flighting, and WSUS with distinct results.
- Source or local evidence:
  - First-capture archive for `TA-PF47WVTR`, collected 2026-08-06 09:16-09:19.
  - `MDM/PolicyManager-Provider-Provenance.csv` and DeviceManagement event 813.
  - `WindowsUpdate/WindowsUpdate.log` service GUIDs and scan results.
  - https://learn.microsoft.com/en-us/intune/device-updates/windows/ref-update-ring-settings
  - https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- Recommended action: In Intune, locate the assigned policy with **Microsoft
  product updates = Allow**. If strict WSUS-only behavior is required, set it to
  **Block** or remove the assignment, synchronize policy, and then remove the
  Microsoft Update service GUID using Microsoft's documented command because
  reverting the CSP alone does not unregister the service.

### 2026-08-06 - Preserve the distinction between source registration and class routing

- Decision: Do not describe the endpoint as simply "using Microsoft Update
  instead of WSUS."
- Status: Accepted
- Evidence type: proven from local endpoint scan records
- Rationale: WSUS remains managed, registered, reachable, and actively scanned.
  Microsoft Update supplied three Microsoft product/security updates, while
  DCat Flighting supplied separate driver/flight metadata. No evidence in the
  capture shows a Windows cumulative quality update bypassing WSUS.
- Source or local evidence: `WindowsUpdate/WindowsUpdate.log` in the first
  `TA-PF47WVTR` capture.
- Recommended action: Define explicit scan-source policy for all four update
  classes if Hall County wants deterministic routing, and judge actual source
  by service-specific scan/install events rather than `IsDefaultAUService`.

### 2026-08-05 - Preserve pre-test policy state

- Decision: The collector is read-only with respect to Group Policy, MDM policy,
  Windows Update scans, and update-service registration.
- Status: Accepted
- Evidence type: recommendation based on diagnostic integrity
- Rationale: Running `gpupdate`, initiating a scan, or modifying service
  registration before evidence capture could erase the timing condition being
  investigated.
- Source or local evidence: The affected devices show different Update Agent
  service-registration states during Autopilot and post-OOBE processing.
- Recommended action: Run the collector before any remediation or manual update
  action.

### 2026-08-05 - Diagnose update source per update class

- Decision: Do not treat `IsDefaultAUService` as sufficient proof of the source
  used for feature, quality, driver, or other updates.
- Status: Accepted
- Evidence type: proven from Microsoft documentation
- Rationale: Modern Windows scan-source policies independently select Windows
  Update or WSUS for each update class.
- Source or local evidence:
  - https://learn.microsoft.com/en-us/windows/deployment/update/wufb-wsus
  - https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- Recommended action: Collect WSUS policy values, `UseUpdateClassPolicySource`,
  all four class-source values, PolicyManager provenance, and Update Agent
  service registration together.

## Disagreements

- None recorded.
