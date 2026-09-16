# AI-Audit-Decisions.md

## Durable Decisions

### 2026-05-14 - Validate Before Clearing Output Artifacts

- Decision: Validate that the batch list has usable serials before clearing or
  rebuilding `Hardware Hash - Upload.csv`.
- Status: Accepted
- Evidence type: proven from temp-folder validation
- Rationale: Version 1.0.4 cleared the upload CSV immediately after reading its
  headers. If the batch list was empty, the script exited 1 but left the upload
  CSV reduced to header-only. Input validation should happen before destructive
  output changes where practical.
- Source: `Inventory\Hashlist Propogate Script.ps1`
- Recommended action: Keep batch-list validation before upload reset logic.

### 2026-05-14 - Source Row Serial Must Match Requested Serial

- Decision: Reject a source CSV when column A in the first data row does not
  match the requested/batch serial, even if the filename matches.
- Status: Accepted
- Evidence type: proven from temp-folder validation
- Rationale: The utility indexes source files by filename, but the upload row is
  built from the CSV content. Without a content check, a mismatched or renamed
  CSV could append the wrong device serial and hash to the upload file.
- Source: `Inventory\Hashlist Propogate Script.ps1`
- Recommended action: Keep filename lookup and row-content serial validation
  together for all future revisions.

### 2026-05-14 - Source CSVs Must Preserve the Semantic Minimum Columns

- Decision: Source CSVs may omit Group Tag and Assigned User, but must include
  at least columns A through C: serial number, product ID, and hardware hash.
- Status: Accepted
- Evidence type: proven from current source files and temp-folder validation
- Rationale: Real source CSVs in `Inventory\Raw Hardware Hash Files` are
  3-column files. Version 1.0.2 correctly stopped requiring five source
  columns, but the relaxed floor of one column allowed corrupt 1- or 2-column
  CSVs to append rows without a hardware hash. A valid upload row needs the
  hardware hash in column C. Columns D and E can be padded blank.
- Source: `Inventory\Hashlist Propogate Script.ps1`
- Recommended action: Keep source validation at a three-column semantic
  minimum unless the script is redesigned to map fields by header name.

### 2026-05-14 - Mandatory CSV Data Arrays Must Allow Empty Strings

- Decision: Add `[AllowEmptyString()]` to mandatory string array parameters that
  represent CSV data fields, not control inputs.
- Status: Accepted
- Evidence type: proven from Windows PowerShell 5.1 temp-folder validation
- Rationale: Standard Autopilot hardware hash CSV rows commonly leave
  `Assigned User` blank. In Windows PowerShell 5.1, a mandatory `[string[]]`
  parameter can reject an empty string element during binding before the
  function body runs. This caused valid source CSV files to be marked as import
  failures.
- Source: `Inventory\Hashlist Propogate Script.ps1`
- Recommended action: For reusable functions that receive CSV row values by
  position, allow empty strings on data parameters and validate only the minimum
  column count in function logic.

### 2026-05-14 - P25 Scalar Unwrap in foreach-to-variable Assignment

- Decision: Wrap all `foreach` expressions assigned to a variable in `@()` when
  the result must be treated as an array (e.g., indexed with `[0]` or tested
  with `.Count`).
- Status: Accepted
- Evidence type: proven from code behavior
- Rationale: PowerShell assigns a scalar string (not a one-element array) when
  a foreach loop outputs exactly one item. `$str[0]` on a string returns the
  first character, not the string. This silently corrupts the path variable and
  causes all downstream file operations to fail with a one-character path.
  Wrapping with `@()` guarantees an array regardless of output count.
- Source: AGENTS.md P25; direct code analysis.
- Recommended action: Apply @() wrapping to any foreach-to-variable assignment
  where index access or .Count checks follow.

### 2026-05-14 - Case-Insensitive Hashtable for Serial Lookup

- Decision: Use `New-Object System.Collections.Hashtable([System.StringComparer]::OrdinalIgnoreCase)`
  instead of `@{}` for the serial-number-to-file index.
- Status: Accepted
- Evidence type: recommendation
- Rationale: Serial numbers are typically uppercase but may be entered in mixed
  case by technicians. A case-sensitive lookup would silently drop valid entries.
  OrdinalIgnoreCase matches Windows filesystem behavior (NTFS is case-insensitive).
- Recommended action: Use OrdinalIgnoreCase for any hashtable keyed on serial
  numbers, device names, or filesystem basenames.
