#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: installs RingCentral desktop application machine-wide.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-RingCentral.ps1 (v4.5.0). Pulls the RingCentral MSI from the shared
    deployment repository on the filestore instead of a bundled Intune package.

    The MSI is a machine-wide installer (APPLICATIONFOLDER = C:\Program Files\RingCentral\)
    that requires admin privileges. This script copies the MSI from the filestore to a
    local ProgramData staging folder, calls msiexec.exe against the local MSI, then
    removes the staged MSI. No user-resolution, scheduled task, or logged-on-user
    dependency is used.

    After a verified successful install, applies the machine-wide RingCentral firewall
    rule via Set-RingCentralFirewallRules-PDQ.ps1 (spawned as a separate powershell.exe
    child process, never dot-sourced). Firewall failures fail this install script so
    PDQ reports failure and the deployed end state includes the machine-wide firewall
    exception.

    TANDEM PARITY: the final device state must satisfy the Intune Detect.ps1 script:
      - C:\Program Files\RingCentral\RingCentral.exe version 26.2.3013.1602 or newer
      - machine-wide firewall rule "Hall County RingCentral - Machine"
      - C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt
        containing exactly 26.2.3013.1602

    Writes a verbose MSI log to C:\IntuneAppLogs\RingCentral_MSI.log on every run.
    Logs script-level errors only to C:\IntuneAppLogs\RingCentral_Install.txt
    (same path as Intune; PDQ entries are tagged [PDQ]).

.NOTES
    Version:        1.0.1
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/07/2026
    Purpose:        Silent PDQ MSI install of RingCentral desktop application

    CHANGE LOG
    Change: 14/07/2026 - Moved MSI staging folder from legacy C:\ProgramData\HallCountyMIS root to the IME-rooted ScriptFiles path per current environment standard -- ver. 1.0.1
    Change: 14/07/2026 - Initial PDQ release, tandem with Intune Install-RingCentral.ps1 v4.5.0 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step 1: PowerShell step running Install-RingCentralSystem-PDQ.ps1
      Extra file:     Set-RingCentralFirewallRules-PDQ.ps1 must be available beside this script
      Run As:         Deploy User (requires READ access to the filestore repository and local admin rights)
      Success codes:  0, 1707, 3010, 1641

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      MSI folder: \\hallcounty\filestore\mis\CDS\Intune Management Applications\RingCentral
#>

#region ========================= CONFIGURATION =========================

$script:AppName           = 'RingCentral'
$script:AppVersion        = '1.0.1'
$script:RepositoryRoot    = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\RingCentral'

# Local MSI staging folder. IME-rooted ScriptFiles is the current standard for
# script-created runtime files (C:\ProgramData\HallCountyMIS is a legacy root).
# The staged MSI is removed after the install attempt; the folder itself is
# removed too when empty, leaving only the standard ScriptFiles parent.
$script:StageRoot         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\RingCentralPDQ'
$script:InstallerFilePattern = '*.msi'

# Must match Detect.ps1's $script:RequiredProductVersion exactly. Detect.ps1 cannot dot-source
# this file -- Intune custom detection only accepts a single self-contained script -- so this
# value, and the ConvertTo-VersionOrNull / Get-RingCentralInstalledVersion /
# Test-RingCentralInstalledVersionAtLeast functions below, are deliberately duplicated there.
# Update both files together whenever the RingCentral MSI is replaced.
$script:RequiredProductVersion = '26.2.3013.1602'

# Version marker: a simple, human-readable version stamp independent of the MSI's own embedded
# FileVersionInfo. Detect.ps1 requires this file to exist AND contain exactly this text, as an
# additional AND condition alongside the real executable/version/firewall checks above. This is
# what actually forces Intune to reinstall on already-"detected" devices when a new MSI is
# uploaded under the same package name -- Intune only re-runs install when detection fails, so a
# version bump here (kept in sync with Detect.ps1's copy) is what flips detection to "not
# installed" fleet-wide. Must match Detect.ps1's $script:RequiredMarkerVersion and
# $script:VersionMarkerPath exactly -- same duplication constraint as RequiredProductVersion above.
$script:VersionMarkerPath      = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt'
$script:RequiredMarkerVersion  = '26.2.3013.1602'

