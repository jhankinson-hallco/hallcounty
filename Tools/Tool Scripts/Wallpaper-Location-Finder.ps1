#Requires -Version 5.1

<#
.SYNOPSIS
    Finds the wallpaper most likely applied to newly created user profiles.

.DESCRIPTION
    Checks:
      - Default user registry hive (NTUSER.DAT)
      - Default user theme files / cached wallpaper files
      - Standard Windows wallpaper/theme folders
      - Common OEM folders (Dell / Lenovo)

    Safe to run locally in an elevated PowerShell session.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$defaultUserProfile = 'C:\Users\Default'
$defaultUserHive    = Join-Path $defaultUserProfile 'NTUSER.DAT'
$tempHiveName       = 'DefaultProfileAuditTemp'
$tempHiveRoot       = "HKU\$tempHiveName"
$tempHivePsPath     = "Registry::HKEY_USERS\$tempHiveName"

$results = New-Object System.Collections.Generic.List[object]
$loadedHive = $false

function Add-Finding {
    param(
        [string]$Category,
        [string]$Item,
        [string]$Path,
        [string]$Status,
        [string]$Details
    )

    $results.Add([pscustomobject]@{
        Category = $Category
        Item     = $Item
        Path     = $Path
        Status   = $Status
        Details  = $Details
    })
}

function Test-SafePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        return (Test-Path -LiteralPath $Path)
    }
    catch {
        return $false
    }
}

function Get-ThemeWallpaperValue {
    param([string]$ThemePath)

    if (-not (Test-SafePath -Path $ThemePath)) {
        return $null
    }

    $wallpaperLine = Get-Content -LiteralPath $ThemePath -ErrorAction Stop |
        Where-Object { $_ -match '^\s*Wallpaper\s*=' } |
        Select-Object -First 1

    if (-not $wallpaperLine) {
        return $null
    }

    return (($wallpaperLine -split '=', 2)[1]).Trim()
}

