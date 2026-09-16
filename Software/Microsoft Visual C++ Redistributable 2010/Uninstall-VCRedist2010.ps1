#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uninstalls Microsoft Visual C++ 2010 SP1 Redistributable (x86 and x64).

.DESCRIPTION
    Intune Win32 App uninstallation script. Counterpart to
    Install-VCRedist2010.ps1.

    Discovers installed x86 and x64 product codes from the uninstall
    registry (DisplayName pattern + Publisher + WindowsInstaller=1 match,
    checked across both the native and WOW6432Node hives) and removes each
    via msiexec /x. Does not rely on a product-code file written at install
    time - discovery is always live, matching this shop's proven Barracuda
    NAC VPN uninstall pattern, so this uninstaller works correctly even
    against an install performed by the old pre-standards script or
    installed manually.

    Idempotent: if neither architecture is installed, the script exits
    successfully without attempting anything.

    Script-authored logging is error-only, to
    C:\IntuneAppLogs\VCRedist2010_Uninstall.txt. Verbose MSI logs are
    written to TEMP and are only copied into C:\IntuneAppLogs when a
    removal does not return a recognized success code.

    Exit Codes:
        0    = Success (both removed, or already absent)
        1605 = Success (one architecture was not installed)
        1614 = Success (uninstalled)
        3010 = Success (soft reboot required)
        1641 = Success (installer initiated reboot)
        1    = Failure

.NOTES
    Version:        1.0.0
    Script Type:    Microsoft Intune Win32 App
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Uninstall Microsoft Visual C++ 2010 SP1 Redistributable (x86 and x64)

    CHANGE LOG
    Change: 17/08/2026 - Full rewrite: live registry-driven product code
                         discovery for both architectures, replacing the
                         pre-standards single-GUID-file approach (which only
                         ever tracked one architecture and depended on a
                         marker file written by the old install script) --
                         ver. 1.0.0

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-VCRedist2010.ps1
      Install behavior: System
      Additional return codes: 1605 = Success, 1614 = Success, 3010 = Success (reboot), 1641 = Success (reboot)

    Paired install script: Install-VCRedist2010.ps1 v1.0.0
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName        = 'VCRedist2010'
$script:ScriptVersion  = '1.0.0'
$script:TimeoutSeconds = 300
$script:SuccessCodes   = @(0, 1605, 1614, 3010, 1641)

$script:DisplayNamePatternX86 = '^Microsoft Visual C\+\+ 2010\s+x86\s+Redistributable'
$script:DisplayNamePatternX64 = '^Microsoft Visual C\+\+ 2010\s+x64\s+Redistributable'
$script:PublisherPattern      = 'Microsoft Corporation*'
$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ($script:AppName + '_Uninstall.txt')

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
        [int]$ExitCode = 1,
        [string]$Message,
        [string]$Category = 'App'
    )
    Write-ErrorLog -Message $Message -Category $Category
    Write-Output $Message
    exit $ExitCode
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

function ConvertTo-MsiProductCode {
    param(
        [string]$Candidate
    )
    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return ''
    }

    # Regex-only validation (no [Guid]::Parse): static .NET type methods such
    # as [Guid]::Parse are blocked under PowerShell Constrained Language Mode
    # (WDAC/AppLocker) - see reference_intune_pitfalls.md P18. Registry key
    # names are already in canonical {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
    # form, so no .NET parsing is actually needed.
    if ($Candidate -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') {
        return $Candidate.ToUpperInvariant()
    }

    return ''
}

function Get-VCRedistProductCode {
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
            Write-ErrorLog -Message ('Unable to enumerate uninstall registry path ''{0}'': {1}' -f $RegistryPath, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
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

                $ProductCode = ConvertTo-MsiProductCode -Candidate ([string]$SubKey.PSChildName)
                if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
                    return $ProductCode
                }
            }
            catch {
                Write-ErrorLog -Message ('Failed to inspect uninstall registry entry ''{0}'': {1}' -f $SubKey.PSPath, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
            }
        }
    }

    return ''
}

function Invoke-MsiUninstall {
    param(
        [string]$ProductCode
    )

    $ProductCodeForFileName = $ProductCode -replace '[^0-9A-Fa-f]', ''
    $LogTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $MsiLogFileName = '{0}_{1}_{2}_MSI_Uninstall.log' -f $script:AppName, $ProductCodeForFileName, $LogTimestamp
    $MsiLogFile = Join-Path -Path $env:TEMP -ChildPath $MsiLogFileName
    $MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    # REBOOT=ReallySuppress (not the weaker Suppress) alongside /norestart -
    # a lesson learned and fixed on this exact conflict in the Barracuda NAC
    # VPN project's uninstall scripts; Suppress alone still permits a no-UI
    # ForceReboot during the transaction.
    $Arguments = '/x {0} /qn /norestart REBOOT=ReallySuppress /L*v "{1}"' -f $ProductCode, $MsiLogFile

    $StartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $MsiExecPath
    $StartInfo.Arguments = $Arguments
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true

    $Process = New-Object -TypeName System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        $Started = $Process.Start()
        if (-not $Started) {
            throw 'Process.Start() returned False for msiexec.exe without throwing.'
        }

        $HasExited = $Process.WaitForExit($script:TimeoutSeconds * 1000)
        if (-not $HasExited) {
            try { $Process.Kill() } catch { }
            try { $null = $Process.WaitForExit(5000) } catch { }
            throw ('msiexec.exe /x timed out after {0} seconds and was terminated.' -f $script:TimeoutSeconds)
        }

        return New-Object -TypeName psobject -Property @{
            ExitCode    = [int]$Process.ExitCode
            LogFile     = $MsiLogFile
            ProductCode = $ProductCode
        }
    }
    finally {
        $Process.Dispose()
    }
}

