#requires -version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:PROCESSOR_ARCHITECTURE -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432 -ne '') {
    & "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe" `
        -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    exit $LASTEXITCODE
}

try {
    $pkg = Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -eq 'MSTeams' }

    if ($null -ne $pkg) {
        Write-Output 'Detected'
        exit 0
    }

    exit 1
}
catch {
    exit 1
}