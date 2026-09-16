# Shared AGENTS.md - Hall County MIS Intune AI Knowledgebase

## Purpose

This is the shared instruction file for AI assistants working anywhere under:

```text
C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files
```

It combines the prior Codex `AGENTS.md`, Claude `CLAUDE.md`, copied memory files,
and PowerShell 5.1 audit standards into one compact operating contract.

This file is intentionally a control plane, not a giant knowledge dump. Read this
file first, then read only the project handoff/decision files and targeted
reference files needed for the task.

## Authority And Conflict Resolution

- If instructions conflict, prefer the rule most compatible with:
  1. Hall County tenant constraints
  2. Intune Management Extension execution reality
  3. Autopilot / White Glove reliability
  4. Windows PowerShell 5.1 compatibility
  5. Deterministic detection and repeatability
  6. Simplicity over cleverness
- Do not hide uncertainty. Label facts as:
  - proven from logs/code/docs
  - likely inference
  - recommendation
- Prefer the real target runtime over theory. For PowerShell, local
  `powershell.exe` 5.1 validation beats memory and generic documentation.
- Prefer current Microsoft documentation for rules, support boundaries, CSPs,
  Intune behavior, and Windows behavior. When docs are incomplete, clearly label
  the workaround and require target-build proof.

## Required Read Order Before Project Work

Before auditing, editing, packaging, or reviewing any project:

1. Read this file:

```text
.\AI Knowledgebase\AGENTS.md
```

1. Locate the matching project knowledge folder:

```text
.\AI Knowledgebase\<Software or System Scripts>\<Project Folder>\
```

Examples:

```text
.\AI Knowledgebase\Software\Microsoft Office 365\
.\AI Knowledgebase\System Scripts\Device Branding\
```

1. Read these project files if they exist:

```text
AI-Audit-Handoff.md
AI-Audit-Decisions.md
```

1. If either project file is missing, create it from the template pattern in this
   file before making substantive edits.

1. For audits and PowerShell/Intune work, read the compact memory index:

```text
.\AI Knowledgebase\MEMORY.md
```

Then read only the targeted reference files listed there that match the task.

## PDQ / Intune Tandem Deployment Standard (Ecosystem-Wide)

These rules apply to EVERY deployment project that has (or gains) a PDQ
counterpart, and to all future PDQ scripting:

1. **Tandem parity is mandatory.** PDQ and Intune deployments of the same item
   must leave the device in an identical state. Every detection artifact -
   files, marker files, registry values, versions, log locations - must be
   mirrored exactly so Intune detection cannot tell whether Intune or PDQ
   performed the install. When either side's on-device footprint changes,
   update BOTH sides in the same change and record it in the project handoff.
2. **Filestore hygiene.** Only deployment payload FILES (installers, shortcuts,
   icons, media) reside on the filestore. Scripts and markdown documentation
   stay in the local `PDQ` subfolder of the project. Do not run development,
   validation, or exploratory commands against the filestore; keep share
   access to the absolute minimum (ideally zero during development) to avoid
   triggering EDR/Defender response on the server.
3. **Channel boundaries.** Only PDQ scripts may reach the filestore. Intune
   scripts must rely exclusively on files bundled inside their `.intunewin`
   package. Intune platform scripts that pull from network shares are
   deprecated.
4. **PDQ script conventions.** Name scripts `<Verb>-<Name>-PDQ.ps1`, start at
   version `1.0.0`, and note the Intune counterpart script and version in
   `.NOTES` (update that reference when the Intune side bumps). Prefer ONE
   script per PDQ install package; uninstall is a separate script/package.
   Install steps that read the filestore must run as the PDQ Deploy User
   (Local System has no share access). Write to the same IME-rooted log files
   as the Intune counterpart, tagging entries `[PDQ]`.
