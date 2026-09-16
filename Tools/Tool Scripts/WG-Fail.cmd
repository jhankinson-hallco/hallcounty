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
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Content
    )

    $path = Join-Path $Root $Name
    $dir  = Split-Path -Path $path -Parent

    if ($dir) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Content | Out-File -FilePath $path -Encoding utf8
    Copy-After -PathC $path
}

function Copy-RecentFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestRoot,

        [Parameter(Mandatory = $true)]
        [datetime]$ThresholdUtc
    )

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        return
    }

    New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null

    Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $ThresholdUtc } |
        ForEach-Object {
            $relative  = $_.FullName.Substring($SourceRoot.Length).TrimStart('\')
            $target    = Join-Path $DestRoot $relative
            $targetDir = Split-Path -Path $target -Parent

            if ($targetDir) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            Copy-Item -LiteralPath $_.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        }

    Copy-After -PathC $DestRoot
}

New-Item -ItemType Directory -Path $Base -Force | Out-Null

$markerPath = Join-Path $Base 'WG_Start_UTC.txt'

if (Test-Path -LiteralPath $markerPath) {
    try {
        $startUtc = [datetime]::Parse((Get-Content -LiteralPath $markerPath -ErrorAction Stop | Select-Object -First 1).Trim()).ToUniversalTime()
    }
    catch {
        $startUtc = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
    }
}
else {
    $startUtc = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
}

$startText = $startUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$runStamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outRoot   = Join-Path $Base ('Fail_' + $runStamp)

New-Item -ItemType Directory -Path $outRoot -Force | Out-Null

Save-Text -Root $outRoot -Name 'WG_Start_UTC.txt' -Content $startText
Save-Text -Root $outRoot -Name 'LocalTime.txt'    -Content (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz')
Save-Text -Root $outRoot -Name 'UtcTime.txt'      -Content ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff UTC'))
Save-Text -Root $outRoot -Name 'TimeZone.txt'     -Content ((tzutil /g) 2>&1)
Save-Text -Root $outRoot -Name 'date.txt'         -Content ((cmd /c date /t) 2>&1)
Save-Text -Root $outRoot -Name 'time.txt'         -Content ((cmd /c time /t) 2>&1)
Save-Text -Root $outRoot -Name 'dsregcmd.txt'     -Content ((cmd /c dsregcmd /status) 2>&1)
Save-Text -Root $outRoot -Name 'tpmtool.txt'      -Content ((cmd /c tpmtool getdeviceinformation) 2>&1)

$logsToExport = @(
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot'
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService'
    'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'
    'Microsoft-Windows-User Device Registration/Admin'
)

$query = "*[System[TimeCreated[@SystemTime>='$startText']]]"

$eventResults = foreach ($logName in $logsToExport) {
    $safeName = ($logName -replace '[\\/:*?""<>| ]', '_')
    $evtxPath = Join-Path $outRoot ($safeName + '.evtx')

    $output = & wevtutil epl $logName $evtxPath /ow:true "/q:$query" 2>&1

    if (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $evtxPath)) {
        Copy-After -PathC $evtxPath
        "EXPORTED | $logName"
    }
    else {
        "FAILED   | $logName | $($output -join ' ')"
    }
}

Save-Text -Root $outRoot -Name 'EventExportStatus.txt' -Content $eventResults

Copy-RecentFiles -SourceRoot 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs' -DestRoot (Join-Path $outRoot 'IMELogs')            -ThresholdUtc $startUtc
Copy-RecentFiles -SourceRoot 'C:\Windows\Panther'                                     -DestRoot (Join-Path $outRoot 'Panther')            -ThresholdUtc $startUtc
Copy-RecentFiles -SourceRoot 'C:\Windows\Panther\UnattendGC'                          -DestRoot (Join-Path $outRoot 'Panther_UnattendGC') -ThresholdUtc $startUtc
Copy-RecentFiles -SourceRoot 'C:\Windows\Logs\MoSetup'                                -DestRoot (Join-Path $outRoot 'MoSetup')            -ThresholdUtc $startUtc
Copy-RecentFiles -SourceRoot 'C:\IntuneAppLogs'                                       -DestRoot (Join-Path $outRoot 'IntuneAppLogs')       -ThresholdUtc $startUtc
Copy-RecentFiles -SourceRoot 'C:\IntuneScriptLogs'                                    -DestRoot (Join-Path $outRoot 'IntuneScriptLogs')    -ThresholdUtc $startUtc

# Copy all marker files unconditionally — presence or absence of any .tag file is diagnostic
# regardless of when it was written (a marker from a prior run is still meaningful context).
if (Test-Path -LiteralPath 'C:\IntuneAppMarkers' -PathType Container) {
    $markerDest = Join-Path $outRoot 'IntuneAppMarkers'
    New-Item -ItemType Directory -Path $markerDest -Force | Out-Null
    Copy-Item -Path 'C:\IntuneAppMarkers\*' -Destination $markerDest -Recurse -Force -ErrorAction SilentlyContinue
}

# Copy the AppX diagnostic trace log unconditionally — it is append-only and survives reboots,
# so it may predate $startUtc even on a fresh run that wrote to it during this session.
$diagFile = 'C:\Windows\Temp\System-RemoveBloatwareAppX_Diag.txt'
if (Test-Path -LiteralPath $diagFile -PathType Leaf) {
    $diagDest = Join-Path $outRoot 'DiagFiles'
    New-Item -ItemType Directory -Path $diagDest -Force | Out-Null
    Copy-Item -LiteralPath $diagFile -Destination $diagDest -Force -ErrorAction SilentlyContinue
}

$reg1 = Join-Path $outRoot 'EnrollmentStatusTracking.reg'
$reg2 = Join-Path $outRoot 'AutopilotDiagnostics.reg'

$null = & reg export 'HKLM\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking' $reg1 /y 2>&1
if (Test-Path -LiteralPath $reg1) {
    Copy-After -PathC $reg1
}

$null = & reg export 'HKLM\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot' $reg2 /y 2>&1
if (Test-Path -LiteralPath $reg2) {
    Copy-After -PathC $reg2
}

$zipPath = $outRoot + '.zip'
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
}

Compress-Archive -Path $outRoot -DestinationPath $zipPath -Force
Copy-After -PathC $zipPath

Write-Host ('Capture created: ' + $zipPath)
exit 0