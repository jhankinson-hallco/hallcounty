# Detect.ps1 - VCRedist 2017-2022
# Checks for vcruntime140.dll in System32 (and SysWOW64 on 64-bit)

$ErrorActionPreference = 'SilentlyContinue'

$System32 = Join-Path -Path $env:WINDIR -ChildPath 'System32\vcruntime140.dll'
$SysWOW64 = Join-Path -Path $env:WINDIR -ChildPath 'SysWOW64\vcruntime140.dll'

$Is64Bit = [Environment]::Is64BitOperatingSystem

if ($Is64Bit) {
    # 64-bit OS: need both x64 (System32) and x86 (SysWOW64)
    if ((Test-Path -LiteralPath $System32) -and (Test-Path -LiteralPath $SysWOW64)) {
        Write-Output "Installed: x64 and x86"
        exit 0
    }
}
else {
    # 32-bit OS: need x86 (System32)
    if (Test-Path -LiteralPath $System32) {
        Write-Output "Installed: x86"
        exit 0
    }
}

exit 1