5. **PDQ marker parity is mandatory, even before an Intune counterpart
   exists.** Every PDQ deployment package includes a dedicated, minimal
   companion script whose only job is writing/updating the PDQ marker
   (`C:\ProgramData\PDQ\AppMarkers\<AppName>.marker`, `Version=` line per
   the marker-versioning policy in "IME Runtime Paths" below) - required
   even for PDQ-only software with no Intune deployment yet, so a future
   Intune deployment immediately recognizes the already-installed state
   instead of reinstalling. This directly reduces accidental
   reinstallation when a device is added to Intune, when PDQ is used to
   force an install on an Intune-managed device, or when PDQ-only
   software later gains an Intune counterpart. Name it
   `Set-<AppName>Marker-PDQ.ps1`, keep it in the project's `PDQ\`
   subfolder, run it as the LAST step of the PDQ package (after the real
   install/uninstall step succeeds). It must remove any pre-existing PDQ
   marker before writing the new one - never rely on silent overwrite.
   Keep its hardcoded version constant in sync with the actual
   bundled/deployed installer version every time the PDQ package updates -
   same discipline as Intune's Install/Detect version sync. Full template:
   `reference_intune_code_patterns.md`.
6. **Shared shortcut repository** (used by all shortcut deployments, standalone
   and packs):

```text
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Icons
```

## Token Discipline

- Do not reread every reference file on every request.
- Always read the active project handoff and decisions.
- Use `MEMORY.md` as the reference index.
- Load full references only when the task touches that topic.
- Keep `AI-Audit-Handoff.md` as a living summary, not an append-only transcript.
- Move old verbose notes into the project `Archive` folder after stabilization.
- Error reduction has priority over token minimization. If a reference is likely
  to prevent a deployment failure, read it.

## User And Environment

- Engineer: Jeremy Hankinson
- Organization: Hall County Georgia MIS
- Primary work: Microsoft Intune / Entra / hybrid Windows deployment
- Default tenant constraints:
  - Microsoft Graph access is blocked or unavailable unless Jeremy explicitly
    authorizes it.
  - Do not design deployment logic around Graph.
  - Do not assume cloud-only join.
  - Do not assume devices can self-rename in Active Directory.
  - Do not assume on-prem domain resources are reachable during White Glove.
  - Do not assume a logged-on user exists during device-targeted deployment.
  - Do not assume user profile paths are valid in SYSTEM context.
  - Company Portal may be allowed; Microsoft Store may be blocked.
  - Fleet can include Windows 11 Pro, Windows 10 Pro, and Windows 10 LTSC
    including older builds such as 1809.
  - Licensing context may be Microsoft 365 G3 GCC.
- Device naming convention is typically:

```text
<department initials>-<%SERIAL%>
```

- Common Intune group naming:

```text
DEV - <dept initials> - <device type>
DEV_USER - <dept initials> - <device type>
```

## Working Style

- Be practical, direct, and outcome-focused.
- Treat reliability as more important than cleverness.
- Make strong recommendations when the evidence is clear.
- Say clearly when an idea is weak, brittle, unsupported, or likely to fail.
- Avoid long troubleshooting fishing expeditions when the root pattern is clear.
- Prefer complete working deliverables over snippets.
- Preserve unrelated user changes.
- Do not silently change architecture. Explain meaningful architecture changes.
- Do not use Graph, cloud polling, domain polling, interactive auth, or remote
  dependencies in deployment scripts unless explicitly requested and justified.

## PowerShell 5.1 Production Standard

All production PowerShell intended for Intune or endpoint deployment defaults to:

```powershell
#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Required practices:

- Target Windows PowerShell 5.1 unless the project clearly requires otherwise.
- Validate syntax with Windows PowerShell, not PowerShell 7:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('C:\Path\Script.ps1', [ref] $tokens, [ref] $errors) | Out-Null; $errors"
```

- Use full cmdlet names, not aliases.
- Use approved Verb-Noun names for reusable functions.
- Use explicit named parameters in production scripts.
- Prefer `Get-CimInstance` over `Get-WmiObject`.
- Avoid `Invoke-Expression`.
- Avoid empty `catch` blocks.
- Use `try` / `catch` around meaningful failure boundaries.
- Use `-ErrorAction Stop` on operations whose failure must be caught.
- Prefer `-LiteralPath` for exact file and registry paths.
- Exception: `New-Item` in Windows PowerShell 5.1 does not support
  `-LiteralPath`. Use `New-Item -Path ...` for `New-Item`, or use .NET APIs such
  as `[System.IO.Directory]::CreateDirectory()` when avoiding PowerShell path
  binding entirely is important.
- Guard missing registry properties under StrictMode with:

```powershell
$object.PSObject.Properties['PropertyName']
```

