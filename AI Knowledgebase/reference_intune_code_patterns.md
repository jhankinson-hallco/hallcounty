---
name: Intune Reusable Code Patterns — Logging, Markers, Hive Ops, Reg.exe, Exit Handling
description: Proven, battle-tested code blocks for use across Win32 app scripts; copy-paste reliable
type: reference
---

## Script Header Template

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    One-line summary.

.DESCRIPTION
    What the script does, what it configures, and what state it leaves.
    Marker/log behavior summary.
    Exit codes documented.

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

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\ScriptName.ps1

      Install behavior: System
#>
```

**Campus-wide (2026-09-08):** `ERROR CODES` sits between `Purpose` and
`CHANGE LOG`, as shown above - this replaces the older `RETURN CODES`
section that used to sit after `CHANGE LOG`/`INTUNE CONFIGURATION`. List
every exit code the script can actually return (see the `Write-ErrorLog` +
`$ERR_*` constant pattern below for how `System Scripts\Serial Marker\`
implements a per-project numeric range, e.g. `1601-1699`), not just the
generic `0`/`3010`/`1` shown in the bare template. Apply this to a given
script the next time that script is otherwise touched, rather than a mass
retrofit.

---

## Configuration Section Template

```powershell
# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppVersion = '1.0.0'

# Source paths (relative to package root)
$script:SomeSourceFile = Join-Path -Path $PSScriptRoot -ChildPath 'FileName.ext'

# Destination paths
$script:DestRoot    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\SubFolder'
$script:DestFile    = Join-Path -Path $script:DestRoot -ChildPath 'FileName.ext'

# Registry paths
$script:SomeRegKey  = 'HKLM:\SOFTWARE\SomePath'

# Markers and logs - current IME-rooted standard (2026-08-20). C:\IntuneAppLogs
# and C:\IntuneAppMarkers are legacy fallback paths only - do not use for new
# work. See "Marker Version Comparison + PDQ Marker Handoff Pattern" below.
$script:MarkerRoot     = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:MarkerPath     = Join-Path -Path $script:MarkerRoot -ChildPath 'AppName.marker'
$script:PdqMarkerRoot  = 'C:\ProgramData\PDQ\AppMarkers'
$script:PdqMarkerPath  = Join-Path -Path $script:PdqMarkerRoot -ChildPath 'AppName.marker'
$script:LogRoot        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile        = Join-Path -Path $script:LogRoot -ChildPath 'APP_AppName_Install.txt'

# =============================================================================
# END CONFIGURATION
# =============================================================================
```

---

## Buffered Error-Only Logging Pattern

```powershell
$script:LogBuffer   = @()
$script:HasWarnings = $false
$script:HasErrors   = $false

function Add-LogLine {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    try {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $script:LogBuffer += "$Timestamp [$Level] $Message"
    }
    catch { }
    if ($Level -eq 'WARN')  { $script:HasWarnings = $true }
    if ($Level -eq 'ERROR') { $script:HasErrors   = $true }
}

function Write-LogIfNeeded {
    try {
        if (-not ($script:HasWarnings -or $script:HasErrors)) { return }
        try { New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null } catch { return }
        try   { $RunHeader = "=== Run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') v$($script:AppVersion) ===" }
        catch { $RunHeader = '=== Run (timestamp unavailable) ===' }
        $Lines = (@('', $RunHeader) + $script:LogBuffer) -join "`r`n"
        Add-Content -LiteralPath $script:LogFile -Value ($Lines + "`r`n") -Encoding UTF8 -ErrorAction Stop
    }
    catch { }
}
```

**Key behaviors:**

- Log file only created if warnings or errors occurred (no chatty success logs)
- Appends across runs (accumulates history)
- Creates log folder on first write, not at script start
- All internal failures are silently swallowed to avoid masking the real error
- CLM-safe: uses `@()` + `+=` instead of `List[string]::new()` + `.Add()`; `New-Item` instead of `[System.IO.Directory]::CreateDirectory`; `Add-Content` instead of `[System.IO.File]::AppendAllText`

---

## Marker File Write Pattern

```powershell
function New-MarkerLines {
    param(
        [Parameter(Mandatory)][string]$Status,
        [string[]]$AdditionalLines = @()
    )
    $Lines = @()
    try { $Lines += "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" } catch { }
    $Lines += "Version=$($script:AppVersion)"
    $Lines += "Status=$Status"
    foreach ($Line in $AdditionalLines) { $Lines += $Line }
    return $Lines
}

