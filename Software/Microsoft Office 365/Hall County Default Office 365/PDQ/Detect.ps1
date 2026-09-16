#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Detection script for Microsoft Office 365 (M365 Apps for Enterprise).

.DESCRIPTION
    Detects a correctly installed Office 365 baseline by performing two checks:

      1. WINWORD.EXE must exist at the expected 64-bit Program Files path.
         This proves Office binaries were written to disk.

      2. HKLM ClickToRun Configuration\ProductReleaseIds must exist and contain
         'O365ProPlusRetail'. This proves an ODT-managed C2R install completed
         product registration - not merely that a Word binary is present from a
         prior partial or unrelated install.

    Both checks must pass for detection to succeed.

    A native file-only detection rule on WINWORD.EXE is insufficient for this package
    because it cannot verify C2R product registration. A native registry string rule
    cannot perform substring matching - ProductReleaseIds can contain multiple product
    IDs (e.g., when Visio or Project is co-installed) and an exact-match rule would
    false-negative on valid multi-product installs. The custom script handles the
    substring check correctly.

    Exit 0 + STDOUT = detected (Office 365 installed and registered).
    Exit 1 / no STDOUT = not detected.

    On exception: exits 1 and writes to stderr so the error is visible in Intune
    diagnostic captures without blocking detection retry.

.NOTES
    Version:        1.5.2
    Script Type:    Microsoft Intune Win32 App (Detection)
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  14/04/2026
    Purpose:        Detects correctly installed M365 Apps for Enterprise (O365ProPlusRetail)

    CHANGE LOG
    Change: 14/04/2026 - Initial release - replaces portal-side file-only detection;
                         performs WINWORD.EXE file check and ClickToRun ProductReleaseIds
                         registry check -- ver. 1.4.0
    Change: 14/04/2026 - Added 64-bit process guard (same requirement as install script -
                         32-bit host redirects ClickToRun registry path causing false-negative
                         on a good install); added cross-reference sync comments to config
                         variables that must match Install-Office365.ps1 -- ver. 1.5.0
    Change: 17/04/2026 - Version sync to 1.5.1 for package consistency; re-saved as
                         UTF-8 with BOM -- ver. 1.5.1
    Change: 17/04/2026 - Version sync to 1.5.2 for package consistency -- ver. 1.5.2
#>

# SYNC NOTE: These three values must match the corresponding constants in
# Install-Office365.ps1 ($script:DetectionPath, $c2rConfigKey, $requiredProductId).
# If you change any value here, update Install-Office365.ps1 to match, and vice versa.

# Must match $script:DetectionPath in Install-Office365.ps1.
$script:WordExePath = 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'

# Must match $c2rConfigKey in Install-Office365.ps1 post-install verification block.
$script:C2RConfigKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'

# Must match $requiredProductId in Install-Office365.ps1 post-install verification block.
# Substring match - ProductReleaseIds can contain multiple IDs when Visio, Project,
# or other C2R products are co-installed.
$script:RequiredProductId = 'O365ProPlusRetail'

try {
    # 64-bit process guard. Both checks below depend on 64-bit host:
    #   - $script:WordExePath is under C:\Program Files (redirected on 32-bit hosts)
    #   - $script:C2RConfigKey is under HKLM\SOFTWARE (redirected to WOW6432Node on 32-bit hosts)
    # A 32-bit host will produce a false-negative on a correctly installed 64-bit Office build.
    # In Intune portal: set "Run script as 32-bit process on 64-bit clients" to No.
    if (-not [Environment]::Is64BitProcess) {
        [Console]::Error.WriteLine('Detect.ps1 requires 64-bit PowerShell. Set "Run as 32-bit" to No in the Intune detection script settings.')
        exit 1
    }

    # Check 1: Word binary must exist.
    if (-not (Test-Path -LiteralPath $script:WordExePath -PathType Leaf)) {
        exit 1
    }

    # Check 2: ClickToRun configuration key must exist.
    if (-not (Test-Path -LiteralPath $script:C2RConfigKey)) {
        exit 1
    }

    $props = Get-ItemProperty -LiteralPath $script:C2RConfigKey -ErrorAction Stop

    # ProductReleaseIds value must be present and contain the expected product ID.
    if (-not $props.PSObject.Properties['ProductReleaseIds']) {
        exit 1
    }

    $productReleaseIds = [string]$props.ProductReleaseIds

    if ($productReleaseIds -notmatch [regex]::Escape($script:RequiredProductId)) {
        exit 1
    }

    Write-Output ('Office 365 ({0}) detected.' -f $script:RequiredProductId)
    exit 0
}
catch {
    [Console]::Error.WriteLine('Detect.ps1 exception: ' + $_.Exception.Message)
    exit 1
}
