#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Intune detection script for Microsoft Visual C++ 2010 SP1 Redistributable (x86 and x64).

.DESCRIPTION
    Detected only when BOTH a trusted x86 AND a trusted x64 Microsoft Visual
    C++ 2010 Redistributable registration exist in the uninstall registry
    (DisplayName pattern + Publisher "Microsoft Corporation*" +
    WindowsInstaller=1), checked across both the native and WOW6432Node
    Uninstall hives.

    No marker file is used - unlike apps with hidden configuration state
    (e.g. the Barracuda NAC VPN project's VPN profile), a VC++
    redistributable's installed state is fully and reliably provable from
    the uninstall registry alone, so direct registry evidence is used per
    reference_intune_detection.md's detection-type preference order.

    Exit 0 + STDOUT = detected. Exit 1 / no STDOUT = not detected (Intune
    retries the install).

.NOTES
    Version:        1.0.0
    Script Type:    Microsoft Intune Win32 App Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  17/08/2026
    Purpose:        Detect Microsoft Visual C++ 2010 SP1 Redistributable (x86 and x64)

    CHANGE LOG
    Change: 17/08/2026 - Full rewrite: registry-based dual-architecture
                         detection, replacing the pre-standards
                         flag-file/GUID-file approach that only ever
                         tracked one architecture -- ver. 1.0.0

    INTUNE CONFIGURATION
      Detection rule: custom detection script Detect.ps1
      Run script as 32-bit process on 64-bit clients: No

    Paired script: Install-VCRedist2010.ps1 v1.0.0
#>

$script:DisplayNamePatternX86 = '^Microsoft Visual C\+\+ 2010\s+x86\s+Redistributable'
$script:DisplayNamePatternX64 = '^Microsoft Visual C\+\+ 2010\s+x64\s+Redistributable'
$script:PublisherPattern      = 'Microsoft Corporation*'
$script:RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

function Test-VCRedistArchitectureInstalled {
    param(
        [string]$DisplayNamePattern
    )

    foreach ($RegistryPath in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $RegistryPath)) {
            continue
        }

        try {
            $SubKeys = @(Get-ChildItem -LiteralPath $RegistryPath -ErrorAction Stop)
        }
        catch {
            continue
        }

        foreach ($SubKey in $SubKeys) {
            try {
                $Properties = Get-ItemProperty -LiteralPath $SubKey.PSPath -ErrorAction Stop
                $DisplayNameProperty = $Properties.PSObject.Properties['DisplayName']
                $PublisherProperty = $Properties.PSObject.Properties['Publisher']
                $WindowsInstallerProperty = $Properties.PSObject.Properties['WindowsInstaller']

                if ($null -eq $DisplayNameProperty -or $null -eq $PublisherProperty -or $null -eq $WindowsInstallerProperty) {
                    continue
                }

                if ([string]$DisplayNameProperty.Value -notmatch $DisplayNamePattern) {
                    continue
                }
                if ([string]$PublisherProperty.Value -notlike $script:PublisherPattern) {
                    continue
                }
                if ([string]$WindowsInstallerProperty.Value -ne '1') {
                    continue
                }

                return $true
            }
            catch {
                continue
            }
        }
    }

    return $false
}

try {
    if (-not (Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX86)) {
        exit 1
    }
    if (-not (Test-VCRedistArchitectureInstalled -DisplayNamePattern $script:DisplayNamePatternX64)) {
        exit 1
    }

    Write-Output 'Detected: Microsoft Visual C++ 2010 Redistributable x86 and x64 both registered.'
    exit 0
}
catch {
    exit 1
}
