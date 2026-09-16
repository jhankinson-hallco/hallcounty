#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Downloads and installs both x86 and x64 builds of the Microsoft Visual
    C++ 2010 SP1 Redistributable.

.DESCRIPTION
    Intune Win32 App installation script. Visual C++ 2010 has no bundled
    installer in this package - both architectures are downloaded directly
    from Microsoft at install time. Unlike VC++ 2015-2022, Microsoft has not
    published an evergreen aka.ms link for this legacy redistributable;
    these are the final, static SP1 build 10.0.40219.325 URLs.

    Phase 1 - Download:
      Downloads vcredist_x86.exe and vcredist_x64.exe to a TEMP staging
      folder over TLS 1.2. Each download is verified against a pinned
      SHA256 hash AND a valid Microsoft Authenticode signature before
      either installer is ever executed.

    Phase 2 - Install:
      Silently installs both (/q /norestart), one at a time.

    Phase 3 - Verify:
      Confirms both architectures are registered in the uninstall registry
      (DisplayName pattern + Publisher + WindowsInstaller=1) before
      declaring success.

    Downloaded installers are transient and removed from TEMP after this
    script completes (success or failure) - they are not needed after
    install and are not part of the persistent Intune package.

    Script-authored logging is error-only, to
    C:\IntuneAppLogs\VCRedist2010_Install.txt.

    KNOWN TRADEOFF: this design requires outbound internet access to
    download.microsoft.com at install time. Unlike a fully offline-bundled
    Win32 app, this has not been validated as safe during White Glove
    technician phase if network access is not yet available at that point -
    see project AI-Audit-Handoff.md.

    Exit Codes:
        0    = Success (both architectures installed and verified)
        3010 = Success; soft reboot required
        1641 = Success; hard reboot initiated by an installer
        1    = Failure (any phase failed; Intune will retry)

.NOTES
    Version:        1.0.0
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Download and install Microsoft Visual C++ 2010 SP1 Redistributable (x86 and x64)

    CHANGE LOG
    Change: 17/08/2026 - Full rewrite from a pre-standards legacy script that
                         was x86-only and referenced a bundled installer that
                         did not actually exist anywhere in the package. Now
                         downloads both architectures directly from Microsoft
                         with SHA256 + Authenticode verification before either
                         is ever executed -- ver. 1.0.0

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-VCRedist2010.ps1
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-VCRedist2010.ps1
      Install behavior: System
      Device restart behavior: Determine behavior based on return codes
      Return code mappings: 0 = Success, 3010 = Soft reboot, 1641 = Hard reboot
      Detection rule: custom detection script Detect.ps1
        Run script as 32-bit process on 64-bit clients: No

    VERIFIED SOURCE (2026-08-17: HEAD request confirmed both URLs live, then
    full download + SHA256 + Authenticode signature check performed directly)
      x86: https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe
           SHA256 99DCE3C841CC6028560830F7866C9CE2928C98CF3256892EF8E6CF755147B0D8
      x64: https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe
           SHA256 F3B7A76D84D23F91957AA18456A14B4E90609E4CE8194C5653384ED38DADA6F3
      Both signed "CN=Microsoft Corporation, O=Microsoft Corporation,
      L=Redmond, S=Washington, C=US"; FileVersion/ProductVersion
      10.0.40219.325 (final SP1 build - Microsoft does not service this
      redistributable further, so these hashes are not expected to change).
      If Microsoft ever does replace this file, SHA256 verification will
      fail loudly by design - update $script:ExpectedSha256X86/X64 above
      using the same download+hash+signature verification method.

    KNOWN RISKS (see project AI-Audit-Handoff.md for detail)
      - Requires outbound HTTPS to download.microsoft.com at install time;
        not validated for White Glove pre-network-availability scenarios.
      - No bundled offline fallback if the download URL becomes unavailable.
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:ScriptVersion = '1.0.0'
$script:AppName       = 'VCRedist2010'

$script:DownloadUrlX86        = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe'
$script:DownloadUrlX64        = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe'
$script:ExpectedSha256X86     = '99DCE3C841CC6028560830F7866C9CE2928C98CF3256892EF8E6CF755147B0D8'
$script:ExpectedSha256X64     = 'F3B7A76D84D23F91957AA18456A14B4E90609E4CE8194C5653384ED38DADA6F3'
$script:ExpectedSignerSubject = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'

$script:DownloadTimeoutSeconds    = 120
$script:InstallTimeoutSeconds     = 300
$script:InstallerArguments        = @('/q', '/norestart')
$script:InstallerSuccessExitCodes = @(0, 1638, 3010, 1641)

$script:DisplayNamePatternX86 = '^Microsoft Visual C\+\+ 2010\s+x86\s+Redistributable'
$script:DisplayNamePatternX64 = '^Microsoft Visual C\+\+ 2010\s+x64\s+Redistributable'
$script:PublisherPattern      = 'Microsoft Corporation*'
$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:DownloadRoot     = Join-Path -Path $env:TEMP -ChildPath 'VCRedist2010_Staging'
$script:InstallerPathX86 = Join-Path -Path $script:DownloadRoot -ChildPath 'vcredist_x86.exe'
$script:InstallerPathX64 = Join-Path -Path $script:DownloadRoot -ChildPath 'vcredist_x64.exe'

$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ($script:AppName + '_Install.txt')

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

