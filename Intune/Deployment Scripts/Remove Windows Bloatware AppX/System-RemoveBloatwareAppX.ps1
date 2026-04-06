$DebloatFolder = "C:\ProgramData\Debloat"
$ZipUrl        = "https://github.com/jhankinson-hallco/hallcounty/raw/refs/heads/main/Intune/Deployment%20Scripts/Remove%20Windows%20Bloatware%20AppX/Debloat/RemoveBloat.zip"
$ZipPath       = Join-Path $DebloatFolder "RemoveBloat.zip"
$ScriptPath    = Join-Path $DebloatFolder "removebloat.ps1"
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

# Create working folder if missing
if (-not (Test-Path -LiteralPath $DebloatFolder)) {
    New-Item -Path $DebloatFolder -ItemType Directory -Force | Out-Null
}

# Download and extract package
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $DebloatFolder -Force

# Confirm extracted script exists
if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "removebloat.ps1 was not found after extraction: $ScriptPath"
}

# Run extracted script in a new PowerShell process
& $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath