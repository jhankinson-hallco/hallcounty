#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Year     = '2005'
$StateRoot = "C:\ProgramData\VCRedist\$Year"
$FlagFile = Join-Path $StateRoot 'Installed.flag'
$GuidFile = Join-Path $StateRoot 'ProductCode.txt'

$LogRoot = 'C:\IntuneAppLogs'
$LogFile = Join-Path $LogRoot "VCRedist$Year.txt"

$EXIT_SUCCESS = 0
$EXIT_RETRY   = 1618
$EXIT_FAILURE = 1

function Ensure-ErrorLog {
    try {
        if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }
        return $true
    } catch { return $false }
}
function Write-ErrorLog([string]$Message) {
    if (-not (Ensure-ErrorLog)) { return }
    try { Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $Message" } catch { }
}

try {
    if (-not (Test-Path $GuidFile)) {
        Remove-Item -Path $FlagFile -Force -ErrorAction SilentlyContinue
        exit $EXIT_SUCCESS
    }

    $guid = (Get-Content -Path $GuidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if ($guid -notmatch '^\{[0-9A-Fa-f-]{36}\}$') {
        Write-ErrorLog "Invalid ProductCode format in '$GuidFile': '$guid'"
        exit $EXIT_FAILURE
    }

    & msiexec.exe @('/x', $guid, '/qn', '/norestart')
    $rc = $LASTEXITCODE

    if ($rc -eq 1618) { exit $EXIT_RETRY }
    if ($rc -ne 0 -and $rc -ne 3010 -and $rc -ne 1641) {
        Write-ErrorLog "Uninstall returned exit code $rc for ProductCode $guid."
        exit $EXIT_FAILURE
    }

    Remove-Item -Path $GuidFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $FlagFile -Force -ErrorAction SilentlyContinue
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog $_.Exception.Message
    exit $EXIT_FAILURE
}