#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Install-LeadToolsOCX.ps1

Purpose:
- Registers specified LeadTools OCX controls using regsvr32 (silent).
- Designed for Microsoft Intune PowerShell script deployment.
- Logging occurs ONLY if an error happens.

Important Intune setting:
- If you deploy via Intune > Devices > Scripts (PowerShell), prefer:
  "Run script in 64-bit PowerShell" = Yes
  (Script will still correctly choose SysWOW64 regsvr32 for 32-bit OCX when needed.)
#>

# ============================
# CONFIG (EDIT HERE ONLY)
# ============================
$AppName = 'LeadToolsOCX'
$LogRoot = 'C:\IntuneScriptLogs'

# OCX paths to register
$OcxPaths = @(
    'C:\ossimob\MCT\Leadtools\ltdlg12n.ocx',
    'C:\ossimob\MCT\Leadtools\ltocx12n.ocx'
)

# Regsvr selection mode:
# - 'Auto' (recommended): chooses 32-bit vs 64-bit regsvr32 based on OCX PE header.
# - 'x86': forces SysWOW64\regsvr32.exe
# - 'x64': forces System32\regsvr32.exe
$RegsvrMode = 'Auto'
# ============================

$LogFile = Join-Path $LogRoot ("{0}_Install.txt" -f $AppName)

function Initialize-ErrorLog {
    # Creates folder + file ONLY when the first error occurs.
    try {
        if (-not (Test-Path -LiteralPath $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
            # Requirement: create the file first, then write to it (no single-line create+write).
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }
    } catch {
        # If logging itself fails, we still must fail the deployment correctly.
        # Avoid recursive logging attempts here.
        throw
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory)][string]$Message
    )
    Initialize-ErrorLog
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Get-PeMachineType {
    <#
    Reads PE header to determine whether a binary is 32-bit or 64-bit.
    Returns: 'x86', 'x64', or 'Unknown'
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $fs = $null
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $br = New-Object System.IO.BinaryReader($fs)

        # DOS header: e_lfanew offset is at 0x3C (60)
        $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $br.ReadInt32()

        if ($peOffset -le 0 -or $peOffset -gt ($fs.Length - 256)) { return 'Unknown' }

        # PE signature "PE\0\0" at peOffset
        $fs.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $sig = $br.ReadUInt32()
        if ($sig -ne 0x00004550) { return 'Unknown' } # "PE\0\0" little-endian

        # IMAGE_FILE_HEADER.Machine is next 2 bytes
        $machine = $br.ReadUInt16()

        switch ($machine) {
            0x014c { return 'x86' }   # IMAGE_FILE_MACHINE_I386
            0x8664 { return 'x64' }   # IMAGE_FILE_MACHINE_AMD64
            default { return 'Unknown' }
        }
    } catch {
        return 'Unknown'
    } finally {
        if ($fs) { $fs.Dispose() }
    }
}

function Resolve-Regsvr32Path {
    param(
        [Parameter(Mandatory)][ValidateSet('Auto','x86','x64')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$OcxPath
    )

    $system32  = Join-Path $env:WINDIR 'System32\regsvr32.exe'   # 64-bit regsvr32 on 64-bit OS
    $syswow64  = Join-Path $env:WINDIR 'SysWOW64\regsvr32.exe'   # 32-bit regsvr32 on 64-bit OS

    $is64OS = [Environment]::Is64BitOperatingSystem

    switch ($Mode) {
        'x64' {
            if (-not (Test-Path -LiteralPath $system32)) { throw "System32 regsvr32 not found at: $system32" }
            return $system32
        }
        'x86' {
            if ($is64OS) {
                if (-not (Test-Path -LiteralPath $syswow64)) { throw "SysWOW64 regsvr32 not found at: $syswow64" }
                return $syswow64
            } else {
                # 32-bit OS has only one regsvr32 in System32
                if (-not (Test-Path -LiteralPath $system32)) { throw "regsvr32 not found at: $system32" }
                return $system32
            }
        }
        'Auto' {
            if (-not (Test-Path -LiteralPath $OcxPath)) { throw "OCX does not exist at: $OcxPath" }

            $machine = Get-PeMachineType -Path $OcxPath

            if (-not $is64OS) {
                if (-not (Test-Path -LiteralPath $system32)) { throw "regsvr32 not found at: $system32" }
                return $system32
            }

            # 64-bit OS: choose correct regsvr32 based on binary type
            if ($machine -eq 'x86') {
                if (-not (Test-Path -LiteralPath $syswow64)) { throw "SysWOW64 regsvr32 not found at: $syswow64" }
                return $syswow64
            }

            if ($machine -eq 'x64') {
                if (-not (Test-Path -LiteralPath $system32)) { throw "System32 regsvr32 not found at: $system32" }
                return $system32
            }

            # Unknown: safest behavior is to try 32-bit first, then 64-bit (without double-registering on success).
            if (Test-Path -LiteralPath $syswow64) { return $syswow64 }
            if (Test-Path -LiteralPath $system32) { return $system32 }

            throw "No usable regsvr32 found under $env:WINDIR (System32/SysWOW64)."
        }
    }
}

function Invoke-Regsvr32 {
    param(
        [Parameter(Mandatory)][string]$Regsvr32Path,
        [Parameter(Mandatory)][string]$OcxPath
    )

    # /s = silent
    $args = @('/s', "`"$OcxPath`"")

    $p = Start-Process -FilePath $Regsvr32Path -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
    return [int]$p.ExitCode
}

# ----------------------------
# Main
# ----------------------------
try {
    # Validate inputs early (fail fast with meaningful exit codes)
    foreach ($p in $OcxPaths) {
        if (-not (Test-Path -LiteralPath $p)) {
            throw [System.IO.FileNotFoundException]::new("Required OCX file not found.", $p)
        }
    }

    foreach ($ocx in $OcxPaths) {
        $regsvr = Resolve-Regsvr32Path -Mode $RegsvrMode -OcxPath $ocx

        $exit = Invoke-Regsvr32 -Regsvr32Path $regsvr -OcxPath $ocx
        if ($exit -ne 0) {
            throw "regsvr32 failed for '$ocx' using '$regsvr' (exit code: $exit)."
        }
    }

    # Success
    exit 0
}
catch {
    # Log only on error (per requirement)
    try {
        Write-ErrorLog -Message ("ERROR: {0}" -f $_.Exception.Message)
        if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
            Write-ErrorLog -Message ("CONTEXT: {0}" -f ($_.InvocationInfo.PositionMessage -replace "`r?`n",' | '))
        }
    } catch {
        # If logging fails, continue to return a failure code anyway.
    }

    # Exit codes (simple, stable, researchable)
    # 20 = missing file
    # 40 = registration failure
    # 90 = unknown failure
    if ($_.Exception -is [System.IO.FileNotFoundException]) { exit 20 }
    if ($_.Exception.Message -like 'regsvr32 failed*') { exit 40 }
    exit 90
}