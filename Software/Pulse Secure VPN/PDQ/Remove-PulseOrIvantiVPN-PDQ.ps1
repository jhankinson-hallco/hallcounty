#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes the legacy Pulse Secure VPN client, the Ivanti Secure Access
    Client, or both, according to what is installed.

.DESCRIPTION
    PDQ removal dispatcher. The legacy Pulse Secure VPN client is detected
    independently from the Ivanti Secure Access Client by reading both native
    machine uninstall registry views.

    - Pulse only: runs the registered PulseUninstall.exe silently.
    - Ivanti only: runs the existing vendor-signed Ivanti deep-clean script.
    - Both: removes Pulse first, then runs the signed Ivanti deep-clean script.
    - Neither: exits successfully without changing the device.

    The signed Ivanti script is not modified. It runs in a child Windows
    PowerShell process so an exit statement inside the vendor script cannot
    terminate this dispatcher before its result is captured.

    Exit codes:
        0    Success or neither product was installed
        1    Failure or required installed-state evidence remains
        3010 Success; restart required
        1641 Success; restart initiated by a child removal process

.NOTES
    Version:        1.0.5
    Script Type:    PDQ Deploy Uninstall
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  18/08/2026
    Purpose:        Dispatch Pulse Secure and Ivanti Secure Access removal

    CHANGE LOG
    Change: 18/08/2026 - Initial release -- ver. 1.0.0
    Change: 18/08/2026 - Fixed a stray duplicate closing brace in
                         Invoke-PulseVpnUninstall that made the entire script
                         fail to parse (proven via Windows PowerShell 5.1
                         Parser::ParseFile - "Unexpected token '}'" at the
                         function's own closing brace). No behavioral change;
                         this restores the function to its evidently-intended
                         structure -- ver. 1.0.1
    Change: 18/08/2026 - Added Restart-In64BitPowerShellIfNeeded so this
                         script's own process (not just the child Ivanti
                         process) is guaranteed 64-bit before the
                         bitness-sensitive ProgramFiles fallback and
                         msiexec.exe path resolution run; added
                         REBOOT=ReallySuppress to the msiexec /x fallback
                         (matching the convention this shop settled on the
                         same day in the Barracuda NAC VPN and VC++ 2010
                         Redistributable projects); narrowed accepted exit
                         codes for the PulseUninstall.exe vendor-EXE path to
                         exclude MSI-specific codes 1605/1614, which have no
                         documented meaning for that tool (the msiexec
                         fallback and the Ivanti path both keep the full,
                         permissive code set); added this PDQ CONFIGURATION
                         block -- ver. 1.0.2
    Change: 18/08/2026 - Broadened Test-IsPulseVpnEntry's DisplayName match
                         from the exact "Pulse Secure" (+ optional version)
                         pattern to a "starts with the word Pulse" prefix
                         match. Live testing on a real endpoint proved the
                         narrow pattern missed two currently-installed
                         components with their own separate uninstall
                         registry entries: "Pulse Application Launcher" and
                         "Pulse Secure Installer Service". The Publisher
                         check is unchanged and remains the precision
                         safety net -- ver. 1.0.3
    Change: 18/08/2026 - Fixed a silent-false-success failure mode: a
                         "successful" exit code from either removal
                         mechanism no longer means the product is actually
                         gone. Added Test-IsUninstallEntryStillRegistered
                         and call it immediately after each removal attempt
                         in Invoke-PulseVpnUninstall (both the vendor-EXE
                         and msiexec branches); if the specific entry is
                         still registered despite an "accepted" exit code,
                         this now throws immediately with a message
                         explaining the likely cause (Windows Installer
                         refusing a transaction because a reboot is already
                         pending from an earlier removal in the same run)
                         instead of silently moving on and only surfacing
                         the problem in the generic end-of-script remaining-
                         evidence check. Also added /L*v verbose MSI
                         logging to the msiexec /x call, persisted to
                         C:\IntuneAppLogs only on failure (Save-MsiLogOnFailure),
                         for real diagnostic visibility into why a
                         transaction did not take effect -- ver. 1.0.4
    Change: 18/08/2026 - The v1.0.4 diagnostic log immediately proved the
                         "reboot pending" theory wrong for this endpoint:
                         msiexec's own engine returned 1605 with no
                         reboot-pending refusal anywhere in the verbose log
                         - a confirmed orphaned ARP entry Windows Installer
                         has no record of, which a normal MSI transaction
                         can never remove no matter how many times it is
                         retried. Added Remove-OrphanedUninstallRegistryEntry
                         and call it specifically when msiexec returns 1605
                         AND the entry is still registered afterward (never
                         used generically). Also moved the Pulse removal
                         loop's try/catch from wrapping the whole loop to
                         wrapping each entry individually - proven necessary
                         live, since one failing entry was silently
                         preventing a second, independent "Pulse Application
                         Launcher" entry from ever being attempted at all in
                         the same run -- ver. 1.0.5

    PDQ CONFIGURATION
      Package step:  PowerShell step running Remove-PulseOrIvantiVPN-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      Success codes: 0, 3010, 1641

    IVANTI PAYLOAD
    \\hallcounty\filestore\mis\CDS\Pulse Secure VPN\ISACDeepCleanScriptSilent_Signed_v1.1.ps1