- Do not use PowerShell 7-only syntax or parameters, including:
  - `??`, `??=`, `?.`
  - ternary operator
  - `&&`, `||`
  - `ForEach-Object -Parallel`
  - `ConvertFrom-Json -AsHashtable`
  - `Join-Path -AdditionalChildPath`
  - common parameters added after Windows PowerShell 5.1 such as
    `-ProgressAction`
- Do not use `if` as an expression in PS 5.1, such as:

```powershell
exit (if ($x) { 0 } else { 1 })
```

### Encoding

For Intune-deployed PowerShell scripts:

- Save as UTF-8 with BOM.
- Keep script content ASCII-only, including comments.
- Do not use em dashes, smart quotes, arrows, ellipses, or non-ASCII symbols.
- Verify before packaging:

```powershell
$bytes = [System.IO.File]::ReadAllBytes('.\Script.ps1')
$hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$content = [System.IO.File]::ReadAllText('.\Script.ps1', [System.Text.Encoding]::UTF8)
$nonAscii = 0
foreach ($c in $content.ToCharArray()) {
    if ([int]$c -gt 127) { $nonAscii++ }
}
"BOM=$hasBOM  NonASCII=$nonAscii"
```

Expected:

```text
BOM=True  NonASCII=0
```

## Intune Win32 App Defaults

- Use Win32 app packaging by default for installs, removals, machine
  configuration, detection, dependencies, uninstall logic, return-code control,
  restart control, or White Glove blocking.
- Use Intune PowerShell platform scripts only for lightweight configuration that
  does not require detection, dependency handling, uninstall behavior, or complex
  restart handling.
- Use device context by default.
- Use user context only when the action truly depends on the current user and is
  safe after sign-in.
- Use 64-bit PowerShell by default for system/device work on 64-bit Windows.
- Portal install/uninstall commands that require 64-bit PowerShell should use:

```text
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe
```

- Detection script setting should be:

```text
Run script as 32-bit process on 64-bit clients: No
```

unless the package intentionally targets 32-bit locations.

## IME Runtime Paths

Current standard: all new script-created Intune runtime files must live under
the Intune Management Extension root:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension
```

Use these subfolders:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
C:\ProgramData\Microsoft\IntuneManagementExtension\Images
C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles
```

Rules:

- Use stable machine paths for assets needed after IME extraction cleanup.
- Do not detect temp folders, IME cache, extraction folders, or package cache.
- Log only on error unless Jeremy asks for verbose logging.
- All script-authored Intune deployment logs belong in
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- New marker files belong in
  `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers`.
