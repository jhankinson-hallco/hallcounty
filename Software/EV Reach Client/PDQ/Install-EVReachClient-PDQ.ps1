#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PDQ deployment: installs EV Reach Client machine-wide.

.DESCRIPTION
    PDQ Deploy installation script. Tandem counterpart of the Intune Win32 app
    Install-EVReachClient.ps1. Pulls EVReachClient64.msi from the shared
    deployment repository on the filestore instead of a bundled Intune package.

    The MSI is copied to a local ProgramData staging folder before msiexec.exe
    is invoked. The staged MSI is removed after the install attempt. Scripts and
    markdown remain in the PDQ folder; only payload files belong on the filestore.

    TANDEM PARITY: the final on-device state must satisfy the Intune Detect.ps1
    script, which checks for GovAgentx64.exe or GovAgent.exe under:
      - C:\Program Files\Goverlan Inc\GoverlanAgent
      - C:\Program Files (x86)\Goverlan Inc\GoverlanAgent

    Logging is error-only to:
    C:\IntuneAppLogs\EVReachClient_Install.txt

    MSI verbose logging is written to the process TEMP folder as:
    EVReachClient_MSI_Install.log

    Exit Codes:
        0    = Success (installed or already detected)
        1707 = Success (MSI reported installation completed)
        3010 = Success (soft reboot required)
        1641 = Success (installer initiated reboot)
        1    = PDQ wrapper failure
        Other nonzero MSI exit code = MSI failure

.NOTES
    Version:        1.0.0
    Script Type:    PDQ Deploy Package (tandem with Intune Win32 app)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/07/2026
    Purpose:        Silent PDQ MSI install of EV Reach Client

    CHANGE LOG
    Change: 14/07/2026 - Initial PDQ release, tandem with Intune Install-EVReachClient.ps1 -- ver. 1.0.0

    PDQ CONFIGURATION
      Package step:  PowerShell step running Install-EVReachClient-PDQ.ps1
      Run As:        Deploy User (requires READ access to the filestore repository
                     and local administrator rights)
      Success codes: 0, 1707, 3010, 1641

    REPOSITORY (PDQ scripts only; Intune scripts must never touch the filestore)
      MSI folder: \\hallcounty\filestore\mis\CDS\Intune Management Applications\EV Reach Client
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppName             = 'EVReachClient'
$script:AppVersion          = '1.0.0'
$script:RepositoryRoot      = '\\hallcounty\filestore\mis\CDS\Intune Management Applications\EV Reach Client'
$script:InstallerFileName   = 'EVReachClient64.msi'
$script:StageRoot           = 'C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\EVReachClientPDQ'
$script:TimeoutSeconds      = 300
$script:MsiParameters       = @('/qn', '/norestart', 'ALLUSERS=1')
$script:SuccessExitCodes    = @(0, 1707, 3010, 1641)

# MSI metadata from the current source MSI on 2026-07-14.
$script:MsiProductName      = 'EasyVista Reach Client v11 (x64)'
$script:MsiProductVersion   = '11.0.11'
$script:MsiProductCode      = '{9B22BBFD-110D-4B2E-AB50-5454C9FA3029}'

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

$script:LogRoot    = 'C:\IntuneAppLogs'
$script:LogFile    = Join-Path -Path $script:LogRoot -ChildPath ($script:AppName + '_Install.txt')
$script:MsiLogFile = Join-Path -Path $env:TEMP -ChildPath ($script:AppName + '_MSI_Install.log')

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


