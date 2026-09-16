#requires -version 5.1
Set-StrictMode -Version Latest

$OSMCTExeName = 'SunGuard.PS.OSSI.UI.OSMCT.exe'

$SpeechDisplayNamePatterns = @(
    'OSSI Speech',
    'Speech Synthesis',
    'OSSI Speech Synthesis'
)

$SpeechExeCandidates = @(
    'OSSI Speech Synthesis.exe',
    'Speech Synthesis.exe'
)

function Find-ExeInProgramFiles {
    param([string]$ExeName)

    $roots = @($env:ProgramFiles, $env:ProgramFiles(x86)) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($r in $roots) {
        try {
            $found = Get-ChildItem -Path $r -Filter $ExeName -Recurse -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            if ($found) { return $found.FullName }
        } catch {}
    }
    return $null
}

function Test-SpeechByUninstallName {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }

        foreach ($child in (Get-ChildItem $p -ErrorAction SilentlyContinue)) {
            try {
                $prop = Get-ItemProperty $child.PSPath -ErrorAction SilentlyContinue
                $dn = $prop.DisplayName
                if (-not $dn) { continue }

                foreach ($pat in $SpeechDisplayNamePatterns) {
                    if ($dn -like "*$pat*") { return $true }
                }
            } catch {}
        }
    }
    return $false
}

function Test-SpeechByFiles {
    foreach ($c in $SpeechExeCandidates) {
        if (Find-ExeInProgramFiles -ExeName $c) { return $true }
    }
    return $false
}

# --- OSMCT presence
$osmctPath = Find-ExeInProgramFiles -ExeName $OSMCTExeName
if (-not $osmctPath) { exit 1 }

# --- Speech presence
$speechInstalled = (Test-SpeechByUninstallName) -or (Test-SpeechByFiles)

if ($speechInstalled) { exit 0 }
exit 1