- New images, icons, wallpapers, and lock screen files belong in
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`.
- New durable script data, helper scripts, prefix files, config files, shell
  layout files, and similar non-image runtime files belong in
  `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles`.
- Use a package-specific subfolder under `Images` or `ScriptFiles` when multiple
  files are staged or when names could collide.
- Scripts under the workspace `Software` directory use log names:
  `APP_<AppName>_Install.txt` and `APP_<AppName>_Uninstall.txt`.
- Scripts under the workspace `System Scripts` directory use log names:
  `SCRIPT_<ScriptName>_Install.txt` and `SCRIPT_<ScriptName>_Uninstall.txt`.
- Detection scripts must check the current IME-rooted path first. If not found,
  they may check legacy paths next for backward compatibility with already
  deployed packages.
- **Markers must carry a version (2026-08-20 policy)**, not just exist: a
  `Version=` line, using the real software version or - if unavailable - the
  file's download date (`yyyy-MM-dd`). PDQ deployments write their own
  marker at `C:\ProgramData\PDQ\AppMarkers\<AppName>.marker`; Intune's own
  marker is always authoritative once it exists, and an Intune install must
  delete any PDQ marker for the same app once it completes. A marker with no
  `Version=` line (pre-policy or legacy) is accepted as detected for now -
  temporary migration leniency, not permanent. Full templates and functions:
  `reference_intune_detection.md`, `reference_intune_code_patterns.md`.
- **Every uninstall script removes ALL marker tiers for its app (2026-08-20
  policy)**, not just the one its own channel writes: the current Intune
  marker, the PDQ marker, AND any legacy-location marker. This applies to
  every uninstall script, Intune and PDQ alike - a PDQ uninstall must also
  remove the Intune marker (and vice versa), so a real uninstall never
  leaves any marker behind that could falsely satisfy a future detection
  run regardless of which channel originally wrote it or which channel
  performed the removal.
- Legacy paths are fallback-only for new work:
  `C:\IntuneAppMarkers`, `C:\IntuneDeploymentFiles`,
  `C:\IntuneDeploymentFiles\Images`, `C:\IntuneScripts`,
  `C:\ProgramData\HallCountyMIS`, `C:\IntuneAppLogs`, and
  `C:\IntuneScriptLogs`.
- `C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles` is NOT
  legacy (corrected 2026-08-26 - see `reference_intune_paths.md`). It is
  the current, active location for a plain-text device-identification file
  that a paired `Detect.ps1` reads directly (e.g. `DevicePrefix.txt` for
  Device Rename, `Serial - <SERIAL>.txt` for Serial Marker). Use
  `ScriptFiles` instead for durable script data, helper scripts, and config
  files that are not themselves the detection artifact.

## Detection Standard

- Detection must prove the intended end state, not just that the installer ran.
- Use native Intune detection first when it proves the state.
- Use custom PowerShell detection only when needed.
- Custom detection success requires both:
  - exit code `0`
  - STDOUT output via `Write-Output`
- Do not use `Write-Host` in detection scripts.
- Marker files are acceptable when software evidence is unreliable or the
  payload is script-only/configuration-only.
- Markers should be version-stamped when package version gates redeployment.
- Detection scripts must be fast, idempotent, and side-effect free.

## Versioning Standard

- New scripts start at `1.0.0`.
- Bump the script version for each revision.
- When an install script version changes, immediately check and update:
  - install script `.NOTES Version`
  - install script `$script:AppVersion` or equivalent
  - `Detect.ps1` `$script:RequiredScriptVersion`
  - `Detect.ps1` `.NOTES Version`
  - uninstall script `.NOTES Version`
  - uninstall script `$script:AppVersion`
  - helper script versions when detection or logs depend on them
  - changelog entries
- If detection reads a marker version, the marker writer and detection version
  must match exactly.

## Packaging Standard

- **Do not build `.intunewin` packages.** Packaging is always performed manually
  by Jeremy when scripts are ready. Never run IntuneWinAppUtil.exe or equivalent.
  Treat packaging as a human step that happens after all script work is complete.
- Validate scripts before packaging (parse, BOM/encoding, version sync).
- Delete or move any existing `.intunewin` from the source folder before
  rebuilding, or output the package to a folder outside the source tree.
- Never package AI notes, audit files, archives, stale packages, logs, or
  reference-only clutter into the Intune payload.
- Confirm install command, uninstall command, detection script, version marker,
  and package artifact are synchronized.

## Portal Metadata Standard

For Intune app packaging work, include or maintain these portal fields:

1. Name
2. Description
3. Publisher
4. App Version
5. Category or categories
6. Informational URL
7. Privacy URL
8. Developer
9. Install command
10. Uninstall command
11. Installation time required
12. Install behavior
13. Device restart behavior
14. Additional return codes
15. Detection rule

For in-house scripts:

```text
Publisher: Hall County MIS
Informational URL: https://www.hallcounty.org/
Privacy URL: https://www.hallcounty.org/
Developer: Hall County MIS
```

## Exit Code Policy

For Intune Win32 apps and deployment scripts:

| Code | Meaning |
| ---- | ------- |
| `0` | Success |
| `3010` | Success, reboot required |
| `1605` | MSI: product not installed (safe idempotency) |
| `1614` | MSI: product uninstalled |
| `1641` | MSI: reboot initiated |

Rules:

- Use only deliberate, meaningful non-zero exit codes.
- If wrapping a native installer, capture its exit code explicitly and map it intentionally.
- Do not rely on `$?` alone to determine native process success.
- Do not swallow a failing native process exit code.

## White Glove and Autopilot Safety

The technician phase (White Glove pre-provisioning) runs in SYSTEM context before any user has logged in. The following must succeed without network dependencies that may be unavailable.

**Safe during technician phase:**

- Silent machine-wide installs from the package
- HKLM registry configuration
- File copy from the package
- Service and scheduled task setup
- Local marker file creation
- Offline-friendly configuration

**Unsafe during technician phase:**

- Reading future user `%LOCALAPPDATA%` or profile paths
- Interactive authentication to any service
- Waiting on domain controller, cloud service, or assigned-user state
- On-prem share or OU logic that requires domain controller access
- Long polling loops waiting on remote conditions
- Mixing Win32 and LOB apps on the same device unless tested specifically for that workflow

## Prohibited Deployment Patterns

Banned by default unless Jeremy explicitly authorizes an exception for a specific request:

- `Connect-MgGraph` or any Microsoft Graph authentication in device scripts
- Azure app registration dependencies in install/uninstall/configuration logic
- Scripts requiring devices to self-write back to Active Directory
- Cloud-only Entra join assumptions in deployment logic
- Scripts assuming White Glove technician flow has immediate domain controller access
- Interactive end-user approval or sign-in during technician flow
- Plaintext credential storage in deployment logic (unless Jeremy explicitly accepts the risk)
- Embedded secrets without documented justification

## .NOTES Standard

Use this structure for new scripts (campus-wide, 2026-09-08 policy):

```powershell
.NOTES
    Version:        1.0.0
    Script Type:    Microsoft Intune <Script or Win32 App>
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  DD/MM/YYYY
    Purpose:        One-line summary of what the script does

    ERROR CODES
      0    = Success
      3010 = Success, reboot required (when applicable)
      1    = Unexpected/unhandled error (fallback catch-all)

    CHANGE LOG
    Change: DD/MM/YYYY - Initial release -- ver. 1.0.0
