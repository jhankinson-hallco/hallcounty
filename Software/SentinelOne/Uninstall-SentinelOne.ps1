<#
Uninstall-SentinelOne.ps1
- Finds SentinelOne uninstall entry (64-bit + WOW6432Node)
- Prefers MSI ProductCode when available
- Error-only logging to C:\IntuneAppLogs\SentinelOne Logs.txt
#>

$ErrorActionPreference = "Stop"

$AppNamePattern = "SentinelOne*"

$LogDir  = "C:\IntuneAppLogs"
$LogFile = Join-Path $LogDir "SentinelOne Logs.txt"

$ERR_ENTRY_NOT_FOUND = 76001
$ERR_UNINSTALL_FAIL  = 76002
$ERR_LOG_FAIL        = 76999

function Initialize-LogFolder {
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
    } catch {
        exit $ERR_LOG_FAIL
    }
}

function Write-ErrorLog {
    param([string]$Message)
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$ts] ERROR: $Message"
    } catch { }
}

Initialize-LogFolder

$roots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

function Get-AppEntry {
    foreach ($r in $roots) {
        $keys = Get-ChildItem $r -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -and $p.DisplayName -like $AppNamePattern) {
                return [pscustomobject]@{
                    DisplayName          = $p.DisplayName
                    QuietUninstallString = $p.QuietUninstallString
                    UninstallString      = $p.UninstallString
                    PSChildName          = $k.PSChildName
                }
            }
        }
    }
    return $null
}

try {
    $entry = Get-AppEntry

    if (-not $entry) {
        # Already removed -> success
        exit 0
    }

    # Prefer ProductCode if it looks like a GUID
    if ($entry.PSChildName -match '^\{[0-9A-Fa-f\-]{36}\}$') {
        $args = "/x $($entry.PSChildName) /qn /norestart"
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        $code = $proc.ExitCode

        switch ($code) {
            0     { exit 0 }
            3010  { exit 3010 }
            1641  { exit 1641 }
            default {
                Write-ErrorLog "MSI uninstall via ProductCode failed. ExitCode=$code"
                exit $code
            }
        }
    }

    # Fall back to QuietUninstallString if present
    $cmd = $entry.QuietUninstallString
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        $cmd = $entry.UninstallString
    }

    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-ErrorLog "Uninstall entry found but no uninstall string present."
        exit $ERR_ENTRY_NOT_FOUND
    }

    # Basic parse into exe + args
    if ($cmd -match '^(?<exe>\".*?\"|\S+)\s*(?<args>.*)$') {
        $exe  = $Matches.exe.Trim('"')
        $args = $Matches.args

        $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        $code = $proc.ExitCode

        switch ($code) {
            0     { exit 0 }
            3010  { exit 3010 }
            1641  { exit 1641 }
            default {
                Write-ErrorLog "Uninstall failed using registry uninstall string. ExitCode=$code"
                exit $code
            }
        }
    }

    Write-ErrorLog "Unable to parse uninstall command string."
    exit $ERR_UNINSTALL_FAIL
}
catch {
    Write-ErrorLog "Unhandled exception during uninstall: $($_.Exception.Message)"
    exit $ERR_UNINSTALL_FAIL
}