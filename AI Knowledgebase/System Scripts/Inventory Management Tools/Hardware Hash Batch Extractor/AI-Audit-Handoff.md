# AI-Audit-Handoff.md

## Current State

- Project: Hardware Hash Batch Extractor
- Current version: 1.0.7
- Deployment type: Local PowerShell utility with cmd launcher
- Primary script: `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
- Launcher: `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Detection: Not applicable
- Uninstall: Not applicable
- Package artifact: Not applicable

## Active Risks

- None recorded. One accepted trade-off remains: a source value can no longer
  contain a genuine embedded line break (multi-line quoted field). This is not
  expected to matter for Autopilot hardware hash exports, which are always one
  physical line per device.

## Recent Changes

- 2026-07-17 (Claude, blind audit of Codex's v1.0.6 header-row change; fixes
  applied -> v1.0.7): Codex's change itself was correct - exact Autopilot
  header text/case (`Device Serial Number,Windows Product ID,Hardware
  Hash,Group Tag,Assigned User`) in row 1, device data in row 2. The audit
  checked the output against Microsoft's CURRENT Autopilot import
  requirements (learn.microsoft.com/autopilot/add-devices, page updated
  2026-06): header case-sensitive; extra columns not allowed; QUOTATION MARKS
  NOT ALLOWED; ONLY ANSI-format text allowed, Unicode not allowed. Findings:
  - HIGH (pre-existing, but critical once headers made files import-ready):
    output files were written UTF-8 WITH BOM - explicitly not ANSI, and the
    BOM prefixes the case-sensitive header cell. Fixed: Windows-1252 without
    BOM. Proven in isolated sandbox: pre-fix first bytes EF,BB,BF; post-fix
    'Dev', zero bytes > 127.
  - MEDIUM: `ConvertTo-CsvField` emitted RFC-4180 quoted fields for values
    containing commas/quotes - a file Intune rejects outright. Replaced with
    `Assert-AutopilotFieldValue`: values containing quotes, commas, line
    breaks, or non-ANSI characters now skip the row with a column-named
    reason in the run summary. `ConvertTo-CsvField` removed; header and data
    rows are joined raw (validated safe).
  - LOW: header detection was bound to physical line 1; a leading blank line
    demoted the header row to data (creating `Device Serial Number.csv`).
    Fixed: first parsed content row is checked instead.
  - Validation: isolated sandbox run (patched copy in `C:\Temp\HHBE-Sandbox`,
    output redirected; real Output Files folder untouched) across 10 synthetic
    rows covering header-after-blank-line, blank Assigned User (1.0.1
    regression guard), quoted-valid, comma-in-serial, unclosed quote,
    text-after-quote, blank serial, duplicate serial, non-ASCII UPN. All
    behaved as designed; exit codes correct. Script parses clean under
    PS 5.1, UTF-8 BOM, ASCII-only.
  - OPERATOR NOTE: any output files generated with v1.0.6 or earlier (e.g.
    `Output Files\RRB03B2021.csv`, 2026-07-17 10:41) carry a UTF-8 BOM and
    may fail Intune import - regenerate them with v1.0.7 before uploading.
  - Safety copy (OneDrive sync-loss precaution):
    `C:\Temp\HHBE-Sandbox\Hardware Hash Batch Extractor-v1.0.7.ps1`.

- Project knowledgebase files created for the new local extractor utility.
- Created the PowerShell extractor and cmd launcher.
- Extractor writes one CSV per data row using column A as the output file name.
- Output directory is configurable in the script through `$OutputDirectory`.
- Optional per-file header output is configurable through `$IncludeHeaderRowInOutput`.
- 2026-07-09 (Claude, blind audit of Codex output): fixed a critical crash --
  `Get-OutputRowValues` and `Export-DeviceCsv` declared `Mandatory [string[]]`
  parameters without `[AllowEmptyString()]`. PowerShell's parameter binder
  rejects the whole array if any element is an empty string, so any source row
  with a blank field (most commonly a blank `Assigned User`, which is normal
  for unassigned devices) crashed the entire batch after writing only the rows
  processed so far. Added `[AllowEmptyString()]` to both parameters. Version
  bumped to 1.0.1.
- 2026-07-09 (Claude, follow-up per "correct all issues"): changed per-row
  failure handling in `Invoke-HardwareHashBatchExtractor` from
  throw-aborts-entire-batch to skip-and-report. A blank column A, a duplicate
  output file name (post-sanitization), or an existing output file with
  overwrite disabled now adds an entry to a `$failedRows` list and continues
  to the next row instead of stopping the loop. The run summary now prints
  `Rows skipped: N` followed by one line per failure (`Row <n> -- <reason>`).
  Exit code is 1 if any row was skipped, but the files that did succeed remain
  on disk. This is a deliberate behavior/architecture change from 1.0.1 --
  previously a single bad row discarded all prior progress in that run.
  Version bumped to 1.0.2.
- 2026-07-09 (Codex, follow-up per "Make any necessary changes"): fixed
  parser-level malformed CSV handling. `TextFieldParser.ReadFields()` is now
  caught before normal row validation, and parse failures are added to the
  standard skipped-row summary instead of bypassing it through the top-level
  catch. Version bumped to 1.0.3.
- 2026-07-09 (Claude, follow-up per "Fix any issues"): replaced
  `Microsoft.VisualBasic.FileIO.TextFieldParser` with a hand-written per-line
  CSV field parser (`ConvertTo-CsvLineFields`) and switched source reading to
  `[System.IO.File]::ReadLines()`. This closes the Critical finding from the
  2026-07-09 blind-audit-of-1.0.3 entry: `TextFieldParser` could silently
  consume multiple physical lines hunting for a closing quote, dropping
  device records with no mention in the summary and desyncing later `Row N`
  labels from the true source line. The new parser processes each physical
  line independently, so a malformed line can only ever affect that one line,
  reported by its exact line number. `Get-ExceptionMessage` was removed as
  dead code (it existed only to unwrap the `.NET` method-invocation exception
  that `TextFieldParser.ReadFields()` produced; the replacement throws plain
  PowerShell exceptions with no wrapper to unwrap). Trade-off: a source value
  can no longer contain a genuine embedded line break, since each physical
  line is now one record by design. Version bumped to 1.0.4.
- 2026-07-09 (Codex, blind audit and fix): tightened the custom per-line CSV
  parser after finding that a malformed quoted field with non-comma text after
  a closing quote was accepted and corrupted instead of skipped. After 1.0.5,
  once a quoted field closes, only comma or end-of-line is valid; any other
  character creates a `CSV parse error` for that row. Version bumped to 1.0.5.
- 2026-07-17 (Codex, launcher fix): fixed the cmd launcher closing before
  PowerShell ran when an operator pasted the source CSV path with literal
  surrounding double quotes. The launcher now removes double quotes from
  `INPUT_FILE` before the empty-input check and PowerShell invocation.
- 2026-07-17 (Codex, output header change): enabled `$IncludeHeaderRowInOutput`
  so each generated CSV contains the standard Autopilot header on row 1 and
  the device values on row 2.

## Required Validation Before Deployment

- Parse PowerShell with Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only content for `.ps1` files.
- Run a sample source CSV through the extractor and confirm one output CSV is created per data row.
- Confirm a source CSV containing a blank field (e.g. blank Assigned User) no
  longer crashes the run (regression test for the 1.0.1 fix).
- Confirm a source CSV with a mix of good and bad rows (blank serial,
  duplicate serial) writes the good rows, skips the bad ones, and lists them
  by row number and reason in the summary (regression test for the 1.0.2
  change).
- Confirm a structurally malformed CSV row prints the normal run summary,
  reports a `CSV parse error`, returns exit code 1, and preserves output files
  written before the malformed row (regression test for the 1.0.3 change).
- Confirm a source CSV with a stray/unmatched `"` in a free-text field only
  affects that one physical line -- rows before and after it, including a
  second independently-malformed row immediately after it, are still
  processed and reported with their correct physical line numbers
  (regression test for the 1.0.4 fix).
- Confirm a free-text field with a literal, non-enclosing quote character
  (e.g. `John "Johnny" Smith` as an Assigned User value) is preserved
  verbatim rather than having the quote characters stripped (regression test
  for the 1.0.4 fix -- the per-line parser must only treat a quote as
  field-enclosing when it is the first character of a field).
- Confirm a quoted field with non-comma text after its closing quote is
  skipped as malformed CSV and does not write an output file for that row
  (regression test for the 1.0.5 fix).
- Confirm each generated per-device CSV includes this row 1 header:
  `Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Assigned User`.
- Confirm the device-specific values from the source row are written on row 2.

## Latest Work Log

### 2026-07-17 - Codex (enable per-device header row)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
- Finding accepted:
  - User clarified that each generated output CSV must include the standard
    Autopilot header row:
    `Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Assigned User`
    in cells A1 through E1, with that device's values in row 2.
- Fix:
  - Set `$IncludeHeaderRowInOutput = $true`.
  - Bumped script version to 1.0.6 and updated the changelog.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: PASS (`ParseErrors=0`).
  - Encoding: PASS (`BOM=True; NonAsciiBytes=0`).
  - Existing GETAC hardware hash source file processed successfully: 1 file
    created, 0 rows skipped, exit code 0.
  - Generated output `RRB03B2021.csv` row 1 is exactly
    `Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Assigned User`.
  - Generated output row 2 begins with the device values from the source row.
- Remaining risks or human decisions:
  - None for this requested behavior change.

### 2026-07-17 - Codex (quoted-path cmd launcher fix)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
- Finding accepted:
  - The extractor script itself worked with the Sheriff's Office GETAC CSV, but the `.cmd` launcher failed before PowerShell when the operator pasted a path wrapped in literal double quotes. Reproduction printed `- was unexpected at this time.` and exited 255 with no output files created.
- Root cause:
  - The launcher read the quoted value with `set /p`, then expanded it inside quoted batch syntax. A value like `"C:\...\Sheriff's Office - GETAC\...\Copy.csv"` produced malformed `cmd.exe` parsing before PowerShell received the argument.
- Fix:
  - Added `set "INPUT_FILE=%INPUT_FILE:"=%"` after the prompt to strip literal double quotes copied from Explorer/documentation before the launcher checks for blank input or invokes PowerShell.
- Tests/validation performed:
  - Direct PowerShell invocation with the exact user-provided CSV path: PASS. Created 165 files, skipped 0 rows, exit code 0.
  - `.cmd` launcher with bare pasted path: PASS. Created 165 files, skipped 0 rows, exit code 0.
  - `.cmd` launcher with literal surrounding double quotes in the pasted path: PASS after fix. Created 165 files, skipped 0 rows, exit code 0.
  - `.cmd` launcher ASCII check: PASS. Zero non-ASCII bytes.
- Remaining risks or human decisions:
  - None for this failure. Output files for the Sheriff's Office GETAC source now exist in `Inventory\Inventory Management Tools\Output Files`.

### 2026-07-09 - Codex (blind audit and fix)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_ps_auditor_standard.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - `AI Knowledgebase\feedback_version_sync.md`
  - This project's `AI-Audit-Handoff.md` / `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
    (added `$quotedFieldClosed` state to `ConvertTo-CsvLineFields`; after a
    quoted field closes, only comma or end-of-line is accepted; `.NOTES`
    updated; version bumped to 1.0.5)
  - This handoff file and `AI-Audit-Decisions.md`
- Findings accepted:
  - Medium: the 1.0.4 custom parser silently accepted malformed quoted fields
    where non-comma text appeared after a closing quote. Example:
    `"Hash "bad" text"` was written as a corrupted field instead of being
    reported as malformed CSV.
- Findings rejected:
  - None.
- Rationale:
  - The parser must not silently repair or mutate malformed quoted CSV data.
    Once a field starts with a quote and that quoted field closes, the only
    valid next character is the delimiter or the end of the physical line.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Verified all function verbs are approved.
  - Searched for common PS7-only or banned constructs: no matches.
  - Validated actual `.cmd` launcher with a quoted serial, quoted comma field,
    escaped quotes, and blank optional values: exit code 0 and expected output
    fields.
  - Reproduced the 1.0.4 issue: malformed field `"Hash "bad" text"` was
    accepted with exit code 0 and written as corrupted output. After the fix,
    the bad row is skipped, rows before and after are written, `Rows skipped:
    1` is reported, and exit code is 1.
  - Revalidated mixed bad rows: blank column A and duplicate sanitized file
    name are skipped and reported by row number; good rows are written; exit
    code 1.
  - Revalidated unterminated quote handling: surrounding good rows are written,
    the malformed row is skipped, and exit code is 1.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header row
    (`$IncludeHeaderRowInOutput`, currently `$false`).
  - Accepted trade-off: a source field can no longer contain a genuine
    embedded line break. Flag if a future source format legitimately needs
    multi-line field values.

### 2026-07-09 - Claude (follow-up: "Fix any issues")

- Files reviewed:
  - Prior Latest Work Log entry in this file (2026-07-09 Claude blind audit
    of 1.0.3)
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
    (removed `Add-Type -AssemblyName Microsoft.VisualBasic` and all
    `TextFieldParser` usage; removed `Get-ExceptionMessage`; added
    `ConvertTo-CsvLineFields`; source reading now uses
    `[System.IO.File]::ReadLines()` with one loop iteration per physical
    line; `.DESCRIPTION` and `.NOTES` updated; version bumped to 1.0.4)
  - This handoff file
- Findings accepted:
  - Critical finding from the 2026-07-09 blind-audit-of-1.0.3 entry: fixed by
    eliminating `TextFieldParser`'s cross-line quote-hunting behavior
    entirely rather than trying to compensate for it.
- Findings rejected:
  - None.
- Rationale:
  - The audit's proposed fix directions were (a) pre-validate quote balance
    per physical line before parsing, or (b) track `$parser.LineNumber` to
    report the true consumed range. Chose a stronger version of (a): stop
    using `TextFieldParser` altogether and parse each physical line with a
    small hand-written field splitter, so a malformed line can structurally
    never affect any other line. This is more invasive than option (b) but
    removes the failure class entirely instead of just reporting it more
    accurately, and it also drops the `Microsoft.VisualBasic` dependency.
  - During implementation, an initial version of `ConvertTo-CsvLineFields`
    treated any `"` character as toggling quote mode regardless of position,
    which is not how `TextFieldParser` (or RFC4180-style CSV) works --
    a quote is only field-enclosing when it is the first character of a
    field. This would have silently stripped literal mid-field quote
    characters from free-text values (e.g. `John "Johnny" Smith` typed as an
    Assigned User). Caught this via a direct before/after comparison against
    `TextFieldParser`'s actual behavior on that input, and corrected the
    parser to only enter quoted-field mode at the start of a field.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Verified all function verbs are approved (Get/ConvertTo/Export/Invoke).
  - Confirmed `[System.IO.File]::ReadLines()` auto-strips a UTF-8 BOM even
    with an explicit `Encoding.UTF8` argument (first character of the first
    line came back as `D` from `Device...`, not the BOM character) -- the
    script's manual `TrimStart` BOM fallback is redundant defense-in-depth,
    not required, and left in place.
  - Reran all three malformed-CSV reproductions from the 1.0.3 audit: stray
    quote near EOF (previously lost 2 devices silently) now correctly writes
    all 3 good devices and reports exactly 1 skipped row; stray quote closed
    by a later incidental quote (previously desynced a later row number) now
    correctly reports two independent parse errors at their true line numbers
    (3 and 4) plus a blank-serial failure correctly labeled row 5 (previously
    mislabeled row 4); two consecutive malformed rows confirmed no hang and
    each now reported independently instead of the second being silently
    absorbed into the first.
  - Compared the new parser against real `TextFieldParser` behavior for a
    mid-field literal quote (`John "Johnny" Smith`): before the field-start
    fix, the new parser incorrectly stripped the quotes to `John Johnny
    Smith`; `TextFieldParser` preserves them verbatim; after the fix, the new
    parser also preserves them verbatim and the value round-trips correctly
    through `ConvertTo-CsvField` on output (re-escaped as
    `"John ""Johnny"" Smith"`).
  - Reran the full existing regression suite (blank fields, mixed good/bad
    rows, quoted commas, embedded-quote round-trip, BOM header, short/extra
    columns, reserved names, invalid chars, empty file) against 1.0.4: all
    pass identically to 1.0.3/1.0.2.
  - Ran the actual `.cmd` launcher end-to-end (not just direct `.ps1`
    invocation) against a standard test file: exit code 0, 4 files created.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header
    row (`$IncludeHeaderRowInOutput`, currently `$false`) -- unchanged from
    prior audits, still open.
  - Accepted trade-off: a source field can no longer contain a genuine
    embedded line break. Flag if a future source format legitimately needs
    multi-line field values.

### 2026-07-09 - Claude (blind audit of 1.0.3)

- Files reviewed:
  - This project's `AI-Audit-Handoff.md` / `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - This handoff file only. No script changes were made during the audit.
- Findings accepted:
  - Critical, unresolved: 1.0.3's malformed-CSV try/catch around `ReadFields()`
    stops the crash but does not stop `TextFieldParser` from silently
    consuming multiple physical lines while hunting for a closing quote,
    which both drops device records with no mention in the summary and
    desyncs `Row N` labels for the rest of the file from the true physical
    line number. This is worse than the pre-1.0.3 crash in practice: the old
    behavior failed loudly; this one produces a clean-looking itemized report
    that understates data loss.
- Findings rejected:
  - None.
- Rationale:
  - A "blind audit" should verify claims empirically, not accept a written
    test description at face value. The 1.0.3 work log claimed malformed CSV
    handling "preserves output files written before the malformed row," which
    is true but incomplete -- it does not mention that rows *after* the
    malformed one can also be silently lost. Independent testing with rows
    following the malformed row (not present in the 1.0.3 validation runs)
    surfaced the gap.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Verified all function verbs are approved (Get/ConvertTo/Export/Invoke).
  - Confirmed `Get-ExceptionMessage`'s `InnerException` unwrap is correct and
    necessary (not unnecessary complexity): `ReadFields()` throws via
    PowerShell method invocation, so `$_.Exception` is a
    `MethodInvocationException` whose own `.Message` includes an
    `"Exception calling ReadFields..."` wrapper; unwrapping produces the
    clean message actually shown to the operator.
  - Reproduction 1 (stray quote near EOF): 5-row CSV, unterminated quote on
    row 3, two good rows after it. Result: `Files created: 1`,
    `Rows skipped: 1`, only row 3 listed -- but only `GOOD001` was written;
    `GOOD003` and `GOOD004` were silently lost, never written and never
    mentioned in the failure list.
  - Reproduction 2 (stray quote closed by later incidental quote): confirmed
    row-number desync -- a device on physical row 4 vanished with zero
    mention, while a genuinely blank-serial row on physical row 5 was
    reported as `Row 4`, which would misdirect an operator opening the source
    file in Excel to fix it.
  - Reproduction 3 (two consecutive malformed rows): confirmed no infinite
    loop / hang -- the script completes normally within a bounded background
    job. This aspect of the 1.0.3 fix is sound.
  - Reran the full existing regression suite (blank fields, mixed good/bad
    rows, quoted commas, embedded quotes, BOM header, short/extra columns,
    reserved names, invalid chars, empty file) against 1.0.3 unchanged: all
    still pass identically to 1.0.2.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Fix direction for the Critical finding: pre-validate each physical source
    line has a balanced quote count before calling `ReadFields()` (rejecting
    a genuinely malformed line without letting the parser hunt across lines),
    or track `$parser.LineNumber` before/after each read and report the true
    consumed line range with an explicit "N source lines could not be
    recovered" warning instead of a single row number. Not implemented --
    awaiting direction on which approach to take.
  - Confirm whether generated per-device CSV files should include a header
    row (`$IncludeHeaderRowInOutput`, currently `$false`) -- unchanged from
    prior audits, still open.

### 2026-07-09 - Codex (follow-up: "Make any necessary changes")

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - This project's `AI-Audit-Handoff.md` / `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
    (added `Get-ExceptionMessage`; added try/catch around `ReadFields`;
    malformed CSV parse errors now enter `$failedRows`; `.DESCRIPTION` and
    `.NOTES` updated; version bumped to 1.0.3)
  - This handoff file and `AI-Audit-Decisions.md`
- Findings accepted:
  - Medium finding from the prior blind audit: malformed CSV parser failures
    bypassed the normal run summary.
- Findings rejected:
  - None.
- Rationale:
  - The tool should use one consistent operator-facing summary for row-level
    failures. A structurally invalid CSV row still returns exit code 1, but it
    now reports files written and skipped rows in the same format as other
    row failures.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Validated cmd-wrapper run with input path containing spaces, quoted comma
    field, embedded quotes, blank Assigned User, and an extra source column:
    exit code 0 and expected five output fields.
  - Validated mixed good/bad rows: blank column A and duplicate sanitized file
    name were skipped and reported by row number; good rows were written; exit
    code 1.
  - Validated malformed CSV with an unterminated quote: normal summary printed,
    `Files created: 1`, `Rows skipped: 1`, parser error listed as row 3, exit
    code 1.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header row
    (`$IncludeHeaderRowInOutput`, currently `$false`).

### 2026-07-09 - Codex (blind audit of current 1.0.2)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_ps_auditor_standard.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - `AI Knowledgebase\feedback_version_sync.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - This handoff file only. No script changes were made during the audit.
- Findings accepted:
  - Medium: malformed CSV parsing happens before the per-row try/catch and is
    still batch-fatal after partial output may already exist.
- Findings rejected:
  - None.
- Rationale:
  - The current 1.0.2 skip/report behavior works for row validation failures
    after a row has been parsed, but it does not cover parser-level failures.
    This is lower risk than normal bad data because the source CSV itself is
    structurally invalid, but the behavior should be explicit because it
    bypasses the normal run summary.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Verified all function verbs are approved.
  - Searched for common PS7-only or banned constructs: no matches.
  - Validated cmd-wrapper run with an input path containing spaces, quoted
    comma field, embedded quotes, blank Assigned User, and an extra source
    column: exit code 0, 3 files created, rows skipped 0, output parsed back
    to the expected five fields.
  - Validated mixed good/bad rows: blank column A and duplicate sanitized file
    name were skipped and reported by row number; good rows were written; exit
    code 1.
  - Validated malformed CSV with an unterminated quote: exit code 1 with a
    top-level parser error and no normal summary; earlier valid row output was
    written before the abort.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Decide whether malformed CSV should be treated as a fatal source-file
    error, or whether the script should catch parser exceptions and print the
    same normal summary before exiting 1.
  - Confirm whether generated per-device CSV files should include a header row
    (`$IncludeHeaderRowInOutput`, currently `$false`).

### 2026-07-09 - Claude (follow-up: "correct all issues")

- Files reviewed:
  - Prior Latest Work Log entry in this file (2026-07-09 blind audit)
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
    (per-row try/catch collecting failures instead of throwing out of the
    batch loop; `$script:HadRowFailures` flag drives exit code; run summary
    now reports `Rows skipped` and each failure; `.DESCRIPTION` and `.NOTES`
    updated; version bumped to 1.0.2)
  - This handoff file and `AI-Audit-Decisions.md`
- Findings accepted:
  - Medium finding from the prior audit (no rollback/progress reporting on
    mid-batch failure) -- fixed via skip-and-report per row.
- Findings rejected:
  - None.
- Rationale:
  - User explicitly asked to correct all remaining issues from the prior
    audit. The only open item was the fail-fast/no-rollback Medium finding.
    Chose skip-and-report over a temp-folder/atomic-move approach because it
    is the smaller, more transparent change and matches how an operator would
    actually want to use this tool: fix the handful of bad rows and rerun
    without losing the rows that already succeeded (`$OverwriteExistingFiles`
    already defaults to `$true`, so a rerun is idempotent for already-written
    files).
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - New test: 5-row CSV with 3 good rows, 1 blank-serial row, 1
    post-sanitization duplicate row. Confirmed all 3 good files were written,
    both bad rows were skipped and listed by row number and reason in the
    summary output, and exit code was 1.
  - Reran the full prior regression matrix (header/quoted-comma/short-row/
    extra-column/blank-field, no-header/invalid-chars/reserved-name/blank-
    lines, BOM header, empty file, embedded-quote round-trip) against the
    updated script -- all still pass with `Rows skipped: 0` and exit code 0.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header
    row (`$IncludeHeaderRowInOutput`, currently `$false`) -- unchanged from
    prior audit, still open.

### 2026-07-09 - Claude (blind audit)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - This project's `AI-Audit-Handoff.md` / `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Files changed:
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
    (added `[AllowEmptyString()]` to `Get-OutputRowValues` and
    `Export-DeviceCsv`; bumped `.NOTES Version` to 1.0.1 with changelog entry)
  - This handoff file and `AI-Audit-Decisions.md`
- Findings accepted:
  - Critical: mandatory `string[]` params crash on any row with a blank field.
    Fixed with `[AllowEmptyString()]`.
  - Medium (not fixed, logged as active risk): no rollback/progress reporting
    on mid-batch failure.
- Findings rejected:
  - None.
- Tests/validation performed:
  - Parsed with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified encoding: `BOM=True  NonASCII=0`.
  - Reproduced the crash in isolation: `Get-OutputRowValues -Fields
    ([string[]]@('DEF456','PID2','HASH2','GroupB',''))` threw "Cannot bind
    argument to parameter 'Fields' because it is an empty string." before the
    fix; confirmed elsewhere in the array (first/middle/last/single-element)
    all trigger the same failure.
  - Reproduced end-to-end through the real `.cmd` launcher against a 4-row
    test CSV (one row with blank Assigned User): pre-fix, aborted after row 1
    with exit code 1 and only 1 of 4 files written; post-fix, all 4 files
    written correctly, exit code 0.
  - Ran 8 constructed test CSVs against the fixed script: quoted-comma field,
    embedded-quote field (`""Hi""`), UTF-8 BOM header, short row (padded
    blank), row with extra (6th) column (dropped), no-header source (row 1
    processed as data), reserved Windows device name `CON` (prefixed `_`),
    invalid filename character `/` (replaced with `_`), case-insensitive
    duplicate serial (`abc123` vs `ABC123`, correctly detected and aborted),
    blank column A mid-file (correctly detected and aborted), long (~4500
    char) hash field, and a 0-byte source file (0 files written, exit 0). All
    behaved correctly.
  - Removed all temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header
    row (`$IncludeHeaderRowInOutput`, currently `$false`) -- unchanged from
    prior audit, still open.
  - Decide whether the fail-fast/no-rollback behavior on mid-batch failure
    (see Active Risks) needs to change, or is acceptable as-is.

### 2026-07-09 - Codex

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - `AI Knowledgebase\feedback_version_sync.md`
  - `AI Knowledgebase\feedback_ps_auditor_standard.md`
- Files changed:
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1`
  - `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.cmd`
- Findings accepted:
  - New project did not have matching handoff/decision files.
- Findings rejected:
  - None.
- Rationale:
  - The project is a local inventory management script, so the knowledgebase entry is under `System Scripts\Inventory Management Tools`.
- Tests/validation performed:
  - Parsed `Hardware Hash Batch Extractor.ps1` with Windows PowerShell 5.1 parser: `ParseErrors=0`.
  - Verified `Hardware Hash Batch Extractor.ps1` encoding: `BOM=True  NonASCII=0`.
  - Ran a sample source CSV with a `Device Serial Number` header through the cmd wrapper: header skipped and 2 files created.
  - Ran a sample source CSV without a header directly through Windows PowerShell 5.1: row 1 processed and 1 file created.
  - Validated output contents copied only source columns A through E, including a quoted comma field.
  - Removed temporary validation input and output files.
- Remaining risks or human decisions:
  - Confirm whether generated per-device CSV files should include a header row. Current default is no header, matching the stated requirement to copy only row values from columns A through E. Change `$IncludeHeaderRowInOutput` to `$true` if each generated file should include the standard Autopilot header.
