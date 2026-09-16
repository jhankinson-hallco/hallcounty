$ErrorActionPreference = 'SilentlyContinue'
if (Test-Path 'C:\ProgramData\VCRedist\2008\Installed.flag') { Write-Output 'Installed'; exit 0 }
exit 1
