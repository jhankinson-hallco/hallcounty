# AI-Audit-Handoff.md

## Current State

- Project: Serial Marker
- Current version: 1.0.5
- Deployment type: Intune Win32 app + PDQ tandem
- Primary install script: Install-SerialMarker.ps1
- Detection: Detect.ps1 (exact single serial file + line-1 serial content +
  versioned marker + current-serial + Status=Success validation). Line 2 of
  the serial file (hostname) is informational only and is not validated.
- Uninstall: Uninstall-SerialMarker.ps1
- Package artifact: `Install-SerialMarker.intunewin` exists, but it is rejected
  for deployment. Read-only inspection found an HMAC-valid v1.0.4 payload with
  seven files: the three Intune scripts, the staging utility, and all three PDQ
  scripts. It was built from the project root instead of a clean source and is
  also stale against the current v1.0.5 scripts. Do not upload it.
- Clean package source: none currently exists for v1.0.5. The v1.0.3 staging
  root under `C:\Temp\IntunePackageSource\SerialMarker` is now stale (canonical
  scripts changed twice since). Regenerate with New-SerialMarkerIntuneSource.ps1
  before packaging.
- Audit status: a fresh Codex audit confirmed the normal v1.0.5 two-line write,
  line-1 detection, marker checks, version parity, PS 5.1 parsing, and encoding.
  One Medium failure-path mismatch was introduced by making the informational
  hostname mandatory to the writer but optional to detection. The prior Medium
  staging-helper defect remains. Two Low stale v1.0.4 references remain in PDQ
  DESCRIPTION prose. The prior Low version-governance gap is resolved by the
  synchronized v1.0.5 bump. Production deployment still requires correction of
  the Medium findings, a clean package rebuild, representative SYSTEM-context
  physical-hardware validation, and manual portal/PDQ configuration.

## Active Risks

- High / deployment artifact: the current
  `Install-SerialMarker.intunewin` embeds v1.0.4 and contains all seven project
  scripts, including the PDQ subtree and local staging utility. Its setup file
  is correctly named and its package HMAC validates, but it is both stale and
  sourced from the wrong folder. Move/delete it before packaging and rebuild
  manually from a freshly generated Intune-only v1.0.5 source. Never upload the
  current artifact.
- Medium / writer-detection contract: Install-SerialMarker.ps1 lines 203-217
  and PDQ\Install-SerialMarker-PDQ.ps1 lines 171-185 treat the informational
  hostname line as mandatory and fail if the written file has fewer than two
  lines. Detect.ps1 lines 182-187 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1 lines 139-144 intentionally accept any file
  whose first line is the correct serial, including a one-line file. Reproduced
  under Windows PowerShell 5.1 by removing `COMPUTERNAME` from the process
  environment on an already-current device: Write-SerialFile threw, left a
  one-line file, and the surviving v1.0.5 marker plus line-1 check still
  evaluated as Detected. Because the hostname is explicitly informational,
  prefer making an unavailable hostname non-fatal while keeping the serial line
  mandatory; otherwise detection must validate line 2 and accept hostname-change
  drift as a reinstall trigger.
- Portal "Additional return codes" for the Intune app has not been
  configured yet. Register 1601/1602/1603/1699 for install and
  1602/1603/1604/1699 for uninstall with the intended Failed/Retry mapping.
  This is a portal step, not a script change.
- No target-device validation has been performed yet for real BIOS/CSP serial
  retrieval, `IntuneFiles` permissions as SYSTEM, or the complete marker
  round-trip on physical hardware. Local tests used isolated paths and mocked
  CIM results.
- The actual PDQ package configuration/export was not present. Confirm the
  install package stops if Install-SerialMarker-PDQ.ps1 fails and runs
  Set-SerialMarkerMarker-PDQ.ps1 last. The marker step now independently rejects
  a missing, duplicated, or invalid serial file, but package order still needs
  to match the documented two-step design.
- PSScriptAnalyzer is not installed in the local PowerShell environments, so its
  lint pass could not be run. Parser and AST policy checks passed instead.
- Medium / packaging helper: New-SerialMarkerIntuneSource.ps1 creates its
  versioned destination before validating every required source and does not
  remove that destination in its catch path. An isolated Windows PowerShell 5.1
  run with only Install-SerialMarker.ps1 available returned 1 but left a
  legitimate-looking v1.0.4 staging directory containing that one file. A later
  manual packaging session could mistake it for a clean source. Prevalidate all
  required inputs before creating the destination and clean up only the
  destination created by the failed run.
- Low / documentation: PDQ\Install-SerialMarker-PDQ.ps1 line 9 and
  PDQ\Uninstall-SerialMarker-PDQ.ps1 line 9 still call their Intune counterpart
  v1.0.4 in DESCRIPTION prose. Their NOTES counterpart fields, executable
  versions, and changelogs correctly say v1.0.5, so this has no runtime effect.

## Recent Changes

- 2026-08-27: Codex independently audited the v1.0.5 hostname-line revision.
  The normal writer/detection and marker cases passed, but a Windows PowerShell
  5.1 failure-path reproduction proved the new mandatory-writer/optional-
  detection mismatch. Read-only inspection also proved the existing
  `.intunewin` contains stale v1.0.4 scripts plus the PDQ/staging files and must
  not be uploaded. Found two Low stale v1.0.4 PDQ DESCRIPTION references. No
  production script or decision file was changed; this handoff was updated.
