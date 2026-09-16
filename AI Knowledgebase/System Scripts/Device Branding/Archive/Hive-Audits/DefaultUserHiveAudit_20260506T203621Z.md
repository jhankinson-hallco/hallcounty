# Default User Hive Audit

- Source hive: `C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files\System Scripts\Device Branding\DefaultUser.NTUSER.dat`
- Source SHA256 before audit: `5A6152601AB907E8E65DB0678FA0EB4559B6269DAAB0A36EB84B56C7BE7D39B3`
- Audit method: copied hive to temp path, mounted copy at `HKU\CodexDBHiveAudit_20260506T203621Z`, enumerated all values, exported REG copy, unloaded hive.
- Unique keys with values: 15
- Total values: 35
- Inventory CSV: `C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files\AI Knowledgebase\System Scripts\Device Branding\Archive\Hive-Audits\DefaultUserHiveInventory_20260506T203621Z.csv`
- REG export: `C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files\AI Knowledgebase\System Scripts\Device Branding\Archive\Hive-Audits\DefaultUserHiveExport_20260506T203621Z.reg`

## IntuneDeploymentFiles References

- `HKCU\Control Panel\Desktop` :: `Wallpaper` = `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` (String)

## Interesting Rows

- `HKCU\Control Panel\Desktop` :: `TileWallpaper` = `0` (String)
- `HKCU\Control Panel\Desktop` :: `Wallpaper` = `C:\IntuneDeploymentFiles\Images\HCWallpaper.jpg` (String)
- `HKCU\Control Panel\Desktop` :: `WallpaperStyle` = `10` (String)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` :: `Start_IrisRecommendations` = `0` (DWord)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` :: `Start_Layout` = `1` (DWord)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` :: `Start_SearchFiles` = `2` (DWord)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` :: `Start_TrackDocs` = `0` (DWord)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\MMTaskbarGl` :: `SystemSettings_DesktopTaskbar_GroupingMode` = `2` (String)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton` :: `SystemSettings_DesktopTaskbar_TaskView` = `0` (String)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAl` :: `SystemSettings_DesktopTaskbar_Al` = `0` (String)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa` :: `SystemSettings_DesktopTaskbar_Da` = `` (String)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlom` :: `SystemSettings_DesktopTaskbar_GroupingMode` = `2` (String)

## Potentially User/Environment-Specific Data

- None found by string scan.

## Policy And Run Keys

- No HKCU policy values found.
- No HKCU Run values found.
