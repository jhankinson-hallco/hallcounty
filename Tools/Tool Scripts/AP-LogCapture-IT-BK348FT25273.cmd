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
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

<#
.SYNOPSIS
    AP-LogCapture.cmd
    Full Autopilot / White Glove deployment log capture.

.DESCRIPTION
    Collects all evidence of a completed Autopilot / White Glove deployment.
    Run as Administrator after the deployment finishes and the user logs in
    for the first time. Captures regardless of success or failure.

    No time filter is applied — every log file is copied in full so that
    the complete deployment history is available for review.

    Output: D:\Logs\AP_<yyyyMMdd-HHmmss>\
      Info\          -- Device identity, domain state, OS, installed apps, GP result
      IME\           -- Full Intune Management Extension log folder
      HallCounty\    -- Current IME AppMarkers, Images, ScriptFiles, plus
                        legacy IntuneAppLogs, IntuneScriptLogs, IntuneAppMarkers,
                        IntuneDeploymentFiles, IntuneScripts
      Setup\         -- Windows Panther, MoSetup, DiagOutputDir, sysprep logs
      Events\        -- Exported event log channels (.evtx) + plain-text summaries
      Registry\      -- Key registry subtrees as .reg exports
      MDM\           -- MdmDiagnosticsTool output
      _SUMMARY.txt   -- Capture manifest and quick-reference guide
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$OutputRoot = 'D:\Logs'

# =============================================================================
# END CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function New-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