#>

$script:ScriptVersion = '1.0.5'
$script:IvantiDeepCleanPath = '\\hallcounty\filestore\mis\CDS\Pulse Secure VPN\ISACDeepCleanScriptSilent_Signed_v1.1.ps1'
$script:ProcessTimeoutSeconds = 1800
$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath 'PulseIvantiVPN_Removal.txt'

function Write-ErrorLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Line = '[{0}] [v{1}] {2}' -f $Timestamp, $script:ScriptVersion, $Message
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Error logging must never mask the original deployment error.
    }
}

function Restart-In64BitPowerShellIfNeeded {
    # PDQ's own execution context bitness is not guaranteed the way Intune's
    # SysNative install command is. Detection itself (Get-MachineUninstallEntry)
    # is bitness-independent (explicit RegistryView64/32), but the Pulse
    # ProgramFiles fallback and the msiexec.exe path resolution are not: under
    # a 32-bit process, %ProgramFiles% and %ProgramFiles(x86)% both resolve to
    # the same WOW64-redirected path, and %SystemRoot%\System32\msiexec.exe
    # resolves to the 32-bit msiexec - confirmed by direct test, not assumed.
    if (-not [Environment]::Is64BitOperatingSystem) {
        return
    }
    if ([Environment]::Is64BitProcess) {
        return
    }

    $SysNativePath = Join-Path -Path $env:SystemRoot -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $SysNativePath -PathType Leaf)) {
        $Message = "Unable to relaunch in 64-bit Windows PowerShell. SysNative path not found: $SysNativePath"
        Write-ErrorLog -Message $Message
        Write-Output $Message
        exit 1
    }

    $Arguments = '-NoProfile -ExecutionPolicy Bypass -NonInteractive -File "{0}"' -f $PSCommandPath
    $ExitCode = Invoke-NativeProcess -FilePath $SysNativePath -Arguments $Arguments -TimeoutSeconds $script:ProcessTimeoutSeconds
    exit $ExitCode
}

function Test-IsAdministrator {
    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -ne $Identity.User -and $Identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $Principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList (,$Identity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-MachineUninstallEntry {
    $Entries = @()
    $Views = @(
        [Microsoft.Win32.RegistryView]::Registry64,
        [Microsoft.Win32.RegistryView]::Registry32
    )

    foreach ($View in $Views) {
        $BaseKey = $null
        $UninstallKey = $null

        try {
            $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine,
                $View
            )
            $UninstallKey = $BaseKey.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
            if ($null -eq $UninstallKey) {
                continue
            }

            foreach ($KeyName in $UninstallKey.GetSubKeyNames()) {
                $ProductKey = $null
                try {
                    $ProductKey = $UninstallKey.OpenSubKey($KeyName)
                    if ($null -eq $ProductKey) {
                        continue
                    }

                    $DisplayName = [string]$ProductKey.GetValue('DisplayName', '')
                    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
                        continue
                    }

                    $Entries += (New-Object -TypeName psobject -Property @{
                        RegistryView        = [string]$View
                        KeyName             = [string]$KeyName
                        DisplayName         = $DisplayName.Trim()
                        DisplayVersion      = [string]$ProductKey.GetValue('DisplayVersion', '')
                        Publisher           = [string]$ProductKey.GetValue('Publisher', '')
                        WindowsInstaller    = [int]$ProductKey.GetValue('WindowsInstaller', 0)
                        UninstallString     = [string]$ProductKey.GetValue('UninstallString', '')
                        QuietUninstallString = [string]$ProductKey.GetValue('QuietUninstallString', '')
                    })
                }
                finally {
                    if ($null -ne $ProductKey) {
                        $ProductKey.Dispose()
                    }
                }
            }
        }
        finally {
            if ($null -ne $UninstallKey) {
                $UninstallKey.Dispose()
            }
            if ($null -ne $BaseKey) {
                $BaseKey.Dispose()
            }
        }
    }

    return $Entries
}

