# Google Earth Pro Win32 App - Intune Configuration Guide

## Issue Diagnosis & Resolution

### Original Problems Identified

The original script had the following issues preventing successful installation:

1. **`Set-StrictMode -Version Latest`** - This caused issues with null comparisons and type coercion
2. **Parameter type mismatch on line 105**: `[int]$InstallerExitCode = $null` - Cannot assign `$null` to a strongly typed `[int]` parameter
3. **Error logging function was not being triggered** - Due to early failures before logging was properly initialized
4. **Missing delay after installation** - The filesystem needs time to update before detection

### Fixes Applied

1. Removed `Set-StrictMode -Version Latest`
2. Changed `$InstallerExitCode` parameter from `[int]` to `[string]` with default empty string
3. Added `Start-Sleep -Seconds 5` after installation to allow filesystem to update
4. Improved error handling throughout the script
5. Added error category classification for troubleshooting

---

## Package Contents

```
GoogleEarthPro\
├── Install-GoogleEarthPro.ps1
├── Uninstall-GoogleEarthPro.ps1
├── Detect-GoogleEarthPro.ps1
└── GoogleEarthProSetup.exe (or googleearthprowin-7.3.6-x64.exe)
```

**Important**: Rename your downloaded installer to `GoogleEarthProSetup.exe` or update the `$InstallerName` variable in the install script.

---

## Intune Win32 App Configuration

### App Information

| Field | Value |
|-------|-------|
| **Name** | Google Earth Pro |
| **Description** | See End-User Description below |
| **Publisher** | Google LLC |
| **App Version** | 7.3.6.9345 |
| **Developer** | Google LLC |
| **Information URL** | https://www.google.com/earth/versions/#earth-pro |
| **Privacy URL** | https://policies.google.com/privacy |

### Program Settings

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-GoogleEarthPro.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleEarthPro.ps1` |
| **Install behavior** | System |
| **Device restart behavior** | No specific action |

### Requirements

| Requirement | Value |
|-------------|-------|
| **Operating system architecture** | 64-bit (or 32-bit if using 32-bit installer) |
| **Minimum operating system** | Windows 10 1607 |
| **Disk space required (MB)** | 2048 |
| **Physical memory required (MB)** | 2048 |
| **Minimum number of logical processors** | 2 |
| **Minimum CPU speed (MHz)** | 1000 |

### Return Codes

| Return Code | Code Type | Description |
|-------------|-----------|-------------|
| 0 | Success | Installation completed successfully |
| 1 | Failed | General failure |
| 1618 | Retry | Another installation in progress |
| 72001 | Failed | Installer not found in package |
| 72002 | Failed | Installer process failed to start |
| 72003 | Failed | Installer timeout exceeded |
| 72004 | Failed | Installation completed but app not detected |

### Detection Rules

| Setting | Value |
|---------|-------|
| **Rules format** | Use a custom detection script |
| **Script file** | `Detect-GoogleEarthPro.ps1` |
| **Run script as 32-bit process on 64-bit clients** | No |
| **Enforce script signature check** | No |

---

## End-User Description (Markdown)

```markdown
## Google Earth Pro

**Google Earth Pro** is a free desktop application that lets you view satellite imagery, maps, terrain, and 3D buildings for locations around the world.

### What you can do
* **Explore the world** with high-resolution satellite imagery
* **Measure distances and areas** with precision tools
* **Create and share maps** with custom placemarks and paths
* **Import GIS data** including shapefiles and spreadsheet data
* **Record HD videos** of virtual tours for presentations
* **View historical imagery** to see how locations have changed over time

> Tip: Use the **Historical Imagery** slider in the toolbar to view satellite images from different years.
```

---

## Creating the .intunewin Package

### Step 1: Download Google Earth Pro

Download from: https://support.google.com/earth/answer/168344?hl=en

- **64-bit**: `googleearthprowin-7.3.6-x64.exe`
- **32-bit**: `googleearthprowin-7.3.6.exe`

### Step 2: Prepare Source Folder

```
C:\IntunePackages\GoogleEarthPro\
├── Install-GoogleEarthPro.ps1
├── Uninstall-GoogleEarthPro.ps1
├── Detect-GoogleEarthPro.ps1
└── GoogleEarthProSetup.exe    (renamed from downloaded installer)
```

### Step 3: Create .intunewin Package

```cmd
IntuneWinAppUtil.exe -c "C:\IntunePackages\GoogleEarthPro" -s "Install-GoogleEarthPro.ps1" -o "C:\IntunePackages\Output"
```

---

## Troubleshooting

### Log Locations

| Log Type | Location |
|----------|----------|
| **Installation Errors** | `C:\IntuneAppLogs\GoogleEarthPro_Install.txt` |
| **Uninstall Errors** | `C:\IntuneAppLogs\GoogleEarthPro_Uninstall.txt` |
| **IME Log** | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` |

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No error log created | Script exits before error occurs | Check IME log for PowerShell errors |
| Error 72001 | Installer not in package | Verify EXE is included and filename matches `$InstallerName` |
| Error 72004 | Install ran but not detected | Check if 32-bit installer was used on 64-bit detection path |
| Silent install shows UI | OMAHA=1 not passed correctly | Verify ArgumentList in script |

### Manual Verification

Run detection script manually:
```powershell
PowerShell.exe -ExecutionPolicy Bypass -File Detect-GoogleEarthPro.ps1
echo Exit code: $LASTEXITCODE
```

Check installation paths:
```powershell
Test-Path "${env:ProgramFiles}\Google\Google Earth Pro\client\googleearth.exe"
Test-Path "${env:ProgramFiles(x86)}\Google\Google Earth Pro\client\googleearth.exe"
```

---

## Silent Install Parameters Reference

| Parameter | Description |
|-----------|-------------|
| `OMAHA=1` | Enables silent/unattended installation |
| `DESKTOPSHORTCUT=0` | Prevents desktop shortcut creation |

### Registry Settings (Optional Post-Install)

Disable startup tips:
```
REG ADD "HKCU\Software\Google\Google Earth Pro" /v "enableTips" /t REG_SZ /d "false" /f
```

Disable usage statistics:
```
REG ADD "HKCU\Software\Google\Google Earth Pro" /v "UsageStats2" /t REG_SZ /d "false" /f
```
