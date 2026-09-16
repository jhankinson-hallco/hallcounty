#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: uninstalls EV Reach Client.

.DESCRIPTION
    PDQ Deploy uninstallation script. Tandem counterpart of the Intune Win32
    uninstall script Uninstall-EVReachClient.ps1.

    Removes the EV Reach Client MSI by product code. The script first tries to
    discover the installed MSI product code from HKLM uninstall registry entries
    that match current EasyVista and legacy EV/Goverlan display names, then falls
    back to the known product code from the current MSI.

    The uninstall is idempotent: if the Intune detection evidence is already
    absent, the script exits successfully. After a successful MSI exit code, the
    script verifies that the same file-based detection evidence used by Intune is
    no longer present.

    Logging is error-only to:
    C:\IntuneAppLogs\EVReachClient_Uninstall.txt

    MSI verbose logging is written to the process TEMP folder as:
    EVReachClient_MSI_Uninstall.log

    Exit Codes:
        0    = Success (client removed or already absent)
        1605 = Success (MSI product is not installed and detection is absent)
        1614 = Success (MSI product uninstalled and detection is absent)
        3010 = Success (soft reboot required; lingering in-use files are
               tolerated because they clear at restart)
        1641 = Success (installer initiated reboot; lingering in-use files are
               tolerated because they clear at restart)
        1    = PDQ wrapper failure
        Other nonzero MSI exit code = MSI failure

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/07/2026
    Purpose:        Silent PDQ MSI uninstall of EV Reach Client

    CHANGE LOG
    Change: 14/07/2026 - Initial PDQ uninstall release, tandem with Intune Uninstall-EVReachClient.ps1 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running Uninstall-EVReachClient-PDQ.ps1
      Run As:        Deploy User or Local System with local administrator rights
      Success codes: 0, 1605, 1614, 3010, 1641
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName          = 'EVReachClient'
$script:AppVersion       = '1.0.0'
$script:KnownProductCode = '{9B22BBFD-110D-4B2E-AB50-5454C9FA3029}'
$script:TimeoutSeconds   = 300
$script:SuccessCodes     = @(0, 1605, 1614, 3010, 1641)

$script:DisplayNamePatterns = @(
    '*EasyVista Reach Client*',
    '*EV Reach Client*',
    '*Goverlan Client*',
    '*Goverlan Reach Client*',
    '*EV Reach Agents*',
    '*GoverlanAgent*'
)

$script:ProgramFilesX86 = ${env:ProgramFiles(x86)}
if ([string]::IsNullOrWhiteSpace($script:ProgramFilesX86)) {
    $script:ProgramFilesX86 = $env:ProgramFiles
}

$script:DetectionPaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Goverlan Inc\GoverlanAgent\GovAgentx64.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Goverlan Inc\GoverlanAgent\GovAgent.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Goverlan Inc\GoverlanAgent\GovAgentx64.exe'),
    (Join-Path -Path $script:ProgramFilesX86 -ChildPath 'Goverlan Inc\GoverlanAgent\GovAgent.exe')
)

$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$script:LogRoot    = 'C:\IntuneAppLogs'
$script:LogFile    = Join-Path -Path $script:LogRoot -ChildPath ($script:AppName + '_Uninstall.txt')
$script:MsiLogFile = Join-Path -Path $env:TEMP -ChildPath ($script:AppName + '_MSI_Uninstall.log')

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$ErrorCode = 'N/A'
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [v{1}] [PDQ] [{2}] {3}' -f $timestamp, $script:AppVersion, $ErrorCode, $Message
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($script:LogFile, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try {
            [Console]::Error.WriteLine('{0} v{1} - LOGGING FAILED: {2}' -f $script:AppName, $script:AppVersion, $Message)
        }
        catch {
            $null = $_
        }
    }
}


function Stop-WithFailure {
    param(
        [int]$ExitCode,
        [string]$Message,
        [string]$ErrorCode = 'FAILURE'
    )

    Write-ErrorLog -Message $Message -ErrorCode $ErrorCode
    Write-Output $Message
    exit $ExitCode
}


function Get-ExceptionMessageChain {
    param(
        [System.Exception]$Exception
    )

    $messages = New-Object 'System.Collections.Generic.List[string]'
    $current = $Exception

    while ($null -ne $current) {
        $message = $current.Message
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            $message = ($message -replace '(\r\n|\n|\r)+', ' ').Trim()
            if ($messages.Count -eq 0 -or $messages[$messages.Count - 1] -ne $message) {
                [void]$messages.Add($message)
            }
        }
        $current = $current.InnerException
    }

    if ($messages.Count -eq 0) {
        return 'Unknown exception (no message provided).'
    }

    $chain = $messages[0]
    for ($i = 1; $i -lt $messages.Count; $i++) {
        $chain += ' [Inner: {0}]' -f $messages[$i]
    }

    return $chain
}


function Restart-In64BitPowerShellIfNeeded {
    if (-not [Environment]::Is64BitOperatingSystem) {
        return
    }

    if ([Environment]::Is64BitProcess) {
        return
    }

    $sysNativePowerShell = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $sysNativePowerShell -PathType Leaf)) {
        Stop-WithFailure -ExitCode 1 -Message ('Unable to relaunch in 64-bit Windows PowerShell. SysNative path not found: {0}' -f $sysNativePowerShell) -ErrorCode 'PDQ_64BIT_RELAUNCH'
    }

    $arguments = '-NoProfile -ExecutionPolicy Bypass -NonInteractive -File "{0}"' -f $PSCommandPath
    $process = Start-Process -FilePath $sysNativePowerShell -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    exit $process.ExitCode
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


function Get-EVReachDetectedPath {
    foreach ($path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return ''
}


function Test-EVReachInstalled {
    $detectedPath = Get-EVReachDetectedPath
    return (-not [string]::IsNullOrWhiteSpace($detectedPath))
}


function Test-DisplayNameMatch {
    param(
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return $false
    }

    foreach ($pattern in $script:DisplayNamePatterns) {
        if ($DisplayName -like $pattern) {
            return $true
        }
    }

    return $false
}


function Get-EVReachUninstallEntries {
    $entries = New-Object 'System.Collections.Generic.List[object]'

    foreach ($registryPath in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $registryPath)) {
            continue
        }

        $subKeys = @(Get-ChildItem -LiteralPath $registryPath -ErrorAction SilentlyContinue)

        foreach ($subKey in $subKeys) {
            try {
                $properties = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
                $displayNameProperty = $properties.PSObject.Properties['DisplayName']

                if ($null -eq $displayNameProperty) {
                    continue
                }

                $displayName = [string]$displayNameProperty.Value
                if (-not (Test-DisplayNameMatch -DisplayName $displayName)) {
                    continue
                }

                $uninstallString = ''
                $uninstallStringProperty = $properties.PSObject.Properties['UninstallString']
                if ($null -ne $uninstallStringProperty) {
                    $uninstallString = [string]$uninstallStringProperty.Value
                }

                $entry = New-Object psobject -Property @{
                    RegistryPath    = [string]$subKey.PSPath
                    KeyName         = [string]$subKey.PSChildName
                    DisplayName     = $displayName
                    UninstallString = $uninstallString
                }
                [void]$entries.Add($entry)
            }
            catch {
                Write-ErrorLog -Message ('Failed to inspect uninstall registry entry ''{0}'': {1}' -f $subKey.PSPath, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'REGISTRY_READ_WARN'
            }
        }
    }

    return $entries.ToArray()
}


function Get-EVReachProductCode {
    $entries = @(Get-EVReachUninstallEntries)

    foreach ($entry in $entries) {
        if ([string]$entry.KeyName -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') {
            return [string]$entry.KeyName
        }

        if ([string]$entry.UninstallString -match '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') {
            return [string]$Matches[0]
        }
    }

    return $script:KnownProductCode
}


function Invoke-MsiUninstall {
    param(
        [string]$ProductCode
    )

    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $arguments = '/x {0} /qn /norestart /L*v "{1}"' -f $ProductCode, $script:MsiLogFile

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $msiexecPath
    $startInfo.Arguments = $arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $started = $process.Start()
        if (-not $started) {
            throw 'Process.Start() returned False for msiexec.exe without throwing.'
        }

        $hasExited = $process.WaitForExit($script:TimeoutSeconds * 1000)
        if (-not $hasExited) {
            try { $process.Kill() } catch { $null = $_ }
            try { $null = $process.WaitForExit(5000) } catch { $null = $_ }
            throw ('msiexec.exe /x timed out after {0} seconds and was terminated.' -f $script:TimeoutSeconds)
        }

        return [int]$process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

# =============================================================================
# MAIN
# =============================================================================

try {
    Restart-In64BitPowerShellIfNeeded

    if (-not (Test-IsAdministrator)) {
        Stop-WithFailure -ExitCode 1 -Message 'This uninstaller requires an elevated administrative token. In PDQ, run as Deploy User or Local System with local administrator rights.' -ErrorCode 'PERMISSIONS'
    }

    if (-not (Test-EVReachInstalled)) {
        Write-Output 'EV Reach Client is already absent.'
        exit 0
    }

    $productCode = Get-EVReachProductCode
    if ([string]::IsNullOrWhiteSpace($productCode)) {
        Stop-WithFailure -ExitCode 1 -Message 'Unable to resolve an EV Reach Client MSI product code.' -ErrorCode 'PRODUCT_CODE'
    }

    $exitCode = Invoke-MsiUninstall -ProductCode $productCode

    if ($script:SuccessCodes -notcontains $exitCode) {
        Stop-WithFailure -ExitCode $exitCode -Message ('EV Reach Client uninstall failed. msiexec.exe returned {0}. Check {1}.' -f $exitCode, $script:MsiLogFile) -ErrorCode 'MSI_UNINSTALL'
    }

    Start-Sleep -Seconds 5

    $remainingEvidence = New-Object 'System.Collections.Generic.List[string]'
    foreach ($path in $script:DetectionPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            [void]$remainingEvidence.Add(('executable still present: {0}' -f $path))
        }
    }

    if ($remainingEvidence.Count -gt 0) {
        $evidenceText = [string]::Join('; ', $remainingEvidence.ToArray())

        if ($exitCode -in @(3010, 1641)) {
            $message = 'EV Reach Client uninstall returned reboot-required exit code {0}; remaining evidence should clear at restart. {1}' -f $exitCode, $evidenceText
            Write-ErrorLog -Message $message -ErrorCode 'DETECTION_PENDING_REBOOT'
            Write-Output $message
            exit $exitCode
        }

        Stop-WithFailure -ExitCode 1 -Message ('EV Reach Client uninstall returned {0}, but Intune detection evidence still exists: {1}' -f $exitCode, $evidenceText) -ErrorCode 'DETECTION_STILL_PRESENT'
    }

    Write-Output ('EV Reach Client uninstall completed by PDQ. ExitCode={0}; product code={1}.' -f $exitCode, $productCode)
    exit $exitCode
}
catch {
    $message = Get-ExceptionMessageChain -Exception $_.Exception
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected EV Reach Client uninstall error: {0}' -f $message) -ErrorCode 'UNEXPECTED'
}
