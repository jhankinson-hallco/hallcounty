#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Install-OperativeIQCheckSheet.ps1

.DESCRIPTION
    Installs Operative IQ Check Sheet using the packaged MSI installer.
    
    - Caches MSI to ProgramData for uninstall (avoids product code dependency)
    - Creates a tag file for detection with metadata
    - Logs ONLY on error to C:\IntuneAppLogs\OperativeIQ_CheckSheet_Install.txt

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -File .\Install-OperativeIQCheckSheet.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-OperativeIQCheckSheet.ps1
    Install behavior: System
    
    PACKAGE CONTENTS:
    OperativeIQCheckSheet\
    ├── Install-OperativeIQCheckSheet.ps1
    ├── Uninstall-OperativeIQCheckSheet.ps1
    ├── Detect.ps1
    └── IQCheckSheet.msi
#>

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = 'OperativeIQ_CheckSheet'
$MsiFileName = 'IQCheckSheet.msi'

# Cache location for MSI (used by uninstall)
$CacheDir = Join-Path -Path $env:ProgramData -ChildPath 'OperativeIQ\CheckSheet'

# Detection tag file
$TagDir = Join-Path -Path $env:ProgramData -ChildPath 'IntuneTags'
$TagFile = Join-Path -Path $TagDir -ChildPath 'OperativeIQ_CheckSheet.tag'

# MSI arguments
$MsiInstallArgs = '/qn /norestart'

# Timeout for MSI (seconds)
$MsiTimeoutSeconds = 600

# Logging (error-only)
$LogFolder = 'C:\IntuneAppLogs'
$LogFile = Join-Path -Path $LogFolder -ChildPath "${AppName}_Install.txt"

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_MSI_NOT_FOUND = 70001
$ERR_MSI_FAILED = 70002
$ERR_MSI_TIMEOUT = 70003
$ERR_GENERAL = 70099

# =============================================================================
# END CONFIGURATION
# =============================================================================

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS (Error-only)
#--------------------------------------------------------------------------------
$script:LogInitialized = $false

function Initialize-ErrorLog {
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

function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    
    try {
        Initialize-ErrorLog
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $LogFile -Value "[$Timestamp] $Message"
    }
    catch { }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Message
    )
    
    Write-ErrorLog -Message "ERROR ($ExitCode): $Message"
    exit $ExitCode
}

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
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Get-MsiProductVersion {
    param([Parameter(Mandatory)][string]$Path)
    
    try {
        $Installer = New-Object -ComObject WindowsInstaller.Installer
        $Database = $Installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $Installer, @($Path, 0))
        $View = $Database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $Database, @("SELECT Value FROM Property WHERE Property='ProductVersion'"))
        $View.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $View, $null) | Out-Null
        $Record = $View.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $View, $null)
        
        if ($null -ne $Record) {
            return $Record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 1)
        }
    }
    catch {
        return $null
    }
    
    return $null
}

function Invoke-MsiInstall {
    param([Parameter(Mandatory)][string]$MsiPath)
    
    $TempMsiLog = Join-Path -Path $env:TEMP -ChildPath "${AppName}_MSI.log"
    
    # Remove old temp log if exists
    if (Test-Path -LiteralPath $TempMsiLog) {
        Remove-Item -LiteralPath $TempMsiLog -Force -ErrorAction SilentlyContinue
    }
    
    $MsiArguments = "/i `"$MsiPath`" $MsiInstallArgs /L*v `"$TempMsiLog`""
    
    try {
        $Process = Start-Process -FilePath 'msiexec.exe' `
                                 -ArgumentList $MsiArguments `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -ErrorAction Stop
        
        $Completed = $Process.WaitForExit($MsiTimeoutSeconds * 1000)
        
        if (-not $Completed) {
            try { $Process.Kill() } catch { }
            
            # Persist MSI log on timeout
            if (Test-Path -LiteralPath $TempMsiLog) {
                Initialize-ErrorLog
                $DestLog = Join-Path -Path $LogFolder -ChildPath "${AppName}_MSI.log"
                Copy-Item -LiteralPath $TempMsiLog -Destination $DestLog -Force -ErrorAction SilentlyContinue
            }
            
            return @{ ExitCode = -1; TimedOut = $true }
        }
        
        $ExitCode = $Process.ExitCode
    }
    catch {
        return @{ ExitCode = -1; TimedOut = $false; Error = $_.Exception.Message }
    }
    
    # Success codes: 0, 3010 (reboot required), 1641 (reboot initiated)
    if ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq 1641) {
        # Remove temp MSI log on success
        if (Test-Path -LiteralPath $TempMsiLog) {
            Remove-Item -LiteralPath $TempMsiLog -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        # Persist MSI log on failure
        if (Test-Path -LiteralPath $TempMsiLog) {
            try {
                Initialize-ErrorLog
                $DestLog = Join-Path -Path $LogFolder -ChildPath "${AppName}_MSI.log"
                Copy-Item -LiteralPath $TempMsiLog -Destination $DestLog -Force
            }
            catch { }
        }
    }
    
    return @{ ExitCode = $ExitCode; TimedOut = $false }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # STEP 1: Verify MSI exists in package
    $MsiSource = Join-Path -Path $PSScriptRoot -ChildPath $MsiFileName
    
    if (-not (Test-Path -LiteralPath $MsiSource -PathType Leaf)) {
        Exit-WithError -ExitCode $ERR_MSI_NOT_FOUND -Message "MSI not found in package: $MsiSource"
    }
    
    # STEP 2: Create cache directory and copy MSI
    if (-not (Test-Path -LiteralPath $CacheDir)) {
        New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null
    }
    
    $MsiCached = Join-Path -Path $CacheDir -ChildPath $MsiFileName
    Copy-Item -LiteralPath $MsiSource -Destination $MsiCached -Force
    
    # STEP 3: Run MSI install
    $Result = Invoke-MsiInstall -MsiPath $MsiCached
    
    if ($Result.TimedOut) {
        Exit-WithError -ExitCode $ERR_MSI_TIMEOUT -Message "MSI install timed out after $MsiTimeoutSeconds seconds"
    }
    
    $MsiExitCode = $Result.ExitCode
    
    if ($MsiExitCode -ne 0 -and $MsiExitCode -ne 3010 -and $MsiExitCode -ne 1641) {
        Exit-WithError -ExitCode $ERR_MSI_FAILED -Message "MSI install failed with exit code: $MsiExitCode"
    }
    
    # STEP 4: Create detection tag file
    if (-not (Test-Path -LiteralPath $TagDir)) {
        New-Item -Path $TagDir -ItemType Directory -Force | Out-Null
    }
    
    $ProductVersion = Get-MsiProductVersion -Path $MsiCached
    
    $TagContent = @(
        "AppName=$AppName"
        "InstalledUtc=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        "MsiFile=$MsiFileName"
        "MsiProductVersion=$(if ($ProductVersion) { $ProductVersion } else { 'Unknown' })"
        "InstallExitCode=$MsiExitCode"
    )
    
    if (-not (Test-Path -LiteralPath $TagFile)) {
        New-Item -Path $TagFile -ItemType File -Force | Out-Null
    }
    Set-Content -LiteralPath $TagFile -Value $TagContent -Encoding ASCII
    
    # STEP 5: Return appropriate exit code
    # Pass through 3010 so Intune can handle reboot if needed
    if ($MsiExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Exit-WithError -ExitCode $ERR_GENERAL -Message "Unhandled exception: $($_.Exception.Message)"
}
