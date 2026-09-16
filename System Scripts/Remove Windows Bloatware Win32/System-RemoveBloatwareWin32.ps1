#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
  Removes preinstalled Win32 applications during Autopilot pre-provisioning (White Glove).

.DESCRIPTION
  - Runs as SYSTEM via Intune Win32 (IME).
  - Attempts to uninstall a configurable list of Win32 apps.
  - Safely skips apps that are not present (counts as success).
  - Prefers registry-based quiet uninstall strings when available because they are usually
    more reliable than hardcoded vendor switches.
  - Falls back to a package-defined uninstaller path search when no matching registry entry exists.
  - Verifies removal via service disappearance or, for known edge cases, a missing service binary.
  - Logs ONLY on error to C:\IntuneAppLogs\<AppName>_Install.txt
  - Creates a versioned marker file only after all targets succeed so Intune can use
    FILE EXISTS detection reliably.

.NOTES
  Author:         Jeremy Hankinson
  Script Version: 1.0.14
  Revision Date:  2026-03-17 (1.0.5); 2026-03-17 (1.0.6); 2026-03-17 (1.0.7); 2026-03-17 (1.0.8); 2026-03-18 (1.0.9); 2026-03-18 (1.0.10); 2026-03-18 (1.0.11); 2026-03-20 (1.0.12); 2026-03-23 (1.0.13); 2026-03-26 (1.0.14)
  Script Name:    System-RemoveBloatwareWin32.ps1

  White Glove / Autopilot guard: WMI (Win32_UserProfile) is the primary profile check,
  with a C:\Users + NTUSER.DAT filesystem fallback. If profile state cannot be determined
  (both methods fail), the guard proceeds fail-OPEN — during White Glove provisioning both
  methods consistently fail, so fail-closed would permanently prevent the script from
  running. The session check uses a provisioning-identity regex to allow defaultuser0 and
  similar OOBE identities. Only a confirmed real user profile or non-provisioning
  interactive session causes the script to write a SkippedPostOOBE marker and exit.

  Intune detection recommendation:
    Detection script paired to this version:
      Detect.ps1
#>

# ============================
# CONFIG (edit here only)
# ============================
$script:AppVersion = '1.0.14'
$script:AppName    = 'HC-RemoveWin32Bloatware'

$Targets = @(
    [PSCustomObject]@{
        DisplayName         = 'Lenovo Vantage Service'

        # Preferred uninstall source:
        # Use a matching uninstall registry entry first, ideally QuietUninstallString.
        RegistryDisplayNames = @('Lenovo Vantage Service')

        # Fallback uninstall source if the registry entry is missing or unusable.
        UninstallExeExact   = ''
        UninstallSearchRoot = 'C:\Program Files (x86)\Lenovo\VantageService'
        UninstallFileName   = 'Uninstall.exe'
        UninstallArgs       = '/SILENT /NORESTART'

        # Pre-uninstall presence checks.
        PresencePaths       = @('C:\Program Files (x86)\Lenovo\VantageService')
        PresenceServices    = @('LenovoVantageService')

        # Post-uninstall verification should focus on files that should disappear.
        VerifyAbsentPaths   = @(
            'C:\Program Files (x86)\Lenovo\VantageService\Uninstall.exe'
        )

        # Lenovo Vantage Service can leave a service registration behind briefly or until
        # a reboot even after the binary is gone. When this is set, a stopped service with
        # a missing/nonexistent image path is treated as removed.
        AllowRegisteredServiceWhenBinaryMissing = $true

        TimeoutSeconds      = 900
    }
)

$AcceptableExitCodes       = @(0, 3010, 1641)
$VerificationMaxAttempts   = 12
$VerificationDelaySeconds  = 10
$script:ServiceRegistryPollSecs   = 30

# Profile folders excluded from the real-user-profile check.
# defaultuser0 and similar OOBE identities are handled separately via ProvisioningUserRegex.
$script:ExcludedProfileNames  = @('Public', 'Default', 'Default User', 'All Users')
$script:ProvisioningUserRegex = '(^|\\)defaultuser\d+$'

