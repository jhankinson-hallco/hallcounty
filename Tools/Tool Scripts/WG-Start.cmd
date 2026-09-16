@echo off
setlocal

set "_PS1=%TEMP%\%~n0_%RANDOM%%RANDOM%.ps1"

for /f "tokens=1 delims=:" %%A in ('findstr /n /b /c:":__POWERSHELL__" "%~f0"') do set "_MARKERLINE=%%A"

if not defined _MARKERLINE (
    echo Embedded PowerShell marker not found.
    exit /b 1
)

set "_SRC=%~f0"
set "_DST=%_PS1%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$src=$env:_SRC; $dst=$env:_DST; $skip=[int]$env:_MARKERLINE; (Get-Content -LiteralPath $src | Select-Object -Skip $skip) | Set-Content -LiteralPath $dst -Encoding UTF8"

if errorlevel 1 exit /b %errorlevel%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%_PS1%"
set "_RC=%errorlevel%"

del "%_PS1%" >nul 2>&1
exit /b %_RC%

:__POWERSHELL__
$ErrorActionPreference = 'Stop'

$Base   = 'C:\WG-Fresh'
$Mirror = 'D:\Logs\WG-Fresh'

function Copy-After {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathC
    )

    try {
        $null = Get-PSDrive -Name D -ErrorAction Stop
    }
    catch {
        return
    }

    if (-not (Test-Path -LiteralPath $PathC)) {
        return
    }

    if (-not $PathC.StartsWith($Base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $relative = $PathC.Substring($Base.Length).TrimStart('\')
    $dest     = Join-Path $Mirror $relative

    if (Test-Path -LiteralPath $PathC -PathType Container) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -Path (Join-Path $PathC '*') -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        $destDir = Split-Path -Path $dest -Parent
        if ($destDir) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $PathC -Destination $dest -Force -ErrorAction SilentlyContinue
    }
}

function Save-Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Content
    )

    $path = Join-Path $Base $Name
    $dir  = Split-Path -Path $path -Parent

    if ($dir) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Content | Out-File -FilePath $path -Encoding utf8
    Copy-After -PathC $path
}

New-Item -ItemType Directory -Path $Base -Force | Out-Null

$stampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

Save-Text -Name 'WG_Start_UTC.txt' -Content $stampUtc
Save-Text -Name 'LocalTime.txt'    -Content (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz')
Save-Text -Name 'UtcTime.txt'      -Content ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff UTC'))
Save-Text -Name 'TimeZone.txt'     -Content ((tzutil /g) 2>&1)
Save-Text -Name 'ComputerName.txt' -Content $env:COMPUTERNAME

$imePath    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$archiveDir = Join-Path $Base ('PreRun_IMELogs_' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

if (Test-Path -LiteralPath $imePath) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

    Get-ChildItem -LiteralPath $imePath -File -Force -ErrorAction SilentlyContinue |
        Move-Item -Destination $archiveDir -Force -ErrorAction SilentlyContinue

    Copy-After -PathC $archiveDir
}

$logsToClear = @(
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot'
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService'
    'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'
    'Microsoft-Windows-User Device Registration/Admin'
)

$clearResults = foreach ($logName in $logsToClear) {
    $output = & wevtutil cl $logName 2>&1
    if ($LASTEXITCODE -eq 0) {
        "CLEARED | $logName"
    }
    else {
        "FAILED  | $logName | $($output -join ' ')"
    }
}

Save-Text -Name 'ClearedLogs.txt' -Content $clearResults
Save-Text -Name 'Status.txt'      -Content 'READY'

Write-Host 'WG prep complete.'
exit 0