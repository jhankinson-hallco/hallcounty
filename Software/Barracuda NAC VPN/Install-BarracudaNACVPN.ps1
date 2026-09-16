#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Installs the VPN-only Barracuda Network Access Client, configures the Hall
    County SAML machine VPN profile, and deploys the Public Desktop shortcut.

.DESCRIPTION
    Intune Win32 App installation script. Combines the three PDQ deployment
    steps (install, VPN profile setup, desktop shortcut) into one script,
    since an Intune Win32 app has a single install command.

    Before this app runs, Intune must evaluate the separate
    Barracuda NAC VPN - Remove Legacy Versions dependency app. That app
    removes pre-5.3.8 versions and, when it performs removal work, waits
    three minutes and returns 1641 (Hard reboot). Intune therefore restarts
    the endpoint before allowing this 5.3.8 app to proceed. The installer
    intentionally does not launch the full uninstaller itself.

    Phase 1 - Install:
      Silently installs BarracudaNAC-SAML.exe (InstallShield EXE wrapping the
      Barracuda NAC MSI) via /clone_wait /s /v"..." with PROGTYPE=VPN. This
      selects the VPN Client only and excludes Personal Firewall and Health
      Monitoring. Verbose MSI log:
      C:\IntuneAppLogs\BarracudaNACVPN_5.3.8_Install.log

      After confirming the expected 5.3.8 registration is present, also
      verifies (read-only - no removal attempted) that no OTHER trusted
      Barracuda NAC MSI registration is present. This is a safety-net check
      only, in case the installer bundles an old version even when starting
      clean; per explicit direction, once install succeeds this script's
      job is done, so it fails loudly rather than attempting any post-
      install cleanup.

    Phase 2 - VPN Profile:
      Imports the Barracuda PowerShell module, ensures the cudanacsvc
      service is running, removes all existing Machine-context VPN
      profiles, and adds the Hall County SAML profile.

    Phase 3 - Shortcut:
      Copies the packaged 'Barracuda VPN Client.lnk' to the Public Desktop.

    Script-authored logging is error-only, to
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\APP_BarracudaNACVPN_Install.txt
    (IME-rooted per the current shop standard - C:\IntuneAppLogs is the
    legacy fallback path).

    On full success (all three phases), writes a version-stamped marker to
    C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\BarracudaNACVPN.marker
    (moved from the legacy C:\IntuneAppMarkers\BarracudaNACVPN.tag).
    Detect-BarracudaNACVPN.ps1 requires this marker (matching this script's
    version) plus direct file/service/shortcut evidence before reporting the
    app as installed. After writing it, this script also deletes any PDQ
    marker for this app (C:\ProgramData\PDQ\AppMarkers\BarracudaNACVPN.marker)
    - Intune is authoritative from this point on; see
    Set-BarracudaNACVPNMarker-PDQ.ps1 (PDQ\) for the PDQ-side counterpart.

    Exit Codes:
        0    = Success (install, VPN profile, and shortcut all completed)
        3010 = Success; soft reboot required
        1641 = Success; hard reboot initiated by installer
        1    = Failure (any phase failed; Intune will retry)