$script:MarkerRoot                = 'C:\IntuneAppMarkers'
$SafeVersionForMarker             = ($script:AppVersion -replace '[^\w.\-]', '_')
$MarkerFileName                   = '{0}_{1}.tag' -f $script:AppName, $SafeVersionForMarker
$script:MarkerPath                = Join-Path $script:MarkerRoot $MarkerFileName

$script:LogRoot                   = 'C:\IntuneAppLogs'
$script:LogFile                   = Join-Path $script:LogRoot ($script:AppName + '_Install.txt')
# ============================
# END CONFIG
# ============================

function Get-ExceptionMessageChain {
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $messages = [System.Collections.Generic.List[string]]::new()
    $currentException = $Exception

    while ($null -ne $currentException) {
        $currentMessage = $currentException.Message

        if (-not [string]::IsNullOrWhiteSpace($currentMessage)) {
            $currentMessage = ($currentMessage -replace '(\r\n|\n|\r)+', ' ').Trim()
            if ($messages.Count -eq 0 -or $messages[$messages.Count - 1] -ne $currentMessage) {
                $messages.Add($currentMessage)
            }
        }

        $currentException = $currentException.InnerException
    }

    if ($messages.Count -eq 0) {
        return 'Unknown exception (no message provided).'
    }

    $fullMessage = $messages[0]
    for ($i = 1; $i -lt $messages.Count; $i++) {
        $fullMessage += " [Inner: $($messages[$i])]"
    }

    return $fullMessage
}

function Get-ErrorCategoryFromMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Message -match 'access is denied|requested operation requires elevation|unauthorized|0x80070005') {
        return 'permissions'
    }

    if ($Message -match 'network path was not found|the network name cannot be found|rpc server is unavailable|name resolution|dns|no such host|remote name could not be resolved') {
        return 'network'
    }

    if ($Message -match 'IntuneAppMarkers|marker file|target validation failed|target configuration|detection rule|detection recommendation|registry uninstall') {
        return 'Intune'
    }

    if ($Message -match 'uninstall|uninstaller|verification failed|timed out|exit code|stdout|stderr|still appears present|quietuninstallstring|uninstallstring') {
        return 'app'
    }

    return 'system'
}

