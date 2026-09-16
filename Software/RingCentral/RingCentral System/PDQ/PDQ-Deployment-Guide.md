# RingCentral System - PDQ Deployment Guide

## Purpose

Deploys the machine-wide RingCentral MSI through PDQ while leaving the same on-device
state as the Intune Win32 app deployment.

The Intune production detection script must not be able to tell whether Intune or PDQ
installed RingCentral. PDQ must therefore create the same installed executable, firewall
rule, and version marker.

## Package Files

Keep these files in the PDQ package folder:

- `Install-RingCentralSystem-PDQ.ps1`
- `Set-RingCentralFirewallRules-PDQ.ps1`
- `Uninstall-RingCentralSystem-PDQ.ps1`
- `PDQ-Deployment-Guide.md`

Do not place scripts or markdown on the filestore. The filestore should contain only
deployment payload files.

## Filestore Payload

The PDQ install script reads the RingCentral MSI from:

```text
\\hallcounty\filestore\mis\CDS\Intune Management Applications\RingCentral
```

That folder must contain exactly one direct-child `.msi` file for this PDQ package.
Zero or multiple MSI files are treated as repository errors. The script copies the MSI
to a local ProgramData staging folder, runs `msiexec` from that local copy, and then
removes the staged MSI.

## Install Package

Use one PowerShell step:

```text
Install-RingCentralSystem-PDQ.ps1
```

Required companion file:

```text
Set-RingCentralFirewallRules-PDQ.ps1
```

Run As:

```text
Deploy User
```

The Deploy User must have local administrator rights on the endpoint and read access to
the RingCentral filestore repository.

Success codes:

```text
0, 1707, 3010, 1641
```

## Uninstall Package

Use one PowerShell step:

```text
Uninstall-RingCentralSystem-PDQ.ps1
```

Run As:

```text
Deploy User or Local System
```

Success codes:

```text
0, 1605, 1614, 3010, 1641
```

## Tandem Parity

The PDQ install must leave these same artifacts as the Intune install:

- `C:\Program Files\RingCentral\RingCentral.exe` at version `26.2.3013.1602` or newer
- Firewall rule `Hall County RingCentral - Machine`
- Version marker `C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt`
- Marker content exactly `26.2.3013.1602`
- Error logs under `C:\IntuneAppLogs`

The PDQ uninstall best-effort removes the firewall rule and marker, matching the Intune
uninstall behavior.

## PDQ Package Description

```text
RingCentral System

Installs the machine-wide RingCentral desktop application MSI.

What it does:
* Copies the RingCentral MSI from the shared filestore repository to local staging
* Installs RingCentral from the locally staged MSI
* Installs to C:\Program Files\RingCentral
* Creates the machine-wide firewall rule Hall County RingCentral - Machine
* Writes the Intune parity marker to C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt
* Leaves the same on-device footprint as the Intune Win32 app deployment

Important distinction
* This is the PDQ tandem deployment for the RingCentral System MSI package
* It is not the older per-user RingCentral EXE deployment
* It does not create per-user scheduled tasks or install into user profiles
* It is designed so Intune detection cannot tell whether PDQ or Intune installed RingCentral

Deployment notes
* Run the install step as the PDQ Deploy User
* The install script reads the MSI payload from the shared RingCentral repository on the filestore and runs it from a local staged copy
* The firewall helper script must be available beside the install script in the PDQ package
* The uninstall script does not require filestore access
* Deploy to devices that should receive the machine-wide RingCentral installation
```
