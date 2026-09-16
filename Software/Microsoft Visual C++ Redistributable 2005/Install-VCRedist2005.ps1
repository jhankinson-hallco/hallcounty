#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =========================
# CONFIG
# =========================
$Year = '2005'
$InstallerRelativePath = 'vcredist_x86.exe'
$InstallerArgs = @('/q')   # adjust only if your 2005 build differs
# =========================

$StateRoot = "C:\ProgramData\VCRedist\$Year"
$FlagFile  = Join-Path $StateRoot 'Installed.flag'
$GuidFile  = Join-Path $StateRoot 'ProductCode.txt'

$LogRoot = 'C:\IntuneAppLogs'
$LogFile = Join-Path $LogRoot "VCRedist$Year_Install.txt"

$EXIT_SUCCESS = 0
$EXIT_REBOOT  = 3010
$EXIT_RETRY   = 1618
$EXIT_FAILURE = 1

function Ensure-ErrorLog {
    try {
        if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }
        return $true
    } catch { return $false }
}

function Write-ErrorLog([string]$Message) {
    if (-not (Ensure-ErrorLog)) { return }
    try {
        Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $Message"
    } catch { }
}

function Ensure-StateRoot {
    if (-not (Test-Path $StateRoot)) { New-Item -Path $StateRoot -ItemType Directory -Force | Out-Null }
}

function Get-UninstallGuidSet {
    # GUID key names only; no registry values, no properties
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($k in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $name = $k.PSChildName
            if ($name -match '^\{[0-9A-Fa-f-]{36}\}$') {
                [void]$set.Add($name.ToUpperInvariant())
            }
        }
    }
    return $set
}

function Get-UninstallRootForGuid {
    param([Parameter(Mandatory)][string]$Guid)

    $wow = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$Guid"
    if (Test-Path $wow) { return 'WOW6432Node' }

    $std = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$Guid"
    if (Test-Path $std) { return 'Standard' }

    return $null
}

function Select-GuidDeterministically {
    param([Parameter(Mandatory)][string[]]$Guids)

    # Prefer WOW6432Node presence, otherwise stable lexicographic
    $wow = @()
    $std = @()

    foreach ($g in $Guids) {
        $where = Get-UninstallRootForGuid -Guid $g
        if ($where -eq 'WOW6432Node') { $wow += $g }
        elseif ($where -eq 'Standard') { $std += $g }
    }

    $candidates = if ($wow.Count -gt 0) { $wow } else { $std }
    return ($candidates | Sort-Object)[0]
}

try {
    # Marker-based idempotency
    if (Test-Path $FlagFile) { exit $EXIT_SUCCESS }

    $exePath = Join-Path $PSScriptRoot $InstallerRelativePath
    if (-not (Test-Path -LiteralPath $exePath)) {
        Write-ErrorLog "Installer not found: '$exePath'"
        exit $EXIT_FAILURE
    }

    $before = Get-UninstallGuidSet

    # Run installer deterministically and capture exit code safely under StrictMode
    $proc = Start-Process -FilePath $exePath `
                          -ArgumentList $InstallerArgs `
                          -Wait `
                          -PassThru `
                          -WindowStyle Hidden

    $rc = [int]$proc.ExitCode

    if ($rc -eq 1618) { exit $EXIT_RETRY }
    if ($rc -ne 0 -and $rc -ne 3010 -and $rc -ne 1641) {
        Write-ErrorLog "Installer returned exit code $rc."
        exit $EXIT_FAILURE
    }

    Start-Sleep -Seconds 5

    $after = Get-UninstallGuidSet

    $new = @()
    foreach ($g in $after) {
        if (-not $before.Contains($g)) { $new += $g }
    }

    Ensure-StateRoot

    if ($new.Count -gt 0) {
        $selected = Select-GuidDeterministically -Guids $new
        Set-Content -Path $GuidFile -Value $selected -Encoding ASCII -Force
    } else {
        # Redist may already exist; still mark installed if installer succeeded
        Write-ErrorLog "Install completed but no new uninstall GUID detected. Marking installed based on return code $rc."
    }

    Set-Content -Path $FlagFile -Value 'Installed' -Encoding ASCII -Force

    if ($rc -eq 3010 -or $rc -eq 1641) { exit $EXIT_REBOOT }
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog $_.Exception.Message
    exit $EXIT_FAILURE
}