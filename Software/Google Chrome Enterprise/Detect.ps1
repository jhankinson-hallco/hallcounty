<#
.SYNOPSIS
    Detect.ps1

.DESCRIPTION
    Detects if Google Chrome Enterprise is installed.
    
    DETECTION LOGIC:
    - Checks for chrome.exe in standard installation locations
    - Uses file-based detection (more reliable than registry for Chrome)
    
    INTUNE DETECTION:
    - Exit code 0 + Write-Output = Application DETECTED (installed)
    - Exit code 1 = Application NOT DETECTED (not installed)

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    INTUNE CONFIGURATION:
    Detection rule type: Use a custom detection script
    Script file: Detect.ps1
    Run script as 32-bit process: No
    Enforce script signature check: No
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Detection paths - standard Chrome installation locations
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

# =============================================================================
# DETECTION LOGIC
# =============================================================================

foreach ($Path in $DetectionPaths) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        # Application is installed
        # Write-Output produces stdout, which Intune requires for detection
        Write-Output "Google Chrome detected at: $Path"
        exit 0
    }
}

# Application is NOT installed
# Exit 1 with no output = not detected
exit 1