.NOTES
    Version:        1.0.6
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  13/08/2026
    Purpose:        Install the Barracuda VPN Client only, configure the Hall County SAML machine profile, and deploy the desktop shortcut

    ERROR CODES
      0    - Success
      1    - Failure; Intune should retry according to assignment policy
      3010 - Success; soft reboot required
      1641 - Success; hard reboot required

    CHANGE LOG
    Change: 13/08/2026 - Initial release -- ver. 1.0.0
    Change: 17/08/2026 - Verify installed product version, repair and verify shortcut icon, validate richer marker state, and preserve installer reboot exit codes -- ver. 1.0.1
    Change: 21/08/2026 - Select the VPN Client only with PROGTYPE=VPN; exclude Personal Firewall and Health Monitoring -- ver. 1.0.2
    Change: 21/08/2026 - Moved logging and the success marker to the current
                         IME-rooted paths (was C:\IntuneAppLogs /
                         C:\IntuneAppMarkers); marker filename now .marker
                         not .tag; added Remove-StalePdqMarker, called after
                         a successful install, to delete any PDQ marker for
                         this app now that Intune is authoritative -- ver. 1.0.3
    Change: 08/09/2026 - Live field fix: added Remove-BarracudaLegacyVersions,
                         called at the end of Phase 1 after the expected
                         5.3.8 registration is confirmed. Reproduced live:
                         clean machine -> fresh 5.1.2 install -> reboot ->
                         this installer -> both 5.1.2 and 5.3.8 registered
                         afterward, because BarracudaNAC-SAML.exe is a
                         chained/multi-package InstallShield transaction
                         (/clone_wait) that does not fully remove the old
                         version it bundles. The new function re-scans the
                         uninstall registry using the same trust rules as
                         Test-BarracudaExpectedVersion, removes every trusted
                         Barracuda NAC entry that is NOT the expected version
                         via msiexec /x (retrying up to 3 times on 1618 -
                         "another installation is already in progress" - in
                         case a leftover msiexec.exe from this installer's
                         own just-completed transaction has not yet released
                         the systemwide mutex), and verifies the registry
                         entry is actually gone afterward rather than
                         trusting the exit code alone. General by design
                         (matches on the existing DisplayName/Publisher/
                         WindowsInstaller pattern, not a hardcoded old
                         ProductCode) so it also catches any other stray
                         version a future installer revision might leave
                         behind. Fails the install phase if any other
                         version cannot be confirmed removed, per Jeremy's
                         explicit requirement that only 5.3.8 remain --
                         ver. 1.0.4
    Change: 08/09/2026 - Superseded the v1.0.4 approach per Jeremy's direct
                         follow-up instruction: "rather than uninstall after
                         installing the correct one, I want all versions of
                         barracuda removed from the machine so that the
                         5.3.8 install is fresh. Once 5.3.8 is installed, it
                         should be done." Removed Remove-BarracudaLegacyVersions
                         (the msiexec /x-calling post-install removal
                         function) entirely. Added a new Phase 0 that runs
                         Uninstall-BarracudaNACVPN.ps1 as a child process
                         before the installer runs, so install always starts
                         from a clean machine; a pending-reboot result
                         (3010/1641) or any other non-clean result fails the
                         install rather than proceeding. Phase 1's post-
                         install check is now read-only (Get-UnexpectedBarracudaVersions,
                         via the new shared Get-TrustedBarracudaEntries
                         scan) - it still fails the install if any other
                         version is somehow present after a clean-start
                         install, but performs no removal, matching "once
                         installed, it should be done." Kept as an explicit,
                         confirmed choice (not dropped) specifically so a
                         still-possible "installer bundles the old version
                         unconditionally" scenario fails loudly instead of
                         shipping silently -- ver. 1.0.5
    Change: 09/09/2026 - Removed the in-process Phase 0 full-uninstall call.
                         Legacy removal is now an independent Intune Win32
                         dependency that waits three minutes and returns
                         1641 after verified removal, ensuring a real restart
                         occurs before this installer is allowed to run.
                         Synchronized the paired detection marker gate --
                         ver. 1.0.6

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-BarracudaNACVPN.ps1
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-BarracudaNACVPN.ps1
      Install behavior: System
      Device restart behavior: Determine behavior based on return codes
      Return code mappings: 0 = Success, 3010 = Soft reboot, 1641 = Hard reboot
      Installation time required: recommend 30 (minutes) - script's own
        install-phase timeout is 900 seconds (15 min), with headroom for
        Intune content download/extraction and the profile/shortcut phases
      Detection rule: custom detection script Detect-BarracudaNACVPN.ps1
        Run script as 32-bit process on 64-bit clients: No
      Dependency: Barracuda NAC VPN - Remove Legacy Versions
        Automatically install: Yes

    PDQ COUNTERPART
      PDQ package steps: BarracudaNAC-SAML.exe install (PROGTYPE=VPN) +
      inline VPN profile PowerShell step + desktop shortcut copy step. No
      versioned PDQ install script file exists for these three steps at this
      time (PDQ uninstall script: PDQ\Uninstall-BarracudaNACVPN-PDQ.ps1).
      Set the PDQ EXE step Parameters field to:
        /clone_wait /s /v"/qn /L*v \"C:\IntuneAppLogs\BarracudaNACVPN_5.3.8_Install.log\" PROGTYPE=VPN REBOOT=ReallySuppress ALLUSERS=1"
      PDQ's own package already runs PDQ\Uninstall-BarracudaNACVPN-PDQ.ps1
      (twice) before this install step, so "clean before install" is
      already PDQ's architecture - unlike Intune, no new pre-install
      script was needed there. What PDQ was missing is the read-only
      post-install safety-net check; see
      PDQ\Test-BarracudaOnlyExpectedVersion-PDQ.ps1 (add as a new step
      immediately after the install step).

    KNOWN RISKS (see project AI-Audit-Handoff.md for detail)
      - Add-VPNProfile/Remove-VPNProfile parameter syntax was proven against
        the 5.1.2 module; not yet independently reconfirmed against the
        installed 5.3.8 module.
      - The packaged .lnk's stale 5.1.2 cache-based IconLocation is corrected
        after copy to use the installed nacvpn.exe icon.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion     = '1.0.6'
