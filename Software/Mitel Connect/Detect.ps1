#requires -version 5.1

<#
.SYNOPSIS
    Detect.ps1 - Mitel Connect

.DESCRIPTION
    Intune detection script - checks if Mitel Connect is installed.
    
    Detection criteria:
    - C:\Program Files (x86)\Mitel\Connect folder exists
#>

$ConnectFolder = 'C:\Program Files (x86)\Mitel\Connect'

if (Test-Path -LiteralPath $ConnectFolder -PathType Container) {
    Write-Output "Mitel Connect installed at $ConnectFolder"
    exit 0
}
else {
    exit 1
}
