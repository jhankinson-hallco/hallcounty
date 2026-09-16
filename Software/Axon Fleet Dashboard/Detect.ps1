<# 
Detect-AxonViewXL.ps1
Simple Intune detection for Axon View XL
- No product codes
- Just verifies the main agent binary exists
- Exit 0 = detected
- Exit 1 = not detected
#>

[CmdletBinding()]
param()

$ExePath = 'C:\Program Files (x86)\Axon\Axon Fleet\Agent\axon-agent.exe'

try {
    if (Test-Path -Path $ExePath) {
        exit 0   # Detected
    }
    else {
        exit 1   # Not detected
    }
}
catch {
    # If anything weird happens, fail as not detected (Intune will try again depending on assignment)
    exit 1
}