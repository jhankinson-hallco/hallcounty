#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: uninstalls Microsoft Office 365 (M365 Apps for Enterprise) via the Office Deployment Tool.

.DESCRIPTION
    PDQ Deploy uninstall script. Tandem counterpart of the Intune Win32 app
    Uninstall.ps1 (v1.5.2).

    Pulls only the Office Deployment Tool setup.exe and Remove-C2R-All.xml from
    the shared filestore repository, stages them locally, and then runs setup.exe
    from the local staged folder to remove all Click-to-Run Office products from
    the device.

    Exits 0 on clean removal. Exits 3010/1641 if ODT signals a reboot is required.
    Exits the ODT exit code on any unexpected failure.

    Logs errors to C:\IntuneAppLogs\Office365_Uninstall.txt. PDQ entries are
    tagged [PDQ].
    ODT also writes its own diagnostic logs to C:\IntuneAppLogs via the Logging element
    in Remove-C2R-All.xml.

    TANDEM PARITY: the removed Office footprint is intended to be indistinguishable
    from the Intune uninstall. Any uninstall, XML, or logging-path change must be
    evaluated against BOTH deployment channels.

.NOTES
    Version:        1.0.2
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/04/2026
    Purpose:        Removes all C2R Office products via ODT Remove All

    CHANGE LOG
    Change: 14/04/2026 - Initial release -- ver. 1.0.0
    Change: 14/04/2026 - Version sync to 1.3.0 to match Install-Office365.ps1 package
                         versioning -- ver. 1.3.0
    Change: 14/04/2026 - Version sync to 1.4.0 for package consistency -- ver. 1.4.0
    Change: 14/04/2026 - Version sync to 1.5.0 for package consistency -- ver. 1.5.0
    Change: 17/04/2026 - Converted Write-ErrorLog, Exit-Failure, Get-ExceptionSummary to
                         simple functions (removed all [Parameter()] and [ValidateSet()]
                         attributes). Same PS 5.1 ParameterBindingException risk class as
                         Install-Office365.ps1. Re-saved as UTF-8 with BOM -- ver. 1.5.1
    Change: 17/04/2026 - Replaced Split-Path -LiteralPath ... -Parent with
                         [System.IO.Path]::GetDirectoryName() in scriptRoot resolution.
                         Same PS 5.1 ParameterBindingException class confirmed in
                         Remove-Office365.ps1 v1.5.7 -- ver. 1.5.2
    Change: 15/07/2026 - Initial PDQ release. Payload now stages setup.exe and
                         Remove-C2R-All.xml from the shared filestore repository
                         before executing locally; logs are tagged [PDQ]; tandem
                         with Intune Uninstall.ps1 v1.5.2 -- ver. 1.0.0
    Change: 15/07/2026 - Added explicit local administrator preflight before
                         payload staging or ODT removal -- ver. 1.0.1
    Change: 15/07/2026 - Logs best-effort payload-stage cleanup warnings so
                         local staging leftovers are visible in PDQ output/logs
                         without failing an otherwise completed uninstall -- ver. 1.0.2

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-Office365-PDQ.ps1
      Run As:        Deploy User with local administrator rights and READ access
                     to the filestore repository. Use Local System only if the
                     computer account can read the repository share.
      Success codes: 0, 3010, 1641

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      Payload: \\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365
#>

#region ========================= CONFIGURATION =========================

$script:AppName     = 'Office 365'
$script:AppVersion  = '1.5.2'
$script:LogRoot     = 'C:\IntuneAppLogs'
$script:LogFileName = 'Office365_Uninstall.txt'
$script:SetupExe    = 'setup.exe'
$script:RemoveXml   = 'Remove-C2R-All.xml'
$script:RepositoryRoot = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365'
$script:StageRoot      = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\Office365UninstallPDQ'
$script:PayloadStagePath = $null

# ODT timeout for removal. Removal is faster than install (no download).
# 1800 s (30 min) is generous; typical removal completes in 5-10 min.
$script:TimeoutSeconds = 1800

# ODT exit codes treated as success.
$script:SuccessExitCodes = @(0, 3010, 1641)

#endregion =================================================================


