# Microsoft Visual C++ Redistributable 2015-2022 - Intune Win32 App Configuration

## Overview

This package installs Microsoft Visual C++ Redistributable 2015-2022 (both x64 and x86) using Windows Package Manager (winget). This runtime is required by many applications built with Visual Studio 2015, 2017, 2019, and 2022.

**Important:** The 2015-2022 redistributables are binary compatible and consolidated into a single package. Installing the latest version provides support for all applications requiring VS 2015, 2017, 2019, or 2022 runtimes.

## Package Contents

```
root:\
├── Install-VCRedist2017-2022.ps1
├── Uninstall-VCRedist2017-2022.ps1
├── Detect-VCRedist2017-2022.ps1
└── VCRedist2017-2022-Intune-Configuration.md
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Windows Version | Windows 10 1809 or later |
| App Installer | winget must be available (pre-installed on Windows 10 1903+ and Windows 11) |
| Network | Internet connectivity to winget sources (CDN) |
| Context | System context (installs machine-wide) |

## IntuneWinAppUtil Packaging

```powershell
# Package the folder
IntuneWinAppUtil.exe -c "C:\Path\To\VCRedist2017-2022" -s "Install-VCRedist2017-2022.ps1" -o "C:\Output"
```

## Intune Configuration

### App Information

| Setting | Value |
|---------|-------|
| Name | Microsoft Visual C++ Redistributable 2015-2022 |
| Description | Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 (x64 and x86). Required runtime for applications built with Visual Studio 2015, 2017, 2019, and 2022. |
| Publisher | Microsoft Corporation |
| App Version | Latest (managed by winget) |
| Category | Utilities & Tools |
| Information URL | https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist |
| Privacy URL | https://privacy.microsoft.com/en-us/privacystatement |
| Developer | Microsoft Corporation |
| Owner | IT Department |
| Notes | Installed via winget. Auto-updates handled by winget if configured. |

### Program

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-VCRedist2017-2022.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-VCRedist2017-2022.ps1` |
| Install behavior | System |
| Device restart behavior | No specific action |
| Return codes | 0 = Success, 1 = Failed, 1618 = Retry, 3010 = Soft reboot |

### Requirements

| Setting | Value |
|---------|-------|
| Operating system architecture | 64-bit, 32-bit |
| Minimum operating system | Windows 10 1809 |
| Disk space required (MB) | 100 |
| Physical memory required (MB) | 512 |
| Minimum number of logical processors | 1 |
| Minimum CPU speed (MHz) | 1000 |

### Detection Rules

| Setting | Value |
|---------|-------|
| Rules format | Use a custom detection script |
| Script file | Detect-VCRedist2017-2022.ps1 |
| Run script as 32-bit process on 64-bit clients | No |
| Enforce script signature check | No |

**Alternative: File-based detection (simpler, but only checks x64)**

| Setting | Value |
|---------|-------|
| Rules format | Manually configure detection rules |
| Rule type | File |
| Path | `C:\Windows\System32` |
| File or folder | `vcruntime140.dll` |
| Detection method | File or folder exists |
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
| 77001 | Winget (App Installer) not found on system |
| 77002 | Failed to install x64 version |
| 77003 | Failed to install x86 version |
| 77004 | Installation completed but DLLs not detected |

## Winget Exit Codes Reference

| Code | Meaning |
|------|---------|
| 0 | Success |
| -1978335189 | Package already installed (treated as success) |
| -1978335212 | Package not found (for uninstall) |

## Files Installed

| Architecture | Primary DLL Location |
|--------------|---------------------|
| x64 | `C:\Windows\System32\vcruntime140.dll` |
| x86 | `C:\Windows\SysWOW64\vcruntime140.dll` |

Additional DLLs installed:
- `vcruntime140_1.dll` (additional runtime)
- `msvcp140.dll` (C++ standard library)
- `msvcp140_1.dll`, `msvcp140_2.dll` (additional C++ components)
- `concrt140.dll` (Concurrency Runtime)
- `vccorlib140.dll` (Windows Runtime C++ support)

## Troubleshooting

### Verify Winget Availability

```powershell
# Check if winget is available
winget --version

# If not found, check App Installer installation
Get-AppxPackage -Name Microsoft.DesktopAppInstaller
```

### Check Installation Status

```powershell
# Verify DLLs exist
Test-Path "C:\Windows\System32\vcruntime140.dll"
Test-Path "C:\Windows\SysWOW64\vcruntime140.dll"

# Check version
(Get-Item "C:\Windows\System32\vcruntime140.dll").VersionInfo.ProductVersion

# List installed via winget
winget list Microsoft.VCRedist
```

### Check Error Logs

```powershell
# View install error log
Get-Content "C:\IntuneAppLogs\VCRedist2017-2022_Install.txt"
```

### Manual Installation Test

```powershell
# Test winget install command directly
winget install -e --id Microsoft.VCRedist.2015+.x64 --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements

winget install -e --id Microsoft.VCRedist.2015+.x86 --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Winget not found | App Installer not installed or outdated | Update App Installer from Microsoft Store or deploy via Intune |
| Network timeout | Cannot reach winget CDN | Check proxy/firewall settings for `*.delivery.mp.microsoft.com` |
| Already installed | Package exists | This is handled gracefully - script exits success |
| Detection fails after install | DLLs in different location | Check if custom VC++ install exists |

## Dependencies

This package requires winget (Windows Package Manager) to be available. On systems without winget:

1. **Windows 10 1903+**: Winget should be pre-installed via App Installer
2. **Older Windows 10**: Deploy App Installer first via Microsoft Store for Business
3. **Alternative**: Consider packaging the MSI installers directly instead of using winget

## Security Considerations

- Winget downloads packages from Microsoft CDN over HTTPS
- Package signatures are verified by winget
- Installation runs in SYSTEM context
- No credentials or sensitive data stored

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-29 | Initial package using winget |

## References

- [Latest Supported Visual C++ Redistributable Downloads](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
- [Windows Package Manager Documentation](https://learn.microsoft.com/en-us/windows/package-manager/)
- [Winget CLI Reference](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