function Write-Marker {
    param([string[]]$Lines)
    # CLM-safe: New-Item instead of [System.IO.Directory]::CreateDirectory;
    # Set-Content instead of [System.IO.File]::WriteAllText/WriteAllLines.
    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction SilentlyContinue | Out-Null
    $Lines | Set-Content -LiteralPath $script:MarkerPath -Encoding UTF8 -ErrorAction Stop
}
```

**Usage in MAIN:**
```powershell
$FinalStatus = if ($script:HasWarnings) { 'CompletedWithWarnings' } else { 'Success' }
Write-Marker -Lines (New-MarkerLines -Status $FinalStatus -AdditionalLines @(
    "SomeKey=$($script:SomeValue)"
))
```

---

## Marker Version Comparison + PDQ Marker Handoff Pattern

Policy (Jeremy, 2026-08-20): every new marker must carry a `Version=` line
usable for version-gated detection, not just existence. PDQ deployments get
their own marker at a separate root; Intune's own marker is always
authoritative once it exists, and Intune deletes any PDQ marker for the same
app once Intune itself has successfully installed.

```powershell
$script:IntuneMarkerRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:PdqMarkerRoot    = 'C:\ProgramData\PDQ\AppMarkers'

function Get-MarkerVersion {
    # Returns $null if the marker does not exist. Otherwise returns a
    # psobject with Exists=$true and Version = the Version= line's value,
    # or Version=$null if the marker exists but has no Version= line
    # (older marker, or a legacy marker predating this policy).
    param(
        [Parameter(Mandatory)][string]$MarkerPath
    )
    if (-not (Test-Path -LiteralPath $MarkerPath -PathType Leaf)) {
        return $null
    }
    $VersionValue = $null
    $Content = Get-Content -LiteralPath $MarkerPath -ErrorAction SilentlyContinue
    foreach ($Line in $Content) {
        if ($Line -match '^Version=(.*)$') {
            $VersionValue = $Matches[1].Trim()
            break
        }
    }
    return New-Object -TypeName psobject -Property @{ Exists = $true; Version = $VersionValue }
}

function Compare-MarkerVersion {
    # Returns 'AtLeast', 'Older', or 'Unknown' (could not compare - treat as
    # not satisfying the requirement; do not treat Unknown as a pass).
    # Tries [version] first (real ScriptVersion/AppVersion values), then
    # falls back to yyyy-MM-dd date parsing (the download-date fallback
    # value used when no real software version exists).
    param(
        [Parameter(Mandatory)][string]$MarkerVersion,
        [Parameter(Mandatory)][string]$RequiredVersion
    )
    try {
        if (([version]$MarkerVersion) -ge ([version]$RequiredVersion)) { return 'AtLeast' }
        return 'Older'
    }
    catch {
        try {
            $MarkerDate = [datetime]::ParseExact($MarkerVersion, 'yyyy-MM-dd', $null)
            $RequiredDate = [datetime]::ParseExact($RequiredVersion, 'yyyy-MM-dd', $null)
            if ($MarkerDate -ge $RequiredDate) { return 'AtLeast' }
            return 'Older'
        }
        catch {
            return 'Unknown'
        }
    }
}