function Test-IsPulseVpnEntry {
    # DisplayName is intentionally a broad "starts with the word Pulse"
    # match, not just "Pulse Secure" - live testing on a real endpoint
    # (2026-08-18) proved the narrower pattern misses real, currently
    # installed components: "Pulse Application Launcher" (does not even
    # start with "Pulse Secure") and "Pulse Secure Installer Service"
    # (starts with "Pulse Secure" but is followed by more words, not a
    # version number, so the old anchored pattern rejected it too). The
    # Publisher check is the precision safety net that keeps this from
    # being too permissive.
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $NameMatches = $Entry.DisplayName -match '^Pulse\b'
    $PublisherMatches = [string]::IsNullOrWhiteSpace($Entry.Publisher) -or
        $Entry.Publisher -match '^(Pulse Secure|Ivanti)'

    return ($NameMatches -and $PublisherMatches)
}

function Test-IsIvantiVpnEntry {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $NameMatches = $Entry.DisplayName -match '^Ivanti Secure Access Client(?:\s+\d.*)?$'
    $PublisherMatches = [string]::IsNullOrWhiteSpace($Entry.Publisher) -or
        $Entry.Publisher -match '^Ivanti'

    return ($NameMatches -and $PublisherMatches)
}

function Get-ExecutablePathFromCommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandLine
    )

    $ExpandedCommandLine = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    if ($ExpandedCommandLine -match '^"(?<Path>[^"]+\.exe)"') {
        return $Matches['Path']
    }
    if ($ExpandedCommandLine -match '^(?<Path>.+?\.exe)(?:\s|$)') {
        return $Matches['Path'].Trim()
    }

    return $null
}

function Stop-ProcessTree {
    param(
        [Parameter(Mandatory = $true)]
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
        catch {
            # Fall through to the direct process termination attempt.
        }
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
    catch {
        # The process may already have exited.
    }
}

function Invoke-NativeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $StartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $FilePath
    $StartInfo.Arguments = $Arguments
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true

    $Process = New-Object -TypeName System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        if (-not $Process.Start()) {
            throw "Process.Start() returned False for '$FilePath'."
        }

        if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-ProcessTree -ProcessId $Process.Id
            throw "Process '$FilePath' timed out after $TimeoutSeconds seconds and was terminated."
        }

        return [int]$Process.ExitCode
    }
    finally {
        $Process.Dispose()
    }
}

function Test-IsSuccessfulRemovalCode {
    # 1605/1614 are Windows Installer-specific codes (ERROR_UNKNOWN_PRODUCT /
    # ERROR_SUCCESS_REBOOT_INITIATED-adjacent "product not installed"/
    # "uninstalled" outcomes). They have a well-defined meaning for msiexec
    # transactions. Neither the vendor PulseUninstall.exe nor the signed
    # Ivanti deep-clean script are documented to use MSI-style exit codes, so
    # only genuine msiexec.exe transactions should accept them - accepting
    # them everywhere risks misclassifying an unrelated PulseUninstall.exe
    # exit code as success. The Ivanti path deliberately still uses the
    # permissive (default) set, since its real exit-code behavior remains
    # unconfirmed (see AI-Audit-Handoff.md) and narrowing it without evidence
    # risks a false failure instead of fixing anything.
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludeMsiSpecificCodes
    )

    if ($ExcludeMsiSpecificCodes) {
        return ($ExitCode -in @(0, 1641, 3010))
    }

    return ($ExitCode -in @(0, 1605, 1614, 1641, 3010))
}

function Test-IsUninstallEntryStillRegistered {
    # Matches by KeyName + RegistryView (the two fields that together
    # uniquely identify one specific uninstall registry subkey), so this
    # works regardless of which removal mechanism (vendor EXE or msiexec)
    # was actually used.
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $StillPresent = @(Get-MachineUninstallEntry) | Where-Object {
        $_.KeyName -eq $Entry.KeyName -and $_.RegistryView -eq $Entry.RegistryView
    }
    return (@($StillPresent).Count -gt 0)
}