try {
    Write-Host "Checking standard Windows wallpaper and theme folders..." -ForegroundColor Cyan

    $standardPaths = @(
        'C:\Windows\Web\Wallpaper',
        'C:\Windows\Web\4K\Wallpaper\Windows',
        'C:\Windows\Web\Screen',
        'C:\Windows\Resources\Themes',
        'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Themes'
    )

    foreach ($path in $standardPaths) {
        if (Test-SafePath -Path $path) {
            Add-Finding -Category 'Standard Path' -Item 'Folder Exists' -Path $path -Status 'Found' -Details 'Standard wallpaper/theme location exists.'
        }
        else {
            Add-Finding -Category 'Standard Path' -Item 'Folder Exists' -Path $path -Status 'Missing' -Details 'Path not present.'
        }
    }

    Write-Host "Checking Default user theme files..." -ForegroundColor Cyan

    $defaultThemeFolder = 'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Themes'
    $defaultThemeFile   = Join-Path $defaultThemeFolder 'Custom.theme'
    $cachedFilesFolder  = Join-Path $defaultThemeFolder 'CachedFiles'
    $transcodedFile     = Join-Path $defaultThemeFolder 'TranscodedWallpaper'

    if (Test-SafePath -Path $defaultThemeFile) {
        $themeWallpaper = Get-ThemeWallpaperValue -ThemePath $defaultThemeFile
        Add-Finding -Category 'Default Profile Theme' -Item 'Custom.theme' -Path $defaultThemeFile -Status 'Found' -Details ("Wallpaper entry: {0}" -f ($(if ($themeWallpaper) { $themeWallpaper } else { '<none found>' })))
    }

    if (Test-SafePath -Path $transcodedFile) {
        Add-Finding -Category 'Default Profile Theme' -Item 'TranscodedWallpaper' -Path $transcodedFile -Status 'Found' -Details 'Default profile contains a transcoded wallpaper file.'
    }

    if (Test-SafePath -Path $cachedFilesFolder) {
        Get-ChildItem -LiteralPath $cachedFilesFolder -File -ErrorAction Stop | ForEach-Object {
            Add-Finding -Category 'Default Profile Theme' -Item 'Cached Wallpaper File' -Path $_.FullName -Status 'Found' -Details 'Cached wallpaper file in Default profile.'
        }
    }

    Write-Host "Loading Default user registry hive..." -ForegroundColor Cyan

    if (-not (Test-SafePath -Path $defaultUserHive)) {
        throw "Default user hive not found at '$defaultUserHive'."
    }

    & reg.exe load $tempHiveRoot $defaultUserHive | Out-Null
    $loadedHive = $true

    $desktopKey = Join-Path $tempHivePsPath 'Control Panel\Desktop'
    $themesKey  = Join-Path $tempHivePsPath 'Software\Microsoft\Windows\CurrentVersion\Themes'

    if (Test-Path -LiteralPath $desktopKey) {
        $desktopProps = Get-ItemProperty -LiteralPath $desktopKey -ErrorAction Stop

        $wallpaperPath   = $desktopProps.Wallpaper
        $wallpaperStyle  = $desktopProps.WallpaperStyle
        $tileWallpaper   = $desktopProps.TileWallpaper

        Add-Finding -Category 'Default User Registry' -Item 'Wallpaper Value' -Path $wallpaperPath -Status ($(if (Test-SafePath -Path $wallpaperPath) { 'Exists' } elseif ([string]::IsNullOrWhiteSpace($wallpaperPath)) { 'Blank' } else { 'Missing Target' })) -Details ("WallpaperStyle={0}; TileWallpaper={1}" -f $wallpaperStyle, $tileWallpaper)
    }

    if (Test-Path -LiteralPath $themesKey) {
        $themeProps = Get-ItemProperty -LiteralPath $themesKey -ErrorAction Stop

        $currentTheme = $themeProps.CurrentTheme
        if (-not [string]::IsNullOrWhiteSpace($currentTheme)) {
            $themeWallpaper = Get-ThemeWallpaperValue -ThemePath $currentTheme
            Add-Finding -Category 'Default User Registry' -Item 'CurrentTheme' -Path $currentTheme -Status ($(if (Test-SafePath -Path $currentTheme) { 'Exists' } else { 'Missing Target' })) -Details ("Wallpaper entry from theme: {0}" -f ($(if ($themeWallpaper) { $themeWallpaper } else { '<none found>' })))
        }
    }

    Write-Host "Checking common OEM folders..." -ForegroundColor Cyan

    $oemRoots = @(
        'C:\ProgramData\Dell',
        'C:\Program Files\Dell',
        'C:\Program Files (x86)\Dell',
        'C:\ProgramData\Lenovo',
        'C:\Program Files\Lenovo',
        'C:\Program Files (x86)\Lenovo'
    )

    $oemImageExtensions = '*.jpg','*.jpeg','*.png','*.bmp','*.webp'

    foreach ($root in $oemRoots) {
        if (Test-SafePath -Path $root) {
            Add-Finding -Category 'OEM Path' -Item 'Folder Exists' -Path $root -Status 'Found' -Details 'OEM folder exists.'

            try {
                Get-ChildItem -LiteralPath $root -Recurse -File -Include $oemImageExtensions -ErrorAction SilentlyContinue |
                    Select-Object -First 20 |
                    ForEach-Object {
                        Add-Finding -Category 'OEM Image Candidate' -Item 'Image File' -Path $_.FullName -Status 'Found' -Details 'Possible OEM wallpaper or branding asset.'
                    }
            }
            catch {
                Add-Finding -Category 'OEM Path' -Item 'Scan Error' -Path $root -Status 'Warning' -Details $_.Exception.Message
            }
        }
    }

    Write-Host ""
    Write-Host "==== MOST LIKELY ANSWER ====" -ForegroundColor Green

    $bestGuess = $results | Where-Object {
        $_.Category -eq 'Default User Registry' -and
        $_.Item -eq 'Wallpaper Value' -and
        $_.Status -in @('Exists','Missing Target','Blank')
    } | Select-Object -First 1

    if ($bestGuess) {
        $bestGuess | Format-List
    }
    else {
        Write-Host "No direct Default User registry wallpaper value was found." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "==== ALL FINDINGS ====" -ForegroundColor Green
    $results | Sort-Object Category, Item, Path | Format-Table -AutoSize
}
catch {
    Write-Error $_.Exception.Message
}
finally {
    if ($loadedHive) {
        try {
            & reg.exe unload $tempHiveRoot | Out-Null
        }
        catch {
            Write-Warning "Failed to unload temporary hive '$tempHiveRoot'. You may need to unload it manually."
        }
    }
}