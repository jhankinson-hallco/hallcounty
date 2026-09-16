# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-07-17 - Project Knowledgebase Location

- Decision: Track this project under `AI Knowledgebase\System Scripts\Inventory Management Tools\Inventory Hash Management Tool`.
- Status: Accepted; superseded by the renamed knowledgebase location in
  project plan D-025 on 2026-07-21.
- Evidence type: recommendation
- Rationale: The project repository is under `Inventory\Inventory Management Tools\Inventory Hash Management Tool`, and the existing shared knowledgebase already stores related inventory-tool work under `System Scripts\Inventory Management Tools`.
- Source or local evidence: `Inventory\Inventory Management Tools\Inventory Hash Management Tool\AI-Project-Plan.md`; existing `AI Knowledgebase\System Scripts\Inventory Management Tools\Hardware Hash Batch Extractor`.
- Recommended action: Historical only. Use the renamed knowledgebase folder
  from the 2026-07-21 local project directory decision unless Jeremy creates a
  dedicated `AI Knowledgebase\Inventory` category.

### 2026-07-20 - Batch Extract Manufacturer-Prefixed Model Folders

- Decision: Batch Extract destinations must use the device-type folder plus a
  preferred/formal model folder name that includes the manufacturer when that is
  the inventory folder convention. Example:
  `Hardware Hash Files\Laptops\Lenovo ThinkPad T14 Gen 3\<SERIAL>.csv`.
  The tool must not file extracted hashes into model-only folders such as
  `Laptops\ThinkPad T14 Gen 3`. For every extracted serial, the tool verifies
  manufacturer/model before choosing the destination folder. It uses decoded
  hash contents first when the hardware hash provides a confident match; if
  the hash data does not provide enough usable model information, it must run
  the warranty lookup pipeline before filing. If neither source can confidently
  map the serial to a known manufacturer-prefixed folder, the extracted file
  goes to Review Staging.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Existing and intended hash-library folders include the
  manufacturer in the folder name, and Batch Extract must file each serial
  into the exact inventory folder rather than a shortened model-only folder.
- Source or local evidence: User clarification on 2026-07-20; project plan
  D-014.
- Recommended action: Ensure `models.csv` includes manufacturer, formal
  folder/display `Model Name`, device type, and decoded/warranty `Model Number
  ##` aliases needed to normalize names from both hash decode and vendor lookup
  sources. Project plan D-023 defines this as `models.csv`; D-024 defines the
  hash library root and device-type folder mapping.

### 2026-07-20 - Normalized Domain Object Model Across All Modules

- Decision: Build the program around a normalized, shared domain object model
  rather than tab-specific flat rows or isolated script variables. Core modules
  expose and consume stable objects such as `SerialNumber`, `DeviceRecord`,
  `DeviceModel`, `Manufacturer`, `InventoryHashFile`, `WarrantyRecord`, and
  field/value metadata objects. A serial number and a device model are separate
  entities; many devices can link to one `DeviceModel`; one model number or
  decoded identifier links to one formal model name and one
  manufacturer-prefixed preferred folder/display name. Relationships must be
  navigable through shared resolver/index functions in both directions where
  useful, such as serial to model, model to serials, serial to warranty
  records, and warranty field to source metadata.
- Status: Accepted
- Evidence type: owner directive plus recommendation
- Rationale: Every tab needs the same inventory facts, model facts, warranty
  facts, and metadata. A normalized object layer prevents six separate
  interpretations of the same serial/model/warranty data and lets future
  features work through the same relationships.
- Source or local evidence: User clarification on 2026-07-20; project plan
  D-015.
- Recommended action: Implement the object layer in `Core.Domain.ps1` and
  `Core.DeviceRecord.ps1`. For v1, prefer simple PowerShell 5.1
  `PSCustomObject` / ordered-hashtable schemas with constructor and resolver
  helper functions unless Phase 1 proves custom classes are materially clearer.
  Keep flat CSV files as storage/import/export surfaces per the Q-14 decision;
  do not let tabs parse or mutate raw fields independently.

### 2026-07-20 - V1 Object Graph Rebuilt From Raw Files

- Decision: V1 will not build or require a continual database or persistent
  catalog. The normalized domain object graph is rebuilt in memory each session
  from the raw hash files, folder paths, variable CSVs, and any warranty lookup
  results requested during that session. The raw files remain the authoritative
  storage and exchange surface. The tool should scan once at startup, provide a
  manual `Refresh Inventory` action, and re-read/revalidate any specific target
  file immediately before a mutating operation such as fix, move, delete,
  overwrite, decommission, or batch filing. If the file changed since the
  session index was built, the tool should warn the operator and require refresh
  or review before proceeding.
- Status: Accepted
- Evidence type: owner directive accepting recommendation
- Rationale: The current inventory size and v1 scope do not justify a database,
  service, or always-running process. Rebuilding from raw files keeps the tool
  portable, works with local/mobile copies and shared filestore data, avoids
  sync conflicts from a second source of truth, and still supports the
  object-centered architecture through in-memory indexes.
- Source or local evidence: User accepted the recommendation for Q-14 on
  2026-07-20; project plan D-016.
- Recommended action: Defer any persistent catalog until a later requirement
  needs data that raw hash files and reports cannot naturally preserve, such as
  long-term warranty cache history, operator notes, manually confirmed model
  resolutions, or offline reconciliation between field copies and the master
  data tree.

### 2026-07-21 - Search And Manage Model Filter Is Searchable Editable Dropdown

- Decision: In Search and Manage, the `Model` filter is an editable drop-down
  / ComboBox, not a fixed plain text box and not a closed pick-list. Its items
  are the `Model Name` values from `models.csv` (project plan D-023). As the
  operator types,
  the drop-down is refined using case-insensitive normalized matching. Exact
  display-name matches and partial matches both work. Matching uses the
  manufacturer-prefixed display name plus generated/model-map aliases, and the
  manufacturer prefix is optional: typing `M70q` should match all relevant M70q
  generations such as `Lenovo ThinkCentre M70q Gen 3`, `Lenovo ThinkCentre M70q
  Gen 4`, and `Lenovo ThinkCentre M70q Gen 5`; typing `Lenovo M70q` should
  reach the same result set.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Operators know model fragments more often than exact formal
  folder names, and the inventory's formal names include manufacturer prefixes.
  Search should support fast narrowing without requiring the operator to know
  or type the manufacturer first.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-017.
- Recommended action: Add search-normalized fields or aliases to `models.csv`
  rows / `DeviceModel` objects. At minimum, build searchable keys from formal
  `Model Name`, manufacturer-stripped display name, model family, generation,
  populated `Model Number ##` values, decoded identifiers, and any future
  aliases maintained in VariablesRoot.

### 2026-07-21 - Product Name And MINT External Data Root

- Decision: The software display name is `MIS Inventory Navigation Tool`, with
  `MINT` as the short name. Project plan D-025 later records that the local
  planning repository was renamed to
  `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\`. The
  external data/database files used by MINT, which may be updated independently
  of the local program files, live under:
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\`.
  The folder spelling `Navagation` is intentional for the path contract and
  must be preserved exactly. Department variables are under
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\variables\`,
  including `depts.csv`; model variables also live there, including
  `models.csv` per project plan D-023.
- Status: Accepted
- Evidence type: owner directive
- Rationale: The tool should be portable locally while shared, frequently
  revised data/configuration files have one organizational home independent of
  any operator's OneDrive or local program copy.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-018.
- Recommended action: Keep one `$script:DataRoot` literal set to the finalized
  UNC path. Use project plan D-025 for the current local repository and AI
  knowledgebase folder names.

### 2026-07-21 - Active Directory Placement Is Authoritative For Department Ownership

- Decision: Add an Active Directory department/location facet to the shared
  device object model and Search and Manage tab. The domain is
  `hallcounty.org`. Computers may appear in the catch-all staging location
  `hallcounty.org/Computers`, or in the authoritative department tree under
  `hallcounty.org/Hall County Departments/<department subfolder>/Computers/`.
  Devices can exist directly in a department's `Computers` OU or in any
  recursive child OU below it. AD placement, not the device-name prefix, is the
  authority for department ownership and expected location.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Device names are imperfect and manually maintained. OU placement
  is the closest available source of truth for ownership/location, while
  prefixes remain useful naming-convention metadata.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-019.
- Recommended action: Load department mappings from
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\variables\depts.csv`.
  D-021/D-022 define the headered CSV schema. Blank prefix cells are normal and
  ignored. `N/A` is no longer required; if present as legacy data, it means no
  expected prefix exists for that department and must not match devices with
  blank, missing, unknown, or incorrect prefixes. If a device is in
  `hallcounty.org/Computers`, report staging/catch-all rather than
  department-owned. If AD is unreachable or unreadable, mark the AD fields
  unavailable/stale and allow non-AD inventory functions to continue.

### 2026-07-21 - Central Per-User Daily Application/Error Logs

- Decision: All MINT application/error logging writes to the shared logs folder
  under the MINT external data root:
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\logs`.
  This replaces the earlier tool-local `Error Logs\` location from project plan
  D-006. Log files are plain `.txt`, append-only, and named with the date first
  so a normal A-to-Z filename sort places newer daily files lower in the folder.
  Required filename pattern:
  `<yyyyMMdd>-MINT-Log-<SafeRunningUser>.txt`.
- Status: Accepted
- Evidence type: owner directive plus recommendation for exact filename pattern
- Rationale: Central logs make it easy for Jeremy to collect troubleshooting
  detail from other operators and to see which running account produced each
  log without asking each user to find a local file.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-020.
- Recommended action: Derive `<SafeRunningUser>` from the actual running
  Windows identity, preferably
  `[System.Security.Principal.WindowsIdentity]::GetCurrent().Name`, then replace
  `\`, `/`, and invalid filename characters with `_`. Example:
  `20260721-MINT-Log-HALLCOUNTY_jhankinson.txt`. There is only one file per
  running user account per calendar day. Multiple runs by that same account on
  the same day append to the same file and must never overwrite/truncate it.
  If the shared log path is unavailable, show that failure in the UI and do not
  silently redirect logs to a local path unless Jeremy later approves a fallback
  location.

### 2026-07-21 - depts.csv Uses A Headered Department Schema

- Decision: `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation
  Tool\variables\depts.csv` is a headered CSV. The original header names used
  `Dept Abbr. ##` for prefix columns.
- Status: Accepted; superseded in part by D-022 on 2026-07-21. The active
  prefix-column header names are `Dept Prefix ##`, not `Dept Abbr. ##`.
- Evidence type: owner directive
- Rationale: A headered schema is easier for people to maintain and makes the
  department map self-documenting instead of relying on hidden positional
  columns.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-021.
- Recommended action: See D-022 for the active header names and prefix-cell
  handling. The standing rule from this decision is to parse `depts.csv` by
  header name rather than raw column position.

### 2026-07-21 - depts.csv Uses Dept Prefix Columns And Blank Prefix Cells

- Decision: The active `depts.csv` prefix-column header names are
  `Dept Prefix 01`, `Dept Prefix 02`, `Dept Prefix 03`, `Dept Prefix 04`, and
  `Dept Prefix 05`. The full required v1 header values, after trimming, are:
  `Group Folder`, `Department Name`, `Dept Prefix 01`, `Dept Prefix 02`,
  `Dept Prefix 03`, `Dept Prefix 04`, and `Dept Prefix 05`.
- Status: Accepted
- Evidence type: owner directive
- Rationale: `Dept Prefix ##` matches the actual purpose of the columns better
  than `Dept Abbr. ##`, and most departments only have one prefix, so blank
  prefix cells are expected.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-022.
- Recommended action: Parse `depts.csv` by header name rather than raw column
  position. Trim header names and cell values so spaces after commas or
  Excel-style formatting do not break the map. `Group Folder` maps to the
  first-tier AD department OU folder, `Department Name` maps to the official
  department display name, and the `Dept Prefix ##` columns map to expected
  device-name prefixes. Blank prefix cells are normal and ignored. `N/A` is no
  longer required and should be removed from the CSV when practical. If `N/A`
  remains in legacy data, treat it as a no-prefix marker only, never as a
  matchable prefix and never as evidence that blank-prefix, unknown-prefix, or
  misnamed devices belong to that department.

### 2026-07-21 - models.csv Defines Formal Model Names And Model-Number Aliases

- Decision: `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation
  Tool\variables\models.csv` is the authoritative model map used to determine
  the formal model name and model folder destination for hash files. It is a
  headered CSV. The required v1 header values, after trimming, are:
  `Model Name`, `Manufacturer`, `Device Type`, `Model Number 01`,
  `Model Number 02`, `Model Number 03`, `Model Number 04`, `Model Number 05`,
  `Model Number 06`, `Model Number 07`, `Model Number 08`, `Model Number 09`,
  and `Model Number 10`.
- Status: Accepted
- Evidence type: owner directive
- Rationale: One editable CSV should own the mapping from decoded/warranty model
  identifiers to the formal model display name and final hash folder path.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-023.
- Recommended action: Parse `models.csv` by header name rather than raw column
  position. Trim header names and cell values. `Model Name` is the formal model
  display value used by Search and Manage. `Manufacturer` stores the normalized
  vendor. Project plan D-028 defines how `Manufacturer`, `Model Name`, and
  `Device Type` resolve to the exact model folder beneath the mapped
  device-type folder. `Device Type` is a controlled value currently expected to
  be `Desktop`, `Laptop`, or `GETAC`; more device types may be added later.
  `Model Number 01` through `Model Number 10` are aliases/model identifiers from
  hash decode, warranty lookup, or other model evidence; blank model-number
  cells are allowed and ignored. A decoded or warranty-supplied model number
  should match any populated `Model Number ##` field for that row.

### 2026-07-21 - Hash Library Root And Device-Type Folder Mapping

- Decision: Hash files are stored under the Endpoint Inventory root:
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory`. The singular hash
  library root is:
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Hardware Hash Files`.
  This is separate from the MINT external data/database root in project plan
  D-018.
- Status: Accepted
- Evidence type: owner directive
- Rationale: MINT variables/logs/configuration data and the actual hash-file
  inventory are separate shared data areas. Keeping them as separate configured
  roots prevents the program from assuming every shared file sits below the
  MINT data folder.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-024.
- Recommended action: Add `$script:HashInventoryRoot` beside `$script:DataRoot`
  in the path configuration block. Build hash destinations from
  `$script:Paths.HashLibraryRoot`, the `Device Type` value in `models.csv`, and
  the `Model Name` value in `models.csv`. Current device-type folder mapping:
  `Desktop` -> `Desktops`, `Laptop` -> `Laptops`, and `GETAC` -> `Getacs`.
  Example model folder:
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Hardware Hash Files\Getacs\GETAC B360 Gen 3`.
  Future device types require extending the mapping deliberately, not guessing
  a plural folder name.

### 2026-07-21 - Local Project Directory Renamed To MIS Inventory Navagation Tool

- Decision: The primary local project directory that contains `AI-Project-Plan.md`
  is now:
  `C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files\Inventory\Inventory Management Tools\MIS Inventory Navagation Tool`.
  The relative repository path is:
  `Inventory\Inventory Management Tools\MIS Inventory Navagation Tool\`.
  The folder spelling `Navagation` is the exact current directory name and must
  be preserved in local path references unless Jeremy renames it again.
- Status: Accepted
- Evidence type: owner directive plus local filesystem verification
- Rationale: The project folder now matches the MINT naming direction and should
  be the active location for future planning and implementation work.
- Source or local evidence: User clarification on 2026-07-21; local folder
  exists; project plan D-025.
- Recommended action: Use the renamed local project folder for all future code,
  project artifacts, and `AI-Project-Plan.md` edits. Keep the matching AI
  knowledgebase folder at
  `AI Knowledgebase\System Scripts\Inventory Management Tools\MIS Inventory Navagation Tool`
  so future sessions follow the AGENTS.md matching-project rule. The product
  display name remains `MIS Inventory Navigation Tool (MINT)` even though the
  local folder name uses `Navagation`. Historical work-log references and
  existing artifact filenames containing `Inventory Hash Management Tool` may
  remain historical unless Jeremy requests cleanup/renaming.

### 2026-07-21 - Backup And Report Retention Comes From Variables

- Decision: Backups and reports default to 180-day retention. The value is kept
  in the MINT variables folder, counted in days, with `0` meaning keep forever.
  Project plan D-026 proposes
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\variables\retention.csv`
  with `Item,Retention Days` rows such as `Backup,180` and `Report,180`.
- Status: Accepted
- Evidence type: owner directive plus recommendation for a simple CSV settings
  file
- Rationale: Jeremy needs retention adjustable without code edits while limiting
  filestore growth.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-026.
- Recommended action: Trim and validate retention settings at startup. Reject
  negative/non-numeric values and report malformed settings.

### 2026-07-21 - Legacy Tools Remain Until MINT Is Complete

- Decision: Legacy/source tools remain in place until MINT is complete and
  parity has been proven. They can be used in the interim and as reference code
  if the approach fits MINT scope and design. Sunsetting them is deferred until
  after MINT completion.
- Status: Accepted
- Evidence type: owner directive
- Rationale: The legacy tools are standalone and currently useful; removing them
  early creates avoidable operational risk.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-027.
- Recommended action: Do not archive or modify legacy tools as part of MINT
  unless Jeremy separately requests it.

### 2026-07-21 - Batch Extract Creates Verified Missing Model Folders

- Decision: Batch Extract automatically creates a missing destination folder
  when model resolution is verified from `models.csv`. The intended path shape
  is `Hardware Hash Files\<Mapped Device Type Folder>\<Manufacturer> <Model Name>\`.
  D-039 finalizes this as the only hardware-hash folder naming contract.
- Status: Accepted
- Evidence type: owner directive plus conflict-prevention recommendation
- Rationale: Verified model-map data is sufficient to create the folder, while
  unknown models still need Review Staging.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-028.
- Recommended action: Create folders only after confident resolution. Never
  create guessed folders for unknown/unverified models. If legacy `models.csv`
  data already has manufacturer text inside `Model Name`, normalize or correct
  that value before folder creation so MINT never creates or accepts a doubled
  manufacturer prefix.

### 2026-07-21 - Upload Builder Metadata Override Model

- Decision: Upload Builder should support Group Tag and Assigned User override
  behavior for now, while keeping pass-through/copy mode, override mode,
  clear-field behavior, and future UI toggles easy to expose later.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Jeremy may want this feature enabled/disabled later; modeling it
  as an explicit mode prevents a rewrite.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-029.
- Recommended action: Keep metadata handling separate from the CSV writer and
  represent it as a mode/options object.

### 2026-07-21 - Short File Locks With Pre-Write Revalidation

- Decision: Files are locked only during active read/write I/O. Read results may
  remain cached in memory after the handle closes. Before a write, MINT locks
  the target, revalidates against cached pre-change state, writes only if still
  valid, then unlocks immediately. Notify only on an actual pre-write mismatch.
- Status: Accepted
- Evidence type: owner directive
- Rationale: This protects shared files without long locks or noisy conflict
  prompts.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-030.
- Recommended action: Use optimistic concurrency per target, with lightweight
  file/content fingerprints and parsed-content validation before writing.

### 2026-07-21 - Default Vendor Batch Input Root

- Decision: The default vendor batch input root is
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Vendor Supplied Hardware Hash Batch Lists`.
  Subdirectories may exist and no stable subfolder naming schema should be
  assumed.
- Status: Accepted
- Evidence type: owner directive
- Rationale: The storage root is known, but lower-level organization is not.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-031.
- Recommended action: Use this as the default file-picker root. Do not hardcode
  subfolder names.

### 2026-07-21 - Filestore Distribution Copy Is Read-Only To AI/Dev Work

- Decision: Software distribution files will be kept at
  `\\hallcounty\filestore\mis\MIS\Intune\MIS Inventory Navagation Tool\MINT Application\MIS Inventory Navagation Tool`.
  AI/development work must not write there. The active scripting repository
  remains Jeremy's OneDrive project folder.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Distribution belongs on the filestore, but development traffic
  should stay out of that location unless Jeremy explicitly requests a release
  copy.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-032.
- Recommended action: Treat the distribution root as read-only/reference until
  a human-approved release step.

### 2026-07-21 - Getac Warranty Should Be Automated If Possible

- Decision: Getac warranty lookup should be automated if technically possible.
  If endpoint investigation proves it cannot be scripted reliably, Getac may
  remain web-assist only.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Automation is preferred, but a brittle or anti-automation-dependent
  workflow should not be built into the tool.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-033.
- Recommended action: Investigate Getac's warranty request flow during the
  vendor lookup phase and implement only if deterministic.

### 2026-07-21 - Decommission Moves Files And Appends Master CSV

- Decision: Decommissioned hash files move to
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Decommissioned Devices\<Current Year>\`.
  The master list is
  `\\hallcounty\filestore\mis\MIS\Intune\Endpoint Inventory\Decommissioned Devices\Decommissioned Devices Master List.csv`
  with fields `Device Serial Number`, `Decommission Username`, `Year`,
  `Month/Day`, `Manufacturer`, `Model Name`, `Last Known Department`, and
  `Last Known User`.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Moving files preserves decommissioned hash records while keeping
  the active library clean; the CSV schema leaves room for future metadata.
- Source or local evidence: User clarification on 2026-07-21; project plan
  D-034.
- Recommended action: Append one CSV row per decommission action, filling known
  fields and leaving unknown fields blank.

### 2026-07-21 - Multi-File Modules Layout Confirmed

- Decision: MINT uses the multi-file, dot-sourced `Modules\` layout shown in
  the project plan, with shared `Core.*.ps1` services and per-tab `Tab.*.ps1`
  files. It should not be built as one monolithic `.ps1`.
- Status: Accepted
- Evidence type: owner directive confirming a recommendation
- Rationale: The module layout is more reliable and scalable for review,
  testing, future edits, and parallel AI work.
- Source or local evidence: User answer to Q-1 on 2026-07-21; project plan
  D-035.
- Recommended action: Keep shared parsing, inventory, lookup, backup, and UI
  helpers in core modules; keep tab-specific behavior in tab modules.

### 2026-07-21 - Pursue Dell TechDirect API Access

- Decision: Dell warranty/model automation should use Dell TechDirect Warranty
  Management API access if Hall County can obtain it. The public Dell warranty
  site is manual web-assist only and must not be treated as a dependable
  scripted lookup target.
- Status: Accepted; API key acquisition remains outside implementation scope
- Evidence type: owner directive plus live/vendor documentation checks
- Rationale: Dell public warranty lookup showed anti-automation blocking during
  prior live checks; the supported programmatic route requires TechDirect
  OAuth2 credentials.
- Source or local evidence: User answer to Q-4 on 2026-07-21; project plan
  D-036.
- Recommended action: Build a Dell provider only once Client ID/Secret material
  exists. Do not store secrets in plaintext scripts or unprotected shared CSVs;
  choose a credential storage design later when real credentials exist. See
  D-044 before defining Dell-specific returned fields or exact value mappings.

### 2026-07-21 - Manual Operator Update Distribution

- Decision: MINT v1 has no launch-time self-update check and no push update
  mechanism. Operators manually retrieve the latest program copy from the
  filestore distribution source when they want the current version.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Avoids building update/version-check machinery before the core
  tool is proven.
- Source or local evidence: User answer to Q-10 on 2026-07-21; project plan
  D-037.
- Recommended action: Show MINT's program version prominently in the window
  title or status bar so operators can compare their copy to the distribution
  source.

### 2026-07-21 - All Generated Outputs Are Central On The Filestore

- Decision: Backups, Reports, Review Staging, and Upload Lists are all central
  under the MINT data root. No MINT v1 generated data output is tool-local.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Central output lets any operator or Jeremy audit, restore, or
  review generated files regardless of which machine produced them.
- Source or local evidence: User answer to Q-2 on 2026-07-21; project plan
  D-038.
- Recommended action: Keep `$script:ProjectRoot` for program files only. Use
  `$script:DataRoot` for generated output folders.

### 2026-07-22 - Hardware Hash Folders Always Use Manufacturer Plus Model Name

- Decision: Every hardware hash model folder uses
  `<Manufacturer> <Model Name>` under the mapped device-type folder. Examples:
  `Hardware Hash Files\Laptops\Lenovo ThinkPad T14 Gen 3\` and
  `Hardware Hash Files\Getacs\GETAC B360 Gen 3\`.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Prior wording left a contract conflict between model-only folder
  names, manufacturer-prefixed examples, and duplicate-prefix avoidance.
- Source or local evidence: User clarification on 2026-07-22; project plan
  D-039.
- Recommended action: Maintain `Model Name` in `models.csv` as the model-only
  segment whenever practical, generate the resolved display/folder value from
  `Manufacturer` plus `Model Name`, and normalize/flag any legacy row that
  already includes the manufacturer so doubled prefixes are never created.

### 2026-07-22 - Decommission Collisions Use Newest-Wins Plus Restore

- Decision: If a decommission move collides with an existing decommissioned
  file or master-list row, MINT compares version evidence, shows a confirmation
  screen, and defaults to preserving the newest version. Overwriting still
  requires confirmation.
- Status: Accepted
- Evidence type: owner directive plus implementation recommendation
- Rationale: Decommission is destructive from the active-library perspective,
  and serial collisions are already known to exist.
- Source or local evidence: User clarification on 2026-07-22; project plan
  D-040.
- Recommended action: Add a Restore action for decommissioned devices. Restore
  runs warranty/model lookup, moves the hash back to
  `Hardware Hash Files\<Mapped Device Type Folder>\<Manufacturer> <Model Name>\`,
  removes the device from the decommission master list after short-lock
  revalidation, and logs/reports the action.

### 2026-07-22 - Migration Timing Remains Owner-Deferred

- Decision: Migration timing is intentionally deferred. MINT planning should
  not invent a migration schedule or data-copy workflow until Jeremy resolves
  that timing.
- Status: Accepted / on hold
- Evidence type: owner directive
- Rationale: The roots are finalized, but copying any legacy OneDrive-only data
  into those roots is an operational timing decision.
- Source or local evidence: User clarification on 2026-07-22; project plan
  D-041.
- Recommended action: Build against the finalized roots and add migration
  handling only if Jeremy later identifies source data that needs a controlled
  move.

### 2026-07-22 - HP And Getac Warranty Automation Findings

- Decision: HP should use the official HP Warranty API path for reliable
  fleet-scale automation if Hall County can obtain access. The public HP
  warranty page remains manual/web-assist unless HP provides a supported public
  automation contract. HP CMSL `Get-HPWarrantyInfo` retrieves warranty data for
  the current HP PC only and does not solve arbitrary serial lookup for MINT.
- Decision: Getac does not currently require a separate Dell-style API for the
  tested path. The public form accepted a direct POST to `txtSNs` with serial
  `RRB03B2021` and returned a result containing that serial and model `B360G3`.
- Status: Accepted as current planning evidence
- Evidence type: live web check plus official vendor documentation
- Rationale: HP has a supported API path and a less stable public-app surface;
  Getac behaved like a deterministic server-side form post for the supplied
  test serial.
- Source or local evidence: Live checks on 2026-07-22; HP Warranty API
  documentation; HP CMSL documentation; Getac warranty form; project plan
  D-042.
- Recommended action: Keep HP behind an API-provider design with credential
  handling decided later. See D-044 before defining HP-specific returned fields
  or exact value mappings. Build Getac as a standard HTTP form provider first,
  with parser validation against more serials and a web-assist fallback.

### 2026-07-22 - Getac Parser Only Captures SN, Model, And Warranty Expiration Date

- Decision: For Getac warranty lookup results, the only fields relevant to MINT
  are `SN`, `Model`, and `Warranty Expiration Date`.
- Status: Accepted
- Evidence type: owner directive
- Rationale: The Getac page includes extra actions and page content, including
  service request links, parts ordering, show-config details, battery warranty
  text, brochure links, and other warranty descriptions. Those do not support
  MINT's current inventory-management scope.
- Source or local evidence: User clarification on 2026-07-22; project plan
  D-043.
- Recommended action: Parse row-scoped result data for exactly those three
  fields. Ignore all other Getac page content unless Jeremy later expands the
  scope.

### 2026-07-22 - Dell And HP API Fields Are Deferred Until Real Payloads

- Decision: Do not speculate on Dell or HP warranty API result fields, exact
  field names, value shapes, or field availability until Hall County has the
  relevant API access and MINT can inspect real response payloads.
- Status: Accepted
- Evidence type: owner directive
- Rationale: Public pages, third-party examples, broad API descriptions, and
  guesses are not enough to define the exact Dell/HP data contract MINT should
  depend on.
- Source or local evidence: User clarification on 2026-07-22; project plan
  D-044.
- Recommended action: Keep Dell and HP as deferred/API-backed provider slots.
  The shared `WarrantyRecord` object may keep generic optional fields such as
  serial, manufacturer, model, source, warranty start, and warranty
  end/expiration, but Dell/HP-specific mapping, display labels, validation, and
  unavailable-field behavior must wait for real API credentials and sample
  payloads.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.
