# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-08-27 - Serial file gains an informational hostname line; detection narrowed to line 1

- Decision: Write-SerialFile (Install-SerialMarker.ps1 and
  PDQ\Install-SerialMarker-PDQ.ps1) now writes two lines to
  "Serial - <SERIAL>.txt": the serial on line 1 (unchanged) and
  `$env:COMPUTERNAME` on line 2, informational only. Detect.ps1 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1's Test-SerialFileCurrent were changed
  to validate only line 1 against the current serial, instead of the entire
  raw file content.
- Status: Accepted and implemented in v1.0.5
- Evidence type: proven by Windows PowerShell 5.1 execution - the coupling
  was identified before implementing, not discovered as a bug afterward
- Rationale: Jeremy asked for the hostname as a second line, purely
  informational, with no detection script changes. That request is
  technically incompatible with the code as it stood: Test-SerialFileCurrent
  compared the file's entire trimmed raw content to the serial
  (`$Content.Trim() -eq $CurrentSerial`), which can never match once the
  file has a second line - every device would show NotDetected permanently.
  Flagged this to Jeremy before implementing; he chose the minimal fix
  (compare line 1 only) over the alternative (leave the txt file untouched
  and put the hostname in the marker file instead). The line-1 comparison
  preserves the exact same detection criteria as before for a
  now-legitimately-multi-line file - no new detection logic was added.
- Source or local evidence: isolated Windows PowerShell 5.1 reproduction of
  Write-SerialFile against a real machine's serial and hostname, followed by
  Test-SerialFileCurrent against the resulting two-line file (matched) and a
  wrong serial (correctly rejected).
- Recommended action: any future addition to this file (a third line, etc.)
  must go through the same check - does Test-SerialFileCurrent's comparison
  still work against the new format - before assuming "informational only"
  requires no detection change. Do not revert to a whole-file content
  comparison in Detect.ps1 or the PDQ marker script.

### 2026-08-26 - Serial identification file location

- Decision: Write "Serial - <SERIAL>.txt" to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles`, as
  originally requested, rather than routing it to `ScriptFiles`.
- Status: Accepted
- Evidence type: proven from code (live, in-production sibling script)
- Rationale: `reference_intune_paths.md` classified this exact path as
  legacy at the start of this task. Jeremy pushed back and pointed at
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`
  (v1.0.3, last revised 2026-07-01, actively deployed), which writes its
  own device-identification file, `DevicePrefix.txt`, to this identical
  path today. A currently-deployed production script outweighs a stale
  reference-doc classification. See the companion disagreement entry
  below and the correction now recorded in `reference_intune_paths.md`
  and `AGENTS.md`.
