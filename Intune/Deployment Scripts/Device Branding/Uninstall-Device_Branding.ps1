#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Removes the device branding configuration applied by System-Device_Branding.ps1.

.DESCRIPTION
    Removes the lock screen enforcement policy registry values, restoring the
    user's ability to change the lock screen background in Settings.
    Removes the install marker so Intune detection reports the app as not installed.

    Does NOT revert the Default User hive wallpaper setting. Reversing a hive
    modification has no effect on existing user profiles (those profiles have
    already been created with their own NTUSER.DAT), and modifying the hive
    again would only affect future profiles. Existing users may simply change
    their own wallpaper through Settings if desired.

    Does NOT remove image files from C:\IntuneDeploymentFiles\Images\ — those
    files may be referenced by other configurations or scripts.

    Always exits 0.

.NOTES
    Author:         Jeremy Hankinson
    Script Version: 1.0.0
    Revision Date:  2026-03-27 (1.0.0)
    Script Name:    Uninstall-Device_Branding.ps1
    Paired script:  System-Device_Branding.ps1 v1.0.0

    INTUNE CONFIGURATION
      Uninstall command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-Device_Branding.ps1

      Install behavior: System

    RETURN CODES
      0    = Success or non-fatal error
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppVersion = '1.0.0'

$script:PersonalizationPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

$script:MarkerRoot = 'C:\IntuneAppMarkers'
$script:MarkerPath = Join-Path -Path $script:MarkerRoot -ChildPath 'System-Device_Branding.tag'

$script:LogRoot = 'C:\IntuneAppLogs'
$script:LogFile = Join-Path -Path $script:LogRoot -ChildPath 'DeviceBranding_Uninstall.txt'

# =============================================================================
# END CONFIGURATION
# =============================================================================

$script:LogBuffer   = [System.Collections.Generic.List[string]]::new()
$script:HasWarnings = $false
$script:HasErrors   = $false

function Add-LogLine {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    try {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        [void]$script:LogBuffer.Add("$Timestamp [$Level] $Message")
    }
    catch { }
    if ($Level -eq 'WARN')  { $script:HasWarnings = $true }
    if ($Level -eq 'ERROR') { $script:HasErrors   = $true }
}

function Write-LogIfNeeded {
    try {
        if (-not ($script:HasWarnings -or $script:HasErrors)) { return }
        try { [System.IO.Directory]::CreateDirectory($script:LogRoot) | Out-Null } catch { return }
        try   { $RunHeader = "=== Run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') v$($script:AppVersion) ===" }
        catch { $RunHeader = '=== Run (timestamp unavailable) ===' }
        $Lines = (@('', $RunHeader) + $script:LogBuffer.ToArray()) -join [System.Environment]::NewLine
        [System.IO.File]::AppendAllText($script:LogFile, $Lines + [System.Environment]::NewLine,
            [System.Text.Encoding]::UTF8)
    }
    catch { }
}

# Removes a single named registry value from the specified key path.
# Silently skips if the key or value does not exist. Logs a warning on error.
function Remove-PolicyValue {
    param(
        [Parameter(Mandatory)][string]$KeyPath,
        [Parameter(Mandatory)][string]$ValueName
    )
    try {
        if (-not (Test-Path -LiteralPath $KeyPath)) { return }
        $Existing = Get-ItemProperty -LiteralPath $KeyPath -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $Existing) { return }
        Remove-ItemProperty -LiteralPath $KeyPath -Name $ValueName -Force -ErrorAction Stop
    }
    catch {
        Add-LogLine -Message "Failed to remove '$ValueName' from '$KeyPath': $($_.Exception.Message)" -Level 'WARN'
    }
}

# =============================================================================
# MAIN
# =============================================================================
try {
    # Remove lock screen policy values set by the install script.
    # Users will regain the ability to change the lock screen in Settings once
    # these values are absent and the next policy evaluation has occurred.
    Remove-PolicyValue -KeyPath $script:PersonalizationPolicyKey -ValueName 'LockScreenImage'
    Remove-PolicyValue -KeyPath $script:PersonalizationPolicyKey -ValueName 'NoChangingLockScreen'

    # Remove the install marker so Intune detection reports the app as not installed.
    if (Test-Path -LiteralPath $script:MarkerPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:MarkerPath -Force -ErrorAction Stop
    }

    Write-LogIfNeeded
    exit 0
}
catch {
    try { Add-LogLine -Message "Uninstall failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Level 'ERROR' } catch { }
    try { Write-LogIfNeeded } catch { }
    exit 0
}
