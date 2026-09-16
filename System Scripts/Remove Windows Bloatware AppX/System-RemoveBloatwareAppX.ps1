#Requires -Version 5.1

<#
.SYNOPSIS
    Removes pre-installed Windows bloatware AppX packages from a device.

.DESCRIPTION
    Intune Win32 app install script. Runs as SYSTEM in device context via IME.

    - Copies the bundled Debloat package from this package's extraction
      folder to C:\ProgramData\Debloat and executes removebloat.ps1 there to
      remove unwanted AppX packages using its built-in whitelist only
      (custom whitelist command parameters are not supported).
    - Runs a supplemental DISM-based removal pass for Clipchamp after
      RemoveBloat.ps1 completes. On Windows 11 22H2+, Microsoft classifies
      Clipchamp as a protected component; Remove-AppxProvisionedPackage
      silently fails with 0x80073CFA while DISM retains the authority to
      remove it. Failure of this supplemental pass is non-fatal.
    - Writes a versioned Intune marker recording successful completion:
      C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\System-RemoveBloatwareAppX.marker
    - Removes any stale PDQ marker for this app (none currently deployed,
      but this is a safe no-op and keeps a future PDQ counterpart correct),
      and removes the pre-1.1.0 legacy marker once the new one is written.
    - Logs only on error/warning to
      C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_RemoveBloatwareAppX_Install.txt.

.NOTES
    Version:        1.1.0
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  27/04/2026
    Purpose:        Remove default Windows bloatware AppX packages at device provisioning time

    ERROR CODES
      0    = Success
      1701 = Could not resolve this script's own source folder (invalid invocation context)
      1702 = Failed to create or access the Debloat staging folder
      1703 = Failed to copy the bundled Debloat package into the staging folder
      1704 = RemoveBloat.ps1 failed to launch, or returned a non-zero exit code
      1705 = RemoveBloat.ps1 wrote to stderr
      1706 = Failed to finalize the Intune marker and PDQ handoff
      1707 = DISM failed to remove the Clipchamp provisioned package (non-fatal - install continues; logged only, not a script exit code)
      1799 = Unexpected error

    CHANGE LOG
    Change: 27/04/2026 - Initial release -- ver. 1.0.0
    Change: 27/04/2026 - Added supplemental DISM removal pass for Clipchamp -- ver. 1.0.1
    Change: 27/04/2026 - Fixed empty $PSScriptRoot when script is dot-sourced or run interactively -- ver. 1.0.2
    Change: 27/04/2026 - Fixed StrictMode error on missing MyCommand.Path property in console sessions -- ver. 1.0.3
    Change: 27/04/2026 - Replaced $PWD fallback with actionable error; script now works from any working directory -- ver. 1.0.4
    Change: 04/05/2026 - Added marker writing and child script stderr/exit-code validation -- ver. 1.0.5
    Change: 04/05/2026 - Removed custom whitelist command parameter path -- ver. 1.0.6
    Change: 08/09/2026 - Moved the detection marker and error log to the
                         current IME-rooted standard (AppMarkers\
                         System-RemoveBloatwareAppX.marker and
                         SCRIPT_RemoveBloatwareAppX_Install.txt), replaced
                         generic throw/exit-1 failure handling with
                         distinct numbered error codes and error-only
                         logging, added PDQ marker handoff and legacy
                         marker cleanup, switched the child PowerShell host
                         to an explicit SysNative path, and relocated the
                         ERROR CODES block ahead of CHANGE LOG per the new
                         campus-wide .NOTES standard -- ver. 1.1.0

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\System-RemoveBloatwareAppX.ps1

      Install behavior: System
      Detection: custom PowerShell (Detect.ps1)
#>

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName    = 'System-RemoveBloatwareAppX'
$script:AppVersion = '1.1.0'
$script:ScriptName = 'RemoveBloatwareAppX'

$script:DebloatFolder = 'C:\ProgramData\Debloat'

$script:IntuneMarkerRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:IntuneMarkerPath = Join-Path -Path $script:IntuneMarkerRoot -ChildPath ($script:AppName + '.marker')
$script:PdqMarkerRoot    = 'C:\ProgramData\PDQ\AppMarkers'
$script:PdqMarkerPath    = Join-Path -Path $script:PdqMarkerRoot -ChildPath ($script:AppName + '.marker')
$script:LegacyMarkerPath = 'C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag'