- Source or local evidence:
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`,
  lines 12-13 (DESCRIPTION) and 113 (`$script:PrefixFilePath`).
- Recommended action: treat `IntuneFiles` as the standard location for
  simple per-device identification text files consumed directly by a
  paired `Detect.ps1`; keep using `ScriptFiles` for durable script data,
  helper scripts, and config files that are not themselves the detection
  artifact.

### 2026-08-26 - Detection method: versioned marker vs. wildcard file match

- Decision: Detect.ps1 recomputes the device's current serial number and
  checks it against a versioned marker
  (`AppMarkers\SerialMarker.marker`, `Version=`/`Serial=` lines) rather
  than doing a wildcard match against `Serial - *.txt` in the target
  folder.
- Status: Accepted (Jeremy's explicit choice between the two options
  presented)
- Evidence type: recommendation, accepted by Jeremy
- Rationale: a wildcard match cannot tell a current serial file from a
  stale one left behind by a prior motherboard replacement or re-image -
  it would report "installed" even when the on-disk file names the wrong
  serial. Recomputing the serial at detection time and comparing it
  against the marker's `Serial=` value is self-correcting: if the
  hardware serial ever changes, detection correctly reports NotDetected
  and Intune reinstalls, which also cleans up the stale txt file (the
  install script deletes any pre-existing "Serial - *.txt" file before
  writing the new one). This also lines up with the shop-wide versioned
  marker policy (2026-08-20) already used by every other project.
- Source or local evidence: `reference_intune_code_patterns.md` "Marker
  Version Comparison + PDQ Marker Handoff Pattern"; `reference_intune_detection.md`
  detection check order.
- Recommended action: the on-disk "Serial - <SERIAL>.txt" file is
  informational only (human-readable identification), not part of the
  detection logic. Do not add wildcard-based detection later without
  revisiting this decision - it reintroduces the stale-file blind spot.

### 2026-08-26 - Validate each serial provider before accepting or falling back

- Decision: Normalize and validate `Win32_BIOS.SerialNumber` first; if that
  candidate is blank, a known placeholder, all-zero after punctuation removal,
  or fewer than four meaningful alphanumeric characters, query and independently
  validate `Win32_ComputerSystemProduct.IdentifyingNumber`.
- Status: Accepted and implemented in v1.0.1
- Evidence type: proven by Windows PowerShell 5.1 branch simulation
- Rationale: v1.0.0 queried the fallback only when the raw BIOS value was blank
  or the BIOS query threw. A nonblank placeholder such as
  `To Be Filled By O.E.M.` was rejected after the fallback opportunity had
  already passed. The v1.0.1 branch matrix proves valid fallback behavior for
  blank, placeholder, N/A, hyphenated all-zero, and too-short BIOS candidates
  across all four serial readers.
- Recommended action: keep `ConvertTo-NormalizedSerial` and
  `Get-DeviceSerialNumber` behavior synchronized across Intune install,
  detection, PDQ install, and PDQ marker scripts on every future revision.

### 2026-08-26 - Uninstall success requires verified artifact removal

- Decision: Intune and PDQ uninstall scripts must attempt every serial/marker
  cleanup item, verify removal, and return a non-zero code when an intended
  artifact remains. Idempotent already-absent state remains success.
- Status: Accepted and implemented in v1.0.1
- Evidence type: proven by code and locked-file execution tests
- Rationale: v1.0.0 swallowed removal failures and always exited 0. A remaining
  current Intune marker could still satisfy Detect.ps1, making the reported
  uninstall success false. In v1.0.1, locked-marker tests return 1603 while
  continuing to remove the other marker and serial file; serial-only cleanup
  failure returns 1602 and unexpected failure returns 1699.
- Recommended action: preserve verified cleanup and non-zero failure semantics;
  do not restore best-effort exit-0 behavior for artifacts this uninstall is
  responsible for removing.

### 2026-08-26 - Clean Intune source is generated, not maintained as duplicates

- Decision: Keep canonical Intune scripts at the project root and PDQ scripts in
  the required `PDQ` subfolder. Generate a clean, unique Intune-only staging
  folder with New-SerialMarkerIntuneSource.ps1 rather than moving canonical
  files or maintaining persistent duplicate script copies.
- Status: Accepted and implemented
- Evidence type: proven from workspace layout and staged SHA256 comparison
- Rationale: Microsoft content preparation includes the full selected source
  tree, so selecting the project root would also package the PDQ subtree.
  Moving the canonical scripts would break the established project path, while
  duplicate maintained copies would add version-drift risk. The staging utility
  derives the package version from the install script, copies only Install,
  Uninstall, and Detect, verifies exactly three files, and does not build an
  `.intunewin`.
- Recommended action: manually package only from a freshly generated staging
  folder. Never select the Serial Marker project root as the Intune source.

### 2026-08-26 - Remove marker pre-deletion instead of reordering it

- Decision: In Install-SerialMarker.ps1 and PDQ\Set-SerialMarkerMarker-PDQ.ps1,
  remove the explicit pre-deletion of the current marker entirely rather than
  just moving it later in the sequence. Both scripts now rely solely on the
  existing Set-Content -Force (temp file) and Move-Item -Force (final path)
  calls to overwrite the old marker atomically.
- Status: Accepted and implemented in v1.0.2
- Evidence type: proven by live simulation (isolated scratch-path
  reproduction, not mocked) plus a direct test confirming Move-Item -Force
  overwrites an existing destination file in a single step
- Rationale: the prior v1.0.1 remediation added an explicit "invalidate old
  marker before changing state" step, intended as a safety measure. Live
  simulation showed the opposite effect: on an already-Detected device, a
  transient failure in an unrelated step (e.g. a locked serial file) deleted
  the valid marker and never restored it, producing a false NotDetected
  until the next successful Intune retry - with no compensating benefit,
  since Detect.ps1 already independently recomputes the live serial and
  compares it to the marker's Serial= field regardless of what the old
  marker said. A reordered version (delete only after the new content is
  ready) was also verified to close the same window, but full removal is
  simpler and carries zero residual risk, since Move-Item -Force (confirmed
  directly: old content in, new content out, single step, no manual
  pre-delete needed) already provides the same atomic-replace guarantee.
- Source or local evidence: isolated reproduction of Install-SerialMarker.ps1's
  MAIN sequence against scratch paths, run under Windows PowerShell 5.1;
  standalone Move-Item -Force overwrite test.
- Recommended action: do not reintroduce a pre-delete-then-write pattern for
  either marker tier. If a future script needs to invalidate evidence before
  a multi-step change, gate the deletion on having already confirmed every
  earlier step succeeded - never delete authoritative evidence before the
  step that depends on it has been proven to work.

### 2026-08-26 - Distinct exit code when both uninstall cleanup tiers fail

- Decision: Uninstall-SerialMarker.ps1 and PDQ\Uninstall-SerialMarker-PDQ.ps1
  now exit 1604 when both the serial-file cleanup and the marker cleanup fail
  in the same run, instead of always surfacing 1603 (marker) and silently
  subordinating the file-cleanup failure.
- Status: Accepted and implemented in v1.0.2
- Evidence type: recommendation (not a functional defect - both failures were
  already fully logged; this only affects what a bare exit code communicates
  without opening the text log)
- Rationale: marker-cleanup failure correctly takes priority when only one
  tier fails (a leftover marker can falsely satisfy detection; a leftover txt
  file is cosmetic since Detect.ps1 never reads it) - that prioritization is
  unchanged. The new code only covers the case where an admin reading
  AppWorkload.log's exit code alone would otherwise not know the file tier
  also failed.
- Recommended action: keep 1604 reserved for "both tiers failed" on this app;
  do not repurpose it.

### 2026-08-26 - Exact serial file is required alongside marker detection

- Decision: Detect.ps1 must require exactly one `Serial - *.txt` artifact, and
  that file's exact name and trimmed content must match the current normalized
  hardware serial before either the Intune or PDQ marker can satisfy detection.
  Marker Status must also equal `Success`.
- Status: Accepted and implemented in v1.0.3
- Evidence type: proven by Windows PowerShell 5.1 failure-path execution
- Rationale: marker-only v1.0.2 detection returned `Detected` after a locked
  stale file made the install return 1602 and prevented creation of the current
  file. The standalone PDQ marker step could likewise create valid detection
  evidence with no serial directory or file. Exact-file validation closes both
  false positives without using a wildcard match as the success condition; the
  wildcard enumeration is used only to reject duplicate/stale extras.
- Recommended action: preserve exact single-file/name/content validation in
  Detect.ps1 and the PDQ marker prerequisite on every future revision.

### 2026-08-26 - Compare filename, not full path, in Test-SerialFileCurrent

- Decision: In both copies of Test-SerialFileCurrent (Detect.ps1 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1), compare the matched file's `.Name`
  against the expected filename (`Split-Path -Leaf`) instead of comparing
  `.FullName` against the Join-Path-built expected path.
- Status: Accepted and implemented in v1.0.4
- Evidence type: proven by Windows PowerShell 5.1 execution - the fragility
  was independently discovered while verifying the v1.0.3 fix, not
  hypothesized
- Rationale: `Get-ChildItem`'s `.FullName` is resolved by the filesystem and
  is not guaranteed to match a manually constructed path string
  byte-for-byte in every environment. This was reproduced directly: with the
  scratch test root under `%TEMP%` (which resolves to an 8.3 short-path
  alias, e.g. `JHANKI~1`, in this environment) while `Get-ChildItem.FullName`
  returned the long form, the exact-file check spuriously failed even though
  the correct file existed with correct content. The literal production path
  (`C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles`) never
  triggers this because none of its components are long enough for 8.3
  aliasing, so this was never a live production bug - but the comparison
  pattern itself was fragile. The `.Name`-based comparison is verified
  immune to this: the same test suite that failed under the old comparison
  passes under the new one even when the scratch root is deliberately placed
  under `%TEMP%`.
- Source or local evidence: isolated Windows PowerShell 5.1 reproduction,
  first with `%TEMP%` (reproduced the failure), then with a fixed root
  (confirmed root cause), then re-run against the `.Name`-based fix with
  `%TEMP%` restored (confirmed the fix holds under the adversarial case).
- Recommended action: prefer comparing filenames over full paths when the
  directory is already fixed by a `-LiteralPath` argument elsewhere in the
  same check. Do not reintroduce a `.FullName` string-equality comparison
  here.

### 2026-08-26 - PDQ marker pre-removal occurs after temp verification

- Decision: Set-SerialMarkerMarker-PDQ.ps1 writes and verifies its temporary
  marker first, then explicitly removes and verifies removal of the current
  final PDQ marker immediately before moving the temp marker into place.
- Status: Accepted and implemented in v1.0.3
- Evidence type: proven by Windows PowerShell 5.1 locked-file and retry tests
- Rationale: this ordering satisfies the ecosystem rule requiring a clean
  pre-removal rather than silent overwrite, while avoiding the earlier v1.0.1
  behavior that deleted valid evidence before unrelated prerequisites were
  proven. When the existing marker was locked, the step returned 1 and preserved
  its old content; after unlock, retry completed the replacement successfully.
- Recommended action: retain the prepare/verify/remove/move ordering. Do not
  pre-delete the final marker before serial-file and temporary-marker validation.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### 2026-08-26 - Marker-only detection does not prove the serial-file end state

- Prior decision: treat `Serial - <SERIAL>.txt` as informational only and use
  only the versioned marker plus live serial comparison for detection, because
  a wildcard file match could accept a stale serial file.
- Disagreement: the wildcard objection is valid, but marker-only detection is
  not the only alternative. A fresh Windows PowerShell 5.1 reproduction against
  v1.0.2 locked a stale `Serial - OLD999.txt`, seeded a valid current marker for
  serial `ABC123`, and ran the actual serial-write and detection functions. The
  write failed, `Serial - ABC123.txt` was absent, the stale file and marker
  remained, and Test-MarkerCurrent returned `Detected`. The marker therefore
  does not prove the script's primary file artifact exists or is correct.
- Evidence type: proven by current code and isolated Windows PowerShell 5.1
  execution.
- Recommended action: retain the marker/version/live-serial checks, then also
  require the exact `Serial - <CurrentSerial>.txt` path to exist and contain the
  same normalized serial. Do not use a wildcard as the success condition. This
  preserves the original stale-file protection while closing the demonstrated
  false-positive path.

### 2026-08-26 - PDQ overwrite decision conflicts with the governing standard

- Prior decision: v1.0.2 intentionally removed explicit pre-deletion from
  Set-SerialMarkerMarker-PDQ.ps1 and relies on a verified temporary file plus
  `Move-Item -Force` to replace the destination.
- Disagreement: regardless of the operational merits of that approach, the
  current ecosystem-wide AGENTS.md and reference_intune_code_patterns.md still
  require every PDQ companion marker script to remove a pre-existing marker
  before writing the new one. The v1.0.2 code and its own DESCRIPTION now also
  disagree with each other. A direct overwrite test proves the resulting
  content, but does not by itself prove the stronger claim that the replacement
  is atomic to every observer.
- Evidence type: proven conflict between current code, project decision, script
  DESCRIPTION, and governing local documentation; atomicity concern is an
  unproven implementation claim.
- Recommended action: Jeremy should choose one durable policy. Either restore
  verified pre-removal in the PDQ marker script, or explicitly revise the shared
  ecosystem rule/template to permit verified temp-file replacement and document
  its failure semantics. Do not leave a project exception implicit.
- Resolved: superseded by "PDQ marker pre-removal occurs after temp
  verification" (v1.0.3, below) - Jeremy's chosen resolution restores explicit
  pre-removal (satisfying the ecosystem template) but defers it until after the
  temp marker is written and verified, minimizing the evidence gap versus the
  v1.0.1 behavior this disagreement was never actually about. This entry is
  kept for its evidence trail; do not treat it as still open.

### 2026-08-26 - IntuneFiles classified as legacy in reference_intune_paths.md / AGENTS.md

- Prior finding: `reference_intune_paths.md` and `AGENTS.md` both listed
  `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles` as a
  legacy path, with `ScriptFiles` as "the" current replacement, implying
  no new script should write there.
- Disagreement: that classification does not match current live
  practice. `Rename-Device-System.ps1` (Device Rename project), last
  revised 2026-07-01 and actively deployed, writes `DevicePrefix.txt` to
  this exact path as its detection-file location. It was not flagged or
  migrated away from this path in its most recent change log entry
  (01/07/2026), meaning the path was still considered correct as of that
  date - well after the reference doc's own 2026-08-20 marker-policy
  update round.
- Evidence type: proven from code (live, dated, in-production script)
- Supporting evidence:
  `System Scripts\Device Rename\All_In_One\Rename-Device-System.ps1`
  lines 12-13, 51-64 (.NOTES / CHANGE LOG), 113.
- Recommended action: corrected `reference_intune_paths.md` (moved
  `IntuneFiles` out of the legacy table into the current-routes table,
  with a clarifying note distinguishing its purpose from `ScriptFiles`)
  and `AGENTS.md` (removed it from the inline legacy list, added the same
  clarifying note) on 2026-08-26. Future audits should treat `IntuneFiles`
  as current for device-identification text files, not legacy, unless
  new evidence shows it has actually been migrated away from across the
  fleet.
