# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-24 - Shortcut Template Uses IME Images And Logs

- Decision: New shortcut packages derived from the template store icon files in
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Images` and write
  script-authored logs to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- Status: Accepted
- Evidence type: Recommendation adopted as workspace standard
- Rationale: New script-created runtime files should live under the IME root.
  Icons are image assets, so they belong in `Images`; shortcut install,
  uninstall, and icon-update diagnostics are logs, so they belong in `Logs`.
- Source or local evidence: `AI Knowledgebase\AGENTS.md`;
  `AI Knowledgebase\reference_intune_paths.md`;
  `System Scripts\Shortcuts\Template\Install-Shortcut.ps1`;
  `System Scripts\Shortcuts\Template\Uninstall-Shortcut.ps1`;
  `System Scripts\Shortcuts\Template\Set-ShortcutIcon.ps1`.
- Recommended action: Do not use `C:\IntuneDeploymentFiles\Images` or
  `C:\IntuneScriptLogs` for newly created shortcut packages. Existing shortcut
  packages can be migrated during their next normal audit/edit/repackage cycle.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.
