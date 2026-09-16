#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstalls OnBase Client 16 by running the site's existing OB16Uninstall
    batch, adapted to run from the Intune package.

.DESCRIPTION
    Intune Win32 App uninstallation script. Counterpart to Install-OnBase.ps1.
    Thin wrapper around Auto\OB16Uninstall-Intune.bat - the uninstall LOGIC
    is exactly the site's existing PDQ batch (Auto\OB16Uninstall.bat), not
    reimplemented here. The only change made to produce the "-Intune" variant
    was replacing \\hallcounty\filestore\... UNC paths with %~dp0-relative
    paths (both msiexec /x calls already used /quiet in the original, so no
    missing-silent-switch fix was needed here the way it was for the install
    batch). See Auto\OB16Uninstall-Intune.bat's own header comment for full
    detail. The PDQ-original batch is untouched, in the Auto\ folder.

    This script lives at the project root (Software\OnBase\), one level
    above Auto\, which holds the batch files and all their referenced
    payload. The batch reference below is Auto\-relative for that reason.

    The batch removes the Hyland Desktop and Hyland Unity Client MSI
    products (msiexec /x against the bundled .msi files, which is valid,
    documented Windows Installer behavior - the ProductCode is read from the
    .msi's own Property table), deletes the OnBase 16 desktop shortcut, and
    removes the raw-copied C:\Program Files\OnBase Client 16 folder.

    Deliberately does NOT remove the VC++ 2013 runtime prerequisite (an
    earlier draft of this project incorrectly called this VC++ 2010), the
    SQL Native Client ODBC drivers, the ODBC registry imports, or
    C:\programdata\hyland software\onbase32.ini - same scope as the site's
    own original uninstall script. Those are shared/prerequisite components
    other software may also depend on; removing them was never part of the
    existing design and was not added here.

    Idempotent: if OnBase 16 is already absent, the batch's msiexec /x and
    delete/rd steps simply no-op (msiexec /x against an already-removed
    product returns a recognized non-fatal code; If Exist / rd guard the
    file operations) and this script still verifies the checked portion of
    the absent end state afterward. This is NOT a complete verification -
    see project AI-Audit-Handoff.md for the full, still-open list of gaps.

    After a successful uninstall (verified below), this script also removes
    the DPI compatibility logon scheduled task and its staged helper script
    that Install-OnBase.ps1/Set-OnBaseDpiCompatibility-PDQ.ps1 register (see
    those scripts and AI-Audit-Decisions.md) - best-effort, does not fail
    the uninstall.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_OnBase_Uninstall.txt
    (IME-rooted per the current shop standard - C:\IntuneAppLogs is the
    legacy fallback path).

    Exit Codes:
        0 = Success (batch ran and the checked portion of absence was
            verified)
        1 = Failure (batch failed to launch, or verification found
            remaining evidence; Intune will retry)

.NOTES
    Version:        1.1.2
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Uninstall OnBase Client 16 via the site's existing uninstall batch, adapted for Intune

    CHANGE LOG
    Change: 17/08/2026 - Initial release as Uninstall-OnBase16.ps1, located
                         in Auto\ -- ver. 1.0.0
    Change: 18/08/2026 - Relocated to the project root (Software\OnBase\) and
                         renamed to Uninstall-OnBase.ps1; batch path
                         reference updated to Auto\OB16Uninstall-Intune.bat;
                         $script:AppName shortened to 'OnBase' (log files are
                         now OnBase_Uninstall.txt, matching the new script
                         name); corrected prerequisite documentation from
                         VC++ 2010 to VC++ 2013 (proven from the bundled
                         installer's own signed version metadata - see
                         AI-Audit-Decisions.md); removed the diagnostic
                         Write-ErrorLog call that fired unconditionally on
                         every run, which contradicted this script's own
                         documented error-only logging -- ver. 1.1.0
    Change: 20/08/2026 - Moved script-authored logging from the legacy
                         C:\IntuneAppLogs to the current IME-rooted
                         standard, C:\ProgramData\Microsoft\
                         IntuneManagementExtension\Logs, and renamed the
                         log file from OnBase_Uninstall.txt to
                         APP_OnBase_Uninstall.txt to match the shop's
                         current naming convention; corrected the stale
                         "Paired install script" version reference below
                         (was v1.1.1, now v1.1.8) -- ver. 1.1.1
    Change: 21/08/2026 - Added Remove-OnBaseDpiCompatibilityLogonTask:
                         best-effort removal of the SYSTEM-context AtLogOn
                         scheduled task and staged helper script that
                         Install-OnBase.ps1 (v1.1.9+) and
                         Set-OnBaseDpiCompatibility-PDQ.ps1 (v1.0.3+) now
                         register for the DPI compatibility logon fix
                         (replacing the earlier Default User hive
                         injection, confirmed not to work - see
                         AI-Audit-Decisions.md). Called after successful
                         uninstall verification; failure here is logged,
                         not fatal - an orphaned task/helper is harmless to
                         a removed application but wasteful to leave
                         behind. Updated "Paired install script" reference
                         to v1.1.9 -- ver. 1.1.2

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-OnBase.ps1
      Install behavior: System
      SysNative is required for the same concrete reason as the install
      script: the batch's "rd" against C:\Program Files\OnBase Client 16
      would be WOW64-redirected to C:\Program Files (x86) if cmd.exe (a
      child of this PowerShell process) were 32-bit.

    PDQ COUNTERPART
      Auto\OB16Uninstall.bat (untouched).

    Paired install script: Install-OnBase.ps1 v1.1.9

    KNOWN RISKS (see project AI-Audit-Handoff.md for full detail - a fresh
    audit on 2026-08-17 found several open findings not yet acted on)
      - Verification after the batch runs covers only four artifacts
        (client exe, both MSI ProductCodes, shortcut) - it does not confirm
        the complete C:\Program Files\OnBase Client 16 directory is gone,
        only that the exe within it is.
      - Force-killing obunity.exe/DMDesktop.exe/obclnt32.exe has no
        user-notification or grace period.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion = '1.1.2'
$script:AppName       = 'OnBase'

$script:UninstallBatchRelativePath = Join-Path -Path 'Auto' -ChildPath 'OB16Uninstall-Intune.bat'
$script:UninstallTimeoutSeconds    = 300

$script:ClientExePath = 'C:\Program Files\OnBase Client 16\obclnt32.exe'
$script:ShortcutPath  = 'C:\Users\Public\Desktop\OnBase 16.lnk'

# Proven directly from the bundled MSI files' own Property tables
# (WindowsInstaller.Installer COM, ProductCode) on 2026-08-17 - see
# AI-Audit-Decisions.md. Must stay identical to Install-OnBase.ps1's values.
$script:DesktopProductCode     = '{DADFAF01-82CE-43D8-8520-3D7D214F9356}'
$script:UnityClientProductCode = '{18E17873-DC2D-4085-B752-DD127D388EBD}'

$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# Scheduled task + staged helper registered by Install-OnBase.ps1 (v1.1.9+)
# and Set-OnBaseDpiCompatibility-PDQ.ps1 (v1.0.3+) for the DPI compatibility
# logon fix. Must match those scripts' constants exactly.
$script:LogonTaskName     = 'Hall County MIS - OnBase DPI Compatibility Logon Fix'
$script:LogonHelperFolder = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\OnBase'

# IME-rooted per the current shop standard (reference_intune_paths.md /
# AGENTS.md "IME Runtime Paths") - C:\IntuneAppLogs is the legacy fallback,
# not used by new work.
$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Uninstall.txt')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    # Logging helper must never throw; all I/O uses SilentlyContinue.
    param(
        [string]$Message,
        [string]$Category = 'App'
    )
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = '[{0}] [v{1}] [{2}] {3}' -f $Timestamp, $script:ScriptVersion, $Category, $Message
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}