function Test-MarkerSatisfiesVersion {
    # Returns 'Detected', 'NotDetected', or 'Absent' (no marker file at all).
    # TEMPORARY migration leniency (Jeremy, 2026-08-20): a marker that exists
    # but has no Version= line at all (predates this policy, or a legacy
    # marker location) is still accepted as 'Detected'. This is intentional
    # and will be phased out once all scripts have been remediated to write
    # versioned markers - do not remove this branch without Jeremy's
    # direction, and do not rely on it remaining forever.
    param(
        [Parameter(Mandatory)][string]$MarkerPath,
        [Parameter(Mandatory)][string]$RequiredVersion
    )
    $Marker = Get-MarkerVersion -MarkerPath $MarkerPath
    if ($null -eq $Marker) { return 'Absent' }
    if ([string]::IsNullOrWhiteSpace($Marker.Version)) { return 'Detected' }
    $Comparison = Compare-MarkerVersion -MarkerVersion $Marker.Version -RequiredVersion $RequiredVersion
    if ($Comparison -eq 'AtLeast') { return 'Detected' }
    return 'NotDetected'
}

function Remove-StalePdqMarker {
    # Call this from the INSTALL script (not detection) immediately after a
    # successful Intune-driven install/update, for the same AppName the PDQ
    # marker would have been written under. Intune is now authoritative;
    # a leftover PDQ marker must not be consulted again.
    param(
        [Parameter(Mandatory)][string]$AppName
    )
    $PdqMarkerPath = Join-Path -Path $script:PdqMarkerRoot -ChildPath "$AppName.marker"
    if (Test-Path -LiteralPath $PdqMarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $PdqMarkerPath -Force -ErrorAction SilentlyContinue
    }
}

