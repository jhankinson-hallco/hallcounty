#requires -version 5.1

<#
.SYNOPSIS
    Install-VCRedist2017-2022.ps1

.DESCRIPTION
    Installs Microsoft Visual C++ Redistributable 2017-2022 (x64 and x86).
    Expects vc_redist.x64.exe and vc_redist.x86.exe in the same folder as this script.

.NOTES
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-VCRedist2017-2022.ps1
    Uninstall Cmd:  cmd.exe /c exit 0
    Install behavior: System
    Device restart: Determine behavior based on return codes
#>

$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION
# =============================================================================

$AppName = 'VCRedist2017-2022'
$ExeX86 = 'vc_redist.x86.exe'
$ExeX64 = 'vc_redist.x64.exe'
$InstallArgs = '/install /quiet /norestart'
$TimeoutSeconds = 600

$LogFolder = 'C:\IntuneAppLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

# =============================================================================
# INITIALIZE LOGGING IMMEDIATELY
# =============================================================================

try {
    if (-not (Test-Path -LiteralPath $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
}
catch {
    # Can't create log folder - try alternate location
    $LogFolder = $env:TEMP
    $LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$Timestamp] $Message"
    try {
        Add-Content -Path $LogFile -Value $Line -ErrorAction Stop
    }
    catch {
        # Last resort - write to temp
        Add-Content -Path "$env:TEMP\${AppName}_Install.txt" -Value $Line -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# LOG STARTUP INFO
# =============================================================================

Write-Log "========== $AppName Install Started =========="
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "User: $env:USERNAME"
Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
Write-Log "64-bit OS: $([Environment]::Is64BitOperatingSystem)"
Write-Log "64-bit Process: $([Environment]::Is64BitProcess)"
Write-Log "PSScriptRoot: $PSScriptRoot"
Write-Log "PSCommandPath: $PSCommandPath"

# =============================================================================
# 64-BIT RELAUNCH
# =============================================================================

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Log "Relaunching as 64-bit process..."
    
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    
    if (Test-Path -LiteralPath $SysNativePwsh) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        Write-Log "64-bit process exited with code: $($Process.ExitCode)"
        exit $Process.ExitCode
    }
    else {
        Write-Log "WARNING: Sysnative path not found, continuing as 32-bit"
    }
}

# =============================================================================
# VERIFY INSTALLERS EXIST
# =============================================================================

Write-Log "Checking for installers in package..."

$PathX86 = Join-Path -Path $PSScriptRoot -ChildPath $ExeX86
$PathX64 = Join-Path -Path $PSScriptRoot -ChildPath $ExeX64

# List all files in package folder
try {
    $PackageFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Force -ErrorAction Stop | Select-Object -ExpandProperty Name
    Write-Log "Package contents: $($PackageFiles -join ', ')"
}
catch {
    Write-Log "ERROR: Failed to list package contents: $($_.Exception.Message)"
}

# Check x86
if (Test-Path -LiteralPath $PathX86 -PathType Leaf) {
    $FileInfo = Get-Item -LiteralPath $PathX86
    Write-Log "Found x86: $PathX86 (Size: $($FileInfo.Length) bytes)"
}
else {
    Write-Log "ERROR: x86 installer NOT FOUND: $PathX86"
    exit 75001
}

# Check x64
if ([Environment]::Is64BitOperatingSystem) {
    if (Test-Path -LiteralPath $PathX64 -PathType Leaf) {
        $FileInfo = Get-Item -LiteralPath $PathX64
        Write-Log "Found x64: $PathX64 (Size: $($FileInfo.Length) bytes)"
    }
    else {
        Write-Log "ERROR: x64 installer NOT FOUND: $PathX64"
        exit 75001
    }
}

# =============================================================================
# INSTALL FUNCTION
# =============================================================================

function Install-VCRedist {
    param(
        [string]$InstallerPath,
        [string]$Architecture
    )
    
    Write-Log "Installing $Architecture..."
    Write-Log "Command: $InstallerPath $InstallArgs"
    
    try {
        $Process = Start-Process -FilePath $InstallerPath `
                                 -ArgumentList $InstallArgs `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -ErrorAction Stop
        
        Write-Log "$Architecture process started (PID: $($Process.Id))"
        
        $Completed = $Process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $Completed) {
            Write-Log "ERROR: $Architecture installer timed out after $TimeoutSeconds seconds"
            try { $Process.Kill() } catch { }
            return -1
        }
        
        $ExitCode = $Process.ExitCode
        Write-Log "$Architecture installer exit code: $ExitCode"
        
        return $ExitCode
    }
    catch {
        Write-Log "ERROR: Failed to start $Architecture installer: $($_.Exception.Message)"
        return -1
    }
}

function Test-VCRedistExitCode {
    param([int]$ExitCode, [string]$Architecture)
    
    switch ($ExitCode) {
        0           { Write-Log "$Architecture : Success"; return 0 }
        3010        { Write-Log "$Architecture : Success (reboot required)"; return 3010 }
        1638        { Write-Log "$Architecture : Already installed (1638)"; return 0 }
        -2147023290 { Write-Log "$Architecture : Already installed (0x80070666)"; return 0 }
        1641        { Write-Log "$Architecture : Success (reboot initiated)"; return 1641 }
        default     { 
            Write-Log "ERROR: $Architecture failed with exit code: $ExitCode"
            return $ExitCode
        }
    }
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

$RebootRequired = $false
$FailedInstall = $false

# Install x64 first (on 64-bit OS)
if ([Environment]::Is64BitOperatingSystem) {
    $RawExitCode = Install-VCRedist -InstallerPath $PathX64 -Architecture "x64"
    $NormalizedCode = Test-VCRedistExitCode -ExitCode $RawExitCode -Architecture "x64"
    
    if ($NormalizedCode -eq 3010 -or $NormalizedCode -eq 1641) {
        $RebootRequired = $true
    }
    elseif ($NormalizedCode -ne 0) {
        $FailedInstall = $true
    }
}

# Install x86
if (-not $FailedInstall) {
    $RawExitCode = Install-VCRedist -InstallerPath $PathX86 -Architecture "x86"
    $NormalizedCode = Test-VCRedistExitCode -ExitCode $RawExitCode -Architecture "x86"
    
    if ($NormalizedCode -eq 3010 -or $NormalizedCode -eq 1641) {
        $RebootRequired = $true
    }
    elseif ($NormalizedCode -ne 0) {
        $FailedInstall = $true
    }
}

# =============================================================================
# EXIT
# =============================================================================

if ($FailedInstall) {
    Write-Log "========== $AppName Install FAILED =========="
    exit 75002
}

if ($RebootRequired) {
    Write-Log "========== $AppName Install Completed (Reboot Required) =========="
    exit 3010
}

Write-Log "========== $AppName Install Completed Successfully =========="
exit 0
