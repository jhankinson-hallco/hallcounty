#requires -version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------------
# Configuration
# ----------------------------
$logRoot = 'C:\IntuneAppLogs'
$logFile = Join-Path $logRoot 'MicrosoftPIA_Install.txt'
$msiName = 'VS_2005_PIA.msi'
$msiPath = Join-Path -Path $PSScriptRoot -ChildPath $msiName

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    try {
        Add-Content -Path $logFile -Value $entry
    } catch {
        # If logging fails, there is nothing more we can do, but we still want an exit code.
    }
}

try {
    # Ensure log directory exists
    if (-not (Test-Path -Path $logRoot)) {
        New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    }

    # Ensure log file is created first
    if (-not (Test-Path -Path $logFile)) {
        New-Item -Path $logFile -ItemType File -Force | Out-Null
    }

    Write-Log "Starting Microsoft Primary Interop Assemblies 2005 installation."

    # Validate MSI presence
    if (-not (Test-Path -Path $msiPath)) {
        Write-Log "MSI not found at path '$msiPath'." 'ERROR'
        exit 1
    }

    # Prepare msiexec arguments
    $arguments = "/i `"$msiPath`" ALLUSERS=1 /qn /norestart"
    Write-Log "Executing: msiexec.exe $arguments"

    # Run installation
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
    $exitCode = $process.ExitCode

    Write-Log "msiexec.exe completed with exit code $exitCode."

    switch ($exitCode) {
        0 {
            Write-Log "Installation completed successfully."
            exit 0
        }
        3010 {
            Write-Log "Installation completed successfully. A reboot is recommended but will not be forced." 'WARN'
            # Treat as success for Intune so deployment is not marked as failed
            exit 0
        }
        default {
            Write-Log "Installation failed with exit code $exitCode." 'ERROR'
            exit $exitCode
        }
    }
}
catch {
    Write-Log "Unhandled exception: $($_.Exception.Message)" 'ERROR'
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-Log "Error location: $($_.InvocationInfo.PositionMessage)" 'ERROR'
    }
    exit 1
}