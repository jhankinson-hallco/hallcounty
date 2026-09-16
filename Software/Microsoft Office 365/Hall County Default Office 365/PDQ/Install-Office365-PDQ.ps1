#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: installs Microsoft Office 365 (M365 Apps for Enterprise) via the Office Deployment Tool.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-Office365.ps1 (v1.5.2).

    Pulls only the Office Deployment Tool setup.exe and
    HallCounty-Default-Office-Config.xml from the shared filestore repository,
    stages them locally, and then runs setup.exe from the local staged folder.
    Intended to run after the M365 Pre-Cleanup package has completed, ensuring
    no legacy or conflicting Office installation remains before provisioning begins.

    - Runs setup.exe /configure with the staged XML in administrative context.
    - Uses System.Diagnostics.Process for explicit timeout control and best-effort
      process-tree termination.
    - Logs only on error to C:\IntuneAppLogs. ODT also writes its own diagnostic
      logs to C:\IntuneAppLogs via the Logging element in the XML. PDQ entries
      are tagged [PDQ].
    - After a successful (non-reboot) ODT exit, performs two post-install checks:
        1. WINWORD.EXE must exist at the expected Program Files path.
        2. HKLM ClickToRun Configuration\ProductReleaseIds must contain
           O365ProPlusRetail - confirming an ODT-managed C2R install registered
           the expected product, not merely that a Word binary is present on disk.

    TANDEM PARITY: the installed Office footprint and detection state are intended
    to be indistinguishable from the Intune deployment. Any install, detection,
    XML, or logging-path change must be evaluated against BOTH deployment channels.

