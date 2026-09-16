<#
.SYNOPSIS
    Sync-IntuneDevice.ps1

.DESCRIPTION
    Triggers an Intune MDM device sync and Entra ID (Azure AD) user sync.
    Mimics the action of: Settings > Access Work or School > [Domain] > Info > Sync
    
    This script can be run from a desktop shortcut to allow users to manually
    trigger a sync without navigating through Settings.

.NOTES
    Author:         Systems Administrator
    Version:        1.0
    
    WHAT THIS SCRIPT DOES:
    1. Triggers Intune MDM device policy sync (same as "Sync" button in Settings)
    2. Triggers Entra ID / Azure AD user sync (WAM account sync)
    3. Triggers Group Policy sync (for Hybrid AD joined devices)
    4. Displays status in a simple GUI popup
    
    METHODS USED:
    - MDM Sync: IMDMEnrollment3 COM interface (DeviceEnroller.exe)
    - Entra Sync: dsregcmd /refreshprt (Primary Refresh Token)
    - GP Sync: gpupdate (Hybrid AD only)
    
    TO CREATE DESKTOP SHORTCUT:
    Target: powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\IntuneSync\Sync-IntuneDevice.ps1"
    Run as: Normal user (not admin required for basic sync)
    
    FOR ADMIN-LEVEL SYNC (more thorough):
    Run PowerShell as Administrator, or use scheduled task with SYSTEM
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Show GUI notifications
$ShowNotifications = $true

# Also trigger Group Policy sync (for Hybrid AD Join)
$SyncGroupPolicy = $true

# Log file location (optional)
$LogPath = "$env:TEMP\IntuneSyncLog.txt"

# =============================================================================
# END CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# FUNCTION: Show-Notification
# -----------------------------------------------------------------------------
function Show-Notification {
    param(
        [string]$Title = "Intune Sync",
        [string]$Message,
        [string]$Type = "Info"  # Info, Warning, Error
    )
    
    if (-not $ShowNotifications) { return }
    
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        
        $Icon = switch ($Type) {
            "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
            "Error"   { [System.Windows.Forms.MessageBoxIcon]::Error }
            default   { [System.Windows.Forms.MessageBoxIcon]::Information }
        }
        
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $Icon) | Out-Null
    }
    catch {
        # Fallback to console if GUI unavailable
        Write-Host "$Title : $Message"
    }
}

# -----------------------------------------------------------------------------
# FUNCTION: Write-Log
# -----------------------------------------------------------------------------
function Write-Log {
    param([string]$Message)
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    try {
        Add-Content -LiteralPath $LogPath -Value $LogEntry -ErrorAction SilentlyContinue
    }
    catch { }
    
    Write-Host $LogEntry
}