```

**ERROR CODES placement and content (campus-wide, 2026-09-08 policy):** the
`ERROR CODES` section sits immediately below `Purpose` and above `CHANGE LOG`
in every script's `.NOTES` block - this supersedes the older `RETURN CODES`
section that some existing scripts still carry after `CHANGE LOG`/`INTUNE
CONFIGURATION`. It must list every exit code the script itself can return,
not just the universal `0`/`3010`/`1` defaults shown above. When a script
needs multiple distinct failure codes for diagnosis (recommended for any
Win32 app install/uninstall script with more than one meaningful failure
point), assign it its own numeric range - e.g. `1601-1699`, `1701-1799` -
and give each code a one-line meaning. Do not reuse another project's range.
A code that is logged but does not itself cause an exit (e.g. a non-fatal
warning) may still be listed here; note that it is non-fatal / logged-only.
This is a documentation-and-template policy, not a mandate to immediately
retrofit every already-existing script - apply it to a script the next time
that script is otherwise touched, same as other incremental policies in this
file (see the marker-versioning migration leniency above).

## Audit Standard

When Jeremy asks for an audit, use a code-review stance:

1. Findings first, severity ranked.
2. Critical / High / Medium / Low grouping when useful.
3. File and line references.
4. Separate proven facts, likely inferences, and recommendations.
5. Check direct code defects and architecture/design defects.
6. Check syntax, runtime context, permissions, paths, race conditions, logging,
   return codes, detection, uninstall/rollback, and packaging.
7. For PowerShell, verify PS 5.1 compatibility with local `powershell.exe`.
8. If changes are requested, provide complete revised files or make the edits
   directly. Do not provide partial snippets when full code is expected.

## Reference Selection Matrix

Always read `MEMORY.md` for audits and script work. Then use these references:

- Any PowerShell audit or edit:
  - `PowerShell-5.1-Official-Reference.md`
  - `feedback_ps_auditor_standard.md`
  - `feedback_script_encoding.md`
  - `feedback_version_sync.md`
- Intune Win32 apps:
  - `reference_script_dev_methodology.md`
  - `reference_intune_detection.md`
  - `reference_intune_contexts.md`
  - `reference_intune_paths.md`
  - `reference_intune_code_patterns.md`
  - targeted sections of `reference_intune_pitfalls.md`
- External `.exe` installer packages:
  - `reference_exe_template.md`
- Logs or failed deployments:
  - `reference_log_triage.md`
  - targeted sections of `reference_intune_pitfalls.md`
- Architecture, 32-bit/64-bit, SysNative, AppX:
  - `reference_ps_architecture.md`
- Registry provider `Set-ItemProperty -Type` questions:
  - `reference_ps51_set_itemproperty.md`
- Scheduled task questions:
  - `reference_scheduledtasks_module.md`
- Lock screen, wallpaper, PersonalizationCSP:
  - `reference_personalization_csp.md`
- Windows 11 Start/taskbar layout:
  - `reference_start_layout_win11.md`

## Durable Lessons Already Learned

- `Set-ItemProperty -Type` is valid in Windows PowerShell 5.1 for registry
  provider paths. Validate provider dynamic parameters with:

```powershell
Get-Command Set-ItemProperty -ArgumentList 'HKLM:\Software'
```

- `LockScreenImageStatus` under PersonalizationCSP is a readback/status node.
  Do not write it in install scripts.
- PersonalizationCSP lock screen behavior has SKU/support boundaries. Direct
  registry writes are workarounds unless proven supported by current Microsoft
  documentation for the target SKU and channel.
- Windows 11 Start `pinnedList` JSON is a managed layout schema, but Shell-folder
  file-placement behavior and `taskbar.pinnedList` need target-build proof.
- `applyOnce` is only honored on Windows 11 24H2 with KB5062660 or newer
  documented support. Older builds may ignore it.
- Default User hive changes affect future profiles only. They do not modify
  existing profiles.
- Default User hive rollback needs provenance. Prefer app-specific backup
  folders plus manifest/hash, not "newest file in a broad backup folder."
- `Win32_ComputerSystem.UserName` is acceptable for standard single-user endpoint
  scenarios, but not a general RDS/VDI/multi-session solution.
- Detection that validates helper infrastructure does not prove Windows shell
  consumed Start/taskbar layout. Do not overclaim semantic delivery.
- Existing user profile work from SYSTEM usually needs a scheduled task, profile
  registry lookup, or explicit user-context design. Do not rely on SYSTEM
  environment variables for user paths.
- All I/O inside `Write-ErrorLog` (and any logging helper) must use
  `-ErrorAction SilentlyContinue`. A logging failure must never propagate and
  mask the original error that triggered the log call. **General rule: logging
  helpers must never throw.**
- Do not use `New-Item -LiteralPath` in Windows PowerShell 5.1. It is not a
  valid parameter. Microsoft documents only `-Path` for `New-Item`, and the
  local PS 5.1 runtime throws `ParameterBindingException` for `-LiteralPath`.
  For `New-Item`, Microsoft documents that `-Path` behaves like `-LiteralPath`
  and wildcards are not interpreted.
- Do not check helper file content for a hardcoded version string in detection.
  A content version check breaks detection on every helper bump without a
  simultaneous `Detect.ps1` update, adding a hidden multi-file coordination
  requirement. File existence plus task action reference is sufficient to prove
  the correct helper is deployed; version gating belongs to the marker
  `ScriptVersion` check.
- Do not compute SHA256 of large files (e.g., `NTUSER.DAT`, 5-30 MB) in
  detection scripts. Detection runs on every Intune check-in cycle (~every 8
  hours). File existence plus path-under-root check is sufficient for detection.
  Reserve SHA256 validation for uninstall, where it runs once before a restore.
- A `Mandatory` `[string[]]` (or scalar `[string]`) parameter without
  `[AllowEmptyString()]` rejects the *entire* call if any single array element
  (first, middle, last, or the only element) is an empty string -- not only
  when the whole value is missing. This bit the Hardware Hash Batch Extractor:
  parsed CSV rows passed as `string[]` crashed on any row with a blank field
  (e.g. blank Assigned User), which is routine in real data. Always add
  `[AllowEmptyString()]` (and `[AllowNull()]` if `$null` is also possible) to
  any mandatory string/string[] parameter that may legitimately receive blank
  values, such as parsed CSV/text fields.
- When hand-writing CSV parsing, do not treat characters after a closing quoted
  field as data. After a quoted field closes, only delimiter or end-of-line is
  valid; otherwise report malformed input. This prevents silent mutation where
  bad input such as `"Hash "bad" text"` is accepted and rewritten.
- Dot-sourcing a `.ps1` file from inside a function imports functions and
  variables into that function's local scope, not the caller's script scope.
  For dot-sourced module layouts, helper functions may resolve or validate
  module paths, but the actual `. $modulePath` call must run in the intended
  persistent scope unless using a real `.psm1` module with `Import-Module`.
- A write to a `$script:`-scoped variable from INSIDE a
  `.GetNewClosure()`'d scriptblock does not propagate back to the real
  script scope -- it lands in the closure's own private snapshot
  instead, silently. Confirmed via a minimal, twice-run isolated
  reproduction: `$script:X = $null; $sb = { $script:X = 'value' }.GetNewClosure(); & $sb`
  leaves the OUTER `$script:X` still `$null` afterward; the identical
  test with a PLAIN scriptblock (no `.GetNewClosure()`) correctly writes
  through. Reads of a pre-existing `$script:` variable from inside a
  `.GetNewClosure()`'d block are affected the same way (read back
  empty/null). This bit a real, live WinForms modal dialog whose OK
  button handler wrote its result to a `$script:`-scoped variable from
  inside a `.GetNewClosure()`'d Click handler: the dialog's own
  `DialogResult` genuinely became OK and it genuinely closed (no crash,
  no error, nothing visibly wrong), but the caller's own
  `return $script:Result`, executed afterward in the true outer scope,
  only ever saw the pre-dialog `$null` -- a real user's completed work
  silently discarded with zero indication anything had gone wrong.
  `.GetNewClosure()` is only actually needed to detach a scriptblock
  from a scope that will change or be destroyed before the scriptblock
  runs (the classic per-iteration loop-variable case) -- a modal
  dialog's own button handlers do NOT need it, since the enclosing
  function's stack frame stays alive for as long as `ShowDialog()`
  blocks, which is the button's entire useful lifetime; a plain
  scriptblock already closes correctly over local variables by ordinary
  lexical scoping. Prefer passing a dialog's result back via a LOCAL
  variable read directly from the outer function after `ShowDialog()`
  returns (reading UI control state, or a local variable set by a
  PLAIN, non-`.GetNewClosure()`'d handler) over a `$script:`-scoped
  intermediary; if a `$script:`-scoped intermediary is unavoidable,
  never set it from inside a `.GetNewClosure()`'d block.
- An `if`/`else` statement can only be used as a value in specific positions
  (an assignment RHS, or inside the `$(...)` subexpression operator). Wrapping
  it in bare parentheses -- `(if (...) {...} else {...})` -- to pass it as one
  argument among several in a function/method call, or inside `@(...)`, does
  NOT work: bare `()` only supports a single pipeline/expression, not a
  statement, and `if` is not a recognized command name, so PowerShell tries to
  run a command literally named `if` and fails at RUNTIME (not parse time)
  with `CommandNotFoundException: The term 'if' is not recognized...`. This
  bit two different real projects independently (a Tab.Warranty.ps1 fix, then
  again in MINT's Reports tab, D-124) before being promoted here. Use
  `$(if (...) {...} else {...})` (the subexpression operator) when the value
  must be computed inline in an argument position, or compute it into its own
  variable first (a plain assignment RHS) and pass the variable -- both work.
  A clean parse-check does NOT catch this; it only surfaces when the line
  actually executes, so treat any bare `(if ...)` in argument position as a
  defect on sight during review, not just when reproduced live.

## AI Collaboration Files

For each project, maintain:

```text
.\AI Knowledgebase\<Software or System Scripts>\<Project Folder>\AI-Audit-Handoff.md
.\AI Knowledgebase\<Software or System Scripts>\<Project Folder>\AI-Audit-Decisions.md
.\AI Knowledgebase\<Software or System Scripts>\<Project Folder>\Archive\
```

`AI-Audit-Handoff.md` is the current living summary. It should contain:

```markdown
# AI-Audit-Handoff.md

## Current State

## Active Risks

## Recent Changes

## Required Validation Before Deployment

## Latest Work Log
```

`AI-Audit-Decisions.md` is durable. It should contain accepted/rejected decisions
with rationale, evidence type, and source links or local file references.

Do not overwrite disagreement. Add a new entry explaining:

- the prior finding you disagree with
- whether the disagreement is proven from code/docs/logs or an inference
- the official documentation or local evidence supporting your position
- the recommended action

After auditing or correcting a script, update the project handoff with:

- files reviewed
- files changed
- findings accepted
- findings rejected
- rationale for meaningful decisions
- tests/validation performed
- remaining risks or human decisions

Also update this shared `AGENTS.md` or the targeted reference file when a durable
new lesson is learned. Keep the lesson concise and reusable.

## Output Preferences

- Be candid and technically honest.
- Keep responses structured and easy to scan.
- Use concrete wording.
- Give exact paths, commands, settings, and metadata.
- If Jeremy explicitly asks for Markdown output, prefer placing the Markdown in a
  fenced code block.
- Do not over-explain basics unless asked.
- Do not present weak approaches as equal options.
- Do not say "just try it and see" when there is a better validation path.