- 2026-08-27: Added an informational hostname line to the serial file.
  Write-SerialFile (Install-SerialMarker.ps1 and
  PDQ\Install-SerialMarker-PDQ.ps1) now writes the serial on line 1 and
  `$env:COMPUTERNAME` on line 2 of "Serial - <SERIAL>.txt", with both lines
  verified after write. This is incompatible with Test-SerialFileCurrent's
  prior whole-file content comparison (Detect.ps1 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1), which would have permanently broken
  detection once the file had a second line - flagged to Jeremy before
  implementing; he chose the minimal fix (compare line 1 only, same
  detection criteria as before) over moving the hostname to the marker file
  instead. Bumped all six deployment scripts to v1.0.5; also resolves the
  prior Low version-governance finding as a side effect (all six are now
  past v1.0.4 regardless). Verified end-to-end in an isolated Windows
  PowerShell 5.1 harness using this machine's real serial and hostname: the
  two-line file writes and self-verifies correctly, Test-SerialFileCurrent
  still matches it, and a wrong serial is still correctly rejected. The
  Medium staging-helper defect (partial output on failure) from the prior
  Codex audit is unrelated and untouched by this pass.
- 2026-08-26: Codex independently re-audited the state after the two PDQ prose
  corrections. All 19 isolated deployment behavior cases passed under Windows
  PowerShell 5.1. Found one Medium staging-helper partial-output defect and one
  Low version-governance issue; no deployment script was changed.
- 2026-08-26: Fixed the two stale "v1.0.3" mentions in the DESCRIPTION prose
  of PDQ\Install-SerialMarker-PDQ.ps1 and PDQ\Uninstall-SerialMarker-PDQ.ps1
  (now v1.0.4, matching the already-correct dedicated version fields). Pure
  text correction, zero behavior change - no version bump applied. Verified
  both files still parse clean with BOM intact and confirmed zero remaining
  "v1.0.3" text anywhere in either file.
- 2026-08-26: Codex independently audited the post-Claude v1.0.4 state. No
  deployment script was changed. All 20 Windows PowerShell 5.1 isolated checks
  passed, including the reproduced 8.3-alias detection case, locked failure
  paths, all-tier cleanup, and complete Intune/PDQ lifecycles. Found two Low
  stale v1.0.3 references in PDQ description text; executable versioning is
  synchronized at v1.0.4.
- 2026-08-26: Applied the fix from the same-day Claude independent v1.0.3
  verification pass. Bumped all six deployment scripts to v1.0.4. In both
  copies of Test-SerialFileCurrent (Detect.ps1 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1), replaced a `.FullName` string-equality
  comparison with a `.Name` comparison, since `.FullName` is not guaranteed to
  match a manually built path string byte-for-byte in every environment
  (reproduced directly via 8.3 short-path aliasing during testing; never a
  live production risk given the literal hardcoded IME path, but a fragile
  pattern regardless). Added a cross-reference note closing the stale "PDQ
  overwrite conflicts with governing standard" disagreement entry, which a
  later decision had already resolved without saying so.
- 2026-08-26: Remediated all open findings and synchronized the six deployment
  scripts at v1.0.3. Detection now proves the exact single serial file/content
  and requires Status=Success. The PDQ marker step verifies the same artifact
  before writing evidence and explicitly removes the final marker only after its
  temporary replacement is verified. Both uninstallers now remove legacy marker
  tiers. Placeholder matching, paired-version documentation, and PDQ unexpected-
  error logging were corrected. Generated and hash-verified a clean v1.0.3
  Intune source; no `.intunewin` was built.
- 2026-08-26: Codex performed a second independent audit after Jeremy reported
  another Claude pass. The seven deployment/staging script hashes were unchanged
  from the prior Codex audit and no newer Claude remediation/audit record was
  present. The High false positive was reproduced again and extended to the PDQ
  marker-only path; two additional Low issues were found (Status ignored by
  detection and the PDQ install unexpected-error log code mismatch).
- 2026-08-26: Codex independently audited the post-Claude v1.0.2 state. No
  deployment script was changed. Normal isolated Intune/PDQ lifecycles and
  locked dual-tier uninstall failure handling passed, but the audit reproduced
  a High detection false-positive after a failed serial-file repair and found
  the additional policy/documentation issues recorded under Active Risks.
- 2026-08-26: Applied the fix from the same-day Claude independent audit.
  Bumped all six deployment scripts to v1.0.2. Removed the pre-deletion of
  the current marker in Install-SerialMarker.ps1 and
  PDQ\Set-SerialMarkerMarker-PDQ.ps1 (both now rely solely on the existing
  Set-Content -Force / Move-Item -Force atomic-overwrite pattern). Added a
  distinct 1604 exit code for "both cleanup tiers failed" and switched
  internal logging to named exit-code constants in both uninstall scripts.
- 2026-08-26: Remediated all Codex audit findings and synchronized the six
  deployment scripts at v1.0.1. Added New-SerialMarkerIntuneSource.ps1 v1.0.0
  and generated a verified clean Intune staging folder containing only Install,
  Uninstall, and Detect. No `.intunewin` was built.
- 2026-08-26: Codex completed an audit of all six scripts and updated this
  handoff only. No production script or decision file was changed.
- 2026-08-26: Initial build of all six scripts (Install/Detect/Uninstall
  at project root, plus PDQ tandem: Install-SerialMarker-PDQ.ps1,
  Set-SerialMarkerMarker-PDQ.ps1, Uninstall-SerialMarker-PDQ.ps1).

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1. (Done 2026-08-27 - all
  seven scripts, including the local staging utility, parsed clean.)
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files. (Done
  2026-08-27 - all seven confirmed BOM=True, NonASCII=0.)
- Resolve the hostname writer/detection contract described under Active Risks,
  then repeat the already-current failed-repair scenario and prove a non-zero
  writer result cannot be followed by Detected state.
