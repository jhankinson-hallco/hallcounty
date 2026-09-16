# Freshservice Discovery Agent - Intune Win32 App Configuration

## Overview

This package installs Freshservice Discovery Agent, which is used for asset discovery and inventory management in the Freshservice IT service management platform.

**Vendor:** Freshworks / Freshdesk  
**Product:** Freshservice Discovery Agent  
**Version:** 3.10.0

## Package Contents

```
root:\
├── Install-FreshServiceAgent.ps1
├── Uninstall-FreshServiceAgent.ps1
├── Detect-FreshServiceAgent.ps1
├── Fresh_Service_Asset_Agent_3.10.0.msi
└── FreshServiceAgent-Intune-Configuration.md
```

## Organization-Specific Configuration

This package is pre-configured with your registration token:

| Setting | Value |
|---------|-------|
| Portal URL | discovery-us.freshservice.com |
| Account Domain | hallmis.freshservice.com |
| Account ID | 216821 |

To change the registration token, edit `Install-FreshServiceAgent.ps1` and modify:

```powershell
$RegistrationToken = "your-new-token-here"
```

## IntuneWinAppUtil Packaging

```powershell
# Package the folder
IntuneWinAppUtil.exe -c "C:\Path\To\FreshServiceAgent" -s "Install-FreshServiceAgent.ps1" -o "C:\Output"
```

## Intune Configuration

### App Information

| Setting | Value |
|---------|-------|
| Name | Freshservice Discovery Agent |
| Description | Freshservice Discovery Agent for asset discovery and inventory management. Automatically discovers and reports hardware and software assets to Freshservice. |
| Publisher | Freshworks |
| App Version | 3.10.0 |
| Category | IT & Management Tools |
| Information URL | https://www.freshservice.com/ |
| Developer | Freshdesk |
| Owner | IT Department |
| Notes | Configured for hallmis.freshservice.com |

### Program

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-FreshServiceAgent.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-FreshServiceAgent.ps1` |
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

**Additional Requirement:** .NET Framework 4.5 or later

### Detection Rules

| Setting | Value |
|---------|-------|
| Rules format | Use a custom detection script |
| Script file | Detect-FreshServiceAgent.ps1 |
| Run script as 32-bit process on 64-bit clients | No |
| Enforce script signature check | No |

**Alternative: File-based detection**

| Setting | Value |
|---------|-------|
| Rules format | Manually configure detection rules |
| Rule type | File |
| Path | `C:\Program Files (x86)\Freshdesk\Freshservice Discovery Agent\bin` |
| File or folder | `FSAgentService.exe` |
| Detection method | File or folder exists |
| Associated with a 32-bit app on 64-bit clients | Yes |

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
| 80001 | MSI installer not found in package |
| 80002 | MSI installation failed |
| 80003 | MSI installation timed out |
| 80004 | Installation completed but agent not detected |

### Common MSI Exit Codes

| Code | Description |
|------|-------------|
| 1603 | Fatal error during installation |
| 1619 | Installation package could not be opened |
| 1625 | Installation prohibited by system policy |
| 1925 | Insufficient privileges (requires admin) |

## MSI Command Line Reference

The install script executes:

```cmd
msiexec.exe /i "Fresh_Service_Asset_Agent_3.10.0.msi" REGISTRATIONTOKEN="<token>" ALLUSERS=1 /qn /norestart /L*v "%TEMP%\FreshServiceAgent_MSI_Install.log"
```

## Installation Location

The agent installs to:
```
C:\Program Files (x86)\Freshdesk\Freshservice Discovery Agent\
```

Key files:
- `bin\FSAgentService.exe` - Main service executable
- `bin\AgentInstaller.dll` - Installation helper
- `conf\` - Configuration files

## Service Information

| Property | Value |
|----------|-------|
| Service Name | FSAgentService |
| Display Name | Freshservice Discovery Agent |
| Startup Type | Automatic |

## Troubleshooting

### Check Installation Status

```powershell
# Check for agent executable
Test-Path "${env:ProgramFiles(x86)}\Freshdesk\Freshservice Discovery Agent\bin\FSAgentService.exe"

# Check service status
Get-Service -Name "FSAgentService" -ErrorAction SilentlyContinue

# Check registry
Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName -like "*Freshservice*" } | 
    Select-Object DisplayName, DisplayVersion, UninstallString

# Run detection script manually
powershell.exe -ExecutionPolicy Bypass -File Detect-FreshServiceAgent.ps1
echo "Exit code: $LASTEXITCODE"
```

### Check Error Logs

```powershell
# View install error log
Get-Content "C:\IntuneAppLogs\FreshServiceAgent_Install.txt"

# View MSI verbose log
Get-Content "$env:TEMP\FreshServiceAgent_MSI_Install.log" -Tail 100
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Error 1925 | Not running as admin | Intune runs as SYSTEM, so this only happens in manual testing. Run as Administrator. |
| Error 1603 | Generic failure | Check MSI log for specific error. Often .NET Framework or permissions issue. |
| Detection failed (80004) | Agent service not started | Check if service exists and is running |
| Timeout (80003) | Slow installation | Increase `$InstallTimeoutSeconds` value |

### Verify Registration

After installation, verify the agent is registered with your Freshservice instance by checking the Freshservice admin console under Discovery > Agents.

## Network Requirements

The agent requires network connectivity to:
- `discovery-us.freshservice.com` (Discovery portal)
- `hallmis.freshservice.com` (Your Freshservice instance)

Ensure firewall rules allow outbound HTTPS (443) connections.

## Dependencies

- .NET Framework 4.5 or later (pre-installed on Windows 10/11)
- Windows Installer service

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.10.0 | 2026-02-17 | Initial Intune package |

## Product Code Reference

| Property | Value |
|----------|-------|
| Product Code | {8BE075F9-36C7-4145-8BC0-35D420223576} |
| Upgrade Code | {6B686B63-A11D-42DE-9678-01FE705125C7} |
