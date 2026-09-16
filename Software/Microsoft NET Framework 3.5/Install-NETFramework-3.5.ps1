<# 
.SYNOPSIS
  Enables .NET Framework 3.5 (NetFx3) using DISM.
  Creates C:\IntuneAppLogs\NETFx3.5Logs.txt
  Ensures the .txt log file exists before appending errors.

.NOTES
  Designed for Intune Win32 deployment.
  Recommended install context: System.
#>

$ErrorActionPreference = 'Stop'

$logDir  = 'C:\IntuneAppLogs'
$logFile = Join-Path $logDir 'NETFx3.5Logs.txt'

function Initialize-Log {
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    # Create the file first (as requested), then append messages later.
    if (-not (Test-Path $logFile)) {
        New-Item -Path $logFile -ItemType File -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

function Get-NetFx3State {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -ErrorAction Stop
        return $feature.State
    }
    catch {
        return $null
    }
}

Initialize-Log

try {
    $state = Get-NetFx3State
    if ($state -eq 'Enabled') {
        Write-Log "NetFx3 already enabled. No action needed."
        exit 0
    }

    Write-Log "Attempting to enable NetFx3 via DISM."

    $dismArgs = "/online /enable-feature /featurename:NetFx3 /All /norestart"
    $proc = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow

    $code = $proc.ExitCode

    if ($code -eq 0) {
        Write-Log "DISM completed successfully. ExitCode=0"
        exit 0
    }
    elseif ($code -eq 3010) {
        # Soft reboot required
        Write-Log "DISM completed successfully but requires reboot. ExitCode=3010"
        exit 3010
    }
    else {
        $hex = ('0x{0:X8}' -f $code)
        Write-Log "ERROR enabling NetFx3. ExitCode=$code ($hex)"
        throw "DISM enable-feature failed with ExitCode=$code ($hex)"
    }
}
catch {
    # Ensure error details are appended after log file creation.
    Write-Log "EXCEPTION: $($_.Exception.Message)"
    Write-Log "STACK: $($_.ScriptStackTrace)"
    # Use a consistent non-zero code if DISM didn't provide one
    exit 1
}