- Run Install-SerialMarker.ps1 on a real device (or in an elevated local
  PowerShell session as SYSTEM via psexec) and confirm:
  - "Serial - <SERIAL>.txt" appears in
    `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles` with the
    serial exactly on line 1 and the install-time hostname on line 2.
  - `AppMarkers\SerialMarker.marker` is written with Version=1.0.5 and a
    Serial= line matching line 1 and the file name.
- Run Detect.ps1 immediately after and confirm exit 0 with STDOUT.
- Run Uninstall-SerialMarker.ps1 and confirm the txt file and all marker tiers
  (Intune AppMarkers, PDQ AppMarkers, and legacy paths) are gone, then
  re-run Detect.ps1 and confirm exit 1.
- Test on at least two different hardware manufacturers in the fleet
  (e.g. Dell and HP/Lenovo) to confirm Get-DeviceSerialNumber returns a
  real serial from Win32_BIOS on both, since the multi-manufacturer
  placeholder-rejection logic has not been exercised against real
  firmware yet - only reasoned about from known OEM placeholder strings.
- Confirm install, uninstall, detection required version, and PDQ marker
  script `$script:AppVersion` are synchronized (all currently 1.0.5).
- Confirm Intune portal settings (install/uninstall command, detection
  script upload, 32-bit setting = No, additional return codes) match the
  script comments before assigning to any group.
- No clean Intune source currently exists (see Current State). Generate and
  hash-verify one with New-SerialMarkerIntuneSource.ps1 before packaging. Do
  not select the project root while its `PDQ` subtree is present. Move/delete
  the rejected v1.0.4 `.intunewin` before rebuilding so it cannot be selected or
  nested into a later package.
- Import/configure the actual PDQ packages and confirm the install package runs
  Install-SerialMarker-PDQ.ps1 first, stops on that step's failure, and runs
  Set-SerialMarkerMarker-PDQ.ps1 last. No PDQ package export/configuration was
  present in the project for this audit.

## Latest Work Log

### 2026-08-27 - Codex independent audit of v1.0.5 hostname-line revision

- Files reviewed: all seven project scripts, the existing `.intunewin`, current
  handoff/decisions, and the required shared PowerShell 5.1, audit,
  methodology, encoding, version-sync, detection, context, path, marker, and
  targeted pitfall references.
- Files changed: AI-Audit-Handoff.md only. Production scripts and
  AI-Audit-Decisions.md were intentionally unchanged because this was an audit.
- Findings:
  - High / deployment artifact: the existing HMAC-valid `.intunewin` embeds
    Install-SerialMarker.ps1 v1.0.4 and seven total files, including the PDQ
    subtree and New-SerialMarkerIntuneSource.ps1. All six embedded deployment
    script hashes differ from current v1.0.5. Do not upload it.
  - Medium / runtime contract: both writers fail when the informational second
    line cannot be produced/verified, while both detection-side checks accept a
    one-line file. On an already-current device with `COMPUTERNAME` removed from
    the process environment, the actual Write-SerialFile function threw after
    leaving the serial-only file, while the actual serial-file and marker checks
    together still returned Detected.
  - Medium / existing staging utility: the previously proven partial-output-on-
    failure defect remains unchanged at lines 64-77.
  - Low / documentation: two PDQ DESCRIPTION lines still say counterpart
    v1.0.4; executable and dedicated counterpart version fields are v1.0.5.
- Validation performed independently under 64-bit Windows PowerShell
  5.1.26100.9168 Desktop:
  - all seven scripts parsed with zero errors, are UTF-8 BOM and ASCII-only,
    and contain no aliases, unapproved function verbs, Parameter/CmdletBinding
    attributes, or prohibited syntax; PSScriptAnalyzer remains unavailable;
  - all six executable version values are synchronized at 1.0.5;
  - the changed Write-SerialFile functions are text-identical across Intune and
    PDQ, and the changed Test-SerialFileCurrent functions are text-identical
    across Detect.ps1 and the PDQ marker step;
  - normal writer output contained exactly serial line 1 and hostname line 2;
    two-line detection passed, wrong/blank serial line and duplicate-file cases
    failed, and changed or missing hostname lines remained accepted as the
    recorded design requires;
  - current marker detection passed while wrong-serial and Status=Failed marker
    cases failed;
  - a locked existing serial file still blocked replacement and remained
    present for accurate failure evidence;
  - only the old v1.0.3 staging directory exists; no clean v1.0.5 source exists.
- Remaining risks/human decisions: decide the hostname failure contract,
  remediate the staging helper, correct the two prose references, generate a
  clean v1.0.5 source and manually rebuild, then complete physical SYSTEM,
  portal, and actual PDQ-package validation.

### 2026-08-26 - Codex follow-up audit after PDQ documentation correction

- Files reviewed: all seven current project scripts, current handoff/decisions,
  and the targeted shared PowerShell audit, development, detection, marker,
  path, encoding, version-sync, packaging, and known-pitfall references.
- Files changed: AI-Audit-Handoff.md only. The six deployment scripts, staging
  utility, and decision record were not changed because this turn was
  audit-only.
- Findings:
  - Medium: New-SerialMarkerIntuneSource.ps1 lines 64-77 create and populate the
    destination before all required sources are known to exist, while lines
    90-92 return failure without removing the partial destination. Reproduced
    under Windows PowerShell 5.1: exit=1, one versioned destination remained,
    and it contained only Install-SerialMarker.ps1.
  - Low: the two corrected PDQ DESCRIPTION lines changed their script files but
    the `.NOTES` versions, executable AppVersion assignments, and changelogs
    remain at v1.0.4. Runtime version parity is correct, but the edit conflicts
    with the shared requirement to bump each script revision.
  - No executable finding in the six install/detect/uninstall/PDQ deployment
    scripts.
