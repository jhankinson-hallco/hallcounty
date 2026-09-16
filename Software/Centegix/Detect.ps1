<#
.SYNOPSIS
    Detect-Centegix.ps1

.DESCRIPTION
    Detects if Centegix CrisisAlert is installed.
    
    DETECTION LOGIC:
    - Checks for Centegix executable in common installation paths
    - Falls back to registry check for installed product

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune
    
    INTUNE DETECTION:
    - Exit code 0 + Write-Output = Application DETECTED (installed)
    - Exit code 1 = Application NOT DETECTED (not installed)
    
    INTUNE CONFIGURATION:
    Detection rule type: Use a custom detection script
    Script file: Detect-Centegix.ps1
    Run script as 32-bit process on 64-bit clients: No
    Enforce script signature check: No
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Detection paths - check for executable files
$DetectionPaths = @(
    "${env:ProgramFiles}\Centegix\Centegix.exe",
    "${env:ProgramFiles}\CENTEGIX\Centegix.exe",
    "${env:ProgramFiles}\Centegix\CrisisAlert.exe",
    "${env:ProgramFiles}\CENTEGIX\CrisisAlert.exe",
    "${env:LocalAppData}\Programs\centegix\Centegix.exe"
)

# Display name patterns for registry detection
$DisplayNamePatterns = @(
    "*Centegix*",
    "*CrisisAlert*"
)

# =============================================================================
# DETECTION LOGIC
# =============================================================================

# Method 1: Check for executable files
foreach ($Path in $DetectionPaths) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Write-Output "Centegix detected at: $Path"
        exit 0
    }
}

# Method 2: Check registry for installed product
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
                            Write-Output "Centegix detected in registry: $DisplayName"
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