# -----------------------------------------------------------------------------
# FUNCTION: Invoke-IntuneMDMSync
# Triggers the same sync as Settings > Access Work or School > Info > Sync
# -----------------------------------------------------------------------------
function Invoke-IntuneMDMSync {
    Write-Log "Starting Intune MDM sync..."
    
    $SyncSuccess = $false
    
    # Method 1: Use scheduled task that Windows creates for MDM sync
    try {
        $TaskPath = "\Microsoft\Windows\EnterpriseMgmt\*"
        $Tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue | 
                 Where-Object { $_.TaskName -like "*Schedule*to*launch*" -or $_.TaskName -like "*PushLaunch*" }
        
        if ($Tasks) {
            foreach ($Task in $Tasks) {
                Write-Log "Running scheduled task: $($Task.TaskName)"
                Start-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop
                $SyncSuccess = $true
            }
        }
    }
    catch {
        Write-Log "Scheduled task method failed: $($_.Exception.Message)"
    }
    
    # Method 2: Use DeviceEnroller.exe directly
    if (-not $SyncSuccess) {
        try {
            $DeviceEnroller = "$env:SystemRoot\System32\DeviceEnroller.exe"
            if (Test-Path -LiteralPath $DeviceEnroller -PathType Leaf) {
                Write-Log "Running DeviceEnroller.exe /c /AutoEnrollMDM"
                $Process = Start-Process -FilePath $DeviceEnroller -ArgumentList "/c /AutoEnrollMDM" -WindowStyle Hidden -PassThru -Wait
                if ($Process.ExitCode -eq 0) {
                    $SyncSuccess = $true
                }
            }
        }
        catch {
            Write-Log "DeviceEnroller method failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Trigger via WMI/CIM (MDM Bridge WMI Provider)
    if (-not $SyncSuccess) {
        try {
            Write-Log "Attempting WMI MDM sync trigger..."
            $EnrollmentID = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Enrollments" -ErrorAction SilentlyContinue | 
                            Where-Object { $_.GetValue("ProviderID") -eq "MS DM Server" } |
                            Select-Object -First 1 -ExpandProperty PSChildName
            
            if ($EnrollmentID) {
                # Trigger sync via scheduled task with enrollment ID
                $TaskName = "Schedule #3 created by enrollment client"
                $TaskPath = "\Microsoft\Windows\EnterpriseMgmt\$EnrollmentID\"
                
                if (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue) {
                    Start-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
                    $SyncSuccess = $true
                    Write-Log "MDM sync triggered via enrollment scheduled task"
                }
            }
        }
        catch {
            Write-Log "WMI method failed: $($_.Exception.Message)"
        }
    }
    
    return $SyncSuccess
}

# -----------------------------------------------------------------------------
# FUNCTION: Invoke-EntraUserSync
# Refreshes the Primary Refresh Token (PRT) for Entra ID / Azure AD
# -----------------------------------------------------------------------------
function Invoke-EntraUserSync {
    Write-Log "Starting Entra ID (Azure AD) user sync..."
    
    $SyncSuccess = $false
    
    try {
        # Method 1: dsregcmd /refreshprt - Refreshes Primary Refresh Token
        $DsRegCmd = "$env:SystemRoot\System32\dsregcmd.exe"
        
        if (Test-Path -LiteralPath $DsRegCmd -PathType Leaf) {
            Write-Log "Running dsregcmd /refreshprt"
            $Process = Start-Process -FilePath $DsRegCmd -ArgumentList "/refreshprt" -WindowStyle Hidden -PassThru -Wait
            
            if ($Process.ExitCode -eq 0) {
                $SyncSuccess = $true
                Write-Log "PRT refresh completed successfully"
            }
            else {
                Write-Log "dsregcmd /refreshprt returned exit code: $($Process.ExitCode)"
            }
        }
    }
    catch {
        Write-Log "Entra sync failed: $($_.Exception.Message)"
    }
    
    # Method 2: Trigger WAM account sync via CloudExperienceHost
    try {
        $WAMTask = Get-ScheduledTask -TaskName "Refresh AAD Device Token" -TaskPath "\Microsoft\Windows\Workplace Join\" -ErrorAction SilentlyContinue
        if ($WAMTask) {
            Write-Log "Running AAD Device Token refresh task"
            Start-ScheduledTask -TaskName $WAMTask.TaskName -TaskPath $WAMTask.TaskPath -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Log "WAM task trigger failed: $($_.Exception.Message)"
    }
    
    return $SyncSuccess
}

# -----------------------------------------------------------------------------
# FUNCTION: Invoke-GroupPolicySync
# Triggers gpupdate for Hybrid AD joined devices
# -----------------------------------------------------------------------------
function Invoke-GroupPolicySync {
    Write-Log "Starting Group Policy sync..."
    
    try {
        # Check if domain joined
        $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        
        if ($ComputerSystem.PartOfDomain) {
            Write-Log "Device is domain joined - running gpupdate"
            $Process = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -PassThru -Wait
            return ($Process.ExitCode -eq 0)
        }
        else {
            Write-Log "Device is not domain joined - skipping GP sync"
            return $true
        }
    }
    catch {
        Write-Log "Group Policy sync failed: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Log "========== Intune/Entra Sync Started =========="
Write-Log "User: $env:USERNAME"
Write-Log "Computer: $env:COMPUTERNAME"

$Results = @{
    MDMSync = $false
    EntraSync = $false
    GPSync = $true  # Default true if not needed
}

# Trigger MDM Sync
$Results.MDMSync = Invoke-IntuneMDMSync

# Trigger Entra/Azure AD Sync
$Results.EntraSync = Invoke-EntraUserSync

# Trigger Group Policy Sync (if enabled and applicable)
if ($SyncGroupPolicy) {
    $Results.GPSync = Invoke-GroupPolicySync
}

Write-Log "========== Sync Complete =========="
Write-Log "MDM Sync: $(if ($Results.MDMSync) { 'Success' } else { 'Failed/Partial' })"
Write-Log "Entra Sync: $(if ($Results.EntraSync) { 'Success' } else { 'Failed/Partial' })"
Write-Log "GP Sync: $(if ($Results.GPSync) { 'Success' } else { 'Failed/Partial' })"

# Show notification to user
$AllSuccess = $Results.MDMSync -and $Results.EntraSync -and $Results.GPSync

if ($AllSuccess) {
    Show-Notification -Title "Sync Complete" -Message "Device and user sync completed successfully.`n`nPolicy changes may take a few minutes to apply." -Type "Info"
}
else {
    $FailedItems = @()
    if (-not $Results.MDMSync) { $FailedItems += "Device (MDM)" }
    if (-not $Results.EntraSync) { $FailedItems += "User (Entra)" }
    if (-not $Results.GPSync) { $FailedItems += "Group Policy" }
    
    Show-Notification -Title "Sync Partially Complete" -Message "Some sync operations may not have completed:`n$($FailedItems -join ', ')`n`nTry running as Administrator for full sync." -Type "Warning"
}

exit 0