$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('SCRIPT_{0}_Install.txt' -f $script:ScriptName)

# =============================================================================
# END CONFIGURATION
# =============================================================================

$EXIT_SUCCESS           = 0
$ERR_SCRIPT_ROOT        = 1701
$ERR_DEBLOAT_FOLDER     = 1702
$ERR_COPY_PACKAGE       = 1703
$ERR_REMOVEBLOAT_RUN    = 1704
$ERR_REMOVEBLOAT_STDERR = 1705
$ERR_MARKER_WRITE       = 1706
$ERR_CLIPCHAMP_DISM     = 1707
$ERR_UNEXPECTED         = 1799

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    param(
        [string]$ErrorMessage,
        [string]$ErrorCode = 'N/A'
    )
    if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { return }
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        try { $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } catch { $ts = '(unavailable)' }
        $line = "[$ts] [v$script:AppVersion] [$ErrorCode] $ErrorMessage"
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Resolve-ScriptRoot {
    # $PSScriptRoot covers all file-based invocations (Intune/IME, & operator,
    # -File flag, dot-source). $MyInvocation.MyCommand.Path is a secondary
    # fallback for edge cases. If neither is available the script is being
    # run by pasting into a console session, which has no file identity.
    if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
        return $PSScriptRoot
    }
    $CmdPath = $null
    try { $CmdPath = $MyInvocation.MyCommand.Path } catch { $CmdPath = $null }
    if (-not [string]::IsNullOrEmpty($CmdPath)) {
        return (Split-Path -LiteralPath $CmdPath -Parent)
    }
    throw 'Cannot determine the script location. Invoke this script as a file (powershell.exe -File, the & call operator, or dot-source) rather than pasting it into a console session.'
}

function Initialize-DebloatFolder {
    param(
        [string]$FolderPath
    )
    if (Test-Path -LiteralPath $FolderPath -PathType Container) { return }
    New-Item -Path $FolderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        throw "Debloat folder was not created at '$FolderPath'."
    }
}

function Copy-DebloatPackage {
    param(
        [string]$SourceFolder,
        [string]$DestinationFolder
    )
    if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
        throw "Bundled Debloat package not found at '$SourceFolder'."
    }
    Copy-Item -Path (Join-Path -Path $SourceFolder -ChildPath '*') -Destination $DestinationFolder -Recurse -Force -ErrorAction Stop

    $DebloatScriptPath = Join-Path -Path $DestinationFolder -ChildPath 'removebloat.ps1'
    if (-not (Test-Path -LiteralPath $DebloatScriptPath -PathType Leaf)) {
        throw "removebloat.ps1 not present in staging folder after copy: '$DebloatScriptPath'."
    }
}

function Invoke-RemoveBloatScript {
    param(
        [string]$DebloatScriptPath,
        [string]$WorkingFolder
    )
    $StdOutPath = Join-Path -Path $WorkingFolder -ChildPath 'RemoveBloat.stdout.log'
    $StdErrPath = Join-Path -Path $WorkingFolder -ChildPath 'RemoveBloat.stderr.log'
    Remove-Item -LiteralPath $StdOutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdErrPath -Force -ErrorAction SilentlyContinue

    # Explicit SysNative path: a 32-bit PS host's System32 is redirected to
    # SysWOW64, which would silently launch a 32-bit child. Fall back to the
    # direct System32 path only if SysNative is unavailable (e.g. already a
    # 64-bit host on 32-bit Windows, where SysNative does not exist).
    $PowerShellExe = Join-Path -Path $env:SystemRoot -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $PowerShellExe -PathType Leaf)) {
        $PowerShellExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    $DebloatArgs = @(
        '-ExecutionPolicy', 'Bypass',
        '-NoProfile',
        '-NonInteractive',
        '-File', $DebloatScriptPath
    )

    $Process = Start-Process -FilePath $PowerShellExe -ArgumentList $DebloatArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -ErrorAction Stop

    if (Test-Path -LiteralPath $StdOutPath -PathType Leaf) {
        Get-Content -LiteralPath $StdOutPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_ }
    }

    $ErrorLines = @()
    if (Test-Path -LiteralPath $StdErrPath -PathType Leaf) {
        $ErrorLines = @(Get-Content -LiteralPath $StdErrPath -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        foreach ($Line in $ErrorLines) { Write-Output "RemoveBloat.ps1 stderr: $Line" }
    }

    return New-Object -TypeName psobject -Property @{
        ExitCode   = $Process.ExitCode
        ErrorLines = $ErrorLines
        StdErrPath = $StdErrPath
    }
}

