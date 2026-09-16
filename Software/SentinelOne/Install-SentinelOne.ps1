<#
Install-SentinelOne.ps1
Hybrid + Autopilot-friendly Win32 installer for SentinelOne

- Installs SentinelOne MSI with MST
- Safe Autopilot guard (won't block non-Autopilot hybrid devices)
- Error-only logging:
    C:\IntuneAppLogs\SentinelOneLogs.txt
  Folder/file created ONLY when an error is logged
  File is explicitly created first, then entries appended
- Does NOT force restart
- Returns 3010 when reboot is required so Intune can safely coordinate

#>

$ErrorActionPreference = "Stop"

# ---------------------------
# Config
# ---------------------------
$MsiName = "SentinelOne_x64_22_2_3_402.msi"
$MstName = "SentinelOne_CPS.mst"

$LogDir  = "C:\IntuneAppLogs"
$LogFile = Join-Path $LogDir "SentinelOneLogs.txt"

# Custom error codes
$ERR_AP_NOT_COMPLETE = 75001
$ERR_MSI_NOT_FOUND   = 75002
$ERR_MST_NOT_FOUND   = 75003
$ERR_MSI_LAUNCH_FAIL = 75004
$ERR_VERIFY_FAIL     = 75005

# ---------------------------
# Error-only logging (explicit create -> then append)
# ---------------------------
function Ensure-LogFolder {
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        return $true
    } catch {
        return $false
    }
}

function Create-LogFileIfNeeded {
    try {
        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
        return $true
    } catch {
        return $false
    }
}

function Write-ErrorLog {
    param([string]$Message)

    if (-not (Ensure-LogFolder)) { return }
    if (-not (Create-LogFileIfNeeded)) { return }

    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$ts] ERROR: $Message"
    } catch {
        # Do not mask primary error
    }
}

# ---------------------------
# Autopilot guard
# - Only enforce ESP wait when Autopilot signals are present
# - Avoid blocking normal hybrid devices
# ---------------------------
function Test-AutopilotProvisioningComplete {
    $autoPilotSignals = @(
        "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot",
        "HKLM:\SOFTWARE\Microsoft\Windows\Autopilot",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MDM\AutoPilot"
    )

    $autopilotLikely = $false
    foreach ($p in $autoPilotSignals) {
        if (Test-Path $p) { $autopilotLikely = $true; break }
    }

    # No Autopilot signals -> allow
    if (-not $autopilotLikely) { return $true }

    # Autopilot signals present -> require provisioning done flag
    $enrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    if (-not (Test-Path $enrollmentsPath)) { return $false }

    $keys = Get-ChildItem $enrollmentsPath -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $firstSyncPath = Join-Path $k.PSPath "FirstSync"
        if (Test-Path $firstSyncPath) {
            $val = (Get-ItemProperty -Path $firstSyncPath -Name "IsServerProvisioningDone" -ErrorAction SilentlyContinue)."IsServerProvisioningDone"
            if ($val -eq 1) { return $true }
        }
    }

    return $false
}

# ---------------------------
# Verification helper
# ---------------------------
function Test-SentinelOneInstalled {
    # Service name is commonly SentinelAgent
    $svc = Get-Service -Name "SentinelAgent" -ErrorAction SilentlyContinue
    if ($svc) { return $true }

    # Fallback to uninstall registry
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($r in $roots) {
        $keys = Get-ChildItem $r -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -and $p.DisplayName -like "SentinelOne*") {
                return $true
            }
        }
    }

    return $false
}

# ---------------------------
# Main
# ---------------------------
try {
    if (-not (Test-AutopilotProvisioningComplete)) {
        Write-ErrorLog "Autopilot/ESP not complete. Deferring SentinelOne install."
        exit $ERR_AP_NOT_COMPLETE
    }

    $msiPath = Join-Path $PSScriptRoot $MsiName
    $mstPath = Join-Path $PSScriptRoot $MstName

    if (-not (Test-Path $msiPath)) {
        Write-ErrorLog "MSI not found: $msiPath"
        exit $ERR_MSI_NOT_FOUND
    }

    if (-not (Test-Path $mstPath)) {
        Write-ErrorLog "MST not found: $mstPath"
        exit $ERR_MST_NOT_FOUND
    }

    # Match your known-good PDQ intent
    $args = "/i `"$msiPath`" ALLUSERS=1 /qn /norestart TRANSFORMS=`"$mstPath`""

    $proc = $null
    try {
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
    } catch {
        Write-ErrorLog "Failed to launch msiexec. $($_.Exception.Message)"
        exit $ERR_MSI_LAUNCH_FAIL
    }

    $msiExit = $proc.ExitCode

    # Accept standard MSI success + reboot-needed codes
    switch ($msiExit) {
        0     { }
        3010  { }
        1641  { }
        default {
            Write-ErrorLog "MSI install failed. msiexec exit code: $msiExit"
            exit $msiExit
        }
    }

    # Verify install presence
    if (-not (Test-SentinelOneInstalled)) {
        Write-ErrorLog "Post-install verification failed (no SentinelAgent service and no SentinelOne uninstall entry)."
        exit $ERR_VERIFY_FAIL
    }

    # We want Intune to manage reboot timing safely.
    # If MSI says reboot needed, normalize to 3010.
    if ($msiExit -eq 1641 -or $msiExit -eq 3010) {
        exit 3010
    }

    exit 0
}
catch {
    Write-ErrorLog "Unhandled exception: $($_.Exception.Message)"
    exit $ERR_MSI_LAUNCH_FAIL
}
