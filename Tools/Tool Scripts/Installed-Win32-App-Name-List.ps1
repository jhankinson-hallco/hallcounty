# 64-bit apps
$u64 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
# 32-bit apps on 64-bit Windows
$u32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"

Get-ItemProperty $u64, $u32 |
Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne "" } |
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString |
Sort-Object DisplayName