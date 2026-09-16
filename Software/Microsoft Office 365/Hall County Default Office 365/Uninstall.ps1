#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstalls Microsoft Office 365 (M365 Apps for Enterprise) via the Office Deployment Tool.

.DESCRIPTION
    Runs the bundled ODT setup.exe with Remove-C2R-All.xml to remove all Click-to-Run
    Office products from the device. Propagates ODT exit codes to Intune.

    Exits 0 on clean removal. Exits 3010/1641 if ODT signals a reboot is required.
    Exits the ODT exit code on any unexpected failure.

    Logs errors to C:\IntuneAppLogs\Office365_Uninstall.txt.
    ODT also writes its own diagnostic logs to C:\IntuneAppLogs via the Logging element
    in Remove-C2R-All.xml.

.NOTES
    Version:        1.5.2
    Script Type:    Microsoft Intune Win32 App (Uninstall)
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
#>

#region ========================= CONFIGURATION =========================

$script:AppName     = 'Office 365'
$script:AppVersion  = '1.5.2'
$script:LogRoot     = 'C:\IntuneAppLogs'
$script:LogFileName = 'Office365_Uninstall.txt'
$script:SetupExe    = 'setup.exe'
$script:RemoveXml   = 'Remove-C2R-All.xml'

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
    # $Category valid values: App, System, Network, Permissions, Intune
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
        $line      = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try { [Console]::Error.WriteLine('{0} uninstall log failed: {1}' -f $script:AppName, $Message) } catch { }
    }
}


function Exit-Failure {
    # Simple function -- no [Parameter()] attributes. See Write-ErrorLog for rationale.
    # $Category valid values: App, System, Network, Permissions, Intune
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

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


# ==========================================================================
# MAIN
# ==========================================================================

try {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot }
                  elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { [System.IO.Path]::GetDirectoryName($PSCommandPath) }
                  else { $null }

    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Exit-Failure -Code 1 -Message 'Cannot resolve script directory. Run as a saved .ps1 file from disk.' -Category 'Intune'
    }

    $setupPath  = Join-Path -Path $scriptRoot -ChildPath $script:SetupExe
    $xmlPath    = Join-Path -Path $scriptRoot -ChildPath $script:RemoveXml

    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('setup.exe not found at ''{0}''. Verify the package.' -f $setupPath) -Category 'Intune'
    }

    if (-not (Test-Path -LiteralPath $xmlPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Remove-C2R-All.xml not found at ''{0}''. Verify the package.' -f $xmlPath) -Category 'Intune'
    }

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
    $startInfo.WorkingDirectory = $scriptRoot
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

    exit $exitCode
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category 'System'
}
