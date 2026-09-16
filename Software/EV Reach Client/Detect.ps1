<#
.SYNOPSIS
    Detect-EVReachClient.ps1

.DESCRIPTION
    Detection script for EV Reach Client Win32 app.
    Checks if GovAgent executable exists in known installation paths.
    
    Detection Logic (Intune Win32 App):
    - Exit code 0 with STDOUT output = Application DETECTED (installed)
    - Exit code 1 OR no STDOUT output = Application NOT DETECTED (not installed)

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune, Hybrid Azure AD Join, Autopilot
    
    IMPORTANT: Use Write-Output (not Write-Host) for STDOUT.
    Detection scripts do not write to log files.
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Detection paths - locations where EV Reach Client components are installed
# Check for the main Goverlan Agent executable
$DetectionPaths = @(
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgent.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe",
    "${env:ProgramFiles(x86)}\Goverlan Inc\GoverlanAgent\GovAgent.exe"
)

# =============================================================================
# MAIN DETECTION LOGIC
# =============================================================================

try {
    foreach ($Path in $DetectionPaths) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            # Application DETECTED
            Write-Output "EV Reach Client detected: $Path"
            exit 0
        }
    }
    
    # Application NOT DETECTED
    exit 1
}
catch {
    # If detection fails, treat as not installed
    exit 1
}
