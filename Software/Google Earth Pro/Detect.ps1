<#
.SYNOPSIS
    Detect-GoogleEarthPro.ps1

.DESCRIPTION
    Detection script for Google Earth Pro Win32 app.
    Checks if googleearth.exe exists in known installation paths.
    
    Detection Logic (Intune Win32 App):
    - Exit code 0 with STDOUT output = Application DETECTED (installed)
    - Exit code 1 OR no STDOUT output = Application NOT DETECTED (not installed)

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    IMPORTANT: Use Write-Output (not Write-Host) for STDOUT.
    Detection scripts do not write to log files - only install/uninstall scripts log.
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Detection paths - locations where googleearth.exe may be installed
# Script checks these paths to determine if Google Earth Pro is installed
$DetectionPaths = @(
    "${env:ProgramFiles}\Google\Google Earth Pro\client\googleearth.exe",
    "${env:ProgramFiles(x86)}\Google\Google Earth Pro\client\googleearth.exe"
)

# =============================================================================
# MAIN DETECTION LOGIC
# =============================================================================

try {
    # Check each potential installation path
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            # Application DETECTED
            # Write to STDOUT (CRITICAL: must use Write-Output, not Write-Host)
            Write-Output "Google Earth Pro detected: $Path"
            exit 0
        }
    }
    
    # Application NOT DETECTED
    # Exit code 1 with no STDOUT tells Intune the app is not installed
    exit 1
}
catch {
    # If detection fails, treat as not installed (safe default - Intune will attempt install)
    exit 1
}