$script:AppName           = 'BarracudaNACVPN'
$script:InstallerFileName = 'BarracudaNAC-SAML.exe'
$script:ShortcutFileName  = 'Barracuda VPN Client.lnk'
$script:ExpectedProductVersion = '9.3.8012'
$script:DisplayNamePattern     = '^Barracuda Network Access Client(?:\s+\d+(?:[.-]\d+)*)?$'
$script:PublisherPattern       = 'Barracuda Networks*'
$script:RegistryPaths          = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# Barracuda VPN-only InstallShield/MSI argument set. PROGTYPE=VPN selects the
# VPN Client and excludes Personal Firewall and Health Monitoring.
$script:InstallerArguments = @(
    '/clone_wait',
    '/s',
    '/v"/qn /L*v \"C:\IntuneAppLogs\BarracudaNACVPN_5.3.8_Install.log\" PROGTYPE=VPN REBOOT=ReallySuppress ALLUSERS=1"'
)
$script:InstallTimeoutSeconds     = 900
$script:InstallerSuccessExitCodes = @(0, 3010, 1641)

$script:ServiceName                = 'cudanacsvc'
$script:ServiceStartTimeoutSeconds = 30
$script:ModulePath                 = 'C:\Program Files\Barracuda\Network Access Client\Modules\BarracudaNetworkAccessClient\BarracudaNetworkAccessClient.psd1'
$script:ProfileDescription         = 'Hall County VPN'
$script:ProfileContext             = 'Machine'
$script:ProfileAuthType            = 'SAML'
$script:ProfileServerAddress       = '75.131.187.244'

$script:NacvpnExePath     = 'C:\Program Files\Barracuda\Network Access Client\nacvpn.exe'
$script:PublicDesktopPath = 'C:\Users\Public\Desktop'
$script:DestShortcutPath  = Join-Path -Path $script:PublicDesktopPath -ChildPath $script:ShortcutFileName

# IME-rooted per the current shop standard (2026-08-20) - C:\IntuneAppLogs
# and C:\IntuneAppMarkers are legacy fallback paths only, not used by new
# writes. See reference_intune_paths.md / AGENTS.md "IME Runtime Paths".
$script:LogRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ('APP_' + $script:AppName + '_Install.txt')

$script:MarkerRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers'
$script:MarkerFile = Join-Path -Path $script:MarkerRoot -ChildPath ($script:AppName + '.marker')

