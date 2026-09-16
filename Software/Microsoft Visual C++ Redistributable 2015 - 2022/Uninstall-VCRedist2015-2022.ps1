<#
.SYNOPSIS
    Uninstall-VCRedist2015-2022.ps1

.DESCRIPTION
    Uninstalls Microsoft Visual C++ Redistributable 2015-2022 (x64 and x86) using winget.
    
    WARNING: Uninstalling VC++ Redistributables may break applications that depend on them.
    Many applications require these runtimes. Use with caution.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Uninstall Cmd:  powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-VCRedist2015-2022.ps1
    Install behavior: System
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$AppName = "VCRedist2015-2022"

# Winget package IDs
$PackageIdX64 = "Microsoft.VCRedist.2015+.x64"
$PackageIdX86 = "Microsoft.VCRedist.2015+.x86"

# Detection paths
$DetectionPathX64 = "${env:SystemRoot}\System32\vcruntime140.dll"
$DetectionPathX86 = "${env:SystemRoot}\SysWOW64\vcruntime140.dll"

# Logging
$LogDirectory = "C:\IntuneAppLogs"
$LogFileName = "${AppName}_Uninstall.txt"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

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
    param([Parameter(Mandatory = $true)][string]$Message)
    
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

#--------------------------------------------------------------------------------
# HELPER FUNCTIONS
#--------------------------------------------------------------------------------
function Get-WingetPath {
    $WingetInPath = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue
    if ($WingetInPath) {
        return $WingetInPath.Source
    }
    
    $PossiblePaths = @(
        "${env:ProgramFiles}\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe",
        "${env:LOCALAPPDATA}\Microsoft\WindowsApps\winget.exe",
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    )
    
    foreach ($PathPattern in $PossiblePaths) {
        $ResolvedPaths = Resolve-Path -Path $PathPattern -ErrorAction SilentlyContinue
        if ($ResolvedPaths) {
            $LatestPath = $ResolvedPaths | Sort-Object -Descending | Select-Object -First 1
            if (Test-Path -LiteralPath $LatestPath.Path -PathType Leaf) {
                return $LatestPath.Path
            }
        }
    }
    
    return $null
}

function Uninstall-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath,
        [Parameter(Mandatory = $true)][string]$PackageId
    )
    
    $Arguments = @(
        "uninstall"
        "-e"
        "--id", $PackageId
        "--silent"
        "--accept-source-agreements"
        "--disable-interactivity"
    )
    
    $ArgumentString = $Arguments -join " "
    
    try {
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $WingetPath
        $ProcessInfo.Arguments = $ArgumentString
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null
        
        $StdOut = $Process.StandardOutput.ReadToEnd()
        $StdErr = $Process.StandardError.ReadToEnd()
        $Process.WaitForExit()
        
        return @{
            ExitCode = $Process.ExitCode
            StdOut   = $StdOut
            StdErr   = $StdErr
            Success  = ($Process.ExitCode -eq 0)
        }
    }
    catch {
        return @{
            ExitCode = -1
            StdOut   = ""
            StdErr   = $_.Exception.Message
            Success  = $false
        }
    }
}

function Test-VCRedistInstalled {
    $X64Installed = Test-Path -LiteralPath $DetectionPathX64 -PathType Leaf
    $X86Installed = Test-Path -LiteralPath $DetectionPathX86 -PathType Leaf
    
    if ([Environment]::Is64BitOperatingSystem) {
        return ($X64Installed -or $X86Installed)
    }
    else {
        return $X86Installed
    }
}

#--------------------------------------------------------------------------------
# MAIN EXECUTION
#--------------------------------------------------------------------------------

try {
    # Check if already uninstalled
    if (-not (Test-VCRedistInstalled)) {
        exit $EXIT_SUCCESS
    }
    
    # Locate winget
    $WingetPath = Get-WingetPath
    
    if (-not $WingetPath) {
        Write-ErrorLog -Message "Winget not found. Cannot uninstall via winget."
        # Exit success since we can't uninstall without winget
        # The detection script will determine actual state
        exit $EXIT_SUCCESS
    }
    
    # Uninstall x64 version
    if ([Environment]::Is64BitOperatingSystem) {
        $X64Result = Uninstall-WingetPackage -WingetPath $WingetPath -PackageId $PackageIdX64
        
        if (-not $X64Result.Success -and $X64Result.ExitCode -ne -1978335212) {
            Write-ErrorLog -Message "Warning: Failed to uninstall $PackageIdX64 (Exit: $($X64Result.ExitCode))"
        }
    }
    
    # Uninstall x86 version
    $X86Result = Uninstall-WingetPackage -WingetPath $WingetPath -PackageId $PackageIdX86
    
    if (-not $X86Result.Success -and $X86Result.ExitCode -ne -1978335212) {
        Write-ErrorLog -Message "Warning: Failed to uninstall $PackageIdX86 (Exit: $($X86Result.ExitCode))"
    }
    
    exit $EXIT_SUCCESS
}
catch {
    Write-ErrorLog -Message "Unexpected error: $($_.Exception.Message)"
    exit $EXIT_FAILURE
}
