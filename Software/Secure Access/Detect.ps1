$ErrorActionPreference = 'SilentlyContinue'

$marker = 'C:\ProgramData\SecureAccess\InstalledAndConfigured.flag'

function Get-UninstallEntries {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -like '*Secure*Access*Client*' }
    }
}

$installed = $false
if ((Get-UninstallEntries | Select-Object -First 1) -ne $null) {
    $installed = $true
}

if ($installed -and (Test-Path $marker)) {
    Write-Output 'Installed'
    exit 0
}

exit 1