# Arguments passed to msiexec.exe after /i "<path>".
# /qn        = no UI (silent install).
# /norestart = do not restart; PDQ controls restart behavior.
$script:MsiArguments = @('/qn', '/norestart')

# Script error log (written only on failure).
$script:LogRoot     = 'C:\IntuneAppLogs'
$script:LogFileName = ((($script:AppName -replace '[\\/:*?"<>|]', '_').Trim()) + '_Install.txt')

# MSI verbose log (written on every run -- use this first when diagnosing install failures).
$script:MsiLogFileName = 'RingCentral_MSI.log'

# Maximum seconds to wait for msiexec.exe before forcibly terminating it.
# Keep below IME's 20-minute hard kill (1200 seconds).
$script:TimeoutSeconds = 900

# Post-install verification path. Machine-wide install location confirmed from MSI log.
# If this file is absent after a reported success, the log entry will explain why
# detection will not accept the install even after msiexec returned 0.
$script:DetectionPath = 'C:\Program Files\RingCentral\RingCentral.exe'

# Exit codes returned by msiexec.exe that this PDQ wrapper treats as success.
$script:SuccessExitCodes = @(0, 1707, 3010, 1641)

# Firewall helper: applies the machine-wide inbound allow rule for RingCentral.exe.
# Must be in the same folder as this script. Spawned as a separate process -- see .DESCRIPTION.
# Required end state: a firewall failure fails this install script so PDQ reports failure.
# 180s (not a smaller value): this spawns a brand-new child powershell.exe that must autoload the
# NetSecurity module and run CIM/WMI queries -- a documented slow path -- while White Glove /
# Autopilot commonly runs several Win32 app installs concurrently under real CPU/disk contention.
# 900 (main) + 180 (firewall) = 1080s worst case, still under IME's 1200s hard kill.
$script:FirewallScriptFileName = 'Set-RingCentralFirewallRules-PDQ.ps1'
$script:FirewallTimeoutSeconds = 180

#endregion =============================================================


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


function Write-ErrorLog {
    param(
        [string]$Message,

        [string]$Category = 'App'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        $logPath   = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line      = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try { [Console]::Error.WriteLine('{0} - logging failed: {1}' -f $script:AppName, $Message) } catch { }
    }
}


function Exit-Failure {
    param(
        [int]$Code,

        [string]$Message,

        [string]$Category = 'App'
    )

    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}


function Get-RepositoryMsiPath {
    param(
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Exit-Failure -Code 1 -Message 'Unable to resolve RingCentral repository folder for MSI discovery.' -Category 'PDQ'
    }

    if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
        Exit-Failure -Code 1 -Message ('RingCentral repository folder not found or not reachable: ''{0}''. Verify the PDQ deploy user can read the filestore path.' -f $RepositoryRoot) -Category 'Network'
    }

    try {
        $msiFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Filter $script:InstallerFilePattern -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer })
    }
    catch {
        Exit-Failure -Code 1 -Message ('Failed to inspect RingCentral repository folder ''{0}'' for MSI files: {1}' -f $RepositoryRoot, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'Network'
    }

    if ($msiFiles.Count -eq 0) {
        Exit-Failure -Code 1 -Message ('No MSI installer was found in RingCentral repository folder ''{0}''. The repository must contain exactly one direct-child .msi file for this PDQ package.' -f $RepositoryRoot) -Category 'Network'
    }

    if ($msiFiles.Count -gt 1) {
        $msiNames = @($msiFiles | Sort-Object Name | ForEach-Object { $_.Name })
        Exit-Failure -Code 1 -Message ('Repository warning: multiple MSI installers were found in ''{0}'': {1}. The RingCentral PDQ repository folder must contain exactly one direct-child .msi file.' -f $RepositoryRoot, ([string]::Join(', ', $msiNames))) -Category 'Network'
    }

    return $msiFiles[0].FullName
}


