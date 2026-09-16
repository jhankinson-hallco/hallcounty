# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-05-14 - Preserve Input Computer Names in Workbook Output

- Decision: Successful Lenovo lookup records must write the computer name from
  the input machine list, not a generated `TC-<serial>` value.
- Status: Accepted
- Evidence type: proven from code and temp workbook validation
- Rationale: The script description says prefixed computer names from the input
  list are used in the workbook. The failure path already used the input name,
  but the success path overwrote it with `TC-$SerialNumber`, causing
  inconsistent and potentially wrong workbook rows.
- Source or local evidence: `Fill-LenovoWarrantyWorkbook.ps1`
- Recommended action: Keep `ComputerName = $displayName` in both success and
  failure record paths.

### 2026-05-14 - Generic List Output Under PS 5.1 StrictMode

- Decision: Do not return a generic list by wrapping the list object directly in
  `@($list)`. Emit each item through the pipeline and let callers capture with
  `@(...)`.
- Status: Accepted
- Evidence type: proven from Windows PowerShell 5.1 runtime validation
- Rationale: Under Windows PowerShell 5.1 with `Set-StrictMode -Version Latest`,
  the prior `return @($entries)` pattern threw `Argument types do not match`
  during a one-machine temp run before any Lenovo or Excel work started.
- Source or local evidence: `Get-MachineList` in `Fill-LenovoWarrantyWorkbook.ps1`
- Recommended action: Keep explicit item emission in list-returning helpers.

### 2026-05-14 - Local Workbook Test Must Use Temp Copies

- Decision: Runtime validation for this project should copy the workbook to a
  temp folder and redirect all output files to temp paths.
- Status: Accepted
- Evidence type: recommendation
- Rationale: The project folder currently contains `~$Hall County Audit.xlsx`,
  indicating the live workbook may be open or locked. The utility also writes
  output workbooks/CSV/JSON files. Temp validation proves behavior without
  touching live audit artifacts.
- Source or local evidence: project folder listing and temp validation
- Recommended action: Continue using copied workbook tests for audits.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.
