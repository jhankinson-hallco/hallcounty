# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-15 - Interactive Company Portal Execution Is Intentional

- Decision: `Rename_by_User` is intentionally interactive. Intune and Company
  Portal are distribution mechanisms, not silent execution requirements for this
  tool.
- Status: Accepted
- Evidence type: user direction
- Rationale: The user-facing department selection and credential prompt are the
  purpose of this package.
- Source or local evidence: Jeremy direction on 2026-06-15 and
  `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`.
- Recommended action: Keep the app in user context and pilot from Company Portal.

### 2026-06-17 - Interactive App Must Not Run In System Context

- Decision: The `Rename_by_User` Company Portal app must use Win32 app Install
  behavior `User`, not `System`.
- Status: Accepted
- Evidence type: deployed IME log evidence
- Rationale: System context launches in the machine session. WinForms
  `ShowDialog()` throws because the process is not running in UserInteractive
  mode, so the department picker and credential prompt can never appear.
- Source or local evidence:
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_Set-DeviceNameInteractive_Install.txt`
  logged the `ShowDialog()` non-interactive exception on 2026-06-17, and
  `AppWorkload.log` showed app id `aa0d246a-1715-462e-baea-898a567688af`
  launching `Win32AppInstaller in machine session` with install context
  `System`.
- Recommended action: Configure the portal app as User install behavior and use
  the v1.0.4 install command with `-STA`.

### 2026-06-17 - GUI Install Command Exception

- Decision: The interactive rename install command should omit
  `-NonInteractive` and use `-STA`.
- Status: Accepted
- Evidence type: implementation decision and local runtime test
- Rationale: `-NonInteractive` alone was not proven to cause the failure, but it
  is misleading for this GUI-based exception. `-STA` is the more explicit host
  mode for Windows Forms and native credential UI work.
- Source or local evidence:
  Local `powershell.exe -NonInteractive` test still returned
  `SystemInformation.UserInteractive=True`; local `powershell.exe -STA` test
  confirmed STA apartment state.
- Recommended action: Use
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -STA -File ".\Set-DeviceNameInteractive.ps1"`
  for install. Continue using `-NonInteractive` for uninstall.

### 2026-06-15 - Local Administrator Requirement Is Intentional

- Decision: Normal non-admin users are not expected to complete the process and
  should not see this app in Company Portal.
- Status: Accepted
- Evidence type: user direction
- Rationale: The local admin requirement is part of the access-control design.
- Source or local evidence: Jeremy direction on 2026-06-15 and the install
  script preflight check.
- Recommended action: Assign the app only to authorized administrators and keep
  the local-admin preflight check in the script.

### 2026-06-15 - Use Single Flexible Marker-Based Detection

- Decision: The interactive rename app writes
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DetectionMarkers\DeviceRenameInteractive.txt`
  after a successful rename command. The marker contains the selected prefix.
- Status: Accepted
- Evidence type: user direction and implementation
- Rationale: The selected department is runtime data, so detection cannot be one
  department-specific static rule. A single marker plus active/pending hostname
  validation supports all departments.
- Source or local evidence:
  `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  and `System Scripts\Device Rename\Rename_by_User\Detect.ps1`.
- Recommended action: Use `Detect.ps1` as the custom detection script for the
  Company Portal app.

### 2026-06-15 - Use Native Windows Credential UI

- Decision: Replace the custom WinForms password textbox with the native Windows
  credential UI through `credui.dll`.
- Status: Accepted
- Evidence type: code audit and implementation
- Rationale: This removes the script-owned password textbox and uses a
  Windows-owned credential prompt while preserving the interactive flow.
- Source or local evidence:
  `System Scripts\Device Rename\Rename_by_User\Set-DeviceNameInteractive.ps1`
  v1.0.1.
- Recommended action: Keep credential collection in the native prompt unless a
  future security review requires another approved credential broker.

### 2026-06-15 - Uninstall Only Removes Detection Marker

- Decision: `Uninstall.ps1` removes only
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DetectionMarkers\DeviceRenameInteractive.txt`
  and does not attempt to rename the device back.
- Status: Accepted
- Evidence type: implementation
- Rationale: The Company Portal app is a one-shot administrative action. Reversing
  a device rename requires a new intentional rename workflow, not uninstalling
  the app metadata.
- Source or local evidence:
  `System Scripts\Device Rename\Rename_by_User\Uninstall.ps1`.
- Recommended action: Use `Uninstall.ps1` as the Intune uninstall command.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:
