#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Adds RingCentral Windows Firewall exceptions for PDQ deployment.

.DESCRIPTION
    Standalone PDQ-friendly script that creates inbound allow rules for:
      - C:\Program Files\RingCentral\RingCentral.exe
      - C:\Users\<user>\AppData\Local\Programs\RingCentral\RingCentral.exe

    The per-user rule is created for every existing real user profile found in
    HKLM ProfileList. The executable does not need to exist yet; Windows Firewall
    rules can target the expected program path before RingCentral creates it.

    This script does not install RingCentral, create Intune markers, create a
    scheduled task, or perform Intune detection. Re-run it with PDQ after new
    user profiles are created if those future users also need pre-created rules.

    Run from PDQ as Local System or as an administrative deploy user such as
    pdqdeploy, as long as that account has local administrator rights on the
    target endpoint.

.NOTES
    Version:        1.0.1
    Script Type:    PDQ PowerShell
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  23/06/2026
    Purpose:        Create RingCentral firewall exceptions for Domain networks

    CHANGE LOG
    Change: 07/07/2026 - Codex audit remediation: renamed firewall profile loop variable
                         to avoid shadowing PowerShell's automatic $PROFILE variable -- ver. 1.0.1
    Change: 23/06/2026 - Initial PDQ standalone firewall exception script -- ver. 1.0.0
#>

$script:AppName          = 'RingCentral'
$script:AppVersion       = '1.0.1'
$script:FirewallGroup    = 'Hall County RingCentral'
$script:FirewallProfiles = @('Domain')
$script:MachineExePath   = 'C:\Program Files\RingCentral\RingCentral.exe'
$script:MachineRuleName  = 'Hall County RingCentral - Machine'
$script:UserExeSubPath   = 'AppData\Local\Programs\RingCentral\RingCentral.exe'


function Test-Administrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -ne $identity.User -and [string]$identity.User.Value -eq 'S-1-5-18') {
            return $true
        }

        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
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
        Write-Output ('Exists: {0} -> {1}' -f $DisplayName, $Program)
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

    Write-Output ('Created: {0} -> {1}' -f $DisplayName, $Program)
}


function Get-RingCentralUserProfileTargets {
    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $profileKeys = @(Get-ChildItem -LiteralPath $profileListPath -ErrorAction Stop)

    foreach ($key in $profileKeys) {
        if ($key.PSChildName -notmatch '^S-1-5-21-') { continue }

        $profileImagePath = [string]$key.GetValue('ProfileImagePath')
        if ([string]::IsNullOrWhiteSpace($profileImagePath)) { continue }

        $expandedPath = [Environment]::ExpandEnvironmentVariables($profileImagePath)
        if ([string]::IsNullOrWhiteSpace($expandedPath)) { continue }

        $profileFolder = [System.IO.Path]::GetFileName($expandedPath.TrimEnd('\'))
        if ([string]::IsNullOrWhiteSpace($profileFolder)) { continue }

        $userExePath = Join-Path -Path $expandedPath -ChildPath $script:UserExeSubPath

        New-Object PSObject -Property @{
            ProfileFolder = $profileFolder
            ExePath       = $userExePath
        }
    }
}


try {
    if (-not (Test-Administrator)) {
        [Console]::Error.WriteLine('This script must run elevated. Configure the PDQ step to run as Local System or an administrative deploy user such as pdqdeploy.')
        exit 1
    }

    Set-RingCentralFirewallRule -DisplayName $script:MachineRuleName -Program $script:MachineExePath

    $profileTargets = @(Get-RingCentralUserProfileTargets)
    foreach ($target in $profileTargets) {
        $userRuleName = 'Hall County RingCentral - User - {0}' -f $target.ProfileFolder
        Set-RingCentralFirewallRule -DisplayName $userRuleName -Program $target.ExePath
    }

    Write-Output ('Complete: RingCentral firewall rules applied for {0} profile(s). Profiles: {1}.' -f $profileTargets.Count, ([string]::Join(', ', $script:FirewallProfiles)))
    exit 0
}
catch {
    [Console]::Error.WriteLine(('RingCentral firewall rule setup failed: {0}' -f $_.Exception.Message))
    exit 1
}
