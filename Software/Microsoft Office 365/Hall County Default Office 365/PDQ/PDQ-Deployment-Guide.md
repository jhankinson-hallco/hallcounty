# Microsoft Office 365 - Hall County Default PDQ Guide

## Package Description

Microsoft Office 365 - Hall County Default

Installs Microsoft 365 Apps for Enterprise using the Hall County default Office Deployment Tool configuration.

What it does:
* Stages setup.exe and HallCounty-Default-Office-Config.xml from the shared Microsoft Office 365 filestore repository
* Runs Office Deployment Tool locally with the Hall County default configuration
* Installs O365ProPlusRetail on the Monthly Enterprise channel
* Excludes Access, Groove, Lync, Outlook classic, and Publisher as defined in the XML
* Removes legacy MSI Office products through the ODT RemoveMSI setting
* Logs Office Deployment Tool diagnostics and script errors to C:\IntuneAppLogs
* Produces the same installed state expected by the Intune detection script

Important distinction:
* This package installs the Hall County default Microsoft 365 Apps desktop suite
* This is not the M365 Pre-Cleanup/removal package
* The PDQ script does not store setup.exe or XML payload files in the PDQ folder

Deployment notes:
* Deploy after the M365 Pre-Cleanup package has completed successfully
* Use a 64-bit PowerShell step
* Run as a Deploy User with local administrator rights and read access to the filestore repository
* Use Local System only if the computer account can read the repository share

Success codes:
* 0 = Success
* 1707 = Alternate MSI-layer success
* 3010 = Success, reboot required
* 1641 = Success, reboot initiated

## Install Step

Script:
Install-Office365-PDQ.ps1

Success codes:
0, 1707, 3010, 1641

Payload repository:
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365

Local stage:
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\Office365InstallPDQ

## Uninstall Package Description

Microsoft Office 365 - Hall County Default Uninstall

Removes Click-to-Run Office products using the Office Deployment Tool Remove All configuration.

What it does:
* Stages setup.exe and Remove-C2R-All.xml from the shared Microsoft Office 365 filestore repository
* Runs Office Deployment Tool locally with the Remove All configuration
* Removes Click-to-Run Office products from the device
* Logs Office Deployment Tool diagnostics and script errors to C:\IntuneAppLogs

Deployment notes:
* Use a 64-bit PowerShell step
* Run as a Deploy User with local administrator rights and read access to the filestore repository
* Use Local System only if the computer account can read the repository share

Success codes:
* 0 = Success
* 3010 = Success, reboot required
* 1641 = Success, reboot initiated

## Uninstall Step

Script:
Uninstall-Office365-PDQ.ps1

Success codes:
0, 3010, 1641

Payload repository:
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Hall County Default Office 365

Local stage:
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\Office365UninstallPDQ
