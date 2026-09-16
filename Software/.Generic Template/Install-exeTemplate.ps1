#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Hardened generic Intune Win32 silent EXE installer template.

.DESCRIPTION
    - Assumes the installer EXE is bundled in the same folder as this script.
    - Intended for Intune Win32 deployment, typically in System context.
    - Uses System.Diagnostics.Process for explicit timeout control and best-effort
      process-tree termination.
    - Logs only on error to C:\IntuneAppLogs.
    - Preserves installer arguments exactly as configured. No additional quoting or
      escaping is injected by the script; include quotes in each argument exactly as
      the vendor documentation requires.
    - Supports optional pre-install and post-install file detection.

.NOTES
    Version:        1.1.4
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  08/04/2026
    Purpose:        Generic silent EXE installer template for Intune Win32 app deployment

    CHANGE LOG
    Change: 08/04/2026 - Initial release -- ver. 1.1.2
    Change: 09/04/2026 - Added explicit [Parameter(Mandatory=$false)] to Invoke-InstallerProcess $ArgumentList to resolve ParameterBindingException under 32-bit IME context -- ver. 1.1.3
    Change: 01/05/2026 - Converted all functions to simple functions: removed all [Parameter()] and
                         [ValidateSet()] attributes (type constraints retained). Replaced both
                         Split-Path -LiteralPath -Parent calls with [System.IO.Path]::GetDirectoryName()
                         in Get-ScriptRoot and Invoke-InstallerProcess. P22 and P24: field-confirmed
                         failure classes in PS 5.1 IME/SYSTEM context. The v1.1.3 partial fix (adding
                         [Parameter(Mandatory=$false)] to one param) was the wrong approach; correct
                         fix removes all [Parameter()] attributes from all functions -- ver. 1.1.4

    Detection guidance:
    This script's optional DetectionPath is only a local guardrail. Intune still
    requires a real detection rule in the Win32 app configuration.
#>

#region ========================= CONFIGURATION =========================

# Friendly application name used in messages and logs.
$script:AppName = 'Your App Name'

# Script version for log entries.
$script:AppVersion = '1.1.4'

# Installer EXE file name only.
# The EXE must be in the same folder as this script.
$script:InstallerFileName = 'YourAppInstaller.exe'

# Silent install arguments.
# One element per logical argument block.
# IMPORTANT:
#   - The script joins these elements with spaces exactly as written.
#   - If the vendor requires quotes, include them in the element yourself.
# Examples:
#   @('/S')
#   @('/quiet', '/norestart')
#   @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
#   @('/s', '/v"/qn"')
$script:InstallArguments = @()

# Error-only log settings.
$script:LogRoot = 'C:\IntuneAppLogs'

# Leave this derived from AppName unless you explicitly need a different file name.
$script:LogFileName = ((($script:AppName -replace '[\\/:*?"<>|]', '_').Trim()) + '_Install.txt')

# Script-level timeout in seconds.
# Keep this below IME's 20-minute hard kill (1200 seconds) so this script can fail
# cleanly and write its own diagnostics first.
$script:TimeoutSeconds = 900

# Require an elevated token.
# Leave $true for most machine-wide installs.
# Set to $false only for genuine per-user installers that are meant to run unelevated.
$script:RequireAdmin = $true

# Installer exit codes to treat as success and pass back to Intune.
# 0    = success
# 1707 = alternate MSI-layer success
# 3010 = success, reboot required
# 1641 = success, reboot initiated
$script:SuccessExitCodes = @(0, 1707, 3010, 1641)

# Optional file-based detection path.
# Leave blank to skip wrapper-side verification.
# This must be a full absolute FILE path, not a directory path.
# Prefer a reliable machine-wide path such as Program Files or ProgramData.
$script:DetectionPath = ''

# If DetectionPath is set and already exists before install, skip install and exit 0.
$script:SkipInstallIfAlreadyDetected = $true

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
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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


function Write-ErrorLog {
    <#
        Creates the log folder only on error.
        Appends directly; AppendAllText creates the file if it does not exist.
        Never lets logging failures crash the real installer flow.
    #>
    param(
        [string]$Message,
        [string]$Category = 'App'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)

        $logPath = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
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
    param(
        [int]$Code,
        [string]$Message,
        [string]$Category = 'App'
    )

    Write-ErrorLog -Message $Message -Category $Category
    exit $Code
}