# PDQ marker parity (2026-08-20 policy): once Intune successfully installs,
# any PDQ marker for this same app is stale and must be removed so it is
# never consulted again ahead of the now-authoritative Intune marker. See
# Set-BarracudaNACVPNMarker-PDQ.ps1 (PDQ\) for the script that writes this.
$script:PdqMarkerPath = Join-Path -Path 'C:\ProgramData\PDQ\AppMarkers' -ChildPath ($script:AppName + '.marker')

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

function ConvertTo-ComparableVersion {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    if ($Value.Trim() -notmatch '^0*(\d+)\.0*(\d+)\.0*(\d+)(?:\.0+)?$') {
        return ''
    }

    return ('{0}.{1}.{2}' -f ([int]$Matches[1]), ([int]$Matches[2]), ([int]$Matches[3]))
}

function Get-TrustedBarracudaEntries {
    # Read-only. Returns every uninstall-registry entry matching this
    # project's established Barracuda NAC trust rules (DisplayName pattern,
    # Publisher, WindowsInstaller=1), regardless of version. Shared by
    # Test-BarracudaExpectedVersion and Get-UnexpectedBarracudaVersions so
    # the scan/match logic exists in exactly one place.
    $Entries = @()

    foreach ($RegistryPath in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $RegistryPath)) {
            continue
        }

        try {
            $SubKeys = @(Get-ChildItem -LiteralPath $RegistryPath -ErrorAction Stop)
        }
        catch {
            continue
        }

        foreach ($SubKey in $SubKeys) {
            try {
                $Properties = Get-ItemProperty -LiteralPath $SubKey.PSPath -ErrorAction Stop
                $DisplayNameProperty = $Properties.PSObject.Properties['DisplayName']
                $PublisherProperty = $Properties.PSObject.Properties['Publisher']
                $WindowsInstallerProperty = $Properties.PSObject.Properties['WindowsInstaller']
                $DisplayVersionProperty = $Properties.PSObject.Properties['DisplayVersion']

                if ($null -eq $DisplayNameProperty -or $null -eq $PublisherProperty -or $null -eq $WindowsInstallerProperty) {
                    continue
                }
                if ([string]$DisplayNameProperty.Value -notmatch $script:DisplayNamePattern) {
                    continue
                }
                if ([string]$PublisherProperty.Value -notlike $script:PublisherPattern) {
                    continue
                }
                if ([string]$WindowsInstallerProperty.Value -ne '1') {
                    continue
                }

                $ComparableVersion = ''
                if ($null -ne $DisplayVersionProperty) {
                    $ComparableVersion = ConvertTo-ComparableVersion -Value ([string]$DisplayVersionProperty.Value)
                }

                $Entries += New-Object -TypeName psobject -Property @{
                    DisplayName       = [string]$DisplayNameProperty.Value
                    ProductCode       = [string]$SubKey.PSChildName
                    ComparableVersion = $ComparableVersion
                    RegistryPath      = [string]$SubKey.PSPath
                }
            }
            catch {
                continue
            }
        }
    }

    return ,$Entries
}

function Test-BarracudaExpectedVersion {
    # Get-TrustedBarracudaEntries comma-protects its return so 0/1/N-element
    # results all survive the function boundary correctly (P29). That
    # contract only holds for a direct assignment - wrapping the call in
    # @() or iterating it inline via "foreach (... in Get-TrustedBarracudaEntries)"
    # both double-wrap the result and silently collapse multi-element
    # results to a single iteration (proven live, 2026-09-08; see
    # AI-Audit-Decisions.md). Always assign to a variable first.
    $Entries = Get-TrustedBarracudaEntries
    foreach ($Entry in $Entries) {
        if ($Entry.ComparableVersion -eq $script:ExpectedProductVersion) {
            return $true
        }
    }
    return $false
}