function Remove-Marker {
    param(
        [string]$MarkerPath
    )
    if ([string]::IsNullOrWhiteSpace($MarkerPath)) { return }
    if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction SilentlyContinue
    }
}

function Write-IntuneMarker {
    param(
        [string]$DebloatScriptPath
    )
    New-Item -ItemType Directory -Path $script:IntuneMarkerRoot -Force -ErrorAction Stop | Out-Null
    $TempMarkerPath = $script:IntuneMarkerPath + '.tmp'
    Remove-Marker -MarkerPath $TempMarkerPath

    $Lines = @()
    try { $Lines += "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" } catch { $Lines += 'Timestamp=Unavailable' }
    $Lines += "Version=$($script:AppVersion)"
    $Lines += 'Status=Success'
    $Lines += "DebloatScript=$DebloatScriptPath"

    $Lines | Set-Content -LiteralPath $TempMarkerPath -Encoding UTF8 -Force -ErrorAction Stop

    $WrittenLines = @(Get-Content -LiteralPath $TempMarkerPath -ErrorAction Stop)
    if (-not ($WrittenLines -contains "Version=$($script:AppVersion)")) {
        throw "Temporary Intune marker verification did not find Version=$($script:AppVersion)."
    }
    if (-not ($WrittenLines -contains 'Status=Success')) {
        throw 'Temporary Intune marker verification did not find Status=Success.'
    }

    Move-Item -LiteralPath $TempMarkerPath -Destination $script:IntuneMarkerPath -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $script:IntuneMarkerPath -PathType Leaf)) {
        throw "Intune marker was not finalized at '$script:IntuneMarkerPath'."
    }
}

# =============================================================================
# MAIN
# =============================================================================

