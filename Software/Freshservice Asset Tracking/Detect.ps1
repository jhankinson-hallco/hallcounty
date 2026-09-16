<#
.SYNOPSIS
    Detect-FreshServiceAgent.ps1

.DESCRIPTION
    Detects if Freshservice Discovery Agent is installed.
    
    DETECTION LOGIC:
    - Checks for FSAgentService.exe in the installation directory
    - Falls back to registry check for installed product

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune
    
    INTUNE DETECTION:
    - Exit code 0 + Write-Output = Application DETECTED (installed)
    - Exit code 1 = Application NOT DETECTED (not installed)
    
    INTUNE CONFIGURATION:
    Detection rule type: Use a custom detection script
    Script file: Detect-FreshServiceAgent.ps1
    Run script as 32-bit process on 64-bit clients: No
    Enforce script signature check: No
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Primary detection path
$DetectionPath = "${env:ProgramFiles(x86)}\Freshdesk\Freshservice Discovery Agent\bin\FSAgentService.exe"

# Display name patterns for registry detection
$DisplayNamePatterns = @(
    "*Freshservice Discovery*",
    "*Fresh Service*Discovery*"
)

# =============================================================================
# DETECTION LOGIC
# =============================================================================

# Method 1: Check for executable
if (Test-Path -LiteralPath $DetectionPath -PathType Leaf) {
    Write-Output "Freshservice Discovery Agent detected at: $DetectionPath"
    exit 0
}

# Method 2: Check registry
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($RegPath in $RegistryPaths) {
    if (Test-Path -LiteralPath $RegPath) {
        $Subkeys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
        
        foreach ($Subkey in $Subkeys) {
            try {
                $DisplayName = (Get-ItemProperty -Path $Subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                
                if ($DisplayName) {
                    foreach ($Pattern in $DisplayNamePatterns) {
                        if ($DisplayName -like $Pattern) {
                            Write-Output "Freshservice Discovery Agent detected in registry: $DisplayName"
                            exit 0
                        }
                    }
                }
            }
            catch { }
        }
    }
}

# Not detected
exit 1
