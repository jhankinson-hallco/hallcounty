# EV Reach Client Win32 App - Intune Configuration Guide

## Overview

EV Reach Client (formerly Goverlan Reach Client) is a remote support agent that enables IT administrators to remotely access, manage, and support Windows endpoints. This package deploys the 64-bit client agent via MSI.

---

## Package Contents

```
EVReachClient\
├── Install-EVReachClient.ps1
├── Uninstall-EVReachClient.ps1
├── Detect-EVReachClient.ps1
└── EVReachClient64.msi
```

---

## Intune Win32 App Configuration

### App Information

| Field | Value |
|-------|-------|
| **Name** | EV Reach Client |
| **Description** | See End-User Description below |
| **Publisher** | EasyVista |
| **App Version** | (Check your MSI version) |
| **Developer** | EasyVista (formerly Goverlan) |
| **Information URL** | https://www.easyvista.com/products/remote-it-support/ |
| **Privacy URL** | https://www.easyvista.com/privacy-policy |

### Program Settings

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Install-EVReachClient.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File Uninstall-EVReachClient.ps1` |
| **Install behavior** | System |
| **Device restart behavior** | Determine behavior based on return codes |

### Requirements

| Requirement | Value |
|-------------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1607 |
| **Disk space required (MB)** | 100 |
| **Physical memory required (MB)** | 512 |
| **Minimum number of logical processors** | 1 |
| **Minimum CPU speed (MHz)** | 1000 |

### Return Codes

| Return Code | Code Type | Description |
|-------------|-----------|-------------|
| 0 | Success | Installation completed successfully |
| 1707 | Success | Installation completed successfully (alternate) |
| 3010 | Soft reboot | Installation successful, reboot required |
| 1641 | Hard reboot | Installation initiated reboot |
| 1618 | Retry | Another installation in progress |
| 1603 | Failed | Fatal error during installation |
| 1619 | Failed | Installation package could not be opened |
| 1620 | Failed | Installation package is invalid |
| 74001 | Failed | MSI installer not found in package |
| 74002 | Failed | MSI execution failed |
| 74003 | Failed | Installation timeout |
| 74004 | Failed | Installation completed but not detected |

### Detection Rules

| Setting | Value |
|---------|-------|
| **Rules format** | Use a custom detection script |
| **Script file** | `Detect-EVReachClient.ps1` |
| **Run script as 32-bit process on 64-bit clients** | No |
| **Enforce script signature check** | No |

---

## End-User Description (Markdown)

```markdown
## EV Reach Client

**EV Reach Client** is a remote support agent that allows your IT department to securely assist you with computer issues without needing physical access to your device.

### What it does
* Enables **secure remote support** from the IT help desk
* Allows IT to **troubleshoot issues** quickly and efficiently
* Provides **background system management** without interrupting your work
* Ensures **secure, encrypted connections** for all remote sessions

### What you need to know
* The client runs quietly in the background
* You may be prompted before IT connects to your computer
* All remote sessions are logged for security and compliance

> Note: This software is managed by your IT department. If you have questions about remote support policies, please contact your help desk.
```

---

## Creating the .intunewin Package

### Step 1: Prepare Source Folder

Create a folder with all package files:

```
C:\IntunePackages\EVReachClient\
├── Install-EVReachClient.ps1
├── Uninstall-EVReachClient.ps1
├── Detect-EVReachClient.ps1
└── EVReachClient64.msi
```

### Step 2: Create .intunewin Package

```cmd
IntuneWinAppUtil.exe -c "C:\IntunePackages\EVReachClient" -s "EVReachClient64.msi" -o "C:\IntunePackages\Output"
```

### Step 3: Upload to Intune

Upload the resulting `.intunewin` file to Intune as a Win32 app.

---

## File Locations After Installation

| Item | Location |
|------|----------|
| Installation Directory | `C:\Program Files\Goverlan Inc\GoverlanAgent\` |
| Main Executable | `C:\Program Files\Goverlan Inc\GoverlanAgent\GovAgentx64.exe` |
| Error Logs | `C:\IntuneAppLogs\EVReachClient_Install.txt` |
| MSI Log (if error) | `%TEMP%\EVReachClient_MSI_Install.log` |

---

## Network Requirements

EV Reach Client uses the following network configuration:

| Setting | Value |
|---------|-------|
| **Default Port** | TCP 22000 |
| **Protocol** | Encrypted proprietary protocol |
| **Firewall** | Agent auto-configures Windows Firewall |

Ensure your firewall allows TCP port 22000 for EV Reach communication.

---

## Troubleshooting

### Log Locations

| Log Type | Location |
|----------|----------|
| **Installation Errors** | `C:\IntuneAppLogs\EVReachClient_Install.txt` |
| **Uninstall Errors** | `C:\IntuneAppLogs\EVReachClient_Uninstall.txt` |
| **MSI Verbose Log** | `%TEMP%\EVReachClient_MSI_Install.log` |
| **IME Log** | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` |

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Error 74001 | MSI not in package | Verify EVReachClient64.msi is included in source folder |
| Error 1618 | Another install running | Wait and retry, or check for stuck msiexec processes |
| Error 1603 | Generic MSI failure | Check MSI log in %TEMP% for details |
| Detection fails | Wrong architecture | Ensure 64-bit MSI matches 64-bit detection paths |
| Port blocked | Firewall issue | Verify TCP 22000 is allowed |

### Verify Installation

```powershell
# Check if agent is installed
Test-Path "${env:ProgramFiles}\Goverlan Inc\GoverlanAgent\GovAgentx64.exe"

# Check if service is running
Get-Service -Name "GovSrv*" -ErrorAction SilentlyContinue

# Run detection script manually
PowerShell.exe -ExecutionPolicy Bypass -File Detect-EVReachClient.ps1
echo "Exit code: $LASTEXITCODE"
```

---

## Advanced Configuration

### GovAgentInstaller.ini

For advanced configuration during installation, you can include a `GovAgentInstaller.ini` file in the package. This allows you to:

- Configure RMC Client Settings
- Apply special permissions
- Create EV Reach Remote Control Admins local group

Refer to EasyVista documentation for INI file parameters.

### Server Configuration

EV Reach Clients can be configured to connect to an EV Reach Server for centralized policy management. This is typically done via:

- DNS Service Location (SRV) record
- Group Policy Object (GPO)
- EV Reach Server policies

---

## Notes

- The EV Reach Client agent is lightweight (~15 MB) and has minimal system impact
- The agent can run on-demand or as a persistent service
- All remote control sessions are logged for auditing
- The client supports Windows 10/11 (64-bit recommended)
- Previous versions may have been named "Goverlan Client" or "Goverlan Reach Client"
