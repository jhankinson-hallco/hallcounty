#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Install-VCRedist2017-2022.ps1

.DESCRIPTION
    Installs Microsoft Visual C++ Redistributable (2017-2022 family / v14) x86 and x64 silently.
    
    Expects these files in the SAME folder as this script:
    - vc_redist.x86.exe
    - vc_redist.x64.exe
    
    Logging ONLY on error to: C:\IntuneAppLogs\VCRedist2017-2022_Install.txt
    Detection via marker file: C:\ProgramData\Intune\Markers\VCRedist2017-2022.tag

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-VCRedist2017-2022.ps1
    Install behavior: System
#>

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'VCRedist2017-2022'

$ExeX86 = 'vc_redist.x86.exe'
$ExeX64 = 'vc_redist.x64.exe'

# Standard silent install for vc_redist*.exe
$InstallArgs = '/install /quiet /norestart'

# Timeout per installer (seconds)
$InstallerTimeoutSeconds = 300

# Marker-based detection (file existence)
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'Intune\Markers'
$MarkerFile = Join-Path -Path $MarkerRoot -ChildPath "$AppName.tag"

# Logging
$LogFolder = 'C:\IntuneAppLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

# OOBE/ESP guard
$EnableOobeGuard = $true

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1
$EXIT_RETRY = 1618
$EXIT_REBOOT = 3010

$ERR_INSTALLER_NOT_FOUND = 75001
$ERR_INSTALLER_FAILED = 75002
$ERR_INSTALLER_TIMEOUT = 75003
$ERR_MARKER_FAILED = 75004

# =============================================================================
# END CONFIGURATION
# =============================================================================

#--------------------------------------------------------------------------------
# 64-BIT POWERSHELL RELAUNCH
#--------------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    
    if (Test-Path -LiteralPath $SysNativePwsh) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#--------------------------------------------------------------------------------
$script:LogInitialized = $false

