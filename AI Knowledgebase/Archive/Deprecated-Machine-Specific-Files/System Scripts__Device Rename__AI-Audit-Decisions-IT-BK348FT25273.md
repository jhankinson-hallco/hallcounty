# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-26 - White Glove Rename App Content And Command Must Match

- Decision: The Device Rename White Glove app must deploy content whose setup
  file and install command reference the same script. Do not pair
  `SetUpFilePath = Set-DevicePrefix.ps1` with an install command that invokes
  `.\Rename-Device-System.ps1`.
- Status: Accepted
- Evidence type: proven from logs and local reproduction
- Rationale: WGDevice01 failed because PowerShell could not find the script
  named in the install command. IME reported process exit `4294770688`
  (`0xFFFD0000`), which was reproduced locally by running PowerShell `-File`
  against a missing script.
- Source or local evidence:
  - `F:\Logs\WGDevice01\AppWorkload.log`: Device Rename app
    `27e63885-db83-4fb7-b69e-0477217f23a6` downloaded version 2 content, then
    ran `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe ... -File .\Rename-Device-System.ps1 -Prefix "TD"`.
  - Policy payload for that same app showed `SetUpFilePath` as
    `Set-DevicePrefix.ps1`.
  - IME recorded `lpExitCode 4294770688`, `EnforcementState = 5000`, and
    `EspAppInstallState = 4`.
- Recommended action: Correct the Intune app assignment/content so the TD
  White Glove app either uses the all-in-one `Rename-Device-System.ps1` content
  and setup file, or uses the `Set-DevicePrefix.ps1` command expected by the
  current content. Re-run White Glove after syncing the app.

### YYYY-MM-DD - <Decision Title>

- Decision:
- Status: Accepted / Rejected / Partially accepted / Superseded
- Evidence type: proven from code/docs/logs / likely inference / recommendation
- Rationale:
- Source or local evidence:
- Recommended action:

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:
