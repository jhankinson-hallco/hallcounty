# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-07-09 - Local CSV Splitter Design

- Decision: Build the Hardware Hash Batch Extractor as a Windows PowerShell 5.1 script with a same-folder cmd launcher.
- Status: Accepted
- Evidence type: recommendation
- Rationale: The requested workflow is local file processing and does not require Intune, Microsoft Graph, cloud polling, or endpoint deployment assumptions.
- Source or local evidence: User requested a script at `Inventory\Inventory Management Tools\Hardware Hash Batch Extractor\Hardware Hash Batch Extractor.ps1` that can run from a cmd file or program exe.
- Recommended action: Keep the tool local and parameter-driven. Validate with Windows PowerShell 5.1.

### 2026-07-09 - Generated CSV Header Default

- Decision: Default generated per-row CSV files to contain only the values from source columns A through E, with optional header inclusion configurable inside the script.
- Status: Accepted
- Evidence type: likely inference
- Rationale: The request says to skip a source header row when present and copy only the values from columns A through E of each data row.
- Source or local evidence: User requirements 5 and 6 in the 2026-07-09 request.
- Recommended action: Superseded by the 2026-07-17 direct user requirement.
  Generated files now include the standard Autopilot header row.

### 2026-07-09 - Mandatory string[] Parameters Require AllowEmptyString

- Decision: `Get-OutputRowValues` and `Export-DeviceCsv` mandatory `[string[]]`
  parameters must carry `[AllowEmptyString()]`.
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 testing
- Rationale: PowerShell's parameter binder validates every element of a
  mandatory `string[]` parameter and throws `Cannot bind argument to
  parameter 'X' because it is an empty string` if any single element (first,
  middle, last, or the only element) is an empty string -- not only when the
  whole array is empty or unbound. Confirmed with an isolated repro:
  `Get-OutputRowValues -Fields ([string[]]@('DEF456','PID2','HASH2','GroupB',''))`
  threw before the fix and returned correctly after adding
  `[AllowEmptyString()]`. This is a general PS 5.1 gotcha, not specific to
  this script -- worth remembering for any future mandatory `string[]`
  parameter that may receive parsed CSV/text field arrays, since blank fields
  are routine in real data (e.g. a blank Assigned User column).
- Source or local evidence: Reproduced locally in Windows PowerShell 5.1;
  reproduced end-to-end through the shipped `.cmd` launcher and `.ps1` with a
  test CSV containing a blank Assigned User field (crashed pre-fix after 1 of
  4 rows, succeeded post-fix for all 4).
- Recommended action: When declaring `Mandatory` `[string[]]` (or scalar
  `[string]`) parameters that may legitimately receive empty-string values,
  always add `[AllowEmptyString()]` (and `[AllowNull()]` if `$null` is also
  possible). Consider adding this pattern to the shared `AGENTS.md` PS 5.1
  standard if it recurs in other projects.

### 2026-07-09 - Bad Rows Are Skipped And Reported, Not Batch-Fatal

- Decision: A per-row failure (blank column A, duplicate output file name
  after sanitization, or an existing output file when overwrite is disabled)
  no longer aborts the whole batch. The row is skipped, recorded, and listed
  in the run summary (`Rows skipped: N` plus one line per failure); the exit
  code is 1 if any row was skipped, but rows that succeeded remain on disk.
- Status: Accepted
- Evidence type: recommendation, implemented and verified by local testing
- Rationale: The prior throw-aborts-everything design meant a single bad row
  anywhere in a batch discarded every file already written in that run, with
  no printed record of what had succeeded before the abort. For a batch tool
  whose whole purpose is turning one big export into many per-device files,
  losing all prior progress on one bad row is worse than reporting the bad
  row and keeping the rest. `$OverwriteExistingFiles` already defaults to
  `$true`, so rerunning after fixing the source data is already idempotent
  for files that succeeded.
- Source or local evidence: User instruction "Correct all issues" following
  the 2026-07-09 blind audit, which had flagged this as a Medium finding.
  Verified with a 5-row test CSV (3 good, 1 blank serial, 1 duplicate) --
  3 files written, 2 failures reported by row number and reason, exit code 1.
- Recommended action: If a future requirement needs strict all-or-nothing
  batch semantics (e.g. importing into a system that must not see partial
  batches), revisit this decision and consider a temp-folder-plus-atomic-move
  design instead.

### 2026-07-09 - Malformed CSV Parser Errors Use Standard Summary

- Decision: Parser-level `TextFieldParser.ReadFields()` failures are caught
  and recorded in the same skipped-row summary as validation failures.
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 testing
- Rationale: In 1.0.2, malformed CSV rows such as unterminated quoted fields
  bypassed the normal run summary because `ReadFields()` executed before the
  inner per-row try/catch. In 1.0.3, the parser call has its own try/catch;
  the script reports `CSV parse error`, prints the normal source/output/files
  summary, preserves previously written outputs, and returns exit code 1.
- Source or local evidence: Verified with a malformed line 3 test. Result:
  normal summary printed, `Files created: 1`, `Rows skipped: 1`, row 3 parse
  error listed, exit code 1.
- Recommended action: Keep malformed CSV as a non-success exit condition.
  Re-run after correcting the source CSV if any parser errors are reported.

### 2026-07-09 - Replaced TextFieldParser With A Per-Line Parser

- Decision: Stop using `Microsoft.VisualBasic.FileIO.TextFieldParser` for
  source CSV reading. Read the file with `[System.IO.File]::ReadLines()` and
  parse each physical line independently with a new
  `ConvertTo-CsvLineFields` function. A quote character is only treated as
  field-enclosing when it is the first character of a field (matching
  `TextFieldParser`'s own behavior for mid-field literal quotes).
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 testing, verified
  against `TextFieldParser`'s actual behavior for comparison
- Rationale: `TextFieldParser` treats an unmatched `"` as the start of a
  field that may legitimately span multiple physical lines and keeps
  consuming lines hunting for a closing quote (up to EOF). This meant a
  single stray quote in a free-text field (Group Tag, Assigned User) could
  silently consume and drop an unknown number of following device records
  with no mention in the run summary, and desync every later `Row N` label
  from the true physical source line. Catching the exception (1.0.3) stopped
  the crash but did not stop the silent consumption -- the underlying data
  loss and mislabeling remained. Parsing one physical line at a time removes
  the failure class structurally: a malformed line can never affect any
  other line.
- Source or local evidence: User instruction "Fix any issues" following the
  2026-07-09 blind audit of 1.0.3, which had flagged this as Critical.
  Reproduced the fix against the audit's exact three test cases (see
  2026-07-09 handoff work log entry) -- all three now show correct,
  complete, accurately-line-numbered results. Also directly compared the new
  parser's handling of a mid-field literal quote (`John "Johnny" Smith`)
  against real `TextFieldParser` output to confirm behavioral parity for
  that case, catching and fixing a regression in an early draft that
  stripped such quotes instead of preserving them.
- Recommended action: If a future data source legitimately needs a field
  value containing an embedded line break, this line-per-record design will
  reject it as malformed. Revisit if that requirement appears; Autopilot
  hardware hash exports do not need it.

### 2026-07-09 - Quoted Field Closure Must Be Strict

- Decision: In the custom per-line CSV parser, after a quoted field closes,
  only comma or end-of-line is valid. Any other character is a malformed CSV
  row and must be reported as a `CSV parse error`.
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 testing
- Rationale: The 1.0.4 parser allowed non-comma text after a closing quote and
  silently appended/mutated data. Example input `"Hash "bad" text"` was
  accepted with exit code 0 and written as corrupted output. Silent mutation
  is worse than rejecting the malformed row.
- Source or local evidence: Reproduced against 1.0.4 and verified fixed in
  1.0.5. The malformed row is now skipped, rows before and after are written,
  `Rows skipped: 1` is reported, and exit code is 1.
- Recommended action: Keep quoted-field closure strict. Literal quotes that
  are not field-enclosing remain allowed in unquoted fields, but malformed
  quoted fields must be skipped rather than repaired.

### 2026-07-17 - Cmd Launcher Strips Pasted Double Quotes From Input Path

- Decision: The `.cmd` launcher strips literal double quote characters from
  the operator-provided `INPUT_FILE` before checking for blank input or
  invoking PowerShell.
- Status: Accepted
- Evidence type: proven from local reproduction
- Rationale: Operators commonly paste paths copied from Explorer or written
  documentation with surrounding double quotes. `cmd.exe` does not treat
  quotes stored inside a variable the same as quotes written in the batch
  source; expanding that quoted value inside another quoted expression caused
  a parser failure before PowerShell received the path.
- Source or local evidence:
  - Reproduction with quoted input: `- was unexpected at this time.`
    Exit code 255, no output created.
  - After stripping quotes, both bare and quoted input paths processed the
    Sheriff's Office GETAC CSV successfully: 165 files created, 0 rows
    skipped, exit code 0.
- Recommended action: Keep the launcher tolerant of quoted pasted paths.
  Continue to let the PowerShell script perform final source path validation.

### 2026-07-17 - Generated CSV Files Include Autopilot Header Row

- Decision: Generated per-device CSV files must include the standard Autopilot
  header row in row 1:
  `Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Assigned User`.
  The device-specific values from the source row are written to row 2.
- Status: Accepted
- Evidence type: direct user requirement
- Rationale: The generated files are intended to be independently usable CSV
  imports with columns A through E clearly labeled.
- Source or local evidence: User clarified the required row layout on
  2026-07-17.
- Recommended action: Keep `$IncludeHeaderRowInOutput = $true` unless Jeremy
  explicitly requests row-only outputs again.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.