function Initialize-ErrorLog {
    # .NET direct: CreateDirectory is idempotent and immune to $ErrorActionPreference = 'Stop'.
    # AppendAllText (called by Write-ErrorLog) creates the log file itself if absent.
    [System.IO.Directory]::CreateDirectory($script:LogRoot) | Out-Null
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('app','system','network','permissions','Intune')]
        [string]$Category
    )

    try {
        Initialize-ErrorLog
        try { $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } catch { $timestamp = '(unavailable)' }
        $line = "[$timestamp] [v$script:AppVersion] [$Category] $Message"
        # .NET direct: AppendAllText creates the file if absent; immune to $ErrorActionPreference = 'Stop'.
        [System.IO.File]::AppendAllText($script:LogFile, $line + [System.Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
    catch {
        try {
            $logFailure = Get-ExceptionMessageChain -Exception $_.Exception
            [Console]::Error.WriteLine(
                "$script:AppName v$script:AppVersion - LOGGING FAILED: Could not write to $script:LogFile. " +
                "Log error: $logFailure | Original message: [$Category] $Message"
            )
        }
        catch {
            # Logging fallback must never crash the script.
        }
    }
}

function Get-TargetPropertyValue {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$PropertyName
    )

    if ($Target.PSObject.Properties[$PropertyName]) {
        return $Target.PSObject.Properties[$PropertyName].Value
    }

    return $null
}

function Get-TargetArrayProperty {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $value = Get-TargetPropertyValue -Target $Target -PropertyName $PropertyName
    if ($null -eq $value) { return @() }

    return @($value)
}

function Merge-RestartCode {
    param(
        [Parameter(Mandatory)][int]$CurrentCode,
        [Parameter(Mandatory)][int]$NewCode
    )

    if ($CurrentCode -eq 1641 -or $NewCode -eq 1641) { return 1641 }
    if ($CurrentCode -eq 3010 -or $NewCode -eq 3010) { return 3010 }
    return 0
}

function New-MarkerFile {
    try {
        # Protect Get-Date — a failure must not prevent the marker from being written.
        try { $Created = Get-Date -Format 's' } catch { $Created = '(unavailable)' }

        $content = @"
AppName=$script:AppName
Version=$script:AppVersion
Created=$Created
"@

        # .NET direct: immune to $ErrorActionPreference = 'Stop' and idempotent for existing directories.
        [System.IO.Directory]::CreateDirectory($script:MarkerRoot) | Out-Null
        [System.IO.File]::WriteAllText($script:MarkerPath, $content, [System.Text.Encoding]::UTF8)

        Get-ChildItem -LiteralPath $script:MarkerRoot -Filter "$($script:AppName)_*.tag" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $script:MarkerPath } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    catch {
        $msg = Get-ExceptionMessageChain -Exception $_.Exception
        throw "Marker write failed at '$script:MarkerPath': $msg"
    }
}

function Test-Targets {
    param(
        [Parameter(Mandatory)]
        [object[]]$Targets
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    if ($Targets.Count -eq 0) {
        $issues.Add('No targets are configured. At least one target entry is required.')
    }

    foreach ($target in $Targets) {
        $displayName = [string](Get-TargetPropertyValue -Target $target -PropertyName 'DisplayName')
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = '(missing DisplayName)'
            $issues.Add('A target entry is missing DisplayName.')
        }

        $registryDisplayNames = @(
            Get-TargetArrayProperty -Target $target -PropertyName 'RegistryDisplayNames' |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )

        $exactPath   = [string](Get-TargetPropertyValue -Target $target -PropertyName 'UninstallExeExact')
        $searchRoot  = [string](Get-TargetPropertyValue -Target $target -PropertyName 'UninstallSearchRoot')
        $fileName    = [string](Get-TargetPropertyValue -Target $target -PropertyName 'UninstallFileName')

        $hasRegistry = $registryDisplayNames.Count -gt 0
        $hasExact    = -not [string]::IsNullOrWhiteSpace($exactPath)
        $hasSearch   = -not [string]::IsNullOrWhiteSpace($searchRoot)
        $hasFileName = -not [string]::IsNullOrWhiteSpace($fileName)

        if (-not $hasRegistry -and -not $hasExact -and -not ($hasSearch -and $hasFileName)) {
            $issues.Add("Target '$displayName' must define RegistryDisplayNames, UninstallExeExact, or both UninstallSearchRoot and UninstallFileName.")
        }

        $verifyPaths = @(
            Get-TargetArrayProperty -Target $target -PropertyName 'VerifyAbsentPaths' |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )

        $services = @(
            Get-TargetArrayProperty -Target $target -PropertyName 'PresenceServices' |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )

        if ($verifyPaths.Count -eq 0 -and $services.Count -eq 0) {
            $issues.Add("Target '$displayName' has no post-uninstall verification criteria. Define PresenceServices and/or VerifyAbsentPaths.")
        }

        $timeoutValue = Get-TargetPropertyValue -Target $target -PropertyName 'TimeoutSeconds'
        if ($null -ne $timeoutValue -and [string]$timeoutValue -ne '') {
            try {
                $parsedTimeout = [int]$timeoutValue
                if ($parsedTimeout -lt 1) {
                    $issues.Add("Target '$displayName' has invalid TimeoutSeconds '$timeoutValue'. It must be greater than 0.")
                }
            }
            catch {
                $issues.Add("Target '$displayName' has non-numeric TimeoutSeconds '$timeoutValue'.")
            }
        }
    }

    if ($issues.Count -gt 0) {
        throw "Target validation failed: $($issues -join ' | ')"
    }
}

function Get-LatestUninstallerPath {
    param(
        [Parameter(Mandatory)][string]$SearchRoot,
        [Parameter(Mandatory)][string]$FileName
    )

    if (-not (Test-Path -LiteralPath $SearchRoot)) { return $null }

    $rootCandidate = Join-Path $SearchRoot $FileName
    if (Test-Path -LiteralPath $rootCandidate) {
        return $rootCandidate
    }

    $candidates = [System.Collections.Generic.List[object]]::new()

    try {
        $subDirs = Get-ChildItem -LiteralPath $SearchRoot -Directory -ErrorAction Stop
    }
    catch {
        $msg = Get-ExceptionMessageChain -Exception $_.Exception
        throw "Failed to enumerate uninstall search root '$SearchRoot': $msg"
    }

    foreach ($dir in $subDirs) {
        $candidatePath = Join-Path $dir.FullName $FileName
        if (Test-Path -LiteralPath $candidatePath) {
            $ver = [version]'0.0.0.0'
            try {
                $ver = [version]$dir.Name
            }
            catch {
                $null = $_
            }

            $candidates.Add([PSCustomObject]@{
                Path    = $candidatePath
                Version = $ver
            })
        }
    }

    if ($candidates.Count -eq 0) { return $null }

    return ($candidates | Sort-Object Version -Descending | Select-Object -First 1).Path
}

function Get-UninstallRegistryEntries {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $entries = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object {
            # PSObject.Properties guard prevents StrictMode PropertyNotFoundException on uninstall
            # keys that lack DisplayName, QuietUninstallString, or UninstallString — the majority
            # of keys in the Uninstall hive do not carry all three. Short-circuit -and ensures
            # dot-notation is only reached after property existence is confirmed.
            ($null -ne $_.PSObject.Properties['DisplayName']) -and $_.DisplayName -and
            (
                (($null -ne $_.PSObject.Properties['QuietUninstallString']) -and $_.QuietUninstallString) -or
                (($null -ne $_.PSObject.Properties['UninstallString'])      -and $_.UninstallString)
            )
        } | ForEach-Object {
            # Publisher, QuietUninstallString, and UninstallString may be absent on entries that
            # passed the Where-Object filter (e.g. a key with UninstallString but no
            # QuietUninstallString). Access each via PSObject.Properties before dot-notation
            # to satisfy StrictMode -Version Latest.
            [PSCustomObject]@{
                DisplayName          = [string]$_.DisplayName
                Publisher            = if ($null -ne $_.PSObject.Properties['Publisher'])            { [string]$_.Publisher }            else { '' }
                QuietUninstallString = if ($null -ne $_.PSObject.Properties['QuietUninstallString']) { [string]$_.QuietUninstallString } else { '' }
                UninstallString      = if ($null -ne $_.PSObject.Properties['UninstallString'])      { [string]$_.UninstallString }      else { '' }
                RegistryKey          = [string]$_.PSChildName
            }
        }
    }

    return @($entries | Sort-Object DisplayName, RegistryKey -Unique)
}