function Copy-MsiToLocalStage {
    param(
        [string]$SourceMsiPath
    )

    if ([string]::IsNullOrWhiteSpace($SourceMsiPath)) {
        Exit-Failure -Code 1 -Message 'Source MSI path is blank.' -Category 'PDQ'
    }

    if (-not (Test-Path -LiteralPath $SourceMsiPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Source MSI not found or not reachable: ''{0}''.' -f $SourceMsiPath) -Category 'Network'
    }

    try {
        [void][System.IO.Directory]::CreateDirectory($script:StageRoot)
    }
    catch {
        Exit-Failure -Code 1 -Message ('Failed to create local MSI staging folder ''{0}'': {1}' -f $script:StageRoot, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'Permissions'
    }

    $stagedMsiPath = Join-Path -Path $script:StageRoot -ChildPath ([System.IO.Path]::GetFileName($SourceMsiPath))

    try {
        Copy-Item -LiteralPath $SourceMsiPath -Destination $stagedMsiPath -Force -ErrorAction Stop
    }
    catch {
        Exit-Failure -Code 1 -Message ('Failed to copy RingCentral MSI from repository to local stage. Source=''{0}'' Destination=''{1}'' Error={2}' -f $SourceMsiPath, $stagedMsiPath, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'Network'
    }

    if (-not (Test-Path -LiteralPath $stagedMsiPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Local MSI staging verification failed. File not found at ''{0}'' after copy.' -f $stagedMsiPath) -Category 'System'
    }

    return $stagedMsiPath
}


function Remove-StagedMsi {
    param(
        [string]$StagedMsiPath
    )

    if ([string]::IsNullOrWhiteSpace($StagedMsiPath)) {
        return
    }

    try {
        if (Test-Path -LiteralPath $StagedMsiPath -PathType Leaf) {
            Remove-Item -LiteralPath $StagedMsiPath -Force -ErrorAction Stop
        }

        if (Test-Path -LiteralPath $script:StageRoot -PathType Container) {
            $remainingItems = @(Get-ChildItem -LiteralPath $script:StageRoot -Force -ErrorAction SilentlyContinue)
            if ($remainingItems.Count -eq 0) {
                Remove-Item -LiteralPath $script:StageRoot -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-ErrorLog -Message ('Failed to remove staged MSI ''{0}'': {1}' -f $StagedMsiPath, $_.Exception.Message) -Category 'System'
    }
}


function Get-ExceptionSummary {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $ex    = $ErrorRecord.Exception

    while ($null -ne $ex) {
        $msg = $ex.Message
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = '(no message)' }
        else { $msg = ($msg -replace '(\r\n|\n|\r)+', ' ').Trim() }
        [void]$parts.Add(('{0}: {1}' -f $ex.GetType().FullName, $msg))
        $ex = $ex.InnerException
    }

    if ($null -ne $ErrorRecord.InvocationInfo) {
        if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
            [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
        }

        if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.Line)) {
            [void]$parts.Add(('Command: {0}' -f ($ErrorRecord.InvocationInfo.Line -replace '(\r\n|\n|\r)+', ' ').Trim()))
        }
    }

    return ($parts -join ' | ')
}


# ConvertTo-VersionOrNull / Get-RingCentralInstalledVersion / Test-RingCentralInstalledVersionAtLeast
# are duplicated verbatim in Detect.ps1 (Detect.ps1 cannot dot-source this file -- Intune custom
# detection only accepts a single self-contained script). Keep both copies identical.
function ConvertTo-VersionOrNull {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $match = [regex]::Match($Value, '\d+(\.\d+){1,3}')
    if (-not $match.Success) {
        return $null
    }

    try { return (New-Object System.Version($match.Value)) }
    catch { return $null }
}


function Get-RingCentralInstalledVersion {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop

        $productVersion = ConvertTo-VersionOrNull -Value ([string]$item.VersionInfo.ProductVersion)
        if ($null -ne $productVersion) {
            return $productVersion
        }

        return (ConvertTo-VersionOrNull -Value ([string]$item.VersionInfo.FileVersion))
    }
    catch {
        return $null
    }
}


function Test-RingCentralInstalledVersionAtLeast {
    param(
        [string]$Path,

        [string]$MinimumVersion
    )

    $installedVersion = Get-RingCentralInstalledVersion -Path $Path
    $minimum = ConvertTo-VersionOrNull -Value $MinimumVersion

    if ($null -eq $installedVersion -or $null -eq $minimum) {
        return $false
    }

    return ($installedVersion -ge $minimum)
}


function Get-ExceptionCategory {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $ex = $ErrorRecord.Exception

    while ($null -ne $ex) {
        $type = $ex.GetType().FullName
        $msg  = $ex.Message

        if (($ex -is [System.UnauthorizedAccessException]) -or ($type -match 'Security') -or
            ($msg -match 'access is denied|access denied|access to the path .* is denied|cannot access the file|permission')) {
            return 'Permissions'
        }

        if (($ex -is [System.Net.WebException]) -or ($ex -is [System.Net.Sockets.SocketException]) -or
            ($type -match 'WebException|SocketException') -or
            ($msg -match 'network path was not found|network name cannot be found|remote name could not be resolved|rpc server is unavailable')) {
            return 'Network'
        }

        $ex = $ex.InnerException
    }

    return 'System'
}


function Get-ExitCodeDescription {
    param(
        [int]$ExitCode
    )

    switch ($ExitCode) {
        0    { return 'Success.' }
        1707 { return 'Installation operation completed successfully.' }
        3010 { return 'Success. Reboot required.' }
        1641 { return 'Success. Installer initiated reboot.' }
        1601 { return 'Windows Installer service could not be accessed.' }
        1603 { return 'Fatal error during installation.' }
        1618 { return 'Another installation is already in progress.' }
        1619 { return 'Installation package could not be opened.' }
        1620 { return 'Installation package is invalid.' }
        1638 { return 'Another version of this product is already installed.' }
        default { return '' }
    }
}


function Stop-ProcessTree {
    param(
        [int]$ProcessId
    )

    $taskKillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'

    if (Test-Path -LiteralPath $taskKillPath -PathType Leaf) {
        try {
            $null = & $taskKillPath /PID $ProcessId /T /F 2>&1
            if ($LASTEXITCODE -in @(0, 128)) { return }
        }
        catch { }
    }

    try {
        $proc = [System.Diagnostics.Process]::GetProcessById($ProcessId)
        try { $proc.Kill(); $null = $proc.WaitForExit(5000) }
        finally { $proc.Dispose() }
    }
    catch { }
}


function Invoke-ChildProcess {
    <#
        Shared launcher for both msiexec.exe and the firewall helper. Runs a real child process
        (never dot-sourced), waits up to TimeoutSeconds, and force-terminates the process tree on
        timeout. Returns the child exit code; throws on Start() failure or timeout.
    #>
    param(
        [string]$FilePath,

        [string]$Arguments,

        [int]$TimeoutSeconds
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName         = $FilePath
    $startInfo.Arguments        = $Arguments
    $startInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($FilePath)
    $startInfo.UseShellExecute  = $false
    $startInfo.CreateNoWindow   = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()

        if (-not $started) {
            throw ('Process.Start() returned False for ''{0}'' without throwing -- unexpected.' -f $FilePath)
        }

        $hasExited = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $hasExited) {
            try { Stop-ProcessTree -ProcessId $process.Id } catch { $null = $_ }
            try { $null = $process.WaitForExit(5000) } catch { }
            throw ('''{0}'' timed out after {1} seconds and was terminated.' -f $FilePath, $TimeoutSeconds)
        }

        return [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}


function Invoke-RingCentralFirewallHelper {
    param(
        [string]$FirewallScriptPath
    )

    if (-not (Test-Path -LiteralPath $FirewallScriptPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Firewall helper not found at ''{0}''. Verify the PDQ package includes ''{1}'' beside this script.' -f $FirewallScriptPath, $script:FirewallScriptFileName) -Category 'PDQ'
    }

    $childPowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $firewallArguments   = '-ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File "{0}"' -f $FirewallScriptPath

    try {
        $firewallExitCode = Invoke-ChildProcess -FilePath $childPowerShellPath -Arguments $firewallArguments -TimeoutSeconds $script:FirewallTimeoutSeconds
    }
    catch {
        Exit-Failure -Code 1 -Message ('Firewall helper failed: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
    }

    if ($firewallExitCode -ne 0) {
        Exit-Failure -Code 1 -Message ('Firewall helper exited with code {0}. The RingCentral app install may be present, but the required machine-wide firewall rule was not confirmed.' -f $firewallExitCode) -Category 'System'
    }
}


function Set-VersionMarker {
    <#
        Writes the plain version stamp Detect.ps1 requires as its marker AND condition. Content is
        exactly $script:RequiredMarkerVersion -- no extra formatting, no trailing newline -- so it
        stays a simple, human-readable text file per its documented purpose.
    #>
    param(
        [string]$Path,
        [string]$Version
    )

    $markerDirectory = [System.IO.Path]::GetDirectoryName($Path)
    [void][System.IO.Directory]::CreateDirectory($markerDirectory)

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Version, $utf8NoBom)
}


function Confirm-RingCentralEndState {
    <#
        Runs after every successful install path (fresh MSI install or the already-satisfied
        fast path): confirms the firewall rule, then writes the version marker. Marker write
        failure is a hard failure, not best-effort -- without it, Detect.ps1's marker AND
        condition would never be satisfied and Intune would retry this install forever with no
        clear signal why.
    #>
    param(
        [string]$FirewallScriptPath
    )

    Invoke-RingCentralFirewallHelper -FirewallScriptPath $FirewallScriptPath

    try {
        Set-VersionMarker -Path $script:VersionMarkerPath -Version $script:RequiredMarkerVersion
    }
    catch {
        Exit-Failure -Code 1 -Message ('Failed to write version marker to ''{0}'': {1}' -f $script:VersionMarkerPath, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
    }
}


# =========================
# MAIN
# =========================
try {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        Exit-Failure -Code 1 -Message 'Unable to resolve PDQ script directory.' -Category 'PDQ'
    }

    if (-not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This installer requires an elevated administrative token. In PDQ, run the package as the Deploy User with local administrator rights and read access to the RingCentral filestore repository.' -Category 'Permissions'
    }

    if (-not [Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message 'This installer must run in 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -Category 'PDQ'
    }

    $firewallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath $script:FirewallScriptFileName

    if (-not (Test-Path -LiteralPath $firewallScriptPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Firewall helper not found at ''{0}''. Verify the PDQ package includes ''{1}'' beside this script.' -f $firewallScriptPath, $script:FirewallScriptFileName) -Category 'PDQ'
    }

    # If the required or newer RingCentral version is already present, still enforce
    # the firewall end state. Older versions must run through the MSI upgrade path.
    if (Test-RingCentralInstalledVersionAtLeast -Path $script:DetectionPath -MinimumVersion $script:RequiredProductVersion) {
        Confirm-RingCentralEndState -FirewallScriptPath $firewallScriptPath
        Write-Output ('{0} {1} or newer already installed; firewall rule and Intune parity marker confirmed by PDQ.' -f $script:AppName, $script:RequiredProductVersion)
        exit 0
    }

    $sourceInstallerPath = Get-RepositoryMsiPath -RepositoryRoot $script:RepositoryRoot
    $installerPath = Copy-MsiToLocalStage -SourceMsiPath $sourceInstallerPath

    # Ensure the log directory exists so the MSI verbose log has a place to write.
    [void][System.IO.Directory]::CreateDirectory($script:LogRoot)

    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $msiLogPath  = Join-Path -Path $script:LogRoot -ChildPath $script:MsiLogFileName

    # Build the argument string directly. No wrapper function -- avoids PS 5.1 parameter
    # binder issues that caused repeated ParameterBindingExceptions in earlier versions.
    $msiArgParts = New-Object 'System.Collections.Generic.List[string]'
    [void]$msiArgParts.Add('/i')
    [void]$msiArgParts.Add('"{0}"' -f $installerPath)
    foreach ($arg in $script:MsiArguments) { [void]$msiArgParts.Add($arg) }
    [void]$msiArgParts.Add('/L*v')
    [void]$msiArgParts.Add('"{0}"' -f $msiLogPath)
    $msiArgumentString = [string]::Join(' ', $msiArgParts.ToArray())

    $exitCode = 0

    try {
        $exitCode = Invoke-ChildProcess -FilePath $msiexecPath -Arguments $msiArgumentString -TimeoutSeconds $script:TimeoutSeconds
    }
    catch {
        Remove-StagedMsi -StagedMsiPath $installerPath
        Exit-Failure -Code 1 -Message ('msiexec.exe failed: {0}. Check RingCentral_MSI.log.' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
    }

    Remove-StagedMsi -StagedMsiPath $installerPath

    if ($script:SuccessExitCodes -notcontains $exitCode) {
        $description = Get-ExitCodeDescription -ExitCode $exitCode
        $message     = '{0} installer returned exit code {1}. Check RingCentral_MSI.log for detail.' -f $script:AppName, $exitCode

        if (-not [string]::IsNullOrWhiteSpace($description)) {
            $message = '{0} {1}' -f $message, $description
        }

        Exit-Failure -Code $exitCode -Message $message -Category 'App'
    }

    # Belt-and-suspenders: verify the exe exists even though msiexec reported success.
    # A missing exe after a 0 exit means the package deployed files to an unexpected path.
    if (-not (Test-Path -LiteralPath $script:DetectionPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('{0} installer exited {1} but executable was not found at ''{2}''. Check RingCentral_MSI.log for the actual install path.' -f $script:AppName, $exitCode, $script:DetectionPath) -Category 'App'
    }

    if (-not (Test-RingCentralInstalledVersionAtLeast -Path $script:DetectionPath -MinimumVersion $script:RequiredProductVersion)) {
        $installedVersion = Get-RingCentralInstalledVersion -Path $script:DetectionPath
        $versionText = 'unknown'
        if ($null -ne $installedVersion) { $versionText = [string]$installedVersion }
        Exit-Failure -Code 1 -Message ('{0} installer exited {1}, but installed version ''{2}'' is lower than required version ''{3}''.' -f $script:AppName, $exitCode, $versionText, $script:RequiredProductVersion) -Category 'App'
    }

    # Required machine-wide firewall rule, then the version marker. The firewall helper is
    # spawned as a separate powershell.exe process -- NOT dot-sourced and NOT called with '&'
    # in-process, because the helper script ends with top-level exit statements that would
    # otherwise terminate this process early.
    Confirm-RingCentralEndState -FirewallScriptPath $firewallScriptPath

    Write-Output ('{0} {1} deployed by PDQ. ExitCode={2}; Marker={3}; FirewallRule={4}.' -f $script:AppName, $script:RequiredMarkerVersion, $exitCode, $script:VersionMarkerPath, 'Hall County RingCentral - Machine')

    exit $exitCode
}
catch {
    $summary  = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