function Write-ErrorLog {
    # Simple function -- no [Parameter()] attributes.
    # PS 5.1 advanced-function parameter-set resolution produced ParameterBindingException
    # in IME/SYSTEM context. Simple functions bypass that engine entirely.
    # $Category valid values: App, System, Network, Permissions, Intune, PDQ
    param(
        [string]$Message,
        [string]$Category = 'App'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        $logPath   = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        if (-not [System.IO.File]::Exists($logPath)) {
            [System.IO.File]::WriteAllText($logPath, '', $utf8NoBom)
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line      = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try { [Console]::Error.WriteLine('{0} uninstall log failed: {1}' -f $script:AppName, $Message) } catch { }
    }
}


function Exit-Failure {
    # Simple function -- no [Parameter()] attributes. See Write-ErrorLog for rationale.
    # $Category valid values: App, System, Network, Permissions, Intune, PDQ
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

    Remove-PDQPayloadStage
    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}


function Get-ExceptionSummary {
    # Simple function -- no [Parameter()] attributes. See Write-ErrorLog for rationale.
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $ex    = $ErrorRecord.Exception

    while ($null -ne $ex) {
        $msg = if ([string]::IsNullOrWhiteSpace($ex.Message)) { '(no message)' }
               else { ($ex.Message -replace '(\r\n|\n|\r)+', ' ').Trim() }
        [void]$parts.Add(('{0}: {1}' -f $ex.GetType().FullName, $msg))
        $ex = $ex.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
    }

    return ($parts -join ' | ')
}


function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        if ($null -ne $identity.User -and [string]$identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}


function Get-PDQPayloadFileNames {
    return @(
        $script:SetupExe,
        $script:RemoveXml
    )
}


function Remove-PDQPayloadStage {
    # Removes only the exact files this PDQ package stages locally.
    try {
        if ([string]::IsNullOrWhiteSpace($script:PayloadStagePath)) {
            return
        }

        foreach ($fileName in (Get-PDQPayloadFileNames)) {
            $stagedFile = Join-Path -Path $script:PayloadStagePath -ChildPath $fileName
            if (Test-Path -LiteralPath $stagedFile -PathType Leaf) {
                Remove-Item -LiteralPath $stagedFile -Force -ErrorAction SilentlyContinue
            }
        }

        if (Test-Path -LiteralPath $script:PayloadStagePath -PathType Container) {
            $remainingItems = @(Get-ChildItem -LiteralPath $script:PayloadStagePath -Force -ErrorAction SilentlyContinue)
            if ($remainingItems.Count -eq 0) {
                Remove-Item -LiteralPath $script:PayloadStagePath -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-ErrorLog -Message ('Best-effort PDQ payload stage cleanup left {0} item(s) in ''{1}''.' -f $remainingItems.Count, $script:PayloadStagePath) -Category 'System'
            }
        }
    }
    catch {
        try {
            Write-ErrorLog -Message ('Best-effort PDQ payload stage cleanup failed for ''{0}'': {1}' -f $script:PayloadStagePath, $_.Exception.Message) -Category 'System'
        }
        catch {
            # Cleanup logging must never change the deployment result.
        }
    }
    finally {
        $script:PayloadStagePath = $null
    }
}


function Copy-PDQPayloadToLocalStage {
    if ([string]::IsNullOrWhiteSpace($script:RepositoryRoot)) {
        Exit-Failure -Code 1 -Message 'Configuration error: RepositoryRoot is blank.' -Category 'PDQ'
    }

    try {
        [void][System.IO.Directory]::CreateDirectory($script:StageRoot)
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Exit-Failure -Code 1 -Message ('Cannot create PDQ payload stage folder ''{0}'': {1}' -f $script:StageRoot, $summary) -Category 'Permissions'
    }

    $script:PayloadStagePath = $script:StageRoot

    foreach ($fileName in (Get-PDQPayloadFileNames)) {
        $sourcePath = Join-Path -Path $script:RepositoryRoot -ChildPath $fileName
        $destPath   = Join-Path -Path $script:PayloadStagePath -ChildPath $fileName

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Exit-Failure -Code 1 -Message ('PDQ payload file not found or not reachable: ''{0}''. Verify repository contents and PDQ run-as account access.' -f $sourcePath) -Category 'Network'
        }

        try {
            Copy-Item -LiteralPath $sourcePath -Destination $destPath -Force -ErrorAction Stop
        }
        catch {
            $summary = Get-ExceptionSummary -ErrorRecord $_
            Exit-Failure -Code 1 -Message ('Failed to stage PDQ payload file ''{0}'' to ''{1}'': {2}' -f $sourcePath, $destPath, $summary) -Category 'Network'
        }

        if (-not (Test-Path -LiteralPath $destPath -PathType Leaf)) {
            Exit-Failure -Code 1 -Message ('PDQ payload staging verification failed. File missing after copy: ''{0}''.' -f $destPath) -Category 'System'
        }
    }

    return $script:PayloadStagePath
}


# ==========================================================================
# MAIN
# ==========================================================================

try {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot }
                  elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { [System.IO.Path]::GetDirectoryName($PSCommandPath) }
                  else { $null }

    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Exit-Failure -Code 1 -Message 'Cannot resolve script directory. Run as a saved .ps1 file from disk.' -Category 'PDQ'
    }

    if (-not [Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message 'This script requires 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -Category 'PDQ'
    }

    if (-not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This uninstall script requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -Category 'Permissions'
    }

    $payloadRoot = Copy-PDQPayloadToLocalStage
    $setupPath   = Join-Path -Path $payloadRoot -ChildPath $script:SetupExe
    $xmlPath     = Join-Path -Path $payloadRoot -ChildPath $script:RemoveXml

    # Pre-create log root so ODT diagnostic output always has a destination.
    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Exit-Failure -Code 1 -Message ('Cannot create log folder ''{0}'': {1}' -f $script:LogRoot, $summary) -Category 'Permissions'
    }

    $arguments = '/configure "{0}"' -f $xmlPath

    $startInfo                  = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName         = $setupPath
    $startInfo.Arguments        = $arguments
    $startInfo.WorkingDirectory = $payloadRoot
    $startInfo.UseShellExecute  = $false
    $startInfo.CreateNoWindow   = $true

    $process           = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()

        if (-not $started) {
            throw ('Process.Start() returned False for ''{0}''.' -f $setupPath)
        }

        $hasExited = $process.WaitForExit($script:TimeoutSeconds * 1000)

        if (-not $hasExited) {
            try { $null = & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 } catch { }
            try { $null = $process.WaitForExit(5000) } catch { }
            Exit-Failure -Code 1 -Message ('ODT removal timed out after {0} seconds.' -f $script:TimeoutSeconds) -Category 'App'
        }

        $exitCode = [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    if ($script:SuccessExitCodes -notcontains $exitCode) {
        Exit-Failure -Code $exitCode -Message ('ODT removal exited with unexpected code {0}. Review ODT logs in C:\IntuneAppLogs.' -f $exitCode) -Category 'App'
    }

    Remove-PDQPayloadStage
    exit $exitCode
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category 'System'
}
