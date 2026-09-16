#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Uninstall-VCRedist2017-2022.ps1
- Uninstalls vc_redist.x86.exe and vc_redist.x64.exe silently (when applicable).
- Logging ONLY on error to: C:\IntuneAppLogs\VCRedist2017-2022_Uninstall.txt
- Removes marker file upon success.
#>

# ============================
# CONFIG (CHANGE ONLY HERE)
# ============================
$AppName       = 'VCRedist2017-2022'

$ExeX86        = 'vc_redist.x86.exe'
$ExeX64        = 'vc_redist.x64.exe'

$UninstallArgs = '/uninstall /quiet /norestart'

$MarkerRoot    = Join-Path $env:ProgramData 'Intune\Markers'
$MarkerFile    = Join-Path $MarkerRoot "$AppName.tag"
# ============================

function New-ErrorLogFile {
    param(
        [Parameter(Mandatory=$true)][string]$AppName,
        [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall','Detect')][string]$Phase
    )

    $logDir = 'C:\IntuneAppLogs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $logPath = Join-Path $logDir ("{0}_{1}.txt" -f $AppName, $Phase)

    if (-not (Test-Path -LiteralPath $logPath)) {
        New-Item -Path $logPath -ItemType File -Force | Out-Null
    }

    return $logPath
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)][string]$LogPath,
        [Parameter(Mandatory=$true)][string]$Message
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $LogPath -Value ("[{0}] {1}" -f $timestamp, $Message)
}

function Invoke-VcRedistUninstall {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [Parameter(Mandatory=$true)][string]$Arguments
    )

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Uninstall binary not found in package: $ExePath"
    }

    $p = Start-Process -FilePath $ExePath -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    $code = [int]$p.ExitCode

    # Treat “already not present” results as success where they occur.
    switch ($code) {
        0          { return 0 }
        3010       { return 3010 }
        1638       { return 0 }
        -2147023290{ return 0 }
        default    { throw "vc_redist uninstall failed: $ExePath returned exit code $code" }
    }
}

try {
    $is64BitOS = [Environment]::Is64BitOperatingSystem

    $pathX86 = Join-Path $PSScriptRoot $ExeX86
    $pathX64 = Join-Path $PSScriptRoot $ExeX64

    $x64Exit = $null
    if ($is64BitOS) {
        $x64Exit = Invoke-VcRedistUninstall -ExePath $pathX64 -Arguments $UninstallArgs
    }

    $x86Exit = Invoke-VcRedistUninstall -ExePath $pathX86 -Arguments $UninstallArgs

    # Remove marker LAST
    if (Test-Path -LiteralPath $MarkerFile) {
        Remove-Item -LiteralPath $MarkerFile -Force
    }

    # If either uninstall indicates reboot required, bubble 3010
    if ($x86Exit -eq 3010 -or $x64Exit -eq 3010) { exit 3010 }

    exit 0
}
catch {
    $logPath = New-ErrorLogFile -AppName $AppName -Phase 'Uninstall'
    Write-ErrorLog -LogPath $logPath -Message "ERROR: $($_.Exception.Message)"
    Write-ErrorLog -LogPath $logPath -Message "SCRIPT: $($MyInvocation.MyCommand.Path)"
    Write-ErrorLog -LogPath $logPath -Message "STACK: $($_.ScriptStackTrace)"
    exit 1
}