function Initialize-Log {
    if ($script:LogInitialized) { return }
    
    try {
        if (-not (Test-Path -LiteralPath $LogFolder)) {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
        $script:LogInitialized = $true
    }
    catch {
        $script:LogInitialized = $true
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Level = 'INFO'
    )
    
    try {
        Initialize-Log
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $LogFile -Value "[$Timestamp] [$Level] $Message"
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message
    )
    
    Write-Log -Message "FATAL: $Message (ExitCode: $ExitCode)" -Level 'ERROR'
    Write-Log -Message "Script: $PSCommandPath" -Level 'ERROR'
    Write-Log -Message "PSScriptRoot: $PSScriptRoot" -Level 'ERROR'
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Test-IsOobeLikelyActive {
    $OobeProcessNames = @(
        'CloudExperienceHostBroker',
        'CloudExperienceHost',
        'UserOOBEBroker',
        'DeviceEnroller'
    )
    
    foreach ($ProcessName in $OobeProcessNames) {
        if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    return $false
}

function Invoke-VcRedistInstall {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$Arguments,
        [Parameter(Mandatory)][string]$Architecture
    )
    
    Write-Log "Installing $Architecture redistributable: $ExePath"
    
    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        throw "Installer not found: $ExePath"
    }
    
    try {
        $Process = Start-Process -FilePath $ExePath `
                                 -ArgumentList $Arguments `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -ErrorAction Stop
        
        $Completed = $Process.WaitForExit($InstallerTimeoutSeconds * 1000)
        
        if (-not $Completed) {
            try { $Process.Kill() } catch { }
            throw "Installer timed out after $InstallerTimeoutSeconds seconds"
        }
        
        $ExitCode = $Process.ExitCode
        Write-Log "$Architecture installer exit code: $ExitCode"
        
        switch ($ExitCode) {
            0           { return 0 }       # Success
            3010        { return 3010 }    # Success, reboot required
            1638        { 
                Write-Log "$Architecture: Another version already installed (1638)"
                return 0 
            }
            -2147023290 { 
                Write-Log "$Architecture: Another version already installed (0x80070666)"
                return 0 
            }
            default     { throw "Installer returned exit code: $ExitCode" }
        }
    }
    catch {
        throw "$Architecture install failed: $($_.Exception.Message)"
    }
}

function Set-Marker {
    param(
        [Parameter(Mandatory)][string]$Content
    )
    
    if (-not (Test-Path -LiteralPath $MarkerRoot)) {
        New-Item -Path $MarkerRoot -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path -LiteralPath $MarkerFile)) {
        New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
    }
    
    Set-Content -LiteralPath $MarkerFile -Value $Content -Force
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

# Always log start (helps diagnose "silent" failures)
Write-Log "========== VCRedist Install Started =========="
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "User: $env:USERNAME"
Write-Log "PSScriptRoot: $PSScriptRoot"
Write-Log "Is64BitOS: $([Environment]::Is64BitOperatingSystem)"
Write-Log "Is64BitProcess: $([Environment]::Is64BitProcess)"

try {
    # OOBE Guard
    if ($EnableOobeGuard -and (Test-IsOobeLikelyActive)) {
        Write-Log "OOBE processes detected, returning RETRY (1618)" -Level 'WARN'
        exit $EXIT_RETRY
    }
    
    # Verify installers exist BEFORE attempting install
    $PathX86 = Join-Path -Path $PSScriptRoot -ChildPath $ExeX86
    $PathX64 = Join-Path -Path $PSScriptRoot -ChildPath $ExeX64
    
    Write-Log "x86 installer path: $PathX86"
    Write-Log "x64 installer path: $PathX64"
    
    # List package contents for troubleshooting
    $PackageContents = Get-ChildItem -LiteralPath $PSScriptRoot -Force -ErrorAction SilentlyContinue | 
                       Select-Object -ExpandProperty Name
    Write-Log "Package contents: $($PackageContents -join ', ')"
    
    if (-not (Test-Path -LiteralPath $PathX86 -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_INSTALLER_NOT_FOUND -Message "x86 installer not found: $PathX86"
    }
    
    $Is64BitOS = [Environment]::Is64BitOperatingSystem
    
    if ($Is64BitOS) {
        if (-not (Test-Path -LiteralPath $PathX64 -PathType Leaf)) {
            Exit-WithError -ExitCode $ERR_INSTALLER_NOT_FOUND -Message "x64 installer not found: $PathX64"
        }
    }
    
    # Install x64 first on 64-bit OS, then x86
    $X64Exit = $null
    $X86Exit = $null
    
    if ($Is64BitOS) {
        try {
            $X64Exit = Invoke-VcRedistInstall -ExePath $PathX64 -Arguments $InstallArgs -Architecture 'x64'
        }
        catch {
            Exit-WithError -ExitCode $ERR_INSTALLER_FAILED -Message "x64 install failed: $($_.Exception.Message)"
        }
    }
    
    try {
        $X86Exit = Invoke-VcRedistInstall -ExePath $PathX86 -Arguments $InstallArgs -Architecture 'x86'
    }
    catch {
        Exit-WithError -ExitCode $ERR_INSTALLER_FAILED -Message "x86 install failed: $($_.Exception.Message)"
    }
    
    # Create marker file
    $MarkerContent = @(
        "Installed=True"
        "UTC=$((Get-Date).ToUniversalTime().ToString('o'))"
        "Computer=$env:COMPUTERNAME"
        "Is64BitOS=$Is64BitOS"
        "X64Result=$X64Exit"
        "X86Result=$X86Exit"
    ) -join "`r`n"
    
    try {
        Set-Marker -Content $MarkerContent
        Write-Log "Marker file created: $MarkerFile"
    }
    catch {
        Exit-WithError -ExitCode $ERR_MARKER_FAILED -Message "Failed to create marker: $($_.Exception.Message)"
    }
    
    # Verify marker exists
    if (-not (Test-Path -LiteralPath $MarkerFile -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_MARKER_FAILED -Message "Marker file not found after creation: $MarkerFile"
    }
    
    Write-Log "========== VCRedist Install Completed Successfully =========="
    
    # If either install indicates reboot required, return 3010
    if ($X86Exit -eq 3010 -or $X64Exit -eq 3010) {
        Write-Log "Reboot required (3010)"
        exit $EXIT_REBOOT
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Write-Log "UNHANDLED EXCEPTION: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "STACK: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit $EXIT_FAILURE
}
