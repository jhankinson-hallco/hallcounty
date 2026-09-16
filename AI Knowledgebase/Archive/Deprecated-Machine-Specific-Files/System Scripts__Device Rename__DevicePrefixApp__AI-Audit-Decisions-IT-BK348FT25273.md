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

### 2026-06-10 - Store Prefix File Under IME IntuneFiles

- Decision: DevicePrefixApp writes
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`.
- Status: Accepted
- Evidence type: user direction and recommendation
- Rationale: The path is machine-wide and available to SYSTEM during White Glove.
  It also groups Intune helper files near IME-managed deployment context.
- Source or local evidence: `Set-DevicePrefix.ps1` v1.0.1 and `Detect.ps1` v1.0.1.
- Recommended action: Any consumer of `DevicePrefix.txt` must read the same path.

### 2026-06-10 - System Script Logs Use IME Logs Naming

- Decision: DevicePrefixApp install errors log to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_Set-DevicePrefix_Install.txt`.
- Status: Accepted
- Evidence type: user direction
- Rationale: Co-locating custom script logs with IME logs simplifies troubleshooting
  and collection.
- Source or local evidence: `Set-DevicePrefix.ps1` v1.0.1.
- Recommended action: If an uninstall script is added later, use
  `SCRIPT_Set-DevicePrefix_Uninstall.txt`.

### 2026-06-11 - Prefix Detection Must Match Each Cloned Package

- Decision: Every DevicePrefixApp clone must use a custom detection script whose
  `$script:ExpectedPrefix` matches the normalized prefix written by the install
  command, including the trailing hyphen.
- Status: Accepted
- Evidence type: proven from logs
- Rationale: The FM deployment installed successfully with `-Prefix "FM"` but the
  deployed detection script expected `TA-`, so post-install detection failed and
  ESP blocked with `0x87d1041c`.
- Source or local evidence: `Logs\_extracted\Fail_20260611-142426\Fail_20260611-142426\IMELogs\AppWorkload.log`
  lines 74, 469-480, 512-524; `EnrollmentStatusTracking.reg` shows
  `Win32App_be328425-2b8c-4d4c-86d5-c2d224178265_1` in state 4 with
  `ErrorHresult` `87d1041c`.
- Recommended action: For the FM package, use
  `Detect\Detect-FM.ps1`. For future clones, upload the matching
  `Detect\Detect-<prefix>.ps1` custom detection script and verify the deployed
  policy body in `AppWorkload.log` if ESP fails.

### 2026-06-11 - Store Department Detection Scripts Under Detect Folder

- Decision: Maintain one department-specific custom detection script per prefix
  under `DevicePrefixApp\Detect\Detect-<prefix>.ps1`, generated from
  `Inventory\Departments.csv`.
- Status: Accepted
- Evidence type: user direction and implementation
- Rationale: Intune custom detection scripts cannot consume the Win32 app install
  command arguments. A per-prefix detection file preserves exact-prefix accuracy
  while avoiding manual edits scattered across the package source root.
- Source or local evidence: `Inventory\Departments.csv`;
  `System Scripts\Device Rename\DevicePrefixApp\Detect\Detect-AD.ps1`;
  generated v1.0.3 `Detect\Detect-*.ps1` files.
- Recommended action: For each department app, set the install command prefix and
  upload the matching `Detect\Detect-<prefix>.ps1` custom detection script. When
  departments or prefixes change, update `Inventory\Departments.csv` and
  regenerate the detection files before portal updates.

### 2026-06-22 - PZ Prefix App Failed Before Set-DevicePrefix Could Run

- Decision: Treat the WGDevice01 2026-06-22 White Glove failure as a PZ
  DevicePrefixApp package/content or portal command/setup mismatch, not an Office
  failure, SentinelOne failure, or `Rename-Device-System.ps1` failure.
- Status: Accepted
- Evidence type: proven from logs plus local PowerShell exit-code reproduction;
  exact uploaded package contents were not available because IME cleaned the
  extracted cache.
- Rationale: IME successfully downloaded, validated, decrypted, and extracted app
  `f27099f8-7ce3-4e9f-a251-60333e598a6d` v3, then launched
  `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`
  from the IMECache working directory. The process exited immediately with
  `lpExitCode 4294770688` (`0xFFFD0000`, signed `-196608`). That matches the
  Windows PowerShell exit code produced when the script passed to `-File` does
  not exist, and no `SCRIPT_Set-DevicePrefix_Install.txt` script log was present.
- Source or local evidence: `F:\Logs\WGDevice01\AppWorkload.log` lines 1929-1960
  show content download/extraction, line 2002 shows the install command, line
  2003 shows the IMECache working directory, lines 2012-2017 show the immediate
  process result and unmapped `lpExitCode 4294770688`, and line 2030 marks
  `Device Rename - PZ - White Glove` as ESP Error.
- Recommended action: Rebuild and re-upload the PZ package from the correct
  `DevicePrefixApp` source root with `Set-DevicePrefix.ps1` at package root, set
  the portal install command to the documented SysNative PowerShell command with
  `-NoProfile` and `-NonInteractive`, upload `Detect\Detect-PZ.ps1`, and wait for
  or clear GRS before retesting.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:
