#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Adds the machine-wide RingCentral Windows Firewall inbound allow rule.

.DESCRIPTION
    Runs as SYSTEM, spawned as a child process from Install-RingCentral.ps1 after a verified
    successful install (also safe to run standalone/manually as SYSTEM). RingCentral installs
    machine-wide only (C:\Program Files\RingCentral\RingCentral.exe) -- this helper creates a
    single inbound allow rule for that path. Idempotent: re-running when the correct rule
    already exists is a no-op.

.NOTES
    Version:        4.2.0
    Script Type:    Microsoft Intune Win32 App Helper
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  22/06/2026
    Purpose:        Maintain the machine-wide RingCentral firewall rule

    CHANGE LOG
    Change: 22/06/2026 - Initial helper for RingCentral firewall rules -- ver. 3.2.0
    Change: 07/07/2026 - Removed per-user S-1-5-21 profile enumeration and per-profile firewall
                         rules -- RingCentral's confirmed install is machine-wide only
                         (C:\Program Files\RingCentral\), so the %LOCALAPPDATA% per-user rule
                         path was unused defensive code. Simplified to a single machine-wide rule.
                         No longer intended to run from a logon-time scheduled task -- ver. 4.0.0
    Change: 07/07/2026 - Codex audit: aligned helper logging with Win32 app log location and
                         kept firewall creation as a required install end state -- ver. 4.1.0
    Change: 07/07/2026 - Audit follow-up: renamed the profile-check loop variable from $profile
                         to $firewallProfile -- $profile shadows PowerShell's automatic $PROFILE
                         variable -- ver. 4.2.0
#>

$script:AppName                 = 'RingCentral'
$script:AppVersion              = '4.2.0'
$script:LogRoot                 = 'C:\IntuneAppLogs'
$script:LogFileName             = 'RingCentral_Firewall.txt'
$script:MachineExePath          = 'C:\Program Files\RingCentral\RingCentral.exe'
$script:FirewallGroup           = 'Hall County RingCentral'
$script:FirewallProfiles        = @('Domain', 'Private')
$script:MachineRuleName         = 'Hall County RingCentral - Machine'
$script:LegacyRuleDisplayFilter = 'RingCentral Allow Inbound *'


function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$Category
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($script:LogRoot)
        $logPath   = Join-Path -Path $script:LogRoot -ChildPath $script:LogFileName
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line      = '[{0}] [v{1}] [{2}] {3}' -f $timestamp, $script:AppVersion, $Category, $Message
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($logPath, $line + [System.Environment]::NewLine, $utf8NoBom)
    }
    catch {
        try { [Console]::Error.WriteLine('{0} - logging failed: {1}' -f $script:AppName, $Message) } catch { }
    }
}


function Test-RingCentralFirewallRule {
    param(
        [string]$DisplayName,
        [string]$Program
    )

    try {
        $rules = @(Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue)
        if ($rules.Count -ne 1) { return $false }

        $rule = $rules[0]
        if ([string]$rule.Enabled -ne 'True') { return $false }
        if ([string]$rule.Direction -ne 'Inbound') { return $false }
        if ([string]$rule.Action -ne 'Allow') { return $false }

        $profileText = [string]$rule.Profile
        if ($profileText -notmatch 'Any') {
            foreach ($firewallProfile in $script:FirewallProfiles) {
                if ($profileText -notmatch $firewallProfile) {
                    return $false
                }
            }
        }

        $filters = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction Stop)
        if ($filters.Count -ne 1) { return $false }

        return ([string]$filters[0].Program -ieq $Program)
    }
    catch {
        return $false
    }
}


function Set-RingCentralFirewallRule {
    param(
        [string]$DisplayName,
        [string]$Program
    )

    if (Test-RingCentralFirewallRule -DisplayName $DisplayName -Program $Program) {
        return
    }

    $existingRules = @(Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue)
    foreach ($rule in $existingRules) {
        Remove-NetFirewallRule -InputObject $rule -ErrorAction Stop
    }

    New-NetFirewallRule `
        -DisplayName $DisplayName `
        -Group $script:FirewallGroup `
        -Direction Inbound `
        -Program $Program `
        -Action Allow `
        -Profile $script:FirewallProfiles `
        -Enabled True `
        -Description 'Allows RingCentral inbound communication on managed network profiles.' `
        -ErrorAction Stop | Out-Null
}


function Remove-RingCentralLegacyRules {
    try {
        $legacyRules = @(Get-NetFirewallRule -DisplayName $script:LegacyRuleDisplayFilter -ErrorAction SilentlyContinue)
        foreach ($rule in $legacyRules) {
            try {
                Remove-NetFirewallRule -InputObject $rule -ErrorAction Stop
            }
            catch {
                Write-ErrorLog -Message ('Firewall: Failed to remove legacy rule ''{0}'': {1}' -f $rule.DisplayName, $_.Exception.Message) -Category 'Permissions'
            }
        }
    }
    catch {
        Write-ErrorLog -Message ('Firewall: Failed to remove a legacy rule: {0}' -f $_.Exception.Message) -Category 'Permissions'
    }
}


try {
    $failureCount = 0

    Remove-RingCentralLegacyRules

    try {
        Set-RingCentralFirewallRule -DisplayName $script:MachineRuleName -Program $script:MachineExePath
    }
    catch {
        $failureCount++
        Write-ErrorLog -Message ('Firewall: Failed to add machine rule: {0}' -f $_.Exception.Message) -Category 'Permissions'
    }

    if ($failureCount -gt 0) {
        exit 1
    }

    exit 0
}
catch {
    Write-ErrorLog -Message ('Firewall: Unexpected error: {0}' -f $_.Exception.Message) -Category 'System'
    exit 1
}