function Test-VCRedistArchitectureInstalled {
    # Registry-based, direct evidence of installed state (preferred over a
    # marker file per reference_intune_detection.md - a VC++ redistributable
    # has no hidden configuration state a marker would need to substitute for).
    param(
        [string]$DisplayNamePattern
    )

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

                if ($null -eq $DisplayNameProperty -or $null -eq $PublisherProperty -or $null -eq $WindowsInstallerProperty) {
                    continue
                }

                if ([string]$DisplayNameProperty.Value -notmatch $DisplayNamePattern) {
                    continue
                }
                if ([string]$PublisherProperty.Value -notlike $script:PublisherPattern) {
                    continue
                }
                if ([string]$WindowsInstallerProperty.Value -ne '1') {
                    continue
                }

                return $true
            }
            catch {
                continue
            }
        }
    }

    return $false
}

function Invoke-VerifiedDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ExpectedSha256
    )

    New-Item -ItemType Directory -Path $script:DownloadRoot -Force -ErrorAction Stop | Out-Null

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $PreviousProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec $script:DownloadTimeoutSeconds -ErrorAction Stop
    }
    finally {
        $ProgressPreference = $PreviousProgressPreference
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw "Download from '$Url' completed without error but the destination file '$Destination' does not exist."
    }

    $ActualSha256 = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($ActualSha256 -ne $ExpectedSha256) {
        throw "SHA256 mismatch for '$Destination'. Expected '$ExpectedSha256', got '$ActualSha256'. Refusing to execute an unverified file."
    }

    $Signature = Get-AuthenticodeSignature -LiteralPath $Destination
    if ($Signature.Status -ne 'Valid') {
        throw "Authenticode signature on '$Destination' is not valid (status: $($Signature.Status)). Refusing to execute an unsigned or tampered file."
    }
    if ([string]$Signature.SignerCertificate.Subject -ne $script:ExpectedSignerSubject) {
        throw "Authenticode signer on '$Destination' does not match the expected Microsoft certificate. Signer: '$($Signature.SignerCertificate.Subject)'."
    }
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

function Invoke-VCRedistInstaller {
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
            throw 'Process.Start() returned False for the VC++ Redistributable installer without throwing.'
        }

        $HasExited = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $HasExited) {
            Stop-ProcessTree -ProcessId $Process.Id
            try { $null = $Process.WaitForExit(5000) } catch { }
            throw ('Installer timed out after {0} seconds and was terminated.' -f $TimeoutSeconds)
        }

        return [int]$Process.ExitCode
    }
    finally {
        $Process.Dispose()
    }
}

function Remove-DownloadStagingBestEffort {
    try {
        if (Test-Path -LiteralPath $script:DownloadRoot -PathType Container) {
            Remove-Item -LiteralPath $script:DownloadRoot -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to remove download staging folder '$($script:DownloadRoot)': $(Get-ExceptionSummary -ErrorRecord $_)" -Category 'System'
    }
}

# =============================================================================
# MAIN
# =============================================================================

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -Message 'This installer requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

# Idempotent short-circuit: skip download and install entirely if both
# architectures are already correctly registered.
if ((Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX86) -and
    (Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX64)) {
    Write-Output 'Microsoft Visual C++ 2010 Redistributable x86 and x64 are both already installed.'
    exit 0
}

try {
    $InstallerExitCodeX86 = 0
    $InstallerExitCodeX64 = 0

    # --- Phase 1: Download + verify (both, before installing either) ---
    try {
        Invoke-VerifiedDownload -Url $script:DownloadUrlX86 -Destination $script:InstallerPathX86 -ExpectedSha256 $script:ExpectedSha256X86
        Invoke-VerifiedDownload -Url $script:DownloadUrlX64 -Destination $script:InstallerPathX64 -ExpectedSha256 $script:ExpectedSha256X64
    }
    catch {
        throw "DOWNLOAD PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Phase 2: Install x86 ---
    try {
        $InstallerExitCodeX86 = Invoke-VCRedistInstaller -FilePath $script:InstallerPathX86 -ArgumentList $script:InstallerArguments -TimeoutSeconds $script:InstallTimeoutSeconds
        if ($script:InstallerSuccessExitCodes -notcontains $InstallerExitCodeX86) {
            throw "x86 installer returned exit code $InstallerExitCodeX86"
        }
    }
    catch {
        throw "X86 INSTALL PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Phase 3: Install x64 ---
    try {
        $InstallerExitCodeX64 = Invoke-VCRedistInstaller -FilePath $script:InstallerPathX64 -ArgumentList $script:InstallerArguments -TimeoutSeconds $script:InstallTimeoutSeconds
        if ($script:InstallerSuccessExitCodes -notcontains $InstallerExitCodeX64) {
            throw "x64 installer returned exit code $InstallerExitCodeX64"
        }
    }
    catch {
        throw "X64 INSTALL PHASE FAILED: $(Get-ExceptionSummary -ErrorRecord $_)"
    }

    # --- Phase 4: Verify both architectures registered ---
    Start-Sleep -Seconds 5
    if (-not (Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX86)) {
        throw 'x86 installer reported success but no trusted x86 registration was found afterward.'
    }
    if (-not (Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX64)) {
        throw 'x64 installer reported success but no trusted x64 registration was found afterward.'
    }

    Remove-DownloadStagingBestEffort

    $OverallExitCode = 0
    if ($InstallerExitCodeX86 -eq 1641 -or $InstallerExitCodeX64 -eq 1641) {
        $OverallExitCode = 1641
    }
    elseif ($InstallerExitCodeX86 -eq 3010 -or $InstallerExitCodeX64 -eq 3010) {
        $OverallExitCode = 3010
    }

    Write-Output "VCRedist2010 install script v$($script:ScriptVersion) completed successfully: x86 (exit $InstallerExitCodeX86) and x64 (exit $InstallerExitCodeX64) both installed and verified. OverallExitCode=$OverallExitCode."
    exit $OverallExitCode
}
catch {
    Remove-DownloadStagingBestEffort
    Stop-WithFailure -Message $_.Exception.Message -Category 'App'
}