function Copy-MsiToLocalStage {
    $sourceMsiPath = Join-Path -Path $script:RepositoryRoot -ChildPath $script:InstallerFileName
    $stagedMsiPath = Join-Path -Path $script:StageRoot -ChildPath $script:InstallerFileName

    if (-not (Test-Path -LiteralPath $script:RepositoryRoot -PathType Container)) {
        Stop-WithFailure -ExitCode 1 -Message ('EV Reach repository folder not found or not reachable: ''{0}''. Verify the PDQ Deploy User can read the filestore path.' -f $script:RepositoryRoot) -ErrorCode 'REPOSITORY_NOT_FOUND'
    }

    if (-not (Test-Path -LiteralPath $sourceMsiPath -PathType Leaf)) {
        Stop-WithFailure -ExitCode 1 -Message ('EV Reach source MSI not found: ''{0}''.' -f $sourceMsiPath) -ErrorCode 'MSI_NOT_FOUND'
    }

    try {
        [void][System.IO.Directory]::CreateDirectory($script:StageRoot)
    }
    catch {
        Stop-WithFailure -ExitCode 1 -Message ('Failed to create local MSI staging folder ''{0}'': {1}' -f $script:StageRoot, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'STAGE_CREATE'
    }

    try {
        Copy-Item -LiteralPath $sourceMsiPath -Destination $stagedMsiPath -Force -ErrorAction Stop
    }
    catch {
        Stop-WithFailure -ExitCode 1 -Message ('Failed to copy EV Reach MSI from repository to local stage. Source=''{0}'' Destination=''{1}'' Error={2}' -f $sourceMsiPath, $stagedMsiPath, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'MSI_COPY'
    }

    if (-not (Test-Path -LiteralPath $stagedMsiPath -PathType Leaf)) {
        Stop-WithFailure -ExitCode 1 -Message ('Local MSI staging verification failed. File not found at ''{0}'' after copy.' -f $stagedMsiPath) -ErrorCode 'MSI_STAGE_VERIFY'
    }

    return $stagedMsiPath
}


function Remove-StagedMsi {
    param(
        [string]$StagedMsiPath
    )

    try {
        if (-not [string]::IsNullOrWhiteSpace($StagedMsiPath) -and (Test-Path -LiteralPath $StagedMsiPath -PathType Leaf)) {
            Remove-Item -LiteralPath $StagedMsiPath -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ErrorLog -Message ('Failed to remove staged EV Reach MSI ''{0}'': {1}' -f $StagedMsiPath, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'STAGE_CLEANUP_WARN'
    }

    try {
        if (Test-Path -LiteralPath $script:StageRoot -PathType Container) {
            $remaining = @(Get-ChildItem -LiteralPath $script:StageRoot -Force -ErrorAction SilentlyContinue)
            if ($remaining.Count -eq 0) {
                Remove-Item -LiteralPath $script:StageRoot -Force -ErrorAction Stop
            }
        }
    }
    catch {
        Write-ErrorLog -Message ('Failed to remove empty EV Reach staging folder ''{0}'': {1}' -f $script:StageRoot, (Get-ExceptionMessageChain -Exception $_.Exception)) -ErrorCode 'STAGE_FOLDER_CLEANUP_WARN'
    }
}


function Invoke-MsiInstall {
    param(
        [string]$MsiPath
    )

    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $arguments = '/i "{0}" {1} /L*v "{2}"' -f $MsiPath, ([string]::Join(' ', $script:MsiParameters)), $script:MsiLogFile

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
            throw ('msiexec.exe /i timed out after {0} seconds and was terminated.' -f $script:TimeoutSeconds)
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
        Stop-WithFailure -ExitCode 1 -Message 'This installer requires an elevated administrative token. In PDQ, run as Deploy User with local administrator rights and read access to the EV Reach filestore repository.' -ErrorCode 'PERMISSIONS'
    }

    $detectedPath = Get-EVReachDetectedPath
    if (-not [string]::IsNullOrWhiteSpace($detectedPath)) {
        Write-Output ('EV Reach Client already detected by PDQ: {0}' -f $detectedPath)
        exit 0
    }

    $stagedMsiPath = ''
    try {
        $stagedMsiPath = Copy-MsiToLocalStage
        $exitCode = Invoke-MsiInstall -MsiPath $stagedMsiPath
    }
    finally {
        Remove-StagedMsi -StagedMsiPath $stagedMsiPath
    }

    if ($script:SuccessExitCodes -notcontains $exitCode) {
        Stop-WithFailure -ExitCode $exitCode -Message ('EV Reach Client installer returned exit code {0}. Check {1}.' -f $exitCode, $script:MsiLogFile) -ErrorCode 'MSI_INSTALL'
    }

    Start-Sleep -Seconds 5

    $detectedPath = Get-EVReachDetectedPath
    if ([string]::IsNullOrWhiteSpace($detectedPath)) {
        Stop-WithFailure -ExitCode 1 -Message ('EV Reach Client installer returned {0}, but Intune detection evidence was not found. Expected one of: {1}' -f $exitCode, ([string]::Join('; ', $script:DetectionPaths))) -ErrorCode 'DETECTION_FAILED'
    }

    Write-Output ('EV Reach Client {0} installed by PDQ. ExitCode={1}; detected at {2}.' -f $script:MsiProductVersion, $exitCode, $detectedPath)
    exit $exitCode
}
catch {
    $message = Get-ExceptionMessageChain -Exception $_.Exception
    Stop-WithFailure -ExitCode 1 -Message ('Unexpected EV Reach Client install error: {0}' -f $message) -ErrorCode 'UNEXPECTED'
}
