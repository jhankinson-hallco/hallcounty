# Microsoft Outlook - PDQ Guide

## Install Package Description

Microsoft Outlook - New Outlook for Windows

Provisions new Outlook for Windows from the offline Microsoft.OutlookForWindows MSIX package.

What it does:
* Exits successfully without repository access if the required provisioned version is already present
* Stages Microsoft.OutlookForWindows_x64.msix from the shared Microsoft Outlook filestore repository
* Runs Add-AppxProvisionedPackage locally from a temporary endpoint stage folder
* Provisions Microsoft.OutlookForWindows at device scope for all users
* Requires Windows build 19041 or later
* Requires AMD64 Windows because the payload is the x64 MSIX
* Logs script errors to C:\IntuneAppLogs\NewOutlook_Install.txt
* Produces the same provisioned package state expected by the Intune detection script

Important distinction:
* This package installs/provisions new Outlook for Windows
* This is not classic Outlook from Microsoft 365 Apps
* This package does not use the Microsoft Store path or the Outlook Setup.exe bootstrapper
* The PDQ script does not store the MSIX payload in the PDQ folder

Deployment notes:
* Use a 64-bit PowerShell step
* Run as a Deploy User with local administrator rights and read access to the filestore repository
* Use Local System only if the computer account can read the repository share
* Do not target Windows builds older than 19041, including Windows 10 LTSC 1809

Success codes:
* 0 = Success; required provisioned package version is present

## Install Step

Script:
Install-Outlook-PDQ.ps1

Success codes:
0

Payload repository:
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Outlook

Local stage:
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\MicrosoftOutlookPDQ

## Uninstall Package Description

Microsoft Outlook - New Outlook for Windows Uninstall

Removes new Outlook for Windows from device scope and existing users.

What it does:
* Removes the Microsoft.OutlookForWindows provisioned package
* Removes existing per-user Microsoft.OutlookForWindows package instances
* Verifies provisioned and per-user package evidence is gone
* Logs script errors to C:\IntuneAppLogs\NewOutlook_Uninstall.txt
* Preserves tandem behavior with the Intune uninstall counterpart

Important distinction:
* This package removes new Outlook for Windows
* This is not a Microsoft 365 Apps or classic Outlook uninstall
* Filestore access is not required for uninstall

Deployment notes:
* Use a 64-bit PowerShell step
* Run as a Deploy User or Local System with local administrator rights

Success codes:
* 0 = Success; package removed or already absent

## Uninstall Step

Script:
Uninstall-Outlook-PDQ.ps1

Success codes:
0
