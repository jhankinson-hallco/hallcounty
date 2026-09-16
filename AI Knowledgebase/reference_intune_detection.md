---
name: Intune Detection — Types, Custom PS Semantics, Marker Patterns, Exit Codes
description: How Intune detection works, what custom detection scripts must do, and when to use each detection type
type: reference
---

## Detection Rule Types (Preference Order)

1. **MSI** — product code-based; accurate for MSI installs; auto-populated if you know the GUID
2. **File existence / file version** — check for a file at a known path; version comparisons supported
3. **Registry existence / value / version** — check for key, value, or specific data in registry
4. **Custom PowerShell detection script** — only when types 1–3 cannot accurately prove desired state

Never skip down the list if a higher type is sufficient. Native detection rules are simpler, less failure-prone, and require no script maintenance.

---

## Custom Detection Script — Exact Semantics

**Intune considers the app DETECTED (installed) when ALL of these are true:**
- Script exits with code `0`
- Script produces at least one line of STDOUT output

**Intune considers the app NOT DETECTED (not installed) when:**
- Script exits with any non-zero code, OR
- Script exits 0 but produces no STDOUT

**Critical rules:**
- Use `Write-Output`, NOT `Write-Host` — `Write-Host` writes to the information stream, not STDOUT; Intune reads STDOUT
- An empty `Write-Output ''` is sufficient STDOUT if needed, but be explicit
- Any unhandled exception that causes a non-zero exit will be treated as "not detected"
- Detection scripts run frequently (on every policy evaluation cycle); keep them fast and lightweight

---

## Detection Script Template (Marker-Based)

Current standard (2026-08-20): markers are version-gated, not just checked
for existence, and there are now three tiers to check in order - current
Intune marker, PDQ marker, then legacy locations. See
`reference_intune_code_patterns.md`, "Marker Version Comparison + PDQ Marker
Handoff Pattern" for the full `Get-MarkerVersion`/`Compare-MarkerVersion`/
`Test-MarkerSatisfiesVersion` function definitions referenced below - copy
them in alongside this template rather than reinventing the comparison
logic.

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName          = 'AppName'
$script:RequiredVersion  = '1.0.0'   # or a yyyy-MM-dd date - see below
$script:IntuneMarkerPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\$($script:AppName).marker"
$script:PdqMarkerPath    = "C:\ProgramData\PDQ\AppMarkers\$($script:AppName).marker"
$script:LegacyMarkerPaths = @(
    "C:\IntuneAppMarkers\$($script:AppName).tag"
    # add other historical per-project legacy paths here as needed
)

# Get-MarkerVersion / Compare-MarkerVersion / Test-MarkerSatisfiesVersion
# copied in from reference_intune_code_patterns.md

