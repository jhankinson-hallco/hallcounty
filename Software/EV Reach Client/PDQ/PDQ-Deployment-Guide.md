# EV Reach Client - PDQ Deployment Guide

## Purpose

Deploys the EV Reach Client MSI through PDQ while leaving the same on-device
state as the Intune Win32 app deployment.

The Intune production detection script must not be able to tell whether Intune
or PDQ installed EV Reach Client. PDQ must therefore create the same installed
Goverlan agent executable paths that the Intune detection script checks.

## Package Files

Keep these files in the PDQ package folder:

- `Install-EVReachClient-PDQ.ps1`
- `Uninstall-EVReachClient-PDQ.ps1`
- `PDQ-Deployment-Guide.md`

Do not place scripts or markdown on the filestore. The filestore should contain
only deployment payload files.

The copied Intune `Detect.ps1` file is intentionally not used in the PDQ package.
PDQ success or failure is determined by the install/uninstall scripts and their
exit codes.

## Filestore Payload

The PDQ install script reads the MSI from:

```text
\\hallcounty\filestore\mis\CDS\Intune Management Applications\EV Reach Client
```

That folder must contain:

```text
EVReachClient64.msi
```

The script copies the MSI to a local ProgramData staging folder, runs `msiexec`
from that local copy, and then removes the staged MSI.

## Current MSI Identity

```text
ProductName: EasyVista Reach Client v11 (x64)
ProductVersion: 11.0.11
ProductCode: {9B22BBFD-110D-4B2E-AB50-5454C9FA3029}
Manufacturer: EasyVista, Inc.
```

## Install Package

Use one PowerShell step:

```text
Install-EVReachClient-PDQ.ps1
```

Run As:

```text
Deploy User
```

The Deploy User must have local administrator rights on the endpoint and read
access to the EV Reach Client filestore repository.

Success codes:

```text
0, 1707, 3010, 1641
```

## Uninstall Package

Use one PowerShell step:

```text
Uninstall-EVReachClient-PDQ.ps1
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

The PDQ install must leave the same detection evidence as the Intune install:

- `C:\Program Files\Goverlan Inc\GoverlanAgent\GovAgentx64.exe`
- `C:\Program Files\Goverlan Inc\GoverlanAgent\GovAgent.exe`
- `C:\Program Files (x86)\Goverlan Inc\GoverlanAgent\GovAgentx64.exe`
- `C:\Program Files (x86)\Goverlan Inc\GoverlanAgent\GovAgent.exe`

The PDQ uninstall removes the MSI product and verifies those same detection paths
are absent. Reboot-required MSI success codes are allowed because in-use agent
files may remain pending deletion until restart.

## PDQ Package Description - Install

```text
EV Reach Client

Installs the EasyVista EV Reach Client remote support agent.

What it does:
* Copies EVReachClient64.msi from the shared filestore repository to local staging
* Installs EV Reach Client silently as a machine-wide MSI
* Installs the Goverlan agent under C:\Program Files\Goverlan Inc\GoverlanAgent
* Enables secure remote support and endpoint management for Hall County MIS
* Leaves the same on-device footprint as the Intune Win32 app deployment

Important distinction
* This is the PDQ tandem deployment for the EV Reach Client MSI package
* It uses the shared filestore MSI payload instead of a bundled Intune package
* It is designed so Intune detection cannot tell whether PDQ or Intune installed EV Reach Client

Deployment notes
* Run the install step as the PDQ Deploy User
* The deploy user must have local administrator rights and read access to the EV Reach Client filestore repository
* Program PDQ success codes as 0, 1707, 3010, 1641
* Deploy to devices that should receive the EV Reach remote support client
```

## PDQ Package Description - Uninstall

```text
EV Reach Client Uninstall

Uninstalls the EasyVista EV Reach Client remote support agent.

What it does:
* Removes EV Reach Client silently by MSI product code
* Searches current EasyVista and legacy EV/Goverlan uninstall registry entries
* Falls back to the known product code for EV Reach Client 11.0.11
* Verifies the same file-based detection evidence used by Intune is absent
* Treats already-absent clients as success so the package can be safely re-run

Important distinction
* This is the PDQ tandem uninstall for the EV Reach Client MSI package
* It does not require filestore access
* It removes the deployed client, not the PDQ or Intune package source files

Deployment notes
* Run as the PDQ Deploy User or Local System with local administrator rights
* Program PDQ success codes as 0, 1605, 1614, 3010, 1641
* Reboot-required success codes may leave in-use files pending deletion until restart
```
