# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-24 - Template Logs Use IME Logs Folder

- Decision: The generic EXE template writes script-authored error logs to
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` using the
  `APP_<AppName>_Install.txt` naming convention.
- Status: Accepted (applied v1.1.5)
- Evidence type: Recommendation adopted as workspace standard
- Rationale: New script-created runtime files should live under the IME root.
  Keeping app logs in the IME Logs folder places script diagnostics next to
  AppWorkload.log and IntuneManagementExtension.log and avoids expanding the
  legacy `C:\IntuneAppLogs` pattern.
- Source or local evidence: `AI Knowledgebase\AGENTS.md`; `AI Knowledgebase\reference_intune_paths.md`;
  `Software\.Generic Template\Install-exeTemplate.ps1` v1.1.5.
- Recommended action: Do not reintroduce `C:\IntuneAppLogs` into derived scripts.
  Existing apps using legacy paths should be migrated during their next normal
  audit/edit/repackage cycle.

### 2026-05-01 - Simple Functions Required: No [Parameter()] Attributes

- Decision: All template helper functions must be simple functions with no `[Parameter()]`,
  `[CmdletBinding()]`, or `[ValidateSet()]` attributes. Type constraints (`[string]`, `[int]`,
  `[string[]]`, `[System.Management.Automation.ErrorRecord]`) remain permitted.
- Status: Accepted (applied v1.1.4)
- Evidence type: Proven from field failures in PS 5.1 IME/SYSTEM context (P22)
- Rationale: PS 5.1 advanced-function parameter-set resolution throws ParameterBindingException
  on any function with [Parameter()] attributes when called from IME/SYSTEM context. Simple
  functions bypass the resolution engine entirely. Named-parameter calls still bind by name match.
  The v1.1.3 partial fix (adding [Parameter(Mandatory=$false)] to $ArgumentList) was the wrong
  approach; the correct fix removes all [Parameter()] attributes from all functions.
- Source: P22 in reference_intune_pitfalls.md; v1.1.4 changelog; Remove-Office365 v1.5.6
  changelog (same root failure)
- Recommended action: Never re-add [Parameter()] to any template function without a
  field-proven justification specific to the PS 5.1 IME/SYSTEM runtime.

### 2026-05-01 - Split-Path -LiteralPath -Parent: Use GetDirectoryName() Instead

- Decision: Parent-directory resolution must use `[System.IO.Path]::GetDirectoryName()` instead
  of `Split-Path -LiteralPath ... -Parent` in all template and derived scripts.
- Status: Accepted (applied v1.1.4)
- Evidence type: Proven from field failure at line 488 in Remove-Office365 v1.5.7 White Glove run
- Rationale: `Split-Path -LiteralPath` with `-Parent` throws ParameterBindingException in PS 5.1
  under IME/SYSTEM context. `GetDirectoryName()` is pure .NET with no parameter binding.
- Source: P24 in reference_intune_pitfalls.md; Remove-Office365 v1.5.8 changelog
- Recommended action: Use `[System.IO.Path]::GetDirectoryName($path)` everywhere in template
  and derived scripts. Never use Split-Path -LiteralPath -Parent.

### 2026-05-01 - TimeoutSeconds Ceiling Is 1199 (Not 1200)

- Decision: `$script:TimeoutSeconds` validation rejects values >= 1200 (ceiling is 1199 inclusive).
- Status: Accepted (original template design; confirmed correct)
- Evidence type: Design decision, documented in script comments
- Rationale: IME's hard kill fires at 20 minutes (1200 seconds). Capping at 1199 guarantees the
  script can log its own timeout failure and exit cleanly before IME kills the host. A script
  that exceeds 1199 seconds without returning leaves no diagnostic trace.
- Source: Template configuration comment; reference_script_dev_methodology.md
- Recommended action: Do not raise the ceiling without changing the portal timeout limit first.

### 2026-05-01 - DetectionPath Requires File Extension

- Decision: `Test-IsLikelyAbsoluteFilePath` rejects paths with no extension. This is intentional
  hardening for the template's file-based detection use case.
- Status: Accepted (original template design; confirmed correct)
- Evidence type: Design decision, documented in function comment
- Rationale: Extension-free paths are almost always directories or misconfigured entries.
  The template is designed for detecting installed .exe, .dll, .ocx, .dat, and similar files.
  Apps that write marker files should use a `.marker` extension; apps that cannot use a file
  extension should set `$script:DetectionPath = ''` and use a companion Detect.ps1 instead.
- Source: Test-IsLikelyAbsoluteFilePath function comment
- Recommended action: Keep the extension requirement. For marker-pattern apps, use `.marker`
  extension or leave DetectionPath blank with a dedicated Detect.ps1.

### 2026-05-01 - System.Diagnostics.Process Instead of Start-Process

- Decision: Use `System.Diagnostics.ProcessStartInfo` + `Process.WaitForExit(milliseconds)` for
  all installer process launches. Do not use `Start-Process -Wait`.
- Status: Accepted (original template design; confirmed correct)
- Evidence type: Proven design decision
- Rationale: `Start-Process -Wait` does not return a reliable exit code in all SYSTEM/IME contexts
  and does not support hard timeouts. `.WaitForExit(ms)` returns a boolean (timed out vs. exited),
  allows explicit timeout enforcement, and returns `[int]$process.ExitCode` reliably.
- Source: Template function comment; reference_exe_template.md
- Recommended action: Do not substitute Start-Process in derived scripts.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.
