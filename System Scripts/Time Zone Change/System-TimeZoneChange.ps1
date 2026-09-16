<#
System-TimeZoneChange.ps1
Intune Win32-friendly time zone script:
- Sets time zone to Eastern Time (Windows ID: "Eastern Standard Time")
- Avoids running during Autopilot/ESP using a conservative registry-based guard
- Logs errors only to C:\IntuneAppLogs\ComputerTimeZoneLogs.txt
- Creates log folder/file ONLY if an error occurs
#>

$ErrorActionPreference = "Stop"

# -----------------------------
# Config
# -----------------------------
$TargetTimeZoneId = "Eastern Standard Time"

$LogDir  = "C:\IntuneAppLogs"
$LogFile = Join-Path $LogDir "ComputerTimeZoneLogs.txt"

# Custom exit codes
$ERR_AP_NOT_COMPLETE   = 74001
$ERR_TZ_READ_FAILED    = 74002
$ERR_TZ_SET_FAILED     = 74003
$ERR_TZ_VERIFY_FAIL    = 74004
$ERR_LOG_FAILED        = 74005

# -----------------------------
# Error-only logging (lazy create)
# - Create folder (if needed)
# - Create log file (if needed)
# - Then append entries
# -----------------------------
function Ensure-LogFile {
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path $LogFile)) {
            # Explicitly create an empty log file first
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    } catch {
        return $false
    }
}

function Write-ErrorLog {
    param([string]$Message)

    # Only create folder/file when an error is being logged
    if (-not (Ensure-LogFile)) {
        # If logging infrastructure can't be created, don't mask primary failure.
        return
    }

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[$timestamp] ERROR: $Message"
        Add-Content -Path $LogFile -Value $line
    } catch {
        # Don’t mask the primary failure if writing fails
    }
}

# -----------------------------
# Autopilot/ESP completion guard (heuristic)
# -----------------------------
function Test-AutopilotProvisioningComplete {
    # Conservative heuristic: checks enrollment FirstSync state
    # Returns true if any enrollment indicates server provisioning done.

    $enrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    if (-not (Test-Path $enrollmentsPath)) {
        return $false
    }

    $keys = Get-ChildItem $enrollmentsPath -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $firstSyncPath = Join-Path $k.PSPath "FirstSync"
        if (Test-Path $firstSyncPath) {
            $val = (Get-ItemProperty -Path $firstSyncPath -Name "IsServerProvisioningDone" -ErrorAction SilentlyContinue)."IsServerProvisioningDone"
            if ($val -eq 1) {
                return $true
            }
        }
    }

    return $false
}

# -----------------------------
# Time zone helpers
# -----------------------------
function Get-CurrentTimeZoneId {
    try {
        return (Get-TimeZone).Id
    } catch {
        throw "Unable to read current time zone. $($_.Exception.Message)"
    }
}

function Set-TargetTimeZone {
    param([string]$TzId)

    try {
        # Prefer PowerShell cmdlet
        Set-TimeZone -Id $TzId -ErrorAction Stop
    } catch {
        # Fallback to tzutil if needed
        try {
            $args = "/s `"$TzId`""
            $proc = Start-Process -FilePath "tzutil.exe" -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
            if ($proc.ExitCode -ne 0) {
                throw "tzutil exit code: $($proc.ExitCode)"
            }
        } catch {
            throw "Failed to set time zone using Set-TimeZone and tzutil. $($_.Exception.Message)"
        }
    }
}

# -----------------------------
# Main
# -----------------------------
try {
    # Guard: avoid running during Autopilot/ESP
    if (-not (Test-AutopilotProvisioningComplete)) {
        exit $ERR_AP_NOT_COMPLETE
    }

    $current = Get-CurrentTimeZoneId

    if ($current -eq $TargetTimeZoneId) {
        exit 0
    }

    try {
        Set-TargetTimeZone -TzId $TargetTimeZoneId
    } catch {
        Write-ErrorLog "Time zone set failed. Current='$current' Target='$TargetTimeZoneId'. Exception: $($_.Exception.Message)"
        exit $ERR_TZ_SET_FAILED
    }

    # Verify
    $after = $null
    try {
        $after = Get-CurrentTimeZoneId
    } catch {
        Write-ErrorLog "Time zone read failed after set attempt. Exception: $($_.Exception.Message)"
        exit $ERR_TZ_READ_FAILED
    }

    if ($after -ne $TargetTimeZoneId) {
        Write-ErrorLog "Time zone verification failed. Expected='$TargetTimeZoneId' Actual='$after'."
        exit $ERR_TZ_VERIFY_FAIL
    }

    exit 0
}
catch {
    $msg = $_.Exception.Message

    if ($msg -like "Unable to read current time zone*") {
        Write-ErrorLog $msg
        exit $ERR_TZ_READ_FAILED
    }

    Write-ErrorLog "Unhandled exception: $msg"
    exit $ERR_TZ_SET_FAILED
}