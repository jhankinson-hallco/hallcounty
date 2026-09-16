# Export current user's pinned Taskbar apps (Win32 + Store/UWP) to CSV + JSON
# Output goes to the same folder this script is running from (or current folder if run interactively).

$OutDir = if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }

$TaskbarPinsDir = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (-not (Test-Path -LiteralPath $TaskbarPinsDir)) {
    throw "Taskbar pins folder not found: $TaskbarPinsDir"
}

$WshShell = New-Object -ComObject WScript.Shell

$pins = Get-ChildItem -LiteralPath $TaskbarPinsDir -Filter "*.lnk" -File | ForEach-Object {
    $lnkPath = $_.FullName
    $sc = $WshShell.CreateShortcut($lnkPath)

    $target = $sc.TargetPath
    $args   = $sc.Arguments
    $wd     = $sc.WorkingDirectory

    # Determine if this is a Store/UWP pin (often stored as explorer.exe + shell:AppsFolder\AUMID)
    $aumid = $null
    $type  = "DesktopApp"

    if ($args -match '(?i)shell:AppsFolder\\(.+)$') {
        $aumid = $Matches[1].Trim()
        $type = "PackagedApp"
    } elseif ($target -match '(?i)\\explorer\.exe$' -and $args -match '(?i)shell:AppsFolder\\(.+)$') {
        $aumid = $Matches[1].Trim()
        $type = "PackagedApp"
    }

    [PSCustomObject]@{
        PinName          = $_.BaseName
        LinkPath         = $lnkPath
        PinType          = $type              # DesktopApp or PackagedApp
        TargetPath       = $target            # For DesktopApp pins
        Arguments        = $args
        WorkingDirectory = $wd
        AUMID            = $aumid             # For PackagedApp pins (Store/UWP)
    }
}

# Keep current order as returned by filesystem; you can also sort by name if preferred.
# $pins = $pins | Sort-Object PinName

$csvPath  = Join-Path $OutDir "TaskbarPins_Export.csv"
$jsonPath = Join-Path $OutDir "TaskbarPins_Export.json"

$pins | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$pins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host "Exported Taskbar pins:"
Write-Host " - $csvPath"
Write-Host " - $jsonPath"