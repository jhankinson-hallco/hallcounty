---
name: Install-ExeTemplate.ps1 — Design Rules, Constraints, and Known Behaviors
description: Everything learned building and fixing the hardened EXE installer template; apply when deriving new Win32 app scripts from the template
type: reference
---

# Install-ExeTemplate.ps1 — Design Reference

## Location and Current Version

- Template: `Software\.Generic Template\Install-exeTemplate.ps1`
- Current template version: `1.1.4`
- Any app derived from the template before v1.1.4 carries P22 ([Parameter()] on all functions) and P24 (Split-Path -LiteralPath -Parent). Those scripts must be audited separately.

---

## Key Design Decisions

### Process Launch — `System.Diagnostics.Process` not `Start-Process`

Uses `System.Diagnostics.ProcessStartInfo` + `Process.WaitForExit(milliseconds)` directly, NOT `Start-Process -Wait`.

**Why:** `Start-Process -Wait` does not return a reliable exit code in all SYSTEM/IME contexts. `.WaitForExit(ms)` gives explicit timeout control and returns `[int]$process.ExitCode` reliably. `Start-Process` also does not support hard timeouts — it blocks indefinitely.

### Working Directory

`$startInfo.WorkingDirectory` is set to `[System.IO.Path]::GetDirectoryName($FilePath)` (the installer EXE's parent folder, which is the same folder as the script). This means relative paths in `$InstallArguments` (e.g., `'HallCounty-Default-Office-Config.xml'`) resolve correctly without needing absolute paths.

### Argument Passing — Array, Not String

`$script:InstallArguments` is a `[string[]]` array, joined with spaces by `Join-InstallerArguments`. Each element is one logical argument block. Quotes must be included literally in the element if the vendor requires them — the script does NOT add quoting.

### Timeout Ceiling

`$script:TimeoutSeconds` must be between 1 and 1199. The template validation rejects `>= 1200` to ensure the script can fail cleanly before IME's 20-minute hard kill. This is a hard constraint — Office uninstalls or slow installs may need the full 1199.

### Log-on-Error Only

`Write-ErrorLog` only fires on failure. No chatty success logging by design.
The log file is created lazily under
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` only when an error
occurs.

### Optional DetectionPath

`$script:DetectionPath` is a post-install file existence check internal to the script — a local guardrail only. Intune still requires its own detection rule. Leave blank when the real install evidence is not a simple file (e.g., %LOCALAPPDATA% installs unreachable from SYSTEM context). In that case use a marker file pattern instead (see below).

### SkipInstallIfAlreadyDetected

Only meaningful when `$script:DetectionPath` is set. If blank, this flag is inert. **For uninstall scripts, set `$script:DetectionPath = ''` and `$script:SkipInstallIfAlreadyDetected = $false`** — the flag is semantically backwards for uninstalls.

---

## Marker File Pattern (RingCentral precedent)

When the app installs to `%LOCALAPPDATA%` (user-profile path), that path is unreachable from SYSTEM/device context. The correct pattern:

1. Install script writes a marker file to
   `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\<AppName>.marker`
   on successful exit, **after** all success checks pass, with a `Version=`
   line per the current marker-versioning policy (see
   `reference_intune_detection.md`).
2. `Detect.ps1` checks that current marker path first (version-gated), then
   falls back to the PDQ marker and legacy marker paths per the three-tier
   detection policy — it does not attempt to find the real install path.
3. Marker write failure is treated as **exit 1** (hard failure), not silently swallowed — without the marker Intune will retry forever.

**Template config for marker-pattern apps:**

```powershell
$script:DetectionPath = ''     # leave blank - no native file check
$script:MarkerFile    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\AppName.marker'
```

Marker write block (add after `$shouldVerifyDetection` block, before `exit $exitCode`):

```powershell
if (-not [string]::IsNullOrWhiteSpace($script:MarkerFile)) {
    try {
        $markerDir = [System.IO.Path]::GetDirectoryName($script:MarkerFile)
        [void][System.IO.Directory]::CreateDirectory($markerDir)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText(
            $script:MarkerFile,
            ('Version={0}' -f $script:AppVersion),
            $utf8NoBom
        )
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Exit-Failure -Code 1 -Message ('Install succeeded but marker file could not be written to ''{0}'': {1}' -f $script:MarkerFile, $summary) -Category 'System'
    }
}
```

**Note:** In the base template, `$script:AppVersion` holds the template's own
script version (currently `1.1.4`), not the deployed software's version. A
project derived from the template must repoint `$script:AppVersion` at the
real installed software version (or add a dedicated variable) before using it
in the marker's `Version=` line — writing the script's own version into the
marker does not satisfy the marker-versioning policy in
`reference_intune_detection.md`. If the real software version is not
available, use the file's download date (`yyyy-MM-dd`) instead.

---

## Template Is Not Suitable For Uninstalls As-Is

- `$script:DetectionPath` checks file **exists** — wrong direction for uninstalls.
- `$script:SkipInstallIfAlreadyDetected` skips if file exists — semantically backwards.
- Safe uninstall config: set both to blank/false and let a dedicated `Detect.ps1` carry idempotency.

---

## Apps Currently Derived From This Template

| Script | Version | Marker? | Notes |
| --- | --- | --- | --- |
| `Software\RingCentral\Install-RingCentral.ps1` | 1.0.2 | Yes — `C:\ProgramData\RingCentral\install.marker` | %LOCALAPPDATA% install path |
| `Software\Microsoft Office 365\Hall County Default Office 365\Install-Office365.ps1` | 1.0.1 | No | ODT install; file detection in portal |
