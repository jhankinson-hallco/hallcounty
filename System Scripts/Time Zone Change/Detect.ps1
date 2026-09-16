<#
Detect.ps1
Exit 0 = Detected (time zone correct)
Exit 1 = Not detected
#>

$ErrorActionPreference = "SilentlyContinue"

$TargetTimeZoneId = "Eastern Standard Time"

try {
    $current = (Get-TimeZone).Id
    if ($current -eq $TargetTimeZoneId) {
        Write-Output "Installed"
        exit 0
    }
} catch {
    # Ignore and fail detection
}

exit 1