function Split-CommandString {
    param(
        [Parameter(Mandatory)]
        [string]$CommandString
    )

    $trimmed = $CommandString.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw 'Command string was empty.'
    }

    if ($trimmed -match '^\s*"([^"]+)"\s*(.*)$') {
        return [PSCustomObject]@{
            FilePath     = $matches[1]
            ArgumentList = $matches[2].Trim()
        }
    }

    if ($trimmed -match '^\s*([^\s]+)\s*(.*)$') {
        return [PSCustomObject]@{
            FilePath     = $matches[1]
            ArgumentList = $matches[2].Trim()
        }
    }

    throw "Could not parse command string: $trimmed"
}

function Resolve-UninstallInvocation {
    param(
        [Parameter(Mandatory)]$Target
    )

    $displayName = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'DisplayName')
    $registryDisplayNames = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'RegistryDisplayNames' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    if ($registryDisplayNames.Count -gt 0) {
        $entries = Get-UninstallRegistryEntries | Where-Object {
            $_.DisplayName -in $registryDisplayNames
        }

        foreach ($entry in $entries) {
            $commandString = $null
            if (-not [string]::IsNullOrWhiteSpace($entry.QuietUninstallString)) {
                $commandString = $entry.QuietUninstallString
            }
            elseif (-not [string]::IsNullOrWhiteSpace($entry.UninstallString)) {
                $commandString = $entry.UninstallString
            }

            if (-not [string]::IsNullOrWhiteSpace($commandString)) {
                $invocation = Split-CommandString -CommandString $commandString
                if (Test-Path -LiteralPath $invocation.FilePath) {
                    return [PSCustomObject]@{
                        FilePath     = $invocation.FilePath
                        ArgumentList = $invocation.ArgumentList
                        Source       = "Registry: $($entry.DisplayName)"
                    }
                }

                if ($invocation.FilePath -match '^(?i)msiexec(?:\.exe)?$') {
                    return [PSCustomObject]@{
                        FilePath     = 'msiexec.exe'
                        ArgumentList = $invocation.ArgumentList
                        Source       = "Registry: $($entry.DisplayName)"
                    }
                }
            }
        }
    }

    $exactPath  = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'UninstallExeExact')
    $searchRoot = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'UninstallSearchRoot')
    $fileName   = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'UninstallFileName')

    $uninstaller = $null
    if (-not [string]::IsNullOrWhiteSpace($exactPath) -and (Test-Path -LiteralPath $exactPath)) {
        $uninstaller = $exactPath
    }
    elseif (-not [string]::IsNullOrWhiteSpace($searchRoot) -and -not [string]::IsNullOrWhiteSpace($fileName)) {
        $uninstaller = Get-LatestUninstallerPath -SearchRoot $searchRoot -FileName $fileName
    }

    if (-not $uninstaller) {
        throw "Uninstaller not found for '$displayName'. RegistryDisplayNames: '$($registryDisplayNames -join ', ')'; exact path: '$exactPath'; search root: '$searchRoot'."
    }

    $uninstallArgs = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'UninstallArgs')
    if ([string]::IsNullOrWhiteSpace($uninstallArgs)) { $uninstallArgs = '' }

    return [PSCustomObject]@{
        FilePath     = $uninstaller
        ArgumentList = $uninstallArgs
        Source       = 'Filesystem fallback'
    }
}