.NOTES
    Version:        1.0.2
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  08/04/2026
    Purpose:        Silent install of Microsoft Office 365 via ODT configuration

    CHANGE LOG
    Change: 08/04/2026 - Initial release -- ver. 1.0.0
    Change: 09/04/2026 - Added explicit [Parameter(Mandatory=$false)] to Invoke-InstallerProcess
                         $ArgumentList to resolve ParameterBindingException under 32-bit IME
                         context (P22) -- ver. 1.0.1
    Change: 14/04/2026 - Fixed TimeoutSeconds validation ceiling: template guard of 1199 was
                         correct for general EXE installers but ODT requires up to 55 min for
                         download+install; ceiling raised to 3599 and value set to 3300 (55 min);
                         set DetectionPath to WINWORD.EXE for post-install file verification;
                         updated synopsis and description to be Office-specific -- ver. 1.1.0
    Change: 14/04/2026 - Added ConfigXmlFileName config variable and pre-launch XML existence
                         check (missing XML now fails fast with a clean error instead of an
                         ODT runtime failure); set SkipInstallIfAlreadyDetected to $false so
                         ODT always runs on re-invocation (DetectionPath is now post-install
                         verification only, not a skip trigger - prevents false-clean-success
                         on partial prior installs); pre-create C:\IntuneAppLogs before ODT
                         launch so diagnostic output is guaranteed even on clean runs; added
                         explicit .NOTES entry documenting portal-side detection design -- ver. 1.2.0
    Change: 14/04/2026 - Quoted XML path argument passed to ODT (paths with spaces were
                         split by Join-InstallerArguments - ODT received a broken path on
                         staging locations under Program Files); added ConfigXmlFileName
                         leaf-name and .xml extension validation in Test-Configuration;
                         post-install verification extended with ClickToRun registry check
                         (ProductReleaseIds must contain O365ProPlusRetail) in addition to
                         WINWORD.EXE file check; Write-ErrorLog updated to explicit
                         folder-create / file-create / append pattern per logging standard
                         -- ver. 1.3.0
    Change: 14/04/2026 - Replaced portal-side file-only detection guidance with bundled
                         Detect.ps1 (WINWORD.EXE file check + ClickToRun ProductReleaseIds
                         registry check); native file-only rule cannot perform substring match
                         on ProductReleaseIds for multi-product installs; updated .DESCRIPTION
                         and config comments to reflect dual-check post-install verification
                         -- ver. 1.4.0
    Change: 14/04/2026 - Added 64-bit process guard at start of MAIN (same pattern as
                         Remove-Office365.ps1); 32-bit host silently redirects the
                         ClickToRun registry path causing post-install verification to
                         false-fail on a good install; added cross-reference comments to
                         DetectionPath, C2RConfigKey, and RequiredProductId config variables
                         noting they must stay in sync with Detect.ps1 -- ver. 1.5.0
    Change: 17/04/2026 - Converted all helper functions to simple functions (removed all
                         [Parameter()] and [ValidateSet()] attributes from ConvertTo-
                         SafeFileNameComponent, Test-IsValidLeafFileName, Test-IsLikelyAbsolute-
                         FilePath, Write-ErrorLog, Exit-Failure, Get-ExceptionSummary,
                         Get-ExceptionCategory, Get-ExitCodeDescription, Stop-ProcessTree,
                         Invoke-InstallerProcess). PS 5.1 advanced-function parameter-set
                         resolution produced ParameterBindingException in IME/SYSTEM context;
                         same failure class already confirmed on Remove-Office365.ps1 side.
                         Replaced all em-dashes with ASCII hyphens; scripts re-saved as
                         UTF-8 with BOM to prevent PS 5.1 ANSI misread of non-ASCII -- ver. 1.5.1
    Change: 17/04/2026 - Replaced Split-Path -LiteralPath ... -Parent with
                         [System.IO.Path]::GetDirectoryName() in Get-ScriptRoot and
                         Invoke-InstallerProcess. Split-Path -LiteralPath with -Parent throws
                         ParameterBindingException in PS 5.1 under IME/SYSTEM context --
                         same failure class confirmed in Remove-Office365.ps1 v1.5.7 -- ver. 1.5.2
    Change: 15/07/2026 - Initial PDQ release. Payload now stages setup.exe and
                         HallCounty-Default-Office-Config.xml from the shared
                         filestore repository before executing locally; logs are
                         tagged [PDQ]; tandem with Intune Install-Office365.ps1
                         v1.5.2 -- ver. 1.0.0
    Change: 15/07/2026 - Relabeled remaining 'Intune' log categories to 'PDQ'
                         for correct channel attribution in shared logs -- ver. 1.0.1
    Change: 15/07/2026 - Reworded PDQ timeout comments, hardened the local
                         administrator preflight to explicitly recognize Local
                         System, and logs best-effort payload-stage cleanup
                         warnings -- ver. 1.0.2

    DEPENDENCY
    This app should be deployed with M365 Pre-Cleanup as a required dependency.
    M365 Pre-Cleanup must complete successfully before this install runs.

    PDQ CONFIGURATION
      Package step:  PowerShell step running Install-Office365-PDQ.ps1
      Run As:        Deploy User with local administrator rights and READ access
                     to the filestore repository. Use Local System only if the
                     computer account can read the repository share.
      Success codes: 0, 1707, 3010, 1641

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      Payload: \\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365

    DETECTION
    Intune uses the bundled Detect.ps1 custom detection script. PDQ deployments
    produce the same on-device state that script expects:
      Script file : Detect.ps1
      Run as 32-bit on 64-bit clients : No
      Enforce script signature check  : No

    Detect.ps1 performs the same two checks the install script uses for post-install
    verification:
      1. WINWORD.EXE must exist at the expected Program Files path.
      2. HKLM ClickToRun Configuration\ProductReleaseIds must contain O365ProPlusRetail.

    A native file-only rule on WINWORD.EXE is insufficient for ongoing detection because:
      - It cannot verify the ClickToRun product registration.
      - Intune native registry detection uses exact string comparison; ProductReleaseIds
        can contain multiple space/comma-separated product IDs (e.g., when Visio or
        Project is also installed), so an exact match would false-negative on valid installs.
    The custom script handles the substring match correctly.
