<# 
Uninstall-AxonViewXL.ps1
- Uninstalls Axon View XL without relying on product codes
- Uses QuietUninstallString when available
- Falls back to UninstallString with safe silent hints
- Creates/uses C:\IntuneAppLogs\AxonViewLog.txt
#>

[CmdletBinding()]
param()

$AppNamePattern = "Axon View XL"
$LogFolder      = "C:\IntuneAppLogs"
$LogFile        = Join-Path $LogFolder "AxonViewLog.txt"

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

function Get-UninstallEntries {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -like "*$AppNamePattern*" }
    }
}

function Build-UninstallCommand {
    param($entry)

    if ($entry.QuietUninstallString) {
        return $entry.QuietUninstallString
    }

    $u = $entry.UninstallString
    if (-not $u) { return $null }

    # If MSI-based uninstall string, ensure silent flags
    if ($u -match "msiexec\.exe") {
        # Normalize to /x with quiet
        # Many uninstall strings already contain /I or /X with a GUID.
        if ($u -notmatch "/qn") {
            $u = "$u /qn /norestart"
        }
        return $u
    }

    # EXE-based fallback: append common quiet flags
    # This is conservative and may need adjustment if Axon docs differ.
    if ($u -notmatch "/quiet|/silent|/verysilent|/S") {
        $u = "$u /quiet /norestart"
    }

    return $u
}

try {
    Ensure-Log
    Write-Log "===== Starting uninstall for $AppNamePattern ====="

    $entries = @(Get-UninstallEntries | Select-Object -First 5)

    if (-not $entries -or $entries.Count -eq 0) {
        Write-Log "No matching uninstall entry found for '$AppNamePattern'. Treating as already uninstalled."
        exit 0
    }

    # Prefer the newest-looking entry if multiple
    $entry = $entries | Sort-Object -Property DisplayVersion -Descending | Select-Object -First 1

    Write-Log "Matched DisplayName: $($entry.DisplayName)"
    Write-Log "Matched DisplayVersion: $($entry.DisplayVersion)"

    $cmd = Build-UninstallCommand -entry $entry
    if (-not $cmd) {
        Fail-Exit -Code 3 -Message "Unable to build uninstall command for matched entry."
    }

    Write-Log "Uninstall command: $cmd"

    # Run via cmd.exe to respect complex uninstall strings
    $process = Start-Process -FilePath "cmd.exe" `
                             -ArgumentList "/c", $cmd `
                             -Wait -PassThru -WindowStyle Hidden `
                             -ErrorAction Stop

    $exitCode = $process.ExitCode
    Write-Log "Uninstall process completed with exit code: $exitCode"

    switch ($exitCode) {
        0     { Write-Log "Uninstall completed successfully." }
        3010  { Write-Log "Uninstall completed successfully; reboot required." }
        1641  { Write-Log "Uninstall completed successfully; reboot initiated by uninstaller." }
        default {
            Fail-Exit -Code $exitCode -Message "Uninstall failed"
        }
    }

    Write-Log "===== Uninstall finished for $AppNamePattern ====="
    exit $exitCode
}
catch {
    Ensure-Log
    Fail-Exit -Code 1 -Message ("Unhandled exception: " + $_.Exception.Message)
}