try {
    Write-Output "System-RemoveBloatwareAppX v$($script:AppVersion) starting."

    try {
        $ScriptRoot = Resolve-ScriptRoot
    }
    catch {
        Write-ErrorLog -ErrorMessage "[System] $($_.Exception.Message)" -ErrorCode $ERR_SCRIPT_ROOT
        exit $ERR_SCRIPT_ROOT
    }

    try {
        Initialize-DebloatFolder -FolderPath $script:DebloatFolder
    }
    catch {
        Write-ErrorLog -ErrorMessage "[System] Failed to prepare Debloat staging folder '$script:DebloatFolder'. Error: $($_.Exception.Message)" -ErrorCode $ERR_DEBLOAT_FOLDER
        exit $ERR_DEBLOAT_FOLDER
    }

    $SourceDebloat = Join-Path -Path $ScriptRoot -ChildPath 'Debloat'
    try {
        Copy-DebloatPackage -SourceFolder $SourceDebloat -DestinationFolder $script:DebloatFolder
    }
    catch {
        Write-ErrorLog -ErrorMessage "[App] Failed to copy Debloat package from '$SourceDebloat' to '$script:DebloatFolder'. Error: $($_.Exception.Message)" -ErrorCode $ERR_COPY_PACKAGE
        exit $ERR_COPY_PACKAGE
    }

    $DebloatScriptPath = Join-Path -Path $script:DebloatFolder -ChildPath 'removebloat.ps1'
    Write-Output "Launching $DebloatScriptPath."

    try {
        $RunResult = Invoke-RemoveBloatScript -DebloatScriptPath $DebloatScriptPath -WorkingFolder $script:DebloatFolder
    }
    catch {
        Write-ErrorLog -ErrorMessage "[App] Failed to launch RemoveBloat.ps1 at '$DebloatScriptPath'. Error: $($_.Exception.Message)" -ErrorCode $ERR_REMOVEBLOAT_RUN
        exit $ERR_REMOVEBLOAT_RUN
    }

    if ($RunResult.ExitCode -ne 0) {
        Write-ErrorLog -ErrorMessage "[App] RemoveBloat.ps1 exited with code $($RunResult.ExitCode)." -ErrorCode $ERR_REMOVEBLOAT_RUN
        exit $ERR_REMOVEBLOAT_RUN
    }

    if ($RunResult.ErrorLines.Count -gt 0) {
        Write-ErrorLog -ErrorMessage "[App] RemoveBloat.ps1 wrote to stderr. See $($RunResult.StdErrPath)." -ErrorCode $ERR_REMOVEBLOAT_STDERR
        exit $ERR_REMOVEBLOAT_STDERR
    }

    # Supplemental Clipchamp removal via DISM.
    # RemoveBloat.ps1 uses Remove-AppxProvisionedPackage with
    # -ErrorAction SilentlyContinue, which fails silently for Clipchamp on
    # Windows 11 22H2+ (error 0x80073CFA - Microsoft classifies it as a
    # protected system component at the AppX API level). DISM has the
    # authority to remove provisioned packages that the AppX cmdlets cannot.
    # Best-effort: failure here does not fail the overall install.
    Write-Output 'Starting supplemental Clipchamp removal pass.'

    $ClipInstalled = Get-AppxPackage -AllUsers -Name 'Clipchamp.Clipchamp' -ErrorAction SilentlyContinue
    if ($ClipInstalled) {
        try {
            $ClipInstalled | Remove-AppxPackage -AllUsers -ErrorAction Stop
            Write-Output 'Clipchamp installed package removed.'
        }
        catch {
            Write-Output "Clipchamp installed package removal failed (non-fatal): $_"
        }
    }
    else {
        Write-Output 'Clipchamp installed package not present.'
    }

    $DismExe = Join-Path -Path $env:SystemRoot -ChildPath 'SysNative\dism.exe'
    if (-not (Test-Path -LiteralPath $DismExe)) {
        $DismExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dism.exe'
    }

    $ClipProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq 'Clipchamp.Clipchamp' }

    if ($ClipProv) {
        Write-Output "Clipchamp provisioned package found: $($ClipProv.PackageName)"
        $DismArgs = @(
            '/Online',
            '/Remove-ProvisionedAppxPackage',
            "/PackageName:$($ClipProv.PackageName)",
            '/Quiet',
            '/NoRestart'
        )
        try {
            $DismProcess = Start-Process -FilePath $DismExe -ArgumentList $DismArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($DismProcess.ExitCode -eq 0) {
                Write-Output 'Clipchamp provisioned package removed successfully via DISM.'
            }
            else {
                Write-ErrorLog -ErrorMessage "[App] DISM Clipchamp removal failed (non-fatal). Exit code: $($DismProcess.ExitCode). PackageName: $($ClipProv.PackageName)." -ErrorCode $ERR_CLIPCHAMP_DISM
                Write-Output "DISM Clipchamp removal failed. Exit code: $($DismProcess.ExitCode)."
            }
        }
        catch {
            Write-ErrorLog -ErrorMessage "[App] DISM Clipchamp removal threw (non-fatal). Error: $($_.Exception.Message)" -ErrorCode $ERR_CLIPCHAMP_DISM
            Write-Output "DISM Clipchamp removal failed (non-fatal): $_"
        }
    }
    else {
        Write-Output 'Clipchamp provisioned package not found; no DISM action needed.'
    }

    try {
        Remove-Marker -MarkerPath $script:PdqMarkerPath
        Remove-Marker -MarkerPath ($script:PdqMarkerPath + '.tmp')
        Write-IntuneMarker -DebloatScriptPath $DebloatScriptPath
        Remove-Marker -MarkerPath $script:LegacyMarkerPath
    }
    catch {
        Write-ErrorLog -ErrorMessage "[App] Failed to finalize Intune marker '$script:IntuneMarkerPath' and PDQ handoff. Error: $($_.Exception.Message)" -ErrorCode $ERR_MARKER_WRITE
        exit $ERR_MARKER_WRITE
    }

    Write-Output "Detection marker written to $script:IntuneMarkerPath."
    Write-Output 'System-RemoveBloatwareAppX completed.'
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -ErrorMessage "[App] Unhandled exception: $($_.Exception.Message)" -ErrorCode $ERR_UNEXPECTED
    exit $ERR_UNEXPECTED
}
