# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-07-13 - Dual-location icon detection (IME OR legacy) for all shortcut projects

- Decision: All shortcut Detect scripts pass when the shortcut exists on the
  Public Desktop AND its icon exists at EITHER
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Images` (current standard)
  OR `C:\IntuneDeploymentFiles\Images` (legacy). Install scripts write ONLY to
  the IME location. Devices deployed before the migration must keep passing
  detection so Intune never re-runs installs just to relocate files.
- Status: Accepted
- Evidence type: proven from code and live detection runs; user direction
- Rationale: Jeremy explicitly required that active machines not have files
  needlessly moved. Live runs on IT-BK348FT25273 (icons in legacy location)
  returned exit 0 via the legacy branch for all 5 deployed projects.
- Source or local evidence: `System Scripts\Shortcuts\<project>\Detect*.ps1`
  v1.1.0; `reference_intune_paths-IT-BK348FT25273.md` (legacy fallback table
  explicitly allows detection to check legacy paths after the IME path).
- Recommended action: Do not remove the legacy branch until the fleet is
  confirmed migrated or reimaged; revisit only with device inventory evidence.

### 2026-07-13 - PDQ tandem standard: mirrored artifacts, shared repository, channel boundaries

- Decision: Every PDQ deployment must leave the device indistinguishable from
  its Intune counterpart (identical files, markers, registry, log locations),
  so Intune detection passes regardless of channel. PDQ installs pull payloads
  from the shared repository
  (`\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\{Shortcuts,Icons}`);
  Intune installs use only bundled package files. Only payload files live on
  the filestore; scripts/markdown stay in the project `PDQ` folder; filestore
  command activity is kept to an absolute minimum (EDR/Defender concern).
  One script per PDQ install package; uninstall is a separate script.
- Status: Accepted (Jeremy's explicit direction, 2026-07-13)
- Evidence type: user direction; codified in AGENTS.md "PDQ / Intune Tandem
  Deployment Standard"
- Rationale: single repository serves standalone shortcuts and the HC pack;
  parity removes double-management of detection state; filestore hygiene
  prevents EDR/Defender responses on the server.
- Recommended action: apply to all future PDQ scripting across the ecosystem,
  not just shortcuts.

### 2026-07-13 - Intune Set-*ShortcutIcon.ps1 platform scripts deprecated

- Decision: The Intune-side Set-Icon platform scripts are deprecated. They
  violate the new channel rule (Intune must not reach the filestore) and point
  at the superseded share path `...\Intune Files\Shortcut Icons`. Files left on
  disk pending portal unassignment; PDQ-folder copies deleted.
- Status: Accepted
- Evidence type: recommendation following from the tandem standard
- Recommended action: Jeremy unassigns them in the portal, then deletes the
  files from the Intune project folders.

### 2026-07-13 - Keep existing script file names (including Fireworks typo) to protect portal commands

- Decision: v1.1.0 regeneration kept every existing script file name, including
  `Uninstall-EPRFIreworksShortcut.ps1` (capital I typo) and Webmail's generic
  `Uninstall-Shortcut.ps1`, because Intune portal install/uninstall/detection
  commands reference file names inside already-uploaded packages.
- Status: Accepted
- Evidence type: recommendation (portal command values not verifiable locally)
- Rationale: Renaming without a synchronized portal update breaks uninstall
  silently. Cosmetic renames are only safe when done together with a package
  rebuild and portal command review.
- Recommended action: If Jeremy wants the names cleaned up, do it at next
  repackage and update the portal commands in the same change.

### 2026-07-13 - Use Template deployment guides instead of per-project guide copies

- Decision: Shortcut deployment documentation is canonical in
  `System Scripts\Shortcuts\Template\Shortcut-Deployment-Guide.md` and
  `System Scripts\Shortcuts\Template\PDQ\PDQ-Deployment-Guide.md`. Stale
  per-project Intune guide copies were removed from deployable source folders.
- Status: Accepted
- Evidence type: proven from source review; recommendation
- Rationale: The removed copies referenced old script names, old icon/log paths,
  and generic v1.0-era packaging guidance. Keeping guide copies in deployable
  source folders increases the chance that reference-only clutter is bundled
  into `.intunewin` packages.
- Source or local evidence: `System Scripts\Shortcuts\Template\*.md`
- Recommended action: Update the Template guides when shortcut deployment
  standards change. Do not recreate per-project guide copies unless they carry
  project-specific information that cannot live in the Template guide.

### 2026-07-13 - Shortcut deployment functions use simple function binding

- Decision: Shortcut deployment scripts should not use `[Parameter()]` or
  `[CmdletBinding()]` attributes in helper functions. Use simple functions with
  typed parameters to avoid the documented Windows PowerShell 5.1 / IME
  `ParameterBindingException` failure class.
- Status: Accepted
- Evidence type: proven from code review; supported by local reference
- Rationale: `Write-ErrorLog` mixed decorated and undecorated parameters, which
  is the classic risky pattern. The broader simple-function rewrite also avoids
  the extended binding-risk class already documented for endpoint deployment
  scripts.
- Source or local evidence: `AI Knowledgebase\reference_intune_pitfalls.md`
  P22; `System Scripts\Shortcuts\<project>\*.ps1` v1.1.1/v1.1.2 and
  `PDQ\*.ps1` v1.0.1/v1.0.2.
- Recommended action: Keep future shortcut helper functions simple unless a
  specific advanced-function feature is required and tested under the target
  Windows PowerShell 5.1 endpoint context.

### 2026-07-13 - Archive stale `.intunewin` files outside deployable source folders

- Decision: Old shortcut `.intunewin` artifacts were moved out of project source
  folders to `System Scripts\Shortcuts\Archive\Stale IntuneWin 2026-07-13`.
- Status: Accepted
- Evidence type: proven from source review; packaging standard
- Rationale: Current scripts are newer than the old packages, and leaving stale
  `.intunewin` files inside source folders risks accidentally bundling old
  packages into new packages or reusing obsolete artifacts.
- Source or local evidence: no `.intunewin` files remain in deployable shortcut
  project folders; 8 old packages are preserved in the archive folder.
- Recommended action: Keep package artifacts outside source folders. Rebuild
  packages manually from clean staging/source folders when ready.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:
