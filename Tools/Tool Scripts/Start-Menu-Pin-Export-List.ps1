# Export Start layout JSON to the same folder this script is running from
$OutPath = Join-Path -Path $PSScriptRoot -ChildPath "StartPinLayout.json"

# Ensure the folder exists (normally it will, but this keeps it robust)
if (-not (Test-Path -LiteralPath $PSScriptRoot)) {
    throw "Script root path not found: $PSScriptRoot"
}

Export-StartLayout -Path $OutPath
Write-Host "Exported Start layout to: $OutPath"