- Validation performed independently under 64-bit Windows PowerShell
  5.1.26100.9168 Desktop:
  - all seven scripts parsed with zero errors, are UTF-8 BOM/ASCII-only, and
    contain no aliases, unapproved function verbs, advanced parameter
    decorations, or prohibited constructs;
  - all four ConvertTo-NormalizedSerial bodies remain identical;
  - the nine-case detection matrix passed, covering exact evidence, missing or
    bad files, duplicates, failed/missing Status, stale version, PDQ fallback,
    and authoritative stale Intune evidence;
  - the 8.3 short-path reproduction produced different constructed/enumerated
    full paths while detection correctly returned 0;
  - locked stale-file install returned 1602, preserved the old marker, and made
    detection return 1;
  - PDQ marker prerequisite, locked-marker failure, and retry cases passed;
  - both uninstallers removed every artifact normally and returned 1603 while
    removing all but a deliberately locked legacy marker in the failure case;
  - complete Intune lifecycle passed: install=0, detect=0, uninstall=0,
    detect-after=1;
  - complete PDQ lifecycle passed: install=0, marker=0, detect=0, uninstall=0,
    detect-after=1.
- Packaging check: the only persistent source remains
  `v1.0.3-20260826-151530-186`; all three hashes differ from canonical v1.0.4.
  No `.intunewin` was found. The isolated failed-staging reproduction was
  removed after testing.
- PSScriptAnalyzer remains unavailable.
- Remaining risks or human decisions: correct the two findings, generate and
  hash-verify a clean source for the resulting version, then complete the
  existing real SYSTEM/hardware, portal, and actual PDQ-package validation.

### 2026-08-26 - Codex independent audit of post-Claude v1.0.4

- Files reviewed: all seven current project scripts, the project handoff and
  decisions, and the unchanged shared audit/PowerShell/Intune standards already
  loaded for this project.
- Files changed: AI-Audit-Handoff.md only. No deployment or staging script was
  changed because this turn was audit-only.
- Findings:
  - No executable defect found.
  - Low / documentation only: PDQ\Install-SerialMarker-PDQ.ps1 line 9 and
    PDQ\Uninstall-SerialMarker-PDQ.ps1 line 9 still describe their Intune
    counterpart as v1.0.3. Each script's `.NOTES`, dedicated counterpart field,
    and executable version assignment correctly say v1.0.4.
- Validation performed independently under 64-bit Windows PowerShell
  5.1.26100.9168 Desktop:
  - all seven scripts parsed with zero errors; AST checks found no aliases or
    unapproved function verbs;
  - all seven scripts remain UTF-8 BOM and ASCII-only, with all six deployment
    scripts synchronized at v1.0.4;
  - all four ConvertTo-NormalizedSerial function bodies are byte-equivalent
    after newline normalization;
  - the detection matrix passed for exact Intune evidence, missing file, wrong
    content, duplicate file, failed/missing Status, stale version, PDQ fallback,
    and Intune authority over a valid PDQ marker;
  - the `%TEMP%` 8.3-alias reproduction confirmed constructed and enumerated
    full paths differ while v1.0.4 detection correctly returns 0, directly
    validating Claude's `.Name` fix;
  - a locked stale serial file made install return 1602, preserved the prior
    marker, left the current file absent, and made detection return 1;
  - the PDQ marker step returned 1602 without its serial-file prerequisite; a
    locked prior marker returned 1 while preserving it and leaving the verified
    temporary marker, then a retry returned 0 with valid v1.0.4 evidence;
  - both uninstallers removed serial files plus Intune, PDQ, temporary, and
    legacy marker tiers; each returned 1603 when one legacy marker was locked
    while still removing every other artifact;
  - complete isolated Intune lifecycle passed: install=0, detect=0,
    uninstall=0, detect-after=1;
  - complete isolated PDQ lifecycle passed: install=0, marker=0, detect=0,
    uninstall=0, detect-after=1.
- Packaging check: the only clean source remains
  `v1.0.3-20260826-151530-186`; all three staged script hashes differ from the
  current v1.0.4 canonical scripts, so it is stale. No `.intunewin` was found.
- PSScriptAnalyzer remains unavailable.
- Remaining risks or human decisions: regenerate a clean v1.0.4 Intune source
  before packaging, correct the two Low documentation references, then complete
  the existing real SYSTEM/hardware, portal, and actual PDQ-package validation.

### 2026-08-26 - Claude (Sonnet 5) independent audit and remediation of v1.0.3

- Files reviewed: all seven current project scripts as they stood at v1.0.3,
  re-read fresh rather than trusting the prior self-reported test log.
- Files changed:
  - Detect.ps1 -> v1.0.4 (Test-SerialFileCurrent now compares `.Name` instead
    of `.FullName`)
  - PDQ\Set-SerialMarkerMarker-PDQ.ps1 -> v1.0.4 (identical fix, same function)
  - Install-SerialMarker.ps1, Uninstall-SerialMarker.ps1,
    PDQ\Install-SerialMarker-PDQ.ps1, PDQ\Uninstall-SerialMarker-PDQ.ps1 ->
    v1.0.4 (version sync only, no logic changed)
  - AI-Audit-Handoff.md and AI-Audit-Decisions.md