#>

#region ========================= CONFIGURATION =========================

# Friendly application name used in messages and logs.
$script:AppName = 'Office 365'

# Script version for log entries.
$script:AppVersion = '1.5.2'

# Installer EXE file name only.
# PDQ stages this file from RepositoryRoot before execution.
$script:InstallerFileName = 'setup.exe'

# ODT configuration XML file name. PDQ stages this file from RepositoryRoot.
# Validated at startup - a missing XML produces a clean preflight error rather
# than an opaque ODT runtime failure.
$script:ConfigXmlFileName = 'HallCounty-Default-Office-Config.xml'

# Shared deployment repository on the filestore (PDQ scripts only).
# PDQ copies only the payload files below to a local stage before execution.
$script:RepositoryRoot = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365'
$script:StageRoot      = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\Office365InstallPDQ'
$script:PayloadStagePath = $null

# Silent install arguments. ConfigXmlFileName is injected at runtime (see MAIN).
# Do not hard-code the XML path here - the script resolves it from $scriptRoot.
$script:InstallArguments = @('/configure')

# Error-only log settings.
$script:LogRoot = 'C:\IntuneAppLogs'

# Leave this derived from AppName unless you explicitly need a different file name.
$script:LogFileName = ((($script:AppName -replace '[\\/:*?"<>|]', '_').Trim()) + '_Install.txt')

# Script-level timeout in seconds for the ODT process.
# ODT downloads and installs Office in the same operation; combined time can
# reach 30-45 minutes on a slow connection. 3300 s (55 min) leaves a 5-min
# buffer inside a bounded deployment run and stays aligned with the Intune
# counterpart's Win32 execution window.
# Must be less than 3600 - see validation in Test-Configuration below.
$script:TimeoutSeconds = 3300

# Require an elevated token.
# Leave $true for most machine-wide installs.
# Set to $false only for genuine per-user installers that are meant to run unelevated.
$script:RequireAdmin = $true

# Installer exit codes to treat as success and pass back to PDQ.
# 0    = success
# 1707 = alternate MSI-layer success
# 3010 = success, reboot required
# 1641 = success, reboot initiated
$script:SuccessExitCodes = @(0, 1707, 3010, 1641)

# Post-install file verification path.
# After a successful (non-reboot) ODT exit, the script first checks this file
# exists, then additionally checks the ClickToRun registry to confirm O365ProPlusRetail
# is registered. Together these prove ODT both wrote the binaries and completed the
# C2R product registration - not merely that a Word binary is present from a prior
# partial install. This must be a full absolute FILE path, not a directory path.
#
# SYNC NOTE: This value must match $script:WordExePath in Detect.ps1.
# If you change this path, update Detect.ps1 to match.
$script:DetectionPath = 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'

# If DetectionPath is set and already exists before install, skip install and exit 0.
# Set to $false for ODT-based installs: ODT is idempotent and exits quickly when
# Office is already installed at the target version. A $true skip on WINWORD.EXE
# would cause false-clean-success if a partial prior install left that binary behind.
$script:SkipInstallIfAlreadyDetected = $false

# When $true, force immediate file verification even when the installer returned
# a reboot-required success code such as 3010 or 1641.
# Leave $false unless you know the target file is guaranteed to exist before reboot.
$script:RequireDetectionOnRebootCodes = $false

#endregion =============================================================


function Get-ScriptRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }

    return $null
}


function ConvertTo-SafeFileNameComponent {
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [string]$Value
    )

    $safeValue = $Value.Trim()

    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeValue = $safeValue.Replace($invalidChar, '_')
    }

    if ([string]::IsNullOrWhiteSpace($safeValue)) {
        return 'Application'
    }

    return $safeValue
}