function Remove-AllMarkerTiers {
    # Policy (Jeremy, 2026-08-20): EVERY uninstall script - Intune or PDQ -
    # removes ALL marker tiers for its app, not just the one its own channel
    # writes. A PDQ uninstall must also remove the Intune marker (and vice
    # versa), so a real uninstall never leaves any marker behind that could
    # falsely satisfy a future detection run. List every legacy path this
    # project has ever used, not just one.
    param(
        [Parameter(Mandatory)][string]$AppName,
        [string[]]$LegacyMarkerPaths = @()
    )
    $MarkerPaths = @(
        (Join-Path -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers' -ChildPath "$AppName.marker"),
        (Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath "$AppName.marker")
    ) + $LegacyMarkerPaths

    foreach ($MarkerPath in $MarkerPaths) {
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction SilentlyContinue
        }
    }
}
```

**Mandatory vs. best-effort:** whether `Remove-AllMarkerTiers` (or an
inline equivalent) should throw on a leftover marker or just log a warning
depends on the SAME test already used for other uninstall cleanup in this
shop's scripts: does this step protect against reporting false success for
a removal THIS run performed (mandatory, verify and throw), or is it
tidying up an already-irrelevant leftover on an idempotent/already-absent
path (best-effort, catch and continue)? Apply per-project, matching
whatever convention that project's uninstall script already uses for its
other cleanup steps (shortcut removal, etc.) - do not introduce a third,
inconsistent style within the same script.

**Version value convention:** use the real software version (`1.2.3`) when
known. **If no real version is available, use the download date in
`yyyy-MM-dd` format instead** (e.g., `Version=2026-08-20`) - this still
sorts and compares correctly via the date-parsing fallback in
`Compare-MarkerVersion` above. Do not mix formats for the same app across
runs.

**Field name flexibility:** the generic templates in this file use
`Version=` for the software-version field. Some projects (e.g. Barracuda
NAC VPN) already have an established two-field marker convention -
`Version=` for the deploying SCRIPT's own version (used to force
reinstall/reconfiguration on a script logic change) and `ProductVersion=`
for the installed SOFTWARE's version. In that case, adapt this policy onto
the field that already matches its intent (`ProductVersion=`) rather than
introducing a second, competing `Version=` meaning in the same marker -
keep the project's existing script-version field doing what it already
does. Document the deviation in that project's own `AI-Audit-Decisions.md`.

**Detection check order (current standard, both markers version-gated the
same way):**

1. `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\<AppName>.marker`
   - If present and version satisfies the requirement: detected.
   - If present but version is older (`NotDetected`): NOT detected - do
     not fall through to PDQ/legacy; the authoritative Intune marker is
     explicitly stale and a reinstall is needed.
2. If the Intune marker is absent, check
   `C:\ProgramData\PDQ\AppMarkers\<AppName>.marker` the same way. This
   exists only to stop Intune from reinstalling a version PDQ already
   installed - if it's older than required, Intune should proceed to
   install, exactly as if no marker existed at all.
3. If neither is present, legacy marker locations may be checked as a
   last resort (existence only, no version distinction) - see
   `reference_intune_detection.md`.

**Install-script responsibility:** after a successful Intune install, write
the Intune marker (with `Version=`) AND call `Remove-StalePdqMarker` for the
same `AppName`, even if no PDQ marker is expected to exist - it is a safe
no-op when absent, and guarantees no stale PDQ marker survives an Intune
takeover.

**PDQ-script responsibility:** after a successful PDQ install, write only
the PDQ marker (`C:\ProgramData\PDQ\AppMarkers\<AppName>.marker`, same
`Version=` line convention) - PDQ scripts do not touch the Intune marker.

---

## PDQ Marker Companion Script (Standalone, Minimal)

Policy (Jeremy, 2026-08-20): every PDQ deployment package - even one with no
Intune counterpart yet - includes this dedicated script as its own PDQ
package step, run LAST, after the real install/uninstall step succeeds.
Its only job is the PDQ marker. Keep it this simple; do not fold other
logic into it.

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Writes/updates the PDQ deployment marker for <AppName>.

.DESCRIPTION
    Standalone PDQ Deploy package step. Sole job: record that PDQ has
    installed <AppName> at $script:Version, so Intune detection (now or
    whenever this app gets an Intune deployment) recognizes the existing
    install and does not reinstall it. Run as the LAST step of the PDQ
    package, after the real install step succeeds. Removes any
    pre-existing marker before writing the new one - always a clean write,
    never a stale leftover from a prior version.

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy PowerShell Step
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  DD/MM/YYYY
    Purpose:        Write/update the PDQ marker for <AppName>

    CHANGE LOG
    Change: DD/MM/YYYY - Initial release -- ver. 1.0.0

    Keep $script:Version in sync with the actual bundled/deployed
    installer version every time this PDQ package is updated - same
    discipline as Intune's Install/Detect version sync.
#>

$script:AppName    = '<AppName>'
$script:Version    = '<X.X.X or yyyy-MM-dd>'
$script:MarkerRoot = 'C:\ProgramData\PDQ\AppMarkers'
$script:MarkerPath = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')

try {
    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction SilentlyContinue | Out-Null

    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
    }

    Set-Content -LiteralPath $script:MarkerPath -Value ('Version=' + $script:Version) -Encoding UTF8 -Force -ErrorAction Stop

    Write-Output ('PDQ marker updated: {0} -> Version={1}' -f $script:MarkerPath, $script:Version)
    exit 0
}
catch {
    Write-Output ('Failed to write PDQ marker: {0}' -f $_.Exception.Message)
    exit 1
}
```

**Naming:** `Set-<AppName>Marker-PDQ.ps1`, in the project's `PDQ\` subfolder.

**PDQ package configuration:** this step writing the marker is a
record-keeping action, not the actual software install - if it fails after
a successful install step, that generally should not undo or block the
already-successful install. Configure this step's failure behavior in the
PDQ package accordingly (do not let a marker-write failure roll back or
re-flag an otherwise-successful deployment), while still surfacing the
failure via its exit code and STDOUT for visibility.

---

## Default User Hive Mount/Unmount Pattern (reg.exe)

