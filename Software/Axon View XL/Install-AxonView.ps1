<# 
Install-AxonViewXL.ps1
- Installs Axon View XL from axon-fleet-1.32.4.exe
- Creates C:\IntuneAppLogs\AxonViewLog.txt first
- Appends status/errors afterward
- Designed for Intune Win32, Hybrid Join, Autopilot-safe
#>

[CmdletBinding()]
param()

$AppName        = "Axon View XL"
$InstallerName  = "axon-fleet-1.32.4.exe"
$LogFolder      = "C:\IntuneAppLogs"
$LogFile        = Join-Path $LogFolder "AxonViewLog.txt"

# Choose silent args here if vendor docs specify differently.
# Common alternatives:
#   NSIS: /S
#   Inno: /VERYSILENT /NORESTART
#   InstallShield wrapper: /s /v"/qn /norestart"
$SilentArgs = "/quiet /norestart"

function Ensure-Log {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$ts [$Level] $Message"
}

function Fail-Exit {
    param(
        [int]$Code,
        [string]$Message
    )
    Write-Log -Level "ERROR" -Message "$Message (ExitCode: $Code)"
    exit $Code
}

try {
    Ensure-Log
    Write-Log "===== Starting install for $AppName ====="

    $InstallerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerName
    if (-not (Test-Path $InstallerPath)) {
        Fail-Exit -Code 2 -Message "Installer not found at $InstallerPath"
    }

    Write-Log "Installer located: $InstallerPath"
    Write-Log "Using silent arguments: $SilentArgs"

    # Start installer
    $process = Start-Process -FilePath $InstallerPath `
                             -ArgumentList $SilentArgs `
                             -Wait -PassThru -WindowStyle Hidden `
                             -ErrorAction Stop

    $exitCode = $process.ExitCode
    Write-Log "Installer process completed with exit code: $exitCode"

    # Intune-friendly handling of common success/reboot codes
    switch ($exitCode) {
        0     { Write-Log "Installation completed successfully." }
        3010  { Write-Log "Installation completed successfully; reboot required." }
        1641  { Write-Log "Installation completed successfully; reboot initiated by installer." }
        default {
            Fail-Exit -Code $exitCode -Message "Installation failed"
        }
    }

    Write-Log "===== Install finished for $AppName ====="
    exit $exitCode
}
catch {
    Ensure-Log
    Fail-Exit -Code 1 -Message ("Unhandled exception: " + $_.Exception.Message)
}