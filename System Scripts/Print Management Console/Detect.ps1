#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detects the Print Management Console Windows Capability for Intune.

.DESCRIPTION
    Checks the live Windows Capability state directly. Matches the
    capability by name prefix and requires exactly one match, so a
    revision-suffix change on a different Windows build fails closed with a
    clear match count instead of silently never matching. Detected only
    when that single match reports Installed.

    Exit 0 plus STDOUT means detected. Exit 1 with no STDOUT means not
    detected. The detection script is side-effect free and does not depend
    on administrative marker files.

.NOTES
    Version:        1.0.3
    Script Type:    Microsoft Intune Win32 App - Custom Detection
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  09/09/2026
    Purpose:        Detect whether the Print Management Console capability is installed

    ERROR CODES
      0 = Detected
      1 = Not detected or detection failed

    CHANGE LOG
    Change: 10/09/2026 - No functional change; version bumped for cross-file version-number consistency with Install-PrintManagementConsole.ps1 v1.0.3 -- ver. 1.0.3
    Change: 10/09/2026 - Match by name prefix instead of a hardcoded exact revision suffix -- ver. 1.0.2
    Change: 09/09/2026 - Use the exact capability identity and correct documentation -- ver. 1.0.1
    Change: 09/09/2026 - Initial release -- ver. 1.0.0

    PAIRED SCRIPT
      Install-PrintManagementConsole.ps1 v1.0.3

    INTUNE CONFIGURATION
      Run script as 32-bit process on 64-bit clients: No
#>

$script:CapabilityFilter = 'Print.Management.Console*'

try {
    $Capabilities = @(Get-WindowsCapability -Online -Name $script:CapabilityFilter -ErrorAction Stop)
    if ($Capabilities.Count -eq 1 -and $Capabilities[0].State -eq 'Installed') {
        Write-Output 'Detected: Print Management Console capability state is Installed.'
        exit 0
    }
    exit 1
}
catch {
    exit 1
}
