$DebloatFolder = "C:\ProgramData\Debloat"
If (Test-Path $DebloatFolder) {
    Write-Output "$DebloatFolder exists. Skipping."
}
Else {
    Write-Output "The folder '$DebloatFolder' doesn't exist. This folder will be used for storing logs created after the script runs. Creating now."
    Start-Sleep 1
    New-Item -Path "$DebloatFolder" -ItemType Directory
    Write-Output "The folder $DebloatFolder was successfully created."
}

$templateFilePath = "C:\ProgramData\Debloat"

$zipUrl = "https://github.com/andrew-s-taylor/public/releases/download/DeBloat/RemoveBloat.zip"
$zipPath = "$templateFilePath\RemoveBloat.zip"
$extractPath = "$templateFilePath"


Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force


##Populate between the speechmarks any apps you want to whitelist, comma-separated
$arguments = ' -customwhitelist ""'
$pathwithfile = "$templateFilePath\removebloat.ps1"

invoke-expression -Command "$pathwithfile $arguments"