- Validation performed independently under Windows PowerShell 5.1 (not reused
  from the Codex audit trail):
  - Extracted ConvertTo-NormalizedSerial from the actual v1.0.3 file and ran
    13 cases, including four hyphenated-placeholder variants
    (`System-Serial-Number`, `Not-Applicable`, `To-Be-Filled-By-O.E.M.`,
    `CHASSIS-SERIAL-NUMBER`) plus a legitimate hyphen-containing serial and a
    VMware VM serial - confirmed the hyphenated-placeholder bypass is fixed
    with no regression on real values.
  - Rebuilt the exact High-severity scenario from the audit trail (stale
    leftover serial file, no file for the live serial, marker still claiming
    match) in an isolated harness against the actual shipped Detect.ps1
    logic - confirmed NotDetected, closing the false positive.
  - While building a "known-good" sanity case for the same harness, hit a
    false "still broken" result caused by my own test root using `%TEMP%`,
    which resolves to an 8.3 short-path alias in this environment while
    `Get-ChildItem.FullName` returns the long form. Root-caused it (confirmed
    with a corrected test root), which surfaced that
    Test-SerialFileCurrent's own `.FullName` string-equality check has the
    same class of fragility, even though it cannot manifest against the
    literal hardcoded production path.
  - Verified the `.Name`-based fix resolves it: re-ran the full four-scenario
    suite (false-positive reproduction, sanity, Status=Failed rejection,
    duplicate-file rejection) with the test root deliberately placed back
    under `%TEMP%` - all four now pass, including the sanity case that
    previously failed.
  - Independently pulled SHA256 hashes of the v1.0.3 staging folder
    (`v1.0.3-20260826-151530-186`) and the canonical source scripts -
    confirmed they match, verifying the prior audit's staging claim rather
    than trusting it.
  - Re-ran the standard parse/BOM/ASCII/version-sync check on all seven
    files after the v1.0.4 edits - all clean, all six deployment scripts
    confirmed at 1.0.4.
- Findings resolved: the `.FullName` comparison fragility (Low severity, not
  a live production defect - see AI-Audit-Decisions.md for the full
  rationale and reproduction). Also added a cross-reference closing the
  stale "PDQ overwrite conflicts with governing standard" disagreement
  entry, which the v1.0.3 "PDQ marker pre-removal occurs after temp
  verification" decision had already resolved without saying so.
- Findings confirmed already correct (no action needed): the High-severity
  exact-file detection fix, Status=Success gating, duplicate-file rejection,
  and the intentional asymmetry between the Intune marker writer (no
  pre-delete) and the PDQ marker writer (pre-delete after verification) -
  the latter is correctly scoped, since the ecosystem's mandatory
  pre-removal rule applies specifically to the PDQ companion-marker
  template, not the Intune-side writer.
- Remaining risks or human decisions: no clean Intune staging source
  currently exists for v1.0.4 (see Current State) - regenerate before
  packaging. All other previously-listed active risks (real hardware
  testing, portal return-code registration, PDQ package configuration,
  PSScriptAnalyzer unavailability) are unchanged by this pass.

### 2026-08-26 - Codex remediation to v1.0.3

- Files changed:
  - Install-SerialMarker.ps1 -> v1.0.3
  - Detect.ps1 -> v1.0.3
  - Uninstall-SerialMarker.ps1 -> v1.0.3
  - PDQ\Install-SerialMarker-PDQ.ps1 -> v1.0.3
  - PDQ\Set-SerialMarkerMarker-PDQ.ps1 -> v1.0.3
  - PDQ\Uninstall-SerialMarker-PDQ.ps1 -> v1.0.3
  - AI-Audit-Handoff.md and AI-Audit-Decisions.md
- Findings resolved:
  - detection requires exactly one `Serial - *.txt` file, requires its name and
    content to match the live normalized serial, and then validates marker
    Version/Serial/Status;
  - the standalone PDQ marker step applies the same file prerequisite and exits
    1602 without writing a marker when it is not satisfied;
  - PDQ final-marker pre-removal is deferred until the verified temp marker is
    ready, satisfying the clean-write rule while minimizing the evidence gap;
  - Intune and PDQ uninstallers remove current, `.tmp`, PDQ, and legacy
    `SerialMarker.tag`/`.marker` tiers and verify failures;
  - punctuation-equivalent known placeholders are rejected in all four readers;
  - stale paired-version text and PDQ unexpected-error log-code drift are fixed.
- Windows PowerShell 5.1 validation:
  - all seven scripts parse clean, are UTF-8 BOM/ASCII-only, and contain no
    aliases, unapproved function verbs, or advanced parameter decorations;
  - all four serial normalizer bodies are identical and the expanded placeholder
    matrix passed, including hyphenated placeholder variants;
  - detection matrix passed for exact-good, missing file, wrong content,
    duplicate stale file, failed/missing Status, stale version, and PDQ fallback;
  - locked stale-file install returned 1602, retained its old marker, and
    detection correctly returned 1;
  - marker-only PDQ execution returned 1602 and wrote no marker;
  - locked PDQ final-marker replacement returned 1 and preserved the old marker;
    an unlocked retry finalized Version=1.0.3;
  - both uninstall channels removed all legacy/current tiers when removable and
    returned 1603 for a locked legacy marker while removing every other artifact;
  - full isolated Intune flow passed: install=0, detect=0, uninstall=0,
    detect-after=1;
  - full isolated PDQ flow passed: install=0, marker=0, detect=0, uninstall=0,
    detect-after=1.
- Clean package source:
  `C:\Temp\IntunePackageSource\SerialMarker\v1.0.3-20260826-151530-186`.
  It contains exactly Install/Uninstall/Detect, no directories, no unexpected
  files, and all SHA256 hashes match the canonical scripts. No `.intunewin`
  exists in the project or staging folder.
- Remaining validation: representative physical hardware under SYSTEM, Intune
  portal configuration, and actual PDQ package step configuration.

### 2026-08-26 - Codex second independent audit of unchanged v1.0.2

- Files reviewed: all seven current project scripts, current project handoff and
  decisions, and the unchanged shared audit/PowerShell/Intune standards already
  loaded for this project.