function Remove-OrphanedUninstallRegistryEntry {
    # Direct registry cleanup for a CONFIRMED orphaned ARP entry only - used
    # exclusively when msiexec.exe /x has already returned 1605 (its own
    # engine reporting no record of this product) AND the entry is still
    # present afterward. A normal MSI transaction cannot remove a registry
    # entry Windows Installer does not recognize as installed, no matter how
    # many times it is retried - proven live on 2026-08-18 (see
    # AI-Audit-Decisions.md), not a theoretical concern. Since msiexec's own
    # internal product/component tracking already has no record of this
    # product, there is nothing else for a normal uninstall to clean up -
    # the stale ARP-visible registry key is the only remaining artifact, so
    # deleting it directly is the correct, narrowly-scoped remediation, not
    # a generic "delete any registry key" operation.
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $View = if ($Entry.RegistryView -eq 'Registry32') {
        [Microsoft.Win32.RegistryView]::Registry32
    }
    else {
        [Microsoft.Win32.RegistryView]::Registry64
    }

    $BaseKey = $null
    $UninstallKey = $null
    try {
        $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $View)
        $UninstallKey = $BaseKey.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', $true)
        if ($null -eq $UninstallKey) {
            throw "Unable to open the uninstall registry key for writing (view: $($Entry.RegistryView))."
        }
        $UninstallKey.DeleteSubKeyTree($Entry.KeyName, $false)
    }
    finally {
        if ($null -ne $UninstallKey) {
            $UninstallKey.Dispose()
        }
        if ($null -ne $BaseKey) {
            $BaseKey.Dispose()
        }
    }
}

function Save-MsiLogOnFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceLogFile
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SourceLogFile) -or -not (Test-Path -LiteralPath $SourceLogFile -PathType Leaf)) {
            return ''
        }
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $DestLogFile = Join-Path -Path $script:LogRoot -ChildPath ([System.IO.Path]::GetFileName($SourceLogFile))
        Copy-Item -LiteralPath $SourceLogFile -Destination $DestLogFile -Force -ErrorAction Stop
        return $DestLogFile
    }
    catch {
        return ''
    }
}

