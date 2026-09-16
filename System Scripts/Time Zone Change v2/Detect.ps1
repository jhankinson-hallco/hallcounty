$currentTZ = (Get-TimeZone).Id

if ($currentTZ -eq "Eastern Standard Time") {
    Write-Host "Eastern Time detected"
    exit 0
} else {
    exit 1
}