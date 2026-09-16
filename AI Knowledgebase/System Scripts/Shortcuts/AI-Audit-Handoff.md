# AI-Audit-Handoff.md

> **ECOSYSTEM RULE (see AGENTS.md "PDQ / Intune Tandem Deployment Standard"):**
> PDQ and Intune deployments must be indistinguishable on-device. All detection
> artifacts (files, markers, registry, logs) are mirrored between channels.
> Only PDQ scripts touch the filestore; Intune scripts use packaged files only.
> Keep filestore command activity at an absolute minimum (EDR/Defender).

## Current State

- Project: Shortcuts family (parent handoff covering all shortcut projects)
- Current versions:
  - Single-shortcut Intune scripts: v1.1.1
  - HC Default Shortcut Pack Intune scripts: v1.1.2
  - Single-shortcut PDQ scripts: v1.0.1
  - HC Default Shortcut Pack PDQ scripts: v1.0.2
- Deployment type: Win32 app per project (Install/Detect/Uninstall) plus optional
  Set-*ShortcutIcon.ps1 platform scripts
- Projects: ADP, Webmail, Inform Browser, Fireworks (EPR), Operative IQ,
  Microsoft Account, Office 365 Web Apps, HC Default Shortcut Pack, Template
  (Guardian Tracking has only a .url asset, no scripts)
- Runtime paths (current IME-rooted standard as of v1.1.x):
  - Icons: `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`
  - Logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
    (`SCRIPT_<AppName>_Install.txt` / `_Uninstall.txt` / `_IconUpdate.txt`)
  - Shortcuts: `C:\Users\Public\Desktop` (unchanged)
- Detection (single-shortcut v1.1.1; HC pack v1.1.2): shortcut present on
  Public Desktop AND icon present at EITHER the IME Images path OR the legacy
  `C:\IntuneDeploymentFiles\Images` path. Legacy acceptance is deliberate so
  already-deployed devices keep passing detection and no files are moved on
  active machines.
- PDQ tandem (added 2026-07-13): each project's `PDQ`
  subfolder holds `Install-<X>-PDQ.ps1` and `Uninstall-<X>-PDQ.ps1`. Installs
  pull payloads from the shared filestore repository
  (`\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts`
  and `...\Icons`); the HC Default Shortcut Pack PDQ install pulls the same
  repository files instead of bundling. On-device end state is identical to the
  Intune install, so Intune detection passes for PDQ-deployed shortcuts. PDQ
  log entries are tagged `[PDQ]` inside the same IME log files. One script per
  PDQ install package; uninstall is a separate script/package. Install steps
  must run as the PDQ Deploy User (share read access); uninstalls need no share.
  Single-shortcut PDQ pairs are v1.0.1 and the HC Default Shortcut Pack PDQ
  pair is v1.0.2 after Codex hardening.

## Active Risks

- All projects require repackaging (`.intunewin` rebuild by Jeremy) before the
  v1.1.x scripts reach devices. Old `.intunewin` files were moved out of
  deployable project folders into
  `System Scripts\Shortcuts\Archive\Stale IntuneWin 2026-07-13`.
- Inform Browser has TWO uninstall scripts (`Uninstall-InformBrowserShortcut.ps1`
  and `Uninstall-Shortcut.ps1`). Both are now correctly configured and identical
  in behavior, but only ONE should be packaged; recommend keeping
  `Uninstall-InformBrowserShortcut.ps1` and confirming the portal uninstall
  command matches whichever is kept.
- Fireworks uninstall filename retains its original typo
  (`Uninstall-EPRFIreworksShortcut.ps1`, capital I) on purpose to avoid breaking
  any existing portal uninstall command. Rename only together with a portal update.
- DEPRECATED (2026-07-13): the Intune-side Set-*ShortcutIcon.ps1 platform
  scripts now violate the ecosystem channel rule (Intune scripts must not reach
  the filestore) AND point at the old share path
  `\\hallcounty\filestore\mis\CDS\Intune Files\Shortcut Icons`, superseded by
  the new repository under `Intune Management Applications\Shortcut Icons`.
  They were intentionally left on disk untouched in case portal assignments
  still reference them. Jeremy: unassign/retire them in the portal, then delete
  the files. Their PDQ-folder copies were already removed (PDQ installs refresh
  icons from the repository, making them redundant).
- Files suffixed `-IT-BK348FT25273` are OneDrive conflict copies; intentionally
  untouched. Never package them.

## Recent Changes

- 2026-07-13 - All 36 scripts across 9 folders regenerated from one standardized
  template set at v1.1.0 (see work log below).
- 2026-07-13 - `.url` source files: `IconFile=` lines that pointed at Jeremy's
  personal OneDrive path now point at the IME Images path; fixed
  `My Account Settings.url` referencing non-existent `Hall County Logo.ico`
  (actual file is `Hall County Logo Icon.ico`).
- 2026-07-13 - Claude blind audit: confirmed all Codex changes sound; normalized
  bare-LF/mixed line endings to CRLF in the three Codex-edited `.url` payloads
  (EPR Fireworks, Inform Browser, Operative IQ) locally and in the repository.
- 2026-07-13 - Codex blind audit after Claude: removed `[Parameter()]`
  attributes from shortcut deployment functions to avoid the documented PS 5.1
  / IME parameter-binding failure class; hardened `.url` icon rewriting to
  insert missing `IconFile=` / `IconIndex=` inside `[InternetShortcut]`;
  released both WScript COM objects for `.lnk` updates; synchronized versions
  (Intune singles v1.1.1, HC pack v1.1.2, PDQ singles v1.0.1, HC pack PDQ
  v1.0.2); archived stale `.intunewin` files out of deployable folders.
- 2026-07-13 - Codex blind audit corrections: added missing `IconFile=` and
  `IconIndex=` lines to Fireworks, Inform Browser, and Operative IQ shortcut
  payloads locally and in the shared repository; hardened HC Default Shortcut
  Pack install scripts with per-file copy verification (Intune v1.1.1, PDQ
  v1.0.1); removed stale per-project Intune guide copies and updated canonical
  Template Intune/PDQ deployment guides.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1. (Done 2026-07-13 Codex
  second audit:
  54/54 pass.)
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
  (Done 2026-07-13 Codex second audit: 54/54 pass.)
- Confirm install, uninstall, detection versions are synchronized:
  single-shortcut Intune v1.1.1, HC Default Shortcut Pack Intune v1.1.2,
  single-shortcut PDQ v1.0.1, HC Default Shortcut Pack PDQ v1.0.2.
- Remove stale `.intunewin`, AI notes, and guide drafts from package payloads.
- Confirm portal install/uninstall commands use
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe` and the correct
  per-project script file names; detection script 32-bit setting = No.
- Test one project end-to-end on a test device (fresh install to IME path) and
  one already-deployed device (must stay detected via legacy path, no reinstall).

## Latest Work Log

### 2026-07-13 - Codex (GPT-5) - Blind audit after Claude follow-up

- Files reviewed: all 54 shortcut PowerShell scripts, all local and repository
  `.url` payloads, Template Intune/PDQ guides, parent handoff/decisions, and
  the shared shortcut repository using minimal read-only filestore access.
- Findings accepted:
  - Proven: function parameters in install/uninstall/PDQ/Set-Icon scripts used
    `[Parameter()]` attributes, with `Write-ErrorLog` mixing decorated and
    undecorated parameters. This matches the documented PS 5.1 / IME
    `ParameterBindingException` risk class in `reference_intune_pitfalls.md`.
  - Proven: `Set-ShortcutIconReference` appended missing `.url` icon keys at
    end-of-file. Current payloads are already explicit, so this was dormant,
    but future multi-section `.url` files could place icon keys outside
    `[InternetShortcut]`.
  - Recommendation accepted: stale `.intunewin` files should not remain inside
    deployable source folders after script versions changed.
- Files changed:
  - All 54 shortcut `.ps1` files had `.NOTES` versions synchronized.
  - 45 scripts with functions had advanced `[Parameter()]` attributes removed.
  - 27 `Set-ShortcutIconReference` implementations now keep `.url` icon keys
    inside `[InternetShortcut]`, throw on malformed `.url` files without that
    section, and release both WScript COM objects for `.lnk` updates.
  - 8 stale `.intunewin` files moved to
    `System Scripts\Shortcuts\Archive\Stale IntuneWin 2026-07-13`.
  - `System Scripts\Shortcuts\Template\PDQ\PDQ-Deployment-Guide.md` updated for
    current PDQ versions.
- Version changes:
  - Single-shortcut Intune scripts: v1.1.1.
  - HC Default Shortcut Pack Intune scripts: v1.1.2.
  - Single-shortcut PDQ scripts: v1.0.1.
  - HC Default Shortcut Pack PDQ scripts: v1.0.2.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 54/54 scripts pass.
  - Script encoding: 54/54 scripts UTF-8 BOM and ASCII-only.
  - No `[Parameter()]` or `[CmdletBinding()]` attributes remain under
    `System Scripts\Shortcuts`.
  - Version family check passed for all 54 scripts.
  - Synthetic `.url` behavior test passed: missing icon keys insert before the
    next INI section; malformed `.url` without `[InternetShortcut]` throws.
  - Live detection execution on this workstation: deployed ADP, HC pack,
    Microsoft Account, Office 365 Web Apps, and Webmail returned exit 0 with
    STDOUT; Fireworks, Inform Browser, Operative IQ, and Template returned exit
    1 with no output.
  - Local and repository `.url` payloads: icon metadata present for every
    supported shortcut, CRLF line endings, no BOM; Guardian Tracking remains
    the explicit exception.
  - Shared repository hygiene: no scripts or markdown on the filestore.
  - Config parity: single-project Intune/PDQ config values match; HC pack
    shortcut lists match across install/detect/uninstall/PDQ scripts.
- Remaining risks or human decisions:
  - Deprecated Set-*ShortcutIcon.ps1 platform-script source files remain local
    and still reference the old share path by design pending portal retirement;
    do not package or assign them as new work.
  - Inform Browser still has two valid uninstall scripts; package only one and
    align the portal uninstall command.
  - Jeremy still needs to rebuild `.intunewin` packages and perform on-device
    tandem testing.

### 2026-07-13 - Claude (Fable 5) - Blind audit of full script set (post-Codex state)

- Scope: all 54 scripts, 12 `.url` payloads, and both Template guides under
  `System Scripts\Shortcuts`, auditing Codex's corrective pass and the earlier
  Claude work with equal skepticism. No filestore reads performed; one minimal
  filestore write (see below).
- Findings confirmed good (proven by local execution):
  - 54/54 scripts parse clean under Windows PowerShell 5.1.26100 and are
    UTF-8 BOM / ASCII-only.
  - Version sync exact: Intune singles 1.1.0, HC pack trio 1.1.1, PDQ singles
    1.0.0, HC pack PDQ pair 1.0.1. Codex correctly updated the HC PDQ `.NOTES`
    tandem references to Intune v1.1.1.
  - HC pack Intune-vs-PDQ code diff shows only the intended deltas (repository
    source paths, `[PDQ]` log tag, message wording). Codex's per-file copy
    verification is identical on both sides - accepted as a good hardening.
  - Masked cross-project diff of all single-shortcut scripts against the
    Webmail baseline: zero real drift; only per-project config values differ.
  - Live detection runs: 5 deployed projects detect exit 0 via the legacy icon
    branch on this workstation; 4 undeployed exit 1 with no output. HC Detect
    v1.1.1 works.
  - All 12 `.url` payloads: `IconFile=` points at the IME Images path, no BOM,
    HC pack copies byte-identical to their single-project counterparts.
  - Codex's rewritten Template Intune guide is accurate (paths, commands,
    detection semantics, packaging hygiene).
- Finding corrected (Low): the three `.url` payloads Codex edited (EPR
  Fireworks, Inform Browser, Operative IQ) had bare-LF or mixed line endings.
  `.url` is INI format; house standard for INI payloads is explicit CRLF.
  Runtime impact was negligible (install scripts rewrite the deployed copy
  with CRLF), but shared payloads must be clean by themselves. Normalized all
  three to CRLF locally and synced the three files to the repository
  `Shortcuts` folder in a single batch copy (the only filestore access this
  session).
- Latent observation (Low, documented only, no code change):
  `Set-ShortcutIconReference` appends missing `IconFile=`/`IconIndex=` lines at
  end-of-file. If a future `.url` payload ever has `[InternetShortcut]` NOT as
  its last section, appended lines would land in the wrong INI section. All
  current payloads carry explicit `IconFile=` lines, so only the in-place
  replace path executes. Keep payloads authored with explicit icon lines
  (now enforced by the repository payloads) and this stays dormant.
- Standing risk re-flagged: deprecated Set-*ShortcutIcon.ps1 scripts remain in
  deployable Intune source folders (still pointing at the old share path).
  They must be excluded from any `.intunewin` build until Jeremy retires the
  portal assignments and deletes them.
- Tests/validation performed: PS 5.1 parse + BOM/ASCII (54/54), live detection
  execution (9/9), HC parity diff, masked cross-project diffs, `.url` encoding
  and line-ending checks, HC pack payload copy comparison.
- Remaining human steps: unchanged from prior entries (repackage, PDQ package
  creation, portal checks, on-device tandem test).

### 2026-07-13 - Codex (GPT-5) - Blind audit and corrective pass

- Files reviewed: parent and project shortcut knowledge files, all scripts and
  shortcut payloads under `System Scripts\Shortcuts`, Template Intune/PDQ
  guides, and a read-only inventory of
  `\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons`.
- Findings accepted:
  - Proven: all 54 PowerShell scripts parse under Windows PowerShell 5.1 and
    meet UTF-8 BOM / ASCII-only requirements.
  - Proven: the shared repository contained only payload files: icons under
    `Icons` and `.url` files under `Shortcuts`; no scripts or markdown were on
    the filestore.
  - Proven: Fireworks, Inform Browser, and Operative IQ `.url` payloads lacked
    `IconFile=` / `IconIndex=` metadata locally and on the repository. The
    install scripts would add those lines after copy, but the shared payloads
    should be clean by themselves.
  - Recommendation accepted: HC Default Shortcut Pack install scripts should
    verify copied icon and shortcut files just like the single-shortcut
    installers.
  - Proven: old per-project Intune guide copies were stale and referenced
    generic 1.0-era script names, `C:\IntuneDeploymentFiles\Images`, and
    `C:\IntuneAppLogs`.
- Files changed:
  - `System Scripts\Shortcuts\Fireworks\EPR Fireworks.url`
  - `System Scripts\Shortcuts\Inform Browser\Inform Browser.url`
  - `System Scripts\Shortcuts\Operative IQ\Operative IQ.url`
  - Matching repository payloads in
    `\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts`
  - `System Scripts\Shortcuts\HC Default Shortcut Pack\Install-DesktopShortcuts.ps1`
  - `System Scripts\Shortcuts\HC Default Shortcut Pack\Detect.ps1`
  - `System Scripts\Shortcuts\HC Default Shortcut Pack\Uninstall-DesktopShortcuts.ps1`
  - `System Scripts\Shortcuts\HC Default Shortcut Pack\PDQ\Install-DesktopShortcuts-PDQ.ps1`
  - `System Scripts\Shortcuts\HC Default Shortcut Pack\PDQ\Uninstall-DesktopShortcuts-PDQ.ps1`
  - `System Scripts\Shortcuts\Template\Shortcut-Deployment-Guide.md`
  - `System Scripts\Shortcuts\Template\PDQ\PDQ-Deployment-Guide.md`
  - Removed stale per-project Intune guide copies from Fireworks, Inform
    Browser, Microsoft Account, Office 365 Web Apps, Operative IQ, and Webmail.
- Version changes:
  - HC Default Shortcut Pack Intune scripts bumped to v1.1.1.
  - HC Default Shortcut Pack PDQ scripts bumped to v1.0.1.
  - Single-shortcut Intune/PDQ scripts unchanged.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: 54/54 scripts pass.
  - Script encoding: 54/54 scripts UTF-8 BOM and ASCII-only.
  - Template markdown guides: ASCII-only.
  - Repository payload inventory: clean `Shortcuts`/`Icons` split verified.
  - Shortcut metadata check: all supported local and repository `.url` files
    have `IconFile=` and `IconIndex=`; Guardian Tracking remains without icon
    metadata by explicit exception.
- Remaining risks or human decisions:
  - Stale `.intunewin` files still exist and must not be reused or packaged into
    new payloads.
  - Intune Set-*ShortcutIcon.ps1 platform-script source files remain deprecated
    and still should be retired from portal assignments before deleting the
    local sources.
  - Inform Browser still has two valid uninstall scripts; package only one and
    align the portal uninstall command.

### 2026-07-13 - Claude (Fable 5) - PDQ tandem deployment build-out

- Files reviewed: all copied files in each project's `PDQ` subfolder; existing
  PDQ precedent `Software\Freshservice Asset Tracking\PDQ\Install-FreshServiceAgent-PDQ.ps1`
  (naming convention only; its content predates current standards); one-time
  read-only inventory of the filestore repository (single command, per the
  EDR-minimization rule).
- Repository inventory result: fully staged. All 7 icons and 8 shortcuts
  present, covering every project including the 4 pairs the HC pack needs.
  Guardian Tracking has a `.url` but no icon and is excluded by design. No
  missing files; nothing needed copying to the share.
- Files changed:
  - 18 new PDQ scripts (v1.0.0): `Install-<X>-PDQ.ps1` + `Uninstall-<X>-PDQ.ps1`
    for ADP, Webmail, Inform Browser, Fireworks, Operative IQ,
    Microsoft Account, Office 365 Web Apps, Template, HC Default Shortcut Pack.
    Generated from one template pair; parity with Intune v1.1.0 documented in
    each `.NOTES`.
  - 43 copied Intune-era files deleted from the PDQ folders (Detect scripts,
    Set-Icon scripts, old-named install/uninstall copies, stale guides).
  - New canonical guide: `Template\PDQ\PDQ-Deployment-Guide.md`.
  - `AI Knowledgebase\AGENTS.md`: added ecosystem-wide "PDQ / Intune Tandem
    Deployment Standard" section near the top.
- Design decisions:
  - PDQ installs pull from the shared repository; Intune installs keep bundled
    package files (unchanged - no Intune script changes were required).
  - Same `AppName` values and IME log file names as Intune; PDQ entries tagged
    `[PDQ]`. Detection artifacts identical by construction.
  - PDQ-side file names fixed the Fireworks typo and the Inform Browser
    duplicate (fresh channel, no legacy portal command constraints).
  - Intune Set-*ShortcutIcon.ps1 platform scripts declared deprecated (see
    Active Risks); left on disk pending portal unassignment.
- Tests/validation performed:
  - PS 5.1 parser + UTF-8 BOM + ASCII-only checks: 18/18 PDQ scripts pass
    (one transient OneDrive file lock re-checked clean).
  - Core `Set-ShortcutIconReference` and `Write-ErrorLog` logic is byte-identical
    to the Intune v1.1.0 functions that were sandbox-tested earlier this date.
  - No install/uninstall executed locally (would modify the Public Desktop) and
    no further filestore access performed.
- Remaining risks or human decisions:
  - Jeremy: build the PDQ packages (install = one PowerShell step running the
    -PDQ install script as Deploy User; uninstall = separate package/step).
  - Jeremy: retire the Intune Set-Icon platform script assignments.
  - Test one PDQ install on a device, then run the Intune detection script on
    it to confirm channel-indistinguishable detection.

### 2026-07-13 - Claude (Fable 5) - IME path migration + standardization

- Files reviewed: every `.ps1`, `.url`, and deployment guide under
  `System Scripts\Shortcuts` (all 9 project folders); baseline diffs proved all
  single-shortcut projects were Template clones differing only in two config values.
- Files changed:
  - 33 scripts regenerated via a single template generator (ADP, Webmail,
    Inform Browser, Fireworks, Operative IQ, Microsoft Account,
    Office 365 Web Apps, Template: Install/Detect/Uninstall/Set-Icon each).
  - 3 HC Default Shortcut Pack scripts rewritten (multi-shortcut variants).
  - 8 `.url` files: `IconFile=` updated to the IME Images path.
- Defects found in prior versions (all fixed by regeneration):
  - `Uninstall-InformBrowserShortcut.ps1` and
    `Uninstall-MicrosoftAccountShortcut.ps1` still had template defaults
    (`Moblan.lnk`) and silently uninstalled nothing.
  - Fireworks `Set-EPRFireworksShortcutIcon.ps1` pointed at the wrong network
    folder (missing `\Shortcut Icons`).
  - All uninstall scripts logged to `*_Shortcut_Install.txt` (copy-paste bug).
  - `Write-ErrorLog` used `-ErrorAction Stop` + `Write-Error`, which can throw
    or terminate under `$ErrorActionPreference = 'Stop'`; replaced with a
    never-throw helper (all I/O SilentlyContinue).
  - No StrictMode/EAP hardening; `Write-Error` usage in main flow could
    terminate before reaching `exit 1` under EAP Stop; replaced with
    `Write-Output` + explicit `exit 1` (`Stop-WithError`).
  - `.url` source files carried `IconFile=` pointing at
    `C:\Users\jhankinson\OneDrive - ...` paths.
- Standardization applied (v1.1.0, all scripts):
  - `#Requires -Version 5.1`, `Set-StrictMode -Version Latest`,
    `$ErrorActionPreference = 'Stop'`.
  - .NOTES block per house format with CHANGE LOG and Intune configuration.
  - IME-rooted Images/Logs paths with `SCRIPT_<AppName>_*` log naming.
  - Detection passes on IME OR legacy icon location (dual-location).
  - `-LiteralPath` throughout; `New-Item -Path` only (PS 5.1 rule);
    `@()` wraps on `Get-Content`; COM release in `finally`.
- Tests/validation performed (all under local Windows PowerShell 5.1):
  - Parser check: 36/36 scripts, zero errors.
  - Encoding check: 36/36 UTF-8 BOM, zero non-ASCII characters.
  - Live-ran all 9 detection scripts on this workstation (IT-BK348FT25273):
    the 5 deployed projects (ADP, HC pack, Microsoft Account, O365, Webmail)
    correctly detected via the LEGACY icon location (exit 0 + STDOUT), proving
    the backward-compatibility requirement; the 4 undeployed correctly exit 1.
  - Sandbox-tested `Set-ShortcutIconReference` (AST-extracted): replaces
    existing IconFile/IconIndex lines, appends when missing, throws on
    unsupported extension.
  - Sandbox-tested `Write-ErrorLog`: writes correctly; does not throw when the
    log path is unwritable.
- Remaining risks or human decisions:
  - Jeremy: rebuild and re-upload `.intunewin` for each project; remove stale
    packages from source folders first.
  - Jeremy: pick one Inform Browser uninstall script for the package.
  - SYSTEM-context and on-device White Glove testing not performed in this
    session (workstation-only validation).
