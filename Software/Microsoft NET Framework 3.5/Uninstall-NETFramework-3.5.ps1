<# 
.SYNOPSIS
  Disables .NET Framework 3.5 (NetFx3) using DISM.
  Uses the same log location and file name.

.NOTES
  Designed for Intune Win32 uninstall.
#>

$ErrorActionPreference = 'Stop'

$logDir  = 'C:\IntuneAppLogs'
$logFile = Join-Path $logDir 'NETFx3.5Logs.txt'

function Initialize-Log {
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
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
    if ($state -ne 'Enabled') {
        Write-Log "NetFx3 already disabled or not present. No action needed."
        exit 0
    }

    Write-Log "Attempting to disable NetFx3 via DISM."

    $dismArgs = "/online /disable-feature /featurename:NetFx3 /norestart"
    $proc = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow

    $code = $proc.ExitCode

    if ($code -eq 0) {
        Write-Log "DISM disable completed successfully. ExitCode=0"
        exit 0
    }
    elseif ($code -eq 3010) {
        Write-Log "DISM disable completed successfully but requires reboot. ExitCode=3010"
        exit 3010
    }
    else {
        $hex = ('0x{0:X8}' -f $code)
        Write-Log "ERROR disabling NetFx3. ExitCode=$code ($hex)"
        throw "DISM disable-feature failed with ExitCode=$code ($hex)"
    }
}
catch {
    Write-Log "EXCEPTION: $($_.Exception.Message)"
    Write-Log "STACK: $($_.ScriptStackTrace)"
    exit 1
}