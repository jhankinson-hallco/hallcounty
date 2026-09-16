# AI-Audit-Decisions.md

## Durable Decisions

### 2026-08-12 - Scope cleanup to one proven Intune enrollment

- Decision: Require the expected computer name, enrollment GUID, MDM certificate
  thumbprint, key container, and Intune registry identity to match before any
  cleanup occurs.
- Status: Accepted
- Evidence type: proven from logs and registry evidence, plus recommendation
- Rationale: Windows contains many non-MDM enrollment keys. Broadly deleting the
  Enrollments tree could damage unrelated Windows provisioning authorities or
  Configuration Manager state.
- Source or local evidence: TA-F4798J4 post-reenrollment report identifies
  enrollment `7BB62591-9BE5-4C3B-9475-3EA0D2E486F7`, certificate
  `45330198FA983C78A09574F469DA3B373F404F69`, key container
  `ConfigMgrEnrollment0`, crypto provider `Microsoft Platform Crypto Provider`,
  ProviderID `MS DM Server`, and the Intune discovery URL.
- Recommended action: Abort on every identity mismatch and use audit-only mode
  before execution.

### 2026-08-12 - Preserve AD join and TPM state

- Decision: Do not call `Remove-Computer`, clear the TPM, remove BitLocker
  protectors, or delete raw TPM/KSP storage files.
- Status: Accepted
- Evidence type: recommendation based on environment design and recovery risk
- Rationale: The intended endpoint remains on-premises domain joined. Clearing
  the TPM or deleting provider storage is materially broader than removing the
  exact broken MDM key and can affect BitLocker, Windows Hello, and other keys.
- Source or local evidence: Hall County environment constraints and the
  TA-F4798J4 device-state report.
- Recommended action: Use certutil against only the named MDM key container. If
  it cannot be deleted, stop and reimage.

### 2026-08-12 - Keep user Entra registration as a supported user action

- Decision: Do not delete per-user WAM, TokenBroker, IdentityCache, or workplace
  registration registry data from the elevated machine cleanup script.
- Status: Accepted
- Evidence type: proven from Microsoft documentation and prior endpoint results
- Rationale: Microsoft Entra registered state is per user on Windows 10/11, and
  Microsoft directs the user to remove it through Access work or school. Direct
  cache deletion already failed to repair this endpoint and can further damage
  sign-in state.
- Source or local evidence:
  - https://learn.microsoft.com/en-us/entra/identity/devices/faq
  - https://learn.microsoft.com/en-us/windows/client-management/mdm-enrollment-of-windows-devices
- Recommended action: Have jtsmith disconnect the work/school connection in
  their own session before running the machine cleanup, then reconnect only
  after cleanup and reboot.

### 2026-08-12 - Treat direct cleanup as last-resort recovery

- Decision: Present the script as a guarded last-resort repair for the proven
  corrupt local state, not as a Microsoft-supported general unenrollment tool.
- Status: Accepted
- Evidence type: proven from Microsoft documentation and local endpoint evidence
- Rationale: Microsoft documents Access work or school Disconnect as the local
  unenrollment path and describes the cleanup Windows performs. It does not
  document arbitrary registry deletion as a normal administrative interface.
  TA-F4798J4 is an exception because that supported action left the old MDM
  account, scheduled tasks, certificate, recovery state, and IME identity.
- Source or local evidence:
  - https://learn.microsoft.com/en-us/windows/client-management/disconnecting-from-mdm-unenrollment
  - https://learn.microsoft.com/en-us/windows/client-management/mdm-enrollment-of-windows-devices
  - TA-F4798J4 post-reenrollment report
- Recommended action: Use audit-only mode first, preserve evidence, run the
  tool only against the exact known enrollment, and reimage if any safety or
  key-deletion verification fails.

### 2026-08-12 - Reset IME identity during the clean machine enrollment repair

- Decision: By default, uninstall the Intune Management Extension and move its
  residual Program Files and ProgramData directories into the protected backup
  before deleting its registry state.
- Status: Accepted
- Evidence type: proven from local logs plus Microsoft documentation
- Rationale: The surviving IME continued to authenticate with the deleted old
  Intune device ID and broken certificate. Microsoft documents that IME is
  installed automatically when an applicable Win32 app or PowerShell workload
  is assigned to a valid enrolled device.
- Source or local evidence:
  - TA-F4798J4 post-reenrollment IME logs
  - https://learn.microsoft.com/en-us/intune/app-management/deployment/win32
- Recommended action: Let a valid new Intune enrollment reinstall IME; expect
  assigned Win32 applications to be reevaluated.

## Disagreements

- None recorded.