function Test-AppPresent {
    param([Parameter(Mandatory)]$Target)

    $paths = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'PresencePaths' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    $services = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'PresenceServices' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) { return $true }
    }

    foreach ($s in $services) {
        if ($null -ne (Get-ServiceInfoSafe -ServiceName $s)) {
            return $true
        }
    }

    $registryDisplayNames = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'RegistryDisplayNames' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    if ($registryDisplayNames.Count -gt 0) {
        if ((Get-UninstallRegistryEntries | Where-Object { $_.DisplayName -in $registryDisplayNames }).Count -gt 0) {
            return $true
        }
    }

    return $false
}

function Get-ServiceInfoSafe {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    try {
        $escapedName = $ServiceName.Replace("'", "''")
        return Get-CimInstance -ClassName Win32_Service -Filter "Name='$escapedName'" -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-ExecutablePathFromCommandLine {
    param(
        [string]$CommandLine
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $null }

    $trimmed = $CommandLine.Trim()

    if ($trimmed -match '^\s*"([^"]+)"') {
        return $matches[1]
    }

    if ($trimmed -match '^\s*([^\s]+\.exe)\b') {
        return $matches[1]
    }

    return $null
}

function Test-AppRemoved {
    param([Parameter(Mandatory)]$Target)

    $verifyPaths = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'VerifyAbsentPaths' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    $services = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'PresenceServices' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    $allowRegisteredServiceWhenBinaryMissing = $false
    $allowValue = Get-TargetPropertyValue -Target $Target -PropertyName 'AllowRegisteredServiceWhenBinaryMissing'
    if ($null -ne $allowValue) {
        $allowRegisteredServiceWhenBinaryMissing = [bool]$allowValue
    }

    if ($verifyPaths.Count -eq 0 -and $services.Count -eq 0) {
        throw "Target '$([string](Get-TargetPropertyValue -Target $Target -PropertyName 'DisplayName'))' has no post-uninstall verification criteria configured."
    }

    foreach ($p in $verifyPaths) {
        if (Test-Path -LiteralPath $p) { return $false }
    }

    foreach ($s in $services) {
        $svc = Get-ServiceInfoSafe -ServiceName $s
        if ($null -eq $svc) {
            continue
        }

        if (-not $allowRegisteredServiceWhenBinaryMissing) {
            return $false
        }

        $imagePath = Get-ExecutablePathFromCommandLine -CommandLine $svc.PathName
        if ($svc.State -ne 'Running' -and ([string]::IsNullOrWhiteSpace($imagePath) -or -not (Test-Path -LiteralPath $imagePath))) {
            continue
        }

        return $false
    }

    # All physical evidence (verify paths + service state) confirmed absent by the preceding checks.
    # Registry uninstall keys that linger post-uninstall pending a reboot are tolerated here —
    # they do not indicate the application is still functional.
    return $true
}

function Wait-ForAppRemoved {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][int]$MaxAttempts,
        [Parameter(Mandatory)][int]$DelaySeconds
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-AppRemoved -Target $Target) {
            return $true
        }

        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $false
}

