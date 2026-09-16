#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: uninstalls RingCentral Desktop Application silently via MSI product code.

.DESCRIPTION
    PDQ Deploy uninstall script. Tandem counterpart of the Intune Win32 app
    Uninstall-RingCentral.ps1 (v3.3.0).
    - Stops any running RingCentral processes.
    - Calls msiexec.exe /x with the MSI product code to remove the machine-wide install
      from C:\Program Files\RingCentral\.
    - Accepts exit code 1605 (product not installed) as success so re-runs are safe.
    - Best-effort removes the machine-wide RingCentral firewall rule created at install time.
      Failure to remove the rule does not fail the uninstall.
    - Best-effort removes the version marker file created at install time.
    - Logs only on error to C:\IntuneAppLogs\RingCentral_Uninstall.txt
      (same path as Intune; PDQ entries are tagged [PDQ]).

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/07/2026
    Purpose:        Silent PDQ MSI uninstall of RingCentral desktop application

    CHANGE LOG
    Change: 14/07/2026 - Initial PDQ release, tandem with Intune Uninstall-RingCentral.ps1 v3.3.0 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-RingCentralSystem-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      Success codes: 0, 1605, 1614, 3010, 1641
#>

# ============================
# CONFIG (edit here only)
# ============================
$script:AppVersion  = '1.0.0'
$script:AppName     = 'RingCentral'

# MSI product code confirmed from the current source MSI Property table on 2026-07-07.
# Machine-wide install (APPLICATIONFOLDER = C:\Program Files\RingCentral\).
# msiexec /x finds the HKLM registration correctly when running as SYSTEM.
$script:ProductCode = '{ED2A3952-3297-49CA-95FA-31AB3078C41C}'

# Must match Install-RingCentralSystem-PDQ.ps1 and Intune Install-RingCentral.ps1 exactly.
$script:VersionMarkerPath = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt'

# Process names to stop before uninstallation.
$script:ProcessesToStop = @('RingCentral', 'Glip')

# Maximum seconds to wait for the uninstaller before killing it.
$script:TimeoutSeconds = 600

# Exit codes that indicate the product is already gone or was removed cleanly.
# 1605 = product not installed (MSI) -- safe to treat as success for idempotency.
# 1614 = product uninstalled (MSI). 3010/1641 = success with reboot semantics.
$script:AcceptableExitCodes = @(0, 1605, 1614, 3010, 1641)

# Must match Set-RingCentralFirewallRules-PDQ.ps1 and Intune Set-RingCentralFirewallRules.ps1 exactly.
$script:FirewallMachineRuleName = 'Hall County RingCentral - Machine'

$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath ($script:AppName + '_Uninstall.txt')
# ============================
# END CONFIG
# ============================


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
        [string]$ErrorMessage,

        [string]$ErrorCode = 'N/A'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        try { $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } catch { $timestamp = '(unavailable)' }
        $line = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $ErrorCode, $ErrorMessage
        [System.IO.File]::AppendAllText(
            $script:LogFile,
            $line + [System.Environment]::NewLine,
            [System.Text.Encoding]::UTF8
        )
    }
    catch {
        try {
            [Console]::Error.WriteLine('{0} v{1} - LOGGING FAILED: {2}' -f $script:AppName, $script:AppVersion, $ErrorMessage)
        }
        catch { }
    }
}


function Get-ExceptionMessageChain {
    param(
        [System.Exception]$Exception
    )

    $messages = New-Object 'System.Collections.Generic.List[string]'
    $current  = $Exception

    while ($null -ne $current) {
        $msg = $current.Message
        if (-not [string]::IsNullOrWhiteSpace($msg)) {
            $msg = ($msg -replace '(\r\n|\n|\r)+', ' ').Trim()
            if ($messages.Count -eq 0 -or $messages[$messages.Count - 1] -ne $msg) {
                [void]$messages.Add($msg)
            }
        }
        $current = $current.InnerException
    }

    if ($messages.Count -eq 0) { return 'Unknown exception (no message provided).' }

    $chain = $messages[0]
    for ($i = 1; $i -lt $messages.Count; $i++) {
        $chain += ' [Inner: {0}]' -f $messages[$i]
    }
    return $chain
}


