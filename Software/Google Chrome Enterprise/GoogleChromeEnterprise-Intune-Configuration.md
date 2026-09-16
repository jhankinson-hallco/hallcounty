# Google Chrome Enterprise - Intune Win32 App Configuration

## Overview

This package deploys Google Chrome Enterprise (64-bit) via Microsoft Intune as a Win32 application. It includes optional installations for Legacy Browser Support and Endpoint Verification extensions.

## Package Contents

```
root:\
├── Configuration\
│   ├── adm\                                (Legacy ADM templates)
│   ├── admx\                               (ADMX policy templates)
│   ├── examples\                           (Configuration examples)
│   ├── com.google.Chrome.plist             (macOS policy template)
│   └── initial_preferences.file            (Chrome initial preferences)
├── Documentation\
│   └── README.pdf                          (Google documentation)
├── Installers\
│   ├── GoogleChromeStandaloneEnterprise64.msi
│   ├── LegacyBrowserSupport_8.1.0.0_en_x64.msi
│   └── EndpointVerification_2.0.3.msi
├── Install-GoogleChromeEnterprise.ps1
├── Uninstall-GoogleChromeEnterprise.ps1
├── Detect.ps1
└── VERSION.file
```

## IntuneWinAppUtil Packaging

```powershell
# Package the entire folder
# Source folder: The folder containing all the above files
# Setup file: Install-GoogleChromeEnterprise.ps1
# Output folder: Where to save the .intunewin file

IntuneWinAppUtil.exe -c "C:\Path\To\GoogleChromeEnterprise" -s "Install-GoogleChromeEnterprise.ps1" -o "C:\Output"
```

## Intune Configuration

### App Information

| Setting | Value |
|---------|-------|
| Name | Google Chrome Enterprise |
| Description | Google Chrome Enterprise browser with managed policy support |
| Publisher | Google LLC |
| App Version | (Version of Chrome MSI being deployed) |
| Category | Productivity / Web Browsers |
| Information URL | https://chromeenterprise.google/browser/ |
| Privacy URL | https://policies.google.com/privacy |
| Developer | Google LLC |
| Owner | IT Department |
| Notes | Includes Legacy Browser Support extension |

### Program

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-GoogleChromeEnterprise.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-GoogleChromeEnterprise.ps1` |
| Install behavior | System |
| Device restart behavior | Determine behavior based on return codes |
| Return codes | 0 = Success, 1 = Failed, 1618 = Retry, 3010 = Soft reboot |

### Requirements

| Setting | Value |
|---------|-------|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 1607 |
| Disk space required (MB) | 500 |
| Physical memory required (MB) | 1024 |
| Minimum number of logical processors | 1 |
| Minimum CPU speed (MHz) | 1000 |

### Detection Rules

| Setting | Value |
|---------|-------|
| Rules format | Use a custom detection script |
| Script file | Detect.ps1 |
| Run script as 32-bit process on 64-bit clients | No |
| Enforce script signature check | No |

**Alternative: File-based detection (simpler)**

| Setting | Value |
|---------|-------|
| Rules format | Manually configure detection rules |
| Rule type | File |
| Path | `C:\Program Files\Google\Chrome\Application` |
| File or folder | `chrome.exe` |
| Detection method | File or folder exists |
| Associated with a 32-bit app on 64-bit clients | No |

## Configuration Options

### Install Script Options

Edit `Install-GoogleChromeEnterprise.ps1` to configure:

```powershell
# Install Legacy Browser Support extension (default: $true)
$InstallLegacyBrowserSupport = $true

# Install Endpoint Verification extension (default: $false)
$InstallEndpointVerification = $false
```

### Uninstall Script Options

Edit `Uninstall-GoogleChromeEnterprise.ps1` to configure:

```powershell
# Uninstall Legacy Browser Support with Chrome (default: $true)
$UninstallLegacyBrowserSupport = $true