function Test-IsValidLeafFileName {
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    if ([System.IO.Path]::GetFileName($Value) -ne $Value) {
        return $false
    }

    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        if ($Value.Contains([string]$invalidChar)) {
            return $false
        }
    }

    return $true
}


function Test-IsLikelyAbsoluteFilePath {
    <#
        This is intentionally conservative.

        A Windows path string cannot always be proven to be "a file" purely from syntax,
        especially before the target exists. To prevent silent misconfiguration, this
        validator requires:
          - absolute path
          - not a root path
          - not ending with a directory separator
          - non-empty leaf name
          - valid leaf name
          - a file extension

        That last requirement is deliberate hardening for this template, since the
        intended use is file-based detection such as .exe/.dll/.ocx/.dat/etc.
    #>
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $trimmedPath = $Path.Trim()

    if (-not [System.IO.Path]::IsPathRooted($trimmedPath)) {
        return $false
    }

    if ($trimmedPath.EndsWith('\') -or $trimmedPath.EndsWith('/')) {
        return $false
    }

    $root = [System.IO.Path]::GetPathRoot($trimmedPath)
    if ($trimmedPath -eq $root) {
        return $false
    }

    $leafName = [System.IO.Path]::GetFileName($trimmedPath)
    if (-not (Test-IsValidLeafFileName -Value $leafName)) {
        return $false
    }

    if (-not [System.IO.Path]::HasExtension($trimmedPath)) {
        return $false
    }

    return $true
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


function Join-InstallerArguments {
    param(
        [string[]]$ArgumentList = @()
    )

    if ($null -eq $ArgumentList -or $ArgumentList.Count -eq 0) {
        return ''
    }

    $normalizedArguments = New-Object 'System.Collections.Generic.List[string]'

    foreach ($argument in $ArgumentList) {
        if ($null -eq $argument) {
            throw 'InstallArguments contains a null element.'
        }

        [void]$normalizedArguments.Add([string]$argument)
    }

    return ($normalizedArguments.ToArray() -join ' ')
}


function Get-PDQPayloadFileNames {
    return @(
        $script:InstallerFileName,
        $script:ConfigXmlFileName
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


function Write-ErrorLog {
    <#
        Creates the log folder and file only on error, then appends.
        Explicit folder-create / file-create / append sequence per logging standard.
        Never lets logging failures crash the real installer flow.
        Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
        $Category valid values: App, System, Network, Permissions, Intune, PDQ
    #>
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
        try {
            [Console]::Error.WriteLine('{0} - logging failed: {1}' -f $script:AppName, $Message)
        }
        catch {
            # Intentionally swallowed. Logging failure must never override the real installer result.
        }
    }
}


function Exit-Failure {
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
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
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $currentException = $ErrorRecord.Exception

    while ($null -ne $currentException) {
        $typeName = $currentException.GetType().FullName
        $message = $currentException.Message

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = '(no message provided)'
        }
        else {
            $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
        }

        [void]$parts.Add(('{0}: {1}' -f $typeName, $message))
        $currentException = $currentException.InnerException
    }

    if ($ErrorRecord.InvocationInfo.ScriptLineNumber -gt 0) {
        [void]$parts.Add(('Line: {0}' -f $ErrorRecord.InvocationInfo.ScriptLineNumber))
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.Line)) {
        $failingCommand = ($ErrorRecord.InvocationInfo.Line -replace '(\r\n|\n|\r)+', ' ').Trim()
        [void]$parts.Add(('Command: {0}' -f $failingCommand))
    }

    if (
        ($ErrorRecord.Exception -is [System.ComponentModel.Win32Exception]) -or
        ($ErrorRecord.Exception -is [System.Runtime.InteropServices.COMException])
    ) {
        $hResult = '0x{0:X8}' -f ($ErrorRecord.Exception.HResult -band 0xffffffff)
        [void]$parts.Add(('HResult: {0}' -f $hResult))
    }

    return ($parts -join ' | ')
}


function Get-ExceptionCategory {
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $currentException = $ErrorRecord.Exception

    while ($null -ne $currentException) {
        $typeName = $currentException.GetType().FullName
        $message = $currentException.Message

        if (
            ($currentException -is [System.UnauthorizedAccessException]) -or
            ($typeName -match 'Security') -or
            ($message -match 'access is denied|access denied|access to the path .* is denied|cannot access the file|permission')
        ) {
            return 'Permissions'
        }

        if (
            ($currentException -is [System.Net.WebException]) -or
            ($currentException -is [System.Net.Sockets.SocketException]) -or
            ($typeName -match 'WebException|SocketException') -or
            ($message -match 'network path was not found|network name cannot be found|remote name could not be resolved|name resolution|semaphore timeout period has expired|rpc server is unavailable')
        ) {
            return 'Network'
        }

        $currentException = $currentException.InnerException
    }

    return 'System'
}


function Get-ExitCodeDescription {
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
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
    # Simple function -- no [Parameter()] attributes. See Invoke-InstallerProcess for rationale.
    param(
        [int]$ProcessId
    )

    $taskKillFailure = $null
    $killFailure = $null
    $taskKillPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\taskkill.exe'

    if (Test-Path -LiteralPath $taskKillPath -PathType Leaf) {
        try {
            $null = & $taskKillPath /PID $ProcessId /T /F 2>&1

            if ($LASTEXITCODE -in @(0, 128)) {
                return
            }

            $taskKillFailure = 'taskkill.exe exited with code {0} while terminating PID {1}.' -f $LASTEXITCODE, $ProcessId
        }
        catch {
            $taskKillFailure = 'taskkill.exe failed: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)
        }
    }

    try {
        $process = [System.Diagnostics.Process]::GetProcessById($ProcessId)

        try {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            return
        }
        finally {
            $process.Dispose()
        }
    }
    catch {
        $killFailure = 'Process.Kill() failed: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)
    }

    if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        return
    }

    $failureParts = New-Object 'System.Collections.Generic.List[string]'

    if (-not [string]::IsNullOrWhiteSpace($taskKillFailure)) {
        [void]$failureParts.Add($taskKillFailure)
    }

    if (-not [string]::IsNullOrWhiteSpace($killFailure)) {
        [void]$failureParts.Add($killFailure)
    }

    if ($failureParts.Count -eq 0) {
        [void]$failureParts.Add('Unknown termination failure.')
    }

    throw ('Failed to terminate installer process tree for PID {0}. {1}' -f $ProcessId, ($failureParts -join ' | '))
}


