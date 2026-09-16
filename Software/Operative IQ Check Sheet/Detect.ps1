#requires -version 5.1

<#
.SYNOPSIS
    Detect.ps1 - Operative IQ Check Sheet

.DESCRIPTION
    Intune detection script - checks for tag file created during install.
    
    Exit 0 = Detected (installed)
    Exit 1 = Not detected
#>

$TagFile = Join-Path -Path $env:ProgramData -ChildPath 'IntuneTags\OperativeIQ_CheckSheet.tag'

if (Test-Path -LiteralPath $TagFile -PathType Leaf) {
    Write-Output "Operative IQ Check Sheet detected via tag file"
    exit 0
}

exit 1