function Copy-Tree {
    # Copies all content from SourcePath into DestPath, silently skipping
    # files that cannot be read (locked, access denied, etc.).
    param(
        [string]$SourcePath,
        [string]$DestPath
    )
    if (-not (Test-Path -LiteralPath $SourcePath)) { return }
    New-Dir -Path $DestPath
    Copy-Item -Path (Join-Path $SourcePath '*') -Destination $DestPath `
              -Recurse -Force -ErrorAction SilentlyContinue
}

function Save-Text {
    # Writes string content or command output to a file.
    param(
        [string]$Path,
        $Content
    )
    $dir = Split-Path -LiteralPath $Path -Parent
    if ($dir) { New-Dir -Path $dir }
    $Content | Out-File -LiteralPath $Path -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

function Export-EventLog {
    # Exports an event log channel to .evtx. Returns status string.
    param(
        [string]$LogName,
        [string]$DestFolder
    )
    $safeName = ($LogName -replace '[\\/:*?"<>| ]', '_')
    $evtxPath = Join-Path $DestFolder ($safeName + '.evtx')
    $output = & wevtutil epl $LogName $evtxPath /ow:true 2>&1
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $evtxPath)) {
        return "OK       $LogName"
    }
    return "SKIPPED  $LogName  ($($output -join ' '))"
}

function Export-EventLogText {
    # Exports all events from a channel as readable plain text.
    param(
        [string]$LogName,
        [string]$DestPath
    )
    $dir = Split-Path -LiteralPath $DestPath -Parent
    if ($dir) { New-Dir -Path $dir }
    $output = & wevtutil qe $LogName /f:text /rd:false 2>&1
    if ($LASTEXITCODE -eq 0) {
        $output | Out-File -LiteralPath $DestPath -Encoding UTF8 -Force
    }
}

function Export-Registry {
    # Exports a registry key as a .reg file. Returns status string.
    param(
        [string]$KeyPath,
        [string]$DestPath
    )
    $dir = Split-Path -LiteralPath $DestPath -Parent
    if ($dir) { New-Dir -Path $dir }
    $output = & reg export $KeyPath $DestPath /y 2>&1
    if ($LASTEXITCODE -eq 0) {
        return "OK       $KeyPath"
    }
    return "SKIPPED  $KeyPath  ($($output -join ' '))"
}

# =============================================================================
# PREFLIGHT
# =============================================================================

# Verify D:\ is accessible.
if (-not (Test-Path -LiteralPath 'D:\')) {
    Write-Host 'ERROR: Drive D:\ is not accessible. Connect the target drive and retry.' -ForegroundColor Red
    exit 1
}

New-Dir -Path $OutputRoot

$RunStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutDir   = Join-Path $OutputRoot ('AP_' + $RunStamp)
New-Dir -Path $OutDir

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "  AP-LogCapture  --  $RunStamp" -ForegroundColor Cyan
Write-Host "  Output: $OutDir" -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$StatusLog = [System.Collections.Generic.List[string]]::new()
function Add-Status { param([string]$Line) $StatusLog.Add($Line) | Out-Null; Write-Host "  $Line" }

# =============================================================================
# SECTION 1: DEVICE INFORMATION
# =============================================================================

Write-Host '[1/8] Device information...' -ForegroundColor Yellow
$InfoDir = Join-Path $OutDir 'Info'
New-Dir -Path $InfoDir

# Timestamps
Save-Text -Path (Join-Path $InfoDir 'LocalTime.txt')  -Content (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz')
Save-Text -Path (Join-Path $InfoDir 'UtcTime.txt')     -Content ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff UTC'))
Save-Text -Path (Join-Path $InfoDir 'TimeZone.txt')    -Content ((& tzutil /g) 2>&1)

# Device identity
Save-Text -Path (Join-Path $InfoDir 'hostname.txt')    -Content $env:COMPUTERNAME
Save-Text -Path (Join-Path $InfoDir 'dsregcmd.txt')    -Content ((& dsregcmd /status) 2>&1)
Save-Text -Path (Join-Path $InfoDir 'tpmtool.txt')     -Content ((& tpmtool getdeviceinformation) 2>&1)
Save-Text -Path (Join-Path $InfoDir 'systeminfo.txt')  -Content ((& systeminfo) 2>&1)
Save-Text -Path (Join-Path $InfoDir 'ipconfig.txt')    -Content ((& ipconfig /all) 2>&1)

# CIM device details (serial, OS, current user)
$DeviceInfo = [ordered]@{}
try {
    $Bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $CS   = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $OS   = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $DeviceInfo['ComputerName']   = $CS.Name
    $DeviceInfo['Domain']         = $CS.Domain
    $DeviceInfo['PartOfDomain']   = $CS.PartOfDomain
    $DeviceInfo['CurrentUser']    = $CS.UserName
    $DeviceInfo['SerialNumber']   = $Bios.SerialNumber
    $DeviceInfo['BiosManufacturer'] = $Bios.Manufacturer
    $DeviceInfo['BiosVersion']    = $Bios.SMBIOSBIOSVersion
    $DeviceInfo['OsCaption']      = $OS.Caption
    $DeviceInfo['OsVersion']      = $OS.Version
    $DeviceInfo['OsBuildNumber']  = $OS.BuildNumber
    $DeviceInfo['OsInstallDate']  = $OS.InstallDate
    $DeviceInfo['LastBootTime']   = $OS.LastBootUpTime
}
catch { }
Save-Text -Path (Join-Path $InfoDir 'device_info.txt') -Content ($DeviceInfo | Format-List | Out-String)

# Installed software (both 64-bit and 32-bit hives)
$InstalledApps = @(
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
    Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation |
    Sort-Object DisplayName
Save-Text -Path (Join-Path $InfoDir 'installed_apps.txt') -Content ($InstalledApps | Format-Table -AutoSize | Out-String -Width 200)

# Group Policy result (computer scope — does not require user interaction)
$GpHtml = Join-Path $InfoDir 'gpresult.html'
& gpresult /h $GpHtml /f 2>$null | Out-Null
Save-Text -Path (Join-Path $InfoDir 'gpresult_text.txt') -Content ((& gpresult /r /scope:computer) 2>&1)

# Local admins (who has elevation on this device)
Save-Text -Path (Join-Path $InfoDir 'local_admins.txt') -Content ((& net localgroup administrators) 2>&1)

Add-Status '[1/8] Device information complete.'

# =============================================================================
# SECTION 2: IME LOGS (Intune Management Extension)
# =============================================================================

Write-Host '[2/8] IME logs...' -ForegroundColor Yellow
$ImeDir = Join-Path $OutDir 'IME'
$ImeSrc = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

if (Test-Path -LiteralPath $ImeSrc) {
    Copy-Tree -SourcePath $ImeSrc -DestPath $ImeDir
    $Count = (Get-ChildItem -LiteralPath $ImeDir -File -Recurse -ErrorAction SilentlyContinue).Count
    Add-Status "[2/8] IME logs complete -- $Count file(s) copied."
}
else {
    Add-Status '[2/8] IME logs -- source path not found (IME may not be installed).'
}

# =============================================================================
# SECTION 3: HALL COUNTY LOGS, MARKERS, AND DEPLOYMENT FILES
# =============================================================================

Write-Host '[3/8] Hall County logs...' -ForegroundColor Yellow

$HcDir   = Join-Path $OutDir 'HallCounty'
$ImeRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension'

# Current IME-rooted script-created runtime folders
Copy-Tree -SourcePath (Join-Path $ImeRoot 'AppMarkers')  -DestPath (Join-Path $HcDir 'AppMarkers')
Copy-Tree -SourcePath (Join-Path $ImeRoot 'Images')      -DestPath (Join-Path $HcDir 'Images')
Copy-Tree -SourcePath (Join-Path $ImeRoot 'ScriptFiles') -DestPath (Join-Path $HcDir 'ScriptFiles')

# Legacy app install/uninstall error logs
Copy-Tree -SourcePath 'C:\IntuneAppLogs'         -DestPath (Join-Path $HcDir 'Legacy\AppLogs')

# Legacy script-only error logs
Copy-Tree -SourcePath 'C:\IntuneScriptLogs'      -DestPath (Join-Path $HcDir 'Legacy\ScriptLogs')

# Marker files - presence or absence is diagnostic evidence for each app
if (Test-Path -LiteralPath (Join-Path $ImeRoot 'AppMarkers')) {
    $MarkerDest = Join-Path $HcDir 'AppMarkers'
    New-Dir -Path $MarkerDest

    # Summary list: one marker = one app that completed successfully
    $MarkerList = Get-ChildItem -LiteralPath (Join-Path $ImeRoot 'AppMarkers') -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object Name, LastWriteTime, @{N='SizeBytes';E={$_.Length}} |
        Sort-Object LastWriteTime
    Save-Text -Path (Join-Path $MarkerDest '_marker_summary.txt') -Content ($MarkerList | Format-Table -AutoSize | Out-String)
}

# Legacy marker files
if (Test-Path -LiteralPath 'C:\IntuneAppMarkers') {
    $MarkerDest = Join-Path $HcDir 'Legacy\AppMarkers'
    New-Dir -Path $MarkerDest
    Copy-Item -Path 'C:\IntuneAppMarkers\*' -Destination $MarkerDest -Recurse -Force -ErrorAction SilentlyContinue

    # Summary list: one marker = one app that completed successfully
    $MarkerList = Get-ChildItem -LiteralPath 'C:\IntuneAppMarkers' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object Name, LastWriteTime, @{N='SizeBytes';E={$_.Length}} |
        Sort-Object LastWriteTime
    Save-Text -Path (Join-Path $MarkerDest '_marker_summary.txt') -Content ($MarkerList | Format-Table -AutoSize | Out-String)
}

# Legacy deployment assets (prefix file, images, configs)
Copy-Tree -SourcePath 'C:\IntuneDeploymentFiles' -DestPath (Join-Path $HcDir 'Legacy\DeploymentFiles')

# Legacy end-user-facing scripts (sync buttons, etc.)
Copy-Tree -SourcePath 'C:\IntuneScripts'         -DestPath (Join-Path $HcDir 'Legacy\Scripts')

# AppX bloatware diagnostic trace (append-only, survives reboots — always copy unconditionally)
$AppXDiag = 'C:\Windows\Temp\System-RemoveBloatwareAppX_Diag.txt'
if (Test-Path -LiteralPath $AppXDiag) {
    Copy-Item -LiteralPath $AppXDiag -Destination (Join-Path $HcDir 'AppLogs\') -Force -ErrorAction SilentlyContinue
}

Add-Status '[3/8] Hall County logs complete.'

# =============================================================================
# SECTION 4: WINDOWS SETUP AND PROVISIONING LOGS
# =============================================================================

Write-Host '[4/8] Windows setup logs...' -ForegroundColor Yellow
$SetupDir = Join-Path $OutDir 'Setup'

Copy-Tree -SourcePath 'C:\Windows\Panther'                     -DestPath (Join-Path $SetupDir 'Panther')
Copy-Tree -SourcePath 'C:\Windows\Panther\UnattendGC'          -DestPath (Join-Path $SetupDir 'Panther_UnattendGC')
Copy-Tree -SourcePath 'C:\Windows\Logs\MoSetup'                -DestPath (Join-Path $SetupDir 'MoSetup')
Copy-Tree -SourcePath 'C:\Windows\System32\sysprep\Panther'    -DestPath (Join-Path $SetupDir 'SysprepPanther')

# CBS/component log (relevant if Windows Update ran during provisioning)
$CbsLog = 'C:\Windows\Logs\CBS\CBS.log'
if (Test-Path -LiteralPath $CbsLog) {
    New-Dir -Path (Join-Path $SetupDir 'CBS')
    Copy-Item -LiteralPath $CbsLog -Destination (Join-Path $SetupDir 'CBS\') -Force -ErrorAction SilentlyContinue
}

Add-Status '[4/8] Windows setup logs complete.'

# =============================================================================
# SECTION 5: WINDOWS EVENT LOGS
# =============================================================================

Write-Host '[5/8] Event log export...' -ForegroundColor Yellow
$EventDir = Join-Path $OutDir 'Events'
New-Dir -Path $EventDir

$EventChannels = @(
    # General OS
    'System'
    'Application'

    # MDM / Intune enrollment
    'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'
    'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational'

    # Autopilot / modern deployment
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Admin'
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot'
    'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService'

    # Entra / hybrid join
    'Microsoft-Windows-User Device Registration/Admin'
    'Microsoft-Windows-AAD/Operational'

    # Group Policy
    'Microsoft-Windows-GroupPolicy/Operational'

    # Provisioning (OEM / OOBE)
    'Microsoft-Windows-Provisioning-Diagnostics-Provider/Admin'
    'Microsoft-Windows-Provisioning-Diagnostics-Provider/AutoPilot'

    # Task Scheduler (detects any scheduled tasks that fired during WG)
    'Microsoft-Windows-TaskScheduler/Operational'

    # Windows Update (if updates were applied during provisioning)
    'Microsoft-Windows-WindowsUpdateClient/Operational'
)

$EventStatus = foreach ($Channel in $EventChannels) {
    Export-EventLog -LogName $Channel -DestFolder $EventDir
}
Save-Text -Path (Join-Path $EventDir '_export_status.txt') -Content $EventStatus

# Plain-text summaries of the highest-value channels for quick triage without an Event Viewer
Export-EventLogText -LogName 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin' `
                    -DestPath (Join-Path $EventDir 'MDM_Admin.txt')
Export-EventLogText -LogName 'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot' `
                    -DestPath (Join-Path $EventDir 'ModernDeployment_Autopilot.txt')
Export-EventLogText -LogName 'Microsoft-Windows-User Device Registration/Admin' `
                    -DestPath (Join-Path $EventDir 'UserDeviceReg_Admin.txt')

Add-Status "[5/8] Event logs complete -- $($EventChannels.Count) channel(s) attempted."

# =============================================================================
# SECTION 6: REGISTRY EXPORTS
# =============================================================================

Write-Host '[6/8] Registry export...' -ForegroundColor Yellow
$RegDir = Join-Path $OutDir 'Registry'
New-Dir -Path $RegDir

$RegStatus = @(
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Enrollments'                              (Join-Path $RegDir 'Enrollments.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot'       (Join-Path $RegDir 'Autopilot_Diagnostics.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Windows\Autopilot'                        (Join-Path $RegDir 'Autopilot.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking' (Join-Path $RegDir 'EnrollmentStatusTracking.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\PolicyManager'                             (Join-Path $RegDir 'PolicyManager.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'    (Join-Path $RegDir 'ProfileList.reg')
    Export-Registry 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'         (Join-Path $RegDir 'Uninstall_64.reg')
    Export-Registry 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' (Join-Path $RegDir 'Uninstall_32.reg')
)
Save-Text -Path (Join-Path $RegDir '_export_status.txt') -Content $RegStatus

Add-Status '[6/8] Registry export complete.'

# =============================================================================
# SECTION 7: MDM DIAGNOSTICS TOOL
# =============================================================================

Write-Host '[7/8] MDM Diagnostics Tool...' -ForegroundColor Yellow
$MdmDir = Join-Path $OutDir 'MDM'
New-Dir -Path $MdmDir

$MdmTool = 'C:\Windows\System32\MdmDiagnosticsTool.exe'
if (Test-Path -LiteralPath $MdmTool) {
    $MdmZip = Join-Path $MdmDir 'MdmDiagnostics.zip'
    $output = & $MdmTool -area 'Autopilot;DeviceEnrollment;DeviceProvisioning;TPM;PolicyPlatform;Certificates' -zip $MdmZip 2>&1
    if (Test-Path -LiteralPath $MdmZip) {
        Add-Status '[7/8] MDM Diagnostics Tool complete.'
    }
    else {
        Save-Text -Path (Join-Path $MdmDir 'MdmDiagnosticsTool_error.txt') -Content $output
        Add-Status '[7/8] MDM Diagnostics Tool ran but produced no output file -- see MdmDiagnosticsTool_error.txt.'
    }
}
else {
    Add-Status '[7/8] MDM Diagnostics Tool not found (C:\Windows\System32\MdmDiagnosticsTool.exe).'
}

# =============================================================================
# SECTION 8: SUMMARY AND TRIAGE GUIDE
# =============================================================================

Write-Host '[8/8] Building summary...' -ForegroundColor Yellow

$AllFiles  = Get-ChildItem -LiteralPath $OutDir -File -Recurse -ErrorAction SilentlyContinue
$TotalMB   = [math]::Round(($AllFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
$TotalFiles = $AllFiles.Count

$Summary = @"
============================================================
 AP-LogCapture.cmd -- Deployment Log Capture
 Timestamp:   $RunStamp
 Computer:    $env:COMPUTERNAME
 Output:      $OutDir
 Total files: $TotalFiles
 Total size:  ${TotalMB} MB
============================================================

CAPTURE STATUS
--------------
$($StatusLog -join "`r`n")

QUICK TRIAGE GUIDE
------------------
Start here for Intune/IME issues:
  IME\IntuneManagementExtension.log  -- Policy check-in, app discovery, IME health
  IME\AppWorkload.log                -- Win32 app install/uninstall workflow
  IME\AgentExecutor.log              -- Platform PowerShell script execution
  IME\AppActionProcessor.log         -- App applicability and detection evaluation
  IME\HealthScripts.log              -- Remediations and custom compliance

Start here for Autopilot / enrollment issues:
  Events\ModernDeployment_Autopilot.txt      -- Autopilot phase-by-phase trace
  Events\MDM_Admin.txt                       -- MDM enrollment and policy delivery
  Events\UserDeviceReg_Admin.txt             -- Entra / hybrid join events
  Info\dsregcmd.txt                          -- Current device join state
  Registry\Enrollments.reg                   -- Enrollment GUIDs and state flags
  Registry\EnrollmentStatusTracking.reg      -- ESP blocking app tracking

Start here for Hall County app issues:
  HallCounty\AppMarkers\                     -- One .tag file per successfully completed app
  HallCounty\AppMarkers\_marker_summary.txt  -- Sorted list with timestamps
  HallCounty\AppLogs\                        -- Error logs (only written on failure)
  HallCounty\ScriptLogs\                     -- Script-only error logs
  HallCounty\DeploymentFiles\DevicePrefix.txt-- Prefix used by the rename app

Start here for rename issues:
  HallCounty\AppLogs\HC-RenameDevice_Install.txt
  Info\dsregcmd.txt   (look for: DomainJoined, AzureAdJoined, DeviceName)
  Info\hostname.txt   (current computer name at time of capture)

MDM full diagnostics package:
  MDM\MdmDiagnostics.zip   -- Open with Event Viewer or extract for raw data

============================================================
"@

Save-Text -Path (Join-Path $OutDir '_SUMMARY.txt') -Content $Summary
Write-Host ''
Write-Host $Summary -ForegroundColor Cyan

exit 0