function Invoke-InstallerProcess {
    <#
        Runs an external installer with an explicit timeout. Returns the integer exit code.
        Throws on process launch failure or timeout.

        Implemented as a SIMPLE function (no [CmdletBinding()], no [Parameter()] attributes).
        This bypasses PS 5.1's advanced-function parameter-set resolution engine, which
        produced ParameterBindingException in IME/SYSTEM context regardless of decoration
        strategy. Simple functions bind named parameters by name match only. All callers
        use explicit named parameters so positional binding is not needed.
    #>
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds
    )

    $workingDirectory = [System.IO.Path]::GetDirectoryName($FilePath)
    $argumentString = Join-InstallerArguments -ArgumentList $ArgumentList

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = $workingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()

        if (-not $started) {
            throw ('Process.Start() returned False without throwing for ''{0}'', which is unexpected.' -f $FilePath)
        }

        $timeoutMilliseconds = $TimeoutSeconds * 1000
        $hasExited = $process.WaitForExit($timeoutMilliseconds)

        if (-not $hasExited) {
            Stop-ProcessTree -ProcessId $process.Id

            try {
                $null = $process.WaitForExit(5000)
            }
            catch {
                # Intentionally swallowed. We already timed out and already attempted termination.
            }

            throw ('Installer timed out after {0} seconds and was terminated. FilePath: ''{1}''.' -f $TimeoutSeconds, $FilePath)
        }

        return [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}


