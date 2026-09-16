# AI-Audit-Handoff.md

## Current State

- Project:          Generic Intune Win32 EXE installer template
- Current version:  1.1.5
- Script type:      Template (not deployed directly; copy and configure per-app)
- Primary script:   Software\.Generic Template\Install-exeTemplate.ps1
- Detection:        Per-app - no Detect.ps1 in this template; each derived app provides its own
- Uninstall:        Per-app - no Uninstall.ps1 in this template; each derived app provides its own

## Active Risks

- **None blocking.** Template v1.1.5 parses and passes the required encoding checks.

- **Medium - Open**: `$script:SkipInstallIfAlreadyDetected = $true` can block upgrades in
  derived app scripts when `$script:DetectionPath` points to a stable file path that is present
  for older versions. In that case the wrapper exits 0 before launching the installer, while
  Intune's real detection may still fail version gating and retry. For upgrade/supersedence
  packages, set this flag to `$false` unless the path is version-specific or the portal detection
  is intentionally existence-only.

- **Low - Open**: `Test-IsLikelyAbsoluteFilePath` and `LogRoot` validation use
  `[System.IO.Path]::IsPathRooted()`, which accepts root-relative paths such as
  `\Program Files\Vendor\App.exe`. The comments require an absolute path, so derived scripts
  should use drive-qualified local paths like `C:\Program Files\...` or `C:\ProgramData\...`.

- **Low - Informational**: `Test-Configuration` validates `$script:TimeoutSeconds < 1200` but passes
  values as-is to `Invoke-InstallerProcess`. For slow installers (Office, large MSI chains) the
  operator must consciously choose a timeout close to 1199 to match the 20-minute portal limit.
  The validation rejects `>= 1200` deliberately, so this is a known design constraint, not a defect.

- **Low - Informational**: `$script:DetectionPath` extension requirement (must have an extension)
  is enforced by `Test-IsLikelyAbsoluteFilePath`. Marker-pattern apps that do not use a file
  extension on their marker must set `$script:DetectionPath = ''` and handle detection via a
  companion `Detect.ps1`. See AI-Audit-Decisions.md for the marker-pattern guidance.

- **Derivation risk**: Any app script derived from this template at v1.1.2 or v1.1.3 carries the
  P22 and P24 defects. Those scripts must be audited and updated separately. See the memory index
  entry `reference_exe_template.md` for the current derived-app inventory.

## Recent Changes

### 2026-06-24 - Codex - IME Logs Standard Update

- Updated `Install-exeTemplate.ps1` from v1.1.4 to v1.1.5.
- Changed template error log root from `C:\IntuneAppLogs` to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- Changed default app log filename pattern to `APP_<AppName>_Install.txt`.
- Updated `reference_exe_template.md` to match the new IME-rooted log and marker
  standard.

### 2026-05-01 - Claude (claude-sonnet-4-6) - Initial Audit

- Converted all 10 decorated functions to simple functions (removed [Parameter(Mandatory=$true/false)]
  from ConvertTo-SafeFileNameComponent, Test-IsValidLeafFileName, Test-IsLikelyAbsoluteFilePath,
  Get-ExceptionSummary, Get-ExceptionCategory, Get-ExitCodeDescription, Stop-ProcessTree, and
  Invoke-InstallerProcess; removed [Parameter()] and [ValidateSet()] from Write-ErrorLog and
  Exit-Failure).
- Replaced both Split-Path -LiteralPath -Parent calls with [System.IO.Path]::GetDirectoryName()
  (Get-ScriptRoot line 108; Invoke-InstallerProcess working directory line 473).
- Applied UTF-8 BOM (file was BOM=False before this session).
- Version bumped: 1.1.3 -> 1.1.4.

## Required Validation Before Use As Template Base

- [x] Parse check: PARSE OK (PS 5.1 parser, verified 2026-05-01)
- [x] Encoding: BOM=True, NonASCII=0 (verified 2026-05-01)
- [ ] Any app derived from this template must have its own Detect.ps1, Uninstall.ps1, and
      portal detection rule - this template provides only the install script skeleton
- [ ] Derived apps must be field-tested; the template cannot be tested in isolation

## Latest Work Log

### 2026-06-24 - Codex - IME Runtime Path Standard

**Files reviewed:**

- `Software\.Generic Template\Install-exeTemplate.ps1`
- `AI Knowledgebase\Software\.Generic Template\AI-Audit-Handoff.md`
- `AI Knowledgebase\Software\.Generic Template\AI-Audit-Decisions.md`
- `AI Knowledgebase\reference_exe_template.md`

**Files changed:**

- `Software\.Generic Template\Install-exeTemplate.ps1`
- `AI Knowledgebase\Software\.Generic Template\AI-Audit-Handoff.md`
- `AI Knowledgebase\Software\.Generic Template\AI-Audit-Decisions.md`
- `AI Knowledgebase\reference_exe_template.md`

**Validation performed:**

- PS 5.1 parser: PARSE OK.
- Encoding: BOM=True, NonASCII=0.

**Remaining risks or human decisions:**

- Existing app scripts derived from older template versions were not bulk-migrated.
  Migrate them when each app is next audited, edited, or repackaged.

### 2026-05-01 - Codex - Independent v1.1.4 Audit

**Files reviewed:**

- Software\.Generic Template\Install-exeTemplate.ps1 (v1.1.4, 668 lines)
- AI Knowledgebase\Software\.Generic Template\AI-Audit-Handoff.md
- AI Knowledgebase\Software\.Generic Template\AI-Audit-Decisions.md
- AI Knowledgebase\reference_exe_template.md
- AI Knowledgebase\reference_intune_detection.md
- AI Knowledgebase\feedback_ps_auditor_standard.md
- AI Knowledgebase\feedback_script_encoding.md
- AI Knowledgebase\feedback_version_sync.md
- AI Knowledgebase\reference_intune_pitfalls.md

**Files changed:**

- AI Knowledgebase\Software\.Generic Template\AI-Audit-Handoff.md

**Validation performed:**

- PS 5.1 parser: PARSE OK
- Encoding: UTF-8 BOM present, NonASCII=0
- Windows PowerShell host check: 5.1.26100.7462, FullLanguage
- PSScriptAnalyzer: not installed locally
- Folder clutter check: source folder contains only Install-exeTemplate.ps1; no `.intunewin`
  artifacts present
- P22/P24 drift check: no active `[Parameter()]`, `[CmdletBinding()]`, `[ValidateSet()]`, or
  `Split-Path -LiteralPath -Parent` usage outside changelog/comments

**Findings:**

- No blocking script defects found.
- Medium derived-app risk: wrapper-side file-existence skip can block version upgrades if left
  enabled with a non-version-specific DetectionPath.
- Low validator risk: IsPathRooted accepts root-relative paths even though the template requires
  absolute local paths.

**Remaining risks or human decisions:**

- Derived app scripts still need their own detection, uninstall, packaging cleanup, and field test.
- Consider whether future v1.1.5 should either default `$script:SkipInstallIfAlreadyDetected` to
  `$false` or add stronger upgrade guidance beside the setting.

### 2026-05-01 - Claude (claude-sonnet-4-6) - Exhaustive PS 5.1 Audit

**Files reviewed:**

- Software\.Generic Template\Install-exeTemplate.ps1 (v1.1.3, 681 lines)
- AI Knowledgebase\AGENTS.md
- memory\reference_exe_template.md

**Files changed:**

- Install-exeTemplate.ps1: P22 fix (all [Parameter()] removed from 10 functions), P24 fix
  (Split-Path -LiteralPath -Parent replaced in 2 locations), BOM applied, version 1.1.3 -> 1.1.4

**Findings by severity:**

**Critical - P22 (Blocking):** 10 of 14 functions used [Parameter()] attributes, triggering
advanced-function parameter-set resolution in PS 5.1. All calls in the MAIN block and
Test-Configuration use explicit named parameters, so they bind correctly with simple functions.
The v1.1.3 "fix" (adding [Parameter(Mandatory=$false)] to one parameter) was the wrong approach
and added more decoration instead of removing it. All [Parameter()] and [ValidateSet()] attributes
removed; type constraints retained. **Fixed.**

**Critical - P24 (Blocking):** Two instances of Split-Path -LiteralPath ... -Parent:

- Get-ScriptRoot (original line 108): replaced with [System.IO.Path]::GetDirectoryName($PSCommandPath)
- Invoke-InstallerProcess (original line 473): replaced with [System.IO.Path]::GetDirectoryName($FilePath)

Both throw ParameterBindingException in PS 5.1 IME/SYSTEM context. **Fixed.**

**Low (Fixed):** BOM was False; applied UTF-8 BOM.

**Informational (No action):**

- P21 check: NonASCII=0; no em-dashes or non-ASCII content present
- P25 check: No multi-element pipeline returns with .Count accesses; N/A for this script
- P26 check: No registry property accesses in this script; N/A
- TimeoutSeconds constraint (< 1200) is intentional design; documented above
- Extension requirement in DetectionPath validator is intentional design hardening; documented above

**Tests/validation performed:**

- PS 5.1 parser: PARSE OK
- Encoding: BOM=True, NonASCII=0
- Manual code review: all execution paths (normal install, already-detected skip, timeout,
  process kill, detection verify, error handling, configuration validation)

**Remaining risks or human decisions:**

- Derived apps at v1.1.2 or v1.1.3 carry P22 and P24; audit and update them separately
- Template cannot be field-tested in isolation; validation occurs via derived-app deployments
