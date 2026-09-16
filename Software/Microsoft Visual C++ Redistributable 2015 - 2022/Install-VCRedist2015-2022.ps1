<#
.SYNOPSIS
    Install-VCRedist2015-2022.ps1

.DESCRIPTION
    Installs Microsoft Visual C++ Redistributable 2015-2022 (x64 and x86) by downloading
    the official installers directly from Microsoft.
    
    This approach is MORE RELIABLE than winget for Intune/SYSTEM context deployments
    because winget can have issues running as SYSTEM (0xC000007B errors, etc.)
    
    This package covers runtimes for:
    - Visual Studio 2015
    - Visual Studio 2017
    - Visual Studio 2019
    - Visual Studio 2022

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Install Cmd:    powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-VCRedist2015-2022.ps1
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-VCRedist2015-2022.ps1
    Install behavior: System
    
    DOWNLOAD URLS:
    These are the official Microsoft download URLs for the latest VC++ Redist.
    They redirect to the current version automatically.
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "VCRedist2015-2022"

# Official Microsoft download URLs (these redirect to latest version)
$DownloadUrlX64 = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$DownloadUrlX86 = "https://aka.ms/vs/17/release/vc_redist.x86.exe"

# Local download paths
$TempFolder = Join-Path -Path $env:TEMP -ChildPath "VCRedist_Install"
$InstallerX64 = Join-Path -Path $TempFolder -ChildPath "vc_redist.x64.exe"
$InstallerX86 = Join-Path -Path $TempFolder -ChildPath "vc_redist.x86.exe"

# Silent install parameters for VC++ Redist EXE
# /install = install mode
# /quiet = no UI
# /norestart = don't reboot
$InstallParams = "/install /quiet /norestart"

# Detection paths - vcruntime140.dll is the primary runtime DLL
$DetectionPathX64 = "${env:SystemRoot}\System32\vcruntime140.dll"
$DetectionPathX86 = "${env:SystemRoot}\SysWOW64\vcruntime140.dll"

# Installation timeout (seconds)
$InstallTimeoutSeconds = 300

# Logging (error-only)
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Install.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

$ERR_DOWNLOAD_FAILED_X64 = 77001
$ERR_DOWNLOAD_FAILED_X86 = 77002
$ERR_INSTALL_FAILED_X64 = 77003
$ERR_INSTALL_FAILED_X86 = 77004
$ERR_DETECTION_FAILED = 77005
$ERR_INSTALL_TIMEOUT = 77006

# =============================================================================
# END CONFIGURATION
# =============================================================================

#--------------------------------------------------------------------------------
# 64-BIT POWERSHELL RELAUNCH
#--------------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $SysNativePwsh = Join-Path -Path $env:WINDIR -ChildPath "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    
    if (Test-Path -LiteralPath $SysNativePwsh -PathType Leaf) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Process = Start-Process -FilePath $SysNativePwsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        exit $Process.ExitCode
    }
}

#--------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#--------------------------------------------------------------------------------
function Write-ErrorLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $LogFilePath -Value "[$Timestamp] $Message" -ErrorAction Stop
    }
    catch {
        Write-Error "LOGGING FAILED: $Message"
    }
}

function Exit-WithError {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$InstallerExitCode = ""
    )
    
    Write-ErrorLog -Message "========== INSTALLATION FAILED =========="
    Write-ErrorLog -Message "Error Code: $ExitCode"
    Write-ErrorLog -Message "Error Message: $Message"
    Write-ErrorLog -Message "Computer Name: $env:COMPUTERNAME"
    Write-ErrorLog -Message "Script Path: $PSCommandPath"
    
    if ($InstallerExitCode -ne "") {
        Write-ErrorLog -Message "Installer Exit Code: $InstallerExitCode"
        
        # Decode common VC++ Redist exit codes
        $ExitCodeMeaning = switch ($InstallerExitCode) {
            "0" { "Success" }
            "1638" { "Another version already installed" }
            "3010" { "Reboot required" }
            "5100" { "System does not meet requirements" }
            "1603" { "Fatal error during installation" }
            "-2147023293" { "Generic failure (0x80070643)" }
            default { "See Microsoft documentation" }
        }
        Write-ErrorLog -Message "Exit Code Meaning: $ExitCodeMeaning"
    }
    
    Write-ErrorLog -Message "Detection Status:"
    Write-ErrorLog -Message "  x64 DLL: $(Test-Path -LiteralPath $DetectionPathX64 -PathType Leaf)"
    Write-ErrorLog -Message "  x86 DLL: $(Test-Path -LiteralPath $DetectionPathX86 -PathType Leaf)"
    Write-ErrorLog -Message "=========================================="
    
    # Cleanup temp folder
    if (Test-Path -LiteralPath $TempFolder -PathType Container) {
        Remove-Item -LiteralPath $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Error "ERROR $ExitCode : $Message"
    exit $ExitCode
}

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Test-VCRedistInstalled {
    $X64Installed = Test-Path -LiteralPath $DetectionPathX64 -PathType Leaf
    $X86Installed = Test-Path -LiteralPath $DetectionPathX86 -PathType Leaf
    
    if ([Environment]::Is64BitOperatingSystem) {
        return ($X64Installed -and $X86Installed)
    }
    else {
        return $X86Installed
    }
}