function Get-UnexpectedBarracudaVersions {
    # Read-only safety-net check, called after Phase 1 confirms the expected
    # version is registered. Returns descriptions of any OTHER trusted
    # Barracuda NAC entry found; an empty array means only the expected
    # version is present. Never calls msiexec and never modifies anything -
    # per explicit direction, this script's job ends once install succeeds,
    # so a non-empty result fails the install rather than attempting to fix
    # it here.
    $Unexpected = @()
    $Entries = Get-TrustedBarracudaEntries
    foreach ($Entry in $Entries) {
        if ($Entry.ComparableVersion -ne $script:ExpectedProductVersion) {
            $Unexpected += "'$($Entry.DisplayName)' ($($Entry.ProductCode)), version '$($Entry.ComparableVersion)'"
        }
    }
    return ,$Unexpected
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

function Invoke-BarracudaInstaller {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [int]$TimeoutSeconds
    )

    $ArgumentString = $ArgumentList -join ' '
    $WorkingDirectory = [System.IO.Path]::GetDirectoryName($FilePath)

    $StartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $FilePath
    $StartInfo.Arguments = $ArgumentString
    $StartInfo.WorkingDirectory = $WorkingDirectory
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true

    $Process = New-Object -TypeName System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        $Started = $Process.Start()
        if (-not $Started) {
            throw 'Process.Start() returned False for the Barracuda installer without throwing.'
        }

        $HasExited = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $HasExited) {
            Stop-ProcessTree -ProcessId $Process.Id
            try { $null = $Process.WaitForExit(5000) } catch { }
            throw ('Barracuda installer timed out after {0} seconds and was terminated.' -f $TimeoutSeconds)
        }

        return [int]$Process.ExitCode
    }
    finally {
        $Process.Dispose()
    }
}

function Wait-BarracudaService {
    if (-not (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue)) {
        throw ('Barracuda service ''{0}'' was not found after install.' -f $script:ServiceName)
    }

    $Service = Get-Service -Name $script:ServiceName -ErrorAction Stop
    if ($Service.Status -ne 'Running') {
        Start-Service -Name $script:ServiceName -ErrorAction Stop
        $Service = Get-Service -Name $script:ServiceName -ErrorAction Stop
        $Service.WaitForStatus('Running', [TimeSpan]::FromSeconds($script:ServiceStartTimeoutSeconds))
    }

    $Service = Get-Service -Name $script:ServiceName -ErrorAction Stop
    if ($Service.Status -ne 'Running') {
        throw ('Barracuda service ''{0}'' did not reach the Running state.' -f $script:ServiceName)
    }
}

function Set-BarracudaVpnProfile {
    if (-not (Test-Path -LiteralPath $script:ModulePath -PathType Leaf)) {
        throw "Barracuda PowerShell module was not found: $($script:ModulePath)"
    }

    Import-Module -Name $script:ModulePath -Force -ErrorAction Stop

    $null = Get-Command -Name 'Remove-VPNProfile' -ErrorAction Stop
    $null = Get-Command -Name 'Add-VPNProfile' -ErrorAction Stop

    Wait-BarracudaService

    Remove-VPNProfile -All -Context $script:ProfileContext -ErrorAction Stop | Out-Null

    Add-VPNProfile -Description $script:ProfileDescription -Context $script:ProfileContext -AuthType $script:ProfileAuthType -ServerAddress $script:ProfileServerAddress -ErrorAction Stop | Out-Null
}

function Copy-BarracudaShortcut {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Packaged shortcut not found at '$Source'."
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw "Shortcut copy verification failed at '$Destination'."
    }

    $ExpectedIconLocation = $script:NacvpnExePath + ',0'
    $ExpectedWorkingDirectory = [System.IO.Path]::GetDirectoryName($script:NacvpnExePath)
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($Destination)
    $Shortcut.TargetPath = $script:NacvpnExePath
    $Shortcut.WorkingDirectory = $ExpectedWorkingDirectory
    $Shortcut.IconLocation = $ExpectedIconLocation
    $Shortcut.Save()

    $VerifiedShortcut = $Shell.CreateShortcut($Destination)
    if ([string]$VerifiedShortcut.TargetPath -ne $script:NacvpnExePath) {
        throw "Shortcut target verification failed at '$Destination'."
    }
    if ([string]$VerifiedShortcut.IconLocation -ne $ExpectedIconLocation) {
        throw "Shortcut icon verification failed at '$Destination'."
    }
}

