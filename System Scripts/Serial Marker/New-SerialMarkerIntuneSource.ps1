#Requires -Version 5.1

<#
.SYNOPSIS
    Creates a clean Intune package-source folder for SerialMarker.

.DESCRIPTION
    Local packaging utility. Copies only the three Intune files required for
    the SerialMarker Win32 app into a new, versioned staging folder under
    C:\Temp\IntunePackageSource\SerialMarker. It does not run
    IntuneWinAppUtil.exe and does not build an .intunewin package.

    Use the generated folder as the source folder during Jeremy's manual
    packaging step. This prevents the project-root PDQ subtree and local
    development files from being included in the Intune payload.

.NOTES
    Version:        1.0.0
    Script Type:    Local Intune Packaging Utility
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  26/08/2026
    Purpose:        Create a clean SerialMarker Intune package-source folder.

    CHANGE LOG
    Change: 26/08/2026 - Initial release -- ver. 1.0.0

    This utility stages files only. Jeremy manually builds the .intunewin.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:StagingRoot = 'C:\Temp\IntunePackageSource\SerialMarker'
$script:SourceFiles = @(
    'Install-SerialMarker.ps1'
    'Uninstall-SerialMarker.ps1'
    'Detect.ps1'
)

try {
    $InstallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Install-SerialMarker.ps1'
    if (-not (Test-Path -LiteralPath $InstallScriptPath -PathType Leaf)) {
        throw "Install script not found at '$InstallScriptPath'."
    }

    $VersionMatch = Select-String -LiteralPath $InstallScriptPath -Pattern "^\`$script:AppVersion\s*=\s*'([^']+)'$" -ErrorAction Stop
    if (@($VersionMatch).Count -ne 1) {
        throw 'Could not determine exactly one AppVersion from Install-SerialMarker.ps1.'
    }
    $PackageVersion = $VersionMatch.Matches[0].Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($PackageVersion)) {
        throw 'The detected AppVersion was empty.'
    }

    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $DestinationName = 'v{0}-{1}' -f $PackageVersion, $Timestamp
    $DestinationPath = Join-Path -Path $script:StagingRoot -ChildPath $DestinationName
    if (Test-Path -LiteralPath $DestinationPath) {
        throw "Staging destination already exists: '$DestinationPath'."
    }

    New-Item -ItemType Directory -Path $DestinationPath -ErrorAction Stop | Out-Null

    foreach ($SourceName in $script:SourceFiles) {
        $SourcePath = Join-Path -Path $PSScriptRoot -ChildPath $SourceName
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "Required Intune source file not found: '$SourcePath'."
        }

        $DestinationFile = Join-Path -Path $DestinationPath -ChildPath $SourceName
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationFile -Force -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $DestinationFile -PathType Leaf)) {
            throw "Failed to verify staged file '$DestinationFile'."
        }
    }

    $StagedFiles = @(Get-ChildItem -LiteralPath $DestinationPath -File -ErrorAction Stop)
    $StagedDirectories = @(Get-ChildItem -LiteralPath $DestinationPath -Directory -ErrorAction Stop)
    if ($StagedFiles.Count -ne $script:SourceFiles.Count -or $StagedDirectories.Count -ne 0) {
        throw "Staging verification failed for '$DestinationPath'."
    }

    Write-Output ("Clean Intune source ready: {0}" -f $DestinationPath)
    Write-Output 'Setup file: Install-SerialMarker.ps1'
    Write-Output 'No .intunewin package was built.'
    exit 0
}
catch {
    Write-Output ("Failed to create clean Intune source: {0}" -f $_.Exception.Message)
    exit 1
}