- Files changed: AI-Audit-Handoff.md only. No deployment or staging script was
  changed because the request was audit-only.
- Baseline check: all seven script SHA256 hashes are unchanged from the prior
  Codex audit; no newer Claude handoff/decision entry was present.
- Findings: prior one High and two Medium findings remain. The deeper pass added
  two Low findings: Detect.ps1 ignores `Status=`, and the PDQ install unexpected
  catch logs `ERROR` while exiting 1699. The prior packaging note was updated:
  the old v1.0.1 staging path is no longer stale-but-present; it is absent.
- Validation performed under Windows PowerShell 5.1.26100.9168 Desktop,
  64-bit:
  - all seven scripts parse clean, are UTF-8 BOM/ASCII-only, contain no advanced
    parameter decorations, aliases, or unapproved function verbs;
  - the locked stale-file scenario again left no current serial file, retained
    the old marker, and returned `Detected`;
  - markers with Success, Failed, and missing Status lines all returned
    `Detected` when Version and Serial matched;
  - the standalone PDQ marker step returned 0 and Detect.ps1 returned 0 with no
    IntuneFiles directory or serial file present;
  - normal isolated Intune lifecycle passed: install=0, detect=0, uninstall=0,
    detect-after=1;
  - normal isolated PDQ lifecycle passed: install=0, marker=0, detect=0,
    uninstall=0, detect-after=1;
  - PSScriptAnalyzer remains unavailable.
- Remaining risks/human decisions: unchanged from Active Risks, plus the fresh
  package-source folder must be generated because no staging root currently
  exists.

### 2026-08-26 - Codex independent audit of v1.0.2

- Files reviewed: all seven project scripts, project handoff/decisions, shared
  AGENTS.md, MEMORY.md, and the required PowerShell 5.1, audit, methodology,
  detection, context, path, marker-pattern, encoding, version-sync, and targeted
  pitfall references.
- Files changed: AI-Audit-Handoff.md and AI-Audit-Decisions.md only. No
  deployment or staging script was changed because this turn was audit-only.
- Findings: one High (marker-only detection can report Detected after the
  serial-file repair failed), two Medium (PDQ marker overwrite conflicts with
  the ecosystem pre-removal rule; uninstall omits the required legacy marker
  tier), and three Low (hyphenated placeholder bypass, two stale counterpart
  references, stale v1.0.1 staging source).
- Validation performed under Windows PowerShell 5.1.26100.9168 Desktop,
  64-bit:
  - all seven scripts parsed clean; all are UTF-8 BOM and ASCII-only;
  - no aliases or advanced-function parameter decorations were found;
  - the four serial normalizer bodies are text-identical;
  - a placeholder-variant matrix proved that space-separated placeholders are
    rejected while equivalent hyphenated placeholders are accepted;
  - an isolated locked stale-file reproduction proved file write failure with
    the old marker surviving, the current serial file absent, and detection
    returning `Detected`;
  - both real uninstall entry points, redirected to isolated paths, returned
    1604 when one serial file and one marker were locked, while still removing
    the other marker;
  - complete isolated Intune flow passed: install=0, detect=0, uninstall=0,
    detection after uninstall=1;
  - complete isolated PDQ flow passed: install=0, marker=0, detect=0,
    uninstall=0, detection after uninstall=1;
  - the local physical machine returned nonblank BIOS and CSP serial candidates
    under Windows PowerShell 5.1 without exposing their values;
  - all three canonical v1.0.2 Intune scripts differ by SHA256 from the existing
    v1.0.1 staging folder;
  - PSScriptAnalyzer remains unavailable.
- Remaining risks/human decisions: remediate the High detection defect; resolve
  the PDQ marker pre-removal policy conflict; add or explicitly waive the legacy
  marker tier; regenerate staging; then perform SYSTEM-context physical-device,
  portal, and actual PDQ package validation.

### 2026-08-26 - Claude (Sonnet 5) remediation

- Files changed:
  - Install-SerialMarker.ps1 -> v1.0.2 (removed the pre-deletion of the
    current Intune marker that ran before the serial-file write; the old
    marker is now only ever replaced via Write-IntuneMarker's existing
    Move-Item -Force)
  - PDQ\Set-SerialMarkerMarker-PDQ.ps1 -> v1.0.2 (same fix: removed the
    pre-deletion of both the real marker path and its .tmp file; relies on
    Set-Content -Force and Move-Item -Force instead)
  - Uninstall-SerialMarker.ps1 -> v1.0.2 (added a distinct 1604 exit code
    for "both cleanup tiers failed" instead of always surfacing 1603 when
    both fail; replaced hardcoded '1602'/'1603'/'1699' string literals in
    Write-ErrorLog calls with the already-declared named constants)
  - PDQ\Uninstall-SerialMarker-PDQ.ps1 -> v1.0.2 (identical uninstall fixes)
  - Detect.ps1 -> v1.0.2 (version sync only; `$RequiredVersion` bumped to
    match; no detection logic changed)
  - PDQ\Install-SerialMarker-PDQ.ps1 -> v1.0.2 (version sync only; this
    step never touched the marker tier, so no logic changed)
