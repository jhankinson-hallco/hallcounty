#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune Win32 MSI installer for RingCentral desktop application (machine-wide, device context).

.DESCRIPTION
    Runs in System context (Intune install behavior: System), assigned to a Device group as
    Required so it also runs during White Glove / Autopilot technician phase pre-login.
    The bundled RingCentral MSI is a machine-wide installer (APPLICATIONFOLDER = C:\Program Files\RingCentral\)
    that requires admin privileges. This script calls msiexec.exe directly as SYSTEM. No user-resolution,
    staged MSI, scheduled task, or logged-on-user dependency of any kind -- safe before any user signs in.

    After a verified successful install, applies the machine-wide RingCentral firewall
    rule via Set-RingCentralFirewallRules.ps1 (spawned as a separate powershell.exe child process,
    never dot-sourced -- that script ends with top-level exit statements, and dot-sourcing or calling
    it in-process would terminate this script's host process prematurely). Firewall failures fail
    this install script so Intune can retry and the deployed end state includes the machine-wide
    firewall exception.

    Writes a verbose MSI log to C:\IntuneAppLogs\RingCentral_MSI.log on every run.
    Logs script-level errors only to C:\IntuneAppLogs\RingCentral_Install.txt.

.NOTES
    Version:        4.5.0
    Script Type:    Microsoft Intune Win32 App
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  08/04/2026
    Purpose:        Silent, White Glove-safe MSI install of RingCentral desktop application

    CHANGE LOG
    Change: 08/04/2026 - Initial release (EXE-based) -- ver. 1.0.0
    Change: 09/04/2026 - Added explicit [Parameter(Mandatory=$false)] to Invoke-InstallerProcess $ArgumentList -- ver. 1.0.1
    Change: 09/04/2026 - Added marker file write on successful install -- ver. 1.0.2
    Change: 28/04/2026 - Replaced EXE installer with RingCentral-x64.msi; adapted execution to msiexec.exe -- ver. 1.1.0
    Change: 28/04/2026 - Switched to User context; RequireAdmin disabled; DetectionPath cleared -- ver. 1.2.0
    Change: 28/04/2026 - Fixed ParameterBindingException: List[string].ToArray() for ArgumentList -- ver. 1.2.1
    Change: 28/04/2026 - Removed ALLUSERS=1; corrected .SYNOPSIS/.DESCRIPTION for User context -- ver. 1.2.2
    Change: 28/04/2026 - Fixed ParameterBindingException: explicit [string[]] variable before call -- ver. 1.2.3
    Change: 28/04/2026 - Added [CmdletBinding()] to Invoke-InstallerProcess; replaced named-parameter call with splatting -- ver. 1.2.4
    Change: 28/04/2026 - Eliminated Invoke-InstallerProcess wrapper; inlined System.Diagnostics.Process in MAIN; added [CmdletBinding()] to all helper functions -- ver. 1.3.0
    Change: 28/04/2026 - Corrected DetectionPath to %LOCALAPPDATA%\Programs\RingCentral\RingCentral.exe -- ver. 1.3.1
    Change: 28/04/2026 - Switched to System context; per-user install via scheduled task running as the logged-on user; WMI/ProfileList user resolution -- ver. 2.0.0
    Change: 28/04/2026 - MSI verbose log; task name unique per PID; ACL rules via SID S-1-5-32-545; log dir granted Users write access -- ver. 2.0.1
    Change: 28/04/2026 - MSI log confirmed machine-wide install (APPLICATIONFOLDER = C:\Program Files\RingCentral\); eliminated scheduled-task/user-resolution approach entirely; direct msiexec as SYSTEM; detection updated to machine-level path -- ver. 3.0.0
    Change: 28/04/2026 - Replaced Split-Path -LiteralPath/-Parent with .NET path resolution for PowerShell 5.1 parameter-set compatibility -- ver. 3.0.1
    Change: 07/07/2026 - Relocated from "RingCentral User" to "RingCentral System" (script was already a device-context
                         machine-wide installer despite its folder/filename; folder no longer matches contents).
                         Renamed from Install-RingCentral-User.ps1 to Install-RingCentral.ps1. Added explicit
                         Test-IsAdministrator elevation check so a misconfigured User-context assignment fails fast
                         with a clear message instead of an opaque msiexec permission error -- this is the concrete
                         White Glove risk: a User-targeted "Available" Company Portal assignment would never run
                         during the pre-login technician phase, and would fail unclearly if forced. Folded in a
                         best-effort call to the trimmed, system-wide-only Set-RingCentralFirewallRules.ps1 as a
                         separate child process after verified install -- ver. 4.0.0
    Change: 07/07/2026 - Codex audit: made the firewall helper required for install success and run it
                         even when RingCentral is already installed, so Intune can converge to the
                         requested machine-wide app plus firewall-rule end state -- ver. 4.1.0
    Change: 07/07/2026 - Codex audit remediation: require installed RingCentral version 26.2.3013.1602
                         or newer before skipping MSI, and guard InvocationInfo access in error
                         summaries -- ver. 4.2.0
    Change: 07/07/2026 - Audit follow-up: raised FirewallTimeoutSeconds from 60 to 180. A required
                         (non-optional) firewall step spawning a brand-new child powershell.exe with
                         NetSecurity module autoload and CIM/WMI queries is a documented slow path,
                         and White Glove/Autopilot commonly runs several Win32 app installs
                         concurrently under real CPU/disk contention -- 60s left too little margin
                         before a working install got reported as a hard failure. 900 + 180 = 1080s
                         total worst case, still under IME's 1200s hard kill with margin. Added
                         cross-reference comments next to the version-check helpers and
                         RequiredProductVersion, since Detect.ps1 duplicates them verbatim and must
                         stay in sync -- Detect.ps1 cannot dot-source this file because Intune custom
                         detection only accepts a single self-contained script -- ver. 4.3.0
    Change: 08/07/2026 - Hardened Test-IsAdministrator to explicitly recognize SID S-1-5-18 (SYSTEM)
                         before falling back to WindowsPrincipal.IsInRole(Administrator), matching
                         the pattern already used in Install-RingCentralPDQ-User.ps1 -- strictly safer,
                         can only make elevation detection more permissive for a legitimate SYSTEM
                         context. Added a version marker file
                         (C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt)
                         written on every successful install -- this is what actually forces Intune to
                         reinstall fleet-wide when a new MSI is uploaded under the same package name,
                         since Intune only re-runs install when detection fails, not merely because a
                         new package was uploaded -- ver. 4.4.0
    Change: 08/07/2026 - Codex remediation: changed the marker value to the full MSI-backed version
                         26.2.3013.1602 and replaced fixed installer filename lookup with package
                         MSI discovery. The source folder must contain exactly one .msi file; zero
                         or multiple MSI files fail fast with a clear package-source warning -- ver. 4.5.0
#>

#region ========================= CONFIGURATION =========================

$script:AppName           = 'RingCentral'
$script:AppVersion        = '4.5.0'
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
# /norestart = do not restart; Intune controls restart behavior.
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
# If this file is absent after a reported success, the log entry will explain why Intune
# re-runs the install even after msiexec returned 0.
$script:DetectionPath = 'C:\Program Files\RingCentral\RingCentral.exe'

# Exit codes returned by msiexec.exe that Intune should treat as success.
$script:SuccessExitCodes = @(0, 1707, 3010, 1641)

# Firewall helper: applies the machine-wide inbound allow rule for RingCentral.exe.
# Must be in the same folder as this script. Spawned as a separate process -- see .DESCRIPTION.
# Required end state: a firewall failure fails this install script so Intune retries.
# 180s (not a smaller value): this spawns a brand-new child powershell.exe that must autoload the
# NetSecurity module and run CIM/WMI queries -- a documented slow path -- while White Glove /
# Autopilot commonly runs several Win32 app installs concurrently under real CPU/disk contention.
# 900 (main) + 180 (firewall) = 1080s worst case, still under IME's 1200s hard kill.
$script:FirewallScriptFileName = 'Set-RingCentralFirewallRules.ps1'
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
        $line      = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
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


function Get-PackageMsiPath {
    param(
        [string]$PackageRoot
    )

    if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
        Exit-Failure -Code 1 -Message 'Unable to resolve package source folder for MSI discovery.' -Category 'Intune'
    }

    if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
        Exit-Failure -Code 1 -Message ('Package source folder not found: ''{0}''.' -f $PackageRoot) -Category 'Intune'
    }

    try {
        $msiFiles = @(Get-ChildItem -LiteralPath $PackageRoot -Filter $script:InstallerFilePattern -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer })
    }
    catch {
        Exit-Failure -Code 1 -Message ('Failed to inspect package source folder ''{0}'' for MSI files: {1}' -f $PackageRoot, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'Intune'
    }

    if ($msiFiles.Count -eq 0) {
        Exit-Failure -Code 1 -Message ('No MSI installer was found in package source folder ''{0}''. The RingCentral System package must contain exactly one .msi file.' -f $PackageRoot) -Category 'Intune'
    }

    if ($msiFiles.Count -gt 1) {
        $msiNames = @($msiFiles | Sort-Object Name | ForEach-Object { $_.Name })
        Exit-Failure -Code 1 -Message ('Package source warning: multiple MSI installers were found in ''{0}'': {1}. The RingCentral System package must contain exactly one .msi file; remove extras or package a dedicated source folder.' -f $PackageRoot, ([string]::Join(', ', $msiNames))) -Category 'Intune'
    }

    return $msiFiles[0].FullName
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
        Exit-Failure -Code 1 -Message ('Firewall helper not found at ''{0}''. Verify the package contains ''{1}'' in the same folder as the script.' -f $FirewallScriptPath, $script:FirewallScriptFileName) -Category 'Intune'
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
        Exit-Failure -Code 1 -Message 'Unable to resolve script directory.' -Category 'Intune'
    }

    if (-not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This installer requires an elevated/SYSTEM token. In Intune, this app must use Install Behavior = System and be assigned to a Device group as Required. A User-targeted or non-elevated assignment will not run during White Glove / Autopilot technician phase and is not supported by this script.' -Category 'Permissions'
    }

    if (-not [Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message 'This installer must run in 64-bit Windows PowerShell. In Intune, use %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe in the install command.' -Category 'Intune'
    }

    $installerPath = Get-PackageMsiPath -PackageRoot $PSScriptRoot
    $firewallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath $script:FirewallScriptFileName

    if (-not (Test-Path -LiteralPath $firewallScriptPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Firewall helper not found at ''{0}''. Verify the package contains ''{1}'' in the same folder as the script.' -f $firewallScriptPath, $script:FirewallScriptFileName) -Category 'Intune'
    }

    # If the required or newer RingCentral version is already present, still enforce
    # the firewall end state. Older versions must run through the MSI upgrade path.
    if (Test-RingCentralInstalledVersionAtLeast -Path $script:DetectionPath -MinimumVersion $script:RequiredProductVersion) {
        Confirm-RingCentralEndState -FirewallScriptPath $firewallScriptPath
        exit 0
    }

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
        Exit-Failure -Code 1 -Message ('msiexec.exe failed: {0}. Check RingCentral_MSI.log.' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
    }

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

    exit $exitCode
}
catch {
    $summary  = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