function Get-FileFromUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    try {
        # Use BITS for more reliable downloads, fallback to WebClient
        $BitsSupported = Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue
        
        if ($BitsSupported) {
            Start-BitsTransfer -Source $Url -Destination $DestinationPath -ErrorAction Stop
        }
        else {
            # Fallback to .NET WebClient
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($Url, $DestinationPath)
            $WebClient.Dispose()
        }
        
        return (Test-Path -LiteralPath $DestinationPath -PathType Leaf)
    }
    catch {
        Write-ErrorLog -Message "Download failed from $Url : $($_.Exception.Message)"
        return $false
    }
}

function Install-VCRedistPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Architecture
    )
    
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        return @{
            ExitCode = -1
            Success  = $false
            Error    = "Installer not found: $InstallerPath"
        }
    }
    
    try {
        $Process = Start-Process -FilePath $InstallerPath `
                                 -ArgumentList $InstallParams `
                                 -Wait:$false `
                                 -PassThru `
                                 -WindowStyle Hidden
        
        $Completed = $Process.WaitForExit($InstallTimeoutSeconds * 1000)
        
        if (-not $Completed) {
            try { $Process.Kill() } catch { }
            return @{
                ExitCode = -999
                Success  = $false
                Error    = "Installation timed out after $InstallTimeoutSeconds seconds"
            }
        }
        
        # Exit codes: 0 = success, 1638 = already installed, 3010 = reboot required
        $Success = $Process.ExitCode -in @(0, 1638, 3010)
        
        return @{
            ExitCode = $Process.ExitCode
            Success  = $Success
            Error    = if ($Success) { "" } else { "Installer returned exit code $($Process.ExitCode)" }
        }
    }
    catch {
        return @{
            ExitCode = -1
            Success  = $false
            Error    = $_.Exception.Message
        }
    }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # -------------------------------------------------------------------------
    # STEP 1: Check if already installed
    # -------------------------------------------------------------------------
    
    if (Test-VCRedistInstalled) {
        exit $EXIT_SUCCESS
    }
    
    # -------------------------------------------------------------------------
    # STEP 2: Create temp folder
    # -------------------------------------------------------------------------
    
    if (-not (Test-Path -LiteralPath $TempFolder -PathType Container)) {
        New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null
    }
    
    # -------------------------------------------------------------------------
    # STEP 3: Download installers
    # -------------------------------------------------------------------------
    
    # Download x64 (on 64-bit systems)
    if ([Environment]::Is64BitOperatingSystem) {
        $DownloadedX64 = Get-FileFromUrl -Url $DownloadUrlX64 -DestinationPath $InstallerX64
        
        if (-not $DownloadedX64) {
            Exit-WithError -ExitCode $ERR_DOWNLOAD_FAILED_X64 `
                           -Message "Failed to download x64 installer from $DownloadUrlX64"
        }
    }
    
    # Download x86
    $DownloadedX86 = Get-FileFromUrl -Url $DownloadUrlX86 -DestinationPath $InstallerX86
    
    if (-not $DownloadedX86) {
        Exit-WithError -ExitCode $ERR_DOWNLOAD_FAILED_X86 `
                       -Message "Failed to download x86 installer from $DownloadUrlX86"
    }
    
    # -------------------------------------------------------------------------
    # STEP 4: Install x64 version
    # -------------------------------------------------------------------------
    
    if ([Environment]::Is64BitOperatingSystem) {
        $X64Result = Install-VCRedistPackage -InstallerPath $InstallerX64 -Architecture "x64"
        
        if (-not $X64Result.Success) {
            Exit-WithError -ExitCode $ERR_INSTALL_FAILED_X64 `
                           -Message "Failed to install x64 VC++ Redistributable: $($X64Result.Error)" `
                           -InstallerExitCode $X64Result.ExitCode
        }
    }
    
    # -------------------------------------------------------------------------
    # STEP 5: Install x86 version
    # -------------------------------------------------------------------------
    
    $X86Result = Install-VCRedistPackage -InstallerPath $InstallerX86 -Architecture "x86"
    
    if (-not $X86Result.Success) {
        Exit-WithError -ExitCode $ERR_INSTALL_FAILED_X86 `
                       -Message "Failed to install x86 VC++ Redistributable: $($X86Result.Error)" `
                       -InstallerExitCode $X86Result.ExitCode
    }
    
    # -------------------------------------------------------------------------
    # STEP 6: Verify installation
    # -------------------------------------------------------------------------
    
    Start-Sleep -Seconds 3
    
    if (-not (Test-VCRedistInstalled)) {
        Exit-WithError -ExitCode $ERR_DETECTION_FAILED `
                       -Message "Installation completed but VC++ Redistributable DLLs not detected."
    }
    
    # -------------------------------------------------------------------------
    # STEP 7: Cleanup and exit
    # -------------------------------------------------------------------------
    
    # Remove temp folder
    if (Test-Path -LiteralPath $TempFolder -PathType Container) {
        Remove-Item -LiteralPath $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Return 3010 if either installer requested reboot
    if (([Environment]::Is64BitOperatingSystem -and $X64Result.ExitCode -eq 3010) -or $X86Result.ExitCode -eq 3010) {
        exit 3010
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -Message "========== UNEXPECTED ERROR =========="
    Write-ErrorLog -Message "Error: $($_.Exception.Message)"
    Write-ErrorLog -Message "Stack: $($_.ScriptStackTrace)"
    Write-ErrorLog -Message "======================================"
    
    # Cleanup
    if (Test-Path -LiteralPath $TempFolder -PathType Container) {
        Remove-Item -LiteralPath $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Error $_.Exception.Message
    exit $EXIT_FAILURE
}