function Test-Configuration {
    if ([string]::IsNullOrWhiteSpace($script:AppName)) {
        Exit-Failure -Code 1 -Message 'Configuration error: AppName is blank.' -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:AppVersion)) {
        Exit-Failure -Code 1 -Message 'Configuration error: AppVersion is blank.' -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:InstallerFileName)) {
        Exit-Failure -Code 1 -Message 'Configuration error: InstallerFileName is blank.' -Category 'PDQ'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:InstallerFileName)) {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerFileName must be a valid file name only, not a path. Value: ''{0}''.' -f $script:InstallerFileName) -Category 'PDQ'
    }

    if ([System.IO.Path]::GetExtension($script:InstallerFileName) -ine '.exe') {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerFileName must point to an .exe file. Value: ''{0}''.' -f $script:InstallerFileName) -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:ConfigXmlFileName)) {
        Exit-Failure -Code 1 -Message 'Configuration error: ConfigXmlFileName is blank.' -Category 'PDQ'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:ConfigXmlFileName)) {
        Exit-Failure -Code 1 -Message ('Configuration error: ConfigXmlFileName must be a valid file name only, not a path. Value: ''{0}''.' -f $script:ConfigXmlFileName) -Category 'PDQ'
    }

    if ([System.IO.Path]::GetExtension($script:ConfigXmlFileName) -ine '.xml') {
        Exit-Failure -Code 1 -Message ('Configuration error: ConfigXmlFileName must point to an .xml file. Value: ''{0}''.' -f $script:ConfigXmlFileName) -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:LogRoot)) {
        Exit-Failure -Code 1 -Message 'Configuration error: LogRoot is blank.' -Category 'PDQ'
    }

    if (-not [System.IO.Path]::IsPathRooted($script:LogRoot)) {
        Exit-Failure -Code 1 -Message ('Configuration error: LogRoot must be an absolute path. Value: ''{0}''.' -f $script:LogRoot) -Category 'PDQ'
    }

    if ([string]::IsNullOrWhiteSpace($script:LogFileName)) {
        $script:LogFileName = (ConvertTo-SafeFileNameComponent -Value $script:AppName) + '_Install.txt'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:LogFileName)) {
        Exit-Failure -Code 1 -Message ('Configuration error: LogFileName must be a valid file name only, not a path. Value: ''{0}''.' -f $script:LogFileName) -Category 'PDQ'
    }

    if (($script:TimeoutSeconds -lt 1) -or ($script:TimeoutSeconds -ge 3600)) {
        # Ceiling is 3599 s (just under 60 min) to stay aligned with the Intune
        # counterpart's bounded Win32 execution window.
        # The template default of 1199 was appropriate for general EXE installers but
        # ODT requires a much larger window for download + install.
        Exit-Failure -Code 1 -Message ('Configuration error: TimeoutSeconds must be between 1 and 3599. Value: ''{0}''.' -f $script:TimeoutSeconds) -Category 'PDQ'
    }

    if ($null -eq $script:InstallArguments) {
        $script:InstallArguments = @()
    }
    else {
        $normalizedArguments = New-Object 'System.Collections.Generic.List[string]'

        foreach ($argument in $script:InstallArguments) {
            if ($null -eq $argument) {
                Exit-Failure -Code 1 -Message 'Configuration error: InstallArguments contains a null element.' -Category 'PDQ'
            }

            [void]$normalizedArguments.Add([string]$argument)
        }

        $script:InstallArguments = $normalizedArguments.ToArray()
    }

    if ($null -eq $script:SuccessExitCodes -or $script:SuccessExitCodes.Count -eq 0) {
        Exit-Failure -Code 1 -Message 'Configuration error: SuccessExitCodes is empty.' -Category 'PDQ'
    }

    $normalizedExitCodes = New-Object 'System.Collections.Generic.List[int]'

    foreach ($exitCode in $script:SuccessExitCodes) {
        try {
            $convertedExitCode = [int]$exitCode
        }
        catch {
            Exit-Failure -Code 1 -Message ('Configuration error: SuccessExitCodes contains a non-integer value: ''{0}''.' -f $exitCode) -Category 'PDQ'
        }

        if (-not $normalizedExitCodes.Contains($convertedExitCode)) {
            [void]$normalizedExitCodes.Add($convertedExitCode)
        }
    }

    $script:SuccessExitCodes = $normalizedExitCodes.ToArray()

    if (-not [string]::IsNullOrWhiteSpace($script:DetectionPath)) {
        if (-not (Test-IsLikelyAbsoluteFilePath -Path $script:DetectionPath)) {
            Exit-Failure -Code 1 -Message ('Configuration error: DetectionPath must be an absolute FILE path with a file name and extension, not a directory path. Value: ''{0}''.' -f $script:DetectionPath) -Category 'PDQ'
        }
    }
}