function Invoke-PulseVpnUninstall {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $UninstallerPath = $null
    foreach ($CandidateCommand in @($Entry.QuietUninstallString, $Entry.UninstallString)) {
        if (-not [string]::IsNullOrWhiteSpace($CandidateCommand) -and
            $CandidateCommand -match '(?i)PulseUninstall\.exe') {
            $UninstallerPath = Get-ExecutablePathFromCommandLine -CommandLine $CandidateCommand
            if (-not [string]::IsNullOrWhiteSpace($UninstallerPath)) {
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($UninstallerPath) -or
        -not (Test-Path -LiteralPath $UninstallerPath -PathType Leaf)) {
        $ProgramFilesRoots = @(
            [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
            [Environment]::GetEnvironmentVariable('ProgramFiles')
        )
        foreach ($ProgramFilesRoot in $ProgramFilesRoots) {
            if ([string]::IsNullOrWhiteSpace($ProgramFilesRoot)) {
                continue
            }
            $CommonUninstallerPath = Join-Path -Path $ProgramFilesRoot -ChildPath 'Pulse Secure\Pulse\PulseUninstall.exe'
            if (Test-Path -LiteralPath $CommonUninstallerPath -PathType Leaf) {
                $UninstallerPath = $CommonUninstallerPath
                break
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($UninstallerPath) -and
        (Test-Path -LiteralPath $UninstallerPath -PathType Leaf)) {
        $ExitCode = Invoke-NativeProcess -FilePath $UninstallerPath -Arguments '/silent=1' -TimeoutSeconds $script:ProcessTimeoutSeconds
        if (-not (Test-IsSuccessfulRemovalCode -ExitCode $ExitCode -ExcludeMsiSpecificCodes)) {
            throw "PulseUninstall.exe returned exit code $ExitCode for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)'."
        }
        # Exit code alone is not trusted as proof of removal - verify the
        # specific registry entry is actually gone. A "successful" exit code
        # that leaves the entry registered means the transaction did not
        # actually remove anything - the specific cause is not assumed here
        # (see the msiexec branch below for the one confirmed cause found so
        # far: an orphaned ARP entry Windows Installer no longer recognizes).
        if (Test-IsUninstallEntryStillRegistered -Entry $Entry) {
            throw "PulseUninstall.exe returned exit code $ExitCode (reported as success) for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)', but the product is still registered afterward."
        }
        return $ExitCode
    }

    $ProductCode = $null
    if ($Entry.KeyName -match '^\{[0-9A-Fa-f-]{36}\}$') {
        $ProductCode = $Entry.KeyName
    }

    $HasMsiUninstallString = $Entry.UninstallString -match '(?i)msiexec(?:\.exe)?\s'
    if (-not [string]::IsNullOrWhiteSpace($ProductCode) -and
        ($Entry.WindowsInstaller -eq 1 -or $HasMsiUninstallString)) {
        $MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
        $ProductCodeForFileName = $ProductCode -replace '[^0-9A-Fa-f]', ''
        $LogTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $MsiLogFile = Join-Path -Path $env:TEMP -ChildPath ('PulseVpn_{0}_{1}_MSI_Uninstall.log' -f $ProductCodeForFileName, $LogTimestamp)
        $MsiArguments = '/x "{0}" /qn /norestart REBOOT=ReallySuppress /L*v "{1}"' -f $ProductCode, $MsiLogFile
        $ExitCode = Invoke-NativeProcess -FilePath $MsiExecPath -Arguments $MsiArguments -TimeoutSeconds $script:ProcessTimeoutSeconds
        if (-not (Test-IsSuccessfulRemovalCode -ExitCode $ExitCode)) {
            $PersistedLog = Save-MsiLogOnFailure -SourceLogFile $MsiLogFile
            $LogReference = if ([string]::IsNullOrWhiteSpace($PersistedLog)) { $MsiLogFile } else { $PersistedLog }
            throw "msiexec.exe /x returned exit code $ExitCode for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)'. Check $LogReference."
        }
        # Same reasoning as the vendor-EXE branch above: verify the entry is
        # actually gone rather than trusting the exit code alone. The
        # registry uninstall key is removed as part of the CORE MSI
        # transaction, before any file-level "pending reboot" cleanup phase
        # - so if it is still present, the transaction did not really run,
        # regardless of what exit code was returned.
        if (Test-IsUninstallEntryStillRegistered -Entry $Entry) {
            $PersistedLog = Save-MsiLogOnFailure -SourceLogFile $MsiLogFile
            $LogReference = if ([string]::IsNullOrWhiteSpace($PersistedLog)) { $MsiLogFile } else { $PersistedLog }

            if ($ExitCode -eq 1605) {
                # Proven live 2026-08-18 (see AI-Audit-Decisions.md), not a
                # theory: 1605 here means msiexec's OWN engine has no record
                # of this product at all - the MSI verbose log shows
                # "MainEngineThread is returning 1605" with no pending-
                # reboot refusal anywhere in it. A normal MSI transaction
                # cannot remove a registry entry Windows Installer does not
                # recognize, no matter how many times it is retried. This is
                # a confirmed orphaned ARP entry - clean up the stale
                # registry key directly instead.
                Remove-OrphanedUninstallRegistryEntry -Entry $Entry
                if (Test-IsUninstallEntryStillRegistered -Entry $Entry) {
                    throw "msiexec.exe /x returned 1605 (Windows Installer has no record of this product) for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)', and direct removal of the orphaned registry entry also failed to clear it. Check $LogReference."
                }
                return $ExitCode
            }

            throw "msiexec.exe /x returned exit code $ExitCode (reported as success) for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)', but the product is still registered afterward. Check $LogReference."
        }
        return $ExitCode
    }

    throw "No supported Pulse VPN uninstaller was found for '$($Entry.DisplayName)' version '$($Entry.DisplayVersion)'."
}

function Get-WindowsPowerShellPath {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $SysNativePath = Join-Path -Path $env:SystemRoot -ChildPath 'SysNative\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $SysNativePath -PathType Leaf) {
            return $SysNativePath
        }
    }

    return (Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe')
}

function Invoke-IvantiDeepClean {
    if (-not (Test-Path -LiteralPath $script:IvantiDeepCleanPath -PathType Leaf)) {
        throw "The signed Ivanti deep-clean script was not found at '$($script:IvantiDeepCleanPath)'."
    }

    $PowerShellPath = Get-WindowsPowerShellPath
    $PowerShellArguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $script:IvantiDeepCleanPath
    return Invoke-NativeProcess -FilePath $PowerShellPath -Arguments $PowerShellArguments -TimeoutSeconds $script:ProcessTimeoutSeconds
}

try {
    Restart-In64BitPowerShellIfNeeded

    if (-not (Test-IsAdministrator)) {
        throw 'Administrator rights are required. Run this package with an elevated PDQ Deploy account.'
    }

    $InitialEntries = @(Get-MachineUninstallEntry)
    $PulseEntries = @($InitialEntries | Where-Object { Test-IsPulseVpnEntry -Entry $_ })
    $IvantiEntries = @($InitialEntries | Where-Object { Test-IsIvantiVpnEntry -Entry $_ })

    if ($PulseEntries.Count -eq 0 -and $IvantiEntries.Count -eq 0) {
        Write-Output 'Neither Pulse Secure VPN nor Ivanti Secure Access Client is installed. No action was required.'
        exit 0
    }

    $FailureMessages = @()
    $SoftRebootRequired = $false
    $HardRebootInitiated = $false

    if ($PulseEntries.Count -gt 0) {
        # try/catch is INSIDE the loop, per entry - a failure on one Pulse
        # component must not prevent attempting the rest. Proven necessary
        # live 2026-08-18: an outer try/catch around the whole loop meant
        # one failing entry aborted the run before a second, independent
        # "Pulse Application Launcher" entry was ever even attempted.
        foreach ($PulseEntry in $PulseEntries) {
            $CurrentPulseEntries = @(Get-MachineUninstallEntry | Where-Object { Test-IsPulseVpnEntry -Entry $_ })
            if ($CurrentPulseEntries.Count -eq 0) {
                break
            }

            try {
                # Invoke-PulseVpnUninstall validates its own exit code (with
                # the correct MSI-vs-vendor-EXE code set for whichever
                # mechanism it actually used) and throws on failure, so no
                # redundant check is needed here - only reboot-code capture.
                $PulseExitCode = Invoke-PulseVpnUninstall -Entry $PulseEntry
                if ($PulseExitCode -eq 3010) {
                    $SoftRebootRequired = $true
                }
                if ($PulseExitCode -eq 1641) {
                    $HardRebootInitiated = $true
                }
            }
            catch {
                $FailureMessages += $_.Exception.Message
            }
        }
    }

    if ($IvantiEntries.Count -gt 0) {
        try {
            $IvantiExitCode = Invoke-IvantiDeepClean
            if (-not (Test-IsSuccessfulRemovalCode -ExitCode $IvantiExitCode)) {
                throw "The signed Ivanti deep-clean script returned exit code $IvantiExitCode."
            }
            if ($IvantiExitCode -eq 3010) {
                $SoftRebootRequired = $true
            }
            if ($IvantiExitCode -eq 1641) {
                $HardRebootInitiated = $true
            }
        }
        catch {
            $FailureMessages += $_.Exception.Message
        }
    }

    Start-Sleep -Seconds 5

    $FinalEntries = @(Get-MachineUninstallEntry)
    $RemainingPulse = @($FinalEntries | Where-Object { Test-IsPulseVpnEntry -Entry $_ })
    $RemainingIvanti = @($FinalEntries | Where-Object { Test-IsIvantiVpnEntry -Entry $_ })

    if ($RemainingPulse.Count -gt 0) {
        $Names = [string]::Join(', ', @($RemainingPulse | ForEach-Object { $_.DisplayName + ' ' + $_.DisplayVersion }))
        $FailureMessages += "Pulse VPN remains registered after removal: $Names"
    }
    if ($RemainingIvanti.Count -gt 0) {
        $Names = [string]::Join(', ', @($RemainingIvanti | ForEach-Object { $_.DisplayName + ' ' + $_.DisplayVersion }))
        $FailureMessages += "Ivanti Secure Access Client remains registered after deep clean: $Names"
    }

    if ($FailureMessages.Count -gt 0) {
        $FailureText = [string]::Join(' | ', $FailureMessages)
        Write-ErrorLog -Message $FailureText
        Write-Output $FailureText
        exit 1
    }

    if ($PulseEntries.Count -gt 0 -and $IvantiEntries.Count -gt 0) {
        Write-Output 'Pulse Secure VPN was removed and the signed Ivanti Secure Access Client deep-clean script completed.'
    }
    elseif ($PulseEntries.Count -gt 0) {
        Write-Output 'Pulse Secure VPN was removed. The Ivanti deep-clean script was not run because Ivanti was not detected.'
    }
    else {
        Write-Output 'The signed Ivanti Secure Access Client deep-clean script completed. Pulse VPN was not detected.'
    }

    if ($HardRebootInitiated) {
        exit 1641
    }
    if ($SoftRebootRequired) {
        exit 3010
    }
    exit 0
}
catch {
    Write-ErrorLog -Message $_.Exception.Message
    Write-Output $_.Exception.Message
    exit 1
}