function Get-ExceptionSummary {
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
        Exit-Failure -Code 1 -Message 'Configuration error: AppName is blank.' -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($script:AppVersion)) {
        Exit-Failure -Code 1 -Message 'Configuration error: AppVersion is blank.' -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($script:InstallerFileName)) {
        Exit-Failure -Code 1 -Message 'Configuration error: InstallerFileName is blank.' -Category 'Intune'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:InstallerFileName)) {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerFileName must be a valid file name only, not a path. Value: ''{0}''.' -f $script:InstallerFileName) -Category 'Intune'
    }

    if ([System.IO.Path]::GetExtension($script:InstallerFileName) -ine '.exe') {
        Exit-Failure -Code 1 -Message ('Configuration error: InstallerFileName must point to an .exe file. Value: ''{0}''.' -f $script:InstallerFileName) -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($script:LogRoot)) {
        Exit-Failure -Code 1 -Message 'Configuration error: LogRoot is blank.' -Category 'Intune'
    }

    if (-not [System.IO.Path]::IsPathRooted($script:LogRoot)) {
        Exit-Failure -Code 1 -Message ('Configuration error: LogRoot must be an absolute path. Value: ''{0}''.' -f $script:LogRoot) -Category 'Intune'
    }

    if ([string]::IsNullOrWhiteSpace($script:LogFileName)) {
        $script:LogFileName = (ConvertTo-SafeFileNameComponent -Value $script:AppName) + '_Install.txt'
    }

    if (-not (Test-IsValidLeafFileName -Value $script:LogFileName)) {
        Exit-Failure -Code 1 -Message ('Configuration error: LogFileName must be a valid file name only, not a path. Value: ''{0}''.' -f $script:LogFileName) -Category 'Intune'
    }

    if (($script:TimeoutSeconds -lt 1) -or ($script:TimeoutSeconds -ge 1200)) {
        Exit-Failure -Code 1 -Message ('Configuration error: TimeoutSeconds must be between 1 and 1199. Value: ''{0}''.' -f $script:TimeoutSeconds) -Category 'Intune'
    }

    if ($null -eq $script:InstallArguments) {
        $script:InstallArguments = @()
    }
    else {
        $normalizedArguments = New-Object 'System.Collections.Generic.List[string]'

        foreach ($argument in $script:InstallArguments) {
            if ($null -eq $argument) {
                Exit-Failure -Code 1 -Message 'Configuration error: InstallArguments contains a null element.' -Category 'Intune'
            }

            [void]$normalizedArguments.Add([string]$argument)
        }

        $script:InstallArguments = $normalizedArguments.ToArray()
    }

    if ($null -eq $script:SuccessExitCodes -or $script:SuccessExitCodes.Count -eq 0) {
        Exit-Failure -Code 1 -Message 'Configuration error: SuccessExitCodes is empty.' -Category 'Intune'
    }

    $normalizedExitCodes = New-Object 'System.Collections.Generic.List[int]'

    foreach ($exitCode in $script:SuccessExitCodes) {
        try {
            $convertedExitCode = [int]$exitCode
        }
        catch {
            Exit-Failure -Code 1 -Message ('Configuration error: SuccessExitCodes contains a non-integer value: ''{0}''.' -f $exitCode) -Category 'Intune'
        }

        if (-not $normalizedExitCodes.Contains($convertedExitCode)) {
            [void]$normalizedExitCodes.Add($convertedExitCode)
        }
    }

    $script:SuccessExitCodes = $normalizedExitCodes.ToArray()

    if (-not [string]::IsNullOrWhiteSpace($script:DetectionPath)) {
        if (-not (Test-IsLikelyAbsoluteFilePath -Path $script:DetectionPath)) {
            Exit-Failure -Code 1 -Message ('Configuration error: DetectionPath must be an absolute FILE path with a file name and extension, not a directory path. Value: ''{0}''.' -f $script:DetectionPath) -Category 'Intune'
        }
    }
}


# =========================
# MAIN
# =========================
try {
    $scriptRoot = Get-ScriptRoot

    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        Exit-Failure -Code 1 -Message 'Unable to resolve script directory. Run this as a saved .ps1 file from disk, not from an unsaved or transient host context.' -Category 'Intune'
    }

    Test-Configuration

    if ($script:RequireAdmin -and -not (Test-IsAdministrator)) {
        Exit-Failure -Code 1 -Message 'This installer script requires an elevated token. In Intune, use System install behavior unless the vendor explicitly requires user context.' -Category 'Permissions'
    }

    $installerPath = Join-Path -Path $scriptRoot -ChildPath $script:InstallerFileName

    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        Exit-Failure -Code 1 -Message ('Installer not found at ''{0}''. Verify the package contains ''{1}'' in the same folder as the script.' -f $installerPath, $script:InstallerFileName) -Category 'Intune'
    }

    if (-not [string]::IsNullOrWhiteSpace($script:DetectionPath)) {
        if (Test-Path -LiteralPath $script:DetectionPath -PathType Container) {
            Exit-Failure -Code 1 -Message ('DetectionPath resolves to a directory, not a file: ''{0}''.' -f $script:DetectionPath) -Category 'Intune'
        }
    }

    if (
        $script:SkipInstallIfAlreadyDetected -and
        -not [string]::IsNullOrWhiteSpace($script:DetectionPath) -and
        (Test-Path -LiteralPath $script:DetectionPath -PathType Leaf)
    ) {
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
            $category = 'Intune'
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
            Exit-Failure -Code 1 -Message ('DetectionPath resolves to a directory, not a file: ''{0}''.' -f $script:DetectionPath) -Category 'Intune'
        }

        if (-not (Test-Path -LiteralPath $script:DetectionPath -PathType Leaf)) {
            Exit-Failure -Code 1 -Message ('{0} installer exited {1}, but detection file was not found: ''{2}''.' -f $script:AppName, $exitCode, $script:DetectionPath) -Category 'App'
        }
    }

    exit $exitCode
}
catch {
    $summary = Get-ExceptionSummary -ErrorRecord $_
    $category = Get-ExceptionCategory -ErrorRecord $_
    Exit-Failure -Code 1 -Message ('Unexpected error: {0}' -f $summary) -Category $category
}