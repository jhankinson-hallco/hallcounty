# AI-Audit-Handoff.md

## Current State

- Project: Hashlist Propagate (local utility for Autopilot hardware hash batch import)
- Current version: 1.0.5
- Deployment type: Local technician utility -- NOT an Intune-deployed script
- Primary script: `Inventory\Hashlist Propogate Script.ps1`
- Launcher: `Inventory\Hashlist Propogate.cmd`
- Detection: N/A (not Intune-managed)
- Uninstall: N/A

Note: The folder and file names use the misspelled "Propogate" (missing second 'a').
The AI Knowledgebase folder uses the correct spelling "Propagate" for searchability.

## Active Risks

- Current `Inventory\Batch List.txt` contains four serials with no matching CSV
  under `Inventory\Raw Hardware Hash Files`: `MZ00H73G`, `MZ00H75G`,
  `MZ00H758`, `MZ00H75T`. This is an input-data issue; the script correctly
  returns exit 2 and writes these serials to `Hash Failure List.txt`.

## Recent Changes

- 2026-05-14: Initial audit completed by Claude Sonnet 4.6. All findings corrected.
- 2026-05-14: Follow-up audit completed by Codex. Fixed blank CSV field
  handling, made duplicate serial tracking case-insensitive, hardened file
  checks, and saved the PS1 as UTF-8 with BOM.
- 2026-05-14: Second Codex audit run completed. No script changes required.
  Expanded PS1/CMD validation passed.
- 2026-05-14: Live-run error: all source CSVs rejected with "fewer than 5 columns."
  Source CSVs have 3 columns (Serial, Product ID, Hash) with Group Tag and Assigned
  User absent. Removed the 5-column floor check on source CSVs. Output padding
  handles missing columns. Bumped to 1.0.2.
- 2026-05-14: Third Codex audit found 1.0.2 was too permissive and accepted
  1- or 2-column source CSVs as successful rows. Fixed by requiring source
  columns A through C, with nonblank serial and hardware hash. Bumped to 1.0.3.
- 2026-05-14: Fourth audit found 1.0.4 cleared the upload CSV before validating
  the batch list and accepted source files whose row serial did not match the
  requested serial. Fixed both issues and bumped to 1.0.5.

## Required Validation Before Use

- Completed 2026-05-14 by Codex:
  - Windows PowerShell 5.1 parser: passed.
  - Encoding: PS1 is UTF-8 with BOM and ASCII-only; CMD is ASCII-only and
    intentionally BOM-less.
  - Temp-folder test runs: 1 serial via PS1, 2 serials with mixed-case
    duplicate, empty batch list, and 1 serial via CMD all passed.

Repeat these checks after any future edits.

## Latest Work Log

### 2026-05-14 - Codex Fourth Audit Run

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`,
  `Inventory\Hashlist Propogate.cmd`
- Files changed: `Inventory\Hashlist Propogate Script.ps1`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Handoff.md`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Decisions.md`,
  `AI Knowledgebase\feedback_ps_auditor_standard.md`
- Findings accepted:
  - MEDIUM: Version 1.0.4 cleared `Hardware Hash - Upload.csv` before
    validating that the batch list contained usable serials. Empty batch lists
    failed but left the existing upload CSV reduced to header-only. Fixed in
    1.0.5 by reading and validating serials before clearing the upload CSV.
  - MEDIUM: The script trusted the source CSV filename but did not verify that
    column A in the source row matched the requested serial. A mismatched file
    could append the wrong device row. Fixed in 1.0.5 by rejecting
    filename/requested-serial versus row-serial mismatches.
- Findings rejected:
  - Broad raw-folder scan found three non-serial-named CSV files whose first row
    serial does not match the filename:
    `Hardware Hash - Sheriff's Office GETACs - December 2025 - Copy.csv`,
    `Hardware Hash - Sheriff's Office GETACs - Small.csv`, and `Temp Start.csv`.
    These are not current script defects because the current batch list does not
    reference those filenames, and lookup is by CSV basename.
  - Current copied real-data run still returned exit 2 for four serials. This is
    not a script defect; no matching CSV exists for those serials under the raw
    hardware hash folder.
- Tests/validation performed:
  - Re-read shared AGENTS, MEMORY, project handoff/decisions, and targeted
    PowerShell audit/encoding/version references.
  - `powershell.exe` 5.1 parser validation: passed.
  - Encoding validation: PS1 `BOM=True NonASCII=0`; CMD `BOM=False NonASCII=0`.
  - Function verbs checked against `Get-Verb`: all approved.
  - Static sweep found no PS7-only syntax, aliases, `Invoke-Expression`, or
    `Get-WmiObject`. The only static CMD hit was normal batch `set` usage.
  - Temp-folder runtime tests after 1.0.5 fix:
    - Empty batch list with pre-existing upload CSV: exit 1, existing upload row
      preserved.
    - Filename/row serial mismatch: exit 2, no row appended, requested serial
      written to failure list.
    - Valid 3-column source CSV: exit 0, row appended, D/E padded blank.
    - Valid 5-column source CSV via CMD: exit 0, row appended.
    - 2-column source CSV: exit 2, no row appended, serial in failure list.
    - 1-column source CSV: exit 2, no row appended, serial in failure list.
    - Blank hardware hash source row: exit 2, no row appended, serial in
      failure list.
    - Missing source serial: exit 2, found row appended, missing serial in
      failure list.
  - Non-destructive copied real-data run using current `Batch List.txt` and
    copied `Raw Hardware Hash Files`: exit 2, 18 rows appended, 4 failures:
    `MZ00H73G`, `MZ00H75G`, `MZ00H758`, `MZ00H75T`.
