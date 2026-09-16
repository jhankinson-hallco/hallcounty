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

### 2026-06-12 - Use Command-Line Prefix In All_In_One Rename App

- Decision: The All_In_One rename app receives the department prefix from the
  Intune install command with `-Prefix` and does not read the prefix file as an
  input source.
- Status: Accepted
- Evidence type: user direction and implementation
- Rationale: This removes the DevicePrefixApp dependency ordering problem while
  preserving per-department assignment control in Intune.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`.
- Recommended action: For each department app, use an install command such as
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Rename-Device-System.ps1 -Prefix "AD"`.

### 2026-06-12 - Write Prefix File For Detection, Not As Install Input

- Decision: The All_In_One install script writes and verifies
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\DevicePrefix.txt`
  before attempting rename, but uses the command-line prefix for target-name
  construction.
- Status: Accepted
- Evidence type: user direction and implementation
- Rationale: The prefix file remains useful as detection state while avoiding a
  race where the rename app waits for a separate prefix app to create it.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`
  `Get-ResolvedDevicePrefix` and `Write-PrefixFile`.
- Recommended action: Keep the prefix file path aligned with detection scripts
  and do not reintroduce prefix-file input fallback unless a specific rollback
  plan is accepted.

### 2026-06-12 - Combined Detection Requires Prefix File And Computer Name

- Decision: Each All_In_One custom detection script must verify both the expected
  prefix file content and the current computer name derived from BIOS serial.
- Status: Accepted
- Evidence type: user direction and implementation
- Rationale: Prefix-file-only detection can false-pass before rename, and
  name-only detection does not prove the app used the intended department prefix
  state. Both checks together prove the intended end state.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Detect\Detect-AD.ps1` and generated
  `Detect\Detect-*.ps1` files.
- Recommended action: For each department app, upload the matching
  `Detect\Detect-<prefix>.ps1` custom detection script.

### 2026-06-12 - AD OU-Derived Prefix Is Not Viable For White Glove

- Decision: Do not derive the department prefix from AD OU for this workflow.
- Status: Accepted
- Evidence type: user-provided environment constraint
- Rationale: During White Glove, devices are newly domain joined into a holding OU
  and are moved by hand later, so the OU at rename time is not the final
  department designation.
- Source or local evidence: Jeremy direction on 2026-06-12.
- Recommended action: Keep department prefix assignment in Intune app assignment
  and install command configuration.

### 2026-06-15 - Validate Prefix Inside Script Body

- Decision: The All_In_One install script accepts `-Prefix` as a plain string and
  validates it inside the main script flow instead of using top-level
  `[Parameter(Mandatory)]` or `[ValidatePattern()]` attributes.
- Status: Accepted
- Evidence type: code audit and implementation
- Rationale: Top-level parameter binding failures occur before script-authored
  logging is available. In Intune/White Glove, missing or malformed portal
  arguments should use the logged 2105 prefix error path for easier triage.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1` v1.0.2.
- Recommended action: Keep deployment-input validation inside the script body for
  this package class unless a future design provides an equally reliable logging
  path for binding failures.

### 2026-06-22 - WGDevice01 PZ Failure Was Wrong Entrypoint, Not Rename Script Failure

- Decision: Treat the 2026-06-22 WGDevice01 PZ White Glove failure as a portal
  command / package entrypoint mismatch. The All_In_One
  `Rename-Device-System.ps1` did not execute.
- Status: Accepted
- Evidence type: proven from logs, local source, and local PowerShell
  reproduction.
- Rationale: The All_In_One source uses `Rename-Device-System.ps1 -Prefix "PZ"`.
  The deployed app policy instead ran
  `powershell.exe -ExecutionPolicy Bypass -File .\Set-DevicePrefix.ps1 -Prefix "PZ"`
  with `SetUpFilePath` also set to `Set-DevicePrefix.ps1`. The All_In_One source
  folder does not contain `Set-DevicePrefix.ps1`. IME launched PowerShell from
  the extracted cache and received `lpExitCode 4294770688` (`0xFFFD0000`, signed
  `-196608`), which was reproduced locally by running PowerShell with a missing
  `-File` target.