function Stop-WithFailure {
    param(
        [string]$Message,
        [string]$Category = 'App'
    )
    Write-ErrorLog -Message $Message -Category $Category
    Write-Output $Message
    exit 1
}

function Get-ScriptRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }
    return $null
}

function Test-IsAdministrator {
    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        if ($null -ne $Identity.User -and [string]$Identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $Principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList (,$Identity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $Parts = @()
    $CurrentException = $ErrorRecord.Exception

    while ($null -ne $CurrentException) {
        $TypeName = $CurrentException.GetType().FullName
        $Message = $CurrentException.Message
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = '(no message provided)'
        }
        else {
            $Message = ($Message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }
        $Parts += ('{0}: {1}' -f $TypeName, $Message)
        $CurrentException = $CurrentException.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        $Parts += ('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber)
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.FullyQualifiedErrorId)) {
        $Parts += ('ErrorId: {0}' -f $ErrorRecord.FullyQualifiedErrorId)
    }

    return ($Parts -join ' | ')
}

function Test-MsiProductRegistered {
    param(
        [string]$ProductCode
    )

    foreach ($RegistryPath in $script:RegistryPaths) {
        $KeyPath = Join-Path -Path $RegistryPath -ChildPath $ProductCode
        if (Test-Path -LiteralPath $KeyPath) {
            return $true
        }
    }

    return $false
}

function Stop-ProcessTree {
    param(
        [int]$ProcessId
    )
    $TaskKillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'
    if (Test-Path -LiteralPath $TaskKillPath -PathType Leaf) {
        try {
            $null = & $TaskKillPath /PID $ProcessId /T /F 2>&1
            if ($LASTEXITCODE -in @(0, 128)) {
                return
            }
        }
        catch { }
    }
    try {
        $Process = [System.Diagnostics.Process]::GetProcessById($ProcessId)
        try {
            $Process.Kill()
            $null = $Process.WaitForExit(5000)
        }
        finally {
            $Process.Dispose()
        }
    }
    catch { }
}

function Invoke-OnBaseUninstallBatch {
    param(
        [string]$BatchPath,
        [int]$TimeoutSeconds
    )

    # Same cmd.exe invocation pattern as Install-OnBase.ps1 / the PDQ
    # original: /s plus the doubled leading quote correctly handles a
    # quoted path that itself contains spaces.
    $ComSpecPath = if (-not [string]::IsNullOrWhiteSpace($env:ComSpec)) { $env:ComSpec } else { Join-Path -Path $env:SystemRoot -ChildPath 'System32\cmd.exe' }
    $ArgumentString = '/s /c ""{0}" "' -f $BatchPath

    $StartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $ComSpecPath
    $StartInfo.Arguments = $ArgumentString
    $StartInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($BatchPath)
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true

    $Process = New-Object -TypeName System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        $Started = $Process.Start()
        if (-not $Started) {
            throw 'Process.Start() returned False for cmd.exe without throwing.'
        }

        $HasExited = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $HasExited) {
            Stop-ProcessTree -ProcessId $Process.Id
            try { $null = $Process.WaitForExit(5000) } catch { }
            throw ('OnBase uninstall batch timed out after {0} seconds and was terminated.' -f $TimeoutSeconds)
        }

        return [int]$Process.ExitCode
    }
    finally {
        $Process.Dispose()
    }
}

function Remove-OnBaseDpiCompatibilityLogonTask {
    # Best-effort, non-fatal: an orphaned task/helper is harmless to a
    # removed application (it would just keep re-writing an AppCompat entry
    # for an exe that no longer exists), but leaving it behind is wasteful
    # and confusing, so clean it up rather than treat it as acceptable.
    try {
        $ExistingTask = Get-ScheduledTask -TaskName $script:LogonTaskName -ErrorAction SilentlyContinue
        if ($null -ne $ExistingTask) {
            Unregister-ScheduledTask -InputObject $ExistingTask -Confirm:$false -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to remove the DPI compatibility logon scheduled task: $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
    }

    try {
        if (Test-Path -LiteralPath $script:LogonHelperFolder -PathType Container) {
            Remove-Item -LiteralPath $script:LogonHelperFolder -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to remove the staged DPI compatibility logon helper folder '$($script:LogonHelperFolder)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'Compatibility'
    }
}

function Test-OnBase16Absent {
    # Returns a single psobject rather than a positional tuple - see
    # Install-OnBase.ps1's Test-OnBase16Installed for why.
    $RemainingEvidence = @()

    if (Test-Path -LiteralPath $script:ClientExePath -PathType Leaf) {
        $RemainingEvidence += 'OnBase Client 16 executable still present'
    }
    if (Test-MsiProductRegistered -ProductCode $script:DesktopProductCode) {
        $RemainingEvidence += 'Hyland Desktop MSI product still registered'
    }
    if (Test-MsiProductRegistered -ProductCode $script:UnityClientProductCode) {
        $RemainingEvidence += 'Hyland Unity Client MSI product still registered'
    }
    if (Test-Path -LiteralPath $script:ShortcutPath -PathType Leaf) {
        $RemainingEvidence += 'Public Desktop shortcut still present'
    }

    return New-Object -TypeName psobject -Property @{
        IsAbsent  = ($RemainingEvidence.Count -eq 0)
        Remaining = $RemainingEvidence
    }
}

# =============================================================================
# MAIN
# =============================================================================

$ScriptRoot = Get-ScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
    Stop-WithFailure -Message 'Unable to resolve script directory. Run this as a saved .ps1 file from disk, not from an unsaved or transient host context.' -Category 'Intune'
}

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -Message 'This uninstaller requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

$BatchPath = Join-Path -Path $ScriptRoot -ChildPath $script:UninstallBatchRelativePath
if (-not (Test-Path -LiteralPath $BatchPath -PathType Leaf)) {
    Stop-WithFailure -Message "Uninstall batch not found at '$BatchPath'. Verify the package contains '$($script:UninstallBatchRelativePath)' and its referenced Desktop\/AE\ subfolders." -Category 'Intune'
}

try {
    $BatchExitCode = 0
    try {
        $BatchExitCode = Invoke-OnBaseUninstallBatch -BatchPath $BatchPath -TimeoutSeconds $script:UninstallTimeoutSeconds
    }
    catch {
        throw "BATCH LAUNCH FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # Batch has no internal error checking between steps; raw exit code is
    # not treated as pass/fail on its own (see .DESCRIPTION). Surfaced on
    # the success STDOUT line and, on failure, inside the thrown message -
    # not via an unconditional log write, which would contradict this
    # script's error-only logging.
    Start-Sleep -Seconds 5

    $VerifyResult = Test-OnBase16Absent

    if (-not $VerifyResult.IsAbsent) {
        $RemainingText = [string]::Join('; ', @($VerifyResult.Remaining))
        throw "Uninstall batch ran (raw exit code $BatchExitCode) but the following evidence still exists: $RemainingText"
    }

    Remove-OnBaseDpiCompatibilityLogonTask

    Write-Output "OnBase uninstall script v$($script:ScriptVersion) completed successfully: client executable, both MSI products, and desktop shortcut all confirmed absent. Batch raw exit code was $BatchExitCode."
    exit 0
}
catch {
    Stop-WithFailure -Message $_.Exception.Message -Category 'App'
}
