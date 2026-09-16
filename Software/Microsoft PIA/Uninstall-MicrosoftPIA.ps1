#requires -version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------------
# Configuration
# ----------------------------
$logRoot = 'C:\IntuneAppLogs'
$logFile = Join-Path $logRoot 'MicrosoftPIA_Uninstall.txt'

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
        # Ignore logging failures
    }
}

function Get-PIAUninstallEntry {
    [CmdletBinding()]
    param()

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -and (
                    $_.DisplayName -like '*Primary Interop*2005*' -or
                    $_.DisplayName -like '*Primary Interoperability Assemblies 2005*'
                )
            }
    }
}

try {
    # Ensure log directory and file
    if (-not (Test-Path -Path $logRoot)) {
        New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -Path $logFile)) {
        New-Item -Path $logFile -ItemType File -Force | Out-Null
    }

    Write-Log "Starting uninstall of Microsoft Primary Interop Assemblies 2005."

    $entry = Get-PIAUninstallEntry | Select-Object -First 1

    if (-not $entry) {
        Write-Log "No matching Microsoft Primary Interop Assemblies 2005 entry found in Uninstall registry. Assuming already removed." 'WARN'
        exit 0
    }

    $uninstallString = $entry.UninstallString

    if (-not $uninstallString) {
        Write-Log "UninstallString not found for detected entry. Cannot proceed with uninstall." 'ERROR'
        exit 1
    }

    Write-Log "Found uninstall entry: DisplayName = '$($entry.DisplayName)'."
    Write-Log "Raw UninstallString: $uninstallString"

    # Try to extract MSI product code {GUID} from the uninstall string
    $productCode = $null
    if ($uninstallString -match '\{[0-9A-Fa-f\-]{36}\}') {
        $productCode = $matches[0]
    }

    if (-not $productCode) {
        Write-Log "Could not extract MSI product code from UninstallString. Attempting to execute raw command silently." 'WARN'

        # Try to ensure quiet flags are present
        if ($uninstallString -notmatch '/qn') {
            $uninstallString += ' /qn'
        }
        if ($uninstallString -notmatch '/norestart') {
            $uninstallString += ' /norestart'
        }

        Write-Log "Executing uninstall command: $uninstallString"

        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString" -Wait -PassThru
        $exitCode = $process.ExitCode
    }
    else {
        $arguments = "/x $productCode /qn /norestart"
        Write-Log "Executing: msiexec.exe $arguments"

        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
        $exitCode = $process.ExitCode
    }

    Write-Log "Uninstall process completed with exit code $exitCode."

    switch ($exitCode) {
        0 {
            Write-Log "Uninstallation completed successfully."
            exit 0
        }
        3010 {
            Write-Log "Uninstallation completed successfully. A reboot is recommended but will not be forced." 'WARN'
            exit 0
        }
        default {
            Write-Log "Uninstallation failed with exit code $exitCode." 'ERROR'
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