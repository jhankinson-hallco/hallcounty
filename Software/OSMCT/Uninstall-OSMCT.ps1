#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogRoot = 'C:\IntuneAppLogs'
$LogFile = Join-Path $LogRoot 'OSMCTLogs.txt'
$PublicDesktop = Join-Path $env:PUBLIC 'Desktop'

$OSMCTShortcut  = Join-Path $PublicDesktop 'OSMCT.lnk'
$MupdateShortcut = Join-Path $PublicDesktop 'mupdate.lnk'

$ProcessNamesToStop = @(
    'SunGuard.PS.OSSI.UI.OSMCT',
    'mupdate'
)

# Broad but reasonable for this bundle
$UninstallNamePatterns = @(
    'OSSI Speech',
    'Speech Synthesis',
    'OSSI Speech Synthesis',
    'OSMCT',
    'SunGuard',
    'OSSI'
)

function Initialize-Log {
    try {
        if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }
        Add-Content -Path $LogFile -Value ("`r`n==== OSMCT Uninstall Run: {0} ====" -f (Get-Date))
    } catch {}
}

function Write-Log {
    param([string]$Message)
    try {
        Add-Content -Path $LogFile -Value ("[INFO ] {0} - {1}" -f (Get-Date), $Message)
    } catch {}
}

function Write-Err {
    param([string]$Step, [System.Exception]$Exception)
    try {
        Add-Content -Path $LogFile -Value ("[ERROR] {0} - Step: {1} | {2}" -f (Get-Date), $Step, $Exception.Message)
    } catch {}
}

function Stop-Processes {
    foreach ($n in $ProcessNamesToStop) {
        try {
            $p = Get-Process -Name $n -ErrorAction SilentlyContinue
            if ($p) {
                Write-Log "Stopping process: $n"
                foreach ($proc in $p) {
                    try { [void]$proc.CloseMainWindow() } catch {}
                }
                Start-Sleep -Seconds 2
                $p = Get-Process -Name $n -ErrorAction SilentlyContinue
                if ($p) {
                    foreach ($proc in $p) {
                        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
                    }
                }
            }
        } catch {
            Write-Err "Stop process $n" $_.Exception
        }
    }
}

function Matches-AnyPattern {
    param([string]$Name, [string[]]$Patterns)
    foreach ($pat in $Patterns) {
        if ($Name -like "*$pat*") { return $true }
    }
    return $false
}

function Get-UninstallEntries {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    $result = @()
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }

        foreach ($k in (Get-ChildItem $p -ErrorAction SilentlyContinue)) {
            try {
                $prop = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
                if ($prop.DisplayName) { $result += $prop }
            } catch {}
        }
    }
    return $result
}

function Invoke-UninstallEntry {
    param($Entry)

    $name = $Entry.DisplayName
    $uninstall = $Entry.UninstallString

    if (-not $uninstall) {
        Write-Log "No UninstallString for $name. Skipping."
        return
    }

    Write-Log "Attempting uninstall for: $name"

    try {
        if ($uninstall -match 'MsiExec\.exe') {
            # Convert /I to /X if present
            $cmd = $uninstall
            if ($cmd -match '(?i)/i') {
                $cmd = $cmd -replace '(?i)/i', '/x'
            }

            # Ensure quiet flags
            if ($cmd -notmatch '(?i)/q') {
                $cmd = "$cmd /qn /norestart"
            }

            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -ErrorAction Stop
        } else {
            # Non-MSI uninstallers may still be interactive
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstall" -Wait -ErrorAction Stop
        }
    } catch {
        Write-Err "Uninstall $name" $_.Exception
    }
}

# ----------------------------
# Main
# ----------------------------
Initialize-Log
Write-Log "Starting OSMCT uninstall workflow."

try {
    Stop-Processes

    $entries = Get-UninstallEntries | Where-Object {
        Matches-AnyPattern -Name $_.DisplayName -Patterns $UninstallNamePatterns
    }

    if ($entries) {
        # Remove speech first if possible via ordering
        $ordered = $entries | Sort-Object DisplayName
        foreach ($e in $ordered) {
            Invoke-UninstallEntry -Entry $e
        }
    } else {
        Write-Log "No matching uninstall entries found."
    }

    foreach ($s in @($OSMCTShortcut, $MupdateShortcut)) {
        try {
            if (Test-Path $s) {
                Remove-Item $s -Force
                Write-Log "Removed shortcut: $s"
            }
        } catch {
            Write-Err "Remove shortcut $s" $_.Exception
        }
    }

} catch {
    Write-Err "Uninstall workflow fatal error" $_.Exception
    exit 1
}

Write-Log "OSMCT uninstall workflow completed."
exit 0