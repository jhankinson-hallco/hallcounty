# AI-Audit-Handoff.md

## Current State

- **ACTION NEEDED FROM JEREMY (as of 2026-07-24, D-058):** a critical
  bug (shared pitfall P30, `reference_intune_pitfalls.md`) meant every
  use of "Fix Import Format" (the standalone button OR Batch Edit's old
  "Fix Import Format only" checkbox mode) silently wiped that file's
  Group Tag to blank, for every use since D-050 shipped on 2026-07-23 --
  including Jeremy's real 175-file production run that motivated D-051.
  The bug is fixed and Jeremy has confirmed the fix works correctly at
  scale against the real live library ("I can confirm it works en
  masse," 2026-07-24) -- but any Group Tag data already lost from the
  OLD 175-file run, BEFORE this fix existed, is NOT automatically
  restored. Jeremy still needs to decide whether those 175 files had
  real Group Tag values before that run and, if so, whether to restore
  them from that run's backup archive. See D-058 in `AI-Project-Plan.md`
  for full detail.
- Project: MIS Inventory Navigation Tool (MINT)
- Current version: entry script v1.4.0 (D-059: main window now shows
  the real Hall County MIS/MINT icon in the title bar and taskbar,
  replacing the default WinForms icon; D-062: whole-app togglable Dark
  Mode, saved locally per installation, via a new Core.Theme.ps1
  v1.0.1, including a same-day fix after Jeremy reported the toggle was
  invisible on real use; D-065: Get-MintPluralizedNoun promoted here
  from Tab.Search.ps1; D-066: Set-MintGridColumnWidthsToContent and
  Get-MintGridSelectedRowsInVisualOrder added here as shared grid
  helpers; D-067: Set-MintGridColumnWidthsToContent now self-heals via
  a HandleCreated hook and enforces a real MinimumWidth floor; new
  Update-MintWaitWindowMessage for live wait-window progress text;
  D-068: Get-MintGridSelectedRowsInVisualOrder now skips a selected row
  whose .Tag is still $null, fixing a real crash that truncated Batch
  Extract's results grid to 1 row; D-072: ReviewStagingRoot moved from
  under DataRoot to under HashInventoryRoot, alongside the governed
  Hash Library, at Jeremy's request), Tab.Search.ps1 v1.8.5 (D-066: grid
  resize fix, selection helper delegate refactor; D-075: Check AD
  display appends a " - Subfolder" suffix when a computer sits under a real
  subfolder of its department's Computers container), Tab.Warranty.ps1
  v1.2.0, Tab.Extract.ps1 v2.6.0 (D-065 full implementation; D-066:
  grid resize, human-readable Status text, Batch Edit, Copy Serial(s),
  and a models.csv editor; D-067: Invoke-MintExtractClassification
  gained -ProgressCallback, wired into both classification call sites
  with button-disable re-entrancy guards; D-068: both call sites now
  read the active wait window via a new CurrentWaitWindow state slot;
  D-072: Device Type/Manufacturer/Model editing and Batch Edit gating
  widened from NeedsFolderReview-only to any non-terminal row;
  Manufacturer/Model are now typeable dropdowns backed by a new
  manufacturer.csv and models.csv's Model Name column; D-073: new
  Update-MintExtractReviewStagingPromotion promotes a ReviewStaging row
  to NeedsFolderReview once its classification is manually completed,
  fixing "Create Folders" silently skipping such a row; D-074: Process
  File now shows a real MessageBox when a batch file's columns 4/5 are
  not really Group Tag/Assigned User), Core.Csv.ps1
  v1.3.0 (D-066: new Write-MintVariableCsv; D-074:
  Read-MintVendorBatchFile is now header-aware for columns 4/5 instead
  of purely positional, fixing a real production bug where Manufacturer
  Name/Device Model text from one specific real batch file's own
  columns was silently written into Group Tag/Assigned User on every
  extracted file), Core.Domain.ps1 v1.1.0,
  Core.Inventory.ps1 v1.2.0 (D-072: new Get-MintManufacturerMapInternal/
  Get-MintManufacturerChoices, Manufacturers on the inventory index),
  Core.Backup.ps1 v1.0.1, Core.ActiveDirectory.ps1 v1.1.0 (D-075: new
  ComputersSubfolder output on Resolve-MintDeviceAdLocation),
  Core.VendorLookup.ps1 v1.5.0 (D-069:
  ConvertTo-MintLenovoModelName strips an embedded mid-string "(Type
  ...)" parenthetical before either brand-parenthetical pattern runs,
  not after; D-070: also strips a redundant leading "Lenovo " word and
  matches a plural "Laptops"/etc. device-type keyword, fixing real
  ThinkPad T14 Gen 2/5/6, T16 Gen 4, and Legion T5 26IAB7 devices that
  were landing on NeedsFolderReview despite already having matching
  models.csv rows; D-071: new ConvertTo-MintGetacModelName normalizes a
  bare "G"+number generation suffix, e.g. "B360G2", to models.csv's own
  "B360 Gen 2" convention, after Jeremy corrected an earlier claim that
  Getac B360 Gen 2/Gen 3 were genuinely unmapped; D-073: fixed the
  Getac field regex to tolerate a Warranty Expiration Date wrapped in an
  inner tag, which silently failed the whole match -- not just the
  date -- for a real expired-warranty Getac B360). Search and Manage
  (Tab 2) is fully
  implemented, tested
  against real filestore data, and has been through SEVENTEEN rounds of
  Jeremy's real first-use feedback.
  Round 1 (5 fixes): "please wait" window on Refresh Inventory, singular
  Device Type display, clearer "Import Format" column + explainer
  button, red text on problem cells, and a real crash fix for a
  .GetNewClosure() scope bug (shared pitfall P28). Round 2 (D-046):
  corrected the canonical header validation rule to a 3/4/5-column
  positional-cascade prefix instead of always requiring the full
  5-column text; narrowed the UTF-8 BOM requirement to program code
  only, never hash data files; switched grid columns from stretch-to-
  fill to size-to-content (AllCells). Round 3 (D-047): removed quoted
  fields as a format issue entirely, based on Jeremy's real operational
  history importing these files -- canonical file count on the real
  library jumped from 1/256 to 80/256 as a direct, verified result.
  Round 4/4.5 (D-048): the `.cmd` launcher was rewritten to run the tool
  as a detached process with a hidden console window and a startup
  "please wait" window; Jeremy's real-world double-click contradicted
  that fix ("still open, just minimized"), so it was superseded the same
  day -- the launcher is now a standalone `MIS Inventory Navigation
  Tool.vbs` (wscript.exe has no console window of its own at all, unlike
  a `.cmd`), with the `.cmd` kept only as a thin legacy shim. Round 5
  (D-049): both grids support multi-row selection with single-file-only
  actions grayed out unless exactly one row is selected; a new Batch
  Edit action mass-assigns Group Tag across every selected device from a
  dropdown backed by a new `variables\grouptags.csv` choice list;
  Decommission and Restore were refactored into per-row worker functions
  so both are now multi-select-capable; Import Format and Duplicate
  columns moved to the end of the live grid's column order. Round 6
  (D-050): Check AD Location is now batch-capable; a new Fix Import
  Format action is available both standalone and as a "fix format only"
  mode inside Batch Edit; the action panel was reorganized into two
  rows; and a real reported crash in Batch Edit was fixed (shared
  pitfall P29 -- a bare `return $array` collapses a 0-element array to
  `$null` across a function boundary, fixed in all four
  Core.Inventory.ps1 array accessors). Library scan/index, format
  classification, duplicate detection, serial/model/device-type search
  (D-017 multi-token matching verified live), on-demand AD lookup
  (verified against a real AD computer object, now batch-capable per
  D-050), Open/Open Folder/Copy Path, Move, Decommission
  (D-034/D-040/D-049), Restore (D-049), Batch Edit (D-049/D-050), and
  Fix Import Format (D-050) all working. Round 7 (D-051): fixed a real
  crash from Jeremy's first live 175-file Fix Import Format run -- the
  report-row writer had zero retry protection against a transient
  network file lock, and the surrounding try/catch could not
  distinguish "nothing changed yet" from "most of the batch already
  succeeded, then the audit log hit a lock," misreporting a likely
  mostly-successful run as a total failure. Fixed both the missing
  retry (moved `Invoke-MintFileWriteWithRetry` into Core.Backup.ps1 so
  the report writer shares it with the decommission master list) and
  the misleading-message design flaw (every mutating handler now keeps
  backup-creation and per-item work in separate try/catch scopes).
  Round 8 (D-052): corrected the actual grouptags.csv format after
  Jeremy created the real live file -- it is a flat one-tag-per-line
  list with no header row, not the headered CSV originally designed;
  the old reader would have silently discarded the first real tag and
  failed the header check, leaving the dropdown empty despite Jeremy
  doing exactly what was asked. Fixed to read plain lines directly,
  verified against a sandbox copy of the real 70-line file (69 unique
  tags after one real duplicate collapses). Core.Logging, Core.Csv,
  Core.Domain, Core.Inventory, Core.Backup, Core.ActiveDirectory,
  Core.DeviceRecord are all real implementations now, not stubs.
  Warranty Lookup (Tab 6) is now also real (D-053): Lenovo (ported from
  Fill-LenovoWarrantyWorkbook.ps1 v5.0.1) and Getac (new) providers
  tried in sequence via Core.VendorLookup.ps1's
  Resolve-MintWarrantyLookup, with an honest "Vendor Not Configured"
  fallback explaining Dell/HP need vendor API access not yet obtained
  (D-036/D-042). Verified via real live lookups against both vendors'
  actual endpoints, including a real Hall County device (MZ013XH6) and
  the known Getac test serial (RRB03B2021); found and fixed two real
  bugs along the way (a missing [AllowEmptyCollection()], and a
  PowerShell gotcha where an if/else statement cannot be used as one
  argument inside a method call or array literal). Hash decode and the
  Dell/HP API providers remain unimplemented -- out of scope for this
  pass by explicit request.
  Round 9 (D-054): added Model Lookup (single-selection only, shows
  Serial/Manufacturer/Model in a popup via the same warranty pipeline as
  Tab 6) and Delete (multi-selection, permanently removes files from
  disk behind a two-step backup-then-confirm dialog sequence -- distinct
  from Decommission, which only moves a file). Verified via real button
  clicks, real auto-answered dialogs, a real live vendor lookup, real
  file deletion, and real backup-zip content inspection (opened and
  counted entries, not just trusted the success message).
  Round 10 (D-055): Group Tag and Assigned User cells in the live
  results grid are now directly editable, spreadsheet-cell style --
  click a cell and type. Group Tag is a searchable/typeable dropdown
  (choices unioned from `variables\grouptags.csv` and every in-use
  value already on disk, plus a blank entry); Assigned User is plain
  free text. Every commit is backed up silently, no confirmation dialog,
  matching a spreadsheet "type and it saves" feel rather than a batch
  operation. Found and fixed a real bug via live testing: a
  DataGridViewComboBoxColumn's built-in dirty-notification wiring does
  not reliably fire for free-typed text (only for picking an existing
  list item), so a newly-typed custom Group Tag silently reverted to its
  old value on commit with no error at all -- fixed by explicitly wiring
  TextChanged to call NotifyCurrentCellDirty. Verified reliable across
  40 assertions of real per-keystroke SendKeys-driven typing (an early
  test using synthetic bulk .Text assignment was genuinely flaky and
  required real investigation, not just more retries, to resolve) plus
  the full 33-assertion inline-edit suite passing 7 consecutive clean
  runs.
  Round 11 (D-056): added a "Copy Serial(s)" action to the live grid
  (1-or-more selection), copying selected serial numbers to the
  clipboard one per line. Found and fixed a real correctness gap before
  it shipped, via an isolated repro rather than assumed:
  DataGridView.SelectedRows enumerates selected rows in reverse-
  selection order, not grid-visual order, which would have produced
  scrambled output for a non-contiguous ("gapped") selection depending
  on click order -- fixed with a new helper
  (Get-MintSearchSelectedFilesInGridOrder) that iterates the grid's own
  row collection in true visual order instead. Verified via a live test
  including the decisive scenario: selecting rows out of visual order
  (click E, then A, then C) still produces clipboard output in correct
  grid order (A, C, E).
  Round 12 (D-057): Assigned User inline edits are now normalized against
  the hallcounty.org domain -- a bare username gets @hallcounty.org
  appended automatically; an already-@-qualified value is accepted only
  if the domain is hallcounty.org, otherwise the edit is rejected with
  an explanatory message rather than silently rewritten. New
  ConvertTo-MintAssignedUserValue does the normalize/validate work; the
  existing D-055 no-op check runs both before AND after normalization,
  which is what actually prevents `john.doe@hallcounty.org` from ever
  becoming `john.doe@hallcounty.org@hallcounty.org` (Jeremy's specific
  concern) and prevents a legacy unqualified value from being silently
  "upgraded" just by clicking into that cell without editing it.
  Round 13 (D-058): added "Remove All Assigned Users" as a third Batch
  Edit mode (radio buttons: Set Group Tag / Remove All Assigned Users /
  Fix Import Format only, mutually exclusive). While building and
  testing the new mode's `OverrideAssignedUser` parameter, found and
  fixed a CRITICAL pre-existing bug (shared pitfall P30): a
  `[string]$Param = $null` parameter combined with an
  `if ($null -ne $Param)` guard does not work in PowerShell 5.1 -- the
  parameter is coerced to a real `""` the instant it is bound, whether
  omitted or explicitly passed `$null`, so the override branch fired
  unconditionally. This means the standalone Fix Import Format button
  (and Batch Edit's old "Fix Import Format only" checkbox mode), which
  have always called the shared worker with zero override arguments
  specifically to leave Group Tag untouched, have been SILENTLY WIPING
  every fixed file's Group Tag to blank on every use since D-050
  shipped -- including Jeremy's real 175-file production run that
  motivated D-051. Fixed via `$PSBoundParameters.ContainsKey()` plus
  conditional splatting at the call site (an always-present
  `-OverrideX $null` argument reproduces the same bug even after the
  function itself is fixed). Also fixed the pre-existing round-2 test
  fixture that had masked this for five prior rounds -- its "no override
  leaves Group Tag untouched" assertion used a sandbox file whose Group
  Tag already started blank, so it could never have caught this. See the
  ACTION NEEDED note at the top of this file.
  Round 14 (D-060): reworked the top summary bar after Jeremy reported
  its wording was unclear (missing plural grammar, showing "0 X" for
  empty categories, "non-canonical" was jargon, and "issues" was
  ambiguous -- Jeremy specifically noted fixing every Import Format
  issue with no duplicates yet still seeing "2 issues"). Root-caused
  first: the Issues count was NEVER connected to Import Format or
  duplicates at all -- it is scan-level problems (a missing/malformed
  `variables\*.csv`, or a hash file that failed to parse entirely), so
  Jeremy's report was consistent with the code all along, just
  impossible to understand from a bare number. Fixed: correct
  singular/plural wording throughout (new `Get-MintPluralizedNoun`),
  every non-file-count category omitted entirely at 0 instead of shown
  as "0 X", "non-canonical" renamed to match the grid's own "Import
  Format" terminology, "issues" renamed to "scan warnings" with a new
  "View Scan Issues..." link showing the real underlying text.
  Round 15 (D-061): made the summary bar's file/needs-fixing/duplicate
  counts filter-aware after Jeremy pointed out "253 files" stayed fixed
  no matter what he typed into the search filters. They now reflect only
  the currently filtered/visible files, narrowing toward "0 files" as a
  serial search eliminates matches, exactly matching what is on screen.
  Scan warnings deliberately still reflect the whole library, since a
  scan-level problem is not tied to any one visible row. Also fixed the
  identical bug in the Decommissioned view's own summary message (always
  showed the total master-list record count regardless of its serial
  filter), picking up correct singular/plural wording in the same pass.
  Round 16 (D-063): the summary bar's leading file-count segment now
  reads "N files found" instead of a bare "N files," per Jeremy's direct
  request. Round 17 (D-064): the Group Tag column is now sortable.
  Jeremy asked whether being unable to sort by Group Tag was deliberate
  or unavoidable -- it was neither: `DataGridViewComboBoxColumn`
  (Group Tag is the only combo column in this grid, since D-055) defaults
  to `SortMode = NotSortable`, unlike the plain-text columns around it,
  which default to `Automatic`; confirmed via a live test that setting
  `Automatic` explicitly works with no exception, fixed with one line.
  Remaining three tabs (Validate, ModelLookup, Upload) are still
  placeholders/stubs.
  D-065 (whole-new-tab feature, not a Search and Manage round): Batch
  Extract (Tab 3) is now a real implementation. Operator selects one
  vendor batch hash CSV; it splits into rows, strips a department-name
  prefix off each serial (reusing the existing New-MintSerialNumber --
  no new prefix logic), and identifies manufacturer/model via the
  warranty lookup pipeline (Resolve-MintWarrantyLookup -- hash decode is
  explicitly NOT used, per Jeremy's own instruction). A device warranty
  lookup identified but models.csv has no folder for yet appears in a
  review grid: Device Type dropdown (Desktop/Laptop/GETAC),
  Manufacturer, Model, all editable, with a live destination-path
  preview. "Create Folders Now" creates confirmed folders in bulk at any
  time. Clicking "Extract" creates any still-missing folders, checks
  every writable row for a duplicate-serial conflict BEFORE writing
  anything, resolves conflicts via a per-row Overwrite/Ignore dialog
  (default Ignore), writes the final set (reusing the existing
  Write-MintCanonicalHashFile, so quoting stays minimal automatically --
  D-047), then verifies every expected file actually landed on disk
  rather than trusting the writer's own success report. Unidentified
  devices go to Review Staging. Found and fixed two real bugs via live
  testing: a DataGridView.ReadOnly=true grid-level setting silently
  overriding per-cell ReadOnly=false overrides (the review grid's
  editable cells were unreachable until fixed), and a shared-pitfall-P29
  bare array return collapsing to $null on a second, nothing-created
  folder-creation run. Also discovered (separately, out of scope for
  D-065) that D-062's OwnerDraw tab-header theming makes tab headers
  invisible to UI Automation, likely also affecting screen readers.
  D-062 (whole-app feature, not a Search and Manage round): added a
  togglable Dark Mode, similar to a system dark-mode setting, applied
  live via a "Dark Mode" checkbox on the main shell. The choice
  persists locally (`MINT-Settings.json` next to the program's own
  files, NOT the shared filestore) per Jeremy's explicit request.
  New Core.Theme.ps1 provides palettes, persistence, and a recursive
  control-theming walker; scope covers Search and Manage, Warranty
  Lookup, and shared shell chrome (the only fully built-out tabs
  today). Found and fixed two real bugs via live testing before
  shipping: (1) an extension of shared pitfall P28 -- a plain
  scriptblock event handler referencing a LOCAL (non-`$script:`)
  variable from an already-returned function throws under StrictMode
  once it actually fires, distinct from the known `.GetNewClosure()`
  finding; fixed via a new `$script:MintMainShellState` container; (2)
  a `Graphics.DrawString` overload-resolution crash (passing a
  `Rectangle` where only `PointF`/`RectangleF` overloads exist) that
  would have crashed the app on every single real startup, in either
  theme -- found only by a full-app cross-process smoke test after an
  earlier off-screen unit test failed to trigger the real paint pass
  that exposed it. Same-day follow-up: Jeremy reported the checkbox was
  invisible on real use ("Where is the darkmode toggle? I don't see
  it."). Root cause: it was positioned via `Location(970,5)` +
  `Anchor=Right` set BEFORE its panel was actually docked, anchoring it
  against the panel's un-docked default width (200px) instead of its
  real ~1084px width, pushing it ~800px past the panel's real right
  edge -- present and functional in the automation tree (why the
  earlier smoke test's presence check missed it) but genuinely
  clipped/invisible on screen. Confirmed via an isolated repro before
  fixing; fixed via `Dock=Right` on the checkbox itself, which has no
  such timing dependency; closed the coverage gap with new
  bounds/on-screen-position assertions in both the unit and full-app
  smoke tests. Entry script v1.0.7 -> v1.0.8. See D-062 in
  `AI-Project-Plan.md` for full detail.
- Deployment type: Local Windows PowerShell 5.1 WinForms utility; not
  Intune-deployed
- Local project directory: `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool`
- Entry point: `MIS Inventory Navigation Tool.ps1`, launched via
  `MIS Inventory Navigation Tool.vbs` (recommended; double-click
  directly) or `.cmd` (legacy shim, delegates to the `.vbs`), dot-sources
  `Modules\Core.*.ps1` and `Modules\Tab.*.ps1` in explicit order
- Filestore distribution source: `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\MINT Application\MIS Inventory Navagation Tool` (AI/dev must not write here unless Jeremy requests a release copy)
- Decommission root: `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Decommissioned Devices`
- Primary install script: N/A (local utility, not Intune-deployed)
- Detection: N/A (local utility, not Intune-deployed)
- Uninstall: N/A (local utility, not Intune-deployed)
- Package artifact: N/A (local utility, not Intune-deployed)

## Active Risks

- Requirements are broad and conceptual; architecture, data source of truth, conflict handling, and operational boundaries are not finalized.
- High-conflict conceptual areas identified on 2026-07-17:
  - MINT external data/database root and Endpoint Inventory hash root are both
    finalized and separate; implementation must keep `$script:DataRoot` and
    `$script:HashInventoryRoot` distinct. Default vendor batch input root is
    now finalized under Endpoint Inventory.
  - Local project folder is renamed to `MIS Inventory Navagation Tool`; future
    docs/code should use that path, while historical work-log entries may still
    reference the old `Inventory Hash Management Tool` folder name.
  - `models.csv` is now the authority for model mapping; code must parse its
    headers, handle blank model-number alias cells, enforce current
    `Device Type` values, and deliberately extend the device-type folder mapping
    when new device types are added. All hardware-hash model folders must
    resolve to `<Manufacturer> <Model Name>` under the mapped device-type
    folder.
  - Active Directory department/location lookup is now in scope; implementation
    must handle `hallcounty.org/Computers` staging, recursive department
    `Computers` OU trees, unavailable AD, malformed `depts.csv`, blank prefix
    cells, any legacy `N/A` values, required `depts.csv` headers, and
    device-name prefix mismatches without blocking non-AD inventory work.
  - Application/error logging is centralized under the MINT filestore `logs`
    folder; implementation must append safely to one per-user daily file, avoid
    overwrites, sanitize the running identity in filenames, and report log-path
    failures in the UI.
  - Multiple operators may mutate the same shared library; implementation must
    use the D-030 short-lock/pre-write revalidation model.
  - Model/device-type/folder truth depends on `models.csv` and the shared object
    model; implementation must support `Model Number ##` aliases, searchable
    resolved model display names, existing nested special groups, and duplicate
    serials.
  - Decommission must handle collisions with newest-wins plus confirmation, and
    must include a Restore action that moves the hardware hash back to its
    warranty/model-resolved active location and removes it from the
    decommission master list.
  - V1 object graph will be rebuilt in memory from raw files; implementation
    must include refresh and per-target revalidation before mutating stale
    indexed data.
  - Portable local program copies can drift in version while acting on one
    shared data tree. V1 update distribution is manual pull from the filestore
    distribution source; the tool should show its version prominently.
  - HP and Dell warranty automation both depend on supported API access for
    reliable fleet-scale use; credential storage remains a later security
    decision once real key material exists. Do not define Dell/HP exact API
    fields, value shapes, display labels, or unavailable-field behavior until
    real API credentials and sample payloads exist. Getac form automation is
    feasible from the supplied test serial but still needs parser and
    sample-set validation; the Getac parser should capture only `SN`, `Model`,
    and `Warranty Expiration Date`.
  - Migration timing is intentionally on hold for Jeremy; do not invent a
    migration/data-copy workflow until he resolves it.
  - Network/vendor/future Graph features need stronger boundaries from
    deterministic local inventory functions.

## Recent Changes

- 2026-08-06 - New "Import Files" tab replaces the placeholder "Model
  Lookup" tab, recorded as D-094, plus a tab reorder (Search and
  Manage, Import Files, Upload Builder, Batch Extract, Validate and
  Organize, Warranty Lookup). Stages operator-selected hash files into
  the same shared Staging folder Batch Extract/Validate and Organize
  already use, classifies each via the same warranty-lookup pipeline,
  and imports via Validate and Organize's own unified fix-and-relocate
  mechanics -- reused via promotion (4 functions moved to Core modules)
  rather than reimplemented. Retired Validate and Organize's own
  `'Staging'` Scan Library option in the same round, closing a
  redundancy Jeremy flagged. Found and fixed a real latent bug along the
  way (a Staging-sourced file's relocation would have resolved a bogus
  destination path inside Staging itself, never reproduced live) and a
  second real bug introduced and caught within this same round (a
  startup-Timer code path that would have thrown on its first real use).
  Full detail in `AI-Project-Plan.md`'s D-094 entry.
- 2026-08-05 - Fixed a real D-089 regression, bigger tab headers/font +
  5px padding, Warranty vendor status auto-checks on startup, recorded
  as D-090. Some tabs were disappearing (blank at startup or after
  being clicked) -- root cause was D-089's tab-strip background fill
  painting outside the current tab's own bounds during its own
  DrawItem callback, which confuses Windows' own per-item paint
  tracking for neighboring tabs; moved to a separate Paint handler on
  TabControl itself. Tab headers/font now ~25% bigger with 5px of
  label padding, via a new Get-MintTabHeaderFont (used only inside
  DrawItem's own DrawString, never TabControl.Font itself, which would
  have enlarged text throughout the whole app) and new
  Set-MintTabControlHeaderSizing (called as plain code after TabPages
  exist -- confirmed live that wiring this to any TabControl event
  instead hangs/crashes the process, a real TabControl.SizeMode
  re-entrancy hazard). Warranty Lookup's Lenovo/Getac vendor status now
  auto-checks itself ~500ms after startup via a one-shot Timer instead
  of sitting on "Unknown" until Refresh -- reverses D-086's original
  choice. Full detail in AI-Project-Plan.md's D-090 entry.
- 2026-08-04 - Dark Mode visual overhaul, recorded as D-089. Full
  VS Code-style palette rewrite from Jeremy's own sampled hex values
  (Dark only -- Light untouched). Fixed all three areas Jeremy flagged
  as completely unthemed: the tab-strip background (the DrawItem
  handler used to only fill each individual tab's own rect, never the
  rest of the header row), ComboBox dropdown lists/arrow buttons
  (FlatStyle was never set anywhere in the codebase, so WinForms
  handed that chrome to the OS regardless of BackColor -- fixed on
  every standalone ComboBox and all 6 DataGridViewComboBoxColumns,
  including their transient editing controls), and button/tab/panel
  borders (new #2C2D2E outline color via Button.FlatAppearance, a new
  DrawRectangle stroke per tab, and a new Add-MintThemedPanelBorder
  helper replacing 3 native BorderStyle=FixedSingle panels that had no
  recolorable property). Native DataGridView/TextBox scrollbar chrome
  stays OS-default gray -- confirmed via live P/Invoke testing that the
  standard SetWindowTheme trick has no effect; going further needs
  undocumented Windows internals, which Jeremy explicitly chose not to
  pursue. Validate and Organize brought into Dark Mode (reversing
  D-080's exclusion, Jeremy's own updated call) -- found and fixed a
  real separate pre-existing bug along the way: its 4 summary-box
  colors were never refreshed on a theme toggle at all. Caught and
  fixed a real luminance/legibility regression via this project's own
  pre-existing D-062 test suite (a first-pass brightened red still
  wasn't bright enough against the dark background) before calling
  this done. Full detail in AI-Project-Plan.md's D-089 entry.
- 2026-08-04 - Search and Manage encompasses Staging; Upload Builder
  real implementation, recorded as D-088. Search and Manage's live grid
  now overlays Staging (cached, refreshed only at existing refresh
  points, never per keystroke) -- a Staging file becomes a real,
  fully-manageable row (Move/Decommission/Delete/edit/Batch Edit all
  work on it) with no change to the shared inventory index other tabs
  rely on. Tab.Upload.ps1, previously a placeholder, is now real: paste
  serials, resolve against the library and Staging, editable/batch-
  editable grid (in-memory only -- never touches source hash files),
  Build Upload File writes a multi-row canonical CSV to a new
  per-account HashUploadRoot location, account dropdown defaulting to
  "Personal" with a documented "ad"-suffix stripping rule. Caught and
  fixed 4 real bugs during testing, all documented at their fix sites.
  Full detail in AI-Project-Plan.md's D-088 entry.
- 2026-08-04 - Warranty Lookup follow-ups, recorded as D-087. Fixed
  Warranty Start/End STILL showing a time component after D-086's own
  fix -- that fix only recognized its own clean write format, not
  older rows already on disk from before it; now uses a general
  date/time parse that reformats any parseable shape. Manufacturer/
  Model/Machine Type/Source now show a blank cell instead of
  "(unavailable)" when the manufacturer did not report that field. New
  green check-circle/red X-circle icons on the Vendor Status pane
  (discovered mid-implementation that WinForms Label cannot host an
  inline image the way Button-family controls can -- fixed with a
  separate PictureBox per card). Removed the now-redundant "Vendor
  coverage today" label. Full detail in AI-Project-Plan.md's D-087
  entry.
- 2026-08-03 - "Check database first" checkbox, Vendor Status pane,
  Source labeling, date-only database writes, recorded as D-086. New
  Warranty Lookup tab checkbox (default checked) controls cache-first
  vs. always-live-and-refresh lookup behavior. New Vendor Status pane
  (Lenovo/Dell/HP/Getac/Surface -- Online in a new theme-aware green,
  Not Configured/Offline in the existing theme-aware red), checked only
  on demand (Refresh button or the start of a real lookup), never
  during tab init, to avoid slowing down app startup. A cache-hit
  result's Source now reads "Warranty Database" instead of the
  original vendor name; the on-disk CSV and Manual Verification rows
  are untouched. Fixed the database writing a stray time-of-day into
  Warranty Start/End. Caught and fixed a real bug during testing: a
  cache-hit row's warranty date displayed raw ISO text instead of the
  same MM/dd/yyyy format live-lookup rows use. Full detail in
  AI-Project-Plan.md's D-086 entry.
- 2026-08-03 - Lenovo false-negative fix, Decommission/Restore warranty
  integration, Warranty tab Copy Serial(s), recorded as D-085. Fixed a
  real pipeline-collapse bug in Get-MintLenovoWarrantyRecord that
  produced false "Not Found" results for genuine Lenovo devices with a
  single-element baseWarranties response (confirmed live: MJ0KVQGG).
  Decommission now pulls Warranty Start/End from the cache only (never
  a live call, since a batch can be large); Restore forces a fresh live
  lookup instead (a decommissioned device may have sat inactive long
  enough for cached data to go stale). New Copy Serial(s) button on the
  Warranty tab. A new sandboxed test caught and fixed a real bug in
  that same button's own handler (a double @() wrap broke every
  selection size). Full detail in AI-Project-Plan.md's D-085 entry.
- 2026-08-03 - Warranty cache relocated, recorded as D-084. Jeremy
  reported nothing being written after real use to
  'variables\devicewarrantydb.csv' -- the real D-082 path was actually
  Endpoint Inventory\Warranty Cache.csv, a different folder AND a
  different filename, so the report doubled as both a location bug and
  a new standing rule: Jeremy wants everything other than hash values,
  batch files, upload files, and machine-local files to live under
  variables\ going forward. $script:Paths.WarrantyCacheFile now points
  at DataRoot\variables\devicewarrantydb.csv -- the internal key name is
  unchanged, so no consumer or test fixture needed updating. Per
  Jeremy's own direction, no full regression battery for this one (a
  single-value path change, unchanged key, touches no consumer logic) --
  parse/BOM/ASCII verified and the new path confirmed to resolve to
  Jeremy's exact stated path, character for character.
- 2026-08-03 - Three staging-loop follow-ups to D-082, recorded as
  D-083. (1) Fixed a real gap: Batch Extract's duplicate check skipped
  the whole-library "does this device already exist elsewhere" search
  specifically for ReviewStaging rows, so a device already manually
  moved out of Staging could get a stale duplicate written back on a
  later re-extraction of the same vendor list -- removed the one guard
  that skipped it; the existing conflict-resolution dialog and status
  handling already covered ReviewStaging rows correctly with zero
  further changes needed. (2) New manual placement verification: the
  warranty cache (D-082) gained a Verified Folder Name column and a
  'Manual Verification' Source -- an operator confirming an unsupported-
  vendor (Dell/HP/Microsoft) device's folder, via Move or a new Verify
  Placement button, means the Fix tool never re-flags or re-checks that
  device again, and never attempts a live lookup for it either (a cache
  hit already short-circuits that). (3) New generic Sort Variable Files
  tool: grouptags.csv gained a header row (unifying every variable file
  onto one read/write pair), a new Invoke-MintVariableFileSort sorts any
  headered variables\*.csv file by its first column with reference-based
  no-op detection, and a new checklist dialog (driven by Jeremy's own
  variablesortlist.csv) sorts multiple files at once behind one shared
  backup archive. Found and fixed one real regression via the battery
  itself: New-MintWarrantyRecord (the shape every LIVE lookup returns)
  was missing the new VerifiedFolderName field, throwing a
  PropertyNotFoundException under StrictMode for every real (non-cached)
  lookup -- fixed by adding the field to its base shape. New
  mint_staging_loop_and_sort_test.ps1 (40/40) added to the battery (now
  40 suites), clean except the already-known SendKeys/hidden-window
  flaky category.
- 2026-07-30/31 - Tool consolidation across Search and Manage and
  Validate and Organize, recorded as D-082: reduced duplicated tooling
  by moving View Format Issues, the standalone Fix Import Format
  button, Move to Model Folder, and the passive Duplicate column off
  Search and Manage onto Validate and Organize (Batch Edit's own "Fix
  Import Format only" mode stays on Search, untouched). Three
  infrastructure pieces this surfaced: a new shared warranty-lookup
  cache (Core.WarrantyCache.ps1) in front of every real vendor lookup
  (a real lookup has been measured taking up to 61 seconds) -- cache
  hits are instant, and only a genuine successful result is ever
  persisted, never a negative one; a new shared Staging folder for hash
  files the program cannot yet place (mostly Dell/HP/Microsoft until
  those vendor lookups exist), which fully replaces Batch Extract's old
  Review Staging folder and is deliberately excluded from an "All" Scan
  Library sweep and from devicetype.csv, reachable only via a new
  explicit dropdown entry; and a redesigned unified fix tool that
  sanitizes the serial, preserves only fields already present in the
  file, and relocates it to the warranty-resolved Model Folder in the
  same pass, with a safe copy-verify-then-delete relocation sequence
  and a cache-miss/lookup-fails file left in place and flagged for
  manual review rather than ever auto-relocated to Staging. The old
  three-way fix button layout (Auto Fix All Issues/Fix Selected
  Issues/Reformat) collapsed to two, both calling the same unified
  logic. New mint_d082_features_test.ps1 (67/67) covers the cache,
  Staging exclusion/inclusion, the Device Type filter (with an explicit
  regression check that scanning a specific Device Type does not
  corrupt that field, the exact bug class identified during planning),
  the unified fix tool's cross-folder relocate-with-verify, the
  cache-miss-flag-not-Staging behavior, Edit Model Folders on Validate
  and Organize, and a rewrite of a retired report-write-failure-
  continuation test against the new call site. Full 38-suite battery
  clean except the two already-known pre-existing SendKeys/hidden-
  window flaky items.
- 2026-07-30 - Applied one permanent, project-wide grid design standard
  to all 4 persistent grids (Search's liveGrid/decommissionedGrid,
  Batch Extract's resultsGrid, Validate and Organize's resultsGrid),
  recorded as D-081. Jeremy's 11-point spec: sortable by every column
  (already true everywhere), header-or-content-based sizing with 15px
  padding, user-resizable even below that minimum (a deliberate reversal
  of D-067's own stricter lock, confirmed directly with Jeremy before
  touching anything), column reordering and hide/show via right-click
  (both judged low-risk after confirming zero positional column access
  anywhere in the codebase), and settings persisting across sessions and
  repopulates -- the last three were explicitly left to Claude's own
  risk judgment, with permission to skip; all three were implemented.
  Persistence extends the existing local MINT-Settings.json (Dark
  Mode's own file) with a new Grids object rather than a second file.
  Two transient dialog grids (Batch Extract's conflictGrid/editorGrid)
  were deliberately excluded from reorder/hide/persistence -- they're
  rebuilt fresh every dialog open, nothing to persist. Found and fixed
  two real bugs via the new test before they ever reached the app: a
  dynamic PSCustomObject property assignment that throws under
  StrictMode (silently swallowed by an existing never-throw try/catch,
  so nothing was actually being saved), and a restored column width
  being silently overridden because a freshly built grid is still in
  continuous AllCells auto-sizing until its first populate. New
  mint_grid_design_standard_test.ps1 (37/37) exercises the REAL
  production functions via AST extraction, not a reimplementation.
- 2026-07-30 - Validate and Organize redesigned to a review-and-select
  model, recorded as D-079 (plus D-077-style promotions this required).
  Jeremy reported he does not want scan-and-auto-fix bundled together --
  he wants to scan (read-only), review the full results, and choose
  fixes deliberately, matching the actual Tab Mockups image's top-left
  panel. Scan Library's path is now editable (defaults to the real
  configured root); scanning no longer touches the shared inventory
  index used by Search and Manage, building its own local result set
  instead so an overridden scan root can never corrupt that other tab's
  view. Three separate fix actions: Auto Fix All Issues and Fix
  Selected Issues both reuse the existing (unchanged) auto-fix pass
  with a different scope; new Reformat does a deeper cleanup that also
  renames a file to match its own Device Serial Number when they
  disagree -- something the safe auto-fix deliberately never does on
  its own. Move now opens the same interactive Device Type + Model
  Folder picker Search and Manage uses (promoted to a new
  Core.Dialogs.ps1, the first shared cross-tab dialog module) instead
  of silently auto-moving, and Delete lost its duplicate-only gating.
  Grid widened to 7 sortable columns showing every scanned row, not
  just flagged ones; summary became four colored counter boxes
  matching the mockup. Found and fixed a real PowerShell gotcha live
  via testing: a bare `$name?` inside a double-quoted string is parsed
  as a reference to a variable literally named `name?` (the `?` gets
  consumed as part of the variable name), not `$name` followed by a
  literal question mark -- needs a backtick-escaped `` `? `` wherever
  this pattern occurs, worth remembering for future work in this
  codebase.
- 2026-07-30 - Fixed a real counting bug in Validate and Organize
  (D-079's own redesign), recorded as D-080. Jeremy scanned the real
  library and reported "383 scanned, 200 clean + 0 fixed + 8 flagged =
  208 accounted for" and GETAC B360 Gen 3 files showing Format "Needs
  Fixing" next to Issue "None" -- both symptoms of the same root cause:
  a non-canonical, auto-fixable file with no other problems got zero
  flag reasons (deliberately withheld) and so was counted as neither
  Clean nor Flagged, vanishing from the summary. FlagReasons now always
  reflects every current problem (including a new filename/serial-
  mismatch reason for the equivalent gap on an otherwise-canonical
  file); the summary counters are computed in one pass with explicit
  Flagged > Fixed > Clean priority so they always sum to Scanned.
  Issue column also color-coded per the same report: duplicate issues
  red, other issues blue, "None" default-colored -- static colors, not
  theme-aware, since Jeremy asked to hold off on Dark Mode for this tab
  for now. New mint_validate_count_fix_test.ps1 (28/28) reproduces the
  exact GETAC-style scenario. Tab.Validate.ps1 only (v3.0.0 -> v3.1.0).
  Full 36-suite regression battery clean except the same already-known
  pre-existing flaky items.
- 2026-07-30 - Validate and Organize (Tab 1) built for the first time,
  recorded as D-078 (plus D-077, the Core.FileOps.ps1 promotion it
  required). Jeremy asked to build the tab, explicitly asking for
  pre-existing modules to be reused and new code to stay modular. Full
  Section 6 Tab 1 spec: scans the whole hash library, auto-fixes
  correctable format issues (one shared backup zip + run report per
  scan), flags non-correctable problems (duplicate serials, misplaced
  files, serial/hash mismatch, invalid/blank hash) for guided
  resolution. Misplaced-file detection uses a real warranty lookup for
  every eligible file (Jeremy's explicit choice over a cheaper
  local-only heuristic), deduped by serial for the whole scan. Most of
  the underlying infrastructure already existed (full-library scan,
  duplicate detection); the real new work was two missing format checks
  (blank/invalid-base64 Hardware Hash -- a real detection gap fix that
  also affects Search and Manage's own grid), the misplaced-file check,
  and promoting three per-file movers out of Tab.Search.ps1 into a new
  Core.FileOps.ps1 (D-077) since this was the first time a second tab
  needed them. New mint_validate_smoke_test.ps1 (21/21) and
  mint_validate_organize_test.ps1 (19/19) cover real live warranty
  lookups (including a real misplaced-file Move click-through that
  physically relocates a file on disk), dedupe-by-serial call counting,
  a real Delete click-through, and no-batch-abort on a locked file.
  Fixing the base64 check exposed that ~19 existing test fixtures used
  fake non-base64 "HASH1"/"HASHDATA1"-style placeholder values --
  fixed by base64-encoding each token consistently (or, where built via
  loop-variable string interpolation, wrapping the whole expression in
  a runtime base64-encode call instead of a blind text substitution,
  which would have produced invalid base64 mid-string).
- 2026-07-29 - Move to Model Folder redesigned (Device Type + Model
  Folder, multi-select) and the Desktop/Laptop/GETAC folder-name
  translation layer removed, recorded as D-076. Jeremy asked for a
  Device Type dropdown alongside the existing Model Folder dropdown
  (previously locked to the selection's current Device Type, so a
  Desktop could never be moved to a Laptop-type folder), sourced from
  a new `variables\devicetype.csv`, plus multi-select support gated on
  every selected device sharing the same current Device Type + Model
  Folder. Separately, Jeremy renamed the real Hash Library's top-level
  folders (Desktops -> Desktop, Laptops -> Laptop, Getacs -> GETAC) to
  match devicetype.csv's own values exactly, so every internal
  singular<->plural translation map in MINT was removed -- the Device
  Type value is now used directly as the real folder name everywhere.
  New Show-MintMoveToModelFolderDialog, Test-MintSearchSelectionSharesModelFolder,
  and Invoke-MintMoveSingleFile (mirrors Invoke-MintDecommissionSingleFile's
  established per-file result-object shape). New
  mint_move_to_model_folder_test.ps1 (28/28) drives the real dialog
  end-to-end via a Timer polling Application.OpenForms, confirming the
  cascading Device Type -> Model Folder refresh and real single/multi
  file moves on disk. Fixing this exposed 4 unrelated pre-existing test
  fixture gaps (a hard StrictMode dependency on a new required Paths
  key across 22 fixtures, 5 files with stale hardcoded 'Desktops'/
  'Laptops' literals, an incomplete synthetic test object, and a
  missing MessageBox auto-dismiss in an unrelated D-057 test) -- all
  fixed so the full regression battery stays meaningful.
- 2026-07-29 - AD Department/Location now shows a subfolder under a
  department's Computers container, recorded as D-075. Jeremy asked
  that a computer in a real subfolder like
  `.../MIS/Computers/Mobile` display "Department: MIS - Mobile" instead
  of just "Department: MIS". Verified live against real AD rather than
  assuming the structure: confirmed "Computers" is a real, consistent
  standard child OU across every department checked (Tax Commissioner,
  Sheriff, Tax Assessors, MIS), and that the real MIS/Computers/Mobile
  subfolder Jeremy described genuinely exists. New ComputersSubfolder
  output on Resolve-MintDeviceAdLocation, appended to the display text
  only when non-empty -- a device directly in Computers (the common
  case) is unaffected. Verified against 2 real known devices (one in
  the real Mobile subfolder, one directly in Computers) through a full
  real end-to-end Check AD button click, producing exactly "Department:
  MIS - Mobile" and "Department: MIS" respectively.
- 2026-07-29 - Fixed a real, wide-reaching data integrity bug: Batch
  Extract was silently writing Manufacturer/Model text into Group
  Tag/Assigned User on extracted hash files, recorded as D-074. Jeremy
  reported a new file (MJ0L3BPR) showing manufacturer/model values in
  those fields under Search and Manage. Investigation found the real
  cause: the real source batch file
  ("AllAutopilotHashes - Copy.csv") has the header "Device Serial
  Number,Windows Product ID,Hardware Hash,Manufacturer Name,Device
  Model" -- a genuinely different vendor export shape, not Group
  Tag/Assigned User at all -- and Read-MintVendorBatchFile's old purely
  positional read never checked what the header actually said before
  treating columns 4/5 as Group Tag/Assigned User. Given the severity,
  scanned the entire real live Hash Library (384 files) for this exact
  corruption signature before writing any code: 126 of 384 real files
  are already affected, including old files that clearly predate this
  session by a long margin. Fixed Read-MintVendorBatchFile to check the
  header's own column 4/5 text and only carry those columns through
  when they genuinely look like Group Tag/Assigned User; otherwise
  leaves both blank and surfaces a real MessageBox warning. **The 126
  already-corrupted real files are NOT touched by this fix** -- this is
  a code fix for future extractions only; Jeremy needs to decide how to
  remediate the already-affected files, and Claude will not modify
  production data without his explicit direction.
- 2026-07-29 - Fixed a real Getac warranty-lookup parsing bug plus a
  related ReviewStaging gap, recorded as D-073. Jeremy reported a real
  Getac B360 (serial RMC03B0199) with no folder despite B360 already
  existing in models.csv, and that clicking "Create Folders" did not
  create it. A real live lookup confirmed Jeremy was right that Getac's
  site lists it as a plain B360 -- but the real parse result was
  Found=False, a genuine bug: this device's warranty expired
  2022-Dec-15, and Getac wraps an expired/highlighted date in
  `<span class="txt-highlight-red">`, which the original regex's
  `[^<]+` capture could not cross, silently failing the WHOLE match (not
  just the date). Fixed by capturing the entire inner content of the
  date cell and stripping any inner tags in code, rather than assuming
  plain text. Separately, tracing what happens once an operator manually
  classifies such a row (possible since D-072 widened editing) surfaced
  a second gap: three downstream functions (folder creation, duplicate
  checking, the Extract write) all still assumed
  Status -eq 'ReviewStaging' always means "goes to the flat holding
  area" -- no longer true once its fields are edited. Fixed with a new
  Update-MintExtractReviewStagingPromotion, promoting Status to
  NeedsFolderReview the moment classification is completed, so all
  three downstream functions already handle it correctly with no
  further changes. Real end-to-end reproduction confirms Create Folders
  Now now genuinely creates the folder. Full 30-suite regression battery
  re-run.
- 2026-07-29 - Batch Extract: four bundled real first-use reports,
  recorded as D-072. (1) "Device Type dropdown doesn't work" and (2)
  "Batch Edit button remains locked out even when multiple files are
  selected" -- extensive static/precedence investigation found no code
  defect, so asked Jeremy two clarifying questions instead of continuing
  to guess; his answers ("the arrow is visible, there is just no action
  at all when I click on it" / "not sure" which statuses were selected)
  pointed to real interaction with ReadyToExtract rows, correctly
  read-only/ineligible under the OLD NeedsFolderReview-only design (a
  read-only DataGridViewComboBoxCell still paints its dropdown arrow but
  silently refuses to enter edit mode -- indistinguishable from
  "broken"). Jeremy confirmed he wants editing available on any row, not
  just to complete a blank one. Widened Device Type/Manufacturer/Model
  inline editing and Batch Edit gating to every row except the 5
  terminal post-Extract statuses. (3) Manufacturer and Model are now
  typeable dropdowns (results grid ComboBoxColumns, Batch Edit dialog
  ComboBoxes), sourced from a new variables\manufacturer.csv and
  models.csv's Model Name column -- mirrors Search and Manage's
  established Group Tag column pattern exactly, including the
  EditingControlShowing DropDownStyle+TextChanged unlock (confirmed via
  a real free-typed-edit test that this is not optional -- without it a
  free-typed value silently reverts on commit) and the DataError safety
  net. (4) ReviewStagingRoot moved from under DataRoot to under
  HashInventoryRoot at Jeremy's request. Two existing test suites had
  assertions that directly encoded the OLD restriction and were updated
  (not left coincidentally passing); a new 16-assertion suite covers the
  dropdown behavior specifically. Full 28-suite regression battery
  re-run.
- 2026-07-28 - Fixed a real Getac model-name matching bug that had
  existed since Getac support was first built (D-053), recorded as
  D-071. Jeremy directly corrected an unverified claim made in D-070's
  own "Remaining risks" note (that Getac B360G2/B360G3 were genuinely
  new/unmapped models, same as the real Legion T5 30AGB10 gap sitting
  next to them): "The Getac B360 Gen 2 and Gen 3 do exist in
  models.csv." Re-checking directly (not assuming) confirmed Jeremy was
  right -- models.csv has "B360 Gen 2"/"B360 Gen 3" rows already. A real
  live lookup for the batch's actual Getac serials showed the raw page
  text is literally "B360G2"/"B360G3" -- the generation number
  concatenated directly onto the model with a bare "G", no space, no
  word "Gen" -- and the Getac provider had never had ANY model-name
  normalization applied to it (unlike Lenovo's own dedicated function),
  so it had never been able to match a generation-numbered Getac model
  against models.csv through this pipeline. Fixed with a new, narrow
  `ConvertTo-MintGetacModelName` normalizer. Full 158-row batch
  NeedsFolderReview count dropped from 4 to 2, and the sole remaining
  row (Legion T5 30AGB10) is confirmed genuinely absent from models.csv
  this time, not assumed.
- 2026-07-28 - Fixed two more real Lenovo product-name parsing bugs
  found by re-testing D-069's own fix against Jeremy's FULL real
  158-row batch file, recorded as D-070. The full-batch NeedsFolderReview
  count was still 19 even after D-069 landed; instrumenting the
  conversion function against the real data revealed two more distinct
  raw shapes: newer models (ThinkPad T14 Gen 5/Gen 6, ThinkPad T16 Gen 4)
  report the device-type keyword in PLURAL form ("Laptops" not "Laptop"),
  which the existing pattern's keyword list didn't match, so the plural
  word fell through into a more permissive fallback pattern and stayed
  embedded in the model text; some Legion-family devices report a
  redundant leading "Lenovo " word baked into the raw text itself
  ("Lenovo Legion T5 26IAB7 - Type 90SU"), which models.csv's Model Name
  convention never includes. Fixed both: an optional plural "s" on the
  device-type keyword, and an unconditional leading-"Lenovo "-word strip.
  Verified against the real raw strings for 4 more real serials; full
  158-row batch NeedsFolderReview count dropped from 19 to 4, and the
  remaining 4 (Legion T5 30AGB10 x2, Getac B360G2/B360G3 x1 each) are
  confirmed genuinely absent from models.csv, not a matching bug.
- 2026-07-28 - Fixed a real Lenovo model/folder matching bug reported by
  Jeremy after confirming D-068's fix worked, recorded as D-069. Jeremy's
  report: real ThinkPad T14 Gen 2 devices from his real batch file were
  showing as "ThinkPad T14 Gen 2 (Type 20W0, 20W1)" and landing on
  NeedsFolderReview, despite the folder and the plain models.csv row
  already existing. A first-pass fix (strip a trailing "(Type ...)"
  parenthetical) passed its own isolated unit test but did NOT take
  effect in a real end-to-end reclassification test -- investigation
  found the real raw Lenovo product text is actually "T14 Gen 2 (Type
  20W0, 20W1) Laptop (ThinkPad) - Type 20W0", with the "(Type ...)" text
  embedded MID-STRING, not just trailing; the function's existing brand-
  parenthetical pattern ran first and its own lazy match swallowed the
  parenthetical whole before the new strip (placed after that pattern)
  ever got a chance to run. Fixed by moving the strip to run first,
  unconditionally, before either existing pattern. Verified against all
  4 real known T14 Gen 2 serials: all now resolve to ReadyToExtract with
  the correct real destination folder.
- 2026-07-28 - Fixed the REAL cause of Batch Extract's "only 1 entry"
  report, recorded as D-068. Jeremy sent the identical report again,
  verbatim, twice in one message, AFTER D-067's progress-feedback fix
  had already shipped -- proving that fix (which does resolve the
  "looks frozen" perception problem) was not actually sufficient; a
  second, separate, deeper bug was still silently truncating the real
  results grid to 1 row on every real run. Investigated exhaustively:
  confirmed the real 158-row file classifies correctly in four
  different ways (headless; simplified UI with sandbox data; simplified
  UI with real production models.csv; manually through the real
  New-MintMainForm) -- only the REAL button click, through the REAL
  main window, with the Batch Extract tab actually selected/visible,
  reproduced the crash, deterministically, 3 times in a row. A closure-
  safety theory was tested and fixed defensively but did NOT resolve
  it. The actual cause, found by instrumenting the real grid-populate
  loop line-by-line and inspecting the full exception (a
  CmdletInvocationException, proving a PowerShell event handler fired
  from inside a .NET method call): WinForms auto-selects the first row
  added to a currently-empty, visible grid as a side effect of
  Rows.Add() itself, firing SelectionChanged before the very next
  statement sets that row's own Tag -- so the selection-handling code
  read a $null Tag and then evaluated a property on it, which
  PowerShell's strict mode rejects. Fixed at the shared selection-
  reading helper (also used by Search and Manage) so a selected row
  without a Tag is simply skipped rather than ever reaching a caller.
  Verified via a new fast, deterministic unit test plus three separate
  re-runs of the exact real crash scenario against Jeremy's own file,
  all clean, plus the full 24-suite regression battery.
- 2026-07-28 - Grid columns now self-heal to content width regardless of
  app startup timing, and Batch Extract shows live progress during long
  real classification runs, recorded as D-067. Jeremy's real first-use
  report against D-066's own grid-resize work: Search and Manage's
  columns no longer sized to content at all, Batch Extract's still would
  not resize, and processing a real 158-row/131-distinct-device
  production file ("AllAutopilotHashes - Copy.csv") "only came up with 1
  entry." Root-caused via a real test reproducing the entry script's OWN
  actual startup order (New-MintMainForm runs Initialize-SearchTab's own
  initial-load populate BEFORE the form is ever Show()'d) -- confirmed
  every D-066 test missed this because every test harness always
  Show()'d its Form before the first populate first, unlike the real
  app; AutoResizeColumns() silently no-ops with no real window handle,
  permanently freezing columns at their tiny default. Fixed by having
  Set-MintGridColumnWidthsToContent defer itself via the grid's own
  HandleCreated event (self-healing regardless of timing) and by
  implementing Jeremy's own more precise restated rule using a real
  DataGridViewColumn.MinimumWidth floor (columns can grow freely but
  never shrink below the true content-driven minimum). Separately,
  investigated the real production file directly (reachable from this
  environment): it parses to all 158 rows correctly; the actual cause
  was a real warranty lookup measured taking 61 real seconds, and with
  131 distinct devices and zero prior progress feedback on a frozen UI,
  a genuinely-still-working multi-minute run looked indistinguishable
  from a hung tool. Fixed by adding an optional progress callback to the
  classification loop, wired to update the wait window's live text, with
  both call sites now disabling Process File/Browse/Edit Model Folders
  for the run's duration since a pumped UI can now receive a second
  click mid-run. Verified via 33 new test assertions across 3 new test
  files (including one that reproduces the real app startup sequence
  end-to-end and is confirmed to genuinely fail against the OLD
  implementation first), plus the full 23-suite regression battery
  clean except this project's already-documented pre-existing SendKeys/
  window-focus flakiness.
- 2026-07-28 - Six Batch Extract follow-ups plus a Search-and-Manage-wide
  grid fix, recorded as D-066. Jeremy sent seven items in one message
  after his first real look at D-065's Batch Extract tab: (1) grid
  columns sized to content were also permanently locked against manual
  resize -- fixed for every MINT grid, with a genuinely subtle WinForms
  snap-back bug (a column's manual-width backing field never updates
  while continuous AllCells auto-sizing is active) found and fixed via
  a failing test, not assumed correct; (2)/(3) the Status column now
  reads as spaced words, and "Skipped" carries one of three specific
  reasons (Blank Serial/Duplicate/Parse Error) rather than Jeremy's
  suggested single "Skipped - Duplicate" label -- his assumption that
  duplicate was the only cause was checked against the real code and
  found incorrect, and reported back rather than complied with
  literally; (4) a new "Batch Edit..." button mass-sets Device
  Type/Manufacturer/Model across every selected NeedsFolderReview row,
  with a live read-only Destination Folder preview (confirmed with
  Jeremy up front); (5) a new "Copy Serial(s)" button reuses a newly
  generalized version of Search and Manage's own D-056 gapped-
  selection-order fix; (6) a new "Edit Model Folders..." button
  (works with or without a batch loaded) opens an add/edit/delete-row
  grid editor for models.csv itself, pre-seeded with suggested new
  rows for the batch's own unmapped devices, auto-re-classifying the
  batch on save unless it already has an Extracted row. Item 7
  ("Lenovo type should be ignored") was investigated against the real
  models.csv and matching code, found to already be true, and
  confirmed with Jeremy as needing no code change. One real bug found
  and fixed via a failing test: a leading comma mistakenly applied to
  a plain property assignment (not a return statement) silently
  double-wrapped an array in a way that was masked during an initial
  manual check by PowerShell's friendly array-property-forwarding but
  broke the real save path, which uses a stricter explicit property
  lookup. Verified via two new test files (64 assertions total,
  including real nested-modal-dialog automation, a real live Getac
  warranty lookup, and a real end-to-end backup+save+re-classify run),
  the full 20-suite regression battery clean except the one pre-
  existing SendKeys flake, and an extended cross-process smoke test
  confirming all three new buttons are genuinely visible in the live
  running app.
- 2026-07-27 - Batch Extract tab fully implemented, recorded as D-065.
  Jeremy: "Let's go ahead and work on the batch extract tool," followed
  by a detailed spec (prefix stripping, minimal CSV quoting, warranty-
  lookup-based model detection, an editable folder-creation review grid
  with a Device Type/Manufacturer/Model/live-path-preview layout,
  automatic folder creation plus per-device hash extraction on Extract,
  post-extraction verification, and a per-duplicate override/ignore
  function). Three ambiguities were confirmed with Jeremy before
  building: unidentified devices go to Review Staging; "upon file
  upload" means one vendor batch CSV, not a multi-file picker;
  duplicate-serial conflicts are checked for and resolved BEFORE any
  file is written. Built via a written, user-approved plan (research +
  a Plan-agent design + verification against the real code) in four
  phases: (1) parsing/prefix-stripping/warranty-lookup orchestration,
  headless, verified against real live Lenovo and Getac endpoints; (2)
  the review grid and folder creation; (3) duplicate detection, the
  Overwrite/Ignore dialog, writing, and post-write verification; (4)
  full UI wiring, the regression battery, and this documentation. Reused
  existing functions rather than rebuilding: New-MintSerialNumber
  (prefix stripping), Write-MintCanonicalHashFile
  (minimal/optional CSV quoting, D-047), Resolve-MintWarrantyLookup
  (model detection -- hash decode was never built and stays out of scope
  per Jeremy's own instruction), Find-MintInventoryFilesBySerial
  (duplicate detection). New shared functions: Read-MintVendorBatchFile
  (Core.Csv.ps1), Get-MintResolvedModelFolderName extracted from
  New-MintDeviceModel's D-039 logic plus New-MintExtractRowPlan
  (Core.Domain.ps1), Get-MintModelDestinationFolder/
  Resolve-MintModelDestinationPath promoted out of two duplicated inline
  call sites in Tab.Search.ps1 (Core.Inventory.ps1). Get-MintPluralizedNoun
  promoted from Tab.Search.ps1 to the entry script so Batch Extract's
  summary line could use it without one Tab module depending on
  another's load order. Found and fixed two real bugs via live testing:
  DataGridView.ReadOnly=true at the grid level silently overrides any
  column/cell-level ReadOnly=false (the review grid's per-row editable
  cells were unreachable until fixed, matching Search and Manage's own
  established pattern); a shared-pitfall-P29 bare array return in the
  folder-creation function collapsed to $null on an idempotent
  nothing-to-create second run. Verified extensively: 33+20+20+4
  assertions across the four build phases (including a real Extract
  button click with a real auto-answered duplicate-resolution dialog,
  and opening a backup zip to confirm an overwritten file's original
  content was genuinely preserved); after fixing four existing
  regression tests that needed the same Get-MintPluralizedNoun stub
  already used elsewhere, 347 of 348 assertions clean across all
  eighteen suites (the one failure is the same pre-existing SendKeys
  flakiness, unrelated); a real cross-process smoke test against the
  live production app, working around a newly-discovered side finding
  (D-062's OwnerDraw tab theming makes tab headers invisible to UI
  Automation, likely also to screen readers -- flagged as a separate,
  out-of-scope accessibility concern) by driving the real Ctrl+Tab
  keyboard shortcut, confirmed every real Batch Extract control
  genuinely visible on screen.
- 2026-07-27 - Group Tag column made sortable, recorded as D-064. Jeremy
  asked: "For some reason I'm not able to sort by group tag. Is that
  deliberate or unavoidable?" Answer: neither. Root cause, confirmed via
  a live isolated test rather than assumed:
  `DataGridViewColumn.SortMode` defaults to `Automatic` for a plain
  `DataGridViewTextBoxColumn` but defaults to `NotSortable` for a
  `DataGridViewComboBoxColumn` -- Group Tag is the only combo column in
  this grid (made one by D-055 so it could offer a
  `variables\grouptags.csv` choice list), so it silently never got the
  click-to-sort behavior every plain-text column around it already had.
  The same isolated test confirmed explicitly setting
  `SortMode = Automatic` on a `DataGridViewComboBoxColumn` works with no
  exception and sorts correctly, ruling out "unavoidable WinForms
  limitation" as the explanation. Fixed in `Modules\Tab.Search.ps1`
  (v1.8.1 -> v1.8.2) with one explicit `SortMode` assignment at column
  creation, plus a comment explaining why it is there (so a future
  reader does not mistake it for a redundant default and remove it).
  Verified via a real functional test against `Initialize-SearchTab`'s
  actual live grid and a 3-file sandbox with distinct Group Tag values:
  the real column's `SortMode` reads back `Automatic`; calling
  `DataGridView.Sort()` against it (the same call WinForms' own header-
  click handler makes) ascending places the blank tag first, then
  `IT-DESKTOPS`, then `IT-LAPTOPS`; descending reverses correctly;
  sorting by Group Tag did not disturb the Serial column's own
  independent sortability afterward -- 6 of 6 assertions, 2 clean runs.
  Re-ran the complete existing regression battery (batch edit, round-2,
  inline-edit, copy-serial, assigned-user-domain, batch continuation,
  remove-assigned-users batch, model-lookup/delete, summary wording,
  dynamic summary, Dark Mode dialog/grid theming) -- 208 of 209
  assertions clean (the one failure is the same pre-existing,
  previously-documented SendKeys/OS-focus flakiness, unrelated to this
  change).
- 2026-07-24 - Summary bar's file-count wording changed from a bare
  "N files" to "N files found," recorded as D-063. Jeremy: "Where it
  says '&lt;number&gt; files' lets change that to '&lt;number&gt; files found'."
  One-line change in `Update-MintSearchSummary`
  (`Modules\Tab.Search.ps1` v1.8.0 -> v1.8.1); the shared
  `Get-MintPluralizedNoun` helper itself was untouched, so its direct
  unit test needed no changes, but the D-060/D-061 summary-wording
  suites assert the actual rendered `SummaryLabel.Text` and needed
  their hardcoded expected strings updated to match this intentional
  wording change -- updated and re-ran both against the real code (15
  of 15, 16 of 16, both clean). Swept every other test file for
  hardcoded "N files" assertions that might have been missed -- found
  none.
- 2026-07-24 - Dark Mode checkbox fixed after shipping invisible,
  recorded as a same-day follow-up to D-062. Jeremy: "Where is the
  darkmode toggle? I don't see it." Root cause: the checkbox was
  positioned via `Location(970, 5)` + `Anchor = Top|Right` set BEFORE
  its containing panel was actually docked/parented, so the Right
  anchor's "distance from the parent's edge" was computed against the
  panel's un-docked DEFAULT width (200px, a bare `Panel`'s
  `DefaultSize`) instead of its real ~1084px docked width -- once the
  panel resized to its real width, the anchor preserved that stale
  distance and pushed the checkbox to X=1880, about 800px past the
  panel's actual right edge and entirely clipped/invisible, even though
  the control genuinely existed and worked correctly in every other
  respect. This is exactly why the earlier full-app smoke test's
  presence check (UI Automation `FindFirst` by name) passed -- an
  automation tree walk is not limited to visible bounds, so it found
  the control fine despite it being off-screen. Confirmed via an
  isolated repro (a throwaway form reproducing the exact same
  Panel/Dock/Anchor/Location sequence, showing the checkbox landing at
  X=1880 in a 1084px-wide panel) before touching product code. Fixed
  in `MIS Inventory Navigation Tool.ps1` (v1.0.7 -> v1.0.8) by
  replacing `Location`+`Anchor` with `Dock = Right` on the checkbox
  itself, which has no parenting-order timing dependency -- re-ran the
  same repro after the fix and confirmed the checkbox now lands flush
  at the panel's real right edge. Closed the test-coverage gap that let
  this ship: added bounds assertions (`checkbox.Right -le panel.Width`,
  `checkbox.Left -ge 0`) to the in-process `New-MintMainForm` test (16
  of 16, up from 14, both new assertions passing), and a real
  on-screen `BoundingRectangle`-within-window check via UI Automation
  to the full-app cross-process smoke test (10 of 10, up from 8, 2
  clean runs against the real running app, both startup scenarios) --
  neither test had previously checked WHERE a control actually renders,
  only whether it exists and functions. Re-ran `Core.Theme.ps1`'s unit
  suite and the `Tab.Search.ps1` dialog/grid suite again to confirm no
  new regressions -- all still clean (40/40, 8/8).
- 2026-07-24 - Whole-app togglable Dark Mode added, saved locally per
  installation, recorded as D-062. Jeremy asked: "Is there a way to
  allow dark mode, similar to the systems settings, and it be togglable
  (but the option saved locally within the installation so it persists
  between launches)?" New `Core.Theme.ps1` (v1.0.1), loaded first, right
  after `Core.Logging.ps1`. `Get-MintThemePalette` returns Light
  (captured live from a fresh `DataGridView` plus documented
  `SystemColors`, so it is byte-identical to the app's original
  appearance -- not guessed) or a hand-picked Dark palette.
  `Set-MintControlTheme` recursively walks a control tree and dispatches
  on runtime type, deliberately leaving per-cell flag colors and the
  path-warning label alone (business-meaning colors, refreshed
  separately). `TabControl` headers cannot be recolored via `BackColor`
  at all, so `Enable-MintTabControlThemedDrawing` switches to
  `OwnerDrawFixed` and paints tabs manually -- a disclosed trade-off
  that also changes Light mode's tab rendering (no native hover
  chrome). The preference persists to `MINT-Settings.json` next to the
  program's own files (`$script:ProjectRoot`), NOT the shared filestore,
  since this is a per-machine display preference, not shared data. The
  entry script (v1.0.6 -> v1.0.7) gained a "Dark Mode" checkbox on the
  main shell (top-right, above the tabs) that applies live via
  `Invoke-MintThemeChange`, no restart required; `Tab.Search.ps1`
  (v1.7.0 -> v1.8.0) themes its three dialogs on open and uses
  `Get-MintThemeErrorColor` instead of hardcoded red for flagged cells;
  `Tab.Warranty.ps1` (v1.1.0 -> v1.2.0) does the same for "Not Found"
  rows plus a new live-refresh helper. Scope: Search and Manage,
  Warranty Lookup, and shared shell chrome only -- the four remaining
  placeholder tabs will inherit theming automatically once built.
  Found and fixed two real bugs via live testing, not assumption: (1) a
  plain scriptblock event handler referencing a LOCAL (non-`$script:`)
  variable from an already-returned function throws under
  `Set-StrictMode -Version Latest` once it fires -- an extension of
  shared pitfall P28, not the same finding; fixed by having the Dark
  Mode checkbox's handler read everything through a new
  `$script:MintMainShellState` container plus `$this`. (2) A
  `Graphics.DrawString` call passed a `Rectangle` where only
  `PointF`/`RectangleF` overloads exist, throwing an unhandled exception
  dialog on every single real app startup, in either theme -- found only
  by a full-app cross-process smoke test against the real production
  entry script (an earlier off-screen in-process unit test never
  triggered the real paint pass that exposed it); fixed by explicitly
  constructing a `RectangleF` before calling `DrawString`
  (`Core.Theme.ps1` v1.0.0 -> v1.0.1). Verified: all four changed/new
  files parse clean (0 AST errors), UTF-8 BOM, ASCII-only.
  `Core.Theme.ps1` unit suite 40/40 (2 runs); `New-MintMainForm`
  AST-extraction suite (exercising the REAL production function) 14/14
  (3 runs), including a real checkbox toggling the real form live,
  persisting to and reading back the real settings file, and a fresh
  form correctly starting Dark from a pre-saved preference;
  `Tab.Search.ps1` dialog/grid theming suite 8/8 (2 runs), including the
  real Model Picker and Batch Edit dialogs opening with Dark colors
  already applied. Re-ran the complete existing regression battery
  after adding `Core.Theme.ps1` to each test's dot-source list: 200 of
  201 assertions clean (the one failure is `mint_inline_edit_test.ps1`'s
  pre-existing, previously-documented SendKeys/OS-focus flakiness around
  free-typing a Group Tag, unrelated to any D-062 code path, reproduced
  consistently both before and after this work). Full-app hidden-process
  smoke test against the real entry script and real production data,
  both startup scenarios (no settings file; pre-saved
  `{"Theme":"Dark"}`) -- this is what caught the `DrawString` crash;
  after the fix, 8/8 clean across 2 runs, production folder left with no
  leftover settings file. Re-ran every theme test again after the
  `DrawString` fix to confirm no new regressions -- all still clean.
- 2026-07-24 - Search and Manage's top summary bar counts became
  filter-aware, recorded as D-061. Jeremy pointed out "253 files" never
  changed no matter what he typed into the search filters, and asked for
  it to reflect what's actually shown, narrowing to "0 files" when
  nothing matches. `Tab.Search.ps1` (v1.6.0 -> v1.7.0):
  `Update-MintSearchSummary` gained a mandatory `-FilteredFiles`
  parameter; its only caller, `Update-MintSearchLiveGrid`, now tracks
  the matched-file list while populating grid rows and passes it in,
  instead of the function independently re-querying the whole library's
  totals. File count, needs-fixing count, and duplicate count (D-060)
  now all reflect only the currently filtered/visible set; scan warnings
  deliberately still reflect the whole library, since a scan-level
  problem is not tied to any one visible row. Also fixed the identical
  bug in the Decommissioned view's summary message (always showed the
  total master-list record count regardless of its own serial filter),
  picking up correct singular/plural wording in the same pass. Verified
  via a live functional test driving real `TextChanged`/
  `SelectedIndexChanged` events against a real 6-file sandbox library:
  unfiltered matches the whole library; narrowing by serial to 3 (then
  1) files correctly drops/shows the needs-fixing segment and updates
  singular/plural wording while the scan-warning count stays constant;
  a filter matching nothing shows a genuinely empty grid and "0 files";
  a Model filter narrows independently; clearing filters returns to the
  original total. A parallel block verified the Decommissioned view fix
  the same way. 16 of 16 assertions passed across 3 repeated runs.
  Re-ran the complete existing regression battery (201 assertions) plus
  a hidden-process smoke test of the full real entry script -- all
  clean.
- 2026-07-24 - Search and Manage's top summary bar reworked, recorded as
  D-060. Jeremy reported the wording was unclear: no plural grammar
  ("0 non-canonical" instead of omitting empty categories), "non-
  canonical" was unexplained jargon, and "issues" gave no indication of
  what was actually wrong -- he had fixed every Import Format issue and
  had no duplicates, yet the summary still showed "2 issues." Root-cause
  found before touching any wording: `Get-MintInventoryIndexSummary`'s
  `Issues` field (Core.Inventory.ps1) was never connected to Import
  Format or duplicate status at all -- it is a list of scan-level
  problem strings (a missing/malformed `variables\models.csv`/
  `depts.csv`/`grouptags.csv`, or a hash file that failed to parse
  entirely) collected while the index is built, a completely separate
  axis from a file's own Import Format/duplicate state. `Tab.Search.ps1`
  (v1.5.0 -> v1.6.0): new `Get-MintPluralizedNoun` helper gives correct
  singular/plural wording throughout ("1 file", never "1 files"); every
  category besides the total file count is omitted entirely at 0
  instead of shown as "0 X"; "non-canonical" renamed to "N need(s)
  Import Format fixing" to match the live grid's own "Import Format"
  column/values; "issues" renamed to "N scan warning(s)" with a new
  "View Scan Issues..." link (visible only when count is 1+, positioned
  dynamically after the summary text) that shows the exact issue text in
  a MessageBox, mirroring the existing per-file View Format Issues
  button. Verified via 6 unit assertions on the pluralization helper
  plus 3 live-grid scenarios against real sandbox libraries (all-clean
  library shows only "N files"; exactly-one-of-everything shows correct
  singular wording throughout plus a working View Scan Issues link whose
  text genuinely names the missing `depts.csv`; multiple-of-everything
  shows correct plural agreement with the scan-warnings segment
  correctly absent when that count is 0) -- 15 of 15 assertions passed
  across 4 repeated runs. Re-ran the complete existing regression battery
  (185 assertions) plus a hidden-process smoke test of the full real
  entry script -- all clean.
- 2026-07-24 - Main window now shows the real Hall County MIS/MINT icon
  in the title bar and taskbar, recorded as D-059. Jeremy noticed the
  default WinForms icon and asked to replace it, offering either
  `Hall County MIS Logo.png` or `MINT.ico` (already present in the
  project folder) and asking which format worked best. `MINT.ico` was
  the right choice: `Form.Icon` requires a real `System.Drawing.Icon`,
  not a generic image, and `MINT.ico` was already a proper multi-
  resolution icon (verified: 7 embedded sizes, 16 through 256px) needing
  no conversion, unlike the `.png`. `MIS Inventory Navigation Tool.ps1`
  (v1.0.5 -> v1.0.6): `New-MintMainForm` now sets `$form.Icon`, resolved
  via the existing `$script:ProjectRoot` variable (not a hardcoded
  path), wrapped in try/catch so a missing/corrupt icon file logs a
  warning and falls back to the default icon rather than blocking
  startup. Verified in three layers: confirmed the `.ico` file itself is
  genuinely well-formed multi-resolution before writing any code; an
  isolated test running the exact product code snippet confirmed
  `Form.Icon` ends up byte-identical to loading `MINT.ico` directly
  (proving the logic is correct) plus confirmed a missing file falls
  back gracefully without throwing; and the REAL entry script was
  launched as a real process, its actual window found via
  `EnumWindows`/`GetWindowThreadProcessId` (P/Invoke, same technique as
  the D-048 launcher verification), and its live icon queried via
  `WM_GETICON` -- confirmed a real icon is present and is visibly
  different from a genuinely unmodified default WinForms icon retrieved
  through the identical pipeline, ruling out "nothing changed" as an
  explanation for a separate, imperfect pixel-for-pixel comparison
  against a fresh file load (best explained as a DPI/icon-caching
  rendering artifact specific to that cross-process retrieval path, not
  a product defect, since the isolated same-process test already proved
  byte-exact correctness). Standard hidden-process full-app smoke test
  stayed clean. Purely cosmetic, low-risk, easily reversible.
- 2026-07-24 - Batch Edit gained "Remove All Assigned Users" as a third
  mode, recorded as D-058 -- AND, found while building/testing it, a
  CRITICAL pre-existing data-loss bug (shared pitfall P30,
  `reference_intune_pitfalls.md`) was discovered and fixed. Jeremy asked
  to add a Remove All Assigned Users function to Batch Edit.
  `Tab.Search.ps1` (v1.4.0 -> v1.5.0): `Show-MintBatchEditDialog` now
  presents three mutually exclusive radio-button modes (Set Group Tag /
  Remove All Assigned Users / Fix Import Format only) instead of the
  previous single checkbox; `Invoke-MintFixImportFormatSingleFile`
  gained a second override parameter, `OverrideAssignedUser`.
  **THE CRITICAL FIND:** the pre-existing `OverrideGroupTag` parameter
  (shipped in D-050, 2026-07-23) used a `[string]$Param = $null` +
  `if ($null -ne $Param)` pattern to mean "only override when a value
  was actually supplied" -- this does NOT work in PowerShell 5.1. A
  `[string]`-typed parameter is coerced to a real, non-null `""` the
  instant it is bound, whether the caller omits it entirely or
  explicitly passes `$null`, so the override branch fired
  unconditionally on every single call. This means the standalone Fix
  Import Format button, and Batch Edit's pre-D-058 "Fix Import Format
  only" checkbox mode -- both of which have always called this worker
  with zero override arguments specifically to leave Group Tag untouched
  -- have been SILENTLY WIPING every fixed file's Group Tag to blank on
  every single use since D-050 shipped, including Jeremy's real 175-file
  production Fix Import Format run that motivated D-051's report-writer
  retry fix. The bug escaped five subsequent rounds of regression
  testing because the existing test fixture for "fix with no override"
  used a sandbox file whose Group Tag already started blank, so that
  assertion could never have caught it either way. Fixed via
  `$PSBoundParameters.ContainsKey()` instead of null-testing the bound
  value, plus conditional splatting at the Batch Edit call site (an
  always-present `-OverrideX $null` argument reproduces the identical
  bug even after the function itself is fixed). Also corrected the
  masking test fixture to start with a real, non-blank Group Tag.
  Verified: the new feature via 19 live UI-automation assertions across
  4 runs (dialog-level mode selection via `Application.OpenForms`-based
  direct control manipulation, plus a full live-grid batch run proving
  Remove All Assigned Users clears Assigned User on all 4 selected
  files -- including a genuinely non-canonical one, proving this mode is
  not format-gated -- while leaving Group Tag untouched on every file);
  the bug fix via 9 targeted assertions directly against
  `Invoke-MintFixImportFormatSingleFile` (all of which FAILED before the
  fix and PASSED after, confirming the bug was real and reproducible on
  demand). Re-ran the complete existing regression battery including the
  corrected round-2 fixture -- 151 of 151 assertions, all clean -- plus
  a hidden-process smoke test of the full real entry script. **Jeremy
  needs to decide whether the real 175-file production run's files had
  real Group Tag values before that run, and if so, whether to restore
  them from that run's backup archive** -- see the ACTION NEEDED note at
  the top of this file.
- 2026-07-23 - Search and Manage's Assigned User inline edits (D-055)
  are now normalized/validated against the hallcounty.org domain,
  recorded as D-057. Jeremy asked for a bare username (e.g. `john.doe`)
  to get `@hallcounty.org` appended automatically, but only that domain
  to be accepted once an `@` is present, specifically to prevent
  `john.doe@hallcounty.org` from ever becoming
  `john.doe@hallcounty.org@hallcounty.org`. `Tab.Search.ps1` (v1.3.0 ->
  v1.4.0): new pure function `ConvertTo-MintAssignedUserValue`
  normalizes/validates a raw cell value (bare username -> appended
  domain; already-qualified hallcounty.org address -> passed through,
  domain case-normalized; wrong domain/second `@`/empty username before
  `@` -> rejected with an explanatory message via the same revert +
  status + warning MessageBox path already used for a failed save).
  Solving the doubling scenario specifically required two no-op checks,
  not just the append logic alone: CellEndEdit's existing D-055 raw-
  value-vs-original no-op check runs BEFORE normalization (so clicking
  into a legacy/unqualified on-disk value without editing it is never
  treated as a change), and a second no-op check runs AFTER
  normalization (so retyping a value that normalizes back to the exact
  original -- including retyping the identical already-qualified address
  itself -- is also recognized as no real change). Verified via 10 pure
  unit-level assertions on the normalizer plus a live grid functional
  test covering 5 real scenarios, including the exact doubling scenario
  from Jeremy's request (retyping an already-qualified address stays
  exactly the same, confirmed no double domain on disk) and the legacy-
  value no-op case (clicking into a pre-existing unqualified value
  without editing it creates no backup and does not get silently
  "upgraded"). 25 of 25 new assertions passed across 4 repeated runs.
  Updated 2 pre-existing D-055 regression assertions that had asserted
  the old (now-incorrect) unqualified on-disk value; not a defect, just
  outdated expectations now that this decision changes the behavior.
  Re-ran the complete existing regression battery (113 assertions) plus
  a hidden-process smoke test of the full real entry script -- all
  clean.
- 2026-07-23 - Search and Manage gained a "Copy Serial(s)" action,
  recorded as D-056. Jeremy asked to copy the serial number of one or
  multiple devices to the clipboard, explicitly noting a multi-selection
  with gaps must still work and paste one device per line.
  `Tab.Search.ps1` (v1.2.0 -> v1.3.0): new button on row 1 of the live
  grid's action panel, enabled for any non-empty selection. Found a real
  correctness gap before it ever reached Jeremy, via a dedicated
  isolated repro rather than assumed: `DataGridView.SelectedRows`
  enumerates in reverse-selection order (most-recently-clicked first),
  not grid-visual order -- reusing the existing order-agnostic
  `Get-MintSearchSelectedFiles` helper would have "handled gaps" without
  crashing, but would have produced a scrambled, click-order-dependent
  line sequence instead of the expected top-to-bottom device order.
  Fixed with a new `Get-MintSearchSelectedFilesInGridOrder` helper that
  iterates the grid's own `.Rows` collection (true visual order)
  filtering on `.Selected`, rather than modifying the existing shared
  helper (left untouched since none of its five other callers -- Check
  AD Location, Batch Edit, Fix Import Format, Decommission/Restore,
  Delete -- depend on selection order). Scoped to the live grid only,
  hidden while viewing decommissioned devices, matching Copy Path's
  existing live-only precedent. Verified via a live functional test:
  button gating at 0/1/many selected, correct singular/plural status
  wording, a contiguous multi-selection copying in order, a full-grid
  selection copying all rows in order, and the decisive scenario --
  selecting rows out of visual click order (E, then A, then C) still
  produces clipboard output in correct grid order (A, C, E), proving the
  ordering fix actually works. 12 of 12 assertions passed across 3
  repeated runs. Re-ran the complete existing regression battery (39 +
  21 + 4 + 16 + 33 = 113 assertions) plus a hidden-process smoke test of
  the full real entry script -- all clean.
- 2026-07-23 - Search and Manage gained spreadsheet-style inline editing
  of Group Tag and Assigned User, recorded as D-055. Jeremy asked for
  the ability to click a cell in the results grid and type a new value
  directly, like an Excel cell -- Group Tag becoming a dropdown populated
  the same way as Batch Edit but with an added blank entry and the
  ability to type a custom value. Before implementing, Claude assessed
  whether this required drastic changes and proposed silent backup with
  no confirmation dialog; Jeremy replied "Go ahead with all of it."
  `Tab.Search.ps1` (v1.1.0 -> v1.2.0): the live grid's `ReadOnly` flag is
  now false, with only Group Tag (`DataGridViewComboBoxColumn`,
  `DropDownStyle=DropDown`) and Assigned User (`DataGridViewTextBoxColumn`)
  individually editable; all other columns stay read-only.
  `CellBeginEdit` captures the pre-edit value and blocks entry entirely
  for a file with a `ReadError`; `CellEndEdit` compares against that
  captured value (a no-op edit does nothing) and calls a new
  `Invoke-MintSearchInlineEdit` worker, which follows the same silent-
  backup-then-write pattern as every other mutating action in this file.
  Found and fixed a real bug via live testing, not assumed: a
  DataGridViewComboBoxColumn's own built-in "this cell changed" dirty
  notification is tied to `SelectedIndexChanged` (picking an existing
  list item) and does not reliably fire for free-typed text alone --
  confirmed live that typing a brand-new custom Group Tag and moving to
  another cell silently discarded it with zero indication anything went
  wrong. Fixed in `EditingControlShowing` by wiring the editing combo's
  `TextChanged` to explicitly set
  `IDataGridViewEditingControl.EditingControlValueChanged` and call
  `NotifyCurrentCellDirty($true)`. An early version of the automated
  test used bulk `.Text = "..."` assignment instead of real keystrokes
  and was genuinely flaky (races the queued TextChanged message against
  EndEdit) -- rebuilt using real `SendKeys` character-by-character
  typing, which is both more representative of actual use and reliably
  stable: 40 assertions across 8 runs of two dedicated repro scripts (new
  custom text via Tab or click-away, clearing to blank, picking a
  configured value, Escape-to-cancel). Separately found and fixed a
  pure test-harness limitation (not a product issue): a second
  synthetic edit later in the same automated test process does not
  reliably receive real OS focus via managed `Control.Focus()`; worked
  around with the raw Win32 `SetFocus` API in the TEST ONLY, since a
  real user's mouse click always transfers real focus natively. Full
  33-assertion inline-edit suite passed 7 consecutive clean runs
  (231/231); all existing regression suites (39 + 21 + 4 + 16 = 80
  assertions) still clean.
- 2026-07-23 - Search and Manage gained Model Lookup and Delete,
  recorded as D-054. Model Lookup is single-selection only: runs the
  selected device's serial through `Resolve-MintWarrantyLookup`
  (Core.VendorLookup.ps1, D-053) and shows Serial Number/Manufacturer/
  Model in a small popup (`Show-MintModelLookupResultDialog`). Delete is
  multi-selection capable and permanently removes file(s) from disk
  (distinct from Decommission, which only moves a file) behind a
  two-step confirmation: an optional backup first (Yes/No/Cancel), then
  a separate explicit "permanently delete, cannot be undone" step,
  worded more urgently when no backup was chosen. New per-item worker
  `Invoke-MintDeleteSingleFile` follows the same shape as the existing
  Decommission/Restore/Fix-Import-Format workers, and Delete's handler
  follows the same D-051 backup-phase-separate-from-per-item-work
  pattern. Verified via real button clicks and real auto-answered
  dialogs (Timer + standard Windows MessageBox Alt+accelerator/Escape
  SendKeys): Model Lookup gates correctly on 1 vs 2 selected and
  performs a genuine live Getac lookup; Delete tested across Backup=Yes/
  Delete=Yes (files genuinely removed, backup zip created and its entry
  count verified by actually opening it), Backup=Cancel (file verifiably
  untouched), and Backup=No/Delete=Yes (file removed, no backup zip
  exists). 16 of 16 new assertions passed; all existing regression
  suites (64 assertions) still clean.
- 2026-07-23 - Warranty Lookup tab (Tab 6) built out, recorded as D-053.
  Jeremy asked to port the proven Lenovo lookup from
  `Fill-LenovoWarrantyWorkbook.ps1` v5.0.1, build a new Getac provider,
  and show an honest "Vendor Not Configured" notice for anything neither
  finds (Dell/HP, pending vendor API access). `Core.Domain.ps1` (v1.0.0
  -> v1.0.1) gained `New-MintWarrantyRecord`, the shared result shape.
  `Core.VendorLookup.ps1` (v1.0.0 stub -> v1.1.0) implements Lenovo
  (ported algorithm: session-cookie-first, product resolver, ibase
  warranty endpoint with machine-type-first/serial-only-retry) and Getac
  (new: POST `txtSNs=<serial>` to the public form, regex-parsed against a
  REAL captured HTML response -- anchored on the result row's
  `id='chk_<serial>' value='<serial>'` checkbox, per D-043 scope of only
  SN/Model/Warranty Expiration Date). `Resolve-MintWarrantyLookup`
  orchestrates both with an explanatory fallback. `Tab.Warranty.ps1`
  (v1.0.0 placeholder -> v1.1.0) is now a real multi-serial lookup UI
  with a results grid and CSV export. Verified via REAL live lookups
  against both vendors: Getac test serial RRB03B2021 -> Found/B360G3;
  Lenovo serial MZ013XH6 (a real Hall County device) -> Found/"ThinkCentre
  M70q Gen 5"/real warranty dates, proving the ported logic still works
  against Lenovo's live site today. Found and fixed two real bugs via
  this live testing: a missing `[AllowEmptyCollection()]` (same PS 5.1
  gotcha already documented from Core.Inventory.ps1) that leaked an
  internal PowerShell binding error into a user-facing message; and a
  genuine PowerShell language gotcha where `(if (...) {...} else {...})`
  in bare parentheses cannot be used as one argument inside a method call
  or array literal (throws "The term 'if' is not recognized"). Hash
  decode and the Dell/HP API providers remain unimplemented, out of scope
  for this explicitly-scoped-down request.
- 2026-07-23 - Jeremy created the real live `variables\grouptags.csv`.
  Recorded as D-052: read the real file directly rather than assuming
  it matched the schema originally documented in D-049 -- it turned out
  to be a flat 70-line list of Group Tag values with NO header row
  (starts immediately with `911 - Desktop`), not the headered CSV
  matching depts.csv/models.csv that was designed. Proved via a sandbox
  COPY of the real file (live file never modified) that the old
  header-keyed reader would have treated the first real tag as the
  header, failed the "Group Tag" required-header check, and silently
  discarded the entire file -- Jeremy's dropdown would have stayed
  empty despite him doing exactly what was asked. This was an AI-side
  design/communication gap, not a mistake on Jeremy's part. Fixed
  `Get-MintGroupTagMapInternal` (Core.Inventory.ps1 v1.0.2 -> v1.0.3) to
  read plain trimmed lines directly instead of through
  `Read-MintVariableCsv`'s header-keyed parsing. Verified against the
  real file: 69 unique tags (70 lines, 1 real exact duplicate --
  "Tax Commissioner - Desktop" -- collapses to one), the first tag no
  longer dropped, an apostrophe in a real tag name and the one
  irregular no-suffix entry ("Marshal's Office") both read correctly.
- 2026-07-23 - Jeremy's seventh feedback round on Search and Manage,
  recorded as D-051: fixed a real crash from Jeremy's first live
  175-file Fix Import Format run (`Fix Import Format backup step
  failed: ... AppendAllText ... because it is being used by another
  process`). Two root causes: (1) `Add-MintRunReportRow` had zero retry
  protection against a transient file lock, unlike the decommission
  master list, which already got `Invoke-MintFileWriteWithRetry` after
  an earlier real crash -- moved that function into Core.Backup.ps1 so
  both writers share it. (2) The surrounding try/catch could not tell
  "nothing changed yet" (a real backup failure) from "most files
  already got fixed, then one audit-log write hit a lock" (a failure
  deep in the per-file loop) -- both produced the same misleading
  "failed before any file was changed" message. Restructured every
  mutating handler (Move, Decommission, Restore, Batch Edit, Fix Import
  Format) so the backup phase and per-item work have separate try/catch
  scopes, and each report-row write is individually wrapped so a
  logging failure never undoes or misreports an already-successful
  mutation, and never aborts the rest of a batch. Verified via a real
  button click with a real auto-answered confirmation dialog and a
  simulated persistent failure on file #2 of 3 -- confirmed all 3 files
  still got fixed and the status accurately read "Fixed 3 of 3."
- 2026-07-23 - Jeremy's sixth feedback round on Search and Manage,
  recorded as D-050: Check AD Location is now batch-capable (loops over
  every selected device instead of requiring exactly one). Added a new
  Fix Import Format action, available both as a standalone button
  (rewrites every selected non-canonical file to the full canonical
  shape, no value changes) and as a "Fix Import Format only (do not
  change Group Tag)" checkbox inside the Batch Edit dialog (skips the
  Group Tag write, preserving each file's own existing value). Both
  share a new `Invoke-MintFixImportFormatSingleFile` worker; Batch
  Edit's "set Group Tag" path was refactored onto the same worker.
  Reorganized the action panel into two rows. Also fixed a real reported
  crash: clicking Batch Edit with multiple devices selected threw
  `Cannot bind argument to parameter 'GroupTagChoices' because it is
  null`. Root cause (documented as shared pitfall P29): four
  Core.Inventory.ps1 accessor functions (`Get-MintInventoryFiles`,
  `Get-MintModelMap`, `Get-MintDepartmentMap`, `Get-MintGroupTagChoices`)
  all returned their array via a bare `return $array` instead of
  `return ,$array`, which collapses a 0-element array to `$null` across
  the function boundary -- `GroupTags` was legitimately empty since
  `variables\grouptags.csv` does not exist yet. Fixed all four together,
  not just the one that had visibly crashed. Verified via an isolated
  local-sandbox test that directly reproduces the crash scenario (no
  grouptags.csv file at all) using a WinForms Timer to auto-close the
  real live modal dialog, confirming the actual `ShowDialog()` code path
  no longer throws: 21 of 21 assertions passed.
- 2026-07-22 - Jeremy's fifth feedback round on Search and Manage,
  recorded as D-049: added multi-row selection to both grids, graying
  out single-file-only actions (Open File, Open Folder, Copy Path, Check
  AD Location, View Format Issues, Move to Model Folder) unless exactly
  one row is selected. Added a new Batch Edit action that mass-assigns
  Group Tag across every selected device via a dialog backed by a new
  `variables\grouptags.csv` choice list (follows the exact
  depts.csv/models.csv pattern; missing/empty file is a valid state,
  dropdown stays editable). Refactored Decommission and Restore into
  reusable per-row worker functions
  (`Invoke-MintDecommissionSingleFile`/`Invoke-MintRestoreSingleRow`) so
  both button handlers now loop over the full selection and aggregate
  results instead of requiring exactly one row. Moved Import Format and
  Duplicate to the end of the live grid's column order. New
  `Write-MintCanonicalHashFile` (Core.Csv.ps1) always writes the full
  canonical 5-column shape when Batch Edit rewrites a file, so an edit
  can only move a file toward canonical format, never away from it.
  Verified via an isolated local-sandbox functional test (no production
  data touched): 39 of 39 assertions passed, plus a hidden-process smoke
  test of the real entry script confirming no startup crash from the new
  module wiring. `variables\grouptags.csv` does not exist on the live
  filestore yet -- deliberately not created by AI/dev (no basis to
  invent Hall County's real Group Tag values); Jeremy needs to create it.
- 2026-07-22 - Jeremy's real-world double-click contradicted the round-4
  console fix below ("The cmd window is still open, just minimized"),
  which had verified clean via automated testing. Recorded as D-048:
  a minimized window is still `IsWindowVisible = True` in Win32, so a
  genuinely hidden window cannot appear "minimized" -- the round-4 test
  had verified the INNER PowerShell process's console was hidden, but
  Jeremy's report was about the OUTER `.cmd` window, which that fix
  never touched. Suspected cause: Windows Terminal (the modern default
  console host) keeps a tab open when its hosted process exits very
  fast, as a crash safeguard, and the `.cmd` exits in ~1-1.5 seconds by
  design. Fix: removed the console/terminal host from the launch chain
  entirely rather than further tuning the PowerShell launch. Built a new
  standalone `MIS Inventory Navigation Tool.vbs` (v1.0.0) containing all
  launch logic (including the `PROCESSOR_ARCHITEW6432` 64-bit path
  resolution, ported from batch); it is now the recommended launcher.
  `wscript.exe` (the default handler for `.vbs`) is a GUI-subsystem
  executable with no console window at all, so there is nothing for
  Explorer/Terminal to host regardless of exit timing. `MIS Inventory
  Navigation Tool.cmd` is kept only as a thin legacy shim
  (`wscript.exe //B "...vbs"`) so any existing shortcut/pin still works.
  Verified mechanically clean via the same P/Invoke window-enumeration
  harness on both launchers (`.vbs` direct: ~615ms, MINT main window
  visible, its console hidden, no lingering wscript.exe; `.cmd` shim:
  ~985ms, same clean result) -- explicitly flagged in D-048 that this
  test cannot detect a Windows Terminal tab kept open independently of
  the launcher's own exit, so Jeremy's real double-click confirmation on
  the `.vbs` is the authoritative check this time, not the automated
  test. Both files verified ASCII-only, no BOM (consistent with the
  existing `.cmd` convention; the BOM requirement is scoped to PS
  5.1/IME-read files, not batch/VBScript launcher glue).
- 2026-07-22 - Jeremy's fourth feedback round: the `.cmd` launcher left a
  console window open for the tool's whole runtime, and startup took
  ~10 seconds. Rewrote `MIS Inventory Navigation Tool.cmd` to launch the
  tool as a detached process (`start "" powershell.exe -WindowStyle
  Hidden ...`) and exit immediately, instead of running powershell.exe
  inside the `.cmd`'s own inherited console. Verified live via
  `EnumWindows`/`GetWindowThreadProcessId`/`IsWindowVisible` P/Invoke
  (not just trusting the flag) that the spawned process's WinForms window
  is genuinely visible while it owns zero `ConsoleWindowClass` windows.
  Since hiding the console removes the only feedback during the ~10
  second initial library scan, added a startup
  `Show-MintWaitWindow`/`Close-MintWaitWindow` (entry script v1.0.3 ->
  v1.0.4) so launching the tool still shows immediate visible feedback.
- 2026-07-22 - Jeremy's third feedback round on Search and Manage
  (Core.Csv.ps1 v1.0.2), recorded as D-047, superseding D-046 item 3
  specifically: quoted CSV fields are no longer a format issue AT ALL --
  Jeremy stated directly that quoted fields have never caused a real
  Autopilot import problem in his operational history, overriding the
  earlier assumption drawn from Microsoft's general documentation. The
  CSV parser is unchanged (still fully parses quoted fields); only the
  "this is a problem" classification was removed. Verified live: canonical
  file count on the real 256-file library jumped from 1/256 to 80/256
  immediately after the change, confirming quoting was the single
  dominant false-positive remaining after D-046's header/BOM fixes.
- 2026-07-22 - Jeremy's second feedback round on Search and Manage
  (Core.Csv.ps1 v1.0.1, Tab.Search.ps1 v1.0.3), recorded as D-046:
  corrected the canonical header validation rule -- a valid header is an
  exact 3/4/5-column positional-cascade prefix of the fixed order, not
  always the full 5-column text (Windows Product ID's header always
  exists regardless of data since it sits between the two always-
  mandatory columns; the same cascade forces Group Tag's header to exist
  if Assigned User has data). Removed the UTF-8 BOM check from hash-file
  format issues entirely -- that requirement applies only to MINT's own
  .ps1/.cmd program code. Verified live (Get-Content raw bytes vs.
  Import-Csv parsed values on the same real file) that the disputed
  "Quoted fields present" finding was correct all along -- Excel hides
  CSV quote-escaping characters that are genuinely present in the raw
  file -- and clarified the message instead of changing the detection
  logic. Switched both grids from AutoSizeColumnsMode Fill to AllCells
  (size to header, grow to widest value) per Jeremy's request. Re-scanned
  the real 256-file library after the fix: canonical/non-canonical split
  unchanged (255/256), confirming literal quoting really is the dominant
  outstanding issue across the library, not a detection artifact.
- 2026-07-22 - Jeremy's first real usage of Search and Manage produced 5
  fixes (entry script v1.0.3, Tab.Search.ps1 v1.0.2): a non-interactive
  "please wait" window (Show-MintWaitWindow/Close-MintWaitWindow, added
  to the entry script as a shared helper) around Refresh Inventory;
  singular Device Type display (Desktop/Laptop/GETAC) via a display-only
  map, internal DeviceTypeFolder stays plural; the Format column renamed
  to "Import Format" with plain OK/Needs Fixing values plus a "View
  Format Issues" button explaining exactly what's wrong; red text on
  Duplicate/Needs Fixing cells; and a real crash fix for clicking "Show
  Decommissioned Devices" ("The property 'ShowingDecommissioned' cannot
  be found on this object"). Root cause: .GetNewClosure() breaks live
  $script:-scoped variable/property access -- documented as a new shared
  pitfall, P28, distinct from P27 (which is about @() array-wrapping).
  Removed the only .GetNewClosure() call in the file; every handler is
  now a plain scriptblock reading $this or $script:MintSearchState.
- 2026-07-22 - Search and Manage (Tab 2) fully implemented: Core.Csv (CSV
  parser ported from Batch Extractor v1.0.7), Core.Domain, Core.Inventory
  (real library scanner), Core.Backup (zip/report engine), Core.ActiveDirectory
  (System.DirectoryServices-based, no RSAT dependency), Core.DeviceRecord
  (D-011 facet resolver), and Tab.Search.ps1 itself all went from stub to
  real, tested against the live filestore data (256 real hash files, real
  depts.csv, real AD). Found and fixed 4 real bugs via live testing: (1)
  missing [AllowEmptyCollection()] on Mandatory collection params in
  Core.Inventory; (2) a previously undocumented PS 5.1 gotcha where
  @($someListVariable) throws ArgumentException -- use .ToArray() instead,
  NOT YET ADDED to the shared pitfalls reference; (3) a nested-function
  scope bug in Tab.Search.ps1 (same family as the entry script's v1.0.2
  fix) that broke every event handler firing after initial load, fixed by
  promoting helpers to script-scope functions (Tab.Search.ps1 -> v1.0.1);
  (4) a data-integrity gap where a locked decommission master list could
  leave a decommission half-done (file moved, record not written) --
  fixed with a retry wrapper. FLAGGED FOR JEREMY: the real master
  decommission list file
  (Endpoint Inventory\Decommissioned Devices\Decommissioned Devices Master
  List.csv) was found durably locked (0 bytes, last write 2026-07-21
  15:06:10, likely a leftover handle from Codex's own prior session) --
  worth checking before relying on it for a real decommission.
- 2026-07-22 - Jeremy corrected the filestore hygiene scope (D-045):
  the restriction is narrowly about not writing/running MINT program
  code (.ps1/.cmd) from the fileserver, not about avoiding MINT's own
  data roots during dev/test. The `Endpoint Inventory` filestore copy is
  a deliberate, disposable test ground for MINT development, separate
  from Jeremy's real production workflow, to be sterilized with fresh
  data before go-live. `variables\*.csv` files are intentionally a live
  external database the program reads at runtime by design, specifically
  so routine data changes never require a new software version. The five
  folders/log file created during the prior audit's testing are correct,
  intended behavior -- no cleanup needed, superseding that entry's
  "awaiting Jeremy's decision" note.
- 2026-07-22 - Independent audit (Claude) of Codex's v1.0.1/v1.0.2
  hardening: zero code defects found. Module-loading scope fix, path
  classification rewrite, and .cmd PROCESSOR_ARCHITEW6432 check all
  independently re-verified via isolated repros, not just re-read.
  Operational finding, CORRECTED after Jeremy caught an error in Claude's
  first report: the live filestore is not just an empty `logs` folder as
  first claimed -- Claude's own verification commands were silently
  checking a local decoy path (`C:\hallcounty\...`) due to a Bash
  command-escaping bug, not the real share. The real
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool`
  contains five real folders (Backups, Reports, Review Staging, Upload
  Lists, logs) created by Codex's own v1.0.0 testing pass, plus one real
  log file with 6 lines (5 from Codex's run, 1 from Claude's own later
  scope test). Both AI assistants touched live production infrastructure
  during testing; functionally harmless (no hash-file data touched) but
  a real process violation of the D-008 hygiene rule for both. Awaiting
  Jeremy's decision on whether to leave or remove the real folders/log
  file, and whether to add a local-test-copy path override before further
  live testing.
- 2026-07-22 - First working code: entry script, .cmd launcher, and 13
  Modules\ files created. UI shell with six placeholder tabs, central
  path validation, and full Core.Logging.ps1 are working. All .ps1 files
  parse clean and pass UTF-8 BOM/ASCII validation. Live smoke test
  confirmed the shell launches and stays open without a filestore
  connection (graceful degradation proven, not just assumed). Core.Csv,
  Core.Backup, Core.Inventory, Core.Domain, Core.VendorLookup,
  Core.ActiveDirectory, Core.DeviceRecord remain documented stubs
  pending Phase 1/2.
- 2026-07-22 - Shell hardening v1.0.1: module loading and WinForms loading are
  now inside the startup failure boundary, the launcher explicitly prefers
  64-bit Windows PowerShell, startup status distinguishes unavailable logs from
  usable logs, missing tab init functions are visible in the tab itself, and
  auto-create path parent detection is explicit instead of defaulting unknown
  paths to the hash root.
- 2026-07-22 - Hotfix v1.0.2: fixed the v1.0.1 module import scope regression.
  Dot-sourcing from inside a helper function made `Write-MintLog` and tab
  initializer functions disappear after the helper returned. Modules are now
  resolved by helper but dot-sourced directly from the script-scope startup
  block.
- 2026-07-22 - Recorded D-044: Dell and HP exact API result fields/value mappings are deferred until real API access and sample payloads are available.
- 2026-07-22 - Recorded D-043: Getac result parsing is scoped to `SN`, `Model`, and `Warranty Expiration Date` only.
- 2026-07-22 - Recorded D-042: HP should use the official Warranty API path if access is available; Getac public form POST automation was live-tested successfully with serial `RRB03B2021`.
- 2026-07-22 - Recorded D-041: migration timing is intentionally owner-deferred and should not be designed before Jeremy resolves it.
- 2026-07-22 - Recorded D-040: decommission collisions use newest-wins with confirmation and require a Restore action.
- 2026-07-22 - Recorded D-039: all hardware hash model folders use `<Manufacturer> <Model Name>` under the mapped device-type folder.
- 2026-07-21 - Recorded D-038: all generated outputs are central on the filestore under `<DataRoot>`.
- 2026-07-21 - Recorded D-037: v1 operator updates are manual pull from the filestore distribution source; no self-update mechanism.
- 2026-07-21 - Recorded D-036: Dell automation should pursue TechDirect Warranty Management API access; public Dell warranty scraping is not a supported path.
- 2026-07-21 - Recorded D-035: the multi-file dot-sourced `Modules\` layout is confirmed.
- 2026-07-21 - Recorded D-034: decommissioned files move to the Endpoint Inventory `Decommissioned Devices\<Current Year>` folder and append the master decommission CSV.
- 2026-07-21 - Recorded D-033: Getac warranty lookup should be automated if technically possible; D-042 later proved initial form-POST feasibility.
- 2026-07-21 - Recorded D-032: software distribution files live under the MINT filestore `MINT Application` path, but AI/development work must not write there.
- 2026-07-21 - Recorded D-031: default vendor batch input root is `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Vendor Supplied Hardware Hash Batch Lists`.
- 2026-07-21 - Recorded D-030: shared-file writes use short locks plus pre-write revalidation; notify only on actual data mismatch.
- 2026-07-21 - Recorded D-029: Upload Builder should support override-mode handling for Group Tag and Assigned User while staying easy to toggle later.
- 2026-07-21 - Recorded D-028: Batch Extract creates missing folders automatically for verified model-map rows.
- 2026-07-21 - Recorded D-027: legacy tools remain available until MINT is complete and parity is proven.
- 2026-07-21 - Recorded D-026: backups and reports default to 180-day retention configured from the MINT variables folder, with `0` meaning keep forever.
- 2026-07-21 - Recorded D-025: local project directory is now `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool`; matching AI knowledgebase folder has been aligned to the renamed project.
- 2026-07-21 - Recorded D-024: hash files live under `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory`; device type maps `Desktop` -> `Desktops`, `Laptop` -> `Laptops`, and `GETAC` -> `Getacs`.
- 2026-07-21 - Recorded D-023: `models.csv` is the formal model/folder map with `Model Name`, `Manufacturer`, `Device Type`, and `Model Number 01` through `Model Number 10`.
- 2026-07-21 - Recorded D-022: active `depts.csv` prefix headers are `Dept Prefix 01` through `Dept Prefix 05`; blank prefix cells are normal and `N/A` is not a match.
- 2026-07-21 - Recorded D-021: `depts.csv` is a headered CSV parsed by header name rather than raw column position.
- 2026-07-21 - Recorded D-020: Application/error logs write to `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\logs` as one append-only daily `.txt` file per running user account.
- 2026-07-21 - Recorded D-019: Active Directory OU placement is authoritative for department ownership/location; `depts.csv` maps department folders, official names, and expected prefixes.
- 2026-07-21 - Recorded D-018: Product name is MIS Inventory Navigation Tool (MINT); external data/database root is `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\`.
- 2026-07-21 - Recorded D-017: Search and Manage Model filter is an editable searchable dropdown with manufacturer-optional partial matching.
- 2026-07-20 - Recorded D-016: v1 object graph is rebuilt from raw files in memory; no continual database.
- 2026-07-20 - Recorded D-015: shared normalized domain object model across all modules and tabs.
- 2026-07-20 - Recorded D-014: Batch Extract must file to manufacturer-prefixed model folders and use warranty lookup when hash data is insufficient.
- 2026-07-20 - Created `Inventory Hash Management Tool - Tab Mockups.png` in the project folder.
- 2026-07-17 - Created `Inventory Hash Management Tool - Project Scope Outline.docx` in the project folder.
- 2026-07-17 - Created initial AI collaboration handoff for the conceptual project.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1 if PowerShell scripts are created.
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
- Validate JSON/XML/config/database schema files if present.
- Confirm install, uninstall, detection, marker versions, helper versions, and package artifact are synchronized if packaged for Intune.
- Confirm `.intunewin` is rebuilt from a clean source folder with no stale `.intunewin`, logs, AI notes, or archives inside the payload if packaged for Intune.
- Confirm Intune portal settings match script comments if deployed through Intune.
- For device-context work, validate 64-bit PowerShell and SYSTEM-context behavior.

## Latest Work Log

### 2026-09-01 - Claude (Upload Builder/Import Files: new Open/Copy destination and staging folder buttons, button reordering (D-149))

- Instruction: Jeremy asked for four new single-selection-gated buttons
  (Open/Copy Destination Folder in Upload Builder, Open/Copy Staging
  Folder in Import Files), confirmation each tab's commit button (Build
  Upload File/Import) stays last, sensible regrouping, and a "full
  gauntlet test." Confirmed by direct code read that both commit
  buttons were already last (Import's is itself prior decision D-097),
  so this was a preservation constraint, not a move. Confirmed via a
  clarifying question that no persisted regression suite exists
  anywhere reachable (Document 08's own "Known gaps" already admits
  this) -- "gauntlet" meant real tests for this change plus a real
  exercise, not a pre-existing battery.
- Design: neither new folder is per-grid-row -- Upload Builder's output
  is `HashUploadRoot\<account>` from the "Write to account" combo box;
  Import Files' staging folder is the single flat `StagingRoot`. New
  `Resolve-MintUploadDestinationFolder` helper in `Tab.Upload.ps1`
  factors out the account-resolution logic for its two new buttons
  (`buildButton`'s own existing inline resolution left untouched --
  promote-on-second-consumer precedent). Each tab's new buttons follow
  that tab's OWN existing gating convention (Upload Builder: no
  pre-graying, inline validation; Import Files: pre-grayed via
  `Update-MintImportFilesActionButtonStates`, matching its existing
  Copy Serial(s)/Batch Edit). Inserted next to each new button's nearest
  thematic sibling rather than a full panel rebuild: Upload Builder =
  `Batch Edit, Remove Selected, Open/Copy Destination Folder, Build
  Upload File`; Import Files = `Create Folders Now, Copy Serial(s),
  Open/Copy Staging Folder, Batch Edit, Batch Edit Group Tag/User, Edit
  Model Folders, Import`.
- Testing: isolated logic test for the new helper (4 branches). Real-control-tree
  test -- dot-sourced the REAL tab files plus every real Core module and
  the entry script's own real shared helpers (extracted as the
  side-effect-free slice ending before its `Application.Run` block)
  against a synthetic sandbox, never the real production UNC paths.
  Confirmed real button existence/text, the real `Controls` collection's
  both Add-order and actual visual X-position, real grid-selection-driven
  click behavior via `PerformClick()` (Clipboard content, status-label
  text), `Start-Process` shadowed so no real Explorer window launched.
  26 assertions, all passing after fixing two real test-harness bugs
  (not code bugs): a `-File`-invoked top-level script has no scope
  boundary between a bare variable and a same-named `$script:`-prefixed
  one, so the entry-script slice's own module-root assignment clobbered
  a same-named test variable; and a synthetic grid row's Tag needed the
  real `New-MintImportFileRowPlan` shape, not an ad-hoc object.
- Status: complete. Both files parse-clean and UTF-8-BOM/ASCII-clean.
  `Tab.Upload.ps1` 0.8.1->0.9.0, `Tab.ImportFiles.ps1` 0.5.2->0.6.0.

### 2026-09-01 - Claude (Codebase-wide comment-density cleanup across all 22 .ps1 files; no functional change (D-148))

- Instruction: Jeremy asked directly for a comment-only cleanup pass
  across every script -- concise comments, brief per-section
  explanations plus anything an auditor/future maintainer needs,
  further detail pushed to a reference doc instead of narrated inline,
  goal of keeping comments from dominating a script (his figure:
  prevent 60%). Measurement confirmed it was real: codebase averaged
  42.7% comment lines, `Core.DeviceRecord.ps1` was already at 73.7%.
- Approach: one convention applied to all 22 files -- `.DESCRIPTION`
  trimmed to load-bearing facts with a Decisions Log pointer; every
  `CHANGE LOG` entry condensed to one line each (all kept, dates/IDs/
  versions unchanged, only verbosity cut -- Doc 07 already prescribed
  this format, so this pass restores it rather than invents it);
  inline comments trimmed to behavior + genuine gotchas, historical
  narration collapsed to a `(D-xxx, AI-Project-Plan.md)` pointer. No
  new reference document created -- the Decisions Log already serves
  that role. `Core.DeviceRecord.ps1` hand-trimmed first as the
  calibration example; the rest done both by hand
  (`Tab.Search.ps1`/`Tab.Validate.ps1`) and via delegated background
  agents given the same convention, each independently re-verified.
  Entry script's `$script:ToolVersion` re-synced to its bumped
  `.NOTES Version:` (Doc 07's documented drift risk) -- the only
  intentional code-adjacent change anywhere in this pass.
- Note on execution: two rounds of parallel background agents were
  killed mid-run by an account-wide session limit (unrelated to this
  task). No work was lost either time -- every file touched before
  each interruption was already independently confirmed code-safe, and
  the one file left mid-progress (`Tab.Validate.ps1`) was finished by
  hand rather than re-risking another batch failure.
- Testing: all 22 files proven code-identical via a token-level
  fingerprint (both versions parsed, Comment/NewLine/EndOfInput tokens
  excluded, remaining code-token sequences diffed) -- zero unexpected
  differences on any file (entry script's one expected ToolVersion
  literal confirmed as its only diff). All 22 re-confirmed parse-clean
  and UTF-8-BOM/ASCII-clean.
- Result: 25,782 -> 21,785 lines (15.5% reduction); comment density
  42.7% -> 32.2% codebase-wide. `Core.DeviceRecord.ps1` (worst
  offender) 73.7% -> 50.7% -- still the highest remaining percentage,
  an inherent floor for a short file whose comment-based-help header
  is a fixed cost.
- Status: complete, all 22 files verified. No live-GUI click-through
  was performed -- the token-level proof of zero code change is
  stronger evidence than a manual pass, and this environment has no
  interactive desktop session to run one from.

### 2026-08-31 - Claude (Fourth blind audit found the identical duplicate-serial compounding-cost issue in the Warranty facet, narrowed to one call site; fixed the same way (D-147))

- Instruction: Jeremy said "Do a fourth run," authorizing a fourth blind
  audit, same methodology. Spawned another fresh Agent, briefed on the
  post-D-146 state, asked whether the same duplicate-serial compounding-
  cost pattern could also apply to the Warranty facet's four
  `-WarrantyCache` call sites.
- Finding (Medium, independently verified by direct code read at every
  step, not taken on faith): same root mechanism as D-146 --
  `Resolve-MintWarrantyLookupCached` only writes a caller's
  `-WarrantyCache` on a SUCCESSFUL lookup, so it gives no protection
  against re-hammering a FAILING serial. But unlike AD, only ONE of
  Warranty's four call sites is actually unprotected -- confirmed by
  direct read: `Tab.Extract.ps1` (protected by its own
  `$SeenNormalizedSerials` pre-check), `Tab.Validate.ps1`'s Scan pass
  (protected by its own local `$placementCache`, which gates
  regardless of success/failure), and `Tab.Warranty.ps1` (protected --
  its input list is already de-duplicated by
  `ConvertTo-MintNormalizedSerialList`'s HashSet) all already had
  incidental protection. The one gap: `Tab.Validate.ps1`'s
  `Invoke-MintValidateFixPass` has NO per-serial gate at all -- it
  filters to `NeedsFix` (which doesn't exclude `IsDuplicate`) and each
  qualifying duplicate-serial file independently calls the Warranty
  facet. During a vendor outage, N duplicate-serial files queued for
  Fix would each cost their own live lookup, up to
  `Core.VendorLookup.ps1`'s ~90s deadline apiece. Not a correctness bug
  in D-144's fix and not a reason to revert it.
- Fixed: `Core.DeviceRecord.ps1` 0.2.3->0.2.4, new optional
  `-WarrantyLookupFailureCache` parameter (mirrors D-146's
  `-AdLookupCache` exactly; distinct from the pre-existing
  `-WarrantyCache`, a different success-only cache) -- a per-pass
  "already failed this pass" marker; a duplicate encounter within one
  pass is skipped with no new live lookup, while a fresh pass (new
  hashtable) still retries once, fully preserving D-144;
  `-ForceWarrantyRefresh` still bypasses it unconditionally. Omitted,
  behavior is unchanged from D-144. `Tab.Validate.ps1` 0.3.0->0.3.1 --
  `Invoke-MintValidateFixPass` builds one `$warrantyLookupFailureCache`
  per Fix pass and threads it through
  `Invoke-MintValidateUnifiedFixSingleFile` to the facet call. The
  other three call sites left unchanged -- already protected, so
  adding the parameter there would be inert.
- Testing: 10 isolated assertions -- confirmed omitting the new
  parameter preserves D-144 exactly (regression check); confirmed a
  duplicate encounter within one pass makes no new live lookup once
  the first attempt in that pass failed; confirmed a fresh pass still
  retries for real (D-144 not regressed); confirmed -ForceWarrantyRefresh
  still bypasses the gate; confirmed a succeeding serial is never
  written to the failure cache.
- Status: fixed and verified. Both files parse-clean and UTF-8-BOM/
  ASCII-clean.

### 2026-08-31 - Claude (Third blind audit found a real cost side effect of D-145's own fix; fixed with a per-pass short-circuit (D-146))

- Instruction: Jeremy said "Go for it" after D-145, authorizing a third
  blind audit, same methodology. Spawned another fresh Agent, briefed
  on the current state, asked explicitly to widen scope beyond
  re-confirming the first two fixes.
- Finding (Medium, verified myself before fixing) -- different in kind
  from D-144/D-145: not an independent bug, but a real cost consequence
  of D-145's own correct fix. Duplicate-serial hash files are never
  collapsed by `Core.Inventory.ps1`; two batch callers
  (`Core.Reports.ps1`'s AD-lookup report loop, Tab.Search.ps1's "Check
  AD Location" multi-select button) iterate raw files, not de-duplicated
  by serial. Before D-145, the first AD failure for a serial was cached
  unconditionally, so duplicates reused it for free -- accidentally
  cheap. After D-145's correct retry-on-failure fix, each duplicate file
  for the same serial now re-triggers its own AD attempt within one
  pass -- during an outage, N duplicate files cost roughly N x the
  ~10-20s AD timeout instead of 1x. Not a correctness bug and not a
  reason to revert D-145 (that would resurrect the button going inert)
  -- a genuine gap between "retry across passes" (what D-145 fixed) and
  "reuse within one pass" (what was accidentally free before).
- Fixed: `Core.DeviceRecord.ps1` 0.2.2->0.2.3, new optional
  `-AdLookupCache` parameter (mirrors the existing `-WarrantyCache`
  pattern) -- a per-pass "already failed this pass" marker; a duplicate
  encounter within one pass is skipped with no new AD call, while a
  fresh pass (new hashtable) still retries once, fully preserving
  D-145. Omitted, behavior is unchanged from D-145. Wired into both real
  batch callers: `Core.Reports.ps1` 0.3.1->0.3.2, `Tab.Search.ps1`
  0.24.0->0.24.1.
- Testing: 8 isolated assertions -- confirmed omitting -AdLookupCache
  preserves D-145 exactly (regression check); confirmed a duplicate
  encounter within one pass makes no new AD call; confirmed a fresh pass
  still retries for real (D-145 not regressed); confirmed a genuine
  success still memoizes normally.
- Status: fixed and verified. All 3 files parse-clean and UTF-8-BOM/
  ASCII-clean.

### 2026-08-31 - Claude (Second blind audit, same methodology, found the identical bug class in the ActiveDirectory facet (D-145))

- Instruction: Jeremy said "Do it again, same methodology used" after
  D-144. Spawned another fresh Agent with no conversation memory,
  briefed on the current (post-D-144) state only, explicitly asked to
  also hunt for the same bug class elsewhere.
- Finding (HIGH, verified myself before fixing): `Core.DeviceRecord.ps1`'s
  ActiveDirectory facet had the exact bug class D-144 fixed for
  Warranty -- `if ($null -eq $record.ActiveDirectory)` with no re-fetch
  at all. `Resolve-MintDeviceAdLocation` sets `Reachable=$false` for any
  transient AD error, meant to be retryable. Real, live impact: Search
  and Manage's "Check AD Location" button silently stopped working
  after its first failure for a given serial, for the rest of the
  session, no error shown. Fixed: `Core.DeviceRecord.ps1` 0.2.1->0.2.2,
  re-fetch now also fires on `-not $record.ActiveDirectory.Reachable`.
- More precise than a blind copy of D-144: AD's result has two separate
  fields, `Reachable` (could we query at all -- the transient-failure
  analog to Warranty's `Found`) and `Found` (given reachability, does
  the device exist there -- a stable fact once reachable, correctly
  left to still memoize). Verified this distinction empirically.
- Also caught and fixed in passing: a leftover wrong date
  ("2026-09-01") in my own D-144 inline comment, corrected to
  2026-08-31.
- Also flagged, not fixed: Existence/HashFile facets have a milder
  version of the same gap, but zero live callers request either facet
  anywhere in the codebase today -- recorded rather than fixed
  speculatively.
- Testing: 7 isolated assertions. Reproduced the "Check AD Location
  goes inert" bug first, confirmed the fix resolves it, and separately
  confirmed the Reachable-vs-Found distinction is correctly scoped (a
  stable not-found result and a genuine success both still memoize
  normally -- not an overly broad "always re-fetch").
- Status: fixed and verified. File is parse-clean and UTF-8-BOM/ASCII-
  clean.

### 2026-08-31 - Claude (Blind second-opinion audit of D-143 found and fixed a real regression (D-144))

- Instruction: Jeremy asked for "a secondary, blind audit of the
  systems you just touched" after D-143. Delegated to a fresh Agent
  with no conversation memory, briefed with a factual description of
  the change only (not an assertion it was correct), told explicitly
  not to assume it was right.
- Finding (HIGH, verified myself before fixing): `Core.DeviceRecord.ps1`'s
  Warranty facet memoization checked only `$null -eq $record.Warranty`,
  missing that a `Found=$false` result is still non-null.
  `Core.WarrantyCache.ps1`'s own disk cache deliberately never persists
  a negative result (its own doc comment explains why -- permanent
  suppression risk), and every direct caller before D-143 re-attempted
  a failed lookup on every call by design. The facet silently
  reintroduced that suppression for 5 of 6 migrated call sites,
  including Tab.Warranty.ps1's own default UI state. Fixed:
  `Core.DeviceRecord.ps1` 0.2.0->0.2.1, re-fetch condition now also
  fires on `-not $record.Warranty.Found`.
- Finding (LOW): `Core.Domain.ps1`'s `New-MintDeviceRecord` still
  declared a `HashDecode` property after D-143 removed the facet --
  contradicted D-143's own "removed entirely" intent. Confirmed nothing
  reads it before removing. Fixed: `Core.Domain.ps1` 0.14.1->0.14.2.
- The audit also independently re-verified everything D-143 claimed to
  have checked (load order, parameter contracts, all 6 call sites,
  parse/encoding) and confirmed it was genuinely correct -- one specific
  logic gap, not a sloppy round overall.
- Testing: 11 isolated assertions. Reproduced the regression first
  (stubbed the vendor call, confirmed a failed-then-recovered lookup
  incorrectly stayed failed before the fix), then confirmed the fix
  resolves it, plus regression-checked that success-case memoization
  and -ForceWarrantyRefresh both still work correctly.
- Status: both findings fixed and verified. D-143's own "Remaining
  risks: none identified" claim corrected in AI-Project-Plan.md rather
  than silently edited.

### 2026-08-31 - Claude (Warranty facet wired to the real implementation, consolidated onto D-011's single-lookup principle; HashDecode removed (D-143))

- Instruction: Jeremy gave a general decision rule rather than picking
  an option: "Change it in whatever way closest resembles the original
  ideology for the framework of the program. If it is something that
  can be realistically utilized, is beneficial, and will serve more
  than one function, then it is worth keeping. If it is redundant,
  stale, and there is no real good reason to keep it, then lose it."
- Applied: Warranty (real, working, beneficial, D-011 says it belongs
  in the one canonical resolver) -- kept and wired for real. HashDecode
  (zero implementation, zero callers, no roadmap urgency) -- removed
  entirely rather than kept as a stub.
- Files changed (5 total, each version-bumped): `Core.DeviceRecord.ps1`
  0.1.1->0.2.0 (new -WarrantyCache/-ForceWarrantyRefresh params on
  `Resolve-MintDeviceRecord`, threaded to
  `Resolve-MintWarrantyLookupCached`; HashDecode case removed entirely);
  `Tab.Extract.ps1` 0.17.1->0.18.0, `Tab.Search.ps1` 0.23.1->0.24.0 (2
  sites), `Tab.Validate.ps1` 0.2.0->0.3.0 (2 sites), `Tab.Warranty.ps1`
  0.14.1->0.15.0 -- all 6 real `Resolve-MintWarrantyLookupCached` call
  sites migrated onto the facet, preserving each site's own exact
  cache/force-refresh behavior. Deliberately did NOT touch
  `Tab.ImportFiles.ps1`'s `Resolve-MintImportFileWarrantyLookupReadOnly`
  -- D-095 requires Staging's classification pass to never auto-persist
  a warranty result, which the auto-persisting facet would violate.
- Correctness check before migrating: `Resolve-MintDeviceRecord`
  normalizes via `New-MintSerialNumber` (strips a hyphen-prefix), more
  aggressive than the direct call's own `.Trim().ToUpperInvariant()`.
  Confirmed safe -- real device serials never contain hyphens (already
  established elsewhere in this codebase), and two of three pre-existing
  facets already normalize this same way.
- Testing: 15 isolated assertions, all passing -- HashDecode now throws;
  Warranty facet returns the real shape via a genuine disk cache-hit;
  -WarrantyCache passthrough proven with a caller-only hashtable entry;
  session memoization proven; -ForceWarrantyRefresh proven to bypass it.
  Two self-caught mistakes in my own first test draft, both corrected
  before considering this done: a wrong expected Source value (missed
  D-086's own already-documented cache-hit display rule), and an
  assumption that -ForceRefresh "re-reads the cache" when its real
  contract is "skip the cache check and call the live vendor lookup" --
  would have made a real network call from an automated test; rewrote
  using a stubbed, call-counting `Resolve-MintWarrantyLookup` instead.
  All 6 migrated call sites re-read individually afterward to check for
  reference errors a parser can't catch.
- Documentation: `Documentation\00-Documentation-Index.md`'s D-142
  "Known gaps" entry updated to resolved; new ADR-020 in
  `09-Architecture-Decision-Records.md`; new entry in `10-Changelog.md`.
- Status: complete, tested, documented. All 5 files parse-clean and
  UTF-8-BOM/ASCII-clean.

### 2026-08-31 - Claude (Deployment-readiness follow-up: warranty-facet doc drift corrected, Q-16/Q-17 closed, documentation set updated (D-142))

- Instruction: Jeremy asked "What are some loose ends that need to be
  tied up before this goes into deployment" -- answered with a survey
  punch list, then he responded item-by-item. This entry covers the
  follow-through.
- Investigated (Jeremy: "Find out"): `Resolve-MintDeviceRecord`'s
  HashDecode/Warranty facets (Core.DeviceRecord.ps1) still return a
  placeholder and are requested by zero live callers -- dormant. The
  file's own claim that Core.VendorLookup.ps1 "remains a stub" is false;
  a full, live Lenovo/Getac implementation exists and is called
  DIRECTLY by five tab modules, bypassing this resolver -- an informal
  departure from D-011's "ONE lookup implementation" principle.
  Corrected the stale comment and the facet's own Note text
  (`Core.DeviceRecord.ps1` 0.1.0->0.1.1); deliberately did NOT unify the
  two paths, since that's a real design decision for Jeremy, not a
  silent refactor.
- Closed Q-16 (Jeremy: "Yes"): enumerated and deleted 466 directories
  matching `mint_*_test_<32-hex-char>` under `%TEMP%` -- confirmed exact
  match to the audit's own documented count/pattern before deleting;
  466 deleted, 0 failed. Left every other `mint_`-prefixed scratch
  artifact untouched (out of the agreed scope).
- Closed Q-17 (Jeremy: "Device age will always be the age from the
  warranty start"): confirmed `Get-MintReportDecommissionedRows`'s
  existing warranty-start-to-today formula was already correct; no code
  change, doc comment updated to record the confirmed answer
  (`Core.Reports.ps1` 0.3.0->0.3.1).
- Updated documentation set (Jeremy: "Update documentation"):
  `Documentation\00-Documentation-Index.md`,
  `08-Verification-and-Release-Plan.md`,
  `09-Architecture-Decision-Records.md`, `10-Changelog.md` all updated
  -- new Known-gaps entries for the audit cycle and the warranty-facet
  drift, a new Changelog entry for D-138 through D-142, and an honest
  note that this round's own test scripts were never added to the
  persisted regression battery Document 08 otherwise describes.
- Explained, not resolved (Jeremy: "Explain" x2): Q-9 (data-root
  migration timing, still deliberately deferred by Jeremy's own past
  instruction) and Q-12 (Group Tag variable-list format) -- Q-12 was
  flagged as LIKELY STALE: real Group Tag infrastructure was clearly
  built out after this question was opened (grouptags.csv,
  Get-MintGroupTagMapInternal, configured dropdowns across four tabs,
  a header-validation fix this same audit cycle), but the question was
  never formally revisited or closed. Left OPEN in the log rather than
  closed unilaterally -- surfaced for Jeremy's own confirmation.
- Confirmed (no action needed): distribution/production promotion
  remains entirely Jeremy's own manual step, done just before the next
  push, per his own explicit confirmation; live smoke-testing is his own
  ongoing activity, to be documented by him if he finds anything.
- Open items for Jeremy: Q-9 and Q-12 remain open in AI-Project-Plan.md
  Section 10 -- Q-12 in particular likely just needs his own
  confirmation that it's already resolved.

### 2026-08-28 - Claude (D-138's 15 of 17 Low findings fixed and verified; 2 flagged as open questions (D-141))

- Instruction: "Now hit the low risk issues," following D-140's Medium
  pass. All 17 Low findings from D-138 addressed: 15 fixed in code, 1
  (#31, `$matches` shadowing) confirmed already fixed as a side effect
  of D-139's earlier work, and 2 (#39 test-sandbox cleanup, #41 Device
  Age semantics) deliberately NOT resolved unilaterally -- flagged as
  new open questions (Q-16, Q-17 in AI-Project-Plan.md) instead, since
  neither is a code-correctness bug: #39 is a test-tooling gap requiring
  a bulk-delete decision, #41 is a product-judgment call.
- Files changed (8 total, each version-bumped with its own CHANGE LOG
  entry): `Core.Csv.ps1` 0.9.0->0.9.1 (StrictMode-safe row access
  consistency); `Core.ActiveDirectory.ps1` 0.2.0->0.3.0 (ambiguous AD
  match now surfaced instead of silently picking the first result; every
  ADSI/COM object now disposed); `Tab.Search.ps1` 0.23.0->0.23.1 (Check
  AD Location no longer re-scans the whole grid per selected file);
  `Core.Inventory.ps1` 0.12.1->0.13.0 (new BySerial hashtable index
  replaces a linear scan in `Find-MintInventoryFilesBySerial`; a
  duplicate models.csv folder name is now reported instead of silently
  dropped); `Tab.Upload.ps1` 0.7.0->0.8.0 (progress feedback on the Load
  loop; two silent catches now log); `Tab.Extract.ps1` 0.17.0->0.17.1
  (Manufacturer/Model choices catches now log); `Tab.Reports.ps1`
  0.3.0->0.3.1 (per-editor-session data-row cache for InData filter
  fields); entry script 0.28.0->0.29.0 (8 previously-unprotected
  `Write-MintLog` calls now nested in their own try/catch; a restored
  grid column's width can no longer silently widen back to 20px on
  repopulate -- the general form of D-137's own fix; the numeric grid
  sorter no longer throws on a null/non-numeric key; the column-
  visibility menu no longer risks saving under the wrong grid's key).
- Testing: 3 isolated/functional test scripts (21 passing assertions)
  plus a live AD test against this real domain confirming the
  disposal/ambiguity changes resolve correctly. Remaining fixes (mostly
  logging-only changes inside WinForms closures, or narrow consistency
  fixes) verified via parse/encoding cleanliness and code reading,
  matching this round's own risk level.
- Open items for Jeremy: Q-16 and Q-17 (AI-Project-Plan.md Section 10)
  both need his own answer. This closes out every finding from the
  original D-138 audit report except those two.

### 2026-08-28 - Claude (D-138's 18 Medium findings fixed and verified (D-140))

- Instruction: "Just go ahead and do the medium issues," following D-139's
  Critical/High pass. All 18 Medium findings from D-138 implemented; the
  17 Low findings remain open, out of scope for this instruction.
- New shared infrastructure (both new precedents for this codebase):
  `Write-MintFileTextAtomic` (Core.Csv.ps1) -- temp-file-then-swap so an
  interrupted write can't corrupt a live CSV; `Get-MintFileFingerprint`/
  `Test-MintFileFingerprintUnchanged` (Core.Csv.ps1) -- D-030's already-
  accepted optimistic-concurrency design, implemented for the first time.
- Files changed (11 total, each version-bumped with its own CHANGE LOG
  entry): `Core.Csv.ps1` 0.8.0->0.9.0 (atomic write + fingerprint
  primitives); `Core.Reports.ps1` 0.2.0->0.3.0 (Decommissioned-row
  boolean fields default to `$null`/blank instead of a fake `$false`;
  CSV export now atomic); `Core.Domain.ps1` 0.14.0->0.14.1
  (`[AllowEmptyString()]` on `New-MintUploadRow`); `Core.VendorLookup.ps1`
  0.8.0->0.9.0 (Lenovo session only cached on success; Lenovo/Getac only
  report `Found` when real data came back); `Core.WarrantyCache.ps1`
  0.5.0->0.6.0 (fingerprint-based retry closes a cache-write race;
  in-memory duplicate-serial path formats dates correctly, matching the
  D-086 fix already on the disk-write path); `Core.EventLog.ps1`
  0.1.0->0.1.1 (trim before hash, matching the trim already applied on
  read -- closes a false-positive tamper-chain-break risk);
  `Core.Inventory.ps1` 0.12.0->0.12.1 (3 loaders gained the same header
  validation their siblings already had); `Tab.Upload.ps1` 0.6.2->0.7.0
  (lookup failures get their own ReadError status + logging; overwrite
  warning now names the existing file's device count); `Tab.Validate.ps1`
  0.1.1->0.2.0 (2 backup-handle-leak fixes, both live-verified);
  `Tab.Search.ps1` 0.22.0->0.23.0 (decommission master-list race closed;
  Copy-succeeded/Delete-failed now gets its own message, live-
  reproduced; Restore's per-row failure isolation now matches
  Decommission's pattern); `Tab.Extract.ps1` 0.16.1->0.17.0 (unresolved
  conflict now fails explicitly instead of overwriting, live-verified;
  matching backup-handle-leak fix to Tab.Validate.ps1's).
- Testing: 8 isolated/functional test scripts, 57+ passing assertions,
  covering 15 of 18 findings with direct functional tests; the other 3
  sit inside WinForms button-click closures and were verified by code
  reading plus the parse/encoding sweep. Two fixes were LIVE-reproduced
  against real file locks, not just reasoned about (the decommission
  Copy/Delete race; the Validate backup-handle close, confirmed by
  successfully re-opening the resulting archive exclusively afterward).
  Also caught and fixed two of my own bugs empirically while building
  the atomic-write helper: `Split-Path -LiteralPath -Parent` is
  genuinely ambiguous in PS 5.1 (P24, already documented in this
  project's pitfalls reference); `[System.IO.File]::Replace` with a
  `$null` backup argument throws in this actual environment despite
  MSDN documenting null as valid.
- Open items for Jeremy: the 17 Low findings from D-138 remain open.
  Full per-finding detail in `AI-Project-Plan.md` D-140.

### 2026-08-28 - Claude (D-138's 1 Critical + 6 High findings fixed and verified (D-139))

- Instruction: Jeremy's own read of the D-138 report -- "Correct the
  critical and high risk ones now." Narrow and explicit: the 7 Critical/
  High findings only, not the 18 Medium/17 Low findings, left untouched
  by design.
- Files changed (10 total, each version-bumped with its own CHANGE LOG
  entry): `Core.Backup.ps1` 0.0.1->0.1.0 (Critical: report-CSV writer now
  routes through the shared, already-guarded `ConvertTo-MintCsvFieldValue`
  instead of its own unfixed duplicate); `Core.ActiveDirectory.ps1`
  0.1.0->0.2.0 (High: RootDSE/domain binds now bounded by a new
  runspace-based timeout helper, 10s budget, plus `ClientTimeout` set on
  the DirectorySearcher); `Core.VendorLookup.ps1` 0.7.0->0.8.0 (High: new
  90s overall wall-clock deadline across a full Lenovo+Getac retry
  sequence, plus `[AllowEmptyString()]` on 5 functions);
  `Core.WarrantyCache.ps1` 0.4.0->0.5.0 (High:
  `[AllowEmptyString()]` on 3 more functions); `Tab.Search.ps1`
  0.21.2->0.22.0 (High: `Remove-MintDecommissionMasterRow` now keys on
  Serial+Year+Month/Day together, not Serial alone); `Tab.Validate.ps1`
  0.1.0->0.1.1 (High: the fix pass's final backup-archive close is now
  try/catch'd instead of bare); `Core.Inventory.ps1` 0.11.0->0.12.0
  (High: `Find-MintInventoryFilesBySerial`'s bare `return @(...)` fixed
  to the codebase's own established `,$array` pattern), with its three
  affected call sites fixed in lockstep -- `Core.DeviceRecord.ps1`
  0.0.0->0.1.0, `Tab.ImportFiles.ps1` 0.5.0->0.5.1, `Tab.Upload.ps1`
  0.6.1->0.6.2 -- each changed from a now-double-wrapping `@(FunctionCall)`
  to a plain assignment.
- Testing: every fix verified by isolated test (6 separate test scripts,
  47+ passing assertions total), plus one live functional test against
  this machine's real AD (`DC=hallcounty,DC=org`) confirming both
  `Test-MintAdReachable` and `Resolve-MintDeviceAdLocation` still resolve
  correctly and fast (<1s) with the new timeout in place. All 10 touched
  files parse-clean (0 AST errors) and UTF-8-BOM/ASCII-clean.
- Correction to the D-138 report: the Critical finding's "currently
  exploitable" framing was overstated. Tracing all 10 real call sites of
  `Add-MintRunReportRow` found every one already prefixes/fixes its
  `-Details`/`-Action` values, so no existing caller could actually reach
  the injection today. The fix remains correct and necessary (closes the
  gap for any future caller, restores consistency with the rest of the
  app's CSV writers) -- reported to Jeremy plainly rather than left as
  the original overstatement.
- Open items for Jeremy: the 18 Medium and 17 Low findings from D-138
  remain open, out of scope for this instruction. Full detail (per-
  finding fix description, verification method) in `AI-Project-Plan.md`
  D-139.

### 2026-08-28 - Claude (Full pre-production audit -- every file read, 42 findings ranked and delivered (D-138))

- Files reviewed: all 22 MINT files (~24,000 lines) -- Jeremy asked for
  an unscoped bugs/errors/gaps audit ahead of production deployment.
  Reports tab + this week's Import Files changes reviewed personally;
  the other 8 file groups each got a dedicated, fully-briefed review
  pass. Two of those passes hit a session usage cap partway through
  (data-safety core: Csv/FileOps/Backup/EventLog/Logging; shared UI
  infrastructure: Theme/Dialogs) -- completed directly rather than
  left undone.
- Findings: 42 total (1 Critical, 6 High, 18 Medium, 17 Low), delivered
  to Jeremy as a standalone report. Critical: the per-run report CSV
  writer never got the 2026-08-24 formula-injection fix every other
  CSV writer in the app has -- a free-typed Group Tag can still write
  a live Excel formula into a report file. High: no AD call timeout
  (can hang the whole app), vendor-lookup retries compounding to a
  ~15-minute worst case per serial, missing `[AllowEmptyString()]` on
  the primary warranty-lookup entry points (the exact bug class that
  already cost this codebase a real incident once), Restore silently
  deleting an unrelated decommission record sharing the same serial,
  an unprotected backup-archive close that can crash the app right
  after Validate's bulk fix already succeeded, and a bare-array-return
  bug (empirically reproduced) that crashes two facets of "the ONE
  device lookup implementation in the whole program," currently
  dormant since no live caller reaches them yet. Full D-138 entry in
  `AI-Project-Plan.md` has the complete Critical/High detail plus a
  summary of the Medium/Low tier and what was confirmed clean (notably:
  zero live `.GetNewClosure()` violations anywhere in the app, zero
  unfixed bare-`(if(...))`-as-argument occurrences, D-105's security
  claims re-hold everywhere except the report-CSV gap above).
- Testing: this was a read-only investigation -- no code changed, no
  fixes applied. Every finding traces to specific file/line references
  and a concrete failure scenario, tagged Proven or Likely Inference.
- Open items for Jeremy: read the full report and decide what to act
  on and in what order; the Critical finding is a one-line fix worth
  prioritizing given it reintroduces a vulnerability class already
  believed closed. Also flagged separately: 466+ leftover test-sandbox
  temp directories have accumulated with no cleanup step in the test
  harness -- a tooling gap, not a MINT bug.

### 2026-08-28 - Claude (Group Tag column width fix: D-136 raised the wrong property (D-137))

- Files reviewed: Jeremy confirmed D-136's columns/buttons work live,
  but reported the actual width fix was wrong: "the Group Tag column
  will not let me reduce it below the default. I want to be able to
  reduce it to smaller than the default" -- a direct restatement of his
  original "It should still remain resizable, though" from the D-136
  request, which shipped code did not honor.
- Files changed: `MIS Inventory Navigation Tool.ps1` (0.27.0 -> 0.28.0).
  Root cause: D-136 set the Group Tag column's `MinimumWidth` (a hard
  resize floor) to the dropdown-driven value, instead of only raising
  its starting `Width`. Fixed: `Set-MintGridColumnWidthsToContent` now
  raises only the starting Width when the dropdown demands more room;
  `MinimumWidth` stays the ordinary flat 20px floor every other column
  already has (D-081, unchanged). Renamed
  `Get-MintGroupTagColumnMinimumWidth` to
  `Get-MintGroupTagColumnDefaultWidth` to match what it now feeds --
  its own measurement logic is unchanged.
- Testing: rewrote the isolated test to exercise the actual shipped
  function against a real DataGridView (not just the measurement
  helper) -- confirms the wide starting default still works, MinimumWidth
  is genuinely 20 again, the column can actually be resized narrower
  than its default (the literal missing behavior), and no other
  column's MinimumWidth is affected (5/5 passed). Parse-check and
  encoding check clean.
- Open items for Jeremy: please confirm live that the column now
  resizes narrower than its default as expected.

### 2026-08-28 - Claude (Icon fix + fallback (D-135); Import Files Group Tag/Assigned User revamp, File Name column removed, Group Tag width standard (D-136))

- Files reviewed: Jeremy's four-item request -- (1) the title-bar/
  taskbar icon disappearing again (same symptom as D-120, recurring);
  (2) Import Files gains Group Tag/Assigned User columns between Model
  and Destination Path, plus Batch Edit for them matching Search and
  Manage; (3) remove the File Name column; (4) every tab's Group Tag
  column should have its minimum width set to the longest dropdown
  value, staying resizable. Asked one clarifying question (AskUserQuestion)
  on how the new Group Tag/Assigned User batch edit should sit next to
  the existing Device Type/Manufacturer/Model one -- Jeremy chose a
  separate, dedicated button.
- Files changed: `MINT.ico` re-copied to the project root from `Mint
  Logo\MINT_Logo.ico`. `MIS Inventory Navigation Tool.ps1` (0.26.0 ->
  0.27.0): icon loader now falls back to `Mint Logo\MINT_Logo.ico` if
  `MINT.ico` is ever missing again; `Set-MintGridColumnWidthsToContent`
  gained a Group-Tag-specific MinimumWidth floor computed from the
  widest string in that column's own dropdown Items (new
  `Get-MintGroupTagColumnMinimumWidth`), applying automatically to
  every grid with a `GroupTag` column (Search and Manage, Upload
  Builder, Import Files) with no per-tab change needed. `Core.Domain.ps1`
  (0.13.0 -> 0.14.0): `New-MintImportFileRowPlan` gained GroupTag/
  AssignedUser, read from the staged file itself. `Tab.ImportFiles.ps1`
  (0.4.0 -> 0.5.0): File Name column removed; Group Tag (typeable
  combo, `Get-MintCombinedGroupTagChoices`) and Assigned User (validated
  via `ConvertTo-MintAssignedUserValue`) columns added, in-memory-only
  until Import runs (same model as Device Type/Manufacturer/Model
  already use here); new "Batch Edit Group Tag/User" button reusing
  `Show-MintBatchEditDialog` verbatim, the same dialog Search and
  Manage's own Batch Edit button opens.
- Testing: parse-check and UTF-8 BOM/ASCII-only check clean on all
  three files. New isolated functional tests for
  `Get-MintGroupTagColumnMinimumWidth` (5/5 passed) and
  `New-MintImportFileRowPlan`'s new fields plus a full regression check
  of its existing fields (14/14 passed). A live full-app smoke test
  could NOT be completed -- MINT was launched multiple times via
  automation and each time allocated memory consistent with a real
  load but never showed a window, staying otherwise idle (not crashed,
  not looping). While investigating, found four long-abandoned,
  still-running `build_booklet_timed.ps1` processes (the superseded
  Word-COM script from the D-133/D-134 booklet saga earlier this same
  session) stuck the identical way since 2026-08-25 -- cleaned up.
  Reasonably strong but indirect evidence this is a characteristic of
  automated GUI process launches in this session's environment
  generally (plausibly related to the Word COM `SaveAs2` hang from
  D-133), not something today's code changes caused, but stated as an
  inference, not a proven root cause.
- Open items for Jeremy: launch MINT the normal way (the `.vbs`
  launcher, not through automation) to actually confirm the new
  columns/buttons work end to end -- the isolated tests only prove the
  logic in isolation. If MINT also fails to launch normally and
  interactively, that would be a real, different problem worth
  reporting back immediately.

### 2026-08-26 - Claude (Booklet: D-133's rebuild rejected as too different; replaced with a surgical, text-only OOXML edit of Jeremy's own restored file (D-134))

- Files reviewed: Jeremy rejected the D-133 Pandoc rebuild -- "the
  document has changed way too much" -- deleted it, and restored his
  own previously hand-corrected copy (Aug 24 15:44, pre-dating the
  Reports tab documentation work entirely). His instructions: add the
  Reports-tab text to the right places, matching existing formatting
  exactly; do not touch page 1, the headers, or any image; no outside
  links; edit existing sections' text in place rather than regenerating
  anything.
- Files changed: `Documentation\Booklet\MINT Documentation Booklet.docx`
  (Jeremy's restored file) edited in place via direct OOXML text/
  paragraph surgery on `word/document.xml` (41 edits, each anchored to
  a specific paragraph's unique `w14:paraId` and pre-checked for a
  unique text match before applying) plus one addition to
  `word/numbering.xml` (a fresh, independently-restarting numbered-list
  definition for the new Reports section's 6-step walkthrough). No Word
  COM used anywhere, same reasoning as D-133. Covered the same ground
  D-132 already covers in the standalone doc set, ported into this
  file's real structure: new Doc 03 Section 9 (Reports walkthrough,
  renumbering 9/10 to 10/11), new Doc 02 Section 3.7 (7 "MINT shall"
  statements, old 3.7 to 3.8), Doc 04's module lists and two new
  subsections (4.5, 5.4), a new Doc 09 ADR-019, a new Doc 10 changelog
  entry, and smaller bullet/count additions in Docs 00, 01, 05, 07, 08.
  Every touched document's "Last updated" line moved from 2026-08-24 to
  2026-08-25 to match the Markdown set's own date.
- Investigation before writing anything: confirmed the restored file's
  real structure (genuine Word-authored `numbering.xml`/`styles.xml`/
  `theme1.xml`, not something Pandoc would produce; a real, dynamic
  local Table of Contents field before each of the 11 documents' own
  content, plus one master TOC field up front -- both left completely
  untouched, since hand-editing a live field's cached page numbers
  would mean faking numbers only Word's own layout engine can compute)
  and confirmed the existing numbered lists each use an independently-
  restarting `numId`, which is why the new list got its own fresh one
  rather than risking a shared/continued count.
- Testing: well-formed-XML check on both edited parts; re-zipped and
  diffed the new archive's part list against the original -- identical;
  every header/footer/media/styles/theme/settings part confirmed
  byte-for-byte identical (SHA-256) to the untouched original, directly
  proving page 1, headers, and every image were never touched;
  page-break count unchanged at 11; bookmark start/end counts still
  balanced; paragraph count grew by exactly the 41 logged insertions;
  spot-read the new paragraphs' extracted text directly from the final
  XML to confirm it reads correctly in place.
- Deliberately not done: the file was never opened in Word during this
  work (Word COM is the unreliable piece here, so it was avoided
  end to end, including for verification) -- open-and-look is Jeremy's
  own step. `pdf\` and the Booklet's own `.pdf` remain untouched/stale,
  per his standing instruction that he handles PDF generation himself.
- Open items for Jeremy: open the file in Word (a plain open was never
  observed to be slow in this environment, only automated COM saves)
  and confirm the new sections read and look right; run one Ctrl+A/F9
  field update so the TOC page numbers and entries catch up to the new
  content, which is normal after any Word document grows and not
  specific to this edit method.

### 2026-08-26 - Claude (Booklet rebuilt via Pandoc + direct OOXML editing after Word COM's SaveAs2 proved unreliable in this environment (D-133))

- Files reviewed: Jeremy asked to update `Documentation\Booklet\MINT
  Documentation Booklet.docx` itself (the combined cover+TOC+all-11-docs
  file, distinct from the individual `docx\` snapshots already handled
  in D-132). The rebuild used the original Word-COM approach
  (`Documents.Add()`, 11x `InsertFile`, TOC field, header/footer,
  `SaveAs2`) -- document assembly finished in ~20-30 seconds every time,
  but `SaveAs2` itself then hung for 15-30+ minutes without ever
  completing or crashing, across six separate attempts over two days.
- Diagnosis performed before giving up on Word COM: saving to a local
  temp path instead of the OneDrive-synced destination was equally slow
  (rules out OneDrive/AV-on-that-path); a trivial one-image/one-field
  blank document was also stuck 84+ seconds and climbing (rules out
  document size/complexity); the D-132 `docx\*.docx` snapshots, written
  by Pandoc -- a different program -- to the same folder tree, saved
  instantly (confirms the slowdown is specific to Word's own COM save
  path, not the machine or folders generally). Leading suspect is
  endpoint security (SentinelOne is present in this environment)
  scrutinizing Word automation specifically, though this was never
  directly confirmed since there's no visibility into EDR logs from
  here -- worth knowing if any future Word-COM automation is attempted
  in this same environment.
- Files changed: `Documentation\Booklet\MINT Documentation Booklet.docx`
  replaced with a version built without any Word COM involvement:
  Pandoc converts one concatenated Markdown file (all 11 source docs,
  joined with real OOXML page breaks -- plain `\newpage` does not
  produce one) straight to `.docx` in a single call, using a YAML title
  block for the cover text (confirmed via raw XML that Pandoc places
  title-block content before its own `--toc` insertion, unlike ordinary
  body content). A small `--reference-doc` template supplies the
  header (logo, every page) and footer (page number, every page),
  itself built by directly editing a Pandoc-generated base docx's OOXML
  by hand (header1.xml/footer1.xml/relationships/content-types/
  sectPr's titlePg) rather than through Word. The cover logo (no native
  image field in a Pandoc title block) was added the same way as a
  second OOXML edit pass. Total build time: about 3 seconds.
- Testing: no Word COM was available to sanity-check interactively, so
  verification was file-format-level instead -- zip integrity and
  well-formed-XML checks on every part; confirmed text-run order is
  cover -> TOC -> Document 00 -> ... as intended; confirmed exactly 11
  page breaks and 1 section; confirmed the header/footer/logo/titlePg
  wiring carried through; confirmed the new Reports-tab content (21
  "Reports" mentions) is present post-merge. Known, accepted limitation:
  Pandoc's TOC field has no pre-computed page numbers (only Word's own
  layout engine can compute those) -- it will populate on first
  Ctrl+A/F9 or on Word's own "update fields" behavior, not before.
- Deliberately not done: `pdf\` and the Booklet's own `.pdf` remain
  untouched/stale, per Jeremy's standing instruction that he handles
  PDF generation himself -- flagged to him that the existing
  `docx_to_pdf.ps1` also uses Word COM's `SaveAs2` and may hit this
  same hang.
- Open items for Jeremy: open the new booklet directly in Word (opening
  a document was never observed to be slow here, only saving one via
  COM automation) to confirm it looks right and update the TOC field if
  it shows blank on first open; consider flagging the Word-COM-hangs-
  here finding to IT/Security since it will resurface for any future
  automated Office document generation in this environment, not just
  this file.

### 2026-08-25 - Claude (Documentation set updated for the Reports tab; individual docx snapshots regenerated (D-132))

- Files reviewed: Jeremy: "Update all of the documentation to include
  this new tab. Update the docx's as well. Don't bother with the pdfs,
  I'll handle that." Researched the doc set's real structure first
  (Markdown is the maintained source under
  `...\Documentation\*.md`; the 11 documents are a formal audience-
  facing set, not one-per-tab; per-tab content lives in Document 03's
  own sections) before editing.
- Files changed: all under `...\MIS Inventory Navigation Tool
  Development\Documentation\`. 03 (User Guide) gained a new Section 9
  Reports walkthrough, matching the existing tab-section format. 01 and
  02 gained Reports as capability/requirement #7 (02 also got a full
  "MINT shall..." requirements section with an honest verification
  note -- no persisted test suite for this tab yet). 04 updated module
  counts (19->21) and added two new subsections: the JSON-on-shared-
  filestore data model (explicitly disambiguated by name from the
  pre-existing, unrelated per-action `Reports` output folder) and a
  report-generation data-flow diagram. 05 noted Reports reuses the
  already-audited CSV writer rather than needing a fresh security
  review. 07 updated its module/decision counts. 09 gained one new ADR
  (ADR-019, scoped to just the JSON departure -- the genuinely
  architectural part, not the tab addition itself). 10 gained a new
  changelog entry bridging 2026-08-24 to 08-25, which also caught up
  some earlier undocumented work (Device Age, the icon fix, the
  documentation set's own completion) that had no changelog entry yet.
  00 and 08 both gained a matching "no Reports test suite yet" Known
  Gaps bullet. 06 was reviewed and deliberately left unchanged (already
  general enough to cover this without a specific mention).
- Also regenerated all 11 individual `.docx` snapshots via Pandoc
  (found already installed at `%LOCALAPPDATA%\Pandoc\pandoc.exe` from a
  prior session), reproducing the original header-line hard-break
  preprocessing since the original conversion script no longer exists
  on disk (it lived in an ephemeral scratchpad, not the committed
  project). Verified by extracting and grepping the regenerated
  `03-User-Guide.docx`'s own XML directly for the new content, not just
  trusting a clean Pandoc exit code.
- Deliberately not done: the `pdf\` folder and the combined `Booklet\`
  (docx+pdf) are now stale and Jeremy said he'll handle those himself;
  rebuilding the Booklet would also require rewriting
  `build_booklet.ps1` from scratch. The Production line's own
  intentionally-frozen documentation folder (ADR-015) was also left
  untouched -- it only changes via a formal promotion step.
- Testing: every "Last updated" date, tab/module count, and renumbered
  section cross-reference was verified via direct grep sweeps across
  the whole `Documentation\` folder, not assumed complete from memory.
- Open items for Jeremy: no visual/formatting check has been done on the
  regenerated `.docx` files (content presence was verified via raw XML,
  not a rendered look) -- worth a quick open-in-Word glance. PDFs and
  the Booklet are next, on your side.

### 2026-08-25 - Claude (Serial Number is now mandatory on every report (D-131))

- Files reviewed: Jeremy: "Let's make Serial Number default... just make
  it default and non-removable." Asked one clarifying question on what
  "non-removable" means; Jeremy chose: present with Remove disabled, but
  its own filter stays fully usable like any other field.
- Files changed: Tab.Reports.ps1 (0.2.0->0.3.0) -- `Show-MintReportEditorDialog`
  now auto-inserts a Serial Number entry at position 0 if missing
  (covers both a brand new report and, defensively, an existing one
  saved before this rule existed); `$removeButton`'s handler blocks
  removing Serial Number specifically with an explanatory MessageBox,
  everything else (Move Up/Down, Edit Filter, and D-130's duplicate-field
  capability) stays normal for it.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only. Not covered
  by an isolated test -- straightforward UI list manipulation, not the
  kind of PowerShell subtlety this project's tests exist to catch.
- Open items for Jeremy: confirm live -- a new report always starts with
  Serial Number present, removing it shows the expected message instead
  of removing it, and its own Edit Filter still works normally.

### 2026-08-25 - Claude (Exclude/Invert for every filter kind, duplicate-field OR/AND logic, a Model Folder/Model Name suggestion dropdown, Machine Type as a real dropdown (D-130) -- self-caught a fresh double-wrap regression before it shipped)

- Files reviewed: Jeremy answered D-129's three clarifying questions
  (all recommended defaults): Manufacturer stays multi-select checkboxes;
  Exclude/Invert applies to every filter kind; duplicate fields OR
  within the same field, AND across different fields.
- Files changed: Core.Domain.ps1 (0.12.0->0.13.0) -- New-MintReportFieldEntry
  gained -Invert. Core.Reports.ps1 (0.1.0->0.2.0) --
  Test-MintReportRowMatchesFilter applies Invert once at the end for
  every Kind; Test-MintReportRowMatchesAllFilters now groups by FieldKey
  (OR within a field's enabled entries, AND across fields);
  Export-MintReportToCsv deduplicates CSV columns by FieldKey; Machine
  Type converted Text->Categorical/InData (no existing controlled list
  for it anywhere in the app); new Get-MintReportInDataDistinctValues
  (shared helper) and Get-MintReportTextSuggestions. Tab.Reports.ps1
  (0.1.0->0.2.0, first version bump since D-121 despite the entire
  D-122-D-129 stabilization pass -- closed that gap here too) -- new
  Exclude checkbox in the filter dialog; Add Field no longer excludes
  fields already in the report; duplicate rows in the fields grid get
  "(2)"/"(3)" suffixes; a "pick a known value" dropdown for Model
  Folder/Model Name that fills the Contains box (not a literal
  radio-toggle as Jeremy described -- flagged as a simplification he can
  push back on).
- Self-caught regression: extracting the shared InData-derivation helper
  broke it at BOTH of its own call sites by wrapping the new helper's
  call in `@(...)` directly -- the exact P25/D-129 double-wrap pitfall,
  this time self-introduced during this very refactor rather than
  inherited from existing code. This also would have silently broken
  Decommission Year's own already-working InData choices, which had been
  safe, inline code before the refactor. Caught by this change's own
  16-assertion test suite (2 failures) before reaching Jeremy; fixed at
  both sites; confirmed via a separate 10-assertion regression pass that
  Decommission Year and D-129's three function-sourced fields still work.
- Testing: all three files parse-checked 0 AST errors, UTF-8
  BOM/ASCII-only. 26 total isolated assertions passed across two test
  files covering Invert (Categorical + Text), duplicate-field OR/AND
  logic including the disabled-duplicate-does-not-neutralize case, CSV
  column dedup, text-suggestion derivation, and the regression pass.
- Open items for Jeremy: none of this has been exercised live yet.
  Please build one report using each new capability -- an inverted
  filter, the same field added twice, and the Model Folder/Model Name
  suggestion dropdown -- to confirm the live UI matches what was
  verified in isolation.

### 2026-08-25 - Claude (First real usability pass on Reports: a fourth P25 double-wrap bug ("System.String[]" checkboxes), Machine Type converted to a real dropdown, a Fields column added (D-129); several feature requests deferred pending Jeremy's answers)

- Files reviewed: with the crash chain resolved (D-121-D-128), Jeremy
  did a full field-by-field pass and reported Device
  Type/Group Tag/Manufacturer each showed one checkbox reading the
  literal text "System.String[]"; Machine Type should be a dropdown
  instead of free text; and the saved-reports grid's Data Scope column
  alone isn't informative enough. He also raised several open feature
  requests (per-field text-suggestion dropdowns, an Exclude/Invert
  option, allowing a field to be added twice) -- held for a follow-up
  decision, not guessed at.
- Root cause of the "System.String[]" bug: a FOURTH instance of this
  project's own well-documented P25 double-wrap pitfall.
  `Get-MintReportFieldChoices` called `return ,@(& $functionName)` for
  any function-sourced Categorical field -- the callee functions
  (Core.Inventory.ps1) already correctly `return ,$array`, but wrapping
  the bare call itself in `@(...)` double-wraps it into a one-element
  array containing the whole original array. Fixed by capturing via
  plain assignment first, matching every other fixed instance of this
  pattern in the file.
- Files changed: Core.Reports.ps1 -- the double-wrap fix; Machine Type's
  registry entry converted from Text to Categorical with
  `ChoiceSource = 'InData'` (no existing controlled list for this field
  anywhere in the app -- it's a free-text vendor warranty code -- so its
  checklist derives from values actually present in the data, same
  mechanism already used for Decommission Year). Tab.Reports.ps1 -- new
  `Get-MintReportFieldSummaryText` helper and a third grid column,
  "Fields," added alongside (not replacing) Data Scope.
- Testing: both files parse-checked 0 AST errors, UTF-8 BOM/ASCII-only.
  Isolated test with a stub choices function matching the real shape
  confirmed the fix returns a proper 3-item array; confirmed Machine
  Type's registry entry and the new field-summary helper's output
  directly.
- Open items for Jeremy: answering the clarifying questions asked right
  after this (Manufacturer's interaction model, Exclude/Invert scope,
  same-field-twice combination logic) unblocks the remaining requested
  work.

### 2026-08-25 - Claude (Report saved correctly, but Generate CSV hung forever -- a missing -WaitWindow argument on a mandatory parameter (D-128), plus AD-lookup progress feedback)

- Files reviewed: Jeremy confirmed D-127's save fix worked, but
  generating a CSV then hung permanently on "Generating report...",
  needing a force-close.
- Root cause: `Invoke-MintReportsGenerate` (Tab.Reports.ps1) called
  `Show-MintWaitWindow` without capturing its return value, then called
  `Close-MintWaitWindow` with ZERO arguments despite `-WaitWindow` being
  `Mandatory`. Under MINT's actual launch method
  (`powershell.exe -File ...`, a real console session behind the WinForms
  UI), a missing mandatory parameter prompts interactively at that
  console and blocks forever -- exactly "stuck, won't close." Grepped
  every other `Close-MintWaitWindow` call site in the codebase -- all
  already correct; isolated to these two new Reports call sites.
- Files changed: Tab.Reports.ps1 -- captured `$waitWindow`, both
  `Close-MintWaitWindow` calls now pass `-WaitWindow $waitWindow`. Also
  added progress feedback for the AD-lookup pass (which the app already
  warns can be slow) using this codebase's own established
  `-ProgressCallback`/`CurrentWaitWindow`-state-slot pattern from Batch
  Extract (D-067/D-068): `Get-MintReportActiveRows`/`Get-MintReportDataRows`
  (Core.Reports.ps1) gained an optional `-ProgressCallback`, invoked once
  per file during AD lookups; `$script:MintReportsState` gained
  `CurrentWaitWindow`; the generate handler now shows live "(AD lookup N
  of Total: SERIAL)" text.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only. Extracted
  the real wait-window functions from the entry script via AST (without
  running full startup) and ran the exact corrected call sequence --
  `Close-MintWaitWindow -WaitWindow $waitWindow` completed in 177ms, no
  hang, versus the old zero-argument call hanging/throwing depending on
  host interactivity.
- Open items for Jeremy: the `-ProgressCallback` addition hasn't been
  exercised against a real live AD lookup yet -- confirm Generate CSV
  completes normally, and that AD-Department reports show live progress
  text during the lookup.

### 2026-08-25 - Claude (D-126's fix wasn't the full story -- the real root cause was a $script: write silently lost inside .GetNewClosure() (D-127))

- Files reviewed: after D-126's AcceptButton + Cancel-feedback fix,
  Jeremy confirmed he clicked the actual "OK" button with the mouse and
  still got "Report not saved (cancelled)." A real mouse click on OK
  cannot be explained by a missing Enter-key wiring, so this needed a
  different, deeper explanation.
- Investigation: added temporary trace logging directly inside the OK
  button's own Click handler. The trace's own first line -- computing a
  log file path from `$script:DataRoot` -- itself crashed with
  "Cannot bind argument to parameter 'Path' because it is null,"
  revealing that `$script:DataRoot` was resolving to `$null` from
  inside that specific handler. Reproduced this in complete isolation,
  outside MINT entirely: a `$script:`-scoped variable set BEFORE a
  `.GetNewClosure()`'d scriptblock reads back empty from inside it, AND
  -- the critical direction -- a WRITE to a script-scoped variable from
  inside a `.GetNewClosure()`'d block is silently lost; the outer scope
  never sees it. A plain (non-`.GetNewClosure()`'d) scriptblock does not
  have this problem in either direction. This is a real,
  previously-undocumented PowerShell 5.1 behavior, not specific to MINT.
- This is the actual, complete explanation for the whole "report not
  saved" mystery, not just D-126's narrower AcceptButton finding:
  `Show-MintReportEditorDialog` sets `$script:MintReportEditorResult = $null`
  before showing the dialog, and its OK button's
  `.GetNewClosure()`'d Click handler writes the real, successfully-built
  result to that same-named variable -- but the write lands in the
  closure's own private snapshot, never the true script scope.
  `DialogResult` genuinely becomes OK and the dialog genuinely closes
  (matching every symptom Jeremy reported -- no crash, no validation
  warning, "closes as if successful"), but the function's own
  `return $script:MintReportEditorResult`, reading from the TRUE outer
  scope after `ShowDialog()` returns, only ever sees the original
  `$null`.
- Files changed: Tab.Reports.ps1 -- `$okButton.Add_Click({...})` is now
  a plain scriptblock, `.GetNewClosure()` removed entirely.
  `.GetNewClosure()` was never actually needed here: it exists to
  detach a scriptblock from a scope that will change/be destroyed
  before the scriptblock runs (the classic per-iteration loop-variable
  case), and neither applies to a modal dialog's own button handler,
  since the enclosing function's stack frame stays alive for the entire
  time `ShowDialog()` blocks. Checked this dialog's other five
  `.GetNewClosure()`'d handlers -- none write to any `$script:`
  variable, so none are exposed to this bug; left unchanged. Grepped
  the whole `Modules\` tree for the same "`$script:...Result = $null`
  before a dialog" pattern this depends on -- exactly one match, the one
  just fixed; not lurking anywhere else in the codebase. All trace
  instrumentation and its shared trace file were removed. Promoted the
  underlying PowerShell lesson to the shared `AGENTS.md` durable-lessons
  list.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only. Verified
  via a clean, minimal, twice-run isolated reproduction matching this
  handler's own real shape -- not a guess -- but not yet re-verified
  through an actual live click in MINT, since UI automation has proven
  unreliable throughout this whole project.
- Open items for Jeremy: please retest one more time -- build a report,
  click OK -- and confirm it actually appears in the saved-reports grid
  this time. This should be the true end of the D-121 through D-127
  crash chain.

### 2026-08-25 - Claude (A saved report silently vanished after D-125 -- traced live to a missing AcceptButton and zero feedback on Cancel, not a code defect (D-126))

- Files reviewed: Jeremy reported building a report successfully
  (including a filter), the editor dialog closing normally, but the
  report never appearing in the saved-reports grid -- no crash, no
  message, nothing.
- Ruled out, each confirmed directly rather than assumed: called the
  real `Save-MintReportDefinition` and `Update-MintReportsGrid` myself
  against the real shared path and a real grid -- both worked correctly.
  Checked the real `reports.json` on the shared drive directly --
  genuinely empty. Checked MINT's real debug log for today -- no error
  logged for Reports at all. Asked Jeremy two direct questions (did the
  "Saved report" status message appear -- no; does it persist across a
  relaunch -- no), which placed the failure before
  `Save-MintReportDefinition` is ever reached, inside
  `Show-MintReportEditorDialog` itself.
- Added temporary trace logging to see exactly how far execution got.
  First attempt wrote to `C:\mint_trace.log` and itself crashed Jeremy's
  live session with an Access Denied error -- a real mistake on my part:
  every earlier successful use of that exact path this session ran
  through processes I launched myself under an elevated shell, never
  through Jeremy's own correctly-non-elevated live session, so the gap
  was never exposed until now. Reverted immediately and rebuilt the
  trace against the shared `debug\` folder instead (the same folder
  `Write-MintLog` already writes to successfully), with
  `-ErrorAction SilentlyContinue` on every line so tracing itself could
  not crash the handler again.
- The corrected trace, from Jeremy's real retest, showed
  `Show-MintReportEditorDialog` returning `$null` -- the dialog closed
  with a DialogResult other than OK, so the button handler correctly did
  nothing, exactly as designed for a Cancel. Root cause: `$okButton.DialogResult`
  is deliberately `None` (so its Click handler can validate before
  closing) and `$dialog.CancelButton` is correctly wired, but
  `$dialog.AcceptButton` was never set at all -- unlike this dialog's own
  sibling, `Show-MintReportFieldFilterDialog`, which sets both. Without
  AcceptButton, Enter does nothing useful; meanwhile Escape (or the
  window's own [X], which WinForms also routes through CancelButton)
  instantly and silently discards the whole report, and every caller's
  `if ($null -ne $result)` gate does nothing at all on Cancel by design.
  Jeremy most likely hit Escape or the window's [X] believing his work
  was already committed -- a reasonable assumption given the dialog gave
  no cue either way. Not the same class of bug as D-122/D-123/D-124 (all
  StrictMode/scoping/syntax defects) -- this one is a real, different
  root cause.
- Files changed: Tab.Reports.ps1 -- `$dialog.AcceptButton = $okButton`
  added to `Show-MintReportEditorDialog`; the New/Edit/Duplicate button
  handlers each gained an explicit `else` branch setting
  `Set-MintReportsStatus -Message 'Report not saved (cancelled).'` when
  the dialog returns null, so Cancel is now always visibly
  distinguishable from a successful save. All trace instrumentation and
  the diagnostic `C:\mint_trace.log`/shared-`debug\` trace file were
  fully removed.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only. This is a
  real, live-diagnosed root cause backed by Jeremy's own trace output,
  not a guess -- but not yet re-verified live now that the fix is in.
- Open items for Jeremy: please retest -- build a report, click OK (or
  press Enter) rather than Escape/the window's [X], confirm it appears
  in the grid, and confirm deliberately cancelling now shows "Report not
  saved (cancelled)." Worth a separate check for the same AcceptButton
  gap in any other modal dialog in this codebase, not done here.

### 2026-08-25 - Claude (D-123's own retest crashed a third time -- bare-parens "if" as a command argument (D-124) -- then a proactive full review of the same dialog found and fixed a fourth issue before Jeremy hit it (D-125))

- Files reviewed: Jeremy retested D-123's fix and hit a third distinct
  error in the same dialog: `CommandNotFoundException: The term 'if' is
  not recognized as the name of a cmdlet...`.
- Root cause, confirmed by an exact isolated two-line reproduction of the
  identical error text: `Show-MintReportFieldFilterDialog`
  (Tab.Reports.ps1:176) computed one argument as
  `-Rows (if (...) {...} else {...})` -- bare parentheses wrapping an
  if/else used directly as a command argument. This parses with 0 AST
  errors (why it passed every prior parse-check) but throws at RUNTIME:
  a parenthesized command argument is parsed as a pipeline, not an
  expression, and `if` is a statement keyword there, not a value. This
  exact pitfall was already known to this codebase -- Tab.Warranty.ps1's
  `Add-MintWarrantyResultRow` carries a detailed comment documenting the
  identical failure from an earlier live bug -- but that lesson had only
  ever been recorded as a local code comment, not promoted anywhere
  shared, so it was not surfaced when Tab.Reports.ps1 was written fresh.
- Fix: replaced the bare-parens argument with a preceding plain if/else
  statement assigning to `$rowsForChoices`, then passed that variable.
  Also promoted the underlying lesson to the shared `AGENTS.md`
  "Durable Lessons Already Learned" section (used across all Hall County
  MIS AI work, not just MINT) so a third project does not repeat it.
- Given this was the THIRD consecutive real crash found on successive
  retests of this exact dialog, did a full line-by-line review of the
  whole function instead of waiting for a fourth live report -- and
  found one: all five filter-type panels (Categorical, Text, Date,
  Duration, Boolean) are built unconditionally every time the dialog
  opens, so all nine of their `$FieldEntry.FilterSettings.<Property>`
  reads ran regardless of the field's actual Kind, while
  `New-MintReportDefaultFilterSettings` only ever populated the
  properties for ONE Kind. Device Age (Duration) would have hit this on
  the very next line after the `if`-expression fix -- `SelectedValues`
  does not exist on a Duration-kind FilterSettings object. This is the
  same class of defect as D-123, just in a different object.
- Fixed both ends: `New-MintReportDefaultFilterSettings` now declares
  all seven possible FilterSettings properties on every object it
  returns; the dialog's nine reads now go through `Get-MintPropertyValue`
  (string properties) or an explicit `PSObject.Properties['SelectedValues']`
  check (the one array property) instead of assuming a shape -- needed
  independently of the constructor fix, since a saved report reloaded
  from `reports.json` is only ever as new as whatever was on disk when
  it was saved. Confirmed the two other functions reading FilterSettings
  (`Test-MintReportRowMatchesFilter`, `Get-MintReportFilterSummaryText`)
  already branch on Kind first and were already safe -- no change needed
  there.
- Testing: both files parse-checked 0 AST errors, UTF-8 BOM/ASCII-only.
  Verified the `if`-fix by reproducing Jeremy's exact error text in
  isolation first, then confirming the fixed statement runs clean for
  both branches. Verified the FilterSettings fix by running the REAL
  `Show-MintReportFieldFilterDialog` function (not a simulation) against
  a deliberately narrow, pre-fix-shaped settings object for Device Age
  specifically, via a background STA runspace with a timeout -- the
  dialog reached `ShowDialog()` (still blocking after 3 seconds) rather
  than crashing during panel construction. Did not extend that exact
  live-invocation test to the other four filter kinds, since a blocked
  native `ShowDialog()` cannot be cleanly cancelled from PowerShell and
  the fix is structurally identical across all nine read sites (already
  confirmed via direct code review).
- Open items for Jeremy: this is now four fixes on the same dialog in
  one review cycle (D-122 through D-125). Please do one more full pass
  through the Report Editor and field filter dialogs -- actually saving
  a report and generating a CSV end to end -- before considering this
  feature stable.

### 2026-08-25 - Claude (D-122's own retest crashed differently -- fixed an inconsistent field-registry object shape under StrictMode (D-123))

- Files reviewed: Jeremy retested D-122's fix -- the `Get-CurrentScope`
  crash was gone -- but clicking "Edit Filter" on a Device Age field
  threw a new error: `PropertyNotFoundException: The property
  'ChoiceSource' cannot be found on this object.`
- Root cause, confirmed by reading the exact failing line: the same
  class of defect as D-118 (StrictMode blocks access to a property never
  declared on a given object), this time in the field registry rather
  than a row object. `$script:MintReportFieldRegistry` (Core.Reports.ps1)
  built each field as a separate object literal, and only Categorical
  fields included the `ChoiceSource`/`FixedChoices` keys -- Device Age
  (Duration kind) genuinely had no such property at all.
  `Show-MintReportFieldFilterDialog` (Tab.Reports.ps1:176) reads
  `$FieldMetadata.ChoiceSource` unconditionally, for every field kind,
  before ever checking Kind, so opening the filter editor for any
  non-Categorical field threw immediately -- `Get-MintReportFieldChoices`
  itself already had the correct guard and was never actually reached.
- Files changed: `Core.Reports.ps1` -- all 21 field-registry entries now
  declare both `ChoiceSource` (`$null` when unused) and `FixedChoices`
  (`@()` when unused) explicitly, matching D-118's own already-learned
  lesson that this feature's row-shape constructor already applied to
  itself but the field registry did not.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only. Verified
  directly against the exact statement that crashed
  (`$metadata.ChoiceSource -eq 'InData'` under
  `Set-StrictMode -Version Latest`) for all 21 registry fields
  individually -- all pass now, all would have thrown before the fix.
  Extended regression pass (scope filtering, Fixed/Duration/Text choice
  retrieval, Duration filter match/non-match on Device Age) -- 11/11
  passed.
- Open items for Jeremy: please retest the same Edit Filter flow again,
  this time actually setting a Device Age filter and confirming
  Save/Generate work end to end -- verification so far covers the crash
  itself, not the full filter-configuration UI flow past that point.

### 2026-08-25 - Claude (New Reports tab -- custom, saved, filterable CSV reports (D-121); fixed a real crash on first live use, a nested-function scoping bug in the Report Editor dialog (D-122))

- Files reviewed: Jeremy asked, as a concept discussion, for a 7th tab
  where he could build a custom CSV report from any available
  field/column, with each field independently toggleable as a
  value-only column or an active filter, and filter controls matched
  to the field's nature (pick-a-value for Device Type, newer/older-than
  for Device Age). Four clarifying questions were asked and answered
  before planning: data scope (Active/Decommissioned/Both) is chosen
  per report; AD Department/Location is included as a field with an
  explicit slow-lookup warning (it is the only live, uncached,
  per-device query any report can use); reports are saved and reusable,
  not one-shot; text-field filtering is substring "contains". Two
  research passes confirmed integration points (tab registration
  pattern, the Tab-module dependency rule, existing dialog/grid
  patterns, CSV writer conventions) before a plan was written and
  approved.
- Files/assets changed: `Core.Reports.ps1` (new -- field registry, data
  gathering, filter evaluation for all five filter kinds, CSV export,
  JSON persistence), `Tab.Reports.ps1` (new -- the tab plus the Report
  Editor and per-field Filter dialogs), `Core.Domain.ps1`
  (0.11.0->0.12.0, new `New-MintReportDefinition` /
  `New-MintReportFieldEntry`), `Core.Inventory.ps1` (0.10.0->0.11.0,
  `Read-MintDecommissionMasterRows` promoted here from Tab.Search.ps1
  per the project's Tab-module dependency rule), `Tab.Search.ps1`
  (0.21.1->0.21.2, its now-duplicate copy of that function removed, its
  three call sites left untouched), and the Development entry script
  (0.25.0->0.26.0 -- new tab registration, module load entry, and
  `ReportDefinitionsFile` path). Report definitions persist to a new
  `variables\reports.json` -- the first JSON file on the shared
  filestore in this codebase (every existing `variables\*.csv` is flat
  CSV), a deliberate departure since a report's nested field/filter
  structure does not fit a flat CSV without an awkward flattening
  scheme.
- Real bug found by Jeremy on his own first live test, not caught by
  isolated testing beforehand: "Tried doing a report, used the device
  age scope and got this error: ... CommandNotFoundException: The term
  'Get-CurrentScope' is not recognized..." thrown from inside a button
  click handler in the Report Editor dialog. Root cause, confirmed
  against the actual stack trace: `Get-CurrentScope` was a nested
  PowerShell `function` declared inside `Show-MintReportEditorDialog`,
  which `.Add_Click({...}.GetNewClosure())` handlers cannot resolve --
  closures capture variable bindings, not sibling function
  declarations. The very same function already had a working sibling
  pattern for this exact situation (`$refreshFieldsGrid` /
  `$refreshAddFieldChoices`, both plain scriptblock variables) that
  simply was not applied consistently to this one helper. Fixed by
  converting to `$getCurrentScope = { ... }` and updating all five call
  sites to `& $getCurrentScope`.
- A second, unrelated defect was caught by this project's own isolated
  testing before it could reach Jeremy: `Get-MintSavedReportDefinitions`'s
  `return ,@()` idiom (correct for a plain `$var = command` capture)
  produced wrong results when a caller wrapped the bare call in
  `@(command)` or piped it into `Where-Object` -- the same P25-class
  pipeline-unwrap pitfall this codebase's pitfalls reference already
  documents elsewhere. Fixed in `Save-MintReportDefinition` /
  `Remove-MintReportDefinition` and in two Tab.Reports.ps1 handlers by
  always assigning to a variable first.
- Testing: parse-checked 0 AST errors, UTF-8 BOM/ASCII-only confirmed on
  every new/touched file. 32-assertion isolated functional test suite
  for Core.Reports.ps1 (all five filter kinds, multi-filter AND, CSV
  export round-trip including the injection guard, JSON persistence
  round-trip) passed in full, re-run again after the pipeline-unwrap
  fix. Live-app check confirmed the Reports tab renders correctly in the
  7th position with correct Dark Mode theming. Live re-verification of
  the `Get-CurrentScope` fix specifically was attempted via UI
  automation but not completed -- this app's dark-themed, owner-drawn
  WinForms controls expose themselves to UI Automation as generic `Pane`
  elements rather than `Button`/`RadioButton`, defeating every
  automation approach tried; reliable automation would need low-level
  cross-process Win32 message marshalling disproportionate to this
  verification. Confidence in the fix is high on code grounds (mirrors
  the already-proven-working sibling pattern in the same function) but
  it has not been confirmed via an actual retest of Jeremy's exact
  steps.
- Open items for Jeremy: please retest your exact repro (New Report,
  change data scope, add a Device Age field) to confirm the crash is
  gone. Beyond that, the plan's full verification checklist is still
  open -- one report per scope with a filtered and a display-only field
  each, generate/open each CSV, confirm the AD warning only fires when
  that field is actually used, Edit/Duplicate/Delete a saved report,
  relaunch and confirm persistence, and the full regression battery
  (already known non-functional due to the pre-existing, unrelated
  "Navagation"-path staleness in most scratchpad fixtures -- flagged in
  D-117's own work log, not fixed here).

### 2026-08-25 - Claude (Device Age moved to last column (D-119); fixed the missing window/taskbar icon and replaced it with the new logo (D-120))

- Files reviewed: Jeremy asked for Device Age to be the last column on
  all four grids it was added to (D-117) -- confirmed after a relaunch
  that Search and Manage specifically needed a real app restart to pick
  it up, since DataGridView columns are only built once at tab
  initialization, not on every row refresh. Separately, Jeremy reported
  the running app's taskbar/title-bar icon showed the generic WinForms
  default and provided a new icon file (`Mint Logo\MINT_Logo.ico`).
- Root cause for the icon (confirmed via a direct file check, not
  assumed): the existing icon-loading code (D-059) was already correct
  and untouched -- `MINT.ico` simply did not exist at all in the
  Development project root, so its own `Test-Path` guard silently
  skipped setting the icon with no error. Production's separate
  `MINT.ico` was untouched and unaffected; Development's copy
  specifically had gone missing, most likely during an earlier file
  reorganization this session.
- Files/assets changed: `Tab.Warranty.ps1` (0.14.0->0.14.1),
  `Tab.Extract.ps1` (0.16.0->0.16.1), `Tab.Search.ps1`
  (0.21.0->0.21.1), `Tab.Upload.ps1` (0.6.0->0.6.1) -- column order plus
  the matching positional `Rows.Add` calls in each. New
  `MINT.ico` at the Development project root (copied from
  `Mint Logo\MINT_Logo.ico`, a genuine multi-resolution icon,
  confirmed by inspecting its actual embedded image directory) -- no
  code change needed for the icon fix at all.
- Testing: confirmed no code in any of the four grid files references a
  column by numeric index (only ever by name), so the reorder could not
  have silently broken anything else. Confirmed the placed icon file
  loads via the exact same `System.Drawing.Icon` call the app itself
  uses.
- Open items for Jeremy: Production's own separate `MINT.ico` was left
  untouched, per the standing rule that Production runs a deliberately
  frozen snapshot (ADR-015) -- say if you want the new logo there too.

### 2026-08-25 - Claude (Fixed a real crash on first use of D-117 -- StrictMode blocks adding a new property to an already-built object -- D-118)

- Files reviewed: Jeremy reported, on a fresh launch, only one device
  (9NS24J4) appeared in Search and Manage, and clicking the search box
  threw a live .NET exception dialog (`SetValueInvocationException` on
  `DeviceAgeSortMonths`, "property cannot be found on this object").
- Root cause, confirmed live: `Set-StrictMode -Version Latest` throws
  when a NEW property is added to an already-constructed
  `[PSCustomObject]` via plain dot-assignment -- only setting an
  EXISTING property works. All four of D-117's `.DeviceAgeSortMonths =`
  write sites hit this, since none of their backing objects' constructors
  declared that property upfront. Explains both symptoms as one cause:
  the grid populate loop adds each row to the grid before the doomed
  property-set line, so the first iteration's row lands then the
  unhandled exception kills the loop (one device shown); the same code
  re-runs on every search-box keystroke with no surrounding try/catch
  (the visible crash dialog).
- Went looking for a second, separate construction site for each of the
  four object shapes (the exact class of gap `New-MintWarrantyRecord`'s
  own docstring already flagged once for a different field) and found
  one real instance: `ConvertTo-MintWarrantyCacheRecord`
  (Core.WarrantyCache.ps1) builds a cache-hit warranty record
  separately from `New-MintWarrantyRecord`'s live-lookup shape -- a
  cache hit is the common case for Warranty Lookup, so this needed the
  same fix or the bug would have persisted for most real use.
- Files changed: `Core.Domain.ps1` (0.10.0->0.11.0, all four
  constructors) and `Core.WarrantyCache.ps1` (0.3.0->0.4.0, the
  cache-hit constructor) -- each now declares
  `DeviceAgeSortMonths = -1` upfront. No Tab file changes needed.
- Testing: reproduced the exact reported exception in isolation first,
  then verified the fix against all five real construction paths with a
  direct functional test (construct via the real function, perform the
  exact assignment each Tab file performs) -- all five passed after the
  fix, all five had thrown before it. Both files parse with 0 AST
  errors and are UTF-8 BOM/ASCII-only.
- Open items for Jeremy: a real live-app smoke test is still worth doing
  on your own machine -- fresh launch, confirm the full device list
  populates, click the search box, sort the Device Age column on all
  four tabs -- since this exact bug was invisible to every check
  performed before D-117 was first reported done.

### 2026-08-24 - Claude (Group Tag "clear to blank" + new sortable Device Age column -- D-117)

- Files reviewed: Jeremy reported no way to explicitly clear a device's
  Group Tag to blank in either inline editing or Batch Edit ("regardless
  of how it is displayed"), and separately asked for a new "Device Age"
  column (warranty start -> today) on Search and Manage, Upload Builder,
  Batch Extract, and Warranty Lookup, formatted `<N> Year/Years, N
  Month/Months` with correct singular/plural and sortable by real age.
  Went through Plan Mode given the multi-file scope (8 files) and real
  design decisions (sentinel wording, sort mechanism, data sourcing per
  tab); plan approved before implementation.
- Root cause confirmed via direct code reads, not assumed: inline
  editing already had a blank dropdown entry that rendered as an
  indistinguishable blank row; Batch Edit had a genuine, deliberate
  guard treating a blank Group Tag exactly the same as Cancel, so
  batch-clearing was actually impossible, not just hard to find.
- Files changed: `Core.Inventory.ps1` (0.9.0->0.10.0), `Core.Dialogs.ps1`
  (0.7.0->0.8.0), `Core.Domain.ps1` (0.9.0->0.10.0, new
  `Get-MintDeviceAge`), `Tab.Search.ps1` (0.20.0->0.21.0),
  `Tab.Upload.ps1` (0.5.0->0.6.0), `Tab.Extract.ps1` (0.15.0->0.16.0),
  `Tab.Warranty.ps1` (0.13.0->0.14.0), and the Development entry script
  (0.24.0->0.25.0, new `Register-MintGridNumericSortColumn` --
  `$script:ToolVersion` kept in sync). Both parts landed as one combined
  Decision D-117.
- Testing: `Get-MintDeviceAge` verified against 15 cases covering every
  spec'd edge (exactly 1 year, 0 years N months, double-digit years with
  no leading zero, null/unparseable input, string-shaped cached dates, a
  future-dated defensive case) -- all passed. All 8 touched files parse
  with 0 AST errors and are UTF-8 BOM/ASCII-only; Group Tag sentinel
  translation re-verified by reading the final committed code in all
  three edit surfaces. The scratchpad regression battery was re-run and
  found to be currently non-functional: most of its ~77 fixtures still
  hardcode the pre-D-109 "Navagation"-spelled path and fail before
  reaching real code -- a pre-existing staleness unrelated to this
  change, confirmed via the actual error text rather than assumed away,
  and not fixed here since it's a separate, unrequested undertaking.
- Open items for Jeremy: the regression battery itself needs a bulk
  path fix before it can verify anything again -- flagged, not actioned.

### 2026-08-24 - Claude (Abandoned the 180-day backup/report retention concept entirely -- D-110)

- Files reviewed: Jeremy: "Remove any mention of the 180 day file
  cleanup from all documentation. We will abandon that concept
  entirely." Supersedes D-026 (2026-07-21) -- a full abandonment, not
  the "designed but unenforced" framing Documents 00/05/06 used as of
  D-108.
- Files changed: Documentation `00`, `04`, `05`, `06` (180-day/
  retention.csv mentions removed or rewritten to state current reality
  without narrating the abandoned idea); both entry scripts (development
  0.23.0->0.24.0, production 1.21.0->1.22.0) and `Core.Csv.ps1`
  (0.7.0->0.8.0) -- removed the never-used
  `$script:Paths.RetentionPolicyFile` definition and its doc-comment
  mentions. This handoff and `AI-Project-Plan.md` (new Decision D-110).
- D-026's own historical entry in the Decisions Log was left untouched,
  per the same convention already used for D-098/D-105/D-106/D-109 --
  history isn't edited, a new entry supersedes it.
- Deliberately kept, as a genuinely separate question: Document 05's
  point that the event log has no retention policy either (never had a
  180-day figure to begin with), and that Georgia Archives schedule
  alignment remains unconfirmed for any of MINT's files -- both restated
  without reference to the abandoned figure.
- Testing: none needed -- the only code change (removing a dead,
  never-read variable) has no behavioral effect; verified via parse/
  encoding checks only, matching the "no need to test" pattern already
  set for this kind of cleanup.
- Open items for Jeremy: none new. If Georgia Archives records
  management later requires a minimum retention period for any of these
  files, that needs a fresh design, not a revival of the abandoned
  180-day figure.

### 2026-08-24 - Claude (Finished the "Navagation" typo cleanup: renamed every real remaining folder, local and filestore -- D-109)

- Files reviewed: Jeremy asked for a full audit of every script for the
  "Navagation" typo. Investigation found the remaining instances were
  all either real, still-typo'd folder names or historically-accurate
  prose -- neither safely fixed by blind find-and-replace. Jeremy then
  reframed directly: "I want to make it so that if I delete any folders
  or files sitting in any path that uses 'Navagation'... it will have
  no adverse effects on the software," confirmed a concrete plan with
  "Yes, clean it up entirely."
- Files/folders changed: both entry scripts (`MIS Inventory Navigation
  Tool Development\...` v0.22.1->0.23.0, `...Production\...`
  v1.20.0->1.21.0) -- `DistributionRoot` path and stale comments fixed
  in both; Production's `$script:DataRoot` fixed from a genuinely broken
  reference (see below). Three real folders renamed to the correct
  spelling: the local Development folder, the local Production folder,
  and the AI Knowledgebase's own project-handoff folder (this file's own
  new location). Two filestore locations cleaned up: the old pre-D-098
  DataRoot deleted entirely (confirmed test-artifact-only), the
  (empty) `DistributionRoot` target renamed. The canonical
  `project_mint_phase2_graph.md` memory file also updated -- it cited
  the pre-rename local path as current.
- Confirmed before touching anything, not assumed: the real application
  has zero hardcoded dependency on its own folder name (both entry
  scripts and both launchers self-locate dynamically), and
  `DistributionRoot` -- the only remaining code reference to a
  "Navagation" path -- is defined but never actually read anywhere.
  This is what made the folder renames genuinely low-risk, not just
  assumed so.
- A real, separate bug found along the way: Production's
  `$script:DataRoot` was still hardcoded to the OLD pre-D-098
  "Navagation" UNC path -- meaning it had been silently broken (pointing
  at a folder that, after this same cleanup's step 1, no longer exists
  at all) for the whole time Production has sat paused. Fixed as a
  targeted patch; Production's own pre-existing Version/ToolVersion
  drift was deliberately left alone as a separate, out-of-scope issue.
- Deliberately not touched, matching the same principle D-098 already
  established: `AI-Project-Plan.md`'s historical Decisions Log, and the
  historical CHANGE LOG entries inside both entry scripts narrating the
  original typo and its fix -- correcting the word inside those would
  make them nonsensical. Jeremy's own personal backup zip, not
  referenced by any code, was also left alone.
- Testing: per Jeremy's explicit instruction, none -- this entry's own
  verification is parse-check/encoding/path-existence only, not a live
  application run. A full case-insensitive search afterward, across
  local folders, the AI Knowledgebase, and the whole filestore Intune
  tree, confirms zero remaining "Navagation" matches outside the two
  preserved historical-record classes and Jeremy's own zip file.
- Open items for Jeremy: any existing desktop/taskbar shortcut pointing
  at either old local folder name needs to be recreated -- a folder
  rename does not update a shortcut's stored absolute target path.

### 2026-08-24 - Claude (Completed the full 10-document formal documentation set -- D-108)

- Files reviewed: Jeremy: "Let's work on the documentation... treat the
  program as a finished product, with only hints to the idea that it
  will expand later on to a grander aspect involving graph... apply
  only to sections that have been developed specifically with this
  later growth in mind. Ask any questions you need." Then, once the
  first batch was delivered: "Go ahead, write everything that needs to
  be written." He also asked what "COM" meant for docx editing
  (referenced back in D-101).
- Files changed: all 10 documents in `Documentation\` (development
  workspace only): `00` through `10`. Four refreshed (Index, Product
  Overview, Architecture Decision Records, Changelog), six written from
  scratch (Requirements Spec, User Guide, Architecture and Data Design,
  Security/Privacy/Records Plan, Deployment/Ops Runbook, Developer and
  Maintainer Guide, Verification/Release Plan -- that's seven; Index was
  the fourth refreshed one). This handoff, `AI-Project-Plan.md` (new
  Decision D-108), and a new project memory
  (`project_mint_documentation_stakes.md`, both the AI Knowledgebase
  canonical file and the auto-memory stub).
- The real story here: Jeremy revealed, when asked what was driving
  priority, that this documentation set is going in front of the
  Director, technician manager, Cybersecurity, Systems Administration,
  and his own superior -- an unsanctioned pet project, at an
  organization with "a slight history when it comes to in-house
  products going astray." He also wants confidence MINT survives his
  own departure. That reframed the whole effort: precision and honesty
  about real limitations (not polish) is what builds trust with this
  audience, and Document 07 became the direct answer to his succession
  concern rather than a checkbox.
- Confirmed live rather than assumed: Word is already installed on this
  machine and COM automation works cleanly -- nothing for Jeremy to set
  up for a future `.docx` snapshot. Confirmed via AskUserQuestion:
  Markdown-only for this pass (matching D-101's existing convention),
  and new ADR entries for D-102/D-105/D-106.
- A real gap found while writing Document 05, not previously surfaced in
  this documentation set: `retention.csv`'s 180-day backup/report
  retention policy (D-026) was confirmed via direct code search to have
  no actual enforcement -- the file doesn't exist and nothing prunes old
  backups/reports. Stated plainly rather than implied-handled. Also did
  not invent a specific Georgia Archives retention schedule citation
  Hall County records management hasn't actually confirmed.
- Testing: none needed -- documentation only, no code changed.
- Open items for Jeremy: Document 06 flags one unresolved question
  (whether the file share has its own snapshot/versioning capability) --
  needs Systems Administration input, not guessed at. Generate a
  `.docx` snapshot on request before any document goes in front of a
  formal reviewer.

### 2026-08-24 - Claude (Removed the planned "web search fallback" step from the Model Identification Pipeline -- D-106)

- Files reviewed: Jeremy: "Let's remove the ability to do a websearch for
  unknown warranty info... if it isn't one of the pre-defined
  manufacturers... it will just remain unknown (staying in the staging
  folder) and will need to manually be sorted until the manufacturer can
  be added." This referenced a step named in D-002 (2026-07-17) and
  Section 7's pipeline design -- opening the browser to a vendor page so
  Jeremy could manually look up an unmatched serial.
- Files changed: `AI-Project-Plan.md` only (Section 5 item 5, Section 7,
  new Decision D-106). No code files touched.
- Investigated before changing anything: confirmed via direct code
  reading that this step was never actually built --
  `Resolve-MintWarrantyLookup` has always been exactly Lenovo -> Getac ->
  an honest "Vendor Not Configured" result, and Tab.Extract.ps1/
  Tab.ImportFiles.ps1 already route an unmatched result straight to
  Staging for manual sorting -- exactly the end state Jeremy described.
  So this was a documentation correction, not a code change: the design
  described a feature already superseded in practice.
- Testing: none needed -- no code changed. Confirmed via repo-wide search
  that no browser-launch/manual-assist pattern exists anywhere tied to
  warranty lookups.
- Open items for Jeremy: his own phrasing ("provided we are able to get
  all of the desired ones working") signals more manufacturer providers
  (most likely Dell/HP once D-036/D-042 API access comes through) are
  expected later -- separate, not-yet-scheduled work.

### 2026-08-24 - Claude (First script-security audit: real CSV/formula-injection and path-traversal gaps found and fixed -- D-105)

- Files reviewed: Jeremy needs to brief his cybersecurity team on this
  project and asked me to first explain the event-log hash-chaining
  briefly, then separately: "I want to check and make sure that any
  area that allows users to input text sanitizes the incoming text to
  prevent any possible code injection or other security concerns." This
  is "script security," the pre-deployment gap named alongside logging
  since D-102 and still unstarted through D-104. Reported findings;
  Jeremy said "Go ahead" to fix.
- Files changed: `Core.Csv.ps1` 0.6.0->0.7.0, `Core.Domain.ps1`
  0.8.0->0.9.0, `Core.Inventory.ps1` 0.8.0->0.9.0, `Core.FileOps.ps1`
  0.2.0->0.3.0, `Tab.Search.ps1` 0.19.0->0.20.0. This handoff and
  `AI-Project-Plan.md` (new Decision D-105).
- Swept every text-input surface: WinForms free-typed fields, CSV
  read/write, AD queries, vendor HTTP lookups, anything reaching a
  shell command/file path/written file. Already correct (verified):
  LDAP filter escaping (strips `* ( ) \` already), vendor HTTP request
  encoding (URL-encoded or JSON/form-serialized throughout, never
  hand-built strings), no shell/command-injection surface at all (no
  `Invoke-Expression`/`cmd.exe`, only two narrow `Start-Process` calls),
  no registry-write surface.
- Two real gaps found and fixed: (1) **CSV/formula injection** --
  `ConvertTo-MintCsvFieldValue` (the one shared writer every CSV in the
  app goes through) never guarded against a leading `= + - @`, and Group
  Tag/Assigned User are both free-typed fields technicians edit directly
  in files routinely opened in Excel (confirmed live during the D-104
  audit -- `depts.csv` was open in Excel at the time). Fixed with the
  standard OWASP leading-apostrophe mitigation. (2) **Path traversal** --
  `Get-MintModelDestinationFolder` joined operator-typed Device
  Type/Model text into a path with zero character filtering; a Model
  Name of `..\..\..\Windows\System32` would walk outside
  `HashLibraryRoot`. Also found `Invoke-MintRestoreSingleRow` reading its
  serial straight from the Decommission Master List CSV, the one
  serial-to-filename path that skipped `New-MintSerialNumber`. Fixed
  with a new shared `ConvertTo-MintSafePathSegment`, wired in at both
  points plus `New-MintSerialNumber` itself (covers every other
  `<serial>.csv` construction in the app) and
  `Invoke-MintRelocateHashFileSingleFile` (defense in depth, doesn't
  just trust its own parameter's name).
- Testing: new `mint_security_audit_test.ps1`, including a real
  end-to-end proof that a crafted Model Name cannot escape
  `HashLibraryRoot` and that a formula-leading value round-trips through
  a real `Write-MintVariableCsv`/`Read-MintVariableCsv` write+read with
  the guard actually on disk. A first battery run caught a real
  self-introduced regression -- `New-MintSerialNumber`'s new
  sanitization step turned a genuinely blank serial into "INVALID"
  instead of staying blank, breaking Batch Extract's "Skipped - Blank
  Serial" classification and others -- fixed (blank stays blank; the
  guard only applies to a non-empty value), two regression-guard
  assertions added (test now 22/22), both affected suites reconfirmed
  clean individually. Final full battery re-run: 77 suites, PASS=56
  FAIL=4 ERROR=1, every remaining entry matching the already-known D-104
  baseline exactly -- zero regressions from the actual security fixes.
- Open items for Jeremy: this was a text-input-injection-focused audit
  specifically, not a full security review (file/share permissions,
  credential handling, and the logging tamper-evidence limits from
  D-102 are separate, already-documented topics). The fix is
  forward-looking only -- it does not retroactively rename anything
  already on the real filestore.

### 2026-08-21 - Claude (Full regression-battery audit: fixed all 13 pre-existing FAIL/ERROR suites, plus a real production version-sync bug -- D-104)

- Files reviewed: Jeremy asked what the battery's 5 FAIL suites were,
  then "Fix any issues you may find, do a full audit if need be."
- Files changed: 13 scratchpad test fixtures (`mint_csv_test.ps1`,
  `mint_grouptags_fix_test.ps1`, `mint_grouptags_realfile_test.ps1`,
  `mint_inventory_test.ps1`, `mint_production_function_test.ps1`,
  `mint_warranty_tab_test.ps1`, `mint_warranty_lookup_test.ps1`,
  `mint_extract_fullapp_smoke_test.ps1`, `mint_theme_fullapp_smoke_test.ps1`,
  `mint_realapp_icon_test.ps1`, `mint_inline_edit_test.ps1`,
  `mint_feedback_fixes_test.ps1`, `mint_scope_test.ps1`). `MIS Inventory
  Navigation Tool.ps1` 0.22.0 -> 0.22.1 (real production fix, see below).
  This handoff and `AI-Project-Plan.md` (new Decision D-104).
- Root causes found, not just papered over: stale pre-D-098 `Navagation`
  typo paths still hardcoded in several fixtures (the old folder is
  still on the share but empty); incomplete `$script:Paths` hashtables
  missing keys the real code has grown to need; missing stubs for
  entry-script-local helper functions (`Enable-MintGridDesignStandard`,
  `Set-MintGridColumnWidthsToContent`, `Get-MintPluralizedNoun`,
  `Core.FileOps.ps1`) that predate the D-081 stub-backfill pass; stale
  button label text (`Browse...` -> `Browse`, dropped the ellipsis);
  stale tab-navigation Ctrl+Tab count (Import Files' insertion shifted
  Extract from index 2 to 3); `-WindowStyle Hidden` silently breaking
  SendKeys keystroke delivery to a launched process (switched to
  `Normal`); a too-short 20s window-find timeout on the app's slower
  current startup (bumped to 120s, matching its siblings).
- Two genuinely deeper findings, not simple staleness: (1) a documented
  P35-class pipeline bug (`return ,$array` piped directly into
  `Select-Object` collapsing the whole array) was silently producing an
  empty "sample of 5 files" table in `mint_inventory_test.ps1` -- fixed
  per the pitfall's own documented remedy (assign to a variable first);
  (2) `mint_realapp_icon_test.ps1`'s exact-pixel icon comparison was
  investigated and found to be comparing two fundamentally
  non-comparable data sources (a live `WM_GETICON` handle vs. a
  file-loaded bitmap, differing by hue even on solidly-opaque pixels) --
  demoted to diagnostic output with the investigation left in place;
  the suite's separate "differs from an unmodified default" assertion is
  what actually proves the custom icon is applied, and still gates.
- A real production bug found along the way (not part of the original
  FAIL/ERROR list): `$script:ToolVersion` (the window title) still read
  0.21.0 while `.NOTES Version:` already said 0.22.0 -- the same
  Version-Sync class of bug fixed once before under D-100, drifted again
  during the D-102 edit. Fixed, bumped to 0.22.1.
- `mint_inline_edit_test.ps1` deserves its own note: one assertion
  (typing a brand-new free-typed Group Tag) had a genuine, confirmed
  WinForms DataGridView internal edit-commit race, traced all the way
  down via direct diagnostics (IsCurrentCellDirty/EditingControlValueChanged/
  GetEditingControlFormattedValue all correct on every run, pass or
  fail) to WinForms' own `EndEdit()` commit step, not the product code.
  An extended message-pump warmup plus a bounded retry loop brought it
  from consistently failing to passing ~7 of 8 runs -- documented in
  place as a mitigated, not eliminated, test-harness limitation.
- Mid-task: Jeremy mentioned he was manually babysitting/re-focusing
  windows for the real-app smoke tests this pass launched, which
  explained a lot of the flakiness being chased. Acknowledged and
  confirmed proceeding was still wanted ("do what is necessary to get
  the best results... so you could better understand why there may have
  been hangups").
- Testing: every touched suite re-run individually and confirmed
  passing (exact counts in D-104, `AI-Project-Plan.md`). A final
  undisturbed full battery run afterward showed 4 more suites as
  FAIL/ERROR purely from the runner's own crude text-matching (a caught
  lock-error message, a date string, the substring "exception" inside
  "no exception") and 3 real-app-window smoke tests failing in that long
  unattended run but re-confirmed 100% clean immediately after when run
  individually -- consistent with Jeremy's own explanation that these
  need active babysitting, not a regression. A 14th suite outside the
  original scope, `mint_extract_followups_test.ps1`, turned up the same
  missing-dot-source pattern as everything else here; fixed, 34/34 clean.
- Open items for Jeremy: script security (the other pre-deployment gap)
  remains fully unstarted.

### 2026-08-21 - Claude (Event logging wired into every real technician action across all six tabs -- D-103)

- Files reviewed: Jeremy's instruction, verbatim: "Alright, lets implement
  it across all event types" -- the tab-by-tab instrumentation D-102
  deliberately deferred.
- Files changed: `Tab.Search.ps1` (0.18.0->0.19.0, 5 call sites:
  Decommission, Restore, InlineEdit, BatchEdit, Delete), `Tab.ImportFiles.ps1`
  (0.3.0->0.4.0, StageImport/Import/BatchEdit/EditModelFolders/CreateFolders),
  `Tab.Upload.ps1` (0.4.0->0.5.0, GenerateUpload), `Tab.Extract.ps1`
  (0.14.0->0.15.0, Extract/BatchEdit/EditModelFolders/CreateFolders),
  `Tab.Validate.ps1` (0.0.0->0.1.0, ValidateFix/MoveToModelFolder --
  discovered Move to Model Folder actually lives here, not in
  Tab.Search.ps1), `Tab.Warranty.ps1` (0.12.0->0.13.0, WarrantyLookup).
  This handoff and `AI-Project-Plan.md` (new Decision D-103).
- Design decision carried over from reading the code first: Extract and
  Validate log AFTER their post-write verification/flag-update step
  (`Test-MintExtractWriteVerification`, `Update-MintValidateResultFlags`),
  never inside the write function itself, since both can retroactively
  flip a row to Failed -- avoids ever recording a false success.
- Test-fixture fallout: 46 scratchpad files dot-source an instrumented
  tab without `Core.EventLog.ps1` present; 42 fixed by a regex bulk-
  insert script, 3 by hand, 1 confirmed already excluded from the
  battery.
- Testing: `mint_decommission_test.ps1` rewritten to call the real
  `Invoke-MintDecommissionSingleFile`/`Invoke-MintRestoreSingleRow`
  functions (it previously hand-replicated their logic and so never
  actually exercised the new event-log calls), using the D-102 identity-
  override test hook to route into a synthetic `MINTSELFTEST-EventLog`
  folder, with new assertions confirming real event content (Area/
  Action/Identity/Result) and a passing `Test-MintEventLogIntegrity`
  check on the resulting chain. Found and fixed two unrelated pre-
  existing fixture bugs blocking this: three scratchpad files still
  used the pre-D-098 typo'd `DataRoot` path, and this test's synthetic
  file used a stale `Desktops` (plural) folder name against the real
  library's `Desktop` (singular). Full battery re-run after fixture
  repairs: 76 suites, PASS=49 FAIL=5 ERROR=8 NO-ASSERTIONS=14 -- FAIL/
  ERROR sets match the pre-existing known baseline exactly, zero new
  regressions (full detail in D-103, `AI-Project-Plan.md`).
- Open items for Jeremy: script security (the other pre-deployment gap
  he named alongside logging) has not been started at all.

### 2026-08-21 - Claude (Logging split into error/diagnostic + new tamper-evident event/audit-trail systems -- D-102)

- Files reviewed: Jeremy renamed the local project folder to
  `MIS Inventory Navagation Tool Development` (still exclusively where
  work happens for now, Production is further from done than expected)
  and asked for tamper-resistant per-technician action logging, unsure
  whether signing/git were relevant. Mid-task, explicitly corrected the
  approach: error logging and event logging must be completely separate
  systems, not one conflated mechanism.
- Files changed: new `Modules\Core.EventLog.ps1` (ver. 0.1.0).
  `MIS Inventory Navigation Tool.ps1` (v0.21.0 -> v0.22.0): `LogRoot`
  relocated to `debug` (via `error logs` briefly), new `EventLogRoot`
  added under the vacated `logs` name, new module wired into load order.
  This handoff and `AI-Project-Plan.md` (new Decision D-102). Bulk-
  updated all 217 scratchpad test/diagnostic scripts to the renamed
  folder path (broken by the rename itself, unrelated to this feature).
- Design: `Write-MintEventLog` writes one hash-chained CSV per running
  Windows identity per day, under a bare-account-name subfolder that
  deliberately does NOT collapse `jhankinson`/`jhankinsonad` together --
  confirmed via direct code reading that `Remove-MintAdAccountSuffix`
  (Core.Domain.ps1, used by Upload Builder's own Personal-account
  folder) was exactly the generalization pattern Jeremy was warning
  against replicating here. Each entry's `EntryHash` chains the
  previous entry's hash with its own fields (SHA-256);
  `Test-MintEventLogIntegrity` independently re-verifies a file and
  reports the first tampered row. Documented honestly as tamper-
  evident, not tamper-proof, given MINT runs under the operator's own
  identity -- explained the real limits and the NTFS-permission /
  out-of-band-collector path to real hardening if ever needed.
  `Write-MintLog` (error logging) got zero code changes, only its root
  path moved.
- Clarified for Jeremy: code signing protects the LOGGING CODE from
  tampering (different concern, needs a cert Hall County doesn't have
  yet); git protects SOURCE CODE history, not runtime log data; neither
  is required for this decision's tamper-evidence improvement.
- Testing: new `mint_eventlog_test.ps1`, 28/28 passing -- includes a
  real tamper-and-detect round-trip (edit a row directly, confirm
  `Test-MintEventLogIntegrity` catches it and reports the exact broken
  row number) and confirms the two logging systems are genuinely
  independent. Full battery re-run given the folder rename affected
  every existing fixture.
- Open items for Jeremy: wiring `Write-MintEventLog` into real tab
  actions (Import, Decommission, Batch Edit, Extract, Validate fixes,
  warranty lookups, etc.) is a separate, larger follow-up not started
  yet, pending his scope/priority call; script security (the other
  pre-deployment gap he named) is not started at all yet.

### 2026-08-20 - Claude (Formal documentation initiative started -- D-101)

- Files reviewed: Jeremy relayed a 10-document outline he developed with
  Codex (Product Overview, Requirements, User Guide, Architecture,
  Security/Privacy/Records, Deployment Runbook, Developer Guide,
  Verification/Release Plan, ADRs, Changelog), grounded in real ISO/IEC/
  IEEE/NIST/Georgia Archives standards but explicitly tailored down to
  MINT's actual scale. Asked me to pick the working file format and
  begin building the set.
- Files created: new
  `Inventory Management Tools Production\Documentation\` folder with
  `00-Documentation-Index.md`, `01-Product-Overview-and-Scope.md`,
  `09-Architecture-Decision-Records.md`, `10-Changelog.md`. This handoff
  and `AI-Project-Plan.md` (new Decision D-101).
- Format decision: Markdown for every living document -- confirmed
  `.docx` cannot be read/written with normal tools at all; a polished
  `.docx` snapshot gets generated on request when a document needs
  formal review, Markdown stays the maintained source.
- Sequencing (confirmed with Jeremy via AskUserQuestion): phased, not
  all 10 at once. Started with the two documents ready to write now with
  real confidence (Overview) plus two curated distillations of this
  existing Decisions Log (ADRs -- 14-entry architecturally-significant
  subset in MADR format; Changelog -- Keep a Changelog style, grouped by
  era, grounded in the real D-001 through D-100 headers). Deferred the
  other 6 until their underlying decisions (permission model, retention
  policy, formal release process) actually settle.
- Findings along the way: the Production folder now exists but runs an
  older snapshot than development (predates D-097-D-100, so a real
  promotion step is still pending); a stale `Project Scope Outline.docx`
  from day one of the project (2026-07-17, "no implementation code
  exists yet") was found in the same folder and flagged as superseded
  rather than left to be mistaken for current.
- Open items for Jeremy: decide when/how to promote the production
  folder's pending fixes; the 6 deferred documents have no fixed
  timeline by design (write "as needed" per his own preference).

### 2026-08-17 - Claude (Retroactive alpha/beta version renumbering across every module -- D-100)

- Files reviewed: Jeremy announced a two-folder split
  (`Inventory Management Tools\` for future Graph/v2.0 work, a new
  `Inventory Management Tools Production\` for what ships soon) and
  asked for a retroactive version scheme: every module's major version
  forced to 0 (alpha/beta), with a future "1.0.0" as the real release.
  Clarified 3 mechanics via AskUserQuestion before touching anything
  (not every module was at major 1 -- Tab.Extract.ps1 was at 2.14.0,
  Tab.Validate.ps1 at 5.0.0): force major to 0 regardless of current
  value (not decrement-by-1); renumber every historical CHANGE LOG
  citation, not just the current line; also update
  `AI-Project-Plan.md`'s own Decision-log version citations (unlike the
  D-098 Navagation entries, which stayed as historical narrative).
- Files changed: all 19 real `.ps1` files (18 `Modules\*.ps1` + entry
  script) -- 201 version citations renumbered. `AI-Project-Plan.md` --
  270 of 298 `vX.Y.Z` citations renumbered (28 left untouched: genuine
  references to three separate external legacy tools MINT replaced or
  ported from, not MINT's own history). This handoff and
  `AI-Project-Plan.md` (new Decision D-100).
- Found along the way: `$script:ToolVersion` (the variable that actually
  populates the main window's title bar) had drifted from `.NOTES
  Version:` -- stuck at 1.1.0 through 20+ real point releases. Fixed to
  match (now 0.21.0); nothing keeps these two in sync automatically, so
  future bumps need both updated by hand.
- NOT done yet: the "1.0.0 today" (production)/"p1.5.0" (non-production)
  final bump Jeremy also described -- the new Production folder does not
  exist yet at the path given (confirmed live), so there's no way to
  know yet which folder's snapshot becomes which baseline. Flagged to
  Jeremy rather than guessed.
- Testing: full backup of all 19 `.ps1` files + `AI-Project-Plan.md`
  taken before any write. Every `.ps1` file re-parses 0 AST errors,
  UTF-8 BOM/ASCII re-verified. `AI-Project-Plan.md` confirmed
  byte-identical in size/line count to its pre-transform backup (only
  single-digit substitutions, no structural change). Full 75-suite
  regression battery re-run: 47 PASS/6 FAIL/8 ERROR/14 NO-ASSERTIONS,
  every FAIL/ERROR triaged. Exactly one genuine regression found -- not
  from the renumbering itself, from this round's OTHER change (D-099's
  checkbox dialog) -- `mint_extract_phase3b_button_test.ps1` still set
  the Resolution cell to a leftover string value; fixed, now 4/4. Every
  other FAIL/ERROR was already-known pre-existing/unrelated debt.
- Open items for Jeremy: confirm the Production folder now exists so the
  final "1.0.0"/"p1.5.0" bump can happen; consider a startup guardrail
  keeping `$script:ToolVersion` synced with `.NOTES Version:` so this
  kind of drift can't recur silently.

### 2026-08-17 - Claude (Resolve Duplicate Serials dialog: Overwrite moved first, checkbox, checked by default -- D-099)

- Files reviewed: Jeremy's follow-up after D-097 shipped: "let's move the
  'Resolution' column to before the Serial column, change it to
  'Overwrite', change the dropdown to a check box, and have it enabled
  by default."
- Files changed: `Modules\Core.Dialogs.ps1` (v1.6.0 -> v1.7.0); this
  handoff and `AI-Project-Plan.md` (new Decision D-099).
- Change: `Show-MintDuplicateConflictDialog` (shared by Import Files AND
  Batch Extract) -- Overwrite is now the first column, a real checkbox
  defaulting to checked, instead of a trailing Ignore/Overwrite combo
  defaulting to Ignore. Return contract unchanged (still
  'Overwrite'/'Ignore' strings), so neither caller needed changes. Added
  a CurrentCellDirtyStateChanged/CommitEdit handler for the well-known
  WinForms checkbox-column commit-timing gotcha.
- Flagged to Jeremy: this dialog is shared, so Batch Extract's own
  duplicate default also flipped from Ignore to Overwrite as a side
  effect -- not requested for that tab specifically.
- Testing: parses 0 AST errors, UTF-8 BOM/ASCII re-verified.
  `mint_importfiles_test.ps1` re-run clean (53/53, unaffected -- it
  drives the Import pass directly, not the modal). New
  `mint_duplicate_checkbox_commit_test.ps1` isolates the real grid/
  column/handler shape (5/5 passing): default-checked, column order,
  real checkbox type, handler doesn't throw.
- CORRECTION found during the D-100 battery re-run: this dialog already
  had real full-automation coverage this entry didn't know about --
  `mint_extract_phase3b_button_test.ps1` drives the real running app
  end to end (real button click, real dialog, real resolution, real OK,
  real file write). This change broke it (leftover
  `Cells['Resolution'].Value = 'Overwrite'` string from the old combo
  column, meaningless to a checkbox cell) -- fixed to `= $true`, now
  passing 4/4 with real proof the checkbox and its commit-timing fix
  work end to end against the actual app, not just an isolation test.
  See D-100's own entry for the full battery triage.

### 2026-08-14 - Claude (MINT data-root UNC folder renamed "Navagation" -> "Navigation" -- D-098)

- Files reviewed: Jeremy renamed the real filestore folder mid-session
  and asked for a full sweep: "Make sure to go through all of the
  modules and scripts to make sure this typo is corrected."
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.20.0 -> v1.21.0,
  `$script:DataRoot` updated); this handoff and `AI-Project-Plan.md`
  (new Decision D-098).
- Findings: verified live that the old path no longer exists and the new
  one does; a whole-codebase search found exactly one functional-code
  reference to the old spelling (`$script:DataRoot` itself) -- no
  `Modules\*.ps1` file hardcodes it. Deliberately did NOT change the
  nested `DistributionRoot` subfolder reference (confirmed still spelled
  "Navagation" on disk, not renamed) or historical Decision-log entries
  that correctly describe the old spelling as true at the time.
- Testing: parses with 0 AST errors, UTF-8 BOM/ASCII re-verified.
  Covered by the same full 74-suite battery re-run as D-097 below.
- Open items for Jeremy: `AI-Project-Plan.md`'s own prose (path examples
  and current-state descriptions outside the numbered Decision entries)
  still has many "Navagation" references, intentionally not bulk-edited
  -- flagged rather than swept, since distinguishing current-state text
  from historical narrative needs a human call, and "modules and
  scripts" doesn't literally cover documentation prose.

### 2026-08-14 - Claude (Real bug: "Overwrite" in the duplicate-conflict dialog never worked; Import button moved to end of row; new Refresh button -- D-097)

- Files reviewed: Jeremy's report, "If I place a hash in staging that is
  a duplicate of another file (when in fact it could be an updated
  version), the program does not seem to be importing the hash file from
  staging to the proper location, even when it has all the correct
  location info," naming a real production file
  (`Staging\RL403A0346.csv`, newer than the existing GETAC A140 copy).
  Plus two UI requests: move the Import button to the end of its row,
  add a general Refresh button.
- Files changed: `Modules\Core.FileOps.ps1` (v1.1.0 -> v1.2.0),
  `Modules\Tab.ImportFiles.ps1` (v1.2.0 -> v1.3.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-097).
- Root cause: confirmed live via a real, read-only diagnostic against
  the actual production Staging file and Hash Library (no writes) --
  the row classifies correctly and a real conflict IS detected, so the
  duplicate dialog does appear. The bug: `Invoke-MintRelocateHashFileSingleFile`
  (`Core.FileOps.ps1`) had no way to honor an "Overwrite" choice at all
  -- "a file already exists at the target" was unconditionally the
  "leave it in place, report Success=true" branch, regardless of what
  the operator picked in the dialog. Fixed with new
  `-OverwriteExisting`/`-BackupHandle` parameters (backs up the existing
  file into the caller's archive, then deletes it, before the normal
  copy-verify-delete runs); both default off, so Validate and Organize's
  own call site (which never offers Overwrite) is unaffected. Also
  fixed an adjacent reporting bug: the run-report Result column said
  "Success" for the old silently-did-nothing outcome.
- UI follow-ups: Import button moved to the end of its row; both button
  rows now use `Set-MintControlRowLayout` (D-092) instead of hand-tuned
  offsets; new Refresh button re-scans Staging on demand via the
  existing `Invoke-MintImportFilesScan`, with mutual button-disable
  against Stage Imports to prevent an overlapping scan (the wait window
  is non-modal, pumped via `DoEvents`).
- Testing: both files parse with 0 AST errors, UTF-8 BOM/ASCII
  re-verified. `mint_importfiles_test.ps1` expanded 45 -> 53 assertions
  (all passing), new coverage built directly around the real RL403A0346
  shape: Overwrite genuinely replaces the library file's on-disk bytes
  and removes the Staging copy; a sibling Ignore choice in the same
  Import pass leaves both files untouched; the pre-overwrite file lands
  in the backup archive first. Full 74-suite regression battery re-run
  (shared `Core.FileOps.ps1` surface): 47 PASS / 5 FAIL / 8 ERROR / 14
  NO-ASSERTIONS, every FAIL/ERROR individually triaged and confirmed
  pre-existing/unrelated (stale dot-source lists from older promotions,
  a stale sample-file path, a stale test expectation, an unrelated
  Search-tab assertion, real-app window-title timing flakiness, and 2
  more instances of the already-known battery-runner false-PASS blind
  spot from D-096) -- full breakdown in `AI-Project-Plan.md`'s D-097
  entry.
- Open items for Jeremy: the test-fixture debt found while triaging
  (listed in D-097's Evidence) is pre-existing and out of scope for this
  round -- worth a cleanup pass before the next real change in Warranty
  tab, Search's GroupTag editing, or the older Extract/production-
  function suites.

### 2026-08-07 - Claude (Model dropdown never populated from models.csv, in Import Files AND Batch Extract -- new pitfall P35 -- D-096)

- Files reviewed: Jeremy's report, "The issue with the Model select on
  Import Files is that the dropdowns are not populating with entries
  from the CSV."
- Files changed: `Modules\Tab.ImportFiles.ps1` (v1.1.0 -> v1.2.0),
  `Modules\Tab.Extract.ps1` (v2.13.0 -> v2.14.0), `Modules\Core.Dialogs.ps1`
  (v1.5.0 -> v1.6.0); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-096, full detail there, including the new pitfall
  P35).
- Root cause: a genuine, previously-undiscovered PowerShell 5.1 pitfall
  (P35) -- `Get-MintModelMap` returns via `return ,$array` (the
  established P29 fix for array-collapse), but piping that function
  call DIRECTLY into `Select-Object -ExpandProperty ModelName` throws
  "Property cannot be found" (confirmed live under real PS 5.1, even
  through an intermediate `Where-Object`), silently swallowed by the
  surrounding `try/catch`. Fixed by assigning to a variable first, then
  piping the variable. Same bug found and fixed in 3 other places
  sharing the identical pattern: Batch Extract's OWN Model dropdown
  (apparently broken the same way all along, masked by its "already in
  use" fallback), and two dialogs in `Core.Dialogs.ps1` (Batch Edit's
  Model list, Move to Model Folder's existing-models list). Also fixed
  a second, separate gap specific to Import Files: Manufacturer/Model
  were only ever populated reactively after a scan, unlike Device Type
  -- both now populate synchronously at tab construction.
- Testing: all 3 files parse with 0 AST errors, UTF-8 BOM/ASCII
  re-verified. `mint_importfiles_test.ps1` expanded to 45 assertions
  (all passing). Found and fixed a stale existing fixture
  (`mint_extract_manufacturer_model_dropdown_test.ps1`, missing the
  D-094 promotion's new dot-sources) while re-verifying the Extract
  fix -- now 16/16, including a new assertion for the Batch Edit
  dialog's own Model list.
- Open items for Jeremy: this fix was scoped to the specific call sites
  found via a targeted grep, not an exhaustive codebase-wide audit for
  every possible instance of this pitfall class.

### 2026-08-07 - Claude (Import Files real-use follow-up: warranty-db write timing corrected, Ready-to-Import status, tab-strip white-gap investigated and deferred -- D-095)

- Files reviewed: Jeremy's real-use report on D-094 (verbatim in
  `AI-Project-Plan.md`'s D-095 entry) -- confirmed 3 behaviors already
  worked as expected (Model dropdown from `models.csv`, Import only
  processing completed rows, Import auto-correcting formatting), flagged
  1 real display gap (Status never promoted to "Ready [to] Import"), and
  explicitly corrected D-094's own guessed reading of the warranty-db
  write timing (staging must be read-only; the write belongs to Import).
  Separately reported the Dark Mode tab-strip white background is back,
  visible only when the window is wider than the tab strip, with
  explicit permission to skip the fix if it turns out difficult/unstable.
- Files changed: `Modules\Tab.ImportFiles.ps1` (v1.0.0 -> v1.1.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-095,
  full detail there). `Modules\Core.Theme.ps1` has NO net change (a fix
  was written, empirically disproved via live testing, then reverted).
- Implementation: new `Resolve-MintImportFileWarrantyLookupReadOnly`
  (checks the cache, falls back to the RAW `Resolve-MintWarrantyLookup`
  live call on a miss, never persists) replaces the shared
  `Resolve-MintWarrantyLookupCached` during classification specifically
  -- that shared function's auto-persist-on-find behavior is correct for
  every other caller in this codebase, just not this tab's own staging
  step. The actual write moved to a new `Save-MintImportFileWarrantyEntry`,
  called only from `Invoke-MintImportFilesImportPass` on a genuinely
  relocated row -- check-then-write-if-missing against a freshly-read
  cache (not an unconditional upsert), specifically so a cache-hit row's
  real vendor `Source` is never overwritten with the cache-hit's own
  display-only "Warranty Database" relabeling. New
  `Update-MintImportFilesReadyPromotion` promotes a `NeedsReview` row to
  `ReadyToImport` (grid Status cell updates live) once all 3 fields are
  manually completed and a real destination resolves.
- Tab-strip investigation: reproduced Jeremy's report live via two
  independent real-render techniques (`DrawToBitmap` pixel sampling and
  a genuine on-screen `PrintWindow` capture with `PW_RENDERFULLCONTENT`)
  -- widening the window past the tab strip's total width leaves the gap
  past the last tab showing native gray/white, not the themed strip
  color. Wrote a targeted fix (`Graphics.ResetClip()` before the
  existing strip-fill), then used the SAME two live techniques to test
  it -- both still showed native gray/white after the fix, disproving
  it. Reverted rather than ship an unverified change to the exact
  OwnerDraw tab-theming code a previous round (D-090) already had to
  patch once for a real regression (tabs disappearing). Left as a
  documented, accepted limitation per Jeremy's own explicit
  instruction -- likely the same class of native Win32 chrome this
  codebase has already found genuinely unfixable twice before
  (scrollbar chrome, ComboBox dropdown arrows, both D-089).
- Testing: `Modules\Tab.ImportFiles.ps1` parses with 0 AST errors, UTF-8
  BOM and ASCII-only re-verified. `mint_importfiles_test.ps1` expanded
  30 -> 43 assertions (all passing), with new coverage specifically
  proving: a `NeedsReview` row's Status only flips to `ReadyToImport`
  once all 3 fields are genuinely complete; a live-lookup-found serial
  is NOT in the warranty db immediately after classification but IS
  immediately after Import, with its real vendor Source intact; a
  second import of an already-cached serial does not corrupt that
  Source. `mint_tab_order_test.ps1` re-run clean (10/10, unaffected).
  `Core.Theme.ps1` confirmed byte-identical to its pre-D-095 state (zero
  `ResetClip` matches, clean re-parse) after the revert. No other files
  touched this round, so the full 72-suite battery was not re-run in
  full -- only the two suites covering the actually-changed code.
- Open items for Jeremy: the tab-strip white-gap limitation is now
  accepted and documented, not fixed -- worth folding into the same
  "known limitations" list as the scrollbar/dropdown-arrow chrome
  (D-089) the next time that area comes up, rather than staying a
  standalone note.

### 2026-08-06 - Claude (new "Import Files" tab replaces the placeholder "Model Lookup" tab; tab reorder -- D-094)

- Files reviewed: Jeremy's full 9-point Import Files specification and
  tab-reorder request (verbatim in `AI-Project-Plan.md`'s D-094 entry),
  preceded by a discussion-only exchange about warranty-database timing
  and architectural redundancy between Validate and Organize/Search and
  Manage. Went through `EnterPlanMode`: three `Explore`-agent research
  passes over `Tab.Extract.ps1`/`Tab.Validate.ps1`/`Core.FileOps.ps1`/
  `Core.Inventory.ps1`/`Core.Dialogs.ps1`/`Core.Domain.ps1`/
  `Core.WarrantyCache.ps1`, a `Plan`-agent design pass, three
  `AskUserQuestion` decisions confirmed with Jeremy (Validate's own
  `'Staging'` scan option retired in favor of this tab; a multi-hash
  file is rejected at Stage Imports time, before it ever reaches
  Staging; "duplicate" means already-in-the-real-library, not
  within-the-current-batch), before any code was written.
- Files changed: new `Modules\Tab.ImportFiles.ps1` v1.0.0 (replaces the
  deleted placeholder `Modules\Tab.ModelLookup.ps1`); `Modules\Core.FileOps.ps1`
  v1.0.0 -> v1.1.0 (new `Invoke-MintRelocateHashFileSingleFile`,
  promoted out of Validate and Organize's own fix tool); `Modules\Core.Inventory.ps1`
  v1.7.0 -> v1.8.0 (new `New-MintMissingModelFolders`, promoted from
  Batch Extract); `Modules\Core.Dialogs.ps1` v1.4.0 -> v1.5.0
  (`Show-MintExtractBatchEditDialog` gains `-DeviceTypeChoices`;
  `Show-MintExtractDuplicateDialog`/`Get-MintExtractSuggestedModelRows`
  promoted here as `Show-MintDuplicateConflictDialog`/
  `Get-MintSuggestedModelRows`); `Modules\Core.Domain.ps1` v1.7.0 ->
  v1.8.0 (new `New-MintImportFileRowPlan`); `Modules\Tab.Extract.ps1`
  v2.12.0 -> v2.13.0 (call sites updated for the four promotions above,
  zero behavior change); `Modules\Tab.Validate.ps1` v4.5.0 -> v5.0.0
  (the `'Staging'` Scan Library option removed; its own unified fix tool
  refactored to call the newly-promoted relocation primitive);
  `Modules\Core.VendorLookup.ps1` (doc-comment only, `Tab.ModelLookup.ps1`
  reference updated to `Tab.ImportFiles.ps1`); `MIS Inventory Navigation
  Tool.ps1` v1.19.0 -> v1.20.0 (new `Show-MintMultiFileOpenDialog`;
  `$tabDefinitions` reordered to Search and Manage, Import Files, Upload
  Builder, Batch Extract, Validate and Organize, Warranty Lookup;
  `$script:TabModuleFiles` entry renamed); this handoff and the matching
  `AI-Project-Plan.md` (new Decision D-094, full detail there).
- Implementation: Import Files stages files into the SAME shared
  `$script:Paths.StagingRoot` Batch Extract's `ReviewStaging` rows and
  Validate and Organize's fix tool already use (D-082) -- copy-verify-
  delete from the operator's chosen source, never a bare `File.Move`,
  since sources are arbitrary off-share locations. A file is read via
  `Read-MintCanonicalHashFile` BEFORE the move; more than one data row
  rejects it outright (must use Batch Extract instead), matching
  Jeremy's confirmed decision. Classification
  (`Resolve-MintImportFileRowPlan`) mirrors Batch Extract's own
  per-row pipeline: `Unfixable` (unreadable/multi-row/bad hash/blank
  serial) is non-editable and left alone; a live warranty match with a
  real models.csv entry is `ReadyToImport`; anything else is
  `NeedsReview`, completed via the same editable Device Type/
  Manufacturer/Model grid columns, Batch Edit, and Edit Model Folders
  Batch Extract already has (all reused/promoted, not reimplemented).
  "Duplicate" is checked against the real Hash Library
  (`Find-MintInventoryFilesBySerial`), not just within the current
  Staging batch. The "Import" action reuses Validate and Organize's own
  unified fix-and-relocate mechanics (now the promoted
  `Invoke-MintRelocateHashFileSingleFile`) rather than a parallel
  implementation, with the same duplicate-conflict dialog Batch Extract
  uses. A successfully imported file is simply gone from Staging by the
  time the mandatory post-Import re-scan runs, so "only files still
  stuck show, otherwise the grid is empty" needed no special tracking at
  all -- the grid always reflects ground truth, matching Validate and
  Organize's own philosophy. Item 8's warranty-db write-then-reverify
  language is read literally as describing classification time (`When
  the files are first staged...`), implemented as a defensive
  write-verification (confirm the cache genuinely contains the entry
  after a live `Found=true` lookup, re-save if it somehow does not) --
  flagged in the plan as the one genuinely ambiguous reading in Jeremy's
  own spec, worth a quick confirmation.
- A real, separate latent bug was found and fixed along the way, not
  just a refactor: `Invoke-MintValidateUnifiedFixSingleFile`'s old
  inline relocation logic resolved its target folder from
  `$File.DeviceTypeFolder`, which `Get-MintStagingFilesInternal`
  hardcodes to the literal string `'Staging'` for every Staging-sourced
  file -- had Validate's (now-removed) `'Staging'` scan option ever been
  combined with a Fix pass, it would have computed a bogus destination
  path INSIDE Staging rather than relocating the file out of it. Never
  reproduced live (Jeremy had not combined those two actions), but a
  real defect regardless, closed by the promotion since the new
  `Invoke-MintRelocateHashFileSingleFile` takes the target folder as an
  explicit parameter instead of reading it off the file.
- A second real bug was found via the new fixture's own testing (not a
  pre-existing one -- introduced during this same round, caught before
  shipping): `Invoke-MintImportFilesScan` originally assumed a wait
  window was already showing (reading `$script:MintImportFilesState.CurrentWaitWindow`
  inside its own progress callback), which is true for its two
  button-triggered callers but NOT for the deferred startup Timer
  (mirroring Warranty tab's own D-086 pattern) that also calls it with
  no wait window active at all -- would have thrown a parameter-binding
  exception the first time Staging had any file to classify at real app
  startup. Fixed by making the scan function self-contained (shows and
  manages its own wait window, matching `Invoke-MintValidateScan`'s own
  established pattern) rather than assuming a caller-managed one.
- Testing: all 9 touched/new files parse with 0 AST errors, UTF-8 BOM
  and ASCII-only verified (the new file initially saved without a BOM
  via the file-write tool, caught and fixed before any other check).
  New `mint_importfiles_test.ps1` (30/30): tab construction, all four
  classification outcomes (ReadyToImport/NeedsReview/Unfixable via
  multi-row/Unfixable via blank hash), the item-8 write-verify function
  (no-op when already present, real write when genuinely missing),
  against-library duplicate detection, the promoted relocation
  primitive specifically proving the latent-bug fix (a Staging-sourced
  file relocates to its real target folder, never a bogus path inside
  Staging), a full Import pass including backup-archive creation, and
  the post-Import re-scan showing only a genuinely-stuck file. New
  `mint_tab_order_test.ps1` (10/10): extracts the REAL `New-MintMainForm`
  from the entry script's own AST (same technique as several existing
  fixtures) and confirms the real `TabControl.TabPages` collection
  matches Jeremy's requested order exactly. Found and fixed 5 of
  Claude's own now-stale fixtures while running the full battery:
  `mint_extract_phase3b_button_test.ps1` (missing the two new
  `Core.Dialogs.ps1`/`Core.FileOps.ps1` dot-sources now needed by
  promoted functions), `mint_d082_features_test.ps1` and
  `mint_validate_devicetype_dropdown_realstartup_test.ps1` (both
  asserted the now-intentionally-removed `'Staging'` Scope dropdown
  option), and `mint_realstartup_gridwidth_test.ps1`/
  `mint_theme_mainform_test.ps1`/`mint_scope_test.ps1` (referenced the
  deleted `Tab.ModelLookup.ps1`/`Initialize-ModelLookupTab` by name) --
  all confirmed passing again after their own fixes, individually
  re-verified standalone. Full regression battery re-run in progress at
  handoff time (~70 of 72+ suites); every failure/error checked so far
  is either one of the five stale fixtures above (now fixed) or a
  pre-existing, unrelated environmental issue (real UNC share
  `\\hallcounty\filestore\...` not reachable from this dev session,
  confirmed via `mint_csv_test.ps1`'s own error text) -- final full-battery
  numbers to be confirmed once the run completes.
- Open items for Jeremy: (1) confirm the item-8 warranty-db-write
  timing reading (classification/staging time, not Import time) matches
  intent -- flagged as the one genuinely ambiguous piece of the spec;
  (2) has not yet been exercised against the real production Hash
  Library/Staging folder on Jeremy's own machine -- the new tests prove
  the mechanics work correctly end-to-end against real sandboxed WinForms
  controls and real file I/O, but not the full lived experience.

### 2026-08-06 - Claude (small follow-up polish round after D-092: ellipsis cleanup, startup width, Warranty overlap/grid, header wrap -- D-093)

- Files reviewed: Jeremy's 6-item follow-up message (verbatim in
  `AI-Project-Plan.md`'s D-093 entry) after seeing D-092 live -- a
  named list of buttons with a trailing "..." that shouldn't have one,
  Warranty's 3 shorter buttons should match its longest one's width,
  the app's startup width should fit all 6 tabs with no scroll arrows,
  Warranty's Refresh button overlapping the vendor cards below it, a
  grid header wrapping multi-word text onto 2 lines, and Warranty's own
  grid header font not matching the rest of the app.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.18.0 ->
  v1.19.0), `Modules\Tab.Warranty.ps1` (v1.11.0 -> v1.12.0),
  `Modules\Tab.Search.ps1` (v1.17.0 -> v1.18.0), `Modules\Tab.Extract.ps1`
  (v2.11.0 -> v2.12.0), `Modules\Tab.Upload.ps1` (v1.3.0 -> v1.4.0),
  `Modules\Tab.Validate.ps1` (v4.4.0 -> v4.5.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-093, full detail
  there).
- Implementation: item 1's button list was matched exactly against
  every real `.Text` across all 6 tabs, all 15 instances found and
  fixed; one judgment call made and flagged rather than silent --
  "Restore" (Search and Manage) shares Decommission's exact slot and
  naming convention but wasn't in Jeremy's own list, dropped its
  ellipsis too for consistency between the two. Item 2 (matching
  button widths) surfaced a real WinForms behavior: a Button left with
  `AutoSize=true` silently reverts a later direct `.Width` assignment
  back to its own `PreferredSize` -- fixed by turning `AutoSize` off
  first. Item 3 (startup width) reads the real required tab-strip
  width directly off `Set-MintTabControlHeaderSizing`'s own already-
  computed `ItemSize.Width * TabCount` -- the same number the strip
  itself draws with -- rather than a new guessed constant; widens both
  the initial size and `MinimumSize.Width` so a later manual shrink
  can't reintroduce the scroll arrows either. Item 4 (Refresh overlap)
  traced to the same "AutoSize doesn't resize until asked" pattern
  D-092 already found (P33), one layer further: the button's real
  height at the bumped font runs a few px taller than its original
  hand-tuned floor, pushing past the hardcoded card-start Y the row
  below it was still using -- fixed by deriving that Y from the header
  row's own real measured bottom edge instead. Item 5 -- "Model
  Lookup" has been a placeholder tab with no grid at all since D-002;
  the described symptom can only happen on a real grid and exactly
  matches what D-092's own investigation already screenshotted on
  Batch Extract's real results grid -- read as a naming mix-up, not
  two different bugs. Root cause, confirmed via three isolated tests
  culminating in the EXACT real construction order (a grid built
  inside a still-unparented TabPage, matching every Initialize-XxxTab):
  `ColumnHeadersDefaultCellStyle.WrapMode` defaults to `True`, letting
  a multi-word header wrap at a real app startup state (0 rows) instead
  of the column widening to fit it -- not reliably reproducible in an
  idealized isolated harness once a grid is already fully shown, only
  in the real app's own actual startup state, so fixed unconditionally
  rather than chased to one exact trigger. Item 6's own investigation
  found `Tab.Warranty.ps1`'s results grid was never wired to
  `Enable-MintGridDesignStandard` at all -- confirmed via a project-
  wide search that every other persistent grid calls it, with no
  documented reason for Warranty's own exclusion (unlike Batch
  Extract's dialog grids, whose exclusion IS documented) -- read as a
  plain oversight; wiring it in fixes the font and automatically
  inherits item 5's WrapMode fix for this grid too.
- Testing: all 6 touched files parse with 0 AST errors, UTF-8 BOM and
  ASCII-only re-verified. Every fix confirmed against the REAL running
  app: all 6 tabs show correct button text with no stray ellipsis, all
  6 tabs fit the startup window with no scroll arrows, Warranty's
  4-button column measured pixel-identical widths (155px each,
  precisely checked, not just visually close), the Refresh button no
  longer overlaps the vendor cards, Batch Extract's grid header renders
  single-line at the bigger font, and Warranty's grid header now
  matches every other grid's font size and also renders single-line.
  Full 72-suite regression battery re-run: 45 passed cleanly. Found and
  fixed one genuine own-test-fixture break (not a production bug):
  `mint_warranty_autocheck_test.ps1`/`mint_vendorcard_border_test.ps1`
  dot-source `Tab.Warranty.ps1` directly without the entry script's
  `Enable-MintGridDesignStandard`, which item 6 now calls -- both
  updated to extract that function, confirmed clean again after. Every
  other fail/error individually confirmed pre-existing or a stale
  assertion in an already-broken (SendKeys-flaky) test fixture -- full
  detail in `AI-Project-Plan.md`'s own D-093 entry.
- Open items for Jeremy: none blocking. The "Restore" ellipsis removal
  was Claude's own judgment call, not explicitly requested -- worth a
  quick confirmation it was the right call, though low-risk either way.

### 2026-08-05 - Claude (real formatting fallout from D-091's font +2, reported after the fact; two genuine PowerShell bugs found along the way -- D-092)

- Files reviewed: Jeremy's 8-item follow-up message (verbatim in
  `AI-Project-Plan.md`'s D-092 entry), reported after using the app
  live with D-091's changes -- tab/button label truncation, field
  labels running into fields, undersized Warranty vendor cards,
  vendor-status font size, a checkbox note overlapping a button, grid
  header font size, dropdown arrow chrome color, and a clearer active-
  tab indicator.
- Files changed: `Modules\Core.Theme.ps1` (v1.5.0 -> v1.6.0),
  `MIS Inventory Navigation Tool.ps1` (v1.17.0 -> v1.18.0),
  `Modules\Tab.Search.ps1` (v1.16.0 -> v1.17.0), `Modules\Tab.Validate.ps1`
  (v4.3.0 -> v4.4.0), `Modules\Tab.Warranty.ps1` (v1.10.0 -> v1.11.0),
  `Modules\Tab.Extract.ps1` (v2.10.0 -> v2.11.0), `Modules\Tab.Upload.ps1`
  (v1.2.0 -> v1.3.0); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-092, Q-15 answered, full detail there).
- Implementation: cataloged every symptom from real cross-process
  screenshots of all 6 tabs first, before any code changes. Root cause
  of the tab-label truncation was a genuine timing bug, not a sizing
  miscalculation: `Set-MintTabControlHeaderSizing` measures against
  `$TabControl.Font`, but the entry script's tab-building loop calls
  every `Initialize-XxxTab` (which is when that sizing call runs)
  BEFORE `$tabControl` is added to `$form.Controls` -- while
  unparented, ambient Font resolution falls back to the plain OS
  default instead of `$form.Font`'s real D-091-bumped value, so the tab
  boxes get sized for a smaller font than they're actually drawn with
  later. Fixed by parenting `$tabControl` immediately instead of at the
  very end of `New-MintMainForm`. The button-truncation and label-
  collision items (both reported, and confirmed to share one root
  cause: hardcoded absolute `.Location.X` positioning that silently
  breaks the moment anything ahead of it in a row grows) got a new
  reusable `Set-MintControlRowLayout` helper, applied across every
  affected row on 5 of the 6 tabs. Building it surfaced two further
  real, previously-invisible bugs, both confirmed live: (1)
  `AutoSize=true` does not resize a Button OR a Label/CheckBox
  immediately -- `.Size` silently stays at a construction-time stub
  until an actual layout pass runs, so reading `.Right`/`.Bottom` right
  after setting AutoSize (as this project's own hand-written label-
  chaining code did in several places) chains off the wrong value --
  fixed by forcing `.PreferredSize` onto `.Size` immediately; (2) that
  `.PreferredSize` measurement itself reads `.Font`, which inside a
  tab's own Initialize function is ALSO still the unparented default
  (same root cause as the tab-sizing bug) -- fixed with new
  `Get-MintBaseAppFontSize`/`Get-MintBaseAppFont` helpers that don't
  depend on any control's parenting state. Warranty's vendor cards
  needed real pixel measurement (`Not Configured` at a candidate +3pt
  size measured 132px wide) before resizing, and building that font
  surfaced a THIRD real, unrelated bug: writing the arithmetic INLINE
  inside a `New-Object Font(...)` argument list is not scalar addition
  in PowerShell -- confirmed live that `+` between two elements of a
  comma-built array literal parses as ARRAY
  CONCATENATION, silently turning a 3-argument constructor call into 4
  arguments and binding a completely different Font overload (wrong
  size, and Style landing as Bold+Italic instead of Regular from an
  unrelated integer in the wrong slot) -- fixed by always computing
  such arithmetic into its own variable first, never inline in an
  argument list. Grid header font hit the same unparented-Font issue,
  fixed the same way, applied in `Enable-MintGridDesignStandard`
  (already called by every persistent grid) rather than in
  `Set-MintControlTheme`, since the latter never runs at all for a
  session that stays in Light Mode. Dropdown arrow color got real,
  thorough empirical investigation -- three separate live tests
  (FlatStyle variants, disabling the OS visual style engine via
  SetWindowTheme, and manually painting over the arrow region, which
  the native chrome immediately repaints over) all confirmed this is a
  genuine WinForms limitation, not fixable via any accessible property
  or simple override -- same category as D-089's already-accepted
  scrollbar-chrome limitation. NOT fixed; flagged for Jeremy's own call
  on a materially larger custom-control investment. The tab-selection
  indicator directly answers Q-15 (raised after D-091): active tab now
  gets a distinct background (matches FormBackColor, "sinks into" its
  own content pane) plus a new 3px accent stripe, while inactive tabs
  keep the literal #3C3D3E Jeremy asked for in D-091's item 2.
- Testing: all 7 touched files parse with 0 AST errors, UTF-8 BOM and
  ASCII-only re-verified. Every fix confirmed against the REAL running
  app across all 6 tabs, both normal and maximized window sizes --
  tab labels render in full, every previously-truncated button now
  fits its text, field labels no longer collide with their fields,
  vendor cards show full un-clipped text in genuinely Regular (not
  Bold/Italic) style, the checkbox note wraps clear of the button
  column, grid headers are visibly bigger with a correctly-grown header
  row, and the selected tab is unambiguous on every tab. Light mode
  spot-checked unaffected. Full 70-suite regression battery re-run: 46
  passed cleanly, and all 11 remaining fails/errors individually
  confirmed pre-existing (stale test fixtures unrelated to this round,
  plus the same already-documented items from D-091's own battery) --
  two suites that had a timing-related failure in D-091's run came back
  fully clean this time.
- Open items for Jeremy: dropdown arrow chrome color (item 7) needs his
  own call on whether a custom-drawn ComboBox replacement is worth a
  separate, materially larger follow-up -- see `AI-Project-Plan.md`'s
  D-092 entry for exactly what was already ruled out.

### 2026-08-05 - Claude (12-item Dark Mode polish round; two real Add-MintThemedPanelBorder bugs found and fixed -- D-091)

- Files reviewed: Jeremy's 12-item message (verbatim in
  `AI-Project-Plan.md`'s D-091 entry) covering font size, button/tab/
  field background colors, disabled-button text contrast, the tab-strip
  background, summary-box and vendor-card border colors/thickness, and
  several text-field/dropdown color-scheme follow-ups across Search and
  Manage, Batch Extract, Upload Builder, and Warranty Lookup.
- Files changed: `Modules\Core.Theme.ps1` (v1.4.0 -> v1.5.0),
  `MIS Inventory Navigation Tool.ps1` (v1.16.0 -> v1.17.0),
  `Modules\Tab.Validate.ps1` (v4.2.0 -> v4.3.0), `Modules\Tab.Warranty.ps1`
  (v1.9.0 -> v1.10.0); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-091 and new Open Question Q-15, full detail there).
- Implementation: most of the 12 items were a straightforward palette
  rewrite (`ButtonBackColor`/`TextBoxBackColor`/both Tab*BackColor ->
  `#3C3D3E`, `TabStripBackColor` -> `#191A1B`) that the existing generic
  Button/TextBox/ComboBox theming branches already apply across every
  tab, plus a new `DisabledButtonForeColor` and a guarded
  `Button.Add_Paint` overpaint handler for disabled-button text
  (confirmed live that WinForms always paints disabled Button text via
  a fixed system color regardless of `.ForeColor`/`FlatStyle`), plus a
  `TabControl.Add_Resize -> Invalidate` hook fixing a real repaint gap
  after maximizing, plus a +2pt bump to the main form's Font relying on
  ambient inheritance. The `#626363`-at-3px border items (Validate's
  summary boxes, Warranty's vendor cards) took real investigation and
  surfaced two genuine, previously-invisible bugs in
  `Add-MintThemedPanelBorder` (D-089) itself: (1) a `.GetNewClosure()`
  scope bug -- confirmed via an isolated instrumented test that
  `.GetNewClosure()` silently detaches a scriptblock from the enclosing
  script's variable table, so a bare `$script:` read inside it comes
  back empty unconditionally, which tripped the handler's own Dark-mode
  guard every time and meant the border never drew in EITHER theme, for
  every existing caller (not just the new ones) -- fixed by storing the
  per-call color/thickness on the Panel's own `.Tag` instead of via
  closure capture, so the handler is a plain scriptblock; (2) once that
  was fixed, Warranty's cards drew correctly but Validate's boxes still
  didn't (an earlier "confirmed working" read of Validate's boxes from
  before this investigation turned out to be a false-positive pixel
  match against unrelated content) -- root-caused to Validate's
  `Dock=Fill` child Label expanding to cover the exact pixels the
  border occupies once `BorderStyle` flips to `None` in Dark (Warranty's
  cards use `Location`-positioned children and never hit this) -- fixed
  generically by giving themed-border panels `Padding` equal to their
  stored Thickness whenever the border is active, which Dock'd children
  respect and non-Dock'd children ignore. Also removed a mid-round
  workaround from `Tab.Warranty.ps1` (an extra `IconBox.Parent.Invalidate()`
  call added on a theory that live testing later disproved) once the
  real fix was found -- the real fix needed no caller-side changes.
- Testing: all 4 touched files parse with 0 AST errors, UTF-8 BOM and
  ASCII-only re-verified (only the 3 BOM bytes themselves are non-ASCII
  in each file). Both border fixes confirmed pixel-exact against the
  REAL running app (cross-process `PrintWindow` capture plus raw
  `GetPixel` sampling landing exactly on `#626363`), in both Dark
  (border drawn, both Validate's summary boxes and every one of
  Warranty's 5 vendor cards) and Light (native single-pixel border
  unchanged, `Padding` correctly resets to 0, no double border). The
  tab-strip resize fix and disabled-button contrast fix were
  re-confirmed together with everything else via a real maximize of the
  live app pre-seeded to Dark Mode. Full 67-suite regression battery
  re-run: 44 passed cleanly, 1 already-known pre-existing failure
  (`mint_inline_edit_test.ps1`'s GroupTag issue, flagged before this
  round), 7 errored on stale/unrelated test-fixture gaps (none touching
  a file this round changed), `mint_theme_core_test.ps1` (the suite
  covering this round's actual theming machinery) 40/40 clean. Two
  failures worth a direct callout: `mint_realapp_icon_test.ps1` and
  half of `mint_theme_fullapp_smoke_test.ps1` time out waiting for the
  real main window against 15s/20s hardcoded budgets; a direct
  standalone timing check confirmed real startup now takes ~33 seconds,
  exceeding both -- dominant cost is Search and Manage's pre-existing
  real network scan (already documented as variable, "~10 seconds on a
  typical run"), with this round's own additions (Font +2pt cascading,
  Set-MintTabControlHeaderSizing's per-tab MeasureString loop) adding
  some real but lighter-weight overhead on top -- worth Jeremy's own
  awareness even though this session's own direct real-app launches
  (40s budget) succeeded every time. A third,
  `mint_realstartup_gridwidth_test.ps1`, had its own "sanity"
  precondition invalidated by pre-existing D-090 code
  (`TabControl.CreateGraphics()` inside `Set-MintTabControlHeaderSizing`
  forces the parent Form's handle to exist earlier than this test
  assumed) -- its real REGRESSION CHECK assertions all still pass. None
  of these three are a functional break; flagged for awareness, not
  fixed, since test-fixture/timeout changes are outside this round's
  12-item scope.
- Open items for Jeremy: see Q-15 in `AI-Project-Plan.md` -- item 2's
  literal instruction (both selected AND unselected tab background ->
  `#3C3D3E`) makes the active tab hard to distinguish from inactive
  ones at a glance; implemented as instructed pending his input.

### 2026-08-05 - Claude (Fixed a real D-089 regression; bigger tab headers/font + 5px padding; Warranty vendor status auto-checks on startup -- D-090)

- Files reviewed: Jeremy's message (verbatim in `AI-Project-Plan.md`'s
  D-090 entry) reporting tabs disappearing (both at startup and after
  being clicked), Warranty's Lenovo/Getac status staying "Unknown"
  until a manual Refresh, and asking whether ~25% bigger tab headers/
  font plus 5px of label padding was possible or a language limitation.
- Files changed: `Modules\Core.Theme.ps1` (v1.3.0 -> v1.4.0),
  `MIS Inventory Navigation Tool.ps1` (v1.15.0 -> v1.16.0),
  `Modules\Tab.Warranty.ps1` (v1.8.0 -> v1.9.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-090, full detail
  there).
- Implementation: reproduced the disappearing-tabs bug directly against
  the real app first (confirmed via a real cross-process screenshot:
  only 1 of 6 real tabs rendered at startup), then isolated the exact
  mechanism with a controlled live A/B test before touching any code --
  D-089's tab-strip-fill addition was painting outside its own tab's
  bounds during that tab's own OwnerDraw callback, which appears to
  mark neighboring tabs' regions as already-clean from Windows' own
  per-item paint tracking, so their own paint never gets dispatched.
  Fixed by moving the fill into a separate Paint handler on TabControl
  itself. Building the tab-sizing feature surfaced two more real,
  confirmed WinForms quirks: TabControl.ItemSize.Width is silently
  ignored unless SizeMode is explicitly Fixed, and GDI text measurement
  (TextRenderer.MeasureText) disagrees with the GDI+ measurement the
  actual rendering uses (Graphics.DrawString), which clipped multi-word
  tab labels until sizing was switched to Graphics.MeasureString
  throughout. A first attempt at wiring the sizing computation to
  TabControl's own HandleCreated event hung/crashed the process twice,
  even with a re-entrancy guard -- confirmed the cause (setting
  SizeMode can itself recreate the control's window handle, re-entering
  the same event mid-processing) and resolved by making it a plain,
  ordinary function call from the entry script instead, right after
  real TabPages exist -- not wired to any control event at all. Full
  mechanism for all three fixes in `AI-Project-Plan.md`'s D-090 entry.
- Testing: the existing D-089 pixel-regression script re-run clean
  (23/23) after updating its own tab-strip check (a DrawToBitmap-based
  pixel sample proved unreliable for that one harness/capture
  combination, a test-tooling quirk, not a real issue -- already proven
  correct two more direct ways). A real isolated repro dot-sourcing the
  actual fixed `Core.Theme.ps1` confirmed all 6 real tabs render
  correctly both at startup and after a simulated tab-selection change.
  A real cross-process screenshot of the actual running app confirmed
  the same against production code end to end. New
  `mint_warranty_autocheck_test.ps1` (7/7, real live network calls)
  confirms the startup auto-check fires once, automatically, without
  blocking the window's first paint, and never fires a second time;
  `mint_d086_test.ps1`'s own stale "stays Unknown" assertion updated to
  match the new intended behavior (34/34 clean after). Full 41-suite
  regression battery: an unusually high 5 suites timed out together in
  one pass (vs. the normal 1-2) -- all 5 already confirmed to share the
  same documented SendKeys/GetForegroundWindow flaky pattern this
  project's own battery runner already calls out; re-ran all 5
  standalone rather than assuming, and 4 of 5 passed cleanly in
  isolation (confirming pure environmental contention from an unusually
  heavy run of GUI automation this session, not a real regression). The
  5th, `mint_round2_test.ps1`, has never once completed in ANY battery
  run this entire session and turned out to have its own pre-existing,
  unrelated test-fixture gap (a missing stub function) -- left as out
  of scope, matching this project's own practice of not expanding scope
  onto an already-broken fixture. Net result: every suite touching a
  changed file passes cleanly and repeatably.
- Open items for Jeremy: none identified. The ~25% font bump and 5px
  padding are his own stated numbers, applied literally to TabControl's
  own inherited font size -- worth a quick look to confirm the exact
  proportions feel right once he's seen it live.

### 2026-08-04 - Claude (Dark Mode visual overhaul: VS Code-style palette, tab strip, ComboBox dropdowns, button/tab/panel borders -- D-089)

- Files reviewed: Jeremy's message (verbatim in `AI-Project-Plan.md`'s
  D-089 entry) reporting Dark Mode had "sections that turn up white"
  and "bold white borders... that make it look garrish," asking for a
  full VS Code-style re-theme using hex values he sampled himself, and
  naming three specific areas as completely unthemed: the bar behind
  the tabs, the bar the scrollbar sits inside, and dropdown menus +
  their arrow buttons. Used Plan Mode given the size (8 files) and the
  number of genuinely hard WinForms questions involved -- did extensive
  direct empirical testing (real WinForms rendering + pixel sampling,
  not assumptions) of the three hardest technical unknowns BEFORE
  writing the plan, and a `Plan` sub-agent's proposed technique for one
  piece (a custom menu color table via a PowerShell 5.1 `class`) was
  tested directly and found not to work, so it was dropped from the
  plan entirely rather than shipped and discovered broken later.
- Files changed: `Modules\Core.Theme.ps1` (v1.2.0 -> v1.3.0, palette
  rewrite + `Set-MintControlTheme`/`Enable-MintTabControlThemedDrawing`
  extensions + new `Add-MintThemedPanelBorder`/`Get-MintThemeWarningColor`),
  `MIS Inventory Navigation Tool.ps1` (v1.14.0 -> v1.15.0),
  `Modules\Core.Dialogs.ps1` (v1.3.0 -> v1.4.0), `Modules\Tab.Extract.ps1`
  (v2.9.1 -> v2.10.0), `Modules\Tab.Search.ps1` (v1.15.0 -> v1.16.0),
  `Modules\Tab.Upload.ps1` (v1.1.0 -> v1.2.0), `Modules\Tab.Warranty.ps1`
  (v1.7.0 -> v1.8.0), `Modules\Tab.Validate.ps1` (v4.1.0 -> v4.2.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-089,
  full detail there).
- Implementation: see `AI-Project-Plan.md`'s D-089 entry for the full
  palette mapping, the `ErrorFlagColor` legibility back-and-forth, and
  exactly how each of the three flagged areas was fixed (tab-strip full
  fill in the existing `DrawItem` handler; `ComboBox.FlatStyle=Flat` on
  every standalone and grid-hosted combo, including previously-
  uncolored transient editing controls; a new outline-only `BorderColor`
  used via `Button.FlatAppearance`, a drawn tab outline, and a new
  `Add-MintThemedPanelBorder` helper for the 3 native-bordered panels
  that had no recolorable property). Native scrollbar chrome is a
  confirmed, accepted limitation -- not fixed -- per Jeremy's own
  choice after seeing the live P/Invoke test proving the standard
  documented approach has no effect and anything further needs
  undocumented Windows internals. Validate and Organize brought into
  Dark Mode, reversing D-080's exclusion (Jeremy's updated call);
  found and fixed a real, separate pre-existing bug along the way
  (its 4 summary-box colors were never refreshed on a theme toggle).
- Testing: a new pixel-regression script (dot-sources the real
  `Core.Theme.ps1`, renders a representative control harness, asserts
  exact pixel colors via `DrawToBitmap`) -- 23/23 passing in BOTH
  themes, including Light-mode no-regression checks for the new code
  paths that now run unconditionally in both themes. A real live pass:
  launched the actual entry script, toggled the real Dark Mode checkbox
  via a direct `BM_CLICK` message (cross-process UI Automation cannot
  reliably invoke this checkbox, a limitation already known from
  D-062/D-083's own smoke tests), captured real window screenshots via
  `PrintWindow`, and visually confirmed all three fixes plus the
  border/bold-text work look correct against the real running app. The
  full regression battery (40 suites) caught two real issues before
  this was considered done: a first-pass brightened red still failed a
  pre-existing D-062 legibility test (luminance 109.6 vs. a required
  150) -- fixed by brightening further to a value that measures 157.9;
  and 2 stale hardcoded-color literals in `mint_d086_test.ps1` from
  before this palette existed -- updated to match the new, deliberately
  different `SuccessColor`. Both fixes re-verified individually, then
  the full battery re-run a second time end to end: every suite
  touching a changed file passes cleanly and repeatably; the only
  persistent failures are the same two pre-existing, already-flagged,
  unrelated items already known from D-085 (a SendKeys/window-focus
  timeout and one GroupTag free-text-save issue), neither touching any
  file this decision changed.
- Open items for Jeremy: several palette values were inferred rather
  than given directly (Button/TextBox/GridHeader background all reuse
  the one grid-background tone he gave, since he didn't break out a
  separate hex per control type) -- cheap to adjust once he's looked at
  it himself. The app's one right-click context menu keeps its
  existing background/text-only theming; a real border/hover-color fix
  would need a genuinely compiled C# class (confirmed a PowerShell 5.1
  `class` cannot do it), scoped out since that menu was never one of
  the three areas he flagged as broken.

### 2026-08-04 - Claude (Search and Manage encompasses Staging; Upload Builder real implementation -- D-088)

- Files reviewed: Jeremy's two-part message (verbatim in
  `AI-Project-Plan.md`'s D-088 entry) -- a lighter-weight "just a
  thought" that Search and Manage should also encompass the Staging
  folder, and a fully-specced request to build out the previously-
  placeholder Upload Builder tab: paste serials like Warranty Lookup,
  resolve against the hash library, load into an editable/batch-
  editable grid like Search and Manage, then write a multi-row
  canonical-format upload CSV to a per-account folder with an account
  dropdown defaulting to "Personal" and a documented Hall-County-
  specific "ad"-suffix admin-account stripping rule. Used Plan Mode for
  this one given the size (8 files, several real architecture
  decisions) -- a Plan-agent second pass caught a real keystroke-
  triggered performance trap and an aliasing-bug risk neither of which
  were in the original research dossier; both are designed around in
  the shipped implementation.
- Files changed: `Modules\Tab.Upload.ps1` (v1.0.0 -> v1.1.0, full real
  implementation replacing the placeholder), `Modules\Tab.Search.ps1`
  (v1.14.0 -> v1.15.0, Staging overlay + 2 promoted-function redirects),
  `Modules\Core.Inventory.ps1` (v1.6.0 -> v1.7.0, `-AdditionalFiles` +
  `Get-MintCombinedGroupTagChoices`), `Modules\Core.Domain.ps1` (v1.6.0
  -> v1.7.0, 2 promoted + 3 new functions), `Modules\Core.Csv.ps1`
  (v1.5.0 -> v1.6.0, `Write-MintUploadHashBatchFile`),
  `Modules\Core.Dialogs.ps1` (v1.2.0 -> v1.3.0, `Show-MintBatchEditDialog`
  promoted + `-AllowFixFormatOnly`), `Modules\Tab.Warranty.ps1` (v1.6.0
  -> v1.7.0, thin-wrapper redirect), `MIS Inventory Navigation Tool.ps1`
  (v1.13.0 -> v1.14.0, new `HashUploadRoot` path + Dark Mode wiring);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-088, full detail there).
- Implementation: see `AI-Project-Plan.md`'s D-088 entry for full
  detail on the Staging-overlay caching strategy, the in-memory-only
  safety property (why `New-MintUploadRow` copies fields instead of
  holding a live reference), and the account-folder resolution rule.
- Testing: a new sandboxed `mint_d088_test.ps1` (51 assertions, all
  passing) covers both parts end-to-end with real click-driven grid
  population, real byte-for-byte source-file-unchanged checks, and a
  real Batch Edit modal driven via the established
  `Application.OpenForms` timer technique (avoids the SendKeys/native-
  MessageBox flakiness this project's own regression runner already
  documents). Four real bugs were caught and fixed during this pass --
  two opposite-direction variants of the same PowerShell array-return-
  boundary pitfall this project already has a name for (P25/P29: wrap
  the whole pipeline, but only ONCE), one parameter-validation mismatch
  between two different consumers of the same new helper function, and
  one (found by the full regression battery, not the new suite)
  StrictMode throwing on dot-notation access to a genuinely MISSING
  hashtable key -- all four documented at their fix sites in code, full
  mechanism in `AI-Project-Plan.md`'s D-088 entry. Also re-ran the
  existing D-087 Warranty test (34/34, unaffected) and the full
  37-suite regression battery, clean after the 4th bug's fix:
  `mint_batch_edit_test.ps1` 36/36, every suite touching a changed file
  passes, and the only remaining failure is the same pre-existing,
  already-flagged, unrelated `mint_inline_edit_test.ps1` GroupTag issue
  from D-085's own entry.
- Open item for Jeremy: Upload Builder's serial resolution does not
  search `DecommissionRoot` -- a recently-decommissioned device's
  serial will show as plain "Not Found," not a distinct status: worth
  knowing if he ever pastes one in expecting to see why. The "ad"-
  suffix stripping rule has the same known false-positive limitation
  he himself described (a genuine username ending in "ad").

### 2026-08-04 - Claude (Warranty Lookup follow-ups: legacy-tolerant date formatting, blank cells, Vendor Status icons, coverage label removed -- D-087)

- Files reviewed: Jeremy's report (verbatim in `AI-Project-Plan.md`'s
  D-087 entry) that Warranty Start/End were STILL showing a time
  component after D-086's own date fix, with an exact example
  ("03/05/2026 00:00:00" for device MZ013XEZ); a request that any
  manufacturer-unreported field (Machine Type named specifically, but
  stated to apply generally) show a blank cell instead of the text
  "(unavailable)"; a request for a green check-circle/red X-circle icon
  next to each Vendor Status pane entry, matching the original tab
  mockup; and a request to remove the now-redundant "Vendor coverage
  today: ..." label.
- Files changed: `Modules\Tab.Warranty.ps1` (v1.5.0 -> v1.6.0) only --
  every fix this round lived in this one file.
- Implementation: see `AI-Project-Plan.md`'s D-087 entry for full
  detail on the root cause of the still-showing-time bug (D-086's fix
  only recognized ITS OWN clean write format, not older stale rows
  already on disk from before that fix -- now uses a general TryParse
  that reformats any parseable date/time text regardless of shape) and
  the Label-vs-PictureBox discovery for the status icons (Label cannot
  host an inline image the way Button-family controls can -- confirmed
  via a live PreferredSize comparison and the absence of a
  TextImageRelation property on Label at all).
- Testing: a new sandboxed `mint_d087_test.ps1` (24 assertions, all
  passing, including a real live Vendor Status Refresh click) covers
  every fix, including Jeremy's EXACT reported stale-date shape. Re-ran
  the existing D-086 test (34 assertions) to confirm no regression from
  touching the same functions again. Also re-ran the full existing
  37-suite regression battery: every suite touching the actually-
  changed file passed clean; two unrelated suites hit a transient
  Windows Clipboard-lock exception and the runner's own already-
  documented SendKeys timeout category respectively (both inside
  Tab.Search.ps1's own tests, neither touched this round); the one
  pre-existing GroupTag inline-edit failure flagged in D-085's own
  entry is unchanged.
- Open item for Jeremy: none new this round.

### 2026-08-03 - Claude ("Check database first" checkbox, Vendor Status pane, Source labeling, date-only database writes -- D-086)

- Files reviewed: Jeremy's three follow-up messages (verbatim in
  `AI-Project-Plan.md`'s D-086 entry) -- a checkbox to control cache-
  first vs. always-live-and-refresh lookup behavior on the Warranty tab;
  a Vendor Status pane matching the original tab mockup's bottom-right
  panel (Online in green, Not Configured/Offline in red); the Source
  column should say "Warranty Database" when a result came from the
  local cache, not the original vendor name; and warranty dates should
  never show a time component.
- Files changed: `Modules\Core.Theme.ps1` (v1.1.0 -> v1.2.0, new
  SuccessColor palette field + Get-MintThemeSuccessColor, mirroring the
  existing ErrorFlagColor/Get-MintThemeErrorColor pair),
  `Modules\Core.VendorLookup.ps1` (v1.6.0 -> v1.7.0, new
  Test-MintVendorPageReachable/Get-MintVendorStatusSummary),
  `Modules\Core.WarrantyCache.ps1` (v1.2.0 -> v1.3.0, date-only database
  writes + Source relabeling on a cache hit),
  `Modules\Tab.Warranty.ps1` (v1.4.0 -> v1.5.0, the checkbox, the Vendor
  Status pane, and a date-display bug fix caught while testing --
  Format-MintWarrantyDateForGrid), `MIS Inventory Navigation Tool.ps1`
  (v1.12.0 -> v1.13.0, Dark Mode toggle handler wired to the new
  Update-MintWarrantyVendorStatusColors); this handoff and the matching
  `AI-Project-Plan.md` (new Decision D-086, full detail there).
- Implementation: see `AI-Project-Plan.md`'s D-086 entry for full
  detail on the checkbox/-ForceRefresh wiring, the Vendor Status pane's
  deliberately-deferred (not tab-init-time) real network checks, the
  Source relabeling that leaves the on-disk CSV and Manual Verification
  rows untouched, and the date-only write fix.
- Testing: a new sandboxed `mint_d086_test.ps1` (34 assertions, all
  passing) covering the theme palette, the date-only database write
  (verified against the raw CSV line on disk, not just the parsed
  object), the Source relabeling (both the ordinary case and the Manual
  Verification exception), a real live `Get-MintVendorStatusSummary`
  call, the Vendor Status pane's full lifecycle (initial state, Refresh
  button, real network results), a real live forced-refresh Lenovo
  lookup overwriting a seeded stale cache entry, and the Dark Mode
  color re-apply. One real bug was caught and fixed during this pass:
  Format-MintWarrantyDateForGrid did not reformat a cache-hit record's
  plain-string warranty date, so it displayed raw ISO text next to a
  live-lookup row's MM/dd/yyyy text in the same column -- see
  `AI-Project-Plan.md`'s D-086 entry for the fix. Also re-ran the full
  existing 37-suite regression battery: every suite touching the
  actually-changed files passed clean; two suites unrelated to this
  round's changes (Model Lookup delete, Batch Extract suggested-rows)
  hit the runner's own already-documented SendKeys/window-focus timeout
  category, not a regression; the one pre-existing GroupTag inline-edit
  failure flagged in D-085's own entry is unchanged.
- Open item for Jeremy: the Vendor Status pane's Lenovo/Getac check
  uses an 8-second timeout, shorter than the real warranty lookup's own
  60-second one -- a slow-but-working response near that boundary could
  read as "Offline" even though a real lookup would still succeed.
  Treat "Offline" here as "worth a manual retry," not a hard guarantee.

### 2026-08-03 - Claude (Lenovo false-negative fix; Decommission/Restore warranty integration; Warranty tab Copy Serial(s) -- D-085)

- Files reviewed: Jeremy's report (verbatim in `AI-Project-Plan.md`'s
  D-085 entry) that a bulk warranty lookup run returned false "Not
  Found" results for real Lenovo devices (MJ0KVQGG confirmed on the
  vendor site), plus two follow-on requests: Decommission should pull
  cached warranty data instead of triggering a live lookup, Restore
  should force a fresh live lookup instead, and the Warranty tab needed
  its own Copy Serial(s) button matching the other tabs.
- Files changed: `Modules\Core.VendorLookup.ps1` (v1.5.0 -> v1.6.0,
  `Get-MintLenovoWarrantyRecord`'s `baseWarranties` pipeline-collapse
  fix plus a defense-in-depth try/catch around response parsing),
  `Modules\Tab.Search.ps1` (v1.13.0 -> v1.14.0, Decommission
  master-list schema + cache-only pull, Restore's forced-fresh
  refresh), `Modules\Tab.Warranty.ps1` (v1.3.0 -> v1.4.0, new Copy
  Serial(s) button); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-085, full detail there).
- Implementation: see `AI-Project-Plan.md`'s D-085 entry for full
  detail on the pipeline-collapse root cause, the cache-only-vs-forced-
  refresh split between Decommission and Restore, and the master list's
  self-migrating read-modify-write.
- Testing: real live Lenovo network calls both before and after the
  fix (MJ0KVQGG false-negative -> confirmed found; MZ013XH6 unaffected);
  `mint_extract_phase1_test.ps1` re-run clean (45 passed, 0 failed) for
  regression coverage on the Lenovo lookup path; a new sandboxed
  `mint_d085_test.ps1` (27 assertions, all passing) covering
  Decommission's cache-hit/cache-miss behavior, the master list's
  schema-migration safety against a seeded old-header file, Restore's
  forced-fresh refresh against the real live Lenovo API (with a seeded
  stale cache entry proving the overwrite is genuine, not a pass-
  through), and the Warranty tab's Copy Serial(s) button via a real
  WinForms form. This testing pass caught and fixed one real bug in the
  new Copy Serial(s) handler itself (a double `@(...)` wrap around
  `Get-MintGridSelectedRowsInVisualOrder`'s already-array-safe return,
  which broke every selection size, not just zero) -- see
  `AI-Project-Plan.md`'s D-085 entry for the full mechanism. All three
  touched files parse with 0 AST errors, UTF-8 BOM and ASCII-only. Also
  ran the full existing 37-suite regression battery for cross-suite
  fallout: everything touching the changed files passed clean; one
  unrelated pre-existing failure surfaced in `mint_inline_edit_test.ps1`
  (GroupTag free-typed edit not landing on disk) in a code path this
  round never touched -- flagged below, not investigated as part of
  D-085.
- Open item for Jeremy: re-run (or spot-check) the warranty lookups
  that came back "Not Found" during the original bulk run -- some may
  have been false negatives from this same single-`baseWarranties`-
  element bug, now fixed.
- Open item for Jeremy: `mint_inline_edit_test.ps1` has one failing
  assertion ("GroupTag edit with a brand-new free-typed value actually
  landed on disk") in Search and Manage's GroupTag ComboBox inline-edit
  path -- unrelated to anything changed this round, not yet
  investigated; worth a dedicated look next session.

### 2026-08-03 - Claude (Warranty cache relocated under variables\, renamed devicewarrantydb.csv -- D-084)

- Files reviewed: Jeremy's report that nothing was being written to
  `variables\devicewarrantydb.csv` after running real warranty lookups.
  Checked the entry script's real `$script:Paths.WarrantyCacheFile`
  definition against what Jeremy checked -- confirmed the real D-082
  path was `Endpoint Inventory\Warranty Cache.csv`, a different folder
  AND filename entirely, so nothing being at the path Jeremy checked was
  expected regardless of whether the real path had ever been populated.
  This session's dev environment has no network reach to the real
  filestore share, so could not independently confirm the old path's
  contents either way. Jeremy's follow-up (verbatim in
  `AI-Project-Plan.md`'s D-084 entry) confirmed his intended path and
  stated the actual standing rule this decision is built on: everything
  other than hash values, batch files, upload files, and machine-local
  files belongs under `variables\`.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.11.0 ->
  v1.12.0, `WarrantyCacheFile`'s `Join-Path` target moved),
  `Modules\Core.WarrantyCache.ps1` (v1.1.0 -> v1.2.0, header doc updated
  to the new location/rationale); this handoff and the matching
  `AI-Project-Plan.md` (new Decision D-084, full detail there).
- Implementation: deliberately kept the internal `$script:Paths`
  hashtable KEY as `WarrantyCacheFile` (unchanged) -- only the VALUE
  (on-disk path and filename) moved to
  `DataRoot\variables\devicewarrantydb.csv`. Every real consumer reads
  this key by name, and every existing test fixture's own sandboxed
  `$script:Paths` already pointed this key at an arbitrary standalone
  temp path unrelated to the other real paths, so nothing downstream
  needed a matching rename.
- Testing: per Jeremy's own explicit direction, no full regression
  battery for this one -- correctly scoped, since it is a single-value
  path change behind an unchanged key, touching no consumer logic.
  Verified: both touched files parse with 0 AST errors, UTF-8 BOM and
  ASCII-only; the new `Join-Path` resolution confirmed to match Jeremy's
  stated path exactly, character for character.
- Open item for Jeremy: if an old `Warranty Cache.csv` with real cached
  entries turns out to still exist under `Endpoint Inventory` on the
  real filestore, that data is now orphaned at the old location and
  would need a manual one-time copy into the new
  `devicewarrantydb.csv` -- not something this session could check or
  do without real network access to the share.

### 2026-08-03 - Claude (Staging-loop follow-up: Batch Extract duplicate-check fix, manual placement verification, generic variable-CSV sort tool -- D-083)

- Files reviewed: Jeremy's own reports (verbatim in `AI-Project-Plan.md`'s
  D-083 entry) -- first floating a "perpetual staging loop" concern for
  Dell/HP/Microsoft devices manually moved out of Staging, then, after
  reviewing and approving a proposed fix, a combined follow-up request
  for a manual verification override plus a new generic variable-CSV
  sort tool driven by his own new `variablesortlist.csv`, including a
  direct question deferring to my judgment on whether `grouptags.csv`
  should gain a header row. Re-read `Find-MintExtractDuplicateConflicts`/
  `Show-MintExtractDuplicateDialog`/`Invoke-MintExtractWriteRows`
  (`Tab.Extract.ps1`), `Resolve-MintValidatePlacementCheck`/
  `Invoke-MintValidateUnifiedFixSingleFile` (`Tab.Validate.ps1`), and
  `Core.WarrantyCache.ps1`'s full D-082 implementation before planning,
  via `EnterPlanMode` given the size and cross-cutting nature of the
  combined request. Found the "staging loop" concern was actually two
  distinct root causes needing two distinct fixes (a Batch Extract
  duplicate-check gap, and a separate Fix-tool re-flagging gap), not
  one. Found `Find-MintExtractDuplicateConflicts` already had the whole-
  library serial search built for every other row status, just
  explicitly skipped for ReviewStaging -- a one-guard-removal fix, not a
  new mechanism. Raised two design forks via `AskUserQuestion` before
  finalizing the plan (dedicated Verify Placement button vs. Move-only;
  first-column sort key vs. per-file configuration) -- Jeremy chose the
  recommended option both times.
- Files changed: `Modules\Tab.Extract.ps1` (v2.9.0 -> v2.9.1),
  `Modules\Core.WarrantyCache.ps1` (v1.0.0 -> v1.1.0, new
  `Save-MintValidateManualVerification`), `Modules\Tab.Validate.ps1`
  (v4.0.1 -> v4.1.0, new Verify Placement/Sort Variable Files buttons),
  `Modules\Core.Inventory.ps1` (v1.5.0 -> v1.6.0,
  `Get-MintGroupTagMapInternal` rewritten), `Modules\Core.Csv.ps1`
  (v1.4.0 -> v1.5.0, new `Invoke-MintVariableFileSort`),
  `Modules\Core.Dialogs.ps1` (v1.1.0 -> v1.2.0, new
  `Show-MintVariableSortDialog`), `Modules\Core.Domain.ps1` (v1.5.0 ->
  v1.6.0, bug fix -- see below), `MIS Inventory Navigation Tool.ps1`
  (v1.10.0 -> v1.11.0, new `VariableSortListFile` path); this handoff
  and the matching `AI-Project-Plan.md` (new Decision D-083, full detail
  there).
- Implementation: see `AI-Project-Plan.md`'s D-083 entry for full detail
  on all three pieces -- the Batch Extract fix, the manual verification
  mechanism (extends the D-082 warranty cache with a Verified Folder
  Name column and 'Manual Verification' Source, consumed by both
  placement-check functions ahead of the vendor-derived folder name),
  and the generic sort tool (unifies every variable file onto
  `Read/Write-MintVariableCsv`, including a `grouptags.csv` header
  addition Jeremy applies to the real production file himself).
- Testing: found and fixed one real regression via the regression
  battery itself, not caught by manual testing beforehand --
  `New-MintWarrantyRecord` (`Core.Domain.ps1`), the shape every LIVE
  (non-cached) warranty lookup returns, was missing the new
  `VerifiedFolderName` field that only the cache-HIT conversion path
  had gained; every real lookup's raw record therefore lacked the
  property entirely, and the new
  `$warrantyRecord.VerifiedFolderName` read in both placement-check
  functions threw a `PropertyNotFoundException` under StrictMode for
  every real lookup -- surfaced by `mint_validate_organize_test.ps1`'s
  own real live Getac lookup test failing ("RRB03B2021 appears in the
  grid" no longer true) and confirmed via the exact StrictMode error
  text captured in `mint_d082_features_test.ps1`'s own battery log.
  Fixed by adding `VerifiedFolderName = $null` to
  `New-MintWarrantyRecord`'s base shape (matches its own "one shape for
  every provider" principle) -- re-verified both affected suites
  individually before re-running the full battery. New
  `mint_staging_loop_and_sort_test.ps1` (40/40, stable across 3
  consecutive runs) covers all three pieces end to end, including a
  real UI-driven Sort Variable Files run (checklist, Sort click, one
  shared backup archive containing both changed files, a second click
  on now-sorted files reporting "Already sorted" with no new backup).
  11 existing fixtures batch-fixed for the new `grouptags.csv` header.
  Full battery (40 suites, two new suites added since D-082's own hotfix)
  re-run clean except the already-known pre-existing SendKeys/hidden-
  window flaky category (`mint_round2_test.ps1`, `mint_inline_edit_test.ps1`,
  and this run also `mint_remove_assigneduser_batch_test.ps1`/
  `mint_modellookup_delete_test.ps1` -- all four confirmed to use the
  same `SendKeys`/`GetForegroundWindow` polling pattern, none touching
  any file this decision changed).
- Open item for Jeremy: needs to add a `Group Tag` header line to the
  real production `grouptags.csv` himself (this session's standing rule
  never touches production data files directly) -- the exact literal
  text `Group Tag` as a new first line, before the existing tag values.
  Has not yet used Verify Placement, the updated Move, or Sort Variable
  Files against the real production data on his own machine.

### 2026-07-30/31 - Claude (Tool consolidation: warranty cache, Staging folder, unified fix tool, Search-to-Validate migration -- D-082)

- Files reviewed: Jeremy's own reports (verbatim in `AI-Project-Plan.md`'s
  D-082 entry) asking for a unified fix tool that rebuilds a file's data
  canonically and resolves the correct folder via warranty lookup,
  followed by a separate report introducing the new Staging folder he
  had already created on the shared filestore, its Scan Library dropdown
  requirement (excluded from `devicetype.csv`), confirmation of the
  cache-miss/lookup-fails handling ("leave the file in place and note a
  flag that it needs to be manually checked/moved"), and a request to
  add Edit Model Folders to Validate and Organize. Re-read
  `Resolve-MintWarrantyLookup` (`Core.VendorLookup.ps1`),
  `Get-MintHashLibraryFilesInternal` (`Core.Inventory.ps1`),
  `Show-MintModelMapEditorDialog` (`Tab.Extract.ps1`, pre-move), and
  Search and Manage's own Move/Duplicate/Fix Import Format/View Format
  Issues code before planning, via `EnterPlanMode` given the size and
  cross-cutting nature of the request. Found `Get-MintHashLibraryFilesInternal`
  derives `DeviceTypeFolder`/`ModelFolderName` from a file's path
  segments relative to whatever root it is given -- pointing it directly
  at a device-type subfolder to "scope" a scan would silently corrupt
  `DeviceTypeFolder`, the exact bug class a new `-DeviceTypeFilter`
  parameter was built to avoid. Found `New-MintBackupArchive`/
  `Close-MintBackupArchive` write a real zip to disk the instant they
  are opened, even with zero files ever added -- confirmed the new
  cache layer must never go through that ceremony. Raised three design
  forks via `AskUserQuestion` before touching code (Staging vs. Review
  Staging consolidation, "All" scope excluding Staging, Edit Model
  Folders starting with no suggestions) plus two more during planning
  (collapsing the fix buttons from three to two; confirming the old
  Review Staging folder was empty before treating the migration as safe)
  -- Jeremy chose the recommended option every time.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.9.0 -> v1.10.0),
  new `Modules\Core.WarrantyCache.ps1` (v1.0.0), `Modules\Core.Inventory.ps1`
  (v1.4.0 -> v1.5.0), `Modules\Core.Dialogs.ps1` (v1.0.0 -> v1.1.0),
  `Modules\Core.Domain.ps1` (v1.4.0 -> v1.5.0), `Modules\Tab.Extract.ps1`
  (v2.8.0 -> v2.9.0), `Modules\Tab.Validate.ps1` (v3.2.0 -> v4.0.0),
  `Modules\Tab.Search.ps1` (v1.12.0 -> v1.13.0), `Modules\Tab.Warranty.ps1`
  (v1.2.0 -> v1.3.0); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-082, full detail there).
- Implementation: see `AI-Project-Plan.md`'s D-082 entry for full detail
  on the warranty cache (never caches a negative result), the Staging
  folder (replaces Review Staging outright, excluded from an "All" scan
  and from `devicetype.csv`), the Device Type filter (post-filters after
  scanning from the TRUE root, never re-roots the scan itself), the
  unified fix tool (copy-verify-then-delete relocation; a cache-miss/
  lookup-fails file is reformatted in place and flagged via its
  `FixMessage`, never auto-relocated to Staging), and the four tools
  migrated from Search and Manage to Validate and Organize (Batch
  Edit's own "Fix Import Format only" mode was explicitly left alone on
  Search).
- Testing: found and fixed one genuine (test-only, not production) bug
  via a diagnostic before concluding a newly-exposed SendKeys-based
  test failure was flaky rather than real -- a `Ctrl+A` SendKeys
  keystroke does not reliably select-all the existing text in a
  `DataGridViewComboBoxEditingControl`, so a pre-existing (unrelated)
  test's free-typed Group Tag assertion had been silently un-exercised
  every prior run this session, masked by an unrelated StrictMode crash
  earlier in the same file; confirmed via a targeted diagnostic that the
  real production commit/save logic was correct throughout, then fixed
  the test to call `.SelectAll()` directly instead of relying on
  SendKeys for it. Also found the new dedicated test suite's own sandbox
  construction from raw `$env:TEMP` resolves to the short 8.3-alias form
  of this machine's profile path, disagreeing with a real file scan's
  always-normalized-to-long-form `FullName` -- a test-environment
  artifact only (production's real `HashLibraryRoot` is a fixed UNC
  string with no such aliasing), fixed by normalizing the sandbox root
  once. New `mint_d082_features_test.ps1` (67/67, added to the battery)
  covers the warranty cache (hit/miss/never-caches-negative-results/
  zero-backup-spam/missing-and-corrupt-file tolerance), Staging
  exclusion from "All" plus a correct flat Staging-only scan, the
  Device Type filter with an explicit `DeviceTypeFolder`-not-corrupted
  regression check, the unified fix tool relocating a file needing both
  a format fix and a Model Folder correction in one pass (verified via
  a real backup archive containing the byte-identical pre-fix original),
  the cache-miss/lookup-fails-leaves-in-place-and-flags behavior, Edit
  Model Folders on Validate and Organize opening with zero suggestions,
  and a rewrite of a retired report-write-failure-continuation scenario
  against the new `Invoke-MintValidateFixPass` call site. Existing
  fixtures updated across three classes of staleness (missing
  dot-sources, a renamed `$script:Paths` key, stale assertions/direct
  call sites reflecting the old three-button/Reformat/Duplicate-column
  behavior); two fixtures retired outright
  (`mint_move_to_model_folder_test.ps1`,
  `mint_batch_continuation_test.ps1`) once their coverage was confirmed
  present elsewhere or rewritten against the new call site. Full battery
  (38 suites) re-run clean except the two already-known pre-existing
  SendKeys/hidden-window flaky items (both confirmed to pass cleanly
  when run in isolation, outside the parallel hidden-window battery
  runner).
- Open item for Jeremy: has not yet used the new Staging dropdown,
  Device Type filter, unified fix tool, or migrated Search-to-Validate
  buttons against the real production hash library on his own machine.
  The old `Review Staging` folder (now retired in code) still physically
  exists on the shared filestore -- confirmed empty before this
  decision, but left for Jeremy to remove at his own discretion.

### 2026-07-30 - Claude (Project-wide grid design standard -- D-081)

- Files reviewed: Jeremy's 11-point spec (verbatim in
  `AI-Project-Plan.md`'s D-081 entry) asking for one permanent grid
  standard across the whole project -- sortability, header/content-based
  minimum width with 15px padding, user resize even below that minimum,
  column reordering, hide/show, and cross-session settings persistence,
  the last three explicitly delegated to Claude's own risk judgment with
  permission to skip. Re-read `Set-MintGridColumnWidthsToContent` (entry
  script, D-067) and every grid's own column-definition code
  (`Tab.Search.ps1`, `Tab.Extract.ps1`, `Tab.Validate.ps1`) before
  planning, via `EnterPlanMode` given the size and cross-cutting nature
  of the request. Found points 1-4 already implemented project-wide.
  Found a direct conflict between point 6 and D-067's own existing
  MinimumWidth lock (which Jeremy himself had requested) -- raised via
  `AskUserQuestion` before finalizing the plan; Jeremy confirmed:
  relax the lock.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.8.0 ->
  v1.9.0), `Modules\Core.Theme.ps1` (v1.0.1 -> v1.1.0),
  `Modules\Tab.Search.ps1` (v1.11.0 -> v1.12.0), `Modules\Tab.Extract.ps1`
  (v2.7.0 -> v2.8.0), `Modules\Tab.Validate.ps1` (v3.1.0 -> v3.2.0);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-081, full detail there).
- Investigation: a codebase-wide grep for positional column/cell access
  (`Cells[0]`, `Columns[1]`, etc.) found zero matches -- every reference
  anywhere in the project is by column `Name`, and the two grids with
  live inline cell editing (Search's `liveGrid`, Extract's `resultsGrid`)
  already resolve `$senderControl.Columns[$e.ColumnIndex].Name` before
  branching on the name. `DataGridViewCellEventArgs.ColumnIndex` is
  WinForms' stable `Columns`-collection index, not the visual
  `DisplayIndex` -- confirming reordering could not break any existing
  handler. Found Extract's `conflictGrid`/`editorGrid` are transient
  dialog grids rebuilt fresh every open, not persistent tab views --
  excluded from reorder/hide/persistence.
- Implementation: `Set-MintGridColumnWidthsToContent` now adds 15px
  padding beyond the AutoResizeColumns fit and relaxes `MinimumWidth` to
  a small 20px floor instead of locking it to the fitted width;
  preserves a column's width across repopulates once tagged
  `MintRestoredWidth`. New shared `Show-MintGridColumnVisibilityMenu`
  (right-click column header, hide/show, refuses to hide the last
  visible column) and `Enable-MintGridDesignStandard` (wires
  reordering, the visibility menu, restore, and a `MouseUp`-triggered
  save onto one grid in a single call). `Core.Theme.ps1` gained
  `Get-MintGridSettings`/`Save-MintGridSettings`/`Restore-MintGridSettings`
  against a new `Grids` object in the existing `MINT-Settings.json`.
  Each of the 4 persistent grids calls `Enable-MintGridDesignStandard`
  once at init.
- Testing: found and fixed two real bugs via the new test, before
  either reached the real app. (1) `Save-MintGridSettings` used plain
  dot-notation (`$settings.Grids.$GridKey = $gridEntry`) to add a new
  property -- confirmed live that this throws under
  `Set-StrictMode -Version Latest` (unlike `$obj.LiteralName = value`,
  which does auto-vivify; that behavior does not extend to the
  `.$Variable` dynamic form), silently caught by the function's own
  never-throw try/catch, so nothing was actually being saved to disk.
  Fixed with `Add-Member -Force`. (2) `Restore-MintGridSettings` set a
  saved `.Width` directly, but a freshly built grid is still in its
  construction-time `AutoSizeColumnsMode = AllCells` at that point
  (`Set-MintGridColumnWidthsToContent` has not run yet) -- confirmed
  live that a direct `.Width` assignment under continuous AllCells is
  silently overridden on the next layout pass. Fixed by switching
  `AutoSizeColumnsMode` to `None` first when there is a width to
  restore. New `mint_grid_design_standard_test.ps1` (37/37) extracts the
  REAL production functions from the entry script's own AST (same
  pattern as `mint_theme_mainform_test.ps1`), not a reimplementation --
  covers padding, floor relaxation, session-width preservation across a
  repopulate, `AllowUserToOrderColumns`, a real
  `ToolStripMenuItem.PerformClick()` hiding a column and saving
  immediately, the last-visible-column guard, a full
  save-on-one-grid/restore-onto-a-fresh-grid round trip surviving a
  simulated repopulate, and never-throw behavior against a missing or
  hand-corrupted settings file. Added to the regression battery (now 37
  suites), full re-run clean except the two already-known pre-existing
  flaky items.
- Noted but not fixed (out of scope): `mint_gridwidth_v2_test.ps1`
  embeds its own hand-copied duplicate of the PRE-D-081
  `Set-MintGridColumnWidthsToContent` rather than extracting the real
  function -- it will keep passing regardless of future changes to the
  real function, and its "clamped back to the floor" assertion now
  describes behavior the real app no longer has. Worth a future cleanup
  (delete, since the new test fully supersedes it, or convert to real
  AST extraction).
- Open item for Jeremy: has not yet used the reordering/hide-show/
  persistence features against the real app on his own machine -- the
  new test proves the mechanism works correctly end-to-end against real
  WinForms controls, but not the full lived experience (e.g. whether
  the right-click gesture feels discoverable without any on-screen
  hint that it exists).

### 2026-07-30 - Claude (Validate and Organize: summary-count/Format-Issue mismatch fixed, Issue column color-coded -- D-080)

- Files reviewed: Jeremy's report, verbatim: "Just did a scan. 383
  scanned. 200 clean, 0 fixed, 8 flagged. If there was 383 scanned and
  only 208 accounted for, where are the other 175 files? Also, there is
  a large section of files (Particulary the GETAC B306 Gen 3 files)
  where the format says 'Needs Fixing', but the issue says 'None'. For
  the 'Issue' column, I would like anything that's a duplicate for the
  text to appear in red, all other issues should appear blue. I can't
  decide if 'None' should exist if the format is 'OK'. If it does
  exist, the text can remain default color." Also explicitly asked to
  hold off on Dark Mode for this tab for now, to be addressed
  separately later. Re-read `Get-MintValidateFlagReasons`/
  `Update-MintValidateResultFlags`/`Update-MintValidateSummary`/
  `Update-MintValidateGrid` in `Modules\Tab.Validate.ps1` (all authored
  this session's own D-079 work) to trace the exact mechanism before
  changing anything.
- Files changed: `Modules\Tab.Validate.ps1` only (v3.0.0 -> v3.1.0);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-080, full detail there).
- Investigation: found the root cause is `Get-MintValidateFlagReasons`
  deliberately withholding a non-canonical file's `FormatIssues` from
  `FlagReasons` whenever the file was auto-fixable -- such a file had
  empty `FlagReasons` (`IsFlagged = $false`) while `IsClean` also
  required `-not IsAutoFixable` (`$false` too), so it landed in neither
  Clean nor Flagged and its grid row showed Format "Needs Fixing" next
  to Issue "None". Also found and closed the same class of gap for a
  filename/serial-mismatch-only file (`Test-MintValidateFileIsReformattable`
  can be true even when `IsCanonicalFormat` is true), which had no flag
  reason at all before this fix and would have surfaced the identical
  complaint for a different file shape eventually.
- Implementation: `Get-MintValidateFlagReasons` now always adds a
  non-canonical file's FormatIssues (removed the `-and -not
  $Result.IsAutoFixable` exclusion) plus a new "Filename does not match
  Device Serial Number" reason. `IsClean` simplified to "no flag
  reasons" (the old extra exclusion was the actual bug and is now
  redundant). `Update-MintValidateSummary` rewritten as one pass per
  result with explicit priority Flagged > Fixed > Clean, guaranteeing
  the three counters always sum to Scanned. `Update-MintValidateGrid`
  sets the Issue cell's `Style.ForeColor` per row: red
  (`FromArgb(204,51,0)`) for a duplicate, blue (`FromArgb(0,102,204)`)
  for any other issue, left alone (default) for "None" -- static
  colors, matching the existing summary-box palette, not theme-aware.
- Testing: new `mint_validate_count_fix_test.ps1` (28/28) -- reproduces
  the exact GETAC B360 Gen 3 scenario (non-canonical, auto-fixable, no
  other problems) in a sandboxed fixture and proves Clean+Fixed+Flagged
  sums exactly to Scanned both before and after an Auto Fix All Issues
  pass, the affected rows show real Issue text instead of "None", and
  the red/blue/default color-coding is correct. Added to the 36-suite
  regression battery, full re-run clean except the two already-known
  pre-existing flaky items (`mint_round2_test.ps1` timeout,
  `mint_inline_edit_test.ps1`'s one GroupTag assertion).
- Open item for Jeremy: has not yet re-run this exact scan against the
  real hash library to confirm 383 now fully accounts for itself in
  production -- the sandboxed repro matches his report precisely but a
  real-data confirmation is still worth getting.

### 2026-07-30 - Claude (Validate and Organize redesigned to a review-and-select model -- D-079 -- plus Core.Dialogs.ps1)

- Files reviewed: Jeremy's report, verbatim: "The function right now is
  to scan and automatically fix. I do not want this. I want to be able
  to review and select changes. The tab should look and work something
  similar to what's seen in the '...Inventory Hash Management Tool -
  Tab Mockups.png' image, the validate and organize tab is the first
  section in the top left of the image." Followed by 7 numbered
  requirements: an editable Scan Library path defaulting to the real
  library location; Auto Fix All Issues; Fix Selected Issues (grid
  selection only); a colored counter summary; a sortable grid; grid
  columns Row #/Serial Number/Device Type/Model Folder/Format/Issue/
  Action; and Move/Delete/Reformat actions, with Reformat described as
  "completely cleans up the file... ensures the filename is the same
  as the serial number... eliminates quotation marks, etc." Viewed the
  actual Tab Mockups image directly before designing anything. Two
  open questions resolved directly with Jeremy: the Scan Library path
  is real/overridable but still assumes the real library's own folder
  structure (no generic scanner); Move opens the same interactive
  picker dialog Search and Manage already has, not a silent auto-move.
- Files changed: `Modules\Core.Inventory.ps1` (v1.3.0 -> v1.4.0),
  `Modules\Core.Dialogs.ps1` (new, v1.0.0), `Modules\Tab.Search.ps1`
  (v1.10.0 -> v1.11.0), `Modules\Core.Domain.ps1` (v1.3.0 -> v1.4.0),
  `Modules\Tab.Validate.ps1` (v2.0.0 -> v3.0.0), `MIS Inventory
  Navigation Tool.ps1` (v1.7.0 -> v1.8.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-079, full detail
  there).
- Investigation: confirmed `Get-MintHashLibraryFilesInternal`'s only
  real dependency on `$script:Paths` was the root path itself -- Device
  Type/Model Folder resolution already worked purely from folder
  structure, so an optional `-HashLibraryRoot` override was small and
  safe. Confirmed `Show-MintMoveToModelFolderDialog` had no hidden
  dependency on Tab.Search.ps1's own state beyond its two existing
  parameters, making it a clean, verbatim promotion.
- Implementation: `Invoke-MintValidateScan` no longer calls the
  auto-fix pass and no longer touches the shared inventory index --
  builds its own local result set instead, so an overridden scan root
  can never silently corrupt Search and Manage's own view. Auto Fix
  All Issues and Fix Selected Issues both reuse the existing
  `Invoke-MintValidateAutoFixPass` unchanged, just with a different
  `-Results` scope. New `Test-MintValidateFileIsReformattable`/
  `Invoke-MintValidateReformatSingleFile`/`Invoke-MintValidateReformatPass`
  back Reformat: the same content rewrite as the safe auto-fix, plus a
  rename to the file's own Device Serial Number when its filename
  disagrees, then a re-read from disk to refresh format fields in
  place (no full re-scan needed). Move/Delete both widened to
  multi-select; Move requires the selection to share one current
  folder and opens the real interactive dialog (promoted to new
  `Core.Dialogs.ps1` -- same reasoning as D-077's `Core.FileOps.ps1`:
  no tab-to-tab dependencies allowed, so a dialog two tabs need
  belongs in Core); Delete lost its duplicate-only gating entirely.
- Tests/validation performed: all 6 changed/new files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New
  `mint_validate_redesign_smoke_test.ps1` (19/19) covers the new flow
  end-to-end: scan finds a fixable file but does not touch it; Auto
  Fix All Issues genuinely fixes it; Reformat genuinely renames a
  serial/filename-mismatched file with its grid Issue clearing
  afterward; a real interactive Move dialog click-through relocates a
  file to an operator-chosen folder; Delete succeeds on a plain
  non-duplicate row. The existing `mint_validate_organize_test.ps1`
  (D-078) was updated for the decoupled scan and the real dialog-
  driven Move (20/20). 16 existing fixtures dot-sourcing
  `Tab.Search.ps1` needed `Core.Dialogs.ps1` added to their own
  dot-source list (same class of fix as D-077's `Core.FileOps.ps1`).
  A real PowerShell string-interpolation bug was found and fixed live
  via the new smoke test (see this handoff's Recent Changes entry for
  detail) -- a genuinely reusable lesson for this codebase, not
  specific to this feature. Full 35-suite regression battery re-run
  clean except the two already-known pre-existing flaky items.
- Remaining risks or human decisions: Jeremy has not yet personally
  used the redesigned tab against the real hash library. The Move
  dialog's Model Folder choices still come from the global inventory
  index tied to the real configured root, not an overridden scan root
  -- only matters in the rare case the Scan Library path is actually
  changed away from the default.

### 2026-07-30 - Claude (Validate and Organize built for the first time -- D-078 -- plus Core.FileOps.ps1, D-077)

- Files reviewed: Jeremy's request, verbatim: "Let's get started on the
  Validate and Manage tab. Utilize any pre-existing modules that have
  been created so far, and when creating new tooling make sure to keep
  in line with the modularity and moldability functionality of the
  project scope." (Section 6's real tab name is "Validate and Organize"
  -- the only tab in the six-tab plan matching this description, and
  the only one still a placeholder; confirmed this reading before
  building anything, rather than guessing.) When the misplaced-file
  check's design needed a real cost/accuracy tradeoff decision --
  live warranty lookup for every file (accurate, real network cost)
  versus a cheaper local-only heuristic (fast, weaker) -- asked Jeremy
  directly rather than assuming; he chose the live warranty lookup for
  every file.
- Files changed: `Modules\Core.FileOps.ps1` (new, v1.0.0),
  `Modules\Tab.Search.ps1` (v1.9.0 -> v1.10.0), `Modules\Core.Csv.ps1`
  (v1.3.0 -> v1.4.0), `Modules\Core.Domain.ps1` (v1.2.0 -> v1.3.0),
  `Modules\Tab.Validate.ps1` (placeholder v1.0.0 -> v2.0.0), `MIS
  Inventory Navigation Tool.ps1` (v1.6.0 -> v1.7.0, `$script:ToolVersion`
  1.0.5 -> 1.1.0); this handoff and the matching `AI-Project-Plan.md`
  (new Decisions D-077 and D-078, full detail there).
- Investigation: read every relevant existing Core module before
  writing anything new, per Jeremy's explicit "utilize pre-existing
  modules" instruction. Found that `Core.Inventory.ps1`'s full-library
  scan already builds every file with `IsCanonicalFormat`/
  `FormatIssues`/`ReadError`/`IsDuplicate`/`DuplicateLocations`
  populated (duplicate detection needed zero new code), and
  `Core.Backup.ps1`'s own docstring had already anticipated this tab's
  need ("a future multi-file batch run (Validate tab auto-fix, Batch
  Extract) can add many files to one archive/report"). Found a real,
  previously-undetected gap: Section 4's required validation list names
  "hash not valid base64" and an implied blank-hash check, neither of
  which `Read-MintCanonicalHashFile` actually implemented -- a file
  with garbage/blank Hardware Hash was silently passing as canonical
  everywhere, including Search and Manage's own grid.
- Implementation: `Invoke-MintMoveSingleFile`/
  `Invoke-MintFixImportFormatSingleFile`/`Invoke-MintDeleteSingleFile`
  promoted out of `Tab.Search.ps1` into new `Core.FileOps.ps1` (D-077)
  -- this codebase has no tab-to-tab dependencies anywhere, so a worker
  two tabs both need belongs in Core, matching the exact precedent
  already set by `Get-MintModelDestinationFolder`'s D-065 promotion.
  Zero behavior change to Search and Manage's own callers. New
  `Test-MintValidateFileIsAutoFixable` classifies a file as correctable
  only when its remaining problems are purely structural; anything
  touching the data itself (ambiguous row count, blank/mismatched
  serial, blank/invalid hash) is non-correctable by default. New
  `Resolve-MintValidatePlacementCheck` runs the real warranty lookup,
  resolves the expected folder via the existing
  `Get-MintResolvedModelFolderName`, and returns a three-state result
  (verified-correct / verified-misplaced / unverifiable) rather than a
  bare bool, so a file the warranty pipeline cannot identify is never
  accused of misplacement. Device Type is never checked (the warranty
  pipeline does not report one), stated plainly in the tab's own
  description text, mirroring Batch Extract's own `NeedsFolderReview`
  limitation. The classification pass dedupes the warranty lookup by
  normalized serial for the whole scan. Guided resolution (Move/Delete)
  is single-row-only for v1 and patches the in-memory result set
  locally after a successful action instead of a full re-scan,
  specifically to avoid re-running real warranty lookups unnecessarily;
  Delete reuses Search and Manage's own established two-step
  backup/confirm UX exactly.
- Tests/validation performed: all 5 changed/new files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New
  `mint_validate_smoke_test.ps1` (21/21) and
  `mint_validate_organize_test.ps1` (19/19): every classification case;
  a real live placement check against a real Lenovo serial (correctly
  verified NOT misplaced) and a real Getac serial deliberately filed
  under the wrong Model Folder (correctly flagged misplaced, exact
  expected folder name resolved -- "Getac B360 Gen 3", matching this
  exact serial's real warranty data already confirmed in D-073); a real
  end-to-end Move click-through that physically relocates a file on
  disk; a real end-to-end Delete click-through with the same two-step
  confirm UX as Search and Manage; dedupe-by-serial confirmed via a
  call-counting stand-in (a duplicate pair triggers exactly one real
  lookup); an auto-fix pass proving no batch abort when one file is
  locked mid-loop, with exactly one shared backup zip for the whole
  pass. Fixing the base64 check's real detection gap surfaced that
  roughly 19 existing test fixtures across the whole regression battery
  used fake, non-base64 placeholder Hardware Hash values ("HASH1",
  "HASHDATA1", etc.) that now correctly failed validation -- fixed via
  an automated script that base64-encodes each distinct token
  consistently everywhere it appears in a file; 3 files whose hash
  values were built via loop-variable string interpolation (e.g.
  "HASH$i") needed a different, hand-written fix (wrapping the whole
  interpolated expression in a runtime base64-encode call), since a
  blind text substitution would have left a raw digit appended after an
  already-encoded prefix, producing invalid base64. 16 existing test
  fixtures that dot-source `Tab.Search.ps1` directly also needed
  `Core.FileOps.ps1` added to their own dot-source list (same class of
  fix already performed twice this session for other promotions). Full
  35-suite regression battery re-run clean except the two already-known
  pre-existing flaky items (`mint_round2_test.ps1`'s occasional timeout,
  confirmed harmless in isolation; `mint_inline_edit_test.ps1`'s
  free-typed-GroupTag assertion, flaky since D-068).
- Remaining risks or human decisions: Jeremy has not yet personally used
  the tab against the real hash library. A full-library scan's real
  cost (one warranty lookup per lookup-eligible file, up to 61 real
  seconds per call in a worst case already observed elsewhere in this
  project) has not been measured against the real ~380-file production
  library. Move to Correct Folder never corrects Device Type, by
  design, since the warranty pipeline cannot verify it.

### 2026-07-29 - Claude (Move to Model Folder redesigned -- Device Type + Model Folder, multi-select -- and the Desktop/Laptop/GETAC folder-name translation layer removed -- D-076)

- Files reviewed: Jeremy's report, verbatim: "Search and Manage: The
  'Move to Model Folder' option currently only brings up the models
  listed under the existing device type of the machine. There should
  be two selections, the Device Type, and the Model Folder. ... If I
  decided it needed to be moved to a Laptop device type, this
  currently isn't available. So, adding the device type to the list,
  the newly selected device type should populate the Model Folder list
  with what's under that device type. The Device Types should populate
  its list from the '\\hallcounty\filestore\mis\MIS\Intune\MIS
  Inventory Navagation Tool\variables\devicetype.csv' file.
  Additionally, at the moment this functionality is locked out if
  multiple selections are made. I would like to unlock this so the
  move is possible so long as all of the selected devices are under
  the same model folder." Followed by: "Additionally, I have changed
  the folder names from 'Desktops' to 'Desktop', 'Laptops' to
  'Laptop', and 'Getacs' to 'GETAC' so that from now on we can use the
  devices in devicetype.csv directly to help determine the folder path
  and keep everything else consistent with the modular theme."
- Files changed: `Modules\Core.Domain.ps1` (v1.1.0 -> v1.2.0),
  `Modules\Core.Inventory.ps1` (v1.2.0 -> v1.3.0),
  `Modules\Tab.Extract.ps1` (v2.6.0 -> v2.7.0), `Modules\Tab.Search.ps1`
  (v1.8.5 -> v1.9.0), `MIS Inventory Navigation Tool.ps1` (v1.4.0 ->
  v1.5.0); this handoff and the matching `AI-Project-Plan.md` (new
  Decision D-076, full detail there).
- Investigation: confirmed the real `variables\devicetype.csv` exists
  (header "Device Type", 3 rows: Desktop/Laptop/GETAC), and confirmed
  live via `Get-ChildItem` that the real Hash Library's top-level
  folders are now literally `Desktop`, `GETAC`, `Laptop`, matching
  Jeremy's rename. Grepped the whole codebase for every consumer of the
  three old singular<->plural translation maps
  (`$script:MintDeviceTypeFolderMap`, `$script:MintDeviceTypeFolderToSingular`,
  `$script:MintDeviceTypeSingularToFolder`) and `Get-MintDeviceTypeDisplayName`
  before removing them, to confirm nothing was missed.
- Implementation: `Show-MintModelPickerDialog` (single Model Folder
  field, Device Type fixed to the selection's current value) replaced
  by `Show-MintMoveToModelFolderDialog`: a Device Type combo
  (`DropDownList`, sourced from new `Get-MintDeviceTypeChoices`) and a
  typeable Model Folder combo. Changing Device Type re-populates Model
  Folder's choices from that type's own real folders and clears the
  Model Folder text. New `Test-MintSearchSelectionSharesModelFolder`
  gates the Move button for multi-selection: true only when every
  selected file shares the same Device Type + Model Folder. New
  `Invoke-MintMoveSingleFile` mirrors
  `Invoke-MintDecommissionSingleFile`'s per-file backup/report/result-
  object shape, looped over the selection so one file's failure does
  not abort the rest. The three translation maps and
  `Get-MintDeviceTypeDisplayName` were removed entirely; every former
  consumer (device-model construction, the live grid's Device Type
  filter/display, Batch Extract's destination preview and Batch Edit
  dialog) now uses the Device Type value directly.
- Tests/validation performed: all 5 changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New
  `mint_move_to_model_folder_test.ps1` (28 of 28 passing) drives the
  real `Show-MintMoveToModelFolderDialog` end-to-end via a Timer
  polling `Application.OpenForms` (this project's established dialog-
  testing pattern): confirms the dialog's defaults, that Model Folder's
  choices are initially scoped to the current Device Type, that
  changing Device Type live-refreshes those choices, and exercises a
  real single-file move and a real two-file multi-select move (both
  physically relocate files on disk, with backup zip verification) plus
  a direct collision-handling check on `Invoke-MintMoveSingleFile`.
  Full 33-suite regression battery re-run clean except the two already-
  known pre-existing flaky items (`mint_round2_test.ps1`'s occasional
  timeout under the headless battery runner, confirmed to pass 22/22 in
  isolation; `mint_inline_edit_test.ps1`'s free-typed-GroupTag
  assertion, flaky since D-068). While verifying, found and fixed 4
  unrelated pre-existing test-fixture gaps that this change's new
  unconditional `Get-MintDeviceTypeMapInternal` call exposed: 22
  fixtures missing the new required `DeviceTypeListFile` Paths key (2
  of which also needed real devicetype.csv content to keep an exact
  scan-issue-count assertion correct), 5 files with stale hardcoded
  'Desktops'/'Laptops' literals surviving the folder rename, one
  synthetic test object missing fields a real object always has, and
  one unrelated D-057 test missing a MessageBox auto-dismiss that
  caused a hang -- none were caused by this feature, but all were fixed
  so the regression battery stays trustworthy.
- Remaining risks or human decisions: Jeremy has not yet personally
  used the redesigned dialog or multi-select move against the real
  tool.

### 2026-07-29 - Claude (AD Department/Location now shows a subfolder under a department's Computers container -- D-075)

- Files reviewed: Jeremy's report, verbatim: "Under the AD Department/
  Location module, lets change it so that if it is in the standard
  `<department>/Computers` folder, it just shows the department, but if
  there is a subfolder that it is in under the
  `<department>/Computers` folder, it will show what that folder is.
  For example, there is a folder '.../MIS/Computers/Mobile', so it
  would display 'Department: MIS - Mobile'."
- Files changed: `Modules\Core.ActiveDirectory.ps1` (v1.0.0 -> v1.1.0),
  `Modules\Tab.Search.ps1` (v1.8.4 -> v1.8.5); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-075, full detail
  there).
- Investigation: read `Resolve-MintDeviceAdLocation`'s existing
  distinguished-name parsing first, then verified live against real AD
  rather than assuming Jeremy's described structure was exactly
  right: confirmed the real MIS OU has a real `OU=Computers,OU=MIS,...`
  child, and that child has real sub-OUs including `OU=Mobile` -- the
  example is a genuinely real, live OU, not hypothetical. Checked 3
  other real departments (Tax Commissioner, Sheriff, Tax Assessors)
  directly and confirmed all of them also have "Computers" as a
  literal, standard direct child OU, giving confidence this is a
  consistent convention worth building against, not a one-off for MIS.
- Implementation: `Resolve-MintDeviceAdLocation` gained a new
  `ComputersSubfolder` output. After resolving the existing
  `DepartmentGroupFolder` (unchanged), the DN part immediately below
  the department OU is checked for a literal "OU=Computers" match; if
  found, and there are one or more additional OU parts between the
  computer's own CN and that Computers OU, those parts are collected
  (root-to-leaf order, "/"-joined for more than one level deep) into
  `ComputersSubfolder`. If a department's real structure doesn't
  literally have "Computers" as its direct child, this whole block
  silently no-ops and the display falls back to the plain department
  name, exactly as before -- no new failure mode for a department with
  a different structure. `Tab.Search.ps1`'s Check AD click handler
  appends a " - Subfolder" suffix to the department text only when
  `ComputersSubfolder` is non-empty.
- Tests/validation performed: both changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New
  `mint_ad_department_subfolder_test.ps1` (9 of 9 passing): direct real
  live `Resolve-MintDeviceAdLocation` calls against two real known
  devices (a real device in the real `MIS/Computers/Mobile` subfolder
  correctly reports `ComputersSubfolder=Mobile`; a real device directly
  in `MIS/Computers` correctly reports an empty `ComputersSubfolder`,
  unchanged), plus a full real end-to-end reproduction through the
  actual Search and Manage grid and the real Check AD button click,
  confirming the displayed text is exactly "Department: MIS - Mobile"
  for the subfolder case and plain "Department: MIS" for the
  non-subfolder case -- matching Jeremy's example exactly.
- Remaining risks or human decisions: Jeremy has not yet personally
  used this against the real tool himself. Only a single level of
  subfolder nesting was available to test against live (Mobile); deeper
  nesting is handled by the same general "/"-joining logic but is
  unverified against any real multi-level example, since none currently
  exists in the real AD structure.

### 2026-07-29 - Claude (Batch Extract was silently writing real Manufacturer/Model text into Group Tag/Assigned User -- 126 of 384 real Hash Library files already affected -- D-074)

- Files reviewed: Jeremy's report, verbatim: "I believe the batch
  extract is adding manufacturers and models to the extracted hash
  files. MJ0L3BPR was a new file and it has those values showing up in
  the group tag and assigned user categories (respectively) under
  Search and Manage."
- Files changed: `Modules\Core.Csv.ps1` (v1.2.0 -> v1.3.0),
  `Modules\Tab.Extract.ps1` (v2.5.0 -> v2.6.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-074, full detail
  there).
- Investigation: read the real extracted file for serial MJ0L3BPR
  directly rather than assuming either a MINT bug or a source-data
  problem -- confirmed its on-disk Group Tag/Assigned User were
  literally `LENOVO`/`11T300C0US` (a manufacturer name and a real
  Lenovo machine-type code, not any real Group Tag or Assigned User
  value). Traced the write path and found it correct -- it faithfully
  writes whatever `RowPlan.GroupTag`/`.AssignedUser` already contain,
  which trace straight back to `Read-MintVendorBatchFile`'s raw per-row
  parse of the SOURCE batch file. Read the real source file
  ("AllAutopilotHashes - Copy.csv") directly: its real header is
  "Device Serial Number,Windows Product ID,Hardware Hash,Manufacturer
  Name,Device Model" -- not Group Tag/Assigned User at all. This is a
  genuinely different vendor export shape (a raw Autopilot registration
  export carrying informational Manufacturer/Model columns), and
  `Read-MintVendorBatchFile`'s old purely-positional read never checked
  what the header actually said before treating columns 4/5 as Group
  Tag/Assigned User -- so every extraction from this file silently
  wrote its real Manufacturer Name/Device Model text into the canonical
  output's Group Tag/Assigned User fields. Given the severity, scanned
  the entire real live Hash Library (384 real CSV files) for this exact
  corruption signature (Group Tag exactly equal to a known manufacturer
  brand name) BEFORE writing any code: 126 of 384 real files are
  already affected, including old files (ThinkPad T14 Gen 1, T470,
  T480, T490) that clearly predate this session by a long margin.
- Implementation: `Read-MintVendorBatchFile` now examines the header
  row's own column 4/5 text (only possible when a real header row is
  present) and accepts it as genuinely Group Tag/Assigned User only if
  column 4 contains "group" (case-insensitive) or is blank, and column
  5 contains "assign" or "user" or is blank. When either check fails,
  both columns are forced blank for every row in that file and a new
  `ColumnMappingWarning` string is set, naming the actual header text
  found. A headerless batch file cannot be checked this way and is
  unaffected -- still assumed to follow the canonical positional
  convention. Batch Extract's Process File handler shows a real
  MessageBox (not just status text) when `ColumnMappingWarning` is set.
- Tests/validation performed: both changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New assertions in
  `mint_extract_phase1_test.ps1` (45 of 45 total passing): a genuine
  Group Tag/Assigned User header produces no warning; the real
  "Manufacturer Name"/"Device Model" header shape produces a warning
  and leaves both fields blank while the serial itself still reads
  correctly; a headerless batch file is unaffected (regression); a
  case/spacing header variant is still correctly recognized, no
  false-positive warning (regression); and a REAL end-to-end read of
  the actual production file confirms it is detected as mismatched and
  that all 158 of its real rows now have genuinely blank Group
  Tag/Assigned User instead of the previous Manufacturer/Model leakage.
- Remaining risks or human decisions: **the 126 real files already
  carrying this corruption in the live Hash Library are NOT touched by
  this fix** -- this is a code fix for future extractions only. Jeremy
  needs to decide how to remediate the already-affected files (MINT has
  no way to recover what the real correct values should have been from
  the corrupted state alone). Claude will not modify any of these 126
  production files without Jeremy's explicit direction. The full file
  list was captured during investigation and can be provided on
  request.

### 2026-07-29 - Claude (Getac warranty-end date parsing failed on a highlighted/expired date; ReviewStaging rows now promote once manually classified -- D-073)

- Files reviewed: Jeremy's report, verbatim, after an initial serial-
  number mixup he corrected mid-message: "RMC03B0199 is a GETAC B360
  (Gen 1, but it doesn't have that listed as part of the model, the
  'Gen #' part doesn't come in till Gen 2). There is no folder for it,
  but the regular B360 is listed in the models.csv, and the GETAC
  warranty site lists it as a regular B360 as well. When I clicked the
  'Create Folders' button, it did not create the regular 'GETAC B360'
  folder."
- Files changed: `Modules\Core.VendorLookup.ps1` (v1.4.0 -> v1.5.0),
  `Modules\Tab.Extract.ps1` (v2.4.0 -> v2.5.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-073, full detail there).
- Investigation: rather than assume either side of the discrepancy,
  re-verified live -- fetched the real raw HTML for serial RMC03B0199
  directly. Confirmed Jeremy exactly: the model cell is plainly
  `<span>B360</span>`, no Gen suffix. But the real parsed result via
  `Get-MintGetacWarrantyRecord` was `Found=False` -- a genuine parsing
  bug. This device's warranty expired 2022-Dec-15, and Getac's site
  wraps an expired/highlighted date in
  `<span class="txt-highlight-red">...</span>` -- the original field
  regex's `[^<]+` capture cannot cross into a nested tag, so once it
  consumed the whitespace before the nested span, the required literal
  `</div>` failed to match immediately after (a `<span...>` came next
  instead), silently failing the ENTIRE match, not just the date field.
  A device Getac's site genuinely recognizes was therefore reported as
  not found at all, landing in the generic ReviewStaging bucket with no
  Manufacturer/Model ever populated. Separately, tracing what happens
  once an operator manually classifies such a row (possible since D-072
  widened editing) surfaced a second, related gap: `New-MintExtractMissingFolders`,
  `Find-MintExtractDuplicateConflicts`, and `Invoke-MintExtractWriteRows`
  all special-case `Status -eq 'ReviewStaging'` on the assumption it
  ALWAYS means "goes to the flat Review Staging area" -- true before
  D-072, no longer guaranteed once its fields can be edited (which
  redirects `DestinationPath` to a real per-model folder while leaving
  Status untouched). This is the literal mechanism behind "Create
  Folders did nothing": the folder-creation function excludes any row
  whose Status isn't ReadyToExtract or NeedsFolderReview, silently
  skipping an edited-but-still-ReviewStaging-labeled row even though its
  DestinationPath had already been correctly recomputed.
- Implementation: the field regex changed from
  `<div class="col">(?<warrantyEnd>[^<]+)</div>` to
  `<div class="col">(?<warrantyEndBlock>[\s\S]*?)</div>` (captures the
  entire inner content up to the div's own closing tag), with any inner
  tags stripped afterward in code rather than special-casing the one
  observed wrapper class -- handles the plain-text case and any current
  or future highlight/styling wrapper uniformly. New
  `Update-MintExtractReviewStagingPromotion` is called from both the
  `CellEndEdit` handler and the Batch Edit apply loop: promotes Status
  from ReviewStaging to NeedsFolderReview only once DestinationPath is
  genuinely non-null, clearing the stale "not found" Detail text.
  Fixing the Status itself means the three downstream functions already
  handle NeedsFolderReview correctly with zero further changes -- a
  single-point fix rather than patching three call sites. `CellEndEdit`
  also now live-updates the grid's own Status cell and, when promotion
  changes the status, refreshes the top summary line.
- Tests/validation performed: both changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New
  `mint_getac_warranty_html_parse_test.ps1` (9 of 9 passing): a
  deterministic offline test against the exact real raw HTML captured
  live from RMC03B0199, a regression check that the ORIGINAL plain-text
  shape still works unaffected, and a REAL LIVE end-to-end call
  confirming `Get-MintGetacWarrantyRecord -SerialNumber 'RMC03B0199'`
  now returns `Found=True`/`ModelName=B360` (was `Found=False` before).
  A real classification run confirms RMC03B0199 now resolves straight
  to `ReadyToExtract` with the correct real destination folder -- no
  manual operator intervention needed at all for this specific device.
  New `mint_extract_reviewstaging_promotion_test.ps1` (14 of 14
  passing): direct unit tests of the promotion function plus a full
  real end-to-end reproduction through the actual grid (real
  BeginEdit/EditingControl.Text/EndEdit cell edits, matching Jeremy's
  exact scenario) proving the Status promotes, the grid's Status cell
  and summary line both live-update correctly, and -- the literal
  reported bug -- clicking Create Folders Now afterward genuinely
  creates the real "Getac B360" folder on disk. Full regression battery
  re-run across all 30 suites.
- Remaining risks or human decisions: Jeremy has not yet personally
  re-run the real batch file himself against this specific fix. The
  tag-stripping approach is deliberately general (strips ANY inner tag)
  rather than matching only the one highlight class observed, so it
  should already tolerate other Getac highlight/styling variants
  without a further fix -- but this generalization itself is unverified
  against any OTHER real highlighted-date shape, since only the
  expired-warranty case was available to test against live.

### 2026-07-29 - Claude (Batch Extract: editing widened to any non-terminal row, real Manufacturer/Model dropdowns, Review Staging relocated -- D-072)

- Files reviewed: Jeremy's report, verbatim, four bullets in one
  message: "Batch Extract: Device Type dropdown doesn't work." / "Batch
  Extract: Batch Edit button remains locked out even when multiple
  files are selected." / "Batch Extract: Manufacturer and Model should
  have a dropdown menu that populates via newly created file
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation
  Tool\variables\manufacturer.csv`, with `Manufacturer` as a header for
  Manufacturer column and the `Model Name` column of the
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation
  Tool\variables\models.csv` file for the Model column." / "Batch
  Extract: Review Staging folder should be located at:
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Review
  Staging`."
- Files changed: `Modules\Tab.Extract.ps1` (v2.3.0 -> v2.4.0),
  `Modules\Core.Inventory.ps1` (v1.1.0 -> v1.2.0), `MIS Inventory
  Navigation Tool.ps1` (v1.3.0 -> v1.4.0); this handoff and the matching
  `AI-Project-Plan.md` (new Decision D-072, full detail there).
- Investigation: extensive static review of reports 1/2 (per-cell vs.
  per-column ReadOnly precedence, EditingControlShowing/CellBeginEdit/
  DataError handler gaps, ComboBox Items population, DeviceTypeChoice
  default values) found no code defect -- a real isolated precedence
  test confirmed setting a cell's own ReadOnly=false after the column's
  ReadOnly=true DOES work correctly (BeginEdit succeeds, edit commits).
  Rather than keep guessing at an invisible failure mode, asked Jeremy
  two clarifying questions instead of a third or fourth static-analysis
  pass: what exactly happens when the Device Type dropdown is clicked
  (answer: "the arrow is visible, there is just no action at all when I
  click on it"), and whether the Batch Edit selection was homogeneous
  NeedsFolderReview or mixed (answer: "not sure"). Jeremy's first answer
  is the exact signature of a read-only DataGridViewComboBoxCell in
  WinForms: it still paints its dropdown arrow glyph, but silently
  refuses to enter edit mode on click -- no visible reaction at all,
  indistinguishable from "broken" to an operator unaware a per-row
  restriction exists. Combined with "not sure" on report 2, the real
  explanation for both reports is real interaction with ReadyToExtract
  rows (now the overwhelming majority of any real batch after
  D-069/D-070/D-071's fixes -- 123 of 158 rows in Jeremy's real file),
  correctly read-only/ineligible under the OLD NeedsFolderReview-only
  restriction. A third clarifying question confirmed Jeremy wants
  editing available on any row, not just to complete a blank
  NeedsFolderReview one but also to correct an already-matched row.
- Implementation: `$script:MintExtractTerminalStatuses` (the 5
  post-Extract statuses where the file is already written) and
  `Test-MintExtractRowPlanEditable -RowPlan` replace the
  `-eq 'NeedsFolderReview'` check everywhere it gated editability
  (`Update-MintExtractGrid`'s per-cell ReadOnly toggle, the
  `CellEndEdit` handler's guard, `Update-MintExtractActionButtonStates`'s
  Batch Edit gating, the Batch Edit button's eligible-rows filter). New
  `Update-MintExtractDropdownColumnChoices -RowPlans` populates the
  results grid's Manufacturer/Model ComboBoxColumn Items with a blank
  entry, every configured choice, AND every value already present
  across the current RowPlans not in those configured lists -- mirrors
  Search and Manage's established `Update-MintSearchGroupTagColumnChoices`
  pattern exactly, since a DataGridViewComboBoxColumn cell throws a
  DataError when asked to display a value not in its own Items list.
  Manufacturer/Model columns changed from DataGridViewTextBoxColumn to
  DataGridViewComboBoxColumn, typeable (unlike Device Type, which stays
  a locked DropDownList) via a new EditingControlShowing handler that
  unlocks DropDownStyle=DropDown and wires TextChanged ->
  NotifyCurrentCellDirty -- confirmed via Search's own Group Tag column
  fix doc comment that DropDownStyle=DropDown alone is NOT sufficient; a
  DataGridViewComboBoxEditingControl's dirty-notification is tied to
  SelectedIndexChanged and does not reliably fire for free-typed text
  alone, so without this wiring a free-typed edit silently reverts on
  commit. New DataError handler as a defensive safety net, also
  mirroring Search's precedent. `Core.Inventory.ps1` gained
  `Get-MintManufacturerMapInternal` (header-keyed via
  Read-MintVariableCsv, since manufacturer.csv HAS a header row --
  confirmed against the real live file -- unlike grouptags.csv's
  headerless convention) and `Get-MintManufacturerChoices`.
  `Show-MintExtractBatchEditDialog`'s Manufacturer/Model TextBoxes
  became ComboBoxes populated from the same choice lists. Entry script:
  `ReviewStagingRoot` moved from under DataRoot to under
  HashInventoryRoot, confirmed directly (not assumed) that neither the
  old nor new location had any existing real data before moving -- a
  clean path change, no migration needed.
- Tests/validation performed: all three changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. Two existing test suites
  had assertions that directly encoded the OLD narrower restriction and
  were UPDATED (not left coincidentally passing) to assert the new
  behavior: `mint_extract_phase2_test.ps1` (added a genuinely-terminal
  Extracted row to prove the one remaining exclusion still works, 24 of
  24 passing) and `mint_extract_followups_test.ps1` (flipped the mixed-
  selection gating assertion, added a terminal-row-in-selection
  exclusion check, updated the real Batch Edit dialog auto-answer logic
  for 3 ComboBoxes instead of 1 combo + 2 textboxes, 34 of 34 passing).
  New `mint_extract_manufacturer_model_dropdown_test.ps1` (16 of 16
  passing): real manufacturer.csv reading, real ComboBoxColumn type and
  Items-list checks (blank + configured + in-use union, both columns), a
  real free-typed edit through the actual grid for both Manufacturer and
  Model proving the TextChanged/NotifyCurrentCellDirty fix genuinely
  works rather than silently reverting, a repopulate-after-free-typed-
  edit check proving no DataError crash, and a real Batch Edit dialog
  click-through confirming the Manufacturer ComboBox is genuinely
  DropDownStyle=DropDown and populated from manufacturer.csv. First full
  regression battery re-run surfaced a genuine self-inflicted
  regression: the new Get-MintManufacturerMapInternal calls
  Read-MintVariableCsv directly and unconditionally (mirroring
  Get-MintModelMapInternal's own established pattern), but
  ManufacturerListFile is a brand-new path key -- any pre-existing test
  whose $script:Paths hashtable didn't already define it crashed at
  parameter-binding time ($null cannot bind to a mandatory [string]
  parameter), breaking Initialize-MintInventoryIndex entirely. Fixed by
  adding ManufacturerListFile to 18 affected pre-existing test files
  (automated, then verified by re-parsing all 18). A second, narrower
  issue then surfaced in exactly 2 of those 18
  (mint_summary_wording_test.ps1, mint_dynamic_summary_test.ps1): both
  assert exact scan-warning wording, and the newly added path (pointing
  nowhere real in their sandboxes) correctly produced a new "file not
  found" Issue their assertions didn't expect -- fixed by creating a
  real minimal manufacturer.csv fixture in both. Full regression battery
  re-run three times total across this investigation; final run clean
  except this project's already-documented pre-existing SendKeys/
  window-focus flakiness (confirmed via isolated re-runs).
- Remaining risks or human decisions: Jeremy has not yet personally
  used any of these four changes against the real production file
  himself at the time of writing -- the verification above is
  real-sandboxed-data reproduction of his exact real scenario (matching
  the composition of his real batch file), not his own hands-on
  confirmation. The Model dropdown is a flat list of every models.csv
  Model Name, not filtered by the row's own Manufacturer selection,
  matching Jeremy's literal request; cross-filtering was not requested
  and was deliberately not added as scope creep.

### 2026-07-28 - Claude (Getac model names never matched models.csv at all: a bare "G" + number generation suffix, corrected by Jeremy -- D-071)

- Files reviewed: Jeremy's message directly correcting D-070's own
  "Remaining risks" note: "The Getac B360 Gen 2 and Gen 3 do exist in
  models.csv." D-070 had assumed, without checking, that both remaining
  real Getac NeedsFolderReview devices were genuinely unmapped models,
  same as the real Legion T5 30AGB10 gap next to them in the same list
  -- an unverified assumption that violated this project's own "confirm
  against real data, don't assume" practice, caught only because Jeremy
  checked it himself.
- Files changed: `Modules\Core.VendorLookup.ps1` (v1.3.0 -> v1.4.0);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-071, full detail there).
- Investigation: re-verified directly against the real models.csv file:
  confirmed it has `B360 Gen 2` and `B360 Gen 3` rows (Manufacturer
  Getac, Device Type GETAC), alongside `A140`, `A140 Gen 2`, `B360`,
  `F120`, `V120` -- the file's own convention spells generations out
  with a space and the word "Gen". A real live lookup for the batch's 2
  actual Getac serials (RQ303B0237, RR803B1349) showed
  `Get-MintGetacWarrantyRecord`'s raw `ModelName` is literally
  `B360G2`/`B360G3` -- the generation number concatenated directly onto
  the base model with a bare "G", no space, no word "Gen" at all.
  Unlike the Lenovo provider (`ConvertTo-MintLenovoModelName`, D-053/
  D-069/D-070), the Getac provider had never had ANY model-name
  normalization applied since it was first built -- the code took the
  raw page text completely as-is (`.Trim()` only). This means every
  Getac model with a generation number has never been able to match
  models.csv through this pipeline, not just B360.
- Implementation: new `ConvertTo-MintGetacModelName -ProductName`
  (`Core.VendorLookup.ps1`, Getac provider region): matches a trailing
  "G" immediately followed by digits with no preceding space, and
  reformats it as "`<base>` Gen `<digits>`"; anything without that exact
  trailing shape (plain models like B360/F120/V120/A140, or already-
  correctly-formatted text) passes through completely unchanged. Wired
  into `Get-MintGetacWarrantyRecord` in place of the old bare `.Trim()`.
- Tests/validation performed: `Core.VendorLookup.ps1` parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New unit test suite
  `mint_getac_modelname_test.ps1` (10 of 10 passing): both real raw
  shapes, a same-shape check on a different base model (A140, to confirm
  the fix generalizes rather than being hardcoded to B360 alone), 4
  no-generation-suffix regression checks, an already-formatted-text
  no-op check, and null/blank-input edge cases. Real end-to-end
  reclassification re-run against both real serials: both now resolve
  to `Status=ReadyToExtract` with the correct real destination folder.
  Full real 158-row batch re-classified end-to-end: NeedsFolderReview
  dropped from 4 to 2, and the sole remaining row is the genuinely-
  unmapped Legion T5 30AGB10 (confirmed directly against models.csv,
  not assumed this time). Full 26-suite regression battery re-run (25
  pre-existing suites plus this decision's own new suite).
- Remaining risks or human decisions: Legion T5 30AGB10 (x2 real
  devices) is the one remaining real NeedsFolderReview case and IS
  genuinely absent from models.csv -- Jeremy can add it via the Edit
  Model Folders dialog (D-066 Item 6) whenever ready. The A140 Gen 2
  generalization is un-guessed (no real A140 Gen 2 serial existed in
  this batch to confirm end-to-end), though the underlying raw-text
  pattern and fix logic are the same mechanism already confirmed twice
  (B360 Gen 2 and Gen 3). Jeremy has not yet personally re-run the real
  batch file himself against this specific fix at the time of writing.

### 2026-07-28 - Claude (Two more real Lenovo product-name shapes found by re-testing D-069 against the full real batch -- D-070)

- Files reviewed: the full real 158-row batch file's classification
  results after D-069 landed (NeedsFolderReview count unexpectedly still
  19, unchanged), and `Core.VendorLookup.ps1`'s `ConvertTo-
  MintLenovoModelName` (the D-069 fix point).
- Files changed: `Modules\Core.VendorLookup.ps1` (v1.2.0 -> v1.3.0);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-070, full detail there).
- Investigation: following this project's own established practice of
  re-verifying a fix's blast radius against the full real dataset rather
  than declaring done after checking only the originally-reported
  serials, re-ran full real classification against the entire real
  158-row batch file after D-069 landed. The aggregate NeedsFolderReview
  breakdown revealed 3 more distinct Lenovo model groups still stuck,
  despite models.csv already having clean matching rows for all of them
  (confirmed directly against the real file): "ThinkPad T14 Gen 6
  Laptops" (x8), "ThinkPad T14 Gen 5 Laptops" (x3), "ThinkPad T16 Gen 4
  Laptops" (x3), and "Lenovo Legion T5 26IAB7" (x1). Instrumented
  `ConvertTo-MintLenovoModelName` again to capture real raw text: real
  serial PF5Z6XVR (ThinkPad T14 Gen 6) returns "T14 Gen 6 (Type 21QC,
  21QD) Laptops (ThinkPad) - Type 21QC" -- PLURAL "Laptops", not
  "Laptop". The first brand-parenthetical pattern's keyword list only
  matched the exact singular word, so the plural text fell through
  unmatched into the second, more permissive pattern (no keyword filter
  at all -- just "anything before (Brand)"), which happily captured
  "T14 Gen 6 Laptops" as the model text, leaving the stray plural word
  embedded in the final result. Separately, real serial S5008BWC (Legion
  T5 26IAB7) returns "Lenovo Legion T5 26IAB7 - Type 90SU" -- a redundant
  leading "Lenovo " word with no brand-parenthetical at all (Legion is a
  Lenovo sub-brand, correctly not in the ThinkCentre/ThinkStation/
  ThinkPad pattern list), which survived the existing dash-suffix strip
  untouched since nothing targeted a leading brand word. Cross-checked
  the remaining NeedsFolderReview rows after this full-batch run (Legion
  T5 30AGB10 x2, Getac B360G2/B360G3 x1 each) directly against the real
  models.csv: none of these 4 have a matching row at all, confirming
  they are genuinely new/unmapped models, not a further matching bug --
  correctly left as NeedsFolderReview.
- Implementation: `ConvertTo-MintLenovoModelName` gained an
  unconditional `-replace '^Lenovo\s+', ''` as the very first cleanup
  step (before the D-069 "(Type ...)" strip), and the first brand-
  parenthetical pattern's device-type keyword group changed from
  `(Desktop|Tiny|Tower|Workstation|Notebook|Laptop)` to
  `(Desktop|Tiny|Tower|Workstation|Notebook|Laptop)s?`.
- Tests/validation performed: `Core.VendorLookup.ps1` parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New unit test assertions in
  `mint_lenovo_modelname_type_test.ps1` (15 of 15 passing total) cover
  both new shapes directly against the exact real raw strings captured
  from Jeremy's real batch file, plus the genuinely-unmapped "Legion T5
  30AGB10" case (confirms the dash-suffix strip alone, with no Lenovo
  prefix present, still works and is correctly left unmatched). Full
  real 158-row batch re-classified end-to-end: NeedsFolderReview dropped
  from 19 to 4, and the remaining 4 confirmed genuinely absent from
  models.csv. Full 25-suite regression battery re-run (24 pre-existing
  suites plus this decision's own new suite): all passed except this
  project's already-documented pre-existing SendKeys/window-focus
  flakiness -- `mint_round2_test.ps1` timed out (documented pattern),
  and two single assertions failed only within the long battery run
  (`mint_inline_edit_test.ps1`'s GroupTag free-typed-value assertion,
  already documented as a known-flaky assertion in D-068's own evidence;
  `mint_copy_serial_test.ps1`'s contiguous-3-row assertion) -- both
  re-ran clean when re-run in isolation immediately afterward, confirming
  neither is a real regression (neither touches `Core.VendorLookup.ps1`
  or any code path this fix touches).
- Remaining risks or human decisions: the 4 remaining real
  NeedsFolderReview devices (Legion T5 30AGB10 x2, Getac B360G2/B360G3
  x1 each) are genuinely new models with no models.csv row yet -- Jeremy
  can add them via the Edit Model Folders dialog (D-066 Item 6) directly
  from the Batch Extract tab. Jeremy has not yet personally re-run the
  real batch file himself against this specific fix at the time of
  writing.

### 2026-07-28 - Claude (Real Lenovo model/folder matching bug: an embedded mid-string "(Type ...)" parenthetical defeated a first-pass fix -- D-069)

- Files reviewed: Jeremy's report, verbatim, sent after confirming
  D-068's fix worked: "I've confirmed it is working. Now I am seeing
  issues with Model and folder matchups. For example, the batch file
  we've been working on this whole time has several cases of 'ThinkPad
  T14 Gen 2 (Type 20W0, 20W1)' showing up, but I know I already have a
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Hardware
  Hash Files\Laptops\Lenovo ThinkPad T14 Gen 2` folder, as well as the
  ThinkPad T14 Gen 2 already defined in `\\hallcounty\filestore\mis\MIS\
  Intune\MIS Inventory Navagation Tool\variables\models.csv`."
- Files changed: `Modules\Core.VendorLookup.ps1` (v1.1.0 -> v1.2.0);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-069, full detail there).
- Investigation: a real live warranty lookup for serial PF469VSC (a real
  ThinkPad T14 Gen 2 from Jeremy's real batch file) confirmed the raw
  `ProductName` text and led to a first-pass fix that stripped a
  trailing "(Type XXXX[, YYYY...])" parenthetical, verified correct
  against an isolated unit test using an assumed simpler shape. A
  follow-up real end-to-end reclassification test against the actual
  production pipeline (same 4 real serials) showed the fix had NOT taken
  effect: all 4 rows still showed the untrimmed model text and
  `Status=NeedsFolderReview`, matching the original bug exactly.
  Instrumenting `ConvertTo-MintLenovoModelName` to log its real raw
  input revealed why: the real raw text is "T14 Gen 2 (Type 20W0, 20W1)
  Laptop (ThinkPad) - Type 20W0" -- the "(Type ...)" segment sits
  MID-STRING, not just trailing, so the function's existing brand-
  parenthetical early-return pattern (which runs before the newly-added,
  too-late-positioned strip) was forced to swallow it whole inside its
  own lazy model capture in order to reach the required "Laptop
  (ThinkPad)" text later in the string. This proved that "passes in
  isolation" is not sufficient evidence a fix works without also
  re-testing against the real end-to-end code path -- the isolated
  test's assumed input shape did not match the real pipeline's actual
  raw text.
- Implementation: moved the "(Type ...)" strip to run first,
  unconditionally, on the raw trimmed name, before either existing
  brand-parenthetical pattern is evaluated. Fixes both the real
  embedded-mid-string shape and the simpler trailing-only shape in one
  place; cannot false-positive against either existing pattern (both
  require either the bare `(ThinkCentre|ThinkStation|ThinkPad)`
  parenthetical or a dash "- Type XXXX" suffix, neither of which begins
  with the literal text "(Type ").
- Tests/validation performed: `Core.VendorLookup.ps1` parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New unit test assertions in
  `mint_lenovo_modelname_type_test.ps1` cover the real embedded-mid-
  string shape directly (not just the simpler assumed shape) plus
  regression checks of both pre-existing working patterns. Real
  end-to-end reclassification re-run against the same 4 real serials
  (PF469VSC/PF40NJHB/PF4134X4/PF412KFQ): all 4 now resolve to
  `Status=ReadyToExtract` with the correct real destination folder,
  matching the folder Jeremy said already exists.
- Remaining risks or human decisions: none for this specific shape --
  see D-070 above, found by re-testing this same fix against the FULL
  real batch file rather than just the originally-reported serials.

### 2026-07-28 - Claude (The real cause of "only 1 entry": SelectionChanged firing mid-Rows.Add() before a Tag is set -- D-068)

- Files reviewed: Jeremy's report, verbatim, sent twice identically in
  one message, AFTER D-067's progress-feedback fix had already
  shipped: "It's still only showing one entry in the batch processing
  on `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Autopilot
  Hash\Hardware Hash List\Master\AllAutopilotHashes - Copy.csv`". This
  proved D-067's own fix, while genuinely correct for the "looks
  frozen" perception problem, was not sufficient on its own -- a
  second, separate, deeper bug remained.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.2.0 ->
  v1.3.0), `Modules\Tab.Extract.ps1` (v2.2.0 -> v2.3.0); this handoff
  and the matching `AI-Project-Plan.md` (new Decision D-068, full
  detail there).
- Investigation, exhaustive and evidence-based, not guessed at any
  point: first asked Jeremy two clarifying questions (did he actually
  restart the app before trying again -- yes, fully closed and
  relaunched, ruling out a stale in-memory process; and what exactly
  did he observe -- "I can see it processing 158 entries based off the
  please wait window, but once that is complete (no hangups) it only
  shows 1 entry," confirming the progress feedback WAS working and
  visible, and that classification itself completes without hanging).
  Ran the real 158-row file through the real classification pipeline
  four separate ways to isolate exactly where the real app diverged
  from every earlier test: (1) headless, no UI at all -- 158/158,
  clean; (2) through a simplified single-tab UI stack with sandboxed
  models.csv -- 158/158, clean; (3) the same simplified UI stack but
  with Jeremy's REAL production models.csv/hash library (read-only,
  83 real models, 253 real hash files) -- 158/158, clean; (4) manually
  calling classification and grid-populate directly (bypassing the
  real button) through the REAL `New-MintMainForm` with real data --
  also clean. Only reproducing the EXACT real sequence -- the REAL
  `New-MintMainForm` (properly sized 1100x700 window, all 6 real
  tabs), the Batch Extract tab genuinely SELECTED (a button on a
  non-selected TabPage is not `Visible`, and `Button.PerformClick()`
  checks `Control.CanSelect` internally, so it silently no-ops on an
  unselected tab -- found and fixed as a TEST-harness gap first, not a
  product bug), and the REAL `Button.PerformClick()` -- reproduced the
  crash. Confirmed deterministic, not a race: re-ran the identical
  test 3 times, same exact failure every time:
  `Exception calling "Add" with "8" argument(s): "The property
  'Status' cannot be found on this object."`, with `RowPlans.Count`
  correctly at 158 but the grid stuck at exactly 1 row.
- A closure-safety theory was tested and ruled out: the D-067
  `-ProgressCallback` scriptblock closed over a local `$waitWindow`
  belonging to the OUTER `$processFileButton.Add_Click` scriptblock --
  itself a delayed WinForms handler, not a regular function, subtly
  different from this project's own established "same call stack"
  safe-closure exception (built for closures defined and invoked
  entirely within a real FUNCTION's frame). Fixed defensively
  regardless (a new `$script:MintExtractState.CurrentWaitWindow` state
  slot instead of the closure, both call sites) since it brings this
  code in line with the project's own no-closures-over-locals rule --
  but re-testing after this fix reproduced the EXACT SAME crash,
  proving it was not the actual cause.
- The real cause was found by instrumenting `Update-MintExtractGrid`'s
  own `Rows.Add(...)` loop line-by-line (a temporary copy of its exact
  logic with a try/catch around each individual statement) against the
  real crash scenario, and inspecting the FULL exception object rather
  than just its top-level message: the inner exception was a
  `System.Management.Automation.CmdletInvocationException` -- direct
  proof that a PowerShell event handler, not plain .NET code, was
  firing from INSIDE the `Rows.Add()` call itself. WinForms auto-
  selects the FIRST row added to a currently-empty, visible/active
  `DataGridView` as a side effect of `Add()` -- this fires the grid's
  own `SelectionChanged` handler
  (`Update-MintExtractActionButtonStates` ->
  `Get-MintGridSelectedRowsInVisualOrder`) BEFORE
  `Update-MintExtractGrid`'s own very next statement
  (`$addedRow.Tag = $rowPlan`) has run -- so the just-added row's
  `.Tag` was still `$null` at that instant.
  `Get-MintGridSelectedRowsInVisualOrder` returned that `$null`, and
  `Update-MintExtractActionButtonStates` then evaluated `$_.Status` on
  it, which `Set-StrictMode -Version Latest` rejects with exactly the
  observed message. This is precisely why every earlier D-066/D-067
  test missed it: none of them had BOTH a real, visible/selected grid
  AND real classified data (specifically real `ReadyToExtract` rows,
  which only exist once a real `models.csv` with real matches is
  loaded) flowing through the real button-click path at the same
  time.
- Implementation: `Get-MintGridSelectedRowsInVisualOrder` (entry
  script, shared by Search and Manage and Batch Extract both) now
  skips any selected row whose `.Tag` is `$null`. Fixed at this single
  shared source rather than patched in either caller, since a `$null`
  Tag is never a genuine selected device from any consumer's
  perspective.
- Tests/validation performed: both changed files parse with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New fast, deterministic
  unit test (`mint_gridselection_nulltag_test.ps1`, 6 of 6 assertions)
  directly reproduces the exact null-Tag-during-populate window
  (a row added and selected but not yet Tagged, matching
  `Update-MintExtractGrid`'s own real sequence) without needing the
  slow real-network scenario -- confirms both that a null-Tag row is
  correctly excluded AND that a genuinely-tagged row is still
  correctly included once its Tag is set, proving this is a real
  regression test rather than a coincidental pass. The exact real
  crash reproduction (real `New-MintMainForm`, real production
  `models.csv`/hash library, real `ProcessFileButton.PerformClick()`,
  Batch Extract tab genuinely selected) was re-run three times after
  the fix; all three now show 158 of 158 rows with the correct summary
  text ("158 rows found -- 78 ready to extract -- 47 need folder
  review -- 6 sent to Review Staging -- 27 skipped"), matching the
  real classification distribution exactly. Full regression battery
  re-run across all 24 suites; every suite passed except this
  project's already-documented pre-existing SendKeys/window-focus
  flakiness (`mint_inline_edit_test.ps1`'s one known flaky assertion,
  plus two suites -- `mint_round2_test.ps1` and
  `mint_remove_assigneduser_batch_test.ps1` -- that hit a timeout only
  when run as part of the long sequential battery but passed cleanly
  every time when re-run in isolation immediately afterward; a third
  suite hit a transient file-lock error from a concurrently-running
  background diagnostic process, also confirmed clean in isolation).
- Remaining risks or human decisions: Jeremy has not yet personally
  re-run the real file himself against this specific fix -- the
  verification above is automated reproduction of his exact real
  scenario (same file, same real production data, same real button
  click path), not his own hands-on confirmation.

### 2026-07-28 - Claude (Grid columns self-heal regardless of startup timing; Batch Extract shows live classification progress -- D-067)

- Files reviewed: Jeremy's real first-use report against this same
  session's D-066 grid-resize work, verbatim: "Attempted to process
  file `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Autopilot
  Hash\Hardware Hash List\Master\AllAutopilotHashes - Copy.csv` in the
  batch section, it only came up with 1 entry despite the file being
  quite large. The default size of the colums in the Search and
  Manage field are no longer defaulting to a minimum of the largest
  entry in the field. The size of the columns in Batch Extract are not
  allowing the size to be edited. All grids of this nature ... need to
  operate on this basic assumption: Minimum column width = width of
  the model header, unless there is an entry in that column that is
  wider than the header, then it needs to be the width of the largest
  entry in that column. The columns should not be unlocked, and should
  be editable after this minimum occurs."
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.1.0 ->
  v1.2.0), `Modules\Tab.Extract.ps1` (v2.1.0 -> v2.2.0); this handoff
  and the matching `AI-Project-Plan.md` (new Decision D-067, full
  detail there).
- Investigation, not guesswork: the real production file IS reachable
  from this environment. Read directly: 158 lines (1 header + 157...
  actually 158 data rows), no BOM, 1560 quote characters (mixed
  quoted/unquoted rows from different export runs over time).
  `Read-MintVendorBatchFile` called directly against the real file
  returns all 158 rows correctly, 0 parse errors, 131 distinct
  normalized serials (17 duplicated). Timed 5 real
  `Resolve-MintWarrantyLookup` calls against real serials from this
  exact file: four completed in 200ms-1.4s, but one
  (`MJ0L3BPQ`) took 61090ms -- almost exactly the provider's own
  60-second HTTP timeout plus a successful retry. Confirmed via a full
  headless classification run (stubbed instant warranty lookups)
  against the real 158-row file that grid population itself is not the
  bug: all 158 RowPlans and all 158 grid rows populate correctly and
  fast (159ms) when lookups are instant.
- Root cause 1 (grid width regression): confirmed by reading the entry
  script's own startup sequence, not assumed -- `New-MintMainForm`
  calls every tab's Init function (`& $initFunctionName -TabPage
  $tabPage`), including `Initialize-SearchTab`'s own unconditional
  final "initial load" call to `Update-MintSearchGrid`, and the entry
  script's OWN established comment confirms `Application.Run()` (and
  therefore the form's real `Show()`/handle creation) only happens
  AFTER `New-MintMainForm` returns. So Search and Manage's very FIRST
  populate of every real session runs before the grid has a real
  window handle. `AutoResizeColumns()` silently no-ops without one,
  and D-066's `Set-MintGridColumnWidthsToContent` still set
  `AutoSizeColumnsMode = None` regardless -- permanently freezing every
  column at its construction-time default (100px) for the whole
  session. Every D-066 test had validated the fit-then-lock logic
  correctly but never caught this, because every one of those test
  harnesses always created and `Show()`'d its own `Form` before ever
  calling the first populate -- unlike the real app. Batch Extract's
  own grid never has an early-populate call site of its own
  (`Update-MintExtractGrid` only ever runs from event handlers well
  after the window is shown), so its "cannot resize" report is fully
  explained by root cause 2 below.
- Root cause 2 ("only 1 entry"): the classification loop
  (`Invoke-MintExtractClassification`) had a deliberate D-065 design
  choice -- "no per-row `DoEvents()` pumping... the UI thread is
  blocked either way, so per-iteration pumping buys nothing." The 61-
  second single-lookup measurement above disproves that assumption for
  a real, large file: with 131 distinct devices, each potentially
  anywhere from ~200ms to 60+ real seconds, and zero progress feedback
  on a fully frozen UI, a genuinely-still-working multi-minute (or
  longer) run is indistinguishable from a hung tool. This most likely
  explains Jeremy's "1 entry" report (checking back on a still-running
  batch too early), though this could not be proven with full
  certainty without reproducing his exact real-time session against
  all 131 real devices (which could plausibly take tens of minutes to
  hours given the measured outlier).
- Implementation: `Set-MintGridColumnWidthsToContent` (entry script)
  now checks `Grid.IsHandleCreated` first; if false, it subscribes to
  the grid's own `HandleCreated` event (reading `$this`, the control
  that actually raised the event, never a closed-over local -- shared
  pitfall P28: a delayed WinForms handler must never close over a
  local from an already-returned function) and returns immediately,
  leaving the grid on its construction-time continuous `AllCells` mode
  until a real handle exists, at which point the SAME function
  re-runs and completes the normal fit-then-lock sequence. This
  self-heals regardless of when the handle actually gets created,
  rather than depending on every call site happening to run after
  `Show()`. Also implements Jeremy's own more precise restated width
  rule: each column's real `DataGridViewColumn.MinimumWidth` (a
  genuine WinForms floor -- clamps manual `.Width` assignment AND
  interactive drag-resize below it, while leaving upward resize free)
  is set to the computed fit-to-content value after every populate,
  with `MinimumWidth` reset to WinForms' own true default (5)
  immediately beforehand every time -- confirmed via a live isolated
  test that without this reset, a stale floor from a PREVIOUS wider-
  content populate blocks a later repopulate with shorter content from
  ever shrinking back down. `Invoke-MintExtractClassification`
  (`Tab.Extract.ps1`) gained an optional `-ProgressCallback` (invoked
  once per row, before that row's own lookup, with
  ProcessedCount/TotalCount/RawSerial) -- kept optional so the function
  stays usable headless. A new `Update-MintWaitWindowMessage` (entry
  script, alongside `Show-MintWaitWindow`/`Close-MintWaitWindow`)
  updates a wait window's visible text and pumps a real repaint via
  `DoEvents()`; `Show-MintWaitWindow` now tags its message `Label` onto
  the returned `Form` so this can find it without any fragile
  `Controls` traversal. Both of Batch Extract's classification call
  sites (Process File, Edit Model Folders's re-classification) wire
  the two together, showing a live "(N of M: SERIAL)" counter. Since a
  pumped UI thread can now process a second click mid-run (impossible
  under the old fully-blocked design), both call sites disable Process
  File/Browse/Edit Model Folders for the duration.
- Tests/validation performed: every changed file parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. New isolated grid-width
  test: 15 of 15 assertions (handle-deferral confirmed via a real
  `Form` not yet `Show()`'d, `MinimumWidth` floor matching the computed
  width, a clamped-shrink attempt genuinely staying at the floor, free
  upward growth, and a repopulate-with-shorter-content case proving
  the floor itself shrinks rather than staying stuck). New real-
  startup-sequence test: extracted the REAL `New-MintMainForm` (and
  its own dependency chain) directly out of the real entry script
  (without dot-sourcing the whole file, which would also run its
  top-level `Application.Run()` block) and called it for real against
  a sandboxed library with a deliberately long Model name -- 6 of 6
  assertions, including confirming the grid genuinely has NO handle
  yet immediately after `New-MintMainForm` returns and is STILL
  correctly sized after `Show()`. Separately re-ran this SAME test
  against the OLD (pre-fix) implementation and confirmed it genuinely
  FAILS (stuck at width 100 both before and after `Show()`) -- proving
  this is a meaningful regression test, not one that would pass either
  way. New progress-feedback test: 12 of 12 assertions, including a
  standalone `-ProgressCallback` check (6 calls, correct 1-of-6
  through 6-of-6 sequence) and a REAL `ProcessFileButton.PerformClick()`
  test using a warranty-lookup stand-in that sleeps 40ms per call and
  records the button's `.Enabled` state on every call, confirming the
  button was disabled for literally every one of the 6 per-row
  lookups and correctly re-enabled afterward (along with Browse/Edit
  Model Folders). Full regression battery re-run across all 23 suites
  (20 pre-existing plus these 3 new ones). Found one real, unrelated
  test-maintenance gap via this run (not a product bug): a fourth test
  file (`mint_extract_item6_test.ps1`, which dot-sources
  `Tab.Extract.ps1` directly, bypassing the entry script) crashed
  because it lacked a local stub for the new `Update-MintWaitWindowMessage`
  -- fixed with the same stub pattern already established repeatedly
  this session for functions promoted into the entry script's shared
  region. Two suites (`mint_round2_test.ps1`,
  `mint_batch_continuation_test.ps1`) intermittently timed out only
  when run back-to-back in the full sequential battery (a pre-existing
  category of SendKeys/window-focus fragility already documented for
  `mint_inline_edit_test.ps1`) but passed cleanly every time when
  re-run in isolation, confirmed 2-3 times each; neither exercises any
  function touched by this decision, ruling out a real regression from
  this work.
- Remaining risks or human decisions: Jeremy has not yet re-run the
  real production file that originally triggered this investigation to
  confirm the progress feedback resolves the "frozen" perception in
  practice against the FULL real 131-distinct-device set (not
  reproduced end-to-end here, since it could plausibly take tens of
  minutes to hours given the measured 61-second single-lookup
  outlier). If real batch runs still feel too slow even with visible
  progress, the next lever would be tuning `Core.VendorLookup.ps1`'s
  HTTP timeout/retry values -- deliberately NOT touched by this
  decision, since changing already-validated vendor-lookup behavior
  without evidence it is itself wrong would be presumptuous.

### 2026-07-28 - Claude (Batch Extract follow-ups: grid resize, Status text, Batch Edit, Copy Serial(s), models.csv editor -- D-066)

- Files reviewed: Jeremy's single message with seven follow-up items
  against the just-shipped D-065 Batch Extract tab (verbatim quoted in
  full in `AI-Project-Plan.md` D-066). Two rounds of clarifying
  questions resolved real ambiguities before implementation: the Batch
  Edit dialog's Destination Path field is a live read-only preview,
  not directly typeable; and item 7 (Lenovo "type" should be ignored)
  needed investigation against the real `models.csv` (Jeremy pointed
  at the T470's 20HD/20HE Model Number aliases) before a second
  question confirmed no code change was actually needed, since
  matching already ignores Model Number/Type entirely and
  `ConvertTo-MintLenovoModelName` already strips a raw Lenovo "Type
  XXXX" suffix.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.0.9 -> v1.1.0,
  two new shared `WINFORMS SHELL` helpers), `Modules\Core.Csv.ps1`
  (v1.1.0 -> v1.2.0, new `Write-MintVariableCsv`), `Modules\Tab.Search.ps1`
  (v1.8.3 -> v1.8.4, grid resize call sites plus a delegate refactor),
  `Modules\Tab.Extract.ps1` (v2.0.0 -> v2.1.0, the majority of the
  diff); this handoff and the matching `AI-Project-Plan.md` (new
  Decision D-066, full detail there).
- Findings accepted, one factual correction reported rather than
  silently complied with: Jeremy's assumption that "duplicate" was the
  only cause a device could show `Skipped` was checked against
  `Resolve-MintExtractRowPlan` and found wrong (a CSV parse error and a
  blank serial ALSO produce `Skipped`, each with different `Detail`
  text) -- implemented three specific sub-labels instead of the single
  "Skipped - Duplicate" Jeremy suggested.
- Implementation: (1) `Set-MintGridColumnWidthsToContent` (entry
  script) replaces continuous `AutoSizeColumnsMode=AllCells` with a
  one-time `AutoResizeColumns()` fit immediately after populate, then
  drops to `None` so the operator can drag-resize afterward; wired
  into `Update-MintExtractGrid` and both Search and Manage grid
  populate functions. A genuinely subtle second bug was caught by a
  FAILING test before this shipped: on a grid still in continuous
  `AllCells` mode, `AutoResizeColumns()` computes and displays the
  right width, but a column's own internal manual-width field is never
  updated while continuous auto-sizing is active, so switching to
  `None` immediately afterward silently reverted every column back to
  its stale construction-time default (e.g. 100px) instead of the
  just-computed width -- fixed by explicitly re-assigning each
  column's own `.Width` to itself first, forcing WinForms to capture
  the current value into that field before the mode switch. (2)/(3)
  `Get-MintExtractStatusDisplayText` maps `RowPlan.Status` to spaced
  display text (display-only; the raw PascalCase value is unchanged
  everywhere else in the pipeline) and inspects `Skipped` rows'
  `Detail` text for one of three known patterns. (4)
  `Show-MintExtractBatchEditDialog` plus a new
  `Update-MintExtractActionButtonStates` -- the first STATUS-aware (not
  just count-aware) MINT button-gating logic, confirmed by reading
  Search and Manage's own gating function in full first; Batch Edit is
  gated to a selection that is non-empty AND entirely
  `NeedsFolderReview`, since applying its fields to an already-
  `models.csv`-verified `ReadyToExtract` row would silently diverge it
  from its match. (5) `Get-MintGridSelectedRowsInVisualOrder` (entry
  script) generalizes Search and Manage's own
  `Get-MintSearchSelectedFilesInGridOrder` (which originated the D-056
  gapped-selection fix but was hardcoded to one grid), with the
  original reduced to a one-line delegate. (6)
  `Get-MintExtractSuggestedModelRows`/`Show-MintModelMapEditorDialog`/
  `Write-MintVariableCsv` -- a grid editor for `models.csv` using
  WinForms' own native add/delete-row support (the first MINT grid to
  do so). Deliberately departs from every other MINT dialog's
  OK-then-validate-after pattern: its OK button stays
  `DialogResult=None` and validates the whole grid FIRST, so an
  invalid save leaves the dialog open with nothing lost rather than
  silently discarding many rows of real typed data over one bad row.
  The button handler (always enabled, works with or without a batch
  loaded) backs up the pre-edit `models.csv` into its own archive --
  the first MINT writer to back up a `variables\*.csv` file, not just
  hash files -- then automatically re-classifies the current batch,
  explicitly SKIPPED if the batch already has any row in a terminal
  post-Extract status so a model-map edit can never silently revert an
  already-written row's grid status.
- One real bug found and fixed via a FAILING test, not assumed
  correct: a leading comma on a plain `PSCustomObject` property
  assignment (`Rows = ,$array`, inside the editor dialog's shared
  validation/build helper) silently double-wrapped the row array in an
  extra layer. An initial manual debug check missed this entirely
  because PowerShell's friendly dot-property array-forwarding reached
  through the extra wrapper and looked correct; the REAL save path
  (`Get-MintPropertyValue`'s explicit `.PSObject.Properties[]` lookup)
  does not get that forwarding and silently produced a blank row
  instead. The leading-comma guard (shared pitfall P29) is only
  correct on a genuine `return $array` statement, never a plain
  assignment -- this project has now hit both directions of that same
  mistake (P29 itself was originally a MISSING comma on a real
  `return`).
- Tests/validation performed: every changed file parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified after every edit. Two new
  dedicated test files: `mint_extract_followups_test.ps1` (Items
  1/2/3/4/5, 32 of 32 assertions, including a real gapped-selection
  Copy Serial(s) button click and a real Batch Edit button click with
  a real auto-answered dialog found by window title) and a second
  suite for Item 6 (32 of 32 assertions: `Write-MintVariableCsv`
  round-trip including a comma-and-embedded-quote value; suggested-row
  dedup against an existing blank-Device-Type row; BOTH validation
  failures proven via real nested-modal automation -- a `MessageBox`
  dismissed with `SendKeys` while confirming the editor dialog is
  STILL open underneath it, then a real second OK click succeeding
  once the row is fixed; Cancel proven to leave `models.csv` byte-for-
  byte unchanged; a full real end-to-end run using a real live Getac
  warranty lookup (`RRB03B2021`) confirming the backup zip, the
  on-disk file, and the automatic re-classification recount message;
  and confirming re-classification is correctly SKIPPED when the batch
  already has an `Extracted` row). Re-ran the full pre-existing
  regression battery after the Items 1-5 changes: 4 Search-suite test
  files needed the same local test-stub maintenance already
  established for functions promoted into the entry script; after that
  fix, all 19 suites passed cleanly except the same pre-existing
  SendKeys/OS-focus flakiness in `mint_inline_edit_test.ps1`. Final
  full regression battery across all 20 suites (including the new Item
  6 suite) re-run clean with the same single pre-existing exception.
  Full-app hidden-process smoke test against the REAL entry script and
  REAL production data, extended from D-065's own smoke test: all 7
  Batch Extract controls (including the 3 new buttons) plus the
  results grid are present and genuinely visible on screen within the
  live window's real bounds -- 18 of 18 assertions.
- Remaining risks or human decisions: Jeremy has not yet exercised
  Batch Edit, Copy Serial(s), or the new models.csv editor against a
  real vendor batch file or real production `models.csv`. The Item 1
  grid-resize trade-off (an in-progress inline cell edit no longer
  auto-grows its column live as the operator types) was disclosed but
  not separately confirmed acceptable beyond Jeremy's original request
  to unlock manual resize.

### 2026-07-27 - Claude (Batch Extract tab fully implemented -- D-065)

- Files reviewed: Jeremy's request to build out the Batch Extract tab
  (placeholder since the project started), with a detailed spec covering
  prefix stripping, minimal CSV quoting, warranty-lookup model
  detection, an editable folder-creation review grid, automatic folder
  creation, extraction, post-write verification, and per-duplicate
  override/ignore. Before building, researched the existing codebase
  (Explore agent pass) to find what already existed to reuse, then
  confirmed three real ambiguities with Jeremy directly (unresolved
  devices -> Review Staging; one batch file, not multi-file; duplicates
  resolved before any write) and wrote a full implementation plan
  (Plan agent + direct verification of every claimed function/line
  against the real code) before writing any code, per Plan Mode.
- Files changed: `Modules\Tab.Extract.ps1` (v1.0.0 placeholder ->
  v2.0.0), `Modules\Core.Csv.ps1` (v1.0.3 -> v1.1.0),
  `Modules\Core.Domain.ps1` (v1.0.1 -> v1.1.0),
  `Modules\Core.Inventory.ps1` (v1.0.3 -> v1.1.0),
  `MIS Inventory Navigation Tool.ps1` (v1.0.8 -> v1.0.9),
  `Modules\Tab.Search.ps1` (v1.8.2 -> v1.8.3, `Get-MintPluralizedNoun`
  removed/promoted); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-065, full detail there, including a Section 6 Tab 3
  spec update covering the two places the original never-built design
  differs from what Jeremy actually asked for).
- Findings accepted: implemented substantially as specified. Reused
  existing functions rather than rebuilding: `New-MintSerialNumber`
  (prefix stripping -- already exactly the rule Jeremy described),
  `Write-MintCanonicalHashFile` (minimal/optional CSV quoting, D-047 --
  satisfies "no quotes unless mandatory" with zero new serialization
  code), `Resolve-MintWarrantyLookup` (model detection, exactly the
  function Jeremy named -- hash decode was never built and stays out of
  scope per his own wording), `Find-MintInventoryFilesBySerial`
  (duplicate detection).
- Implementation, built in four phases within one session: (1)
  `Read-MintVendorBatchFile` (new, `Core.Csv.ps1`), the batch-CSV
  reader, reusing `ConvertTo-MintCsvLineFields`; `Get-MintResolvedModelFolderName`
  (new, extracted behavior-preserving from `New-MintDeviceModel`'s
  D-039 doubled-prefix logic) and `New-MintExtractRowPlan` (new, both
  `Core.Domain.ps1`); `Get-MintModelDestinationFolder`/
  `Resolve-MintModelDestinationPath` (new, `Core.Inventory.ps1`,
  promoting a resolve-model-then-build-path join previously duplicated
  twice inline in `Tab.Search.ps1`); `Resolve-MintExtractRowPlan`/
  `Invoke-MintExtractClassification` (new, `Tab.Extract.ps1`, headless
  classification pipeline); `Get-MintPluralizedNoun` promoted out of
  `Tab.Search.ps1` into the entry script. (2) the results grid
  (Row #/Serial/Status/Device Type/Manufacturer/Model/Destination
  Path/Detail columns), per-row cell editability only on a
  `NeedsFolderReview` row, live destination-path preview on
  `CellEndEdit`, "Create Folders Now". (3)
  `Find-MintExtractDuplicateConflicts`, `Show-MintExtractDuplicateDialog`
  (modal, Overwrite/Ignore per row, default Ignore), `Invoke-MintExtractWriteRows`
  (one shared backup archive/report for the whole run),
  `Test-MintExtractWriteVerification` (re-checks disk, never trusts the
  writer), and the full "Extract" button pipeline. (4) file-browse panel
  wiring (already substantially done in phases 2-3), theming
  confirmation, version bumps, the regression battery, and this
  documentation.
- Two real bugs found and fixed via live testing, not assumed to work:
  (1) `DataGridView.ReadOnly = $true` at the grid level takes ABSOLUTE
  precedence over any column/cell-level `ReadOnly = $false` -- the
  review grid's per-row editable cells were completely unreachable until
  the grid-level default was flipped to `$false` (matching Search and
  Manage's own established D-055 pattern, confirmed the hard way here
  via a failing test before the fix). (2) `New-MintExtractMissingFolders`'s
  second, create-nothing-new run returned `$null` instead of an empty
  array (shared pitfall P29 -- a bare `return $array` collapses a
  0-element array across a function boundary), caught by an idempotency
  assertion in its own test.
- Tests/validation performed: every changed/new file parses with 0 AST
  errors, UTF-8 BOM and ASCII-only verified. Phase 1: 33 of 33
  assertions, including a REAL live `Resolve-MintWarrantyLookup` call
  against the same proven Lenovo (`MZ013XH6`) and Getac (`RRB03B2021`)
  serials D-053's own tests used, an in-batch duplicate-serial
  collision, a malformed line, and a fault-injection test (a throwing
  stand-in for the warranty function, defined/torn down locally) proving
  a network failure never aborts the batch. Phase 2: 20 of 20, including
  a real cell edit through the actual grid (the same
  `BeginEdit`/`EditingControl`/`EndEdit` technique already established
  for Search and Manage's inline editing) proving the Destination Path
  column updates live, a deliberate doubled-manufacturer-prefix case,
  and real folder creation plus idempotency against a sandboxed library.
  Phase 3: 20 of 20 at the function level (a genuine collision correctly
  detected while excluding a row's own file; a clean multi-row batch
  producing byte-correct on-disk content, including a Review Staging row
  landing outside the governed hash library; opening the resulting
  backup zip to confirm an Overwrite row's ORIGINAL content was
  genuinely preserved before being replaced; an Ignore'd row confirmed
  byte-for-byte unchanged; a deliberately deleted post-write file
  proving verification actually catches it) plus 4 of 4 via a real
  Extract button click with a real auto-answered duplicate-resolution
  dialog (found by window title, resolved via its real grid and OK
  button, PID confirmed writing the new data). Re-ran the complete
  existing regression battery after `Get-MintPluralizedNoun`'s move:
  four suites needed the same local stub already used elsewhere for a
  function now living in the entry script rather than a `Modules\*.ps1`
  file; after that fix, 347 of 348 assertions clean across all eighteen
  suites (the one failure is the same pre-existing, previously-
  documented SendKeys/OS-focus flakiness in `mint_inline_edit_test.ps1`,
  unrelated to D-065). Full-app hidden-process smoke test against the
  REAL entry script and REAL production data: process survives, real
  main window found; while verifying the Batch Extract tab specifically,
  discovered that D-062's OwnerDraw tab-header theming makes ALL
  TabItem elements invisible to UI Automation (0 found via a
  `ControlType.TabItem` search, not just non-selected ones) -- a real
  finding with likely screen-reader/accessibility implications, flagged
  as out of scope for D-065 rather than silently worked around and
  forgotten. Worked around it for THIS test by driving the real
  Ctrl+Tab keyboard accelerator (which goes through the actual Windows
  input pipeline, unaffected by OwnerDraw) to select the Batch Extract
  tab; confirmed every real control (Process File, Browse..., Create
  Folders Now, Extract, and the results grid) is present and genuinely
  visible on screen within the live window's real bounds -- 12 of 12
  assertions across 2 clean runs.
- Remaining risks or human decisions: Jeremy has not yet run a real
  vendor batch file through this tab himself. The OwnerDraw/UI
  Automation tab-header accessibility finding (see above) is unresolved
  and was not part of this decision's scope -- worth a human decision on
  priority at some point. Hash decode (Section 7 step 1) remains
  unbuilt; Batch Extract works fully without it per Jeremy's explicit
  instruction, but any device only a hash (not a warranty lookup) could
  identify still routes to Review Staging today.

### 2026-07-27 - Claude (Group Tag column made sortable -- D-064)

- Files reviewed: Jeremy's question: "For some reason I'm not able to
  sort by group tag. Is that deliberate or unavoidable?"
- Files changed: `Modules\Tab.Search.ps1` (v1.8.1 -> v1.8.2); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-064,
  full detail there).
- Diagnosis: rather than guessing, wrote an isolated repro (throwaway
  `DataGridView` with the same column configuration -- one
  `DataGridViewComboBoxColumn` for Group Tag, `DataGridViewTextBoxColumn`
  for everything else) and read each column's actual default
  `SortMode`. Confirmed: `DataGridViewTextBoxColumn` defaults to
  `Automatic`; `DataGridViewComboBoxColumn` defaults to `NotSortable`.
  Group Tag became the grid's only combo column under D-055 (to offer a
  `variables\grouptags.csv` pick-list), so it silently lost the
  click-to-sort behavior every other column already had by default --
  nobody ever deliberately disabled it. Also confirmed in the same repro
  that explicitly setting `SortMode = Automatic` on a
  `DataGridViewComboBoxColumn` works with no exception and sorts
  correctly, ruling out "WinForms cannot sort combo columns" as an
  explanation.
- Findings accepted: answered Jeremy's actual question directly (not
  deliberate, not unavoidable) and fixed it, since the fix is a single
  explicit property assignment with no downside.
- Implementation: set `SortMode = Automatic` on the Group Tag column at
  creation time in the live grid's column-building loop, with a comment
  explaining the WinForms default so a future reader does not mistake
  the explicit assignment for redundant boilerplate and remove it.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Live functional test against the REAL
  `Initialize-SearchTab` and a real 3-file sandbox library with distinct
  Group Tag values (`IT-DESKTOPS`, `IT-LAPTOPS`, and one blank): the
  real column's `SortMode` reads back `Automatic`; calling
  `DataGridView.Sort()` against it (the same method WinForms' own
  internal header-click handler invokes) ascending correctly orders
  blank, then `IT-DESKTOPS`, then `IT-LAPTOPS`; descending reverses
  correctly; sorting by Group Tag did not disturb the Serial column's
  own independent sortability afterward. 6 of 6 assertions passed
  across 2 repeated runs. Re-ran the complete existing regression
  battery: batch edit (39), round-2 (22), inline-edit (32 of 33 -- the
  one failure is the same pre-existing, previously-documented
  SendKeys/OS-focus flakiness around free-typing a Group Tag, unrelated
  to this change), copy-serial (12), assigned-user-domain (25), batch
  continuation (4), remove-assigned-users batch (19),
  model-lookup/delete (16), summary wording (15), dynamic summary (16),
  Dark Mode dialog/grid theming (8) -- 208 of 209 assertions clean.
- Remaining risks or human decisions: Jeremy has not yet confirmed
  Group Tag sorting against the real 253-file library himself.

### 2026-07-24 - Claude (Summary bar file-count wording: "N files" -> "N files found" -- D-063)

- Files reviewed: Jeremy's request: "Where it says '&lt;number&gt; files'
  lets change that to '&lt;number&gt; files found'."
- Files changed: `Modules\Tab.Search.ps1` (v1.8.0 -> v1.8.1); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-063,
  full detail there).
- Findings accepted: exactly as requested -- only the leading file-count
  segment changed, no other summary segment reworded.
- Implementation: one line in `Update-MintSearchSummary`, appending
  " found" at the call site rather than inside the shared
  `Get-MintPluralizedNoun` helper (which stayed untouched, since other
  callers of that helper -- needs-fixing, duplicates, scan warnings --
  should not also gain " found").
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. The D-060/D-061 summary-wording test suites assert the
  actual rendered `SummaryLabel.Text` from the real
  `Update-MintSearchSummary`, so their hardcoded expected strings needed
  updating to reflect this intentional wording change (not a
  regression) -- updated and re-ran both against the real code: summary
  wording suite 15 of 15, dynamic (filter-aware) summary suite 16 of 16,
  both clean. Swept every other scratchpad test file for hardcoded
  "N files" assertions that might have been missed -- found none beyond
  the two already updated. Re-ran the Dark Mode dialog/grid-theming
  suite as a sanity check since it also touches `Tab.Search.ps1` --
  still clean (8 of 8).
- Remaining risks or human decisions: none identified.

### 2026-07-24 - Claude (Dark Mode checkbox fix: shipped invisible, found via real use -- D-062 follow-up)

- Files reviewed: Jeremy's report, immediately after D-062 shipped:
  "Where is the darkmode toggle? I don't see it."
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.0.7 -> v1.0.8);
  `AI-Project-Plan.md`'s D-062 entry updated in place with a third
  found-bug writeup and revised Status/Evidence/Remaining-risks; this
  handoff (Current State, Recent Changes, this entry).
- Root cause: `New-MintMainForm`'s Dark Mode checkbox was positioned via
  `Location(970, 5)` + `Anchor = Top|Right`, both set BEFORE the
  checkbox's containing panel (`$themeTogglePanel`) was added to the
  form and actually docked. WinForms establishes a Right anchor's
  "distance from the parent's edge" using the parent's CURRENT width at
  the moment the anchor is set -- at that point the panel was still
  unparented and had its default, un-docked `Panel` size (200x100,
  `Control.DefaultSize`), not its eventual ~1084px docked width. Once
  the panel later got added to the form (`Dock = Top`, spanning the
  form's real client width), the anchor preserved the stale
  "distance from edge" computed against the 200px reference, which
  pushed the checkbox to X=1880 -- about 800px past the panel's real
  right edge (1084px wide), completely clipped outside the panel's
  visible bounds. The control genuinely existed, was correctly wired,
  and functioned perfectly (toggling, persisting, re-theming) in every
  way EXCEPT being visible, which is exactly why the earlier full-app
  smoke test's presence check (a UI Automation `FindFirst` by control
  name) passed cleanly: an automation tree walk finds a control
  regardless of whether it is within its parent's visible bounds, so it
  reported the checkbox as present without ever checking WHERE it
  actually rendered.
- Diagnosis method: rather than guessing from the code, wrote an
  isolated repro script (`mint_darkmode_visibility_repro.ps1`)
  reproducing the EXACT same Panel/Dock/Anchor/Location sequence in a
  throwaway form, then read the checkbox's actual final `.Location`/
  `.Bounds` after a real `Show()` + `DoEvents()` layout pass. This
  confirmed the checkbox landed at X=1880 inside a 1084px-wide panel
  (`checkbox.Right=1958 > panel.Width=1084`) -- an exact, reproducible
  match for "invisible," not a guess.
- Fix: replaced `Location`+`Anchor` with `Dock = Right` directly on the
  checkbox (plus `TextAlign = MiddleRight` so the label reads naturally
  against the right-docked edge). `Dock` has no parenting-order timing
  dependency -- it always resolves against the parent's actual current
  size whenever layout runs, regardless of when the child was added.
  Re-ran the same repro script after the fix: checkbox now lands flush
  at the panel's real right edge (`X=1006` to `X=1084` in a 1084px-wide
  panel) regardless of add order.
- Test-coverage gap closed: neither the in-process `New-MintMainForm`
  unit test nor the cross-process full-app smoke test had ever checked
  WHERE a control actually renders -- only whether it exists
  (`mint_theme_mainform_test.ps1`) or is present in the automation tree
  (`mint_theme_fullapp_smoke_test.ps1`), both of which this bug passed
  cleanly despite being fully invisible to a real user. Added: (1) to
  the unit test, two bounds assertions directly on the real production
  `New-MintMainForm` function's checkbox (`checkbox.Right -le
  panel.Width`, `checkbox.Left -ge 0`); (2) to the smoke test, a real
  on-screen `AutomationElement.Current.BoundingRectangle` comparison
  between the checkbox and the live running app's actual main window
  rectangle, cross-process, against the REAL app (not a test double).
- Tests/validation performed: entry script parses with 0 AST errors,
  UTF-8 BOM verified, ASCII-only verified. `New-MintMainForm`
  AST-extraction suite: 16 of 16 assertions (up from 14 -- both new
  bounds assertions passing: `checkbox.Right=1084` exactly matches
  `panel.Width=1084`, `checkbox.Left=1006` is non-negative). Full-app
  hidden-process smoke test against the REAL entry script and REAL
  production data, both startup scenarios (no settings file; pre-saved
  `{"Theme":"Dark"}`): 10 of 10 assertions across 2 clean runs (up from
  8) -- the new on-screen bounds check reports the checkbox's real
  screen rectangle (e.g. `2616,566,117,42`) as genuinely contained
  within the live window's real screen rectangle (e.g.
  `1095,519,1650,1050`) in both scenarios. Re-ran `Core.Theme.ps1`'s
  unit suite (40 of 40) and the `Tab.Search.ps1` dialog/grid theming
  suite (8 of 8) again to confirm this fix introduced no new
  regressions -- both still clean.
- Remaining risks or human decisions: Jeremy has not yet visually
  re-confirmed that the Dark Mode checkbox is now actually visible on
  his own real screen/resolution -- this fix is verified via real
  on-screen coordinate math (UI Automation `BoundingRectangle` against
  the live running app), not a human visual check.

### 2026-07-24 - Claude (Whole-app togglable Dark Mode, saved locally -- D-062)

- Files reviewed: Jeremy's request: "Is there a way to allow dark mode,
  similar to the systems settings, and it be togglable (but the option
  saved locally within the installation so it persists between
  launches)?" Explored the codebase to scope what could realistically be
  themed today (Search and Manage and Warranty Lookup are the only
  fully built-out tabs) and how WinForms theming actually works (no
  built-in dark mode; every control's colors need manual handling, and
  `DataGridView`/`TabControl`/`StatusStrip` each need more than a plain
  `BackColor` assignment), then proposed a plan Jeremy explicitly
  approved ("Let's go ahead an implement it").
- Files changed: new `Modules\Core.Theme.ps1` (v1.0.0 -> v1.0.1, one
  fix during smoke testing); `MIS Inventory Navigation Tool.ps1`
  (v1.0.6 -> v1.0.7); `Modules\Tab.Search.ps1` (v1.7.0 -> v1.8.0);
  `Modules\Tab.Warranty.ps1` (v1.1.0 -> v1.2.0); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-062, full detail there,
  including a Section 5 architecture spec update).
- Findings accepted: exactly as proposed -- a "Dark Mode" checkbox on
  the main shell (top-right, above the tabs), applying live with no
  restart, persisted locally (`MINT-Settings.json` next to the
  program's own files, not the shared filestore), scoped to Search and
  Manage, Warranty Lookup, and shared shell chrome.
- Implementation: `Core.Theme.ps1` provides `Get-MintThemePalette`
  (Light captured live from a fresh `DataGridView` plus documented
  `SystemColors` so it is byte-identical to the pre-existing
  appearance, not guessed; Dark hand-picked with brighter red/blue for
  contrast against a near-black background), `Set-MintControlTheme` (a
  recursive control-tree walker dispatching on runtime type,
  deliberately skipping per-cell flag colors and the path-warning
  label since those carry business meaning refreshed separately),
  `Enable-MintTabControlThemedDrawing` (TabControl headers cannot be
  recolored via `BackColor` at all, so this switches to
  `OwnerDrawFixed` and paints tabs manually -- a disclosed trade-off:
  even Light mode loses native hover/gradient chrome once wired), and
  `Get-MintThemeSettingsPath`/`Get-MintThemePreference`/
  `Save-MintThemePreference`/`Invoke-MintThemeChange` for local
  persistence and live application. The entry script loads
  `Core.Theme.ps1` first (right after `Core.Logging.ps1`), adds the
  checkbox/panel to `New-MintMainForm`, applies the saved preference at
  startup, and themes the startup wait window. `Tab.Search.ps1` themes
  its three dialogs (Model Picker, Batch Edit, Model Lookup result) on
  open and swaps hardcoded `Color.Red` flag colors for
  `Get-MintThemeErrorColor`. `Tab.Warranty.ps1` does the same for "Not
  Found" rows plus a new `Update-MintWarrantyGridFlagColors` so an
  already-populated grid updates its flag colors immediately on a live
  toggle.
- Two real bugs found and fixed via live testing before shipping, not
  assumed to work:
  1. A plain scriptblock event handler (no `.GetNewClosure()`)
     referencing a LOCAL (non-`$script:`-scoped) variable from a
     function that has already returned throws under
     `Set-StrictMode -Version Latest` once the handler actually fires
     -- an extension of shared pitfall P28, not the same finding (P28
     is specifically about `.GetNewClosure()` breaking `$script:`
     access). Found via an isolated test where the handler first
     appeared to silently not fire at all; tracing revealed
     `PerformClick()`/`Click` requires a realized window handle
     (`.Show()`) to dispatch at all, and only after adding `.Show()`
     did the real StrictMode exception surface. Separately confirmed
     `CheckedChanged` (unlike `Click`) fires correctly even before
     `.Show()`, validating the startup design of setting `.Checked`
     before `Application.Run()`. Fixed by redesigning the Dark Mode
     checkbox's handler to read everything through a new
     `$script:MintMainShellState` container (`MainForm`,
     `PathStatusLabel`, `UnreachablePathCount`, `DarkModeCheckBox`)
     plus `$this`, never local closures.
  2. `Enable-MintTabControlThemedDrawing`'s `DrawItem` handler called
     `Graphics.DrawString` with a `Rectangle`, which has no matching
     overload -- PowerShell resolved to the
     `(string,Font,Brush,PointF,StringFormat)` overload and threw
     `"Cannot convert...Rectangle...to PointF"` as an unhandled
     exception dialog on every single real app startup, in either
     theme, since `DrawItem` always fires once `OwnerDraw` is enabled.
     This would have been a hard crash for Jeremy on first use. Not
     caught by the earlier in-process `New-MintMainForm` unit test,
     which positioned its test form off-screen at `(-3000,-3000)` --
     apparently enough that Windows never generated a real `WM_PAINT`
     for it, so the bug was never actually exercised until the full-app
     cross-process smoke test (a real, visible, hidden-window process)
     caught it immediately. Fixed by explicitly constructing a
     `RectangleF` from the tab rect before calling `DrawString`.
- Tests/validation performed: all four changed/new files parse with 0
  errors under the Windows PowerShell 5.1 AST parser; verified UTF-8
  BOM and ASCII-only on each. `Core.Theme.ps1` unit/integration suite:
  40 of 40 assertions, 2 clean runs (persistence round-trip, palette
  correctness, `Set-MintControlTheme` dispatch across control types).
  AST-extraction test of the REAL `New-MintMainForm` function (parses
  the real entry script, extracts only that function's text via
  `[System.Management.Automation.Language.Parser]::ParseFile` +
  `FindAll`, evaluates it in isolation to avoid the entry script's
  blocking `Application.Run()`): 14 of 14 assertions, 3 clean runs,
  including the real checkbox toggling the real form live, persisting
  to and reading back from the real settings file, and a fresh form
  correctly starting Dark when a Dark preference was already saved.
  Real dialog/grid theming test against `Tab.Search.ps1`: 8 of 8
  assertions, 2 clean runs -- Format-flag color is theme-aware both at
  initial populate and after a live `Update-MintSearchGrid` refresh,
  and the real Model Picker and Batch Edit dialogs (opened via real
  `PerformClick()`, found via `Application.OpenForms` polling,
  auto-closed via Cancel) open with Dark colors already applied.
  Re-ran the complete existing regression battery after adding
  `Core.Theme.ps1` to each test's dot-source list (needed since
  `Tab.Search.ps1`/`Tab.Warranty.ps1` now call
  `Get-MintThemeErrorColor`): batch edit (39), round-2 (22), inline-edit
  (32 of 33 -- one pre-existing, previously-documented SendKeys/OS-focus
  flakiness around free-typing a Group Tag, unrelated to any D-062 code
  path, reproduced identically across 3 runs both before and after this
  work), copy-serial (12), assigned-user-domain (25), batch continuation
  (4), remove-assigned-users batch (19), model-lookup/delete (16),
  summary wording (15), dynamic summary (16) -- 200 of 201 assertions
  clean. Full-app hidden-process smoke test against the REAL entry
  script and REAL production data, both startup scenarios (no settings
  file present; a pre-saved `{"Theme":"Dark"}` settings file): real
  process survives, real main window found, real "Dark Mode" checkbox
  present. This smoke test is what caught the `DrawString` crash above
  -- the first run failed with the unhandled-exception dialog text
  captured via a UI Automation tree dump; after the fix, 8 of 8
  assertions, 2 clean runs, and the production folder was left with no
  leftover settings file (backed up/restored around the test; none
  existed beforehand). Re-ran the `Core.Theme.ps1` unit suite, the
  `New-MintMainForm` AST-extraction suite, and the `Tab.Search.ps1`
  dialog/grid suite again after the `DrawString` fix to confirm it
  introduced no new regressions -- all still clean (40/40, 14/14, 8/8).
- Remaining risks or human decisions: Jeremy has not yet tried Dark Mode
  himself. Only Search and Manage, Warranty Lookup, and shared shell
  chrome are themed; the four still-placeholder tabs will inherit
  theming automatically once built, but have not been visually
  confirmed since they do not exist yet.

### 2026-07-24 - Claude (Search and Manage: summary bar counts become filter-aware -- D-061)

- Files reviewed: Jeremy's follow-up on the just-reworked summary bar
  (D-060): "the files show a constant (in this case) '253 files'...
  Rather than showing the fixed amount, can we instead make it actively
  dynamic to reflect the total number of files shown in the field? So
  as I enter in search terms, the number gets smaller with each match,
  and displays 0 files if there is no match at all."
- Files changed: `Modules\Tab.Search.ps1` (v1.6.0 -> v1.7.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-061,
  full detail there, including a Section 6 Tab 2 spec update).
- Findings accepted: file count reflects the filtered/visible set, not
  the whole library, updating live as the operator types.
- Scoping decision made and disclosed rather than silently assumed:
  extended the same fix to the "need Import Format fixing" and
  "duplicate" counts too, not just the raw file count Jeremy explicitly
  named -- reasoned that leaving those two pinned to whole-library
  totals while the file count became filtered would produce an
  internally inconsistent, MORE confusing summary (e.g. "3 files -- 15
  need Import Format fixing" when only 3 files are even visible) than
  either the old fully-static or the new fully-filtered state. Also
  proactively fixed the Decommissioned view's twin bug (identical root
  cause: a raw total count instead of the actually-filtered/displayed
  count, in code immediately adjacent to what was already being
  touched) rather than leaving a known-identical bug sitting right next
  to the one just fixed.
- Implementation: `Update-MintSearchSummary` gained a mandatory
  `-FilteredFiles` parameter; `Update-MintSearchLiveGrid` (its only
  caller) now tracks the matched-file list alongside populating grid
  rows and passes it in, rather than the function independently
  re-querying `Get-MintInventoryIndexSummary` for whole-library totals.
  Scan warnings intentionally still come from that whole-library query,
  unaffected by the filter, since a scan-level problem is not tied to
  any one visible row.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Built a live functional test against a real 6-file sandbox
  library (3 canonical + 1 non-canonical desktop, 2 canonical laptops,
  `depts.csv` deliberately omitted for exactly 1 constant scan warning)
  driving REAL `TextChanged`/`SelectedIndexChanged` events (setting
  `SerialTextBox.Text`/`ModelComboBox.Text` directly, the same events
  real typing fires) and asserting the summary after each change:
  unfiltered matches the whole library; a serial filter matching exactly
  3 (excluding the non-canonical file) drops the needs-fixing segment
  entirely while the scan-warning count stays exactly 1 and unchanged;
  narrowing to exactly 1 file uses correct singular wording; a filter
  matching only the non-canonical file shows the needs-fixing segment
  reappearing; a filter matching nothing shows a genuinely empty grid
  and "0 files" (plural) with the scan warning still present; a Model
  filter narrows independently of the serial filter; clearing all
  filters returns to the exact original unfiltered summary. A parallel
  block verified the identical fix in the Decommissioned view against a
  real 3-row master list, including correct singular wording at exactly
  1 match. 16 of 16 assertions passed across 3 repeated runs. Re-ran the
  complete existing regression battery: D-060's own summary-wording
  suite (15), batch edit (39), round-2 (22), inline-edit (33), copy-
  serial (12), assigned-user-domain (25), batch continuation (4),
  remove-assigned-users batch (19), model-lookup/delete (16) -- 201 of
  201 assertions, all clean -- plus a hidden-process smoke test of the
  full real entry script.
- Remaining risks or human decisions: Jeremy has not yet used the
  live-filtering summary against the real 253-file library himself.

### 2026-07-24 - Claude (Search and Manage: top summary bar wording/pluralization + "View Scan Issues" link -- D-060)

- Files reviewed: Jeremy's report that the summary bar ("253 files -- 0
  non-canonical -- 0 duplicate -- 2 issues") had several problems:
  missing plural grammar, empty categories still shown as "0 X",
  unexplained "non-canonical" jargon, and an "issues" count that gave no
  indication of what was wrong -- specifically noting he had fixed every
  Import Format issue and had zero duplicates, yet still saw "2 issues."
- Files changed: `Modules\Tab.Search.ps1` (v1.5.0 -> v1.6.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-060,
  full detail there, including a Section 6 Tab 2 spec update).
- Root-caused the "issues" confusion BEFORE writing any wording changes,
  since Jeremy's report implied the count might be measuring something
  different from what its label suggested: traced
  `Get-MintInventoryIndexSummary`'s `Issues` field back through
  `Core.Inventory.ps1` and found it is a flat list of scan-level problem
  strings collected while `Initialize-MintInventoryIndex` builds the
  index (a missing/malformed `variables\models.csv`/`depts.csv`/
  `grouptags.csv`, or a hash file with a `ReadError` -- a strictly more
  severe condition than "non-canonical," meaning the file could not even
  be parsed, not just that it doesn't match Intune's exact format) --
  confirmed via direct code reading, not assumption, that this field has
  NEVER been connected to Import Format or duplicate status in any way.
  This means Jeremy's observation was fully consistent with the code all
  along; the count just had no way to explain itself.
- Findings accepted: correct singular/plural grammar throughout (new
  `Get-MintPluralizedNoun` helper); every category besides the total
  file count omitted entirely when its count is 0 rather than shown as
  "0 X"; "non-canonical" renamed to "N need(s) Import Format fixing" to
  match the live grid's own "Import Format" column/values instead of a
  database term; "issues" renamed to "N scan warning(s)" with a new
  "View Scan Issues..." `LinkLabel` (visible only when count is 1+,
  repositioned dynamically right after the summary text every time it
  updates) that shows the exact issue text via a MessageBox, mirroring
  the existing per-file View Format Issues button's pattern exactly.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. 6 unit assertions directly against `Get-MintPluralizedNoun`
  (0/1/2/253 for files, 1/3 for duplicates). 3 live-grid functional test
  scenarios against real sandbox libraries: an all-canonical/no-
  duplicate/no-scan-issue library shows ONLY "N files" with the link
  hidden; a library engineered to have exactly one of every category
  (achieved by deliberately omitting `depts.csv` for exactly one real
  scan warning, and a genuine duplicate-serial pair placed in two
  different folders so both files stay individually canonical while
  triggering `IsDuplicate`) shows fully correct singular wording and a
  working link whose MessageBox text genuinely names the missing
  `depts.csv`; a library with multiples of each category (2 needing
  fixes, 4 duplicate files) shows correct plural verb/noun agreement
  with the scan-warnings segment and link both correctly absent since
  that count is 0 even though the others are not. First test run
  surfaced two of my own fixture bugs (not product bugs) before I
  trusted the results: an early duplicate-file fixture accidentally
  named files so their filename did not match their own internal serial
  number, which legitimately made them non-canonical and inflated the
  "need Import Format fixing" count -- fixed by using the same filename
  as each file's own serial, placed in two different folders instead.
  15 of 15 assertions passed across 4 repeated runs. Re-ran the complete
  existing regression battery: batch edit (39), round-2 (22), inline-
  edit (33), copy-serial (12, one run hit an unrelated transient Windows
  clipboard-ownership exception, confirmed clean on immediate re-run
  alone), assigned-user-domain (25), batch continuation (4),
  remove-assigned-users batch (19), model-lookup/delete (16) -- 185 of
  185 assertions, all clean -- plus a hidden-process smoke test of the
  full real entry script.
- Remaining risks or human decisions: Jeremy has not yet seen the
  reworded summary bar or clicked View Scan Issues against the real
  library himself, so the exact real-world scan-warning text he
  encounters is still unconfirmed. Likely candidates given the project's
  history are a missing `depts.csv` (never explicitly confirmed created,
  unlike `grouptags.csv` in D-052) and/or a hash file with a genuine
  `ReadError` -- flagged as a guess, not asserted as fact; the new link
  will show him the real text directly the next time he opens the tab.

### 2026-07-24 - Claude (Main window/taskbar icon -- D-059)

- Files reviewed: Jeremy's request to replace the default WinForms icon
  shown in the title bar and taskbar, offering `Hall County MIS
  Logo.png` or `MINT.ico` and asking which format works best.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.0.5 -> v1.0.6);
  this handoff and the matching `AI-Project-Plan.md` (new Decision
  D-059, full detail there).
- Findings accepted: `MINT.ico` over the `.png` -- `Form.Icon` is
  strongly typed as `System.Drawing.Icon`, not a generic image, and a
  `.png` would need runtime bitmap-to-icon conversion (fragile, single-
  resolution, GDI-handle-disposal concerns); `MINT.ico` was already a
  proper multi-resolution icon needing no conversion at all. Verified
  this via `System.Drawing.Icon` load plus raw `.ico` header byte
  parsing BEFORE writing any code, rather than assuming the file was
  well-formed: 7 embedded images, 16 through 256px.
- Implementation: added `$form.Icon` assignment in `New-MintMainForm`,
  resolved via the existing `$script:ProjectRoot` variable (the folder
  the script itself lives in) rather than the absolute OneDrive path
  Jeremy gave in chat, so the code stays portable if the project folder
  is ever copied/moved -- consistent with this project's "no hardcoded
  paths outside the central path-configuration block" convention.
  Wrapped in try/catch: falls back to the default icon and logs a
  warning if the file is ever missing/corrupt, rather than blocking
  startup over a cosmetic resource.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Verified in three layers rather than trusting the code
  read-through alone: (1) confirmed `MINT.ico` is genuinely well-formed
  and multi-resolution before writing any code; (2) an isolated test
  running the EXACT product code snippet against a real `Form` proved
  `Form.Icon` ends up byte-identical (full memory-stream comparison) to
  loading `MINT.ico` directly, plus a second scenario confirmed a
  missing icon file leaves the default icon untouched without throwing;
  (3) launched the REAL entry script as a real hidden process, found its
  actual window via `EnumWindows`/`GetWindowThreadProcessId` (P/Invoke,
  reusing the technique already established from the D-048 launcher
  verification work), and queried its live icon via `WM_GETICON`/
  `SendMessage` -- confirmed a real, non-zero icon is present and is
  visibly different (pixel comparison) from a genuinely unmodified
  default WinForms form's icon retrieved through the identical
  cross-process pipeline. This ruled out "nothing actually changed" as
  an explanation when an EARLIER, separate exact-pixel-match attempt
  (live icon vs. a freshly file-loaded icon) initially failed -- traced
  that specific failure to a DPI-scaling/icon-caching artifact of the
  `WM_GETICON`/`SendMessage` cross-process retrieval path itself (a test
  methodology limitation, not a product defect), since layer (2) had
  already proven byte-exact correctness through a single, non-cross-
  process code path. Standard hidden-process full-app smoke test stayed
  clean.
- Remaining risks or human decisions: none identified. Purely cosmetic,
  low risk, and easily reversible (revert the diff, or the try/catch
  already degrades gracefully if `MINT.ico` is ever removed).

### 2026-07-24 - Claude (Batch Edit: "Remove All Assigned Users" mode, PLUS critical Group Tag data-loss bug found and fixed -- D-058, shared pitfall P30)

- Files reviewed: Jeremy's request, "Let's add a function to the batch
  edit tool: Remove All Assigned Users." Reviewed the existing
  `Show-MintBatchEditDialog`/`Invoke-MintFixImportFormatSingleFile`
  pair (D-049/D-050) to extend rather than duplicate.
- Files changed: `Modules\Tab.Search.ps1` (v1.4.0 -> v1.5.0);
  `reference_intune_pitfalls.md` (new P30 entry); `MEMORY.md` (pitfall
  count 29 -> 30); this handoff and the matching `AI-Project-Plan.md`
  (new Decision D-058, full detail there, including a prominent ACTION
  NEEDED note for Jeremy).
- Findings accepted: the new feature exactly as described -- a third
  Batch Edit mode, mutually exclusive with the existing two (Set Group
  Tag, Fix Import Format only), via radio buttons rather than a
  checkbox, since three options no longer fit a single-checkbox mental
  model. Combining modes (e.g. set a Group Tag AND clear Assigned User
  in one pass) was not requested and was deliberately not added.
- **Critical finding, not part of what was asked but too serious to
  ship past without disclosing:** while building and live-testing the
  new mode's `OverrideAssignedUser` parameter (mirroring the existing
  `OverrideGroupTag` parameter's `[string]$Param = $null` +
  `if ($null -ne $Param)` pattern), a live isolated repro showed the
  override branch firing even when the parameter was never supplied at
  all. Did not assume this was specific to the new parameter --
  immediately tested whether the SAME pattern on the PRE-EXISTING
  `OverrideGroupTag` parameter had the identical problem, using the
  exact call shape the standalone Fix Import Format button has always
  used (zero override arguments). It did. Root-caused precisely: in
  Windows PowerShell 5.1 (confirmed on the exact build this product
  requires, 5.1.26100.8655), a `[string]`-typed parameter with a
  `= $null` default is coerced to a real `System.String` instance
  holding `""` the moment it is bound -- both when the caller omits the
  parameter and when the caller explicitly passes `$null` -- so
  `$null -ne $Param` is unconditionally true and can never distinguish
  "not supplied" from "supplied." This means every use of Fix Import
  Format (the standalone button, or Batch Edit's pre-D-058 checkbox
  mode) has been silently wiping that file's Group Tag to blank since
  D-050 shipped on 2026-07-23 -- Jeremy's real 175-file production Fix
  Import Format run (the one that motivated D-051) is very likely
  affected if any of those files had a real Group Tag beforehand.
- Also root-caused WHY this escaped detection through D-050, D-051,
  D-052, and every later round's regression re-runs: the existing
  round-2 fixture's "no override leaves Group Tag untouched" test used a
  sandbox file whose Group Tag already started blank (a 3-column row
  with no Group Tag data), so `IsNullOrEmpty(result.GroupTag)` was
  trivially true regardless of whether the value was correctly preserved
  or silently wiped -- the assertion had no ability to ever fail.
- Fix: changed `Invoke-MintFixImportFormatSingleFile` to check
  `$PSBoundParameters.ContainsKey('OverrideGroupTag')` /
  `ContainsKey('OverrideAssignedUser')` instead of testing the bound
  value against `$null`. This alone is not sufficient at the call site,
  though -- an always-present `-OverrideX $null` named argument (which is
  what a naive fix of the NEW Batch Edit loop would have looked like)
  reproduces the identical bug, since `ContainsKey` would still report
  it as supplied. Changed the per-file loop in `batchEditButton.Add_Click`
  to build a splat hashtable that only gains a key when that specific
  mode genuinely intends that override. The standalone Fix Import Format
  button needed no change at all -- it already omitted both parameters
  entirely and is simply correct now that the function it calls is
  fixed. Also corrected the round-2 regression fixture to start
  `TESTSN002` with a real, non-blank Group Tag (`REALTAG`) instead of a
  blank one, so this exact class of regression can be caught in the
  future.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. New feature verified via 19 live UI-automation assertions
  across 4 repeated runs: 9 dialog-level (each of the three modes
  returns the correct result shape, verified by directly manipulating
  the dialog's real controls via `[System.Windows.Forms.Application]::
  OpenForms` rather than fragile SendKeys-driven radio-button
  navigation; the Group Tag combo's Enabled state toggles correctly
  across all three modes) plus 10 live-grid integration assertions
  (selecting 4 real sandbox devices -- one already-domain-qualified
  Assigned User, one legacy-unqualified, one already blank, and one
  genuinely non-canonical file -- running Remove All Assigned Users
  clears Assigned User on all 4 including the non-canonical one,
  confirming this mode is NOT format-gated the way Fix Import Format is,
  while Group Tag stays untouched on every file, and exactly one backup
  archive is created for the whole batch). The bug fix was independently
  verified via 9 targeted assertions directly against the real
  `Invoke-MintFixImportFormatSingleFile` (no override at all now
  preserves both fields; a real GroupTag override still applies
  correctly without disturbing Assigned User; a real empty-string
  AssignedUser override clears only that field; a splatted call with
  only `-File` preserves both) -- confirmed these FAILED before the fix
  and PASSED after, on the same test, proving the bug was genuinely real
  and the fix genuinely resolves it, not assumed from the code alone.
  Re-ran the complete existing regression battery, including the
  corrected round-2 fixture: batch edit (39), round-2 (22, gained one
  assertion from the fixture fix), inline-edit (33), copy-serial (12),
  assigned-user-domain (25), batch continuation (4), model-lookup/delete
  (16) -- 151 of 151 assertions, all clean -- plus a hidden-process
  smoke test of the full real entry script.
- Remaining risks or human decisions: Jeremy confirmed on 2026-07-24
  that the new Remove All Assigned Users feature (and, by extension, the
  P30 Group Tag preservation fix in the same release) works correctly
  against the real live library at scale ("I can confirm it works en
  masse") -- the real-world verification gap this decision originally
  flagged is now closed. **Still open and unaddressed: whether the OLD
  175-file Fix Import Format production run (the one that motivated
  D-051, run before this fix existed) actually wiped any real Group Tag
  values, and whether Jeremy wants to check that run's backup archive to
  identify and restore any lost data.** This is a distinct question from
  "does the fix work now" -- it is about data that may already have been
  lost before the fix shipped -- and Jeremy's confirmation message did
  not address it either way. Still a data question only Jeremy can
  answer, not something to guess at or silently remediate.

### 2026-07-23 - Claude (Search and Manage: Assigned User domain normalization/validation -- D-057)

- Files reviewed: Jeremy's request for Assigned User inline edits (D-055)
  to auto-append `@hallcounty.org` to a bare username, but only accept
  that exact domain once an `@` is present, specifically to prevent
  `john.doe@hallcounty.org` from ever becoming
  `john.doe@hallcounty.org@hallcounty.org`.
- Files changed: `Modules\Tab.Search.ps1` (v1.3.0 -> v1.4.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-057,
  full detail there).
- Findings accepted: exactly as described -- bare username gets the
  domain appended; an already-qualified value is accepted only if the
  domain is hallcounty.org (case-insensitive); anything else is rejected
  with an explanatory message rather than silently rewritten.
- Design note worth flagging: solving the doubling scenario correctly
  required more than just "append if no @ present." Reasoned through the
  no-op-detection ordering carefully before writing code: the existing
  D-055 CellEndEdit handler already has a raw-value-vs-original no-op
  check (skip everything if nothing actually changed) -- that check must
  run BEFORE any Assigned User normalization, or else merely clicking
  into a cell holding a legacy/pre-existing unqualified value (no domain
  at all, from before this decision existed) and clicking back out
  without typing anything would appear to "change" it (since
  normalization would append a domain to the raw value), triggering an
  unwanted backup and write. A SECOND no-op check was then added AFTER
  normalization, since normalizing what was actually typed can also land
  back on the exact original value (retyping the bare username into an
  already-qualified cell, or retyping the identical full address itself)
  -- both cases are genuine no-ops that must not write, and this second
  check is specifically what stops the doubling scenario from Jeremy's
  request.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Ten pure unit-level assertions directly against the new
  `ConvertTo-MintAssignedUserValue` function covering bare username,
  already-qualified address, mixed-case domain (accepted, normalized to
  lowercase, local part case preserved), blank/whitespace-only, wrong
  domain, trailing bare `@`, `@` with no username, two `@` signs, and
  whitespace trimming. Fifteen further assertions via a live grid
  functional test against a real sandbox grid covering five real
  scenarios, including the exact doubling scenario (retyping an
  already-qualified address into itself stays exactly the same, no
  double domain confirmed on disk) and the legacy-value no-op case
  (clicking into a pre-existing unqualified value without editing it
  creates no backup and is not silently upgraded). 25 of 25 assertions
  passed across 4 repeated runs. Two pre-existing D-055 regression
  assertions needed updating (not a defect -- the old test typed a bare
  username and asserted the OLD unqualified on-disk value, which this
  decision correctly changes); updated and re-verified passing. Re-ran
  the complete existing regression battery: batch edit (39), round-2
  (21), batch continuation (4), model-lookup/delete (16), and the
  updated D-055 inline-edit suite (33) -- 113 of 113 assertions, all
  clean -- plus a hidden-process smoke test of the full real entry
  script.
- Remaining risks or human decisions: Jeremy has not yet used the
  feature against the real library himself. The hallcounty.org domain
  is hardcoded rather than externalized to a `variables\*.csv` file --
  deliberate, since Jeremy did not ask for a configurable domain and
  Hall County has exactly one domain; flagged in case that assumption
  ever needs to change. No additional username-format validation
  (characters, length, AD existence check) was added beyond the
  `@`/domain handling actually requested.

### 2026-07-23 - Claude (Search and Manage: "Copy Serial(s)" action, gap-safe multi-selection -- D-056)

- Files reviewed: Jeremy's request to copy one or multiple devices'
  serial numbers to the clipboard, explicitly calling out that a
  multi-selection with gaps must still work and paste one device per
  line.
- Files changed: `Modules\Tab.Search.ps1` (v1.2.0 -> v1.3.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-056,
  full detail there).
- Findings accepted: a new "Copy Serial(s)" button on the live grid's
  action panel, enabled for 1-or-more selected rows, copying serial
  numbers one per line (CRLF-joined) to the clipboard.
- Real bug found and fixed before it shipped, via a dedicated isolated
  repro rather than assumed: built a small standalone test selecting
  grid rows out of visual order (row 4, then row 1, then row 5) and
  found `DataGridView.SelectedRows` enumerates in REVERSE-SELECTION
  order (most-recently-selected first), not grid-visual order. The
  existing `Get-MintSearchSelectedFiles` helper (used by 5 other
  features) relies on that same property, so reusing it directly would
  have "handled gaps" in the sense of not crashing or skipping rows, but
  would have produced scrambled, click-order-dependent clipboard output
  for any gapped selection -- directly undermining the "one device per
  line" requirement's implicit expectation of predictable, visually-
  sensible order. Confirmed the fix (iterate `.Rows` filtering
  `.Selected`, which does return true visual order) in the same isolated
  repro before writing any product code, then added it as a new
  `Get-MintSearchSelectedFilesInGridOrder` helper rather than modifying
  the shared, already-tested `Get-MintSearchSelectedFiles` (its five
  other callers do not depend on selection order, so changing shared
  code they rely on was unnecessary risk for this decision).
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Built a live functional test driving real button-state
  checks and real `PerformClick()` calls against a real 6-row sandbox
  grid: button disabled at 0 selected, enabled at 1 and at many;
  single-selection copies exactly that one serial with singular status
  wording; a contiguous 3-row selection copies in grid order with plural
  wording; selecting all 6 rows copies all 6 in order; the button
  correctly hides while viewing decommissioned devices and reappears in
  the live view. The decisive test: selecting rows E, then A, then C (a
  scrambled, gapped, non-visual click order) produced clipboard output
  in true grid order A, C, E -- not click order E, A, C -- confirming
  the fix actually works, not just that gaps don't crash it. 12 of 12
  assertions passed across 3 repeated runs. Re-ran the complete existing
  regression battery: batch edit (39), round-2 (21), batch continuation
  (4), model-lookup/delete (16), and the D-055 inline-edit suite (33) --
  113 of 113 assertions, all clean -- plus a hidden-process smoke test
  of the full real entry script.
- Remaining risks or human decisions: Jeremy has not yet used the
  feature against the real library himself. A matching Copy Serial(s)
  action for the decommissioned-devices view was not requested and was
  not added, consistent with Copy Path's existing live-only scoping --
  flagged as a natural future extension if wanted, not assumed.

### 2026-07-23 - Claude (Search and Manage: inline spreadsheet-style Group Tag/Assigned User editing -- D-055)

- Files reviewed: Jeremy's request for Excel-cell-style inline editing of
  Group Tag and Assigned User in the Search and Manage results grid,
  followed by his confirmation ("Go ahead with all of it") of the
  silent-backup/no-confirmation-dialog design Claude proposed after
  first assessing whether the change would be drastic.
- Files changed: `Modules\Tab.Search.ps1` (v1.1.0 -> v1.2.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-055,
  full detail there).
- Findings accepted: exactly as described -- Group Tag becomes a
  searchable/typeable dropdown with a blank entry and free-text support;
  Assigned User is plain text; silent backup on every commit, no
  confirmation dialog.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Found a real product bug via live testing before writing
  any fix: a DataGridViewComboBoxColumn's built-in dirty-notification
  wiring does not reliably fire for free-typed text, only for picking an
  existing list item, so a newly-typed custom Group Tag silently
  reverted on commit with zero error or indication -- fixed via an
  explicit TextChanged-driven NotifyCurrentCellDirty call in
  EditingControlShowing. Investigated a subsequent intermittent test
  failure rather than assuming the fix was already good enough: traced
  it to the test itself using unrealistic synthetic bulk `.Text =`
  assignment (races the queued TextChanged message against EndEdit)
  rather than genuine per-keystroke input; rebuilt using real
  `System.Windows.Forms.SendKeys` typing and confirmed the underlying
  product fix is reliable across 40 assertions spanning 8 runs of two
  dedicated single-purpose repro scripts covering fresh custom text
  (Tab-commit and click-away-commit), clearing to blank, picking a
  configured value, and Escape-to-cancel. Separately root-caused and
  fixed an unrelated pure test-harness limitation (confirmed not a
  product issue): once a grid cell has gone through one edit cycle
  earlier in the same automated test process, a later synthetic edit's
  control does not reliably receive real OS keyboard focus via managed
  `Control.Focus()` (silently no-ops); worked around with the raw Win32
  `SetFocus` API in the test only, since a real user's mouse click
  always transfers genuine OS focus. After this test-harness fix, the
  full 33-assertion inline-edit suite (column setup, Group Tag
  choice-list union, free-text unlock, a real AssignedUser save, a real
  free-typed GroupTag save, a non-canonical file's Format cell updating
  in place, a same-value no-op edit creating no backup, and a ReadError
  file correctly blocking edit entry) passed 7 consecutive full runs
  (231/231 assertions) with zero flakiness. Re-ran the complete existing
  regression battery -- batch edit (39), round-2 (21), batch continuation
  (4), model-lookup/delete (16) -- 80 of 80 assertions, all clean.
- Remaining risks or human decisions: Jeremy has not yet used the
  feature against the real library himself. Unrelated observation,
  flagged but not investigated further since it is out of scope here and
  touches code untouched in this session: `mint_report_retry_test.ps1`'s
  "persistent lock exhausts retries and throws" assertion
  (Core.Backup.ps1, D-051) failed consistently across this session's
  regression re-runs; likely a `Start-Job` dispatch-timing artifact in
  that specific test, not a product regression, but worth a dedicated
  look in a future session.

### 2026-07-23 - Claude (Search and Manage: Model Lookup + Delete -- D-054)

- Files reviewed: Jeremy's request for a single-selection-only Model
  Lookup action reusing the warranty pipeline (D-053), and a multi-
  selection Delete action with a two-step (backup-then-confirm)
  confirmation sequence.
- Files changed: `Modules\Tab.Search.ps1` (v1.0.6 -> v1.1.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-054,
  full detail there).
- Findings accepted: both features exactly as described. Model Lookup
  calls `Resolve-MintWarrantyLookup` and shows results in a new
  `Show-MintModelLookupResultDialog`. Delete adds
  `Invoke-MintDeleteSingleFile` and follows the exact D-051 backup-
  phase-separate-from-per-item-work pattern already used by every other
  batch action in this file.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Built a live functional test driving REAL button clicks
  and REAL modal dialogs (Timer polling the foreground window title,
  standard Windows MessageBox Alt+accelerator/Escape SendKeys, not
  approximated): Model Lookup button correctly gates on exactly 1 vs 2
  selected, and a real click against the real Getac test serial
  (RRB03B2021) produces a genuine live lookup with a success status.
  Delete tested across four real scenarios: Backup=Yes/Delete=Yes on 2
  files (both genuinely removed from disk, exactly one backup zip
  created, and the zip opened via `System.IO.Compression.ZipFile` to
  verify it actually contains both files); Backup=Cancel (target file
  verifiably left untouched); Backup=No/Delete=Yes (file still correctly
  deleted, status explicitly states no backup was made, no backup zip
  exists afterward). 16 of 16 assertions passed. Re-ran all existing
  regression suites (39 + 21 + 4 = 64 assertions) plus a hidden-process
  smoke test of the full real entry script -- all clean.
- Remaining risks or human decisions: Jeremy has not yet used either
  feature against the real library himself. Delete is Live-view-only,
  matching every other batch action's existing scoping convention.

### 2026-07-23 - Claude (Warranty Lookup tab built: Lenovo ported, Getac new, honest fallback -- D-053)

- Files reviewed: `Fill-LenovoWarrantyWorkbook.ps1` v5.0.1 in full (to
  port its proven algorithm, not re-derive it); the `Core.VendorLookup.ps1`
  and `Tab.Warranty.ps1` stubs (already documented the intended design);
  Section 6 Tab 6 and Section 7 of the plan; D-033/D-042/D-043.
- Files changed: `Modules\Core.Domain.ps1` (v1.0.0 -> v1.0.1),
  `Modules\Core.VendorLookup.ps1` (v1.0.0 stub -> v1.1.0),
  `Modules\Tab.Warranty.ps1` (v1.0.0 placeholder -> v1.1.0); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-053,
  full detail there).
- Findings accepted: Jeremy's explicit scope -- Lenovo (ported) + Getac
  (new, "should be simple," held up) + an honest "Vendor Not Configured"
  notice for anything else, not the full Section 7 pipeline.
- Tests/validation performed: made real live HTTP calls to the actual
  Getac endpoint BEFORE writing any parser -- captured a real response
  for test serial RRB03B2021 (Model B360G3, Warranty Expiration Date
  2030-Dec-26) and a real live "not found" response for a fake serial,
  then built/verified the parser against both real captures. Ran a live
  functional test against REAL vendor endpoints: Getac RRB03B2021 ->
  Found/B360G3/real date; Getac fake serial -> correctly Not Found;
  Lenovo MZ013XH6 (a real Hall County device) -> Found/Lenovo/"ThinkCentre
  M70q Gen 5"/machine type 12TD/real warranty dates (03/05/2025 to
  03/04/2028), proving the ported logic still works against Lenovo's
  live site today; orchestrator correctly chains Lenovo-miss -> Getac-hit,
  and correctly returns an explanatory fallback for an unknown serial.
  Found and fixed two real bugs via this live testing: (1) a missing
  `[AllowEmptyCollection()]` -- same PS 5.1 gotcha already documented from
  Core.Inventory.ps1, freshly reintroduced here, leaking an internal
  PowerShell binding error into a user-facing message; (2) a genuine
  PowerShell language gotcha found via a full real-UI test (real button
  click, real grid, real CSV export): `(if (...) {...} else {...})` in
  bare parentheses as one argument among several in a method call or
  array literal throws "The term 'if' is not recognized" -- fixed by
  computing each conditional value into its own variable first. Re-ran
  both existing regression suites (60 assertions) after touching
  Core.Domain.ps1, plus a hidden-process smoke test of the full real
  entry script -- all clean.
- Remaining risks or human decisions: Jeremy has not yet used the real
  tab himself. Hash decode and Dell/HP API providers remain
  unimplemented by design. The cached Lenovo web session has no tested
  refresh-on-failure path if it goes stale mid-session.

### 2026-07-23 - Claude (Jeremy created the real grouptags.csv; format mismatch found and fixed -- D-052)

- Files reviewed: Jeremy reported creating the real live
  `variables\grouptags.csv`. Read it directly over the UNC path rather
  than assuming it matched the D-049 design.
- Files changed: `Modules\Core.Inventory.ps1` (v1.0.2 -> v1.0.3); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-052,
  full detail there).
- Findings accepted: the real file is a flat 70-line list with no
  header row, starting immediately with real data -- does not match
  D-049's original headered-CSV design.
- Root-caused via a sandbox COPY of the real file (live file never
  modified) before writing any fix: proved the OLD reader would treat
  the first real tag as a header, fail the required-header check, and
  silently discard the whole file -- Jeremy's dropdown would have
  stayed empty despite him doing exactly what was asked. AI-side
  design/communication gap, not a mistake on Jeremy's part.
- Rationale: adapted the code to Jeremy's real, already-populated file
  rather than asking him to retrofit a header line onto 70 real rows --
  a single-column list has no ambiguity a header would resolve. Same
  precedent as D-047.
- Tests/validation performed: parsed the changed file with the Windows
  PowerShell 5.1 AST parser (0 errors); verified UTF-8 BOM and
  ASCII-only. Ran the new reader against a sandbox copy of the REAL live
  file: 69 unique tags (70 lines, 1 real duplicate collapses to one);
  confirmed the first real tag is no longer dropped, an apostrophe reads
  correctly, and the one irregular no-suffix entry reads correctly.
  Updated the one existing test fixture that had synthesized a headered
  grouptags.csv, then re-ran all 4 test suites (68 assertions, 0
  failures) plus a hidden-process smoke test of the real entry script.
- Remaining risks or human decisions: the real file has one exact
  duplicate line and one entry without a suffix -- both handled
  gracefully, flagged only in case either was unintentional. Jeremy has
  not yet used the populated Batch Edit dropdown himself.

### 2026-07-23 - Claude (Jeremy's seventh feedback round: real 175-file crash, report-writer resilience -- D-051)

- Files reviewed: a real logged error Jeremy hit running Fix Import
  Format against 175 real files: `Fix Import Format backup step failed:
  ... AppendAllText ... because it is being used by another process`.
- Files changed: `Modules\Core.Backup.ps1` (v1.0.0 -> v1.0.1),
  `Modules\Tab.Search.ps1` (v1.0.5 -> v1.0.6); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-051, full detail there).
- Root-caused before touching code: the log message blamed "the backup
  step," but the exception text pointed at `AppendAllText` (the
  run-report writer, not the backup archive) -- traced this to two
  separate real problems. (1) `Add-MintRunReportRow` had no retry
  protection at all, unlike the decommission master list. (2) The
  try/catch structure could not distinguish "nothing changed yet" from
  "most files already got fixed, then one audit-log write hit a lock,"
  so both landed in the same catch block with the same misleading
  message -- Jeremy's real 175-file run was very likely mostly
  successful but reported as a total failure.
- Findings accepted: fixed both root causes together, not just the
  missing retry, since a retry alone would still misreport a genuinely
  persistent (non-transient) lock as a total failure.
- Tests/validation performed: parsed both changed files with the
  Windows PowerShell 5.1 AST parser (0 errors); verified both are
  UTF-8 BOM and ASCII-only. Built two new isolated tests: one exercises
  `Add-MintRunReportRow` against a REAL file lock held by a background
  job, confirming it retries through an 800ms lock and succeeds, and
  still throws (not hangs forever) when a lock persists longer than the
  retry window. The other drives the REAL `$fixFormatButton` click
  end-to-end -- a real button click, the real Yes/No confirm dialog
  auto-answered via a Timer + SendKeys, and `Add-MintRunReportRow`
  redefined after dot-sourcing to simulate a persistent lock on exactly
  the 2nd of 3 files -- confirmed the loop attempted all 3 report
  writes, the final status read "Fixed 3 of 3 device(s)" despite the
  simulated failure, and all 3 sandbox files were genuinely canonical on
  disk. Re-ran both existing regression suites (60 assertions, 0
  failures) plus the new 8, and the full real entry script as a hidden
  background process.
- Remaining risks or human decisions: Jeremy has not yet re-run the real
  175-file batch that originally crashed. The zip backup step has no
  equivalent retry protection -- flagged as a known gap, not fixed here
  since it was not what broke.

### 2026-07-23 - Claude (Jeremy's sixth feedback round: batch AD check, Fix Import Format, real Batch Edit crash fix -- D-050)

- Files reviewed: Jeremy's request to make Check AD Location batch-
  capable and add an Import Format correction button both inside and
  outside Batch Edit, plus a real .NET unhandled-exception dialog from
  clicking Batch Edit with multiple devices selected
  (`ParameterBindingValidationException: Cannot bind argument to
  parameter 'GroupTagChoices' because it is null`).
- Files changed: `Modules\Core.Inventory.ps1` (v1.0.1 -> v1.0.2),
  `Modules\Tab.Search.ps1` (v1.0.4 -> v1.0.5); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-050, full detail there);
  shared `reference_intune_pitfalls.md` (new P29 entry) and `MEMORY.md`.
- Findings accepted: both feature requests -- see D-050 for full detail.
- Root-caused the crash before touching code: traced past the
  `[AllowEmptyCollection()]` parameter constraint (correct, not the bug)
  to where the `$null` actually originated -- `Get-MintGroupTagChoices`
  returning a bare `return $script:MintInventoryIndex.GroupTags` instead
  of comma-wrapping it, which collapses to `$null` when the array has 0
  elements (true here, since `variables\grouptags.csv` does not exist
  yet). Checked the other three array accessors in the same file and
  found the identical latent bug in all of them; fixed all four
  together. Documented as new shared pitfall P29.
- Tests/validation performed: parsed both changed `.ps1` files with the
  Windows PowerShell 5.1 AST parser (0 errors); verified both are UTF-8
  BOM and ASCII-only. Extended the local-sandbox functional test to
  directly reproduce Jeremy's exact crash scenario (no grouptags.csv
  file at all) and confirm it no longer throws -- verified via a
  WinForms Timer that auto-closes the real, live
  `Show-MintBatchEditDialog` modal by title match, so the actual
  `ShowDialog()` call path executes for real. Also verified
  `Invoke-MintFixImportFormatSingleFile` fixes a genuinely non-canonical
  sandbox file to canonical while preserving Hardware Hash and leaving
  Group Tag untouched with no override; the same worker with
  `-OverrideGroupTag` preserves Hardware Hash while changing Group Tag;
  a `ReadError` file is `Skipped` not attempted; and
  `Update-MintSearchActionButtonStates` keeps Check AD Location and the
  new Fix Import Format button enabled for a 2-row selection. 21 of 21
  assertions passed. Re-ran the full real entry script as a hidden
  background process and confirmed it still reaches the WinForms run
  loop and stays running.
- Remaining risks or human decisions: Jeremy has not yet re-tested Batch
  Edit against the real library to confirm the crash is actually gone in
  practice, or used batch AD check / Fix Import Format (either path)
  himself. `variables\grouptags.csv` still does not exist on the live
  filestore.

### 2026-07-22 - Claude (Jeremy's fifth feedback round: multi-select, Batch Edit Group Tag, batch Decommission/Restore, column reorder -- D-049)

- Files reviewed: Jeremy's request for multi-select with realistically-
  batchable actions available and the rest grayed out, a Batch Edit
  action to mass-assign Group Tag from a dropdown, Decommission working
  across a multi-selection "unless technically not possible," Import
  Format/Duplicate moved to the end of the column order, and the
  already-implemented Decommission-becomes-Restore toggle.
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.0.4 -> v1.0.5),
  `Modules\Core.Csv.ps1` (v1.0.2 -> v1.0.3), `Modules\Core.Inventory.ps1`
  (v1.0.0 -> v1.0.1), `Modules\Tab.Search.ps1` (v1.0.3 -> v1.0.4); this
  handoff and the matching `AI-Project-Plan.md` (new Decision D-049,
  full technical detail there).
- Findings accepted: all four items from Jeremy -- see D-049 for full
  detail. The Decommission/Restore button-swap Jeremy asked about was
  already implemented and working from an earlier round; extended it to
  also toggle the new Batch Edit button's visibility.
- Findings rejected/scoped down: Move to Model Folder was deliberately
  NOT made batch-capable -- Jeremy did not ask for it; flagged in D-049
  as a natural future extension instead of assumed.
- Tests/validation performed: parsed all 4 changed `.ps1` files with the
  Windows PowerShell 5.1 AST parser (0 errors); verified all 4 are UTF-8
  BOM and ASCII-only. Built an isolated local-sandbox functional test
  (temp folders standing in for the shared filestore -- no production
  data touched) covering Get-MintGroupTagChoices, the
  Write-MintCanonicalHashFile round-trip, live grid column order,
  MultiSelect on both grids, Update-MintSearchActionButtonStates across
  0/1/2-row selections, the Decommission/Restore/BatchEdit visibility
  toggle, and a full decommission-then-restore mutation cycle against
  sandbox files -- 39 of 39 assertions passed after fixing two WinForms/
  PowerShell test-harness quirks along the way (Control.Visible reads
  False for any control under a Form that was Hide()'d or never shown,
  regardless of its own flag; piping a `,$array`-returning function
  directly into Where-Object hands the whole array to $_ as one item
  instead of enumerating it). Also launched the real entry script as a
  hidden background process and confirmed it reaches the WinForms run
  loop and stays running.
- Remaining risks or human decisions: `variables\grouptags.csv` does not
  exist on the live filestore yet -- deliberately not created by AI/dev
  (no basis to invent Hall County's real Group Tag values); Jeremy needs
  to create it (header `Group Tag`, one tag per row). Free-text entry in
  the Batch Edit dropdown works either way in the meantime. Jeremy has
  not yet exercised multi-select, Batch Edit, or batch Decommission/
  Restore against the real library himself.

### 2026-07-22 - Claude (Jeremy's real-world contradiction of the round-4 console fix; rebuilt as .vbs, D-048)

- Files reviewed: Jeremy's exact real-world report after the round-4 fix
  directly below: "The cmd window is still open, just minimized." This
  directly contradicted that fix's own verification (zero visible
  `ConsoleWindowClass` windows measured for the spawned process).
- Files changed: `MIS Inventory Navigation Tool.vbs` (new, v1.0.0,
  primary/recommended launcher), `MIS Inventory Navigation Tool.cmd`
  (rewritten again, demoted to a legacy shim); this handoff and the
  matching `AI-Project-Plan.md` (new Decision D-048, full detail there).
- Findings accepted: did not just re-assert the round-4 fix works.
  Recognized a genuinely hidden window cannot appear "minimized"
  (minimizing does not clear `WS_VISIBLE`), so the round-4 test's result
  was answering the wrong question -- it verified the INNER PowerShell
  process's console, not the OUTER `.cmd` window Jeremy was actually
  describing. Suspected real cause: Windows Terminal keeps a tab open
  when its hosted process exits very quickly (crash safeguard), and the
  `.cmd` exits in ~1-1.5 seconds by design.
- Fix: eliminated the console/terminal host from the launch chain
  entirely for the primary use case instead of further tuning how
  PowerShell is started. All launch logic (including the
  `PROCESSOR_ARCHITEW6432` 64-bit PowerShell path resolution, ported
  from batch to VBScript) now lives in a single standalone `.vbs`, using
  `WshShell.Run(cmd, 0, False)`. `wscript.exe` has no console window of
  its own, so there is no terminal host for Explorer to create at all.
  The `.cmd` is kept only as a thin `wscript.exe //B "...vbs"` shim for
  existing shortcuts/pins, but is no longer the recommended entry point.
- Also built and rejected as insufficient: an intermediate
  `Launch-Hidden.vbs` invoked FROM the `.cmd` (keeping the `.cmd` as the
  primary target). Verified mechanically clean, but does not remove the
  outer console host Explorer creates to interpret the `.cmd` itself, so
  it does not address the suspected real cause. Discarded in favor of a
  standalone, self-sufficient `.vbs`.
- Tests/validation performed: rebuilt the EnumWindows/
  GetWindowThreadProcessId/IsWindowVisible/GetClassName P/Invoke harness
  and ran it against both launchers. `.vbs` direct: exits ~615ms, MINT
  main WinForms window `Visible=True`, MINT's own `ConsoleWindowClass`
  window `Visible=False`, zero lingering `wscript.exe` processes. `.cmd`
  shim: exits ~985ms, identical clean result. Explicitly noted this
  test's limitation in D-048: it cannot detect a Windows Terminal tab
  kept open independently of the launcher process's own exit, which is
  exactly the failure mode suspected here -- reported as "mechanically
  verified," not "confirmed fixed." Re-verified both files ASCII-only,
  no BOM (matches existing `.cmd` convention).
- Remaining risks or human decisions: this is the second attempt at the
  same complaint, and the first attempt's automated verification did not
  predict the real-world failure. Jeremy's real-world double-click
  confirmation on the new `.vbs` is the authoritative check this time.
  Jeremy will also need to know to switch any desktop shortcut/taskbar
  pin from the `.cmd` to the `.vbs` to get the fully clean experience.

### 2026-07-22 - Claude (Jeremy's fourth feedback round: console window and startup delay)

- Files reviewed: Jeremy's observation of a ~10 second startup delay and
  a console window that stayed open for the tool's whole runtime.
- Files changed: `MIS Inventory Navigation Tool.cmd` (rewritten),
  `MIS Inventory Navigation Tool.ps1` (v1.0.3 -> v1.0.4); this handoff and
  the matching `AI-Project-Plan.md` (full detail there).
- Findings accepted: the console window has no functional purpose for a
  WinForms tool. Fixed by launching the script detached with `start ""
  powershell.exe -WindowStyle Hidden ...` instead of running it inside
  the `.cmd`'s own inherited console.
- Self-identified and addressed proactively: hiding the console removes
  the only visible feedback during the ~10 second initial library scan
  (256+ real files over the network). Added a startup wait window
  (reusing the Refresh Inventory helpers) so the fix does not create a
  worse first-launch experience than what it replaced.
- Tests/validation performed: built a live P/Invoke-based test
  (EnumWindows/GetWindowThreadProcessId/IsWindowVisible/GetClassName)
  to directly inspect the spawned process's actual windows rather than
  trusting the -WindowStyle Hidden flag alone. Confirmed the .cmd's own
  process exits in under 1 second, a detached process launches with a
  genuinely visible WinForms window, and that process owns zero
  ConsoleWindowClass windows. Standard smoke test and full 15-file parse/
  BOM/ASCII validation both re-run clean.
- Remaining risks or human decisions: Jeremy to confirm this matches
  expectations on a real double-click and that the startup wait window's
  appearance/wording looks right.

### 2026-07-22 - Claude (Jeremy's third feedback round: quoted fields are not a problem)

- Files reviewed: Jeremy's direct statement that quoted CSV fields have
  never caused a real Autopilot import problem in his operational
  history.
- Files changed: `Modules\Core.Csv.ps1` (v1.0.1 -> v1.0.2); this handoff
  and the matching `AI-Project-Plan.md` (Section 4 rewritten, new
  Decision D-047, full detail there).
- Findings accepted: quoted fields removed as a format issue entirely
  (not just reworded, per D-046's earlier message-clarification pass --
  fully removed this time). Parser behavior unchanged.
- Findings rejected: none. Directly overrides the earlier assumption
  (from Batch Extractor v1.0.7's changelog, citing Microsoft's general
  Autopilot CSV documentation) that quoting was disallowed -- Jeremy's
  real repeated import history outweighs it per the shared AGENTS.md
  authority order.
- Tests/validation performed: re-scanned the real 256-file library --
  canonical count jumped from 1/256 to 80/256, confirming quoting was the
  dominant remaining false-positive. Full functional test suite, full
  app smoke test, and full 15-file parse/BOM/ASCII validation all re-run
  clean.
- Remaining risks or human decisions: none new. Remaining 176 non-
  canonical files reflect other genuine issues now, not quoting.

### 2026-07-22 - Claude (Jeremy's second feedback round: format spec + grid sizing)

- Files reviewed: Jeremy's detailed correction of the canonical header
  rule, his direct dispute of the "Quoted fields present" finding, and
  his BOM-scope clarification.
- Files changed: `Modules\Core.Csv.ps1` (v1.0.0 -> v1.0.1),
  `Modules\Tab.Search.ps1` (v1.0.2 -> v1.0.3); this handoff and the
  matching `AI-Project-Plan.md` (Section 4 rewritten, new Decision D-046,
  full technical detail there).
- Findings accepted: all three from Jeremy (BOM scope, header rule, grid
  sizing) -- see `AI-Project-Plan.md`'s D-046 for full detail.
- Findings rejected: none. On the disputed quotes finding specifically:
  verified live (not assumed) that this was correct all along -- Excel's
  parsing hides real quote-escaping characters; fixed the message, not
  the detection logic.
- Rationale: the header-rule and BOM-scope issues meant the tool was
  reporting false format problems on files that are actually fine, which
  would mislead operators about what genuinely needs fixing before any
  future auto-fix tab gets built.
- Tests/validation performed: 7 synthetic test cases for the new header
  rule (all correct); re-scanned the real 256-file library (aggregate
  split unchanged at 255/256, confirming quoting is a genuine widespread
  issue, not a detection artifact); full functional test suite and full
  application smoke test re-run clean; full 15-file parse/BOM/ASCII
  validation re-run clean.
- Remaining risks or human decisions: Jeremy to confirm grid column
  sizing looks right visually; a very long value (e.g. an AD error
  message) could make a column wide enough to need horizontal scroll --
  literal behavior as requested, flagging in case it looks awkward.

### 2026-07-22 - Claude (Jeremy's first-use feedback on Search and Manage, v1.0.2)

- Files reviewed: Jeremy's direct feedback plus a real .NET unhandled
  exception dialog (full stack trace) from clicking "Show Decommissioned
  Devices".
- Files changed: `MIS Inventory Navigation Tool.ps1` (v1.0.2 -> v1.0.3),
  `Modules\Tab.Search.ps1` (v1.0.1 -> v1.0.2); this handoff and the
  matching `AI-Project-Plan.md` work log (full detail there); shared
  `reference_intune_pitfalls.md` (new P28 entry) and `MEMORY.md` index.
- Findings accepted: all 5 items from Jeremy (wait window, singular device
  type display, clearer Import Format column + explainer, red problem
  text, and the ShowingDecommissioned crash) -- see
  `AI-Project-Plan.md`'s matching entry for full technical detail on each.
- Findings rejected: none.
- Rationale: direct usability feedback from the tool's actual user, plus
  one real correctness bug that made a documented, spec'd feature
  (D-040 Restore, which needs the decommissioned-devices view) completely
  unusable.
- Tests/validation performed: extended the functional test harness with
  the exact checkbox-click scenario that had been missing (the gap that
  let the crash through undetected in the prior session's testing);
  verified all 5 fixes live against real data, including the specific
  crash no longer reproducing in either toggle direction. Found and fixed
  an unrelated duplicate-line copy-paste bug introduced by Claude's own
  edit, caught by reviewing the diff before testing. Full app smoke test
  and full 15-file parse/BOM/ASCII validation re-run clean.
- Remaining risks or human decisions: Jeremy to confirm the fixes look
  right in practice (Claude cannot visually verify WinForms layout without
  a screenshot tool); the action-panel button row is now fairly full and
  may need revisiting if it looks cramped.

### 2026-07-22 - Claude (Search and Manage: real implementation, Tab 2 complete)

- Files reviewed: Hardware Hash Batch Extractor.ps1 v1.0.7 (ported its
  hardened CSV parser); the real Endpoint Inventory hash library and MINT
  variables folder on the live filestore (inspected directly before
  writing any scanning code).
- Files changed: `Modules\Core.Csv.ps1`, `Core.Domain.ps1`,
  `Core.Inventory.ps1`, `Core.Backup.ps1`, `Core.ActiveDirectory.ps1`,
  `Core.DeviceRecord.ps1`, `Tab.Search.ps1` (stub -> real implementation);
  this handoff and the matching `AI-Project-Plan.md` (full detail there).
- Findings accepted: N/A (new implementation).
- Bugs found and fixed via live testing against real filestore data (see
  `AI-Project-Plan.md`'s matching work log entry for full detail on each):
  missing `[AllowEmptyCollection()]` on three `Core.Inventory.ps1`
  parameters; a previously undocumented PS 5.1 gotcha where
  `@($someListVariable)` throws `ArgumentException` (use `.ToArray()`
  instead -- affected 175 real Getac files during testing, NOT YET added
  to the shared pitfalls reference); a nested-function scope bug in
  `Tab.Search.ps1` in the same family as the entry script's v1.0.2 fix
  (`Tab.Search.ps1` bumped to v1.0.1); a data-integrity gap where a locked
  decommission master list could leave a decommission half-recorded,
  fixed with a retry wrapper covering both `IOException` and
  `UnauthorizedAccessException`.
- Rationale: Search and Manage needs most of the core engine to be real
  (index scanning, CSV parsing, backup/decommission, AD lookup) rather
  than stubbed, so this necessarily became a vertical-slice implementation
  pass, not just one tab.
- Tests/validation performed: extensive live testing against the real 256-
  file hash library, real `depts.csv` (36 rows), real AD (verified against
  this machine's own computer object and a real department resolution),
  and a full functional simulation of the tab (real `TabPage`, simulated
  `TextChanged`/`Click` events via `.PerformClick()`). Decommission/Restore
  mutation logic tested end-to-end using a synthetic throwaway serial, not
  any of Jeremy's real sample data, fully cleaned up afterward. All 15
  `.ps1` files re-verified: parse-clean, UTF-8 BOM, 0 non-ASCII. Full
  application smoke test re-run clean after all changes.
- Remaining risks or human decisions: the real master decommission list
  file is durably locked right now (see Recent Changes above) -- needs
  investigation before it can be relied on. The `@()` vs `.ToArray()`
  pitfall should be added to the shared knowledgebase pitfalls reference
  (not yet done). Jeremy has not yet used the real tab himself. Five tabs
  and `Core.VendorLookup.ps1` remain stubs.

### 2026-07-22 - Codex (hotfix v1.0.2 for module dot-source scope)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - This handoff and the matching `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.ps1`
- Files changed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.ps1`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
- Findings accepted: Jeremy's startup error was caused by the v1.0.1 import
  hardening. In PowerShell, dot-sourcing a module from inside a function defines
  imported functions in that function's local scope, so `Write-MintLog` was no
  longer available when startup path validation tried to log warnings.
- Findings rejected: the missing log entry was expected for this specific
  failure path because the logging function itself was not present in script
  scope. It was not evidence that the log-file append code failed after loading.
- Rationale: Keep module path validation in a helper, but perform dot-sourcing
  directly in the script-scope startup `try` block so module functions persist
  for the rest of the application session.
  The dot-source scoping rule was also added to shared `AGENTS.md` as a durable
  PowerShell lesson.
- Tests/validation performed: parsed all 15 `.ps1` files with the Windows
  PowerShell 5.1 AST parser (0 errors); verified `.ps1` files are UTF-8 with BOM
  and ASCII-only; verified the `.cmd` launcher is ASCII-only; searched for common
  PowerShell 7-only syntax and risky shell constructs with no hits; hidden
  smoke launch reached the WinForms run loop and stayed running past 3 seconds
  with no stdout/stderr startup error, then the test process was intentionally
  killed and verified cleaned up.
- Remaining risks or human decisions: Jeremy should rerun the `.cmd` on the
  Hall County network context to confirm the visible shell opens and the shared
  log file records expected startup warnings or stays quiet when all paths are
  reachable.

### 2026-07-22 - Codex (shell hardening v1.0.1)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `AI Knowledgebase\MEMORY.md`
  - `AI Knowledgebase\PowerShell-5.1-Official-Reference.md`
  - `AI Knowledgebase\feedback_ps_auditor_standard.md`
  - `AI Knowledgebase\feedback_script_encoding.md`
  - `AI Knowledgebase\feedback_version_sync.md`
  - This handoff and the matching `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.ps1`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.cmd`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\Modules\Core.Logging.ps1`
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.ps1`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.cmd`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\Modules\Core.Logging.ps1`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
- Findings accepted: the earlier shell-audit risks were valid and were fixed
  without adding real tab business logic. The app remains a shell, but startup
  is now harder to break during iterative module work.
- Findings rejected: no need to build the CSV/domain/inventory/warranty engines
  as part of this cleanup; Jeremy only requested necessary shell-risk fixes.
- Rationale: A testable shell should fail clearly when a developer breaks a
  module, should not point users to nonexistent logs, and should reliably start
  in the intended 64-bit Windows PowerShell host.
- Tests/validation performed: parsed all 15 `.ps1` files with the Windows
  PowerShell 5.1 AST parser (0 errors); verified `.ps1` files are UTF-8 with BOM
  and ASCII-only; verified the `.cmd` launcher is ASCII-only; searched for common
  PowerShell 7-only syntax and risky shell constructs with no hits; hidden
  smoke launch reached the WinForms run loop and stayed running past 3 seconds,
  then the test process was intentionally killed and verified cleaned up.
- Remaining risks or human decisions: Jeremy still needs to double-click the
  `.cmd` from the Hall County network context to confirm live shared-path health
  and visual behavior against the real filestore.

### 2026-07-22 - Codex (audit of initial MINT shell code)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - This handoff and the matching `AI-Audit-Decisions.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.ps1`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\MIS Inventory Navigation Tool.cmd`
  - All current `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\Modules\*.ps1` files
- Files changed:
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
- Findings accepted: the current scripted state is appropriately a shell only;
  missing tab functionality is not a defect at this phase. The shell/module files
  have no current parse, encoding, or obvious PowerShell 7-only compatibility
  issue. Areas to address before the shell becomes the foundation for real logic:
  early module/Add-Type failures currently occur before the friendly startup
  error handler; the status bar can tell users to see a log even when the log
  root itself is unreachable; the `.cmd` launcher can still enter a 32-bit
  PowerShell host when invoked from a 32-bit parent; startup path creation and
  future path classification should be kept deliberate and explicit.
- Findings rejected: do not count unimplemented core modules or placeholder tab
  content as project failure for this audit, because Jeremy confirmed the goal is
  a testable shell while looking for potentially breaking logic.
- Rationale: MINT is entering iterative implementation, so shell survivability
  and clear startup diagnostics matter more than feature completeness in this
  review.
- Tests/validation performed: parsed all 15 `.ps1` files with the Windows
  PowerShell 5.1 AST parser (0 errors); verified `.ps1` files are UTF-8 with BOM
  and ASCII-only; verified the `.cmd` launcher is ASCII-only; searched for common
  PowerShell 7-only syntax and risky shell constructs with no hits; confirmed the
  local `powershell.exe` apartment state is STA for WinForms.
- Remaining risks or human decisions: Jeremy still needs to run the shell from
  the Hall County network context to confirm the shared-path status turns healthy
  against the real filestore. Recommended next development cleanup is to wrap
  module loading/Add-Type in the startup error boundary and improve log-path
  unavailable reporting before large module logic is added.

### 2026-07-22 - Claude (first working code: UI shell with placeholder tabs)

- Files reviewed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md` (full read, all decisions through D-044)
  - This handoff and the matching `AI-Audit-Decisions.md`
- Files changed/created:
  - `MIS Inventory Navigation Tool.ps1` (entry point, D-005 path config, module loader, D-005-rule-3 startup path validation, WinForms shell, v1.0.0)
  - `MIS Inventory Navigation Tool.cmd` (launcher)
  - `Modules\Core.Logging.ps1` (fully implemented, D-020)
  - `Modules\Core.Domain.ps1`, `Core.Csv.ps1`, `Core.Backup.ps1`, `Core.Inventory.ps1`, `Core.VendorLookup.ps1`, `Core.ActiveDirectory.ps1`, `Core.DeviceRecord.ps1` (documented stubs)
  - `Modules\Tab.Validate.ps1`, `Tab.Search.ps1`, `Tab.Extract.ps1`, `Tab.ModelLookup.ps1`, `Tab.Upload.ps1`, `Tab.Warranty.ps1` (placeholder tab UIs)
  - Updated `AI-Project-Plan.md` (module tree, top status line, stale Upload Lists line) and this handoff
- Findings accepted: multi-file `Modules\` layout per Q-1/D-035; central
  path config with DataRoot/HashInventoryRoot split per D-018/D-024/D-038;
  Core.Logging.ps1 added as a necessary module not in the original list.
- Findings rejected: an initially-drafted SysNative 32-bit/64-bit relaunch
  block in the `.cmd` launcher was removed after recognizing it solves an
  Intune/IME-specific problem that does not apply to a tool launched
  directly by a person; a simple 64-bit guard in the .ps1 itself is
  sufficient and correct here.
- Rationale: Jeremy asked to start real implementation with a testable
  shell so tabs can be filled in incrementally and verified as work
  proceeds, rather than building the full core engine before anything is
  visible/testable.
- Tests/validation performed: parsed all 15 `.ps1` files with the Windows
  PowerShell 5.1 AST parser (0 errors); verified/corrected UTF-8 BOM
  (Write tool does not add one) and ASCII-only content for all 15 files;
  live-launched the actual shell via Start-Process, confirmed it stays
  running (Application.Run reached, form and all 6 tabs built without
  exception) with both shared filestore roots unreachable from this dev
  environment, proving the graceful-degradation path rather than assuming
  it; found and fixed a real bug (unvoided Write-MintLog boolean returns
  leaking "True" lines to stdout) via this same live test, then
  re-verified clean output after the fix.
- Remaining risks or human decisions: Jeremy has not yet visually
  confirmed the running window himself. Phase 1 core-engine implementation
  (CSV parser, backup/report engine, inventory index, domain objects,
  device-record resolver) is still pending; all six tabs are placeholders
  with no real functionality yet.

### 2026-07-22 - Codex (Dell/HP API field speculation deferred)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Findings accepted: Dell and HP exact API result fields, field names, value
  shapes, display labels, and unavailable-field behavior are intentionally
  deferred until real API credentials and sample payloads exist.
- Findings rejected: Do not infer Dell/HP API payload shape from public warranty
  pages, broad vendor documentation, third-party examples, or guesses.
- Rationale: Waiting for real payloads prevents false UI expectations and
  avoidable provider rewrites.
- Tests/validation performed: Documentation-only change; no code exists yet.
- Remaining risks or human decisions: Dell TechDirect access and HP Warranty API
  access remain future vendor-admin items.

### 2026-07-22 - Codex (Getac relevant field scope)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Findings accepted: Getac warranty result parsing is intentionally limited to
  `SN`, `Model`, and `Warranty Expiration Date`.
- Findings rejected: Do not parse or store Getac service request links,
  parts-order links, show-config details, battery warranty content, brochure
  content, or other non-MINT page details.
- Rationale: MINT only needs Getac warranty lookup data that supports serial,
  model, and warranty-expiration inventory decisions.
- Tests/validation performed: Documentation-only change; no code exists yet.
- Remaining risks or human decisions: Getac parser still needs implementation
  validation against more sample serials.

### 2026-07-22 - Codex (planning contract cleanup and HP/Getac warranty check)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
  - HP Warranty API documentation
  - HP CMSL `Get-HPWarrantyInfo` documentation
  - HP public warranty page assets
  - Getac warranty form pages
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Findings accepted: Hardware hash model folders must resolve to
  `<Manufacturer> <Model Name>`; decommission collisions use newest-wins with
  confirmation; decommissioned devices need a Restore action; migration timing
  is on hold until Jeremy resolves it; HP should use official API access for
  reliable automation; Getac public form POST automation is feasible for the
  supplied test serial.
- Findings rejected: Do not leave model-folder naming as a mixed
  model-only/manufacturer-prefixed contract. Do not build a migration workflow
  before Jeremy defines the timing. Do not treat HP's public dynamic warranty
  page as the preferred automation contract.
- Rationale: These changes remove remaining planning conflicts before code
  begins and keep vendor lookup work aligned with supported or proven request
  flows.
- Tests/validation performed: Documentation-only edits. Live-tested Getac
  `https://support.getac.com/Service/F1800/Index` with
  `txtSNs=RRB03B2021`, which returned an inquiry result containing
  `RRB03B2021` and model `B360G3`. Fetched HP public warranty page assets and
  verified the official HP Warranty API and HP CMSL documentation.
- Remaining risks or human decisions: HP API access/credentials remain a
  future vendor-admin item. Getac parser behavior still needs implementation
  validation against more sample serials. Migration timing remains Jeremy-held.

### 2026-07-21 - Codex (open question answers and refinements)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
  - Dell TechDirect / Dell Command Warranty public documentation
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Findings accepted: Backup/report retention is 180 days by default and
  variable-driven; legacy tools remain until MINT is complete; Batch Extract
  auto-creates verified missing model folders; Upload Builder should be modeled
  for override toggles; shared writes use short locks with pre-write
  revalidation; vendor batch root, distribution source path, Getac automation
  preference, and decommission paths/schema are now documented.
- Findings rejected: Long-lived shared locks and noisy conflict notifications
  are not desired. Public Dell warranty web scraping should not be treated as
  the preferred automation path if TechDirect API access is available.
- Rationale: These answers reduce implementation ambiguity before code starts,
  especially around shared-file mutation and filestore boundaries.
- Tests/validation performed: Documentation-only change; no code exists yet.
  Verified current Dell public documentation for TechDirect API purpose and
  Dell Command Warranty automation behavior.
- Remaining risks or human decisions: Q-1 remains a recommendation unless
  Jeremy explicitly accepts the module layout; Q-2 output placement needs
  confirmation; Dell TechDirect access/key availability is unknown; operator
  update mechanism and group-tag list format remain open; migration need from
  old OneDrive-only data requires clarification.

### 2026-07-21 - Codex (local project directory rename)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool\AI-Audit-Decisions.md`
- Findings accepted: The primary local project directory is now
  `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool`.
- Findings rejected: The old `Inventory\Inventory Management Tools\Inventory Hash Management Tool`
  path is no longer the active project repository path.
- Rationale: Future implementation, planning, and handoff work should use the
  renamed MINT project folder and matching AI knowledgebase folder.
- Tests/validation performed: Verified the renamed local folder exists and
  contains `AI-Project-Plan.md`; verified the renamed AI knowledgebase folder
  exists and the old matching knowledgebase folder no longer exists.
- Remaining risks or human decisions: Existing artifact filenames still include
  `Inventory Hash Management Tool`; they remain historical unless Jeremy wants
  them renamed.

### 2026-07-21 - Codex (models.csv and Endpoint Inventory hash root)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: `models.csv` under the MINT `variables` folder is the
  formal model/folder map. Hash files live under
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory`, with singular
  hashes under `Hardware Hash Files`. Current device types map as `Desktop` ->
  `Desktops`, `Laptop` -> `Laptops`, and `GETAC` -> `Getacs`.
- Findings rejected: Hash files should not be assumed to live under the MINT
  external data/database root.
- Rationale: Tool variables and logs need their own MINT root, while the actual
  endpoint hash inventory has a separate operational root.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Default vendor batch input root and
  group-tag list format remain open.

### 2026-07-21 - Codex (depts.csv header schema clarification)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: `depts.csv` has a header row. D-022 later changed active
  prefix-column names to `Dept Prefix ##`; parser logic should use header names,
  trim values, allow blank prefix cells, and keep any legacy `N/A` as a
  no-prefix sentinel.
- Findings rejected: Positional-only parsing of `depts.csv` should not be the
  implementation contract.
- Rationale: Headers make the department mapping safer for manual maintenance
  and clearer for future code.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Other variable-list schemas remain open
  under Q-12.

### 2026-07-21 - Codex (depts.csv prefix header and blank prefix clarification)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: Active `depts.csv` prefix columns are `Dept Prefix 01`
  through `Dept Prefix 05`; most departments have only one prefix, so blank
  prefix cells are normal and ignored.
- Findings rejected: `N/A` must not be treated as a matchable prefix or as proof
  that blank-prefix, unknown-prefix, or misnamed devices belong to that
  department.
- Rationale: Department ownership comes from AD OU placement, not from naming
  prefixes, and the CSV should support departments with only one or no expected
  prefixes without fake matches.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Other variable-list schemas remain open
  under Q-12.

### 2026-07-21 - Codex (central per-user daily logging clarification)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: MINT application/error logs are centralized under
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\logs`;
  log filenames contain the run date and sanitized running user; one file per
  user account per day is appended across multiple runs.
- Findings rejected: The earlier tool-local `Error Logs\` location is superseded
  for MINT application/error logs.
- Rationale: Centralized per-user daily logs make it easier for Jeremy to
  collect diagnostics from other operators and identify whose report belongs to
  whom.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Log retention is not yet defined.

### 2026-07-21 - Codex (MINT name, data root, and AD department scope)

- Files reviewed:
  - `AI Knowledgebase\AGENTS.md`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: Product name is `MIS Inventory Navigation Tool (MINT)`;
  external data/database files live under
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\`;
  `depts.csv` lives under that root's `variables` folder; AD OU placement is
  authoritative for department ownership/location.
- Findings rejected: Device-name prefixes are not authoritative for ownership;
  `N/A` prefix rows must not match devices with missing or unknown prefixes into
  those departments.
- Rationale: MINT needs one shared data/configuration home while remaining a
  portable local tool, and AD placement better reflects actual department
  ownership than imperfect device names.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Migration timing, model/group-tag
  variable formats, and central-vs-local output placement still need
  confirmation.

### 2026-07-21 - Codex (Search and Manage model dropdown clarification)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: Search and Manage `Model` should be an editable dropdown backed by model display names. Typing exact or partial text refines the dropdown, and manufacturer text is optional for matching.
- Findings rejected: None.
- Rationale: Model search must handle formal manufacturer-prefixed names while allowing operators to type practical fragments such as `M70q`.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Model map/DeviceModel aliases must be designed during Phase 1.

### 2026-07-20 - Codex (Q-14 persistence decision)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: Q-14 is answered. V1 should rebuild the object graph in memory from raw hash files, folder paths, variable CSVs, and session lookup results; no continual database or persistent catalog is required.
- Findings rejected: A v1 database/service/always-running catalog is not needed for the current scope.
- Rationale: Raw files remain the authoritative storage surface, preserving portability and mobile/shared-data operation while still allowing object-centered behavior in memory.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Implement refresh and per-target revalidation before mutating indexed files.

### 2026-07-20 - Codex (domain object model clarification)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: The program should use a normalized shared domain object model across modules and tabs, with separate linked objects for serials, devices, models, manufacturers, hash files, warranty records, and field metadata.
- Findings rejected: None.
- Rationale: Tabs should work through shared objects and resolver/index functions so the same facts are reachable from different directions without duplicating or reinterpreting raw data.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Added Q-14 about in-memory object graph vs persistent catalog.

### 2026-07-20 - Codex (Batch Extract manufacturer folder clarification)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Findings accepted: Batch Extract destination folders include the manufacturer in the folder name; a ThinkPad T14 Gen 3 destination is `Laptops\Lenovo ThinkPad T14 Gen 3`, not model-only.
- Findings rejected: None.
- Rationale: The implementation must verify each extracted serial's manufacturer/model before filing; use hash decode first and warranty lookup when hash data is insufficient.
- Tests/validation performed: Documentation-only clarification; no code exists yet.
- Remaining risks or human decisions: Open questions in the project plan remain unchanged.

### 2026-07-20 - Codex (tab UI mockup image)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\Inventory Hash Management Tool - Tab Mockups.png`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
- Findings accepted: User requested a mockup image showing what each planned tab could look like.
- Findings rejected: None.
- Rationale: The project is still conceptual, so this is a non-binding visual planning mockup rather than an implemented UI specification.
- Tests/validation performed: Visually inspected the generated image for the six requested tabs and planned control groups.
- Remaining risks or human decisions: Open questions in the project plan remain unchanged.

### 2026-07-17 - Codex (project scope outline document)

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
- Files changed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\Inventory Hash Management Tool - Project Scope Outline.docx`
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
- Findings accepted: User requested a Word outline of the project scope so far, especially each tab and how it will function.
- Findings rejected: None.
- Rationale: The project is still conceptual, so the document is a scope outline rather than an implementation specification.
- Tests/validation performed: Verified `.docx` package entries and parsed `word/document.xml` successfully; document contains 166 paragraphs.
- Remaining risks or human decisions: Open questions in the project plan remain unchanged.

### 2026-07-17 - Codex

- Files reviewed:
  - `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool\AI-Audit-Decisions.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Handoff.md`
  - `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor\AI-Audit-Decisions.md`
- Files changed: Created this handoff and `AI-Audit-Decisions.md`.
- Findings accepted: None yet; conceptual observations only.
- Findings rejected: None yet.
- Rationale: Required project collaboration files were missing for the new project; initial conceptual review focused on likely conflict points before implementation.
- Tests/validation performed: Not applicable; no implementation exists yet.
- Remaining risks or human decisions: Resolve or intentionally defer the active risks above before implementation begins, especially before building mutating functions.