# Uninstall Endpoint Verification with Chrome (default: $true)
$UninstallEndpointVerification = $true
```

## Exit Codes

### Standard Codes

| Code | Meaning | Intune Action |
|------|---------|---------------|
| 0 | Success | Mark as installed |
| 1 | General failure | Mark as failed |
| 1618 | Another installation in progress | Retry |
| 3010 | Reboot required | Soft reboot |

### Custom Error Codes (Install)

| Code | Description |
|------|-------------|
| 76001 | Chrome MSI not found in package |
| 76002 | Chrome MSI installation failed |
| 76003 | Chrome MSI installation timed out |
| 76004 | Chrome not detected after installation |
| 76005 | Legacy Browser Support installation failed (warning only) |
| 76006 | Endpoint Verification installation failed (warning only) |

### Custom Error Codes (Uninstall)

| Code | Description |
|------|-------------|
| 76010 | Chrome product code not found in registry |
| 76011 | Chrome uninstallation failed |
| 76012 | Chrome uninstallation timed out |
| 76013 | Chrome still detected after uninstallation |

## File Locations After Installation

| Item | Location |
|------|----------|
| Chrome executable | `C:\Program Files\Google\Chrome\Application\chrome.exe` |
| Chrome user data | `%LOCALAPPDATA%\Google\Chrome\User Data` |
| Error logs (install) | `C:\IntuneAppLogs\GoogleChromeEnterprise_Install.txt` |
| Error logs (uninstall) | `C:\IntuneAppLogs\GoogleChromeEnterprise_Uninstall.txt` |
| MSI logs (on error) | `%TEMP%\GoogleChromeEnterprise_Chrome_Install.log` |

## Group Policy / ADMX Templates

The `Configuration\admx\` folder contains ADMX templates for managing Chrome via Group Policy or Intune Administrative Templates.

### Deploy ADMX via Intune

1. Go to **Devices > Configuration profiles > Create profile**
2. Select **Windows 10 and later** > **Templates** > **Imported Administrative templates (Preview)**
3. Upload the ADMX/ADML files from `Configuration\admx\`
4. Configure policies as needed

### Common Chrome Policies

| Policy | Description |
|--------|-------------|
| HomepageLocation | Sets the default homepage |
| RestoreOnStartup | What to show when Chrome starts |
| BookmarkBarEnabled | Show/hide the bookmark bar |
| PasswordManagerEnabled | Enable/disable password manager |
| AutofillAddressEnabled | Enable/disable address autofill |
| BrowserSignin | Control browser sign-in |
| SyncDisabled | Disable Chrome Sync |
| ExtensionInstallBlocklist | Block specific extensions |
| ExtensionInstallAllowlist | Allow specific extensions |
| ExtensionInstallForcelist | Force-install extensions |

## Troubleshooting

### Check Installation Status

```powershell
# Verify Chrome is installed
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"

# Check Chrome version
(Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.ProductVersion

# Run detection script manually
powershell.exe -ExecutionPolicy Bypass -File Detect.ps1
echo "Exit code: $LASTEXITCODE"
```

### Check Error Logs

```powershell
# View install error log
Get-Content "C:\IntuneAppLogs\GoogleChromeEnterprise_Install.txt"

# View MSI log (if exists)
Get-Content "$env:TEMP\GoogleChromeEnterprise_Chrome_Install.log"
```

### Check IME Logs

```powershell
# Intune Management Extension logs
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Tail 100
```

### Manual Installation Test

```powershell
# Test install command (run as Administrator)
cd "C:\Path\To\Package"
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-GoogleChromeEnterprise.ps1
echo "Exit code: $LASTEXITCODE"
```

## Chrome Enterprise Resources

- Download: https://chromeenterprise.google/browser/download/
- Documentation: https://support.google.com/chrome/a/
- Policy List: https://chromeenterprise.google/policies/
- Release Notes: https://chromereleases.googleblog.com/

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-29 | Initial package |