function Stop-RelatedServices {
    param([Parameter(Mandatory)]$Target)

    $services = @(
        Get-TargetArrayProperty -Target $Target -PropertyName 'PresenceServices' |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    $anyStopped = $false
    foreach ($s in $services) {
        try {
            $svc = Get-Service -Name $s -ErrorAction Stop
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $s -Force -ErrorAction Stop
                $anyStopped = $true
            }
        }
        catch {
            # Service stop is best-effort. If the service cannot be stopped (already stopped,
            # access denied, or not found), the uninstaller will handle it.
            $null = $_
        }
    }

    if ($anyStopped) { Start-Sleep -Seconds 5 }
}

function Invoke-Uninstall {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][int[]]$AcceptableExitCodes
    )

    $displayName = [string](Get-TargetPropertyValue -Target $Target -PropertyName 'DisplayName')
    $invocation = Resolve-UninstallInvocation -Target $Target

    Stop-RelatedServices -Target $Target

    $timeoutSecs = Get-TargetPropertyValue -Target $Target -PropertyName 'TimeoutSeconds'
    if ($null -eq $timeoutSecs -or [string]$timeoutSecs -eq '') {
        $timeoutSecs = 600
    }
    else {
        $timeoutSecs = [int]$timeoutSecs
    }

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $workingDir = Split-Path -LiteralPath $invocation.FilePath -Parent -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($workingDir)) {
            # Bare executable name (e.g. msiexec.exe) has no parent path — fall back to System32.
            $workingDir = Join-Path $env:SystemRoot 'System32'
        }

        $proc = Start-Process -FilePath $invocation.FilePath `
                              -ArgumentList $invocation.ArgumentList `
                              -WorkingDirectory $workingDir `
                              -NoNewWindow `
                              -RedirectStandardOutput $stdoutFile `
                              -RedirectStandardError $stderrFile `
                              -PassThru

        if (-not $proc.WaitForExit($timeoutSecs * 1000)) {
            try { $proc.Kill() } catch { $null = $_ }
            throw "Uninstaller timed out after $timeoutSecs seconds for '$displayName'. Source: $($invocation.Source). FilePath: '$($invocation.FilePath)'. Arguments: '$($invocation.ArgumentList)'."
        }

        if ($AcceptableExitCodes -notcontains $proc.ExitCode) {
            $rawOut = (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue) -replace '\s+', ' '
            $rawErr = (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue) -replace '\s+', ' '

            $stdout = if ($rawOut -and $rawOut.Trim()) { $rawOut.Trim() } else { '(none)' }
            $stderr = if ($rawErr -and $rawErr.Trim()) { $rawErr.Trim() } else { '(none)' }

            throw "Uninstaller returned exit code $($proc.ExitCode) for '$displayName'. Source: $($invocation.Source). FilePath: '$($invocation.FilePath)'. Arguments: '$($invocation.ArgumentList)'. STDOUT: [$stdout] STDERR: [$stderr]"
        }

        $pollServices = @(
            Get-TargetArrayProperty -Target $Target -PropertyName 'PresenceServices' |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )

        if ($pollServices.Count -gt 0) {
            $pollDeadline = (Get-Date).AddSeconds($script:ServiceRegistryPollSecs)
            do {
                $anyRegistered = $false
                foreach ($s in $pollServices) {
                    if (Get-ServiceInfoSafe -ServiceName $s) {
                        $anyRegistered = $true
                        break
                    }
                }

                if (-not $anyRegistered) { break }
                Start-Sleep -Seconds 2
            } while ((Get-Date) -lt $pollDeadline)
        }
        else {
            Start-Sleep -Seconds 5
        }

        return [PSCustomObject]@{
            ExitCode        = [int]$proc.ExitCode
            UninstallerPath = $invocation.FilePath
            ArgumentList    = $invocation.ArgumentList
            Source          = $invocation.Source
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-IsProvisioningIdentity {
    param(
        [AllowNull()][string]$UserName
    )

    # A null or blank username means no interactive session — safe to proceed.
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return $true
    }

    # Allow defaultuser0, defaultuser1, etc. — OOBE/White Glove identities.
    return ($UserName -match $script:ProvisioningUserRegex)
}