```powershell
$script:DefaultHivePath     = 'C:\Users\Default\NTUSER.DAT'
$script:TempHiveMountPoint  = 'HKU\TempDefault'
$script:RegExe              = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'

function Set-DefaultUserHiveValues {
    $HiveLoaded = $false
    try {
        # Pre-emptive unload: prevents infinite retry if prior run was killed before unload
        & $script:RegExe unload $script:TempHiveMountPoint 2>&1 | Out-Null

        if (-not (Test-Path -LiteralPath $script:DefaultHivePath -PathType Leaf)) {
            throw "Default User hive not found at '$($script:DefaultHivePath)'."
        }
        $LoadOutput = & $script:RegExe load $script:TempHiveMountPoint $script:DefaultHivePath 2>&1
        if ($LASTEXITCODE -ne 0) { throw "reg load failed (exit $LASTEXITCODE): $LoadOutput" }
        $HiveLoaded = $true

        # Write values using reg.exe (not PS Registry provider — provider handles block unload)
        $SomeKey = "$script:TempHiveMountPoint\Some\Sub\Key"
        $Out = & $script:RegExe add $SomeKey /v 'ValueName' /t REG_SZ /d 'ValueData' /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to set value (exit $LASTEXITCODE): $Out" }
    }
    finally {
        if ($HiveLoaded) {
            # GC before unload: release any residual .NET handles on the hive
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $UnloadOutput = & $script:RegExe unload $script:TempHiveMountPoint 2>&1
            if ($LASTEXITCODE -ne 0) {
                Add-LogLine -Message "reg unload warning (exit $LASTEXITCODE): $UnloadOutput" -Level 'WARN'
            }
        }
    }
}
```

**Why reg.exe instead of PS Registry provider:**
- PS Registry provider keeps open handles on mounted hives
- Open handles cause `reg unload` to fail (access denied / busy)
- reg.exe write + PS Registry read = handle conflict
- Use reg.exe for ALL writes to mounted hives; avoid PS provider entirely for hive operations

**Why pre-emptive unload:**
- If the script was killed/crashed between `reg load` and `reg unload`, the mount persists across reboots in HKEY_USERS
- Next run: `reg load` fails with "already loaded" → script throws → no marker written → Intune retries forever
- Solution: attempt `reg unload` before `reg load`, discard result; idempotent

**Why GC before unload:**
- .NET strings created from reg.exe output may hold internal handles into the hive path
- `[System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()` releases them before unload attempt

---

## Registry Key Creation + Value Set Pattern

```powershell
# Create key if missing, then set value
if (-not (Test-Path -LiteralPath $script:SomeKey)) {
    New-Item -Path $script:SomeKey -Force -ErrorAction Stop | Out-Null
}
Set-ItemProperty -Path $script:SomeKey -Name 'ValueName' -Value 'ValueData' -Type String -Force -ErrorAction Stop
```

Use `-Type String` / `DWord` / `ExpandString` explicitly — never let PowerShell infer the type.

---

## Registry Value Removal Pattern (Graceful)

```powershell
function Remove-PolicyValue {
    param(
        [Parameter(Mandatory)][string]$KeyPath,
        [Parameter(Mandatory)][string]$ValueName
    )
    try {
        if (-not (Test-Path -LiteralPath $KeyPath)) { return }
        $Existing = Get-ItemProperty -LiteralPath $KeyPath -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $Existing) { return }
        Remove-ItemProperty -LiteralPath $KeyPath -Name $ValueName -Force -ErrorAction Stop
    }
    catch {
        Add-LogLine -Message "Failed to remove '$ValueName' from '$KeyPath': $($_.Exception.Message)" -Level 'WARN'
    }
}
```

---

## MAIN try/catch Shell

```powershell
try {
    # Step 1: ...
    # Step 2: ...
    # Step 3: ...

    $FinalStatus = if ($script:HasWarnings) { 'CompletedWithWarnings' } else { 'Success' }
    Write-Marker -Lines (New-MarkerLines -Status $FinalStatus)
    Write-LogIfNeeded
    exit 0
}
catch {
    try { Add-LogLine -Message "Installation failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Level 'ERROR' } catch { }
    try { Write-LogIfNeeded } catch { }
    exit 0  # or exit 1 if failure should block Intune retry; see exit code policy
}
```