try {
    $IntuneResult = Test-MarkerSatisfiesVersion -MarkerPath $script:IntuneMarkerPath -RequiredVersion $script:RequiredVersion
    if ($IntuneResult -eq 'Detected') {
        Write-Output 'Detected: current Intune marker satisfies required version'
        exit 0
    }
    if ($IntuneResult -eq 'NotDetected') {
        # Authoritative marker present but stale - do not fall through.
        exit 1
    }

    $PdqResult = Test-MarkerSatisfiesVersion -MarkerPath $script:PdqMarkerPath -RequiredVersion $script:RequiredVersion
    if ($PdqResult -eq 'Detected') {
        Write-Output 'Detected: PDQ marker satisfies required version'
        exit 0
    }

    foreach ($LegacyPath in $script:LegacyMarkerPaths) {
        if (Test-Path -LiteralPath $LegacyPath -PathType Leaf) {
            Write-Output 'Detected: legacy marker present (temporary compatibility, no version distinction)'
            exit 0
        }
    }

    exit 1
}
catch {
    exit 1
}
```

Keep detection scripts to this pattern when marker-based. Nothing more.

---

## When to Use Marker Files

Use a marker file when:
- The payload is script-only or configuration-only (no software binary to detect)
- The software does not leave reliable, version-stable evidence (registry key moves, no file version, etc.)
- You need to track "this configuration was applied" rather than "this software exists"

**Current marker locations (2026-08-20 policy):**

- Intune-authoritative: `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\<AppName>.marker`
- PDQ (secondary, existence-prevents-duplicate-install only):
  `C:\ProgramData\PDQ\AppMarkers\<AppName>.marker`
- Legacy (existence-only fallback, temporary, being phased out):
  `C:\IntuneAppMarkers\<ScriptName>.tag` and other historical per-project
  paths.

**Markers must include a version, not just exist.** Every marker written by
a new or remediated script must contain a `Version=` line:

```
Status=Success
Version=1.0.2
Timestamp=2026-03-27 09:15:00
```

Use the real software version when known. **If no real version is
available, use the file's download date in `yyyy-MM-dd` format instead**
(e.g., `Version=2026-08-20`) - `Compare-MarkerVersion` in
`reference_intune_code_patterns.md` handles both formats. Detection must
compare the marker's `Version=` value against the script's own required
version, not just check that the file exists - see the template above.

**Temporary migration leniency (2026-08-20, will be phased out):** a marker
that exists but has no `Version=` line at all - i.e. it predates this
policy, or lives at a legacy location that never had version data - is
still accepted as detected. This bridges already-deployed packages so they
do not all appear "not detected" and trigger mass reinstalls the moment a
project's `Detect.ps1` is remediated to this standard. Do not remove this
leniency from an individual project's detection script without Jeremy's
direction, and do not treat it as a permanent design feature - it goes away
once every project's markers have been remediated to carry real version
data.

**PDQ/Intune authority handoff:** a PDQ marker only satisfies detection if
its version is at least the required version - its only purpose is to stop
Intune from reinstalling a version PDQ already deployed. The moment Intune
successfully installs/updates an app, the install script must write the
current Intune marker AND delete any PDQ marker for that same app (see
`Remove-StalePdqMarker` in `reference_intune_code_patterns.md`) - Intune is
now authoritative and a leftover PDQ marker must never be consulted again.

---

## Detection for 64-bit vs 32-bit

For custom detection scripts in Intune portal:
- **"Run script as 32-bit process on 64-bit clients"** → `No` for any check against 64-bit paths
- If checking `C:\Program Files` or `HKLM:\Software` (non-WOW6432Node), must run as 64-bit
- If the wrong bit-ness is set, registry/file paths may be silently redirected and detection always fails or always passes incorrectly

---

## Native Detection: File Type Settings

| Setting | Notes |
|---|---|
| Rule type: File | Check for file or folder existence |
| Path | Folder path only (e.g., `C:\Program Files\AppName`) |
| File or folder name | Just the file/folder name |
| Detection method | "File or folder exists" is simplest; "String version" for version gating |
| Associated with 32-bit app | `No` for 64-bit installs; `Yes` forces 32-bit registry/path view |

---

## Native Detection: Registry Type Settings

| Setting | Notes |
|---|---|
| Key path | Full path, e.g., `HKEY_LOCAL_MACHINE\SOFTWARE\AppName` |
| Value name | Specific value name, or blank to check for key existence |
| Detection method | Key exists / String comparison / Integer comparison |
| Associated with 32-bit app | `No` for 64-bit; `Yes` redirects to WOW6432Node |

---

## Detection Must Prove End State, Not Installer Run

Detection that only proves "the installer ran" is insufficient. Examples:
- BAD: Detect a temp extraction folder (transient, cleaned up)
- BAD: Detect an IME cache artifact
- BAD: Detect the installer EXE itself (may be present without install completing)
- GOOD: Detect the installed binary in `Program Files`
- GOOD: Detect a registry value written by the installer's post-install phase
- GOOD: Detect a marker file written by the script only after all steps succeeded

---

## Paired Script / Detection Version Tracking

Keep detection script version and paired-script reference in `.NOTES`:

```
Script Version: 1.0.1
Paired script:  System-Device_Branding.ps1 v1.0.2
```

When the install script version changes, update the detect script's `.NOTES` reference. When detection logic changes, bump the detect script's own version.
