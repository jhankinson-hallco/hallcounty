<# 
.SYNOPSIS
  Intune detection for .NET Framework 3.5 feature state.
  Exit 0 = detected/installed
  Exit 1 = not detected
#>

try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -ErrorAction Stop
    if ($feature.State -eq 'Enabled') {
        Write-Output "NetFx3 is Enabled."
        exit 0
    }
    else {
        Write-Output "NetFx3 is NOT enabled. State: $($feature.State)"
        exit 1
    }
}
catch {
    Write-Output "Failed to query NetFx3 state."
    exit 1
}