---

## Writing Theme Files (CRLF-Safe, No BOM)

```powershell
$ThemeLines = @(
    '[Theme]'
    'DisplayName=MyTheme'
    ''
    '[Control Panel\Desktop]'
    "Wallpaper=C:\Path\To\Wallpaper.jpg"
    'TileWallpaper=0'
    'WallpaperStyle=10'
    'Pattern='
    ''
    '[VisualStyles]'
    'Path=%SystemRoot%\Resources\Themes\Aero\Aero.msstyles'
    'ColorStyle=NormalColor'
    'Size=NormalSize'
    'AutoColorization=0'
)
# Explicit CRLF join — source-file-encoding-independent (unlike here-strings)
$ThemeContent = ($ThemeLines -join "`r`n") + "`r`n"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($ThemeFilePath, $ThemeContent, $Utf8NoBom)
```

**Do NOT use here-strings for theme files.** Here-string line endings mirror the source `.ps1` encoding. If the file has LF-only line endings (e.g., Git checkout on Linux/Mac), the theme file gets LF-only, which Windows theme engine may reject or misparse.

**Do NOT include `[Slideshow]` section** unless you have actual image items (`Item0Path=...` or `ImagesRootPath=...`). An empty slideshow section can cause a black desktop on some Windows 11 builds.

---

## File Copy with Source Validation

```powershell
function Copy-DeploymentFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required file not found in package at '$Source' — check package contents."
    }
    # CLM-safe: Split-Path instead of [System.IO.Path]::GetDirectoryName;
    # New-Item instead of [System.IO.Directory]::CreateDirectory.
    $DestDir = Split-Path -Path $Destination -Parent
    New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
}
```

---

## CLM-Safe .NET Substitution Reference

Under WDAC/AppLocker Constrained Language Mode, all `.NET` static method calls and type instantiations are blocked. Use the PS cmdlet equivalents below in all production scripts. See **P18** in `reference_intune_pitfalls.md` for the full failure-mode description.

| Blocked (.NET — CLM-unsafe) | Replacement (PS cmdlet — CLM-safe) |
| --- | --- |
| `[System.Collections.Generic.List[string]]::new()` | `@()` |
| `$list.Add($item)` | `$array += $item` |
| `$list.ToArray()` | `$array` (plain PS array, no conversion needed) |
| `[System.IO.Directory]::CreateDirectory($path)` | `New-Item -ItemType Directory -Path $path -Force -ErrorAction SilentlyContinue \| Out-Null` |
| `[System.IO.File]::AppendAllText($path, $content, $enc)` | `Add-Content -LiteralPath $path -Value $content -Encoding UTF8 -ErrorAction Stop` |
| `[System.IO.File]::WriteAllText($path, $content, $enc)` | `Set-Content -LiteralPath $path -Value $content -Encoding UTF8 -ErrorAction Stop` |
| `[System.IO.File]::WriteAllLines($path, $lines, $enc)` | `$lines \| Set-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop` |
| `[System.IO.Path]::Combine($a, $b)` | `Join-Path -Path $a -ChildPath $b` |
| `[System.IO.Path]::GetDirectoryName($path)` | `Split-Path -Path $path -Parent` |
| `[System.Environment]::NewLine` | `` "`r`n" `` |
| `[datetime]::Now` | `Get-Date` |
| `[System.Text.Encoding]::UTF8` | Use `-Encoding UTF8` parameter on cmdlet |

**Key rule:** If `$ErrorActionPreference = 'Stop'` is set and a blocked .NET call is placed **outside** the main `try/catch`, it will propagate directly to the PS runtime as an unhandled terminating exception → exit code 1 with no logging. Move all initialization code inside the `try` block, or replace with CLM-safe equivalents.

**Exception:** `.NET` calls inside a `try/catch` that swallows the error (e.g., `try { $x = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $x = 'unknown' }`) fail gracefully and are acceptable for non-critical enrichment data.