function Save-MsiLogOnFailure {
    param(
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
        Write-ErrorLog -Message ('Failed to persist MSI log ''{0}'' to ''{1}'': {2}' -f $SourceLogFile, $script:LogRoot, (Get-ExceptionSummary -ErrorRecord $_)) -Category 'System'
        return ''
    }
}

# =============================================================================
# MAIN
# =============================================================================

if (-not (Test-IsAdministrator)) {
    Stop-WithFailure -ExitCode 1 -Message 'This uninstaller requires an elevated token. In Intune, use System install behavior.' -Category 'Permissions'
}

try {
    $ProductCodeX86 = Get-VCRedistProductCode -DisplayNamePattern $script:DisplayNamePatternX86
    $ProductCodeX64 = Get-VCRedistProductCode -DisplayNamePattern $script:DisplayNamePatternX64

    if ([string]::IsNullOrWhiteSpace($ProductCodeX86) -and [string]::IsNullOrWhiteSpace($ProductCodeX64)) {
        Write-Output 'Microsoft Visual C++ 2010 Redistributable (x86 and x64) is already absent.'
        exit 0
    }

    $ExitCodes = @()

    if (-not [string]::IsNullOrWhiteSpace($ProductCodeX86)) {
        $ResultX86 = Invoke-MsiUninstall -ProductCode $ProductCodeX86
        if ($script:SuccessCodes -notcontains $ResultX86.ExitCode) {
            $PersistedLog = Save-MsiLogOnFailure -SourceLogFile $ResultX86.LogFile
            $LogReference = if ([string]::IsNullOrWhiteSpace($PersistedLog)) { $ResultX86.LogFile } else { $PersistedLog }
            Stop-WithFailure -ExitCode ([int]$ResultX86.ExitCode) -Message ('x86 uninstall failed for product code {0}. msiexec.exe returned {1}. Check {2}.' -f $ProductCodeX86, $ResultX86.ExitCode, $LogReference) -Category 'App'
        }
        $ExitCodes += [int]$ResultX86.ExitCode
    }

    if (-not [string]::IsNullOrWhiteSpace($ProductCodeX64)) {
        $ResultX64 = Invoke-MsiUninstall -ProductCode $ProductCodeX64
        if ($script:SuccessCodes -notcontains $ResultX64.ExitCode) {
            $PersistedLog = Save-MsiLogOnFailure -SourceLogFile $ResultX64.LogFile
            $LogReference = if ([string]::IsNullOrWhiteSpace($PersistedLog)) { $ResultX64.LogFile } else { $PersistedLog }
            Stop-WithFailure -ExitCode ([int]$ResultX64.ExitCode) -Message ('x64 uninstall failed for product code {0}. msiexec.exe returned {1}. Check {2}.' -f $ProductCodeX64, $ResultX64.ExitCode, $LogReference) -Category 'App'
        }
        $ExitCodes += [int]$ResultX64.ExitCode
    }

    Start-Sleep -Seconds 5

    $RemainingX86 = Get-VCRedistProductCode -DisplayNamePattern $script:DisplayNamePatternX86
    $RemainingX64 = Get-VCRedistProductCode -DisplayNamePattern $script:DisplayNamePatternX64
    if (-not [string]::IsNullOrWhiteSpace($RemainingX86) -or -not [string]::IsNullOrWhiteSpace($RemainingX64)) {
        Stop-WithFailure -ExitCode 1 -Message ('Uninstall completed but registry evidence still exists. x86 remaining: ''{0}''; x64 remaining: ''{1}''.' -f $RemainingX86, $RemainingX64) -Category 'App'
    }

    $OverallExitCode = 0
    if ($ExitCodes -contains 1641) {
        $OverallExitCode = 1641
    }
    elseif ($ExitCodes -contains 3010) {
        $OverallExitCode = 3010
    }

    Write-Output ('Microsoft Visual C++ 2010 Redistributable uninstall completed. ExitCode={0}.' -f $OverallExitCode)
    exit $OverallExitCode
}
catch {
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected VCRedist2010 uninstall error: {0}' -f (Get-ExceptionSummary -ErrorRecord $_)) -Category 'App'
}