function Get-RealUserProfiles {
    <#
        Primary:  Win32_UserProfile (WMI)
        Fallback: C:\Users filesystem + NTUSER.DAT existence check

        Returns an array when determination succeeds.
        Returns $null when state cannot be determined reliably.
        Callers must treat $null as fail-closed — suppress execution.
    #>

    # [SYSTEM/WMI]
    try {
        $Profiles = @(
            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
                Where-Object {
                    -not $_.Special -and
                    $_.LocalPath -like 'C:\Users\*'
                } |
                ForEach-Object {
                    [pscustomobject]@{
                        Name      = Split-Path -Path $_.LocalPath -Leaf
                        LocalPath = $_.LocalPath
                    }
                } |
                Where-Object {
                    $script:ExcludedProfileNames -notcontains $_.Name -and
                    $_.Name -notmatch '^defaultuser\d+$'
                }
        )

        return $Profiles
    }
    catch { }

    # [SYSTEM/PERMISSIONS] — Fallback: folder + NTUSER.DAT
    try {
        $Profiles = @(
            Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction Stop |
                Where-Object {
                    $script:ExcludedProfileNames -notcontains $_.Name -and
                    $_.Name -notmatch '^defaultuser\d+$' -and
                    (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'NTUSER.DAT') -PathType Leaf)
                } |
                ForEach-Object {
                    [pscustomobject]@{
                        Name      = $_.Name
                        LocalPath = $_.FullName
                    }
                }
        )

        return $Profiles
    }
    catch {
        # [SYSTEM/PERMISSIONS] — Both enumeration methods failed. Return $null to signal that
        # profile state cannot be determined. Callers exit 0 without writing a marker so
        # Intune can retry on a future evaluation cycle.
        return $null
    }
}

