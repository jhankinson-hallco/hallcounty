# Centegix CrisisAlert - Intune Win32 App Configuration

## Overview

This package installs Centegix CrisisAlert desktop application, an emergency response and notification platform that allows staff to receive real-time alerts and respond to emergencies.

## Package Contents

```
root:\
├── Install-Centegix.ps1
├── Uninstall-Centegix.ps1
├── Detect-Centegix.ps1
├── Centegix-Setup-1.10.3-win64.msi
└── Centegix-Intune-Configuration.md
```

## IntuneWinAppUtil Packaging

```powershell
# Package the folder
IntuneWinAppUtil.exe -c "C:\Path\To\Centegix" -s "Install-Centegix.ps1" -o "C:\Output"
```

## Intune Configuration

### App Information

| Setting | Value |
|---------|-------|
| Name | Centegix CrisisAlert |
| Description | Centegix CrisisAlert emergency response and notification application. Allows staff to receive real-time alerts and respond to emergencies. |
| Publisher | Centegix |
| App Version | 1.10.3 |
| Category | Business / Productivity |
| Information URL | https://www.centegix.com/ |
| Privacy URL | https://www.centegix.com/privacy-policy/ |
| Developer | Centegix |
| Owner | IT Department |
| Notes | CrisisAlert desktop client for emergency notifications |

### Program

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-Centegix.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-Centegix.ps1` |
| Install behavior | System |
| Device restart behavior | No specific action |
| Return codes | 0 = Success, 1 = Failed, 1618 = Retry, 3010 = Soft reboot |

### Requirements

| Setting | Value |
|---------|-------|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 1607 |
| Disk space required (MB) | 200 |
| Physical memory required (MB) | 512 |
| Minimum number of logical processors | 1 |
| Minimum CPU speed (MHz) | 1000 |

### Detection Rules

| Setting | Value |
|---------|-------|
| Rules format | Use a custom detection script |
| Script file | Detect-Centegix.ps1 |
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
| Value | Centegix |
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
| 78001 | MSI installer not found in package |
| 78002 | MSI installation failed |
| 78003 | MSI installation timed out |
| 78004 | Installation completed but Centegix not detected |

## Troubleshooting

### Check Installation Status

```powershell
# Check for Centegix executable
Get-ChildItem -Path "${env:ProgramFiles}\Centegix" -ErrorAction SilentlyContinue

# Check registry
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName -like "*Centegix*" } | 
    Select-Object DisplayName, DisplayVersion, UninstallString

# Run detection script manually
powershell.exe -ExecutionPolicy Bypass -File Detect-Centegix.ps1
echo "Exit code: $LASTEXITCODE"
```

### Check Error Logs

```powershell
# View install error log
Get-Content "C:\IntuneAppLogs\Centegix_Install.txt"

# View MSI verbose log (if error occurred)
Get-Content "$env:TEMP\Centegix_MSI_Install.log" -Tail 100
```

### Manual Installation Test

```powershell
# Test install command (run as Administrator)
cd "C:\Path\To\Package"
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-Centegix.ps1
echo "Exit code: $LASTEXITCODE"

# Or direct MSI install with logging
msiexec /i "Centegix-Setup-1.10.3-win64.msi" /qn /L*v "C:\temp\centegix_install.log"
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| MSI not found (78001) | MSI file missing from package | Verify MSI is included when creating .intunewin |
| Install failed (78002) | MSI error | Check MSI log in %TEMP% for details |
| Detection failed (78004) | Non-standard install path | Update detection paths in scripts |
| Timeout (78003) | Slow installation | Increase $InstallTimeoutSeconds value |

## Network Requirements

Centegix CrisisAlert may require network connectivity to:
- Centegix cloud services for alert delivery
- Push notification services

Ensure firewall rules allow outbound connections as required by Centegix.

## Support

- Centegix Support: support@centegix.com
- Phone: 800-950-9202
- Website: https://www.centegix.com/login/

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.10.3 | 2026-01-29 | Initial Intune package |
