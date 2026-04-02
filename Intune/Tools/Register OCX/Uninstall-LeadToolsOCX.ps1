#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Uninstall-LeadToolsOCX.ps1

Purpose:
- Unregisters specified OCX controls using regsvr32 (/u /s).
- Logging occurs ONLY if an error happens.
#>

# ============================
# CONFIG (EDIT HERE ONLY)
# ============================
$AppName = 'LeadToolsOCX'
$LogRoot = 'C:\IntuneScriptLogs'

$OcxPaths = @(
    'C:\ossimob\MCT\Leadtools\ltdlg12n.ocx',
    'C:\ossimob\MCT\Leadtools\ltocx12n.ocx'
)

$RegsvrMode = 'Auto'   # 'Auto', 'x86', 'x64'
# ============================

$LogFile = Join-Path $LogRoot ("{0}_Uninstall.txt" -f $AppName)

function Initialize-ErrorLog {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-ErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    Initialize-ErrorLog
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Get-PeMachineType {
    param([Parameter(Mandatory)][string]$Path)
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        $br = New-Object System.IO.BinaryReader($fs)
        $fs.Seek(0x3C, 'Begin') | Out-Null
        $peOffset = $br.ReadInt32()
        if ($peOffset -le 0 -or $peOffset -gt ($fs.Length - 256)) { return 'Unknown' }
        $fs.Seek($peOffset, 'Begin') | Out-Null
        if ($br.ReadUInt32() -ne 0x00004550) { return 'Unknown' }
        $machine = $br.ReadUInt16()
        switch ($machine) {
            0x014c { 'x86' }
            0x8664 { 'x64' }
            default { 'Unknown' }
        }
    } catch { 'Unknown' }
    finally { if ($fs) { $fs.Dispose() } }
}

function Resolve-Regsvr32Path {
    param(
        [Parameter(Mandatory)][ValidateSet('Auto','x86','x64')]
        [string]$Mode,
        [Parameter(Mandatory)][string]$OcxPath
    )

    $system32 = Join-Path $env:WINDIR 'System32\regsvr32.exe'
    $syswow64 = Join-Path $env:WINDIR 'SysWOW64\regsvr32.exe'
    $is64OS   = [Environment]::Is64BitOperatingSystem

    switch ($Mode) {
        'x64' { return $system32 }
        'x86' { return ($is64OS ? $syswow64 : $system32) }
        'Auto' {
            if (-not $is64OS) { return $system32 }
            if (-not (Test-Path -LiteralPath $OcxPath)) { return $syswow64 } # best effort if missing

            $m = Get-PeMachineType -Path $OcxPath
            if ($m -eq 'x86') { return $syswow64 }
            if ($m -eq 'x64') { return $system32 }
            return $syswow64
        }
    }
}

function Invoke-Unregsvr32 {
    param(
        [Parameter(Mandatory)][string]$Regsvr32Path,
        [Parameter(Mandatory)][string]$OcxPath
    )

    # /u = unregister, /s = silent
    $args = @('/u','/s', "`"$OcxPath`"")
    $p = Start-Process -FilePath $Regsvr32Path -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
    return [int]$p.ExitCode
}

try {
    foreach ($ocx in $OcxPaths) {
        # If the file is gone already, treat as success (idempotent uninstall behavior).
        if (-not (Test-Path -LiteralPath $ocx)) { continue }

        $regsvr = Resolve-Regsvr32Path -Mode $RegsvrMode -OcxPath $ocx
        if (-not (Test-Path -LiteralPath $regsvr)) {
            throw "regsvr32 not found at expected path: $regsvr"
        }

        $exit = Invoke-Unregsvr32 -Regsvr32Path $regsvr -OcxPath $ocx
        if ($exit -ne 0) {
            throw "regsvr32 /u failed for '$ocx' using '$regsvr' (exit code: $exit)."
        }
    }

    exit 0
}
catch {
    try { Write-ErrorLog -Message ("ERROR: {0}" -f $_.Exception.Message) } catch {}
    # 50 = unregister failure, 90 = unknown failure
    if ($_.Exception.Message -like 'regsvr32 /u failed*') { exit 50 }
    exit 90
}