- Source or local evidence: `F:\Logs\WGDevice01\AppWorkload.log` line 2002 shows
  the wrong command, line 2003 shows the IMECache working directory, lines
  2012-2017 show immediate failure with `lpExitCode 4294770688`, and line 2030
  marks `Device Rename - PZ - White Glove` as ESP Error. Local source inventory
  under `System Scripts\Device Rename\All_In_One` contains
  `Rename-Device-System.ps1` and `Detect\Detect-PZ.ps1`, not
  `Set-DevicePrefix.ps1`.
- Recommended action: Configure each All_In_One department app to use:
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Rename-Device-System.ps1 -Prefix "<PREFIX>"`.
  For PZ, use `-Prefix "PZ"` and upload/select `Detect\Detect-PZ.ps1`. If the
  portal setup file still shows `Set-DevicePrefix.ps1`, rebuild/re-upload from
  the correct All_In_One source. Add `2107 = Retry` before retesting.

### 2026-07-01 - Exact Computer Name Is The Authoritative No-Run State

- Decision: Every All_In_One department detector must return exit 0 plus STDOUT
  immediately when the current computer name exactly equals the target name
  calculated from that detector's hardcoded prefix and the normalized serial.
  Prefix-file absence, content, or other package state must not override this
  result.
- Status: Accepted; supersedes the success criteria in the 2026-06-12 combined
  detection decision.
- Evidence type: user direction, proven prior control flow, and local Windows
  PowerShell 5.1 simulation.
- Rationale: A Required assignment does not install a Win32 app when custom
  detection reports installed. The old prefix-file-first ordering returned not
  detected on an already-correct device when `DevicePrefix.txt` was absent or
  mismatched, allowing the app to launch unnecessarily.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Detect\Detect-SO.ps1` v1.0.1 and the
  equivalent hard gate in all 31 department detectors. The simulated
  `SO-A1B2C3D4` case returned STDOUT and exit 0 while prefix-file access was
  mocked to throw if reached.
- Recommended action: Upload the matching v1.0.1 detection script to every
  existing department app. Rebuild the package manually before deploying
  `Rename-Device-System.ps1` v1.0.3 so the installer-side early exit is also in
  production.

### 2026-08-27 - Merge Serial Marker's identification write into the rename install script

- Decision: `Rename-Device-System.ps1` (v1.0.4) now writes a per-device
  identification file ("Serial - <SERIAL>.txt", serial on line 1, the new
  target computer name on line 2) and a versioned marker
  (`AppMarkers\SerialMarker.marker`) as a new STEP 10, immediately after
  `Rename-Computer` succeeds and before the STEP 11 reboot-required exit.
  This reuses the exact `$Serial` and `$TargetName` values the rename logic
  already computed - it does not call BIOS/CIM again and does not read
  `$env:COMPUTERNAME` (which would still show the pre-rename name at that
  point, since the rename does not take effect until reboot). No existing
  rename variable, function, exit code, or control flow was changed; the
  new code lives in a separately-labeled block using
  `SerialMarker`-prefixed names to avoid colliding with the rename script's
  own `$script:AppName`/`$script:AppVersion`/etc. The new step is wrapped in
  its own try/catch that only logs on failure (via the existing
  `Write-ErrorLog`) - it can never change this script's exit code or block
  the reboot.
- Status: Accepted and implemented (Jeremy's explicit request, 2026-08-27)
- Evidence type: user direction and implementation; verified by isolated
  Windows PowerShell 5.1 execution
- Rationale: Jeremy judged the standalone Serial Marker Win32 app and this
  rename app as redundant deployment surface for the same underlying need
  (stamp the device's serial and eventual hostname), and pointed out that
  doing it here produces a MORE accurate result than the standalone app
  could: at rename time, the true target hostname is already known and
  about to be applied, whereas the standalone app (or this same write done
  before rename) could only read the current, soon-to-be-stale
  `$env:COMPUTERNAME`. Jeremy explicitly declined to add this to Intune
  detection for this app: the txt file/marker write is simple and
  low-failure-probability, and adding it as a second or third detection
  criterion for one app increases the chance of a false negative (any one
  failing check makes the whole app, including the disruptive rename +
  reboot, look "not installed" and retry) without a commensurate benefit.
  This mirrors the Serial Marker project's own detection design principle
  (marker/file existence is informational, not a gate) but goes further:
  here, none of it is checked at all, only the rename outcome is.
- Source or local evidence: isolated Windows PowerShell 5.1 reproduction of
  the injected STEP 10 functions against scratch paths, confirming (a) the
  written file's second line is the TARGET name, not the live
  `$env:COMPUTERNAME`, and (b) a simulated failure inside the injected
  try/catch (blocked marker directory) does not propagate past that block -
  the surrounding step still completes and the script would still reach
  `exit 3010` unconditionally.
- Recommended action: any future change to the rename flow's own serial or
  name computation (`Get-DeviceSerial`, `Get-TargetName`) automatically
  flows into what this step writes, since it consumes those same values -
  no separate synchronization is needed. Do not make this step's success a
  condition of Intune detection for this app without revisiting this
  decision. A related open question - whether the standalone Serial Marker
  Win32 app should still be deployed alongside this merged behavior, given
  both would now write to the same marker/file during the same technician
  phase - was raised to Jeremy but not resolved as part of this change; see
  Active Risks in the handoff.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:

### 2026-08-27 - Reusing Rename Serial Does Not Preserve Serial Marker Compatibility

- Prior finding: The 2026-08-27 merge decision states that reusing the rename
  flow's `$Serial` means future serial changes flow automatically and no separate
  synchronization is needed.
- Disagreement: The two projects currently define different serial contracts.
  Reusing rename `$Serial` preserves hostname consistency, but it does not
  preserve compatibility with Serial Marker v1.0.5 files or detection.
- Evidence type: proven from code and Windows PowerShell 5.1 execution of the
  actual function bodies with mocked CIM values.
- Supporting evidence: Rename removes every non-alphanumeric character and only
  falls back when BIOS is blank. Serial Marker preserves hyphens, rejects known
  placeholders and all-zero values, then tries the product identifier. The
  tested inputs `ABC-1234`, `To Be Filled By O.E.M.`, and `0000-0000` all
  produced different outputs between the two projects.
- Recommended action: Do not alter rename name computation. Add a separately
  named Serial Marker resolver that follows the standalone v1.0.5 rules and use
  its result only for the serial filename, line 1, and marker `Serial=` value;
  continue using `$TargetName` for line 2.

### 2026-08-27 - Rename-Only Success Paths Do Not Guarantee Merged Artifacts

- Prior finding: The 2026-08-27 merge decision treats the new serial write as a
  replacement for the same underlying need while deliberately leaving detection
  rename-only.
- Disagreement: Rename-only detection can be a valid policy, but the current
  installer also exits before the writer when the name is already correct. As a
  result, the merged behavior cannot backfill artifacts on existing correctly
  named devices and cannot by itself replace the standalone app fleet-wide.
- Evidence type: proven from installer and detector control flow.
- Supporting evidence: all 31 detectors return installed at the exact-name gate;
  the installer has the same early success exit at lines 586-587; the marker
  calls occur later at lines 656 and 659.
- Recommended action: Invoke one shared, best-effort marker-write helper from
  both successful paths. Detection may remain rename-only if Jeremy explicitly
  classifies the artifacts as optional; otherwise use a separately scoped
  remediation/detection mechanism rather than making the disruptive rename app
  repeatedly fail detection.