function Write-SuccessMarker {
    New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction Stop | Out-Null
    $Lines = @(
        "Timestamp=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Version=$($script:ScriptVersion)",
        "ProductVersion=$($script:ExpectedProductVersion)",
        'Status=Success'
    )
    $Lines | Set-Content -LiteralPath $script:MarkerFile -Encoding UTF8 -ErrorAction Stop
}

function Remove-StalePdqMarker {
    # Best-effort, non-fatal: Intune is now authoritative for this app, so a
    # leftover PDQ marker must not survive to be consulted by a future
    # detection run. A failure here must not fail the install - the real
    # Intune marker has already been written successfully at this point.
    try {
        if (Test-Path -LiteralPath $script:PdqMarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $script:PdqMarkerPath -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to remove stale PDQ marker '$($script:PdqMarkerPath)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'App'
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
    Stop-WithFailure -Message 'This installer requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

$InstallerPath = Join-Path -Path $ScriptRoot -ChildPath $script:InstallerFileName
$SourceShortcutPath = Join-Path -Path $ScriptRoot -ChildPath $script:ShortcutFileName

if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
    Stop-WithFailure -Message "Installer not found at '$InstallerPath'. Verify the package contains '$($script:InstallerFileName)'." -Category 'Intune'
}
if (-not (Test-Path -LiteralPath $SourceShortcutPath -PathType Leaf)) {
    Stop-WithFailure -Message "Shortcut not found at '$SourceShortcutPath'. Verify the package contains '$($script:ShortcutFileName)'." -Category 'Intune'
}
try {
    # --- Phase 1: Install ---
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null

        $InstallerExitCode = Invoke-BarracudaInstaller -FilePath $InstallerPath -ArgumentList $script:InstallerArguments -TimeoutSeconds $script:InstallTimeoutSeconds

        if ($script:InstallerSuccessExitCodes -notcontains $InstallerExitCode) {
            throw "installer returned exit code $InstallerExitCode"
        }

        if (-not (Test-Path -LiteralPath $script:NacvpnExePath -PathType Leaf)) {
            throw "installer reported success (exit $InstallerExitCode) but '$($script:NacvpnExePath)' was not found"
        }

        if (-not (Test-BarracudaExpectedVersion)) {
            throw "installer reported success (exit $InstallerExitCode), but no trusted Barracuda MSI registration with expected product version '$($script:ExpectedProductVersion)' was found"
        }

        $UnexpectedVersions = Get-UnexpectedBarracudaVersions
        if ($UnexpectedVersions.Count -gt 0) {
            throw "expected product version '$($script:ExpectedProductVersion)' is installed, but one or more other Barracuda NAC versions are ALSO present (the legacy-removal dependency should have prevented this): $([string]::Join('; ', $UnexpectedVersions))"
        }
    }
    catch {
        throw "INSTALL PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Phase 2: VPN Profile ---
    try {
        Set-BarracudaVpnProfile
    }
    catch {
        throw "VPN PROFILE PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Phase 3: Shortcut ---
    try {
        Copy-BarracudaShortcut -Source $SourceShortcutPath -Destination $script:DestShortcutPath
    }
    catch {
        throw "SHORTCUT PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Success marker ---
    try {
        Write-SuccessMarker
    }
    catch {
        throw "Install succeeded but the success marker could not be written to '$($script:MarkerFile)': $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    Remove-StalePdqMarker

    Write-Output "BarracudaNACVPN install script v$($script:ScriptVersion) completed successfully: installer, VPN profile, and desktop shortcut all deployed. ExitCode=$InstallerExitCode."
    exit $InstallerExitCode
}
catch {
    Stop-WithFailure -Message $_.Exception.Message -Category 'App'
}