- Remaining risks or human decisions:
  - Add or correct the four missing source CSVs before expecting a clean exit 0
    from the current batch list.
  - File/folder names still contain the typo "Propogate" instead of
    "Propagate". Renaming remains a human decision because it affects launcher
    references and user muscle memory.

### 2026-05-14 - Codex Third Audit Run

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`,
  `Inventory\Hashlist Propogate.cmd`
- Files changed: `Inventory\Hashlist Propogate Script.ps1`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Handoff.md`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Decisions.md`,
  `AI Knowledgebase\feedback_ps_auditor_standard.md`
- Findings accepted:
  - MEDIUM: Version 1.0.2 correctly allowed 3-column source CSVs, but also
    allowed 1- and 2-column source CSVs to append as successful upload rows.
    That could create `Hardware Hash - Upload.csv` rows with no hardware hash.
    Fixed in 1.0.3 by requiring source columns A through C and requiring
    nonblank serial and hardware hash values.
- Findings rejected:
  - Current copied real-data run returned exit 2 for four serials. This is not
    a script defect; no matching CSV exists for those serials under the raw
    hardware hash folder.
- Tests/validation performed:
  - Re-read shared AGENTS, MEMORY, project handoff/decisions, and targeted
    PowerShell audit/encoding/version references.
  - Confirmed current raw source CSVs are 3-column files with headers:
    `Device Serial Number`, `Windows Product ID`, `Hardware Hash`.
  - `powershell.exe` 5.1 parser validation: passed.
  - Encoding validation: PS1 `BOM=True NonASCII=0`; CMD `BOM=False NonASCII=0`.
  - Function verbs checked against `Get-Verb`: all approved.
  - Static sweep found no PS7-only syntax, aliases, `Invoke-Expression`, or
    `Get-WmiObject`. The only static CMD hit was normal batch `set` usage.
  - Temp-folder runtime tests after 1.0.3 fix:
    - 3-column source CSV: exit 0, row appended, D/E padded blank.
    - 5-column source CSV via CMD: exit 0, row appended.
    - 2-column source CSV: exit 2, no row appended, serial in failure list.
    - 1-column source CSV: exit 2, no row appended, serial in failure list.
    - Blank serial source row: exit 2, no row appended, serial in failure list.
    - Blank hardware hash source row: exit 2, no row appended, serial in
      failure list.
    - Missing source serial: exit 2, found row appended, missing serial in
      failure list.
    - Empty batch list: exit 1 with zero-byte failure list.
  - Non-destructive copied real-data run using current `Batch List.txt` and
    copied `Raw Hardware Hash Files`: exit 2, 18 rows appended, 4 failures:
    `MZ00H73G`, `MZ00H75G`, `MZ00H758`, `MZ00H75T`.
- Remaining risks or human decisions:
  - Add or correct the four missing source CSVs before expecting a clean exit 0
    from the current batch list.
  - File/folder names still contain the typo "Propogate" instead of
    "Propagate". Renaming remains a human decision because it affects launcher
    references and user muscle memory.

### 2026-05-14 - Claude Sonnet 4.6 (1.0.2)

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`
- Files changed: `Inventory\Hashlist Propogate Script.ps1`
- Findings accepted:
  - HIGH (live run): Source CSVs rejected with "fewer than 5 columns" because
    the column-count floor in `Get-FirstCsvDataRowValues` was 5 and in
    `New-OutputCsvObjectByPosition` was also 5. Source CSVs only have 3 columns
    (Serial, Product ID, Hash). Group Tag and Assigned User are absent, not just
    blank. The padding loop in `New-OutputCsvObjectByPosition` already fills
    missing columns with empty strings -- the guards were wrong thresholds.
    Fix: changed `Get-FirstCsvDataRowValues` floor to 1 (empty CSV guard only);
    removed the source-column floor from `New-OutputCsvObjectByPosition` entirely.
    The upload-CSV header floor (5 columns) was left unchanged.
- Tests/validation performed: PS 5.1 parse: PASSED.
- Remaining risks: Live re-run needed to confirm fix resolves all serials.

