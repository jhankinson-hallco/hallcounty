# Lynx Notification Client - Intune Win32 App Configuration

## Overview

This package installs Lynx Notification Client, a mass notification and emergency communication platform that enables organizations to send critical alerts and messages to staff and stakeholders.

**Vendor:** Status Solutions / Lynx Guide  
**Website:** https://www.lynxguide.com/

## Package Contents

```
root:\
├── Install-LynxClient.ps1
├── Uninstall-LynxClient.ps1
├── Detect-LynxClient.ps1
├── LynxClient_v10.4.26.0.msi
└── LynxClient-Intune-Configuration.md
```

## Organization-Specific Configuration

This package is pre-configured for your organization:

| Setting | Value |
|---------|-------|
| Hostname | `city-of-gainesville-cb24.stratus-lynx.com` |
| Profile | `DefaultClientProfile` |

To change these settings, edit `Install-LynxClient.ps1` and modify:

```powershell
$LynxHostname = "city-of-gainesville-cb24.stratus-lynx.com"
$LynxProfile = "DefaultClientProfile"
```

## IntuneWinAppUtil Packaging

```powershell
# Package the folder
IntuneWinAppUtil.exe -c "C:\Path\To\LynxClient" -s "Install-LynxClient.ps1" -o "C:\Output"
```

## Intune Configuration

### App Information

| Setting | Value |
|---------|-------|
| Name | Lynx Notification Client |
| Description | Lynx mass notification and emergency communication client. Receives critical alerts and emergency messages from the organization's Lynx notification system. |
| Publisher | Status Solutions |
| App Version | 10.4.26.0 |
| Category | Business / Communication |
| Information URL | https://www.lynxguide.com/ |
| Developer | Status Solutions |
| Owner | IT Department |
| Notes | Configured for city-of-gainesville-cb24.stratus-lynx.com |

### Program

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-LynxClient.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-LynxClient.ps1` |
| Install behavior | System |
| Device restart behavior | No specific action |
| Return codes | 0 = Success, 1 = Failed, 1618 = Retry, 3010 = Soft reboot |

### Requirements

| Setting | Value |
|---------|-------|
| Operating system architecture | 64-bit, 32-bit |
| Minimum operating system | Windows 10 1607 |
| Disk space required (MB) | 100 |
| Physical memory required (MB) | 512 |
| Minimum number of logical processors | 1 |
| Minimum CPU speed (MHz) | 1000 |

### Detection Rules

| Setting | Value |
|---------|-------|
| Rules format | Use a custom detection script |
| Script file | Detect-LynxClient.ps1 |
| Run script as 32-bit process on 64-bit clients | No |
| Enforce script signature check | No |

**Alternative: Registry-based detection**

| Setting | Value |
|---------|-------|
| Rules format | Manually configure detection rules |
| Rule type | Registry |
| Key path | `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` |
| Value name | DisplayName |
| Detection method | String comparison |
| Operator | Contains |
| Value | Lynx |
| Associated with a 32-bit app on 64-bit clients | No |

## Exit Codes

### Standard Codes

| Code | Meaning | Intune Action |
|------|---------|---------------|
| 0 | Success | Mark as installed |
| 1 | General failure | Mark as failed |
| 1618 | Another installation in progress | Retry |
| 3010 | Reboot required | Soft reboot |

### Custom Error Codes

| Code | Description |
|------|-------------|
| 79001 | MSI installer not found in package |
| 79002 | MSI installation failed |
| 79003 | MSI installation timed out |
| 79004 | Installation completed but Lynx Client not detected |

## MSI Command Line Reference

The install script executes the following MSI command:

```cmd
msiexec.exe /i "LynxClient_v10.4.26.0.msi" HOSTNAME="city-of-gainesville-cb24.stratus-lynx.com" PROFILE="DefaultClientProfile" /qn /norestart /L*v "%TEMP%\LynxClient_MSI_Install.log"
```

### MSI Properties

| Property | Description |
|----------|-------------|
| HOSTNAME | Lynx server hostname (your organization's cloud instance) |
| PROFILE | Client profile name for configuration |

## Troubleshooting

### Check Installation Status

```powershell
# Check for Lynx Client executable
Get-ChildItem -Path "${env:ProgramFiles}\Lynx*" -Recurse -ErrorAction SilentlyContinue

# Check registry
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName -like "*Lynx*" } | 
    Select-Object DisplayName, DisplayVersion, UninstallString

# Run detection script manually
powershell.exe -ExecutionPolicy Bypass -File Detect-LynxClient.ps1
echo "Exit code: $LASTEXITCODE"
```

### Check Error Logs

```powershell
# View install error log
Get-Content "C:\IntuneAppLogs\LynxClient_Install.txt"

# View MSI verbose log (if error occurred)
Get-Content "$env:TEMP\LynxClient_MSI_Install.log" -Tail 100
```

### Manual Installation Test

```powershell
# Test install command (run as Administrator)
cd "C:\Path\To\Package"
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-LynxClient.ps1
echo "Exit code: $LASTEXITCODE"

# Or direct MSI install with logging
msiexec.exe /i "LynxClient_v10.4.26.0.msi" HOSTNAME="city-of-gainesville-cb24.stratus-lynx.com" PROFILE="DefaultClientProfile" /qn /L*v "C:\temp\lynx_install.log"
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| MSI not found (79001) | MSI file missing from package | Verify MSI is included when creating .intunewin |
| Install failed (79002) | MSI error | Check MSI log in %TEMP% for details |
| Detection failed (79004) | Non-standard install path | Update detection paths in scripts |
| Connection issues | Wrong hostname | Verify HOSTNAME parameter matches your Lynx instance |

## Network Requirements

Lynx Notification Client requires network connectivity to:
- Your Lynx server: `city-of-gainesville-cb24.stratus-lynx.com`
- Ports: Typically HTTPS (443) - verify with Lynx documentation

Ensure firewall rules allow outbound connections to your Lynx server.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 10.4.26.0 | 2026-01-29 | Initial Intune package |
