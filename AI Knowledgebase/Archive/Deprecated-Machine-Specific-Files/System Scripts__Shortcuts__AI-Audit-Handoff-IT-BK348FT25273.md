# AI-Audit-Handoff.md

## Current State

- Project:          Public Desktop shortcut deployment templates
- Current version:  Template scripts list version 1.0; path standard updated 2026-06-24
- Deployment type:  Microsoft Intune Win32 App / optional platform script helper
- Primary install script: `System Scripts\Shortcuts\Template\Install-Shortcut.ps1`
- Detection:        `System Scripts\Shortcuts\Template\Detect.ps1`
- Uninstall:        `System Scripts\Shortcuts\Template\Uninstall-Shortcut.ps1`
- Optional helper:  `System Scripts\Shortcuts\Template\Set-ShortcutIcon.ps1`
- Package artifact: Per-shortcut package; no single active artifact tracked here

## Active Risks

- Existing deployed shortcut packages outside `Template` still reference legacy
  paths such as `C:\IntuneDeploymentFiles\Images` and `C:\IntuneScriptLogs`.
  They were not bulk-migrated in the 2026-06-24 standards update. Migrate each
  concrete shortcut package when it is next audited, edited, or repackaged.
- Template functions still use older decorated parameter style in helper
  functions. This pass was scoped to the IME runtime path standard, not a full
  P22/simple-function rewrite.

## Recent Changes

### 2026-06-24 - Codex - IME Runtime Path Standard Update

- Updated shortcut template icon storage from `C:\IntuneDeploymentFiles\Images`
  to `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`.
- Updated shortcut template error logging from `C:\IntuneScriptLogs` to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- Updated shortcut template log names to use `SCRIPT_...` prefixes.
- Updated shortcut template install/uninstall command documentation to use
  `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe` with
  `-NoProfile -NonInteractive`.
- Normalized template `.ps1` files to UTF-8 BOM with ASCII-only content.

## Required Validation Before Deployment

- Parse all PowerShell with Windows PowerShell 5.1.
- Verify UTF-8 BOM and ASCII-only content for deployed `.ps1` files.
- Validate JSON/XML/config files if present.
- Confirm install, uninstall, detection, marker versions, helper versions, and
  package artifact are synchronized.
- Confirm `.intunewin` is rebuilt from a clean source folder with no stale
  `.intunewin`, logs, AI notes, or archives inside the payload.
- Confirm Intune portal settings match the script comments.
- For device-context work, validate 64-bit PowerShell and SYSTEM-context behavior.

## Latest Work Log

### 2026-06-24 - Codex - IME Runtime Path Standard

- Files reviewed: `Install-Shortcut.ps1`, `Uninstall-Shortcut.ps1`,
  `Set-ShortcutIcon.ps1`, `Detect.ps1`, and `Shortcut-Deployment-Guide.md`.
- Files changed: `Install-Shortcut.ps1`, `Uninstall-Shortcut.ps1`,
  `Set-ShortcutIcon.ps1`, `Detect.ps1` (encoding only), and
  `Shortcut-Deployment-Guide.md`.
- Findings accepted: new shortcut template runtime files should use IME
  `Images` and `Logs` folders.
- Findings rejected: none.
- Rationale: aligns new shortcut deployments with the workspace standard that
  all new script-created runtime files belong under the IME root.
- Tests/validation performed: PS 5.1 parser passed for all four `.ps1` files;
  encoding check passed with BOM=True and NonASCII=0 for all four `.ps1` files.
- Remaining risks or human decisions: decide per concrete shortcut package
  whether to migrate immediately or wait until the next normal repackaging.