### 2026-05-14 - Codex Second Audit Run

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`,
  `Inventory\Hashlist Propogate.cmd`
- Files changed: `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Handoff.md`
- Findings accepted: None. No new defects found in the PS1 or CMD launcher.
- Findings rejected:
  - `Write-Host` usage is acceptable because this is a local technician utility,
    not an Intune detection script.
  - The CMD `pause` behavior is acceptable for the intended interactive launcher.
- Tests/validation performed:
  - Re-read shared AGENTS, MEMORY, project handoff/decisions, and targeted
    PowerShell audit/encoding/version references.
  - `powershell.exe` 5.1 parser validation: passed.
  - Encoding validation: PS1 `BOM=True NonASCII=0`; CMD `BOM=False NonASCII=0`.
  - Function verbs checked against `Get-Verb`: all approved.
  - Windows PowerShell 5.1 command syntax checked for `Get-ChildItem`,
    `Export-Csv`, `Set-Content`, and `Import-Csv`.
  - Static sweep found no PS7-only syntax, aliases, `Invoke-Expression`,
    `Get-WmiObject`, or companion detect/uninstall scripts requiring version
    sync.
  - Expanded temp-folder runtime tests:
    - Single serial via PS1: exit 0, 1 row appended, zero-byte failure list.
    - Two serials with mixed-case duplicate: exit 0, 2 rows appended,
      zero-byte failure list.
    - Missing source serial: exit 2, found serial appended, missing serial
      written to failure list.
    - Header-only source CSV: exit 2, no row appended, serial written to
      failure list.
    - Existing upload CSV: exit 0, new row appended without replacing existing
      row.
    - Upload CSV path exists as folder: exit 1 with zero-byte failure list.
    - Empty batch list: exit 1 with zero-byte failure list.
    - CMD launcher from a path containing spaces: exit 0, 1 row appended,
      zero-byte failure list.
- Remaining risks or human decisions:
  - File/folder names still contain the typo "Propogate" instead of
    "Propagate". Renaming remains a human decision because it affects launcher
    references and user muscle memory.

### 2026-05-14 - Codex

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`,
  `Inventory\Hashlist Propogate.cmd`
- Files changed: `Inventory\Hashlist Propogate Script.ps1`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Handoff.md`,
  `AI Knowledgebase\System Scripts\Hashlist Propagate\AI-Audit-Decisions.md`,
  `AI Knowledgebase\feedback_ps_auditor_standard.md`
- Findings accepted:
  - MEDIUM: Mandatory `[string[]]$SourceValues` rejected valid CSV rows when
    the `Assigned User` field was blank. Fixed with `[AllowEmptyString()]`.
  - LOW: PS1 was ASCII-only but lacked UTF-8 BOM. Re-saved as UTF-8 with BOM.
  - LOW: `$SeenSerials` used a default case-sensitive hashtable. Changed to
    `OrdinalIgnoreCase`.
  - LOW: Empty failure list used `Set-Content -Encoding UTF8`, producing a
    BOM-only file instead of a true zero-byte empty file. Added `Set-FailureList`.
  - LOW: File checks accepted folders where files were expected. Added
    `-PathType Leaf` / container checks and explicit file-operation errors.
  - LOW: Duplicate matching CSVs used filesystem enumeration order. Added
    sorting by full path for deterministic first-match behavior.
- Findings rejected:
  - No CMD launcher defect found. It successfully launched the PS1 in temp
    validation; the intentional `pause` behavior was left unchanged.
- Tests/validation performed:
  - `powershell.exe` 5.1 parser validation: passed.
  - Encoding validation: PS1 `BOM=True NonASCII=0`; CMD `BOM=False NonASCII=0`.
  - Temp-folder runtime tests:
    - Single serial via PS1: exit 0, 1 row appended, zero-byte failure list.
    - Two serials plus mixed-case duplicate: exit 0, 2 rows appended,
      zero-byte failure list.
    - Empty batch list: exit 1, zero-byte failure list.
    - Single serial via CMD: exit 0, 1 row appended, zero-byte failure list.
- Remaining risks or human decisions:
  - File/folder names still contain the typo "Propogate" instead of
    "Propagate". Renaming remains a human decision because it affects launcher
    references and user muscle memory.

### 2026-05-14 - Claude Sonnet 4.6

- Files reviewed: `Inventory\Hashlist Propogate Script.ps1`, `Inventory\Hashlist Propogate.cmd`
- Files changed: Both files above.
- Findings accepted:
  - HIGH: P25 scalar unwrap bug -- $FoundBatchListPaths from foreach was a scalar
    string when exactly one batch file was found; [0] returned the first character.
    Fixed with @() wrapper.
  - MEDIUM: Missing #requires -version 5.1. Added.
  - MEDIUM: Missing Set-StrictMode -Version Latest. Added.
  - MEDIUM: .NOTES block missing required fields. Rebuilt to standard format.
  - LOW: New-HeaderOnlyCsv used Set-Content -Path; changed to -LiteralPath.
  - LOW: $CsvFilesBySerial used default case-sensitive @{}; changed to
    OrdinalIgnoreCase hashtable so serial case mismatches between BatchList.txt
    and CSV filenames do not silently fail.
  - LOW: CMD error message referenced "powershellscript.ps1" instead of
    "Hashlist Propogate Script.ps1". Corrected.
- Findings rejected: None.
- Tests/validation performed: Code review only. No live run performed.
- Remaining risks or human decisions:
  - Jeremy should do a live test run with a known-good set of hash CSVs before
    relying on the tool in production.
  - File/folder names contain a typo ("Propogate" instead of "Propagate").
    Renaming is a human decision.
