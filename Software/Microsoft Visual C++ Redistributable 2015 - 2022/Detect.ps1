<#
.SYNOPSIS
    Detect-VCRedist2015-2022.ps1

.DESCRIPTION
    Detects if Microsoft Visual C++ Redistributable 2015-2022 is installed.
    
    DETECTION LOGIC:
    - On 64-bit systems: Checks for BOTH x64 and x86 runtime DLLs
    - On 32-bit systems: Checks for x86 runtime DLL only
    
    The vcruntime140.dll is the core runtime DLL installed by VC++ Redist 2015-2022.

.NOTES
    Author:         Systems Administrator
    Environment:    Microsoft Intune
    
    INTUNE DETECTION:
    - Exit code 0 + Write-Output = Application DETECTED (installed)
    - Exit code 1 = Application NOT DETECTED (not installed)
    
    INTUNE CONFIGURATION:
    Detection rule type: Use a custom detection script
    Script file: Detect-VCRedist2015-2022.ps1
    Run script as 32-bit process on 64-bit clients: No
    Enforce script signature check: No
#>

#Requires -Version 5.1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Detection paths - vcruntime140.dll is the primary runtime DLL
$DetectionPathX64 = "${env:SystemRoot}\System32\vcruntime140.dll"
$DetectionPathX86 = "${env:SystemRoot}\SysWOW64\vcruntime140.dll"

# =============================================================================
# DETECTION LOGIC
# =============================================================================

if ([Environment]::Is64BitOperatingSystem) {
    # 64-bit OS: Require BOTH x64 and x86 runtimes
    $X64Exists = Test-Path -LiteralPath $DetectionPathX64 -PathType Leaf
    $X86Exists = Test-Path -LiteralPath $DetectionPathX86 -PathType Leaf
    
    if ($X64Exists -and $X86Exists) {
        Write-Output "VC++ Redistributable 2015-2022 detected (x64 and x86)"
        exit 0
    }
}
else {
    # 32-bit OS: Only require x86 runtime
    # Note: On 32-bit, System32 contains 32-bit DLLs
    $X86Path = "${env:SystemRoot}\System32\vcruntime140.dll"
    
    if (Test-Path -LiteralPath $X86Path -PathType Leaf) {
        Write-Output "VC++ Redistributable 2015-2022 detected (x86)"
        exit 0
    }
}

# Not detected
exit 1