# =========================
# MAIN
# =========================
try {
    # 64-bit process guard. Post-install verification accesses HKLM:\SOFTWARE\Microsoft\Office\
    # ClickToRun\Configuration and C:\Program Files\... - both resolve incorrectly from a
    # 32-bit host on a 64-bit OS due to WOW64 registry and file system redirection.
    # Configure the PDQ PowerShell step to use 64-bit Windows PowerShell.
    if (-not [Environment]::Is64BitProcess) {
        Exit-Failure -Code 1 -Message 'This script requires 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -Category 'PDQ'
    }

    $scriptRoot = Get-ScriptRoot

    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Exit-Failure -Code 1 -Message 'Unable to resolve script directory. Run this as a saved .ps1 file from disk, not from an unsaved or transient host context.' -Category 'PDQ'
    }

    Test-Configuration

    if ($script:RequireAdmin -and -not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This installer script requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -Category 'Permissions'
    }

    $payloadRoot = Copy-PDQPayloadToLocalStage
    $installerPath = Join-Path -Path $payloadRoot -ChildPath $script:InstallerFileName
    $configXmlPath = Join-Path -Path $payloadRoot -ChildPath $script:ConfigXmlFileName

    # Inject the resolved XML path into the argument list.
    # The path is quoted explicitly to handle staging locations that contain spaces
    # (e.g., C:\Program Files (x86)\...). Join-InstallerArguments joins with spaces
    # and does no quoting - the caller is responsible for quoting paths that may
    # contain spaces.
    $script:InstallArguments = @('/configure', ('"{0}"' -f $configXmlPath))

    # Pre-create the log root before ODT launches. ODT is configured to write
    # diagnostic logs here via the Logging element in the XML. Without pre-creation,
    # ODT output could be lost on a clean run where Write-ErrorLog never fires.
    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
    }
    catch {
        $summary = Get-ExceptionSummary -ErrorRecord $_
        Exit-Failure -Code 1 -Message ('Cannot create log folder ''{0}'': {1}' -f $script:LogRoot, $summary) -Category 'Permissions'
    }

    if (-not [string]::IsNullOrWhiteSpace($script:DetectionPath)) {
        if (Test-Path -LiteralPath $script:DetectionPath -PathType Container) {
            Exit-Failure -Code 1 -Message ('DetectionPath resolves to a directory, not a file: ''{0}''.' -f $script:DetectionPath) -Category 'PDQ'
        }
    }

    if (
        $script:SkipInstallIfAlreadyDetected -and
        -not [string]::IsNullOrWhiteSpace($script:DetectionPath) -and
        (Test-Path -LiteralPath $script:DetectionPath -PathType Leaf)
    ) {
        Remove-PDQPayloadStage
        exit 0
    }

    $exitCode = Invoke-InstallerProcess -FilePath $installerPath -ArgumentList $script:InstallArguments -TimeoutSeconds $script:TimeoutSeconds

    if ($script:SuccessExitCodes -notcontains $exitCode) {
        $description = Get-ExitCodeDescription -ExitCode $exitCode
        $message = '{0} installer returned exit code {1}.' -f $script:AppName, $exitCode

        if (-not [string]::IsNullOrWhiteSpace($description)) {
            $message = '{0} {1}' -f $message, $description
        }

        $category = 'App'
        if ($exitCode -in @(1619, 1620)) {
            $category = 'PDQ'
        }

        Exit-Failure -Code $exitCode -Message $message -Category $category
    }

    $shouldVerifyDetection =
        (-not [string]::IsNullOrWhiteSpace($script:DetectionPath)) -and
        (
            ($exitCode -notin @(3010, 1641)) -or
            $script:RequireDetectionOnRebootCodes
        )

    if ($shouldVerifyDetection) {
        if (Test-Path -LiteralPath $script:DetectionPath -PathType Container) {
            Exit-Failure -Code 1 -Message ('DetectionPath resolves to a directory, not a file: ''{0}''.' -f $script:DetectionPath) -Category 'PDQ'
        }

        if (-not (Test-Path -LiteralPath $script:DetectionPath -PathType Leaf)) {
            Exit-Failure -Code 1 -Message ('{0} installer exited {1}, but detection file was not found: ''{2}''.' -f $script:AppName, $exitCode, $script:DetectionPath) -Category 'App'
        }

        # Secondary verification: confirm the ClickToRun configuration key exists and
        # contains the expected product ID. This proves an ODT-managed C2R install
        # actually landed - not just that a WINWORD.EXE binary is present on disk
        # (which could be a leftover from a failed or partial install).
        #
        # SYNC NOTE: These two constants must match $script:C2RConfigKey and
        # $script:RequiredProductId in Detect.ps1. If you change either value here,
        # update Detect.ps1 to match.
        $c2rConfigKey      = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
        $requiredProductId = 'O365ProPlusRetail'

        try {
            if (-not (Test-Path -LiteralPath $c2rConfigKey)) {
                Exit-Failure -Code 1 -Message ('{0} installer exited {1} and WINWORD.EXE exists, but the ClickToRun configuration registry key is absent. The install may not have completed correctly.' -f $script:AppName, $exitCode) -Category 'App'
            }

            $c2rProps = Get-ItemProperty -LiteralPath $c2rConfigKey -ErrorAction Stop

            if (-not $c2rProps.PSObject.Properties['ProductReleaseIds']) {
                Exit-Failure -Code 1 -Message ('{0} installer exited {1}, but the ClickToRun ProductReleaseIds value is missing from the registry. The install may not have completed correctly.' -f $script:AppName, $exitCode) -Category 'App'
            }

            $productReleaseIds = [string]$c2rProps.ProductReleaseIds

            if ($productReleaseIds -notmatch [regex]::Escape($requiredProductId)) {
                Exit-Failure -Code 1 -Message ('{0} installer exited {1}, but ProductReleaseIds does not contain {2}. Found: ''{3}''. The install may have landed incorrectly.' -f $script:AppName, $exitCode, $requiredProductId, $productReleaseIds) -Category 'App'
            }
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            # Registry key not present - treat as failed install.
            Exit-Failure -Code 1 -Message ('{0} installer exited {1} and WINWORD.EXE exists, but the ClickToRun configuration key could not be read.' -f $script:AppName, $exitCode) -Category 'App'
        }
        catch {
            $summary = Get-ExceptionSummary -ErrorRecord $_
            Exit-Failure -Code 1 -Message ('{0} post-install registry verification failed: {1}' -f $script:AppName, $summary) -Category 'System'
        }
    }

    Remove-PDQPayloadStage
    exit $exitCode
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}
