#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================
# CONFIG - CHANGE ONLY THIS LINE
# ============================
$ShortcutName = 'Moblan.lnk'   # <=== CHANGE ONLY THIS LINE
# ============================

# ----------------------------
# Paths
# ----------------------------
# Resolve the *actual* Common Desktop path (more reliable than hardcoding C:\Users\Public\Desktop)
$DestFolder = [Environment]::GetFolderPath('CommonDesktopDirectory')
if ([string]::IsNullOrWhiteSpace($DestFolder)) {
    $DestFolder = Join-Path $env:PUBLIC 'Desktop'
}

$BaseName    = [System.IO.Path]::GetFileNameWithoutExtension($ShortcutName)
$SourcePath  = Join-Path $PSScriptRoot $ShortcutName
$DestPath    = Join-Path $DestFolder  $ShortcutName

# Icon configuration
$IconFileName = 'MobLanIcon.ico'
$SourceIconPath = Join-Path $PSScriptRoot $IconFileName
$LocalIconFolder = 'C:\IntuneDeploymentFiles\Images'
$LocalIconPath = Join-Path $LocalIconFolder $IconFileName

# ----------------------------
# Logging
# ----------------------------
$LogRoot = 'C:\IntuneAppLogs'
$LogFile = Join-Path $LogRoot ("{0}_Install.txt" -f $BaseName)

# ----------------------------
# Detection marker (registry)
# ----------------------------
$RegRoot = 'HKLM:\SOFTWARE\HallCounty\IntuneShortcuts'
$RegPath = Join-Path $RegRoot $BaseName

function Initialize-Logging {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }

    # Create the log file first, then append (per requirement)
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-Log {
    param([Parameter(Mandatory)][string]$Message)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $LogFile -Value "[$ts] $Message"
}

function Fail {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][int]$ExitCode
    )

    try { Write-Log "ERROR: $Message" } catch {}
    exit $ExitCode
}

# ----------------------------
# Main
# ----------------------------
Initialize-Logging
Write-Log "Starting shortcut deployment (packaged .lnk)."
Write-Log "ShortcutName='$ShortcutName' BaseName='$BaseName'"
Write-Log "PSScriptRoot='$PSScriptRoot'"
Write-Log "Resolved Common Desktop='$DestFolder'"
Write-Log "SourcePath='$SourcePath'"
Write-Log "DestPath='$DestPath'"

# Execution context diagnostics
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    Write-Log "Identity: $($id.Name)"
    Write-Log "IsSystem: $($id.IsSystem)"
    Write-Log "IsAdmin:  $($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
} catch {
    Write-Log "Context diagnostics failed: $($_.Exception.Message)"
}

try {
    # Verify packaged shortcut exists
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-Log ("Directory listing of package root:`r`n" + ((Get-ChildItem -LiteralPath $PSScriptRoot | Select-Object Name,Length | Out-String).Trim()))
        Fail -Message "Packaged shortcut not found next to script: $SourcePath" -ExitCode 2
    }

    # Ensure destination directory exists
    if (-not (Test-Path -LiteralPath $DestFolder)) {
        Write-Log "Destination folder missing; creating: $DestFolder"
        New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
    }

    # Write-probe to validate we can write to resolved Common Desktop
    try {
        $probe = Join-Path $DestFolder "_write_probe.txt"
        "probe" | Out-File -LiteralPath $probe -Force
        Remove-Item -LiteralPath $probe -Force
        Write-Log "Write probe to Common Desktop: SUCCESS"
    } catch {
        Write-Log "Write probe to Common Desktop: FAILED - $($_.Exception.Message)"
        Write-Log ("icacls Common Desktop:`r`n" + ((icacls $DestFolder 2>&1) -join "`r`n"))
        Fail -Message "Cannot write to resolved Common Desktop. Check ACLs / endpoint controls. See log for icacls output." -ExitCode 5
    }

    # Replace any existing shortcut
    if (Test-Path -LiteralPath $DestPath) {
        Write-Log "Existing shortcut found; removing: $DestPath"
        Remove-Item -LiteralPath $DestPath -Force
    }

    # Copy from package to Common Desktop
    Write-Log "Copying shortcut: '$SourcePath' -> '$DestPath'"
    Copy-Item -LiteralPath $SourcePath -Destination $DestPath -Force

    if (-not (Test-Path -LiteralPath $DestPath)) {
        Fail -Message "Copy completed but destination file missing: $DestPath" -ExitCode 4
    }

    # Integrity check via SHA256 (cheap and reliable)
    $srcHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash -LiteralPath $DestPath   -Algorithm SHA256).Hash

    if ($srcHash -ne $dstHash) {
        Fail -Message "Hash mismatch after copy. Source=$srcHash Dest=$dstHash" -ExitCode 4
    }

    # Write detection marker
    if (-not (Test-Path -LiteralPath $RegRoot)) {
        New-Item -Path $RegRoot -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name 'ShortcutName' -Value $ShortcutName -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name 'Sha256'       -Value $dstHash     -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name 'InstalledOn'  -Value (Get-Date).ToString('o') -PropertyType String -Force | Out-Null

    Write-Log "Shortcut deployed successfully. SHA256=$dstHash"

    # ----------------------------
    # Update Shortcut Icon
    # ----------------------------
    Write-Log "Starting icon update process..."

    # Verify packaged icon exists
    if (-not (Test-Path -LiteralPath $SourceIconPath -PathType Leaf)) {
        Write-Log "WARNING: Icon file not found in package: $SourceIconPath"
        Write-Log "Skipping icon update. Shortcut will use default icon."
    }
    else {
        Write-Log "Source icon found: $SourceIconPath"

        # Create local icon folder if needed
        if (-not (Test-Path -LiteralPath $LocalIconFolder)) {
            New-Item -Path $LocalIconFolder -ItemType Directory -Force | Out-Null
            Write-Log "Created icon folder: $LocalIconFolder"
        }

        # Copy icon to local folder
        Copy-Item -LiteralPath $SourceIconPath -Destination $LocalIconPath -Force
        Write-Log "Copied icon to: $LocalIconPath"

        # Verify copy succeeded
        if (-not (Test-Path -LiteralPath $LocalIconPath -PathType Leaf)) {
            Write-Log "WARNING: Icon copy failed. Shortcut will use default icon."
        }
        else {
            # Update shortcut icon
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($DestPath)

            Write-Log "Current icon location: $($Shortcut.IconLocation)"

            $Shortcut.IconLocation = "$LocalIconPath,0"
            $Shortcut.Save()

            Write-Log "Updated icon to: $LocalIconPath,0"

            # Release COM object
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null

            # Update registry with icon info
            New-ItemProperty -Path $RegPath -Name 'IconPath' -Value $LocalIconPath -PropertyType String -Force | Out-Null

            Write-Log "Icon update completed successfully."
        }
    }

    Write-Log "Install completed successfully."
    exit 0
}
catch [System.UnauthorizedAccessException] {
    Fail -Message "Access denied. Details: $($_.Exception.Message)" -ExitCode 5
}
catch {
    Fail -Message "Unhandled exception: $($_.Exception.Message)" -ExitCode 1
}