- Findings resolved (from the same-day Claude independent audit):
  - Medium: the pre-deletion pattern that the prior Codex remediation pass
    introduced (as "invalidate old authoritative evidence before changing
    the serial file") was itself the source of a regression - it destroyed
    a still-valid marker on any transient failure in an unrelated step,
    with no compensating benefit, since Detect.ps1 already independently
    recomputes and compares the live serial regardless of what the old
    marker said. Removed rather than reordered, since Move-Item -Force
    (and Set-Content -Force for the PDQ script's temp file) already
    overwrite atomically - confirmed directly.
  - Low: uninstall exit-code priority when both cleanup tiers fail (now a
    distinct 1604 instead of silently subordinating 1602 to 1603).
  - Low: hardcoded exit-code string literals in log calls (now use the
    named constants, preventing future drift if codes are renumbered).
- Validation performed under Windows PowerShell 5.1:
  - Re-ran the PS 5.1 parse check, UTF-8 BOM / ASCII check, and a
    version-string grep across all seven files - all seven parse clean,
    BOM=True, NonASCII=0, and all six deployment scripts (excluding the
    staging utility, which derives its version dynamically) confirmed at
    1.0.2.
  - Re-read the actual shipped MAIN/function bodies of both edited files
    line-by-line and confirmed they match the ordering already proven
    correct in the prior turn's live simulation (transient serial-write
    failure no longer destroys a valid marker; the marker only changes
    once new content is ready).
  - Confirmed via direct Read that `$ERR_BOTH_FAILED` is genuinely
    referenced in both uninstall scripts, despite the IDE's PSScriptAnalyzer
    flagging it as unused (see Active Risks) - a documented false positive,
    not a fix applied.
- Remaining risks or human decisions: the clean Intune staging folder
  listed under Current State was generated from v1.0.1 and is now stale -
  regenerate with New-SerialMarkerIntuneSource.ps1 before packaging. All
  other previously-listed active risks (real hardware testing, portal
  return-code registration - now needs 1604 added for uninstall, PDQ
  package configuration) are unchanged by this pass.

### 2026-08-26 - Claude (Sonnet 5) independent audit

- Files reviewed: all seven current project scripts (Install-SerialMarker.ps1,
  Detect.ps1, Uninstall-SerialMarker.ps1, PDQ\Install-SerialMarker-PDQ.ps1,
  PDQ\Set-SerialMarkerMarker-PDQ.ps1, PDQ\Uninstall-SerialMarker-PDQ.ps1,
  New-SerialMarkerIntuneSource.ps1) as they stand post-Codex-remediation at
  v1.0.1. No production script or decision file was changed by this pass -
  audit only, matching the shop's audit-then-remediate-as-a-separate-step
  convention already used for the prior Codex pass.
- Validation performed (independently, not reused from the prior audit):
  - Re-ran PS 5.1 parse check and UTF-8 BOM / ASCII verification on all
    seven files myself - confirmed clean.
  - Extracted ConvertTo-NormalizedSerial into an isolated test harness and
    ran it under real Windows PowerShell 5.1 against 15 cases (blank,
    whitespace, 6 known OEM placeholders, all-zero with/without hyphen, the
    all-punctuation edge case that was the actual v1.0.0 bug, too-short, a
    VMware-style VM serial, and a non-string candidate) - all correct.
  - Built an isolated reproduction of Install-SerialMarker.ps1's MAIN
    sequence and marker functions against scratch paths (not real
    ProgramData) and simulated a transient failure in the serial-file-write
    step on an already-Detected device - confirmed live that the existing
    marker is deleted and not restored, flipping the device to NotDetected.
    Verified a reordered/deferred-deletion fix resolves it in the same
    harness without weakening the fail-closed behavior on genuine failures.
    Independently confirmed Move-Item -Force overwrites an existing
    destination file atomically, which is why the pre-deletion step is
    unnecessary.
  - Built an isolated reproduction of Uninstall-SerialMarker.ps1's cleanup
    functions with the Intune marker held open by another process (real
    file lock, not a mock) - confirmed both cleanup tiers are still
    attempted independently and the script correctly reports failure
    rather than false success.
- Findings: see Active Risks above (Medium: redundant pre-deletion around
  both marker writers) plus two Low/cosmetic notes (uninstall exit-code
  priority when both cleanup tiers fail; hardcoded exit-code string
  literals in log calls instead of the already-declared named constants).
  Reported to Jeremy; not yet accepted/rejected or remediated.
- Remaining risks or human decisions: whether to remediate the Medium
  finding now (fix already verified and ready to apply) or defer; all
  other previously-listed active risks (real hardware testing, portal
  return-code registration, PDQ package configuration) are unchanged by
  this pass.

### 2026-08-26 - Codex remediation

- Files changed:
  - Install-SerialMarker.ps1 -> v1.0.1
  - Detect.ps1 -> v1.0.1
  - Uninstall-SerialMarker.ps1 -> v1.0.1
  - PDQ\Install-SerialMarker-PDQ.ps1 -> v1.0.1
  - PDQ\Set-SerialMarkerMarker-PDQ.ps1 -> v1.0.1
  - PDQ\Uninstall-SerialMarker-PDQ.ps1 -> v1.0.1
  - New-SerialMarkerIntuneSource.ps1 -> new local staging utility v1.0.0
  - AI-Audit-Handoff.md and AI-Audit-Decisions.md
- Findings resolved:
  - Each BIOS/CSP candidate is now normalized and validated independently.
    Blank, placeholder, too-short, and hyphenated all-zero BIOS values now use
    a valid CSP fallback in all four serial readers.
  - Both uninstall channels attempt every cleanup item, verify removal, and
    return 1602/1603/1699 instead of false success when cleanup fails.
  - Both install channels use terminating, verified stale-serial cleanup.
  - Intune invalidates old Intune marker evidence before changing state,
    performs verified PDQ handoff cleanup, and finalizes its marker last.
  - Intune and PDQ marker writers now verify a temporary marker and move it to
    the final path only after Version/Serial/Status validation. Uninstall also
    removes any leftover `.tmp` marker files.
  - All `[Parameter()]` / `[CmdletBinding()]` decorations were removed.
  - The local staging utility creates a unique clean folder containing only the
    three Intune source files and never invokes IntuneWinAppUtil.
- Validation performed under Windows PowerShell 5.1.26100.9168 Desktop,
  64-bit:
  - Parser: all seven scripts clean.
  - Encoding: all seven scripts BOM=True and NonASCII=0.
  - AST command review: no aliases and no unapproved function verbs.
  - Version sync: all six deployed scripts are 1.0.1; paired references match.
  - Advanced-function scan: zero `[Parameter()]` or `[CmdletBinding()]`
    matches.
  - Serial branch matrix passed in all four readers, including blank BIOS,
    OEM placeholder, N/A, all-zero GUID, too-few meaningful characters, valid
    primary, and both-invalid cases.
  - Locked stale-serial test: both install writers failed before writing a new
    serial file.
  - Locked-marker test: both uninstall entry points returned 1603, left the
    locked marker for accurate failure evidence, and still removed the other
    marker and serial file.
  - Complete isolated Intune flow passed: install=0, detect=0, uninstall=0,
    detection after uninstall=1.
  - Complete isolated PDQ flow passed: install=0, marker=0, detect=0,
    uninstall=0, detection after uninstall=1.
  - Clean staging folder contains exactly Install/Uninstall/Detect; SHA256
    hashes match the canonical source files and no PDQ file/subfolder is
    present.
- Package artifact: none built, per workspace policy.
- Remaining validation: real physical hardware and SYSTEM context, Intune
  portal return-code configuration, and actual PDQ package step configuration.

### 2026-08-26 - Codex

- Files reviewed: Install-SerialMarker.ps1, Detect.ps1,
  Uninstall-SerialMarker.ps1, PDQ\Install-SerialMarker-PDQ.ps1,
  PDQ\Set-SerialMarkerMarker-PDQ.ps1, and
  PDQ\Uninstall-SerialMarker-PDQ.ps1; project handoff/decisions; the shared
  PowerShell 5.1, Intune detection/context/path/code-pattern, encoding,
  version-sync, methodology, and targeted pitfall references.
- Files changed: AI-Audit-Handoff.md only. Production scripts and
  AI-Audit-Decisions.md were intentionally left unchanged because the request
  was an audit, not remediation.
- Findings: two High and three Medium findings recorded under Active Risks.
  The existing decisions to use `IntuneFiles` for the identification file and
  to use marker-plus-current-serial detection were preserved.
- Validation performed:
  - Windows PowerShell 5.1.26100.9168 Desktop, 64-bit parser: all six scripts
    parse clean.
  - Encoding: all six files are UTF-8 BOM and ASCII-only.
  - AST command review: no aliases and no unapproved function verbs.
  - Version review: install/detect/uninstall/PDQ references are synchronized at
    1.0.0.
  - Detection helper matrix: missing, current, serial-mismatch, stale-version,
    and malformed-version cases returned the intended results under PS 5.1.
  - Serial fallback simulation: blank BIOS correctly used the fallback, but
    placeholder/short-invalid BIOS values did not; hyphenated all-zero BIOS was
    accepted. The same result was reproduced in all four serial readers.
  - Locked-marker uninstall simulation: both uninstall helpers logged the
    failure, swallowed it, left the marker present, and retained the configured
    top-level exit-0 path.
  - Locked stale-serial simulation: both install helpers wrote the new serial
    file while silently leaving the old file present.
  - PSScriptAnalyzer was not installed, so its lint pass could not be run.
- External source verification: current Microsoft Intune documentation still
  requires custom detection to return exit 0 plus STDOUT, and Microsoft's
  content-prep documentation confirms that every file and subfolder below the
  selected source directory is packaged.
- Remaining risks: no SYSTEM-context or real-hardware execution was performed;
  no actual PDQ package configuration/export was available to verify step
  order/failure behavior; portal configuration and manual packaging remain
  human steps.

### 2026-08-26 - Claude (Sonnet 5)

- Files reviewed: Install-SerialMarker.ps1, Detect.ps1,
  Uninstall-SerialMarker.ps1 (pre-existing, blank), PDQ folder (empty),
  reference_intune_paths.md, reference_intune_code_patterns.md,
  reference_intune_detection.md, feedback_notes_format.md,
  feedback_script_encoding.md, feedback_version_sync.md,
  Rename-Device-System.ps1 (sibling project, read for serial-retrieval
  and IntuneFiles-path precedent), Install-MobileCAD-SO.ps1 (read for
  serial-retrieval precedent).
- Files changed:
  - Install-SerialMarker.ps1 (new)
  - Detect.ps1 (new)
  - Uninstall-SerialMarker.ps1 (new)
  - PDQ\Install-SerialMarker-PDQ.ps1 (new)
  - PDQ\Set-SerialMarkerMarker-PDQ.ps1 (new)
  - PDQ\Uninstall-SerialMarker-PDQ.ps1 (new)
  - AI Knowledgebase\reference_intune_paths.md (corrected legacy-path
    classification for IntuneFiles)
  - AI Knowledgebase\AGENTS.md (corrected inline legacy-path list to match)
- Findings accepted: see AI-Audit-Decisions.md for the IntuneFiles
  legacy-path disagreement and its resolution.
- Findings rejected: none.
- Rationale: see AI-Audit-Decisions.md.
- Tests/validation performed: PS 5.1 parse check (0 errors, all 6 files)
  and UTF-8 BOM / ASCII-only verification (BOM=True, NonASCII=0, all 6
  files) via the standard verification command.
- Remaining risks or human decisions: real-device execution testing not
  yet performed (see Required Validation above); portal return-code
  registration not yet configured (Jeremy's manual packaging step).