function Stop-RunningProcesses {
    foreach ($name in $script:ProcessesToStop) {
        try {
            Get-Process -Name $name -ErrorAction SilentlyContinue |
                ForEach-Object {
                    try { Stop-Process -InputObject $_ -Force -ErrorAction Stop } catch { $null = $_ }
                }
        }
        catch { $null = $_ }
    }
    Start-Sleep -Seconds 2
}


function Remove-RingCentralFirewallRule {
    <#
        Best-effort cleanup of the machine-wide firewall rule created by
        Set-RingCentralFirewallRules-PDQ.ps1. Never throws -- failure here must not fail the uninstall.
    #>
    try {
        $rules = @(Get-NetFirewallRule -DisplayName $script:FirewallMachineRuleName -ErrorAction SilentlyContinue)
        foreach ($rule in $rules) {
            try {
                Remove-NetFirewallRule -InputObject $rule -ErrorAction Stop
            }
            catch {
                Write-ErrorLog -ErrorMessage ('Failed to remove firewall rule ''{0}'': {1}' -f $script:FirewallMachineRuleName, $_.Exception.Message) -ErrorCode 'FIREWALL'
            }
        }
    }
    catch {
        Write-ErrorLog -ErrorMessage ('Firewall rule cleanup failed: {0}' -f $_.Exception.Message) -ErrorCode 'FIREWALL'
    }
}


function Remove-VersionMarker {
    <#
        Best-effort cleanup of the version marker file written by Install-RingCentralSystem-PDQ.ps1.
        Never throws -- failure here must not fail the uninstall.
    #>
    try {
        if (Test-Path -LiteralPath $script:VersionMarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $script:VersionMarkerPath -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -ErrorMessage ('Failed to remove version marker ''{0}'': {1}' -f $script:VersionMarkerPath, $_.Exception.Message) -ErrorCode 'MARKER'
    }
}


function Invoke-MsiUninstall {
    param(
        [string]$ProductCode,

        [int]$TimeoutSeconds
    )

    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $arguments   = '/x {0} /qn /norestart' -f $ProductCode

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName        = $msiexecPath
    $startInfo.Arguments       = $arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow  = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()

        if (-not $started) {
            throw ('Process.Start() returned False for msiexec.exe without throwing.')
        }

        $hasExited = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $hasExited) {
            try { $process.Kill() } catch { $null = $_ }
            try { $null = $process.WaitForExit(5000) } catch { }
            throw ('msiexec.exe /x timed out after {0} seconds and was terminated.' -f $TimeoutSeconds)
        }

        return [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}


# ============================
# MAIN
# ============================
try {
    if (-not (Test-IsAdministrator)) {
        Write-ErrorLog -ErrorMessage 'This uninstaller requires an elevated administrative token. In PDQ, run the package as the Deploy User or Local System with local administrator rights.' -ErrorCode 'PERMISSIONS'
        exit 1
    }

    if (-not [Environment]::Is64BitProcess) {
        Write-ErrorLog -ErrorMessage 'This uninstaller must run in 64-bit Windows PowerShell. In PDQ, configure the PowerShell step to use the 64-bit host.' -ErrorCode 'PDQ'
        exit 1
    }

    Stop-RunningProcesses

    $invokeParams = @{
        ProductCode    = $script:ProductCode
        TimeoutSeconds = [int]$script:TimeoutSeconds
    }
    $exitCode = Invoke-MsiUninstall @invokeParams

    if ($script:AcceptableExitCodes -notcontains $exitCode) {
        Write-ErrorLog -ErrorMessage ('msiexec /x returned exit code {0} for product code {1}.' -f $exitCode, $script:ProductCode) -ErrorCode $exitCode
        exit $exitCode
    }

    Remove-RingCentralFirewallRule
    Remove-VersionMarker

    if ($exitCode -in @(3010, 1641)) {
        Write-Output ('{0} uninstall completed by PDQ with reboot-required exit code {1}.' -f $script:AppName, $exitCode)
        exit $exitCode
    }

    Write-Output ('{0} uninstall completed by PDQ. ExitCode={1}; firewall rule and Intune parity marker cleanup attempted.' -f $script:AppName, $exitCode)
    exit 0
}
catch {
    $msg = Get-ExceptionMessageChain -Exception $_.Exception
    Write-ErrorLog -ErrorMessage $msg -ErrorCode 'UNEXPECTED'
    exit 1
}