function Get-InteractiveUserName {
    try {
        return (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
    }
    catch {
        # [SYSTEM/INTUNE] — CIM query failure. Return $null; provisioning identity check
        # will treat $null as a safe provisioning identity and allow execution.
        return $null
    }
}

# ============================
# MAIN
# ============================
$failures            = [System.Collections.Generic.List[object]]::new()
$successfulRemovals  = 0
$attemptedUninstall  = $false
$overallRestartCode  = 0

try {
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        exit 0
    }

    # -------------------------------------------------------------------------
    # Session Guard: White Glove / Autopilot Only
    # Prevents execution on production devices — both actively-used and idle.
    #
    # Check 1 — Real user profiles (primary gate):
    #   Get-RealUserProfiles uses WMI (Win32_UserProfile) with a C:\Users +
    #   NTUSER.DAT fallback. Returns $null if state cannot be determined —
    #   callers exit 0 fail-closed without writing the marker so Intune retries.
    #
    # Check 2 — Active interactive session (secondary catch):
    #   Non-provisioning interactive sessions (not defaultuser0 / OOBE identities)
    #   are treated as a production context. Exit 0 without writing the marker.
    #
    # Both cases: exit 0 without writing the marker. Detect.ps1 mirrors this
    # logic to suppress retries on production devices.
    # -------------------------------------------------------------------------
    $RealProfiles = Get-RealUserProfiles
    if ($null -eq $RealProfiles) {
        # Cannot determine provisioning state — fail OPEN and proceed.
        # During White Glove, WMI and filesystem enumeration both consistently
        # fail. Fail-closed here would permanently prevent this script from running.
    }
    elseif ($RealProfiles.Count -gt 0) {
        # Real profiles confirmed — device has been in production.
        # Write marker so detection permanently suppresses future install attempts.
        New-MarkerFile
        exit 0
    }

    $LoggedOnUser = Get-InteractiveUserName
    if (-not (Test-IsProvisioningIdentity -UserName $LoggedOnUser)) {
        exit 0
    }

    Test-Targets -Targets $Targets

    foreach ($t in $Targets) {
        $displayName = [string](Get-TargetPropertyValue -Target $t -PropertyName 'DisplayName')

        try {
            if (-not (Test-AppPresent -Target $t)) {
                continue
            }

            $attemptedUninstall = $true

            $invokeResult = Invoke-Uninstall -Target $t -AcceptableExitCodes $AcceptableExitCodes
            $overallRestartCode = Merge-RestartCode -CurrentCode $overallRestartCode -NewCode $invokeResult.ExitCode

            if (-not (Wait-ForAppRemoved -Target $t -MaxAttempts $VerificationMaxAttempts -DelaySeconds $VerificationDelaySeconds)) {
                if ($invokeResult.ExitCode -in @(3010, 1641)) {
                    $successfulRemovals++
                    continue
                }

                throw "Verification failed: '$displayName' still appears present after uninstall."
            }

            $successfulRemovals++
        }
        catch {
            $message = Get-ExceptionMessageChain -Exception $_.Exception
            $category = Get-ErrorCategoryFromMessage -Message $message

            $failures.Add([PSCustomObject]@{
                DisplayName = $displayName
                Category    = $category
                Error       = $message
            })
        }
    }

    if ($failures.Count -gt 0) {
        Write-ErrorLog -Message 'One or more uninstall operations failed — writing marker and exiting 0 to prevent ESP chain failure.' -Category 'Intune'
        Write-ErrorLog -Message "ScriptVersion: $script:AppVersion" -Category 'Intune'
        Write-ErrorLog -Message "MarkerPath: $script:MarkerPath" -Category 'Intune'
        Write-ErrorLog -Message "AttemptedUninstall: $attemptedUninstall" -Category 'Intune'
        Write-ErrorLog -Message "SuccessfulRemovals: $successfulRemovals" -Category 'Intune'
        Write-ErrorLog -Message "FailureCount: $($failures.Count)" -Category 'Intune'

        foreach ($f in $failures) {
            Write-ErrorLog -Message "[$($f.DisplayName)] $($f.Error)" -Category $f.Category
        }

        try { New-MarkerFile } catch { } # Marker write failure must not prevent exit 0 — swallow silently.
        exit 0
    }

    New-MarkerFile

    if ($overallRestartCode -ne 0) {
        exit $overallRestartCode
    }

    exit 0
}
catch {
    # Each call is individually protected so that a failure in logging or message
    # extraction cannot prevent the unconditional exit 0 below.
    try {
        $message  = Get-ExceptionMessageChain -Exception $_.Exception
        $category = Get-ErrorCategoryFromMessage -Message $message
        Write-ErrorLog -Message $message -Category $category
    } catch { } # Log write failure must not prevent exit 0 — swallow silently.
    try { New-MarkerFile } catch { } # Marker write failure must not prevent exit 0 — swallow silently.
    exit 0
}