# Detect-MicrosoftPrimaryInteroperabilityAssemblies2005.ps1
# Detects Microsoft Primary Interoperability Assemblies 2005

$ErrorActionPreference = 'SilentlyContinue'

$ExpectedDisplayName = 'Microsoft Primary Interoperability Assemblies 2005'
$ExpectedProductCode = '{D24DB8B9-BB6C-4334-9619-BA1C650E13D3}'

$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ExpectedProductCode",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ExpectedProductCode"
)

foreach ($Key in $UninstallKeys) {
    if (Test-Path $Key) {
        $Item = Get-ItemProperty -Path $Key

        if ($Item.DisplayName -eq $ExpectedDisplayName) {
            Write-Output "Installed: $($Item.DisplayName) $($Item.DisplayVersion)"
            exit 0
        }
    }
}

# Fallback: search uninstall registry by exact display name.
$SearchRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($Root in $SearchRoots) {
    if (Test-Path $Root) {
        $Match = Get-ChildItem -Path $Root |
            Get-ItemProperty |
            Where-Object {
                $_.DisplayName -eq $ExpectedDisplayName -and
                $_.Publisher -eq 'Microsoft Corporation'
            } |
            Select-Object -First 1

        if ($Match) {
            Write-Output "Installed: $($Match.DisplayName) $($Match.DisplayVersion)"
            exit 0
        }
    }
}

exit 1