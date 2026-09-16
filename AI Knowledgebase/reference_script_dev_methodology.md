---
name: Intune Script Development Methodology — Build, Validate, Package, Deploy
description: Step-by-step process for developing, validating, and deploying Intune Win32 scripts correctly; checkpoints before each stage
type: reference
---

# Intune Script Development Methodology

This is the required sequence for any new Win32 app script. Skipping stages is the primary cause of repeated deploy-fail-redeploy cycles.

---

## Stage 1 — Write

### Decisions before writing a single line

**App type first:**
- Win32 app → anything with detection, dependencies, uninstall logic, restart control, or White Glove blocking requirement
- Platform script → lightweight one-time config with no detection/uninstall/retry need
- Remediation → only when recurring drift-correction is explicitly required
- When uncertain: default to Win32 app

**Context:**
- Default: `System` / device context
- User context only when the action genuinely requires the logged-on user AND is safe outside technician flow

**Architecture:**
- Default: 64-bit (`SysNative` in portal command)
- Never let host bitness be accidental

### Mandatory script structure (in order)

1. `#Requires -Version 5.1`
2. Top-level `param()` block if needed (e.g., `-AppXOnly` switch) — must be before `Set-StrictMode`
3. `Set-StrictMode -Version Latest`
4. `$ErrorActionPreference = 'Stop'`
5. `.SYNOPSIS` / `.DESCRIPTION` / `.NOTES` block (see `feedback_notes_format.md`)
6. `#region CONFIGURATION` — all editable values in one place, named clearly
7. Helper functions — all simple functions (no `[Parameter()]`, no `[CmdletBinding()]`)
8. `# MAIN` — guarded in top-level `try/catch`

### Function rules

- **All functions must be simple functions** — no `[Parameter()]` attributes, no `[CmdletBinding()]`
- PS 5.1 advanced-function parameter-set resolution is unreliable in IME/SYSTEM context (see P22)
- `[ValidateSet()]` also requires advanced-function mode — document valid values in a comment instead
- All callers should use explicit named parameters regardless

### Logging rules

- Log **only on error** — no chatty success logs
- App install/uninstall logs →
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_<AppName>_Install.txt`
  or `APP_<AppName>_Uninstall.txt`
- Script-only install/uninstall logs →
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<ScriptName>_Install.txt`
  or `SCRIPT_<ScriptName>_Uninstall.txt`
- Other new script-created files must also stay under the IME root:
  - Images and wallpapers:
    `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`
  - App markers:
    `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers`
  - Prefix files, helper scripts, config, shell layout files, and similar data:
    `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles`
- Detection scripts must check these current IME-rooted locations first, then
  check legacy paths only for backward compatibility.
- Log write sequence: `CreateDirectory` → `WriteAllText('', '')` (create empty file) → `AppendAllText`
- Log format: `[yyyy-MM-dd HH:mm:ss] [v{version}] [{Category}] {Message}`
- Categories: `App`, `System`, `Network`, `Permissions`, `Intune`

### Exit code rules

- `0` = success
- `3010` = success, reboot required
- `1` = deliberate failure — Intune retries
- Never swallow a native installer exit code
- Never rely on `$?` alone to determine process success
- If wrapping a native installer, capture `$process.ExitCode` explicitly

### Detection rules (in preference order)

1. Native MSI detection (product code)
2. Native file existence/version detection
3. Native registry detection
4. Custom `Detect.ps1` — only when native cannot accurately prove the desired end state

**Custom detection script requirements:**
- Exit `0` + `Write-Output` (not `Write-Host`) = detected
- Exit `1` / no STDOUT = not detected
- Must be 64-bit (`Run as 32-bit: No`) for any script checking 64-bit paths or HKLM\SOFTWARE
- No STDERR on successful detection

**Marker file pattern** — use when:
- The install evidence (file/registry) is in a user-profile path unreachable from SYSTEM context
- The package is script-only or configuration-only with no software artifact
- The install script writes the marker; Detect.ps1 reads it — both halves must exist

---

## Stage 2 — Validate Locally

**Do this before packaging. Every time. Without exception.**

### 2a — Parse check

```powershell
$errors = $null
$tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    'C:\Path\To\YourScript.ps1', [ref]$tokens, [ref]$errors)
if ($errors.Count -eq 0) {
    Write-Output 'PARSE OK'
} else {
    $errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }
}
```

A parse error = script never runs. No amount of deployment fixes, architecture fixes, or permission fixes will help. **Fix parse errors first.**

Common parse error sources:
- Em dash (`—` U+2014) inside double-quoted strings (see P21)
- Smart quotes (`"` `"`) pasted from documentation or AI output
- Missing closing brackets, braces, or parentheses in complex expressions
- Backtick line continuation with trailing space after the backtick

### 2b — Run as SYSTEM

Use `PsExec64.exe -s -i powershell.exe` or a platform script to test as SYSTEM before packaging:

```powershell
# Verify language mode
Write-Output $PSLanguageMode   # Must be FullLanguage

# Verify architecture
Write-Output [Environment]::Is64BitProcess   # Must be True

# Dry-run the script
& 'C:\Path\To\YourScript.ps1'
```

Things that work as admin but fail as SYSTEM:
- Path assumptions (`%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%`)
- Network share access
- HKCU registry writes (HKCU in SYSTEM context = S-1-5-18 hive, not the user's hive)
- COM objects that require a user session

### 2c — PSScriptAnalyzer lint

```powershell
Invoke-ScriptAnalyzer -Path '.\YourScript.ps1' -Severity Warning,Error
```

Fix or consciously waive:
- Aliases in production scripts
- `Write-Host` usage
- Deprecated `Get-WmiObject` (prefer `Get-CimInstance`)
- Empty catch blocks

---

## Stage 3 — Package

### What goes in the package

Include only what the script needs at runtime:
- Install script (e.g., `Install-AppName.ps1` or `Remove-Office365.ps1`)
- Uninstall script (`Uninstall.ps1`)
- Detection script (`Detect.ps1`) — if using custom detection
- Supporting files: installer binaries (`setup.exe`), config XMLs, assets

**Do not include:**
- Source control files (`.git/`, `.gitignore`)
- Dev artifacts (test scripts, audit notes, draft versions)
- Duplicate or deprecated versions of scripts

Extra files in the payload increase package size, complicate verification, and make it harder to confirm which file was actually deployed to a device.

### Building the .intunewin

```
IntuneWinAppUtil.exe -c "<source folder>" -s "<install script name>" -o "<output folder>"
```

- `-c` = the folder containing all package files
- `-s` = the setup/install script filename (entry point)
- `-o` = output folder for the `.intunewin`

**The `.intunewin` is a snapshot.** It captures the exact file state at packaging time. If you change a script after packaging, you must rebuild. Uploading a new `.intunewin` to an existing Intune app object replaces the content, but devices may have cached the old content — see Stage 4.

---

## Stage 4 — Upload and Portal Configuration

### Portal metadata checklist (in order)

1. Name
2. Description (Company Portal markdown — use the standard template)
3. Publisher
4. App Version — software version if installing software; script `$AppVersion` if script-only
5. Category
6. Informational URL / Privacy URL
7. Developer
8. Install command — must match the `.NOTES` block exactly
9. Uninstall command — must match the `.NOTES` block exactly
10. Installation time (minimum 10 min, maximum 60 min)
11. Install behavior: `System`
12. Device restart behavior
13. Additional return codes (e.g., `3010` if not already default)
14. Detection rule

### Install/uninstall command standard

```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\ScriptName.ps1
```

All four flags are required: `SysNative`, `-ExecutionPolicy Bypass`, `-NoProfile`, `-NonInteractive`.

### After uploading new content

Intune content propagation is not instant. Before testing:
- Wait for the upload to fully process in the portal (spinner gone, version updated)
- Initiate a device sync or wait for the next scheduled check-in cycle
- Do not begin White Glove or Autopilot immediately after upload — allow at least several minutes for content propagation

If testing the same app repeatedly across multiple White Glove attempts:
- Consider creating a **new Win32 app object** for the test build rather than updating the existing one — this eliminates any cached-content ambiguity entirely

---

## Stage 5 — Test Deployment

### White Glove testing sequence

1. Confirm the new package version appears in the portal (not stale)
2. Confirm assignment is correct (device group, Required intent)
3. Confirm dependency chain is correctly configured
4. Begin White Glove provisioning
5. On failure: collect logs **before** resetting the device

### Log collection

After a White Glove failure, retrieve from the device:
- `C:\Windows\Logs\MoSetup\UpdateAgent.log` (ESP/OOBE)
- `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`
  - `IntuneManagementExtension.log`
  - `AppWorkload.log`
  - `AppActionProcessor.log`
  - `AgentExecutor.log`
  - script-written error logs such as `APP_*` and `SCRIPT_*`
- Legacy fallback only, when troubleshooting older packages:
  `C:\IntuneAppLogs\` and `C:\IntuneScriptLogs\`

See `reference_log_triage.md` for triage order and what each log tells you.

---

## Quick Reference — Common Mistakes

| Mistake | Consequence |
|---|---|
| Em dash in double-quoted strings | Parse error, script never runs (P21) |
| `[Parameter()]` on any function param | ParameterBindingException at call site (P22) |
| `powershell.exe` instead of SysNative path | 32-bit host, AppX cmdlets crash silently (P1) |
| Missing `-NonInteractive` flag | Subtle headless behavior differences (P20) |
| Script writes marker before verifying success | Detection passes even on failed install (P23) |
| Testing immediately after content upload | May run stale cached content |
| Using `Write-Host` in Detect.ps1 | Detection always reports "not installed" (P5) |
| Checking `C:\Program Files` path from 32-bit host | WOW64 redirection — wrong path evaluated (P10) |
| Not running parse check before packaging | Every other fix is irrelevant if script doesn't parse |
