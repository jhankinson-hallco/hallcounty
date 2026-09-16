# M365 Pre-Cleanup PDQ Guide

> **HOLD LIFTED (2026-07-15):** `Remove-Office365-PDQ.ps1` v1.1.2 is re-derived
> from the recovered Intune v1.5.20 source, then synced to v1.5.22, and
> `Uninstall-M365PreCleanup-PDQ.ps1` v1.0.3 is synced with the v1.5.22 reset
> script. Marker parity is now `ScriptVersion=1.5.22` at the IME AppMarkers
> path; logs go to the IME Logs folder; AppX cleanup and AppX-only budget
> shortfalls are fail-forward per v1.5.20 through v1.5.22. History:
> `AI Knowledgebase\Software\Microsoft Office 365\AI-Audit-Handoff.md`.

## Package Description

M365 Pre-Cleanup

Removes existing Microsoft 365 and Office component variants before the managed Hall County Office 365 deployment runs.

What it does:
* Stages setup.exe and Remove-C2R-All.xml from the shared Microsoft Office 365 removal repository
* Removes Click-to-Run Office products using the Office Deployment Tool Remove All configuration
* Removes targeted Microsoft Store/AppX Office, Teams, Outlook, and OneDrive packages
* Removes legacy MSI-based Office, Visio, and Project entries when detected
* Removes standalone machine-wide OneDrive when detected
* Attempts DISM cleanup for protected provisioned AppX packages when required
* Writes C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers\M365PreCleanup.marker with ScriptVersion=1.5.22 after a clean full-pass scan
* Logs script errors and Office Deployment Tool diagnostics to C:\ProgramData\Microsoft\IntuneManagementExtension\Logs (APP_M365PreCleanup_Install.txt)

Important distinction:
* This package prepares a device for Office deployment; it does not install Office
* The PDQ script writes the same marker that the Intune detection script expects
* The PDQ script disables the Autopilot/White Glove process-kill default by setting KillOfficeProcesses to false
* The PDQ script does not store setup.exe or XML payload files in the PDQ folder

Deployment notes:
* Deploy before the Hall County Default Office 365 install package
* Use a 64-bit PowerShell step
* Run as a Deploy User with local administrator rights and read access to the filestore repository
* Use Local System only if the computer account can read the repository share
* Schedule for a maintenance window when possible, because open Office-related processes can block removal

Success codes:
* 0 = Success; cleanup completed and marker was written
* 3010 = Success, reboot required; marker was not written and cleanup should run again after reboot

## Install Step

Script:
Remove-Office365-PDQ.ps1

Success codes:
0, 3010

Payload repository:
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Microsoft Office 365\Microsoft Office 365 Removal

Local stage:
C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\M365PreCleanupPDQ

## Reset Package Description

M365 Pre-Cleanup - Reset Detection

Resets the M365 Pre-Cleanup detection state so the cleanup package can run again.

What it does:
* Removes the marker from C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers and the legacy C:\ProgramData\HallCountyMIS path when present
* Does not reinstall Office
* Does not remove Office
* Always exits successfully so a missing or locked marker does not create an uninstall retry loop

Deployment notes:
* Use only when the M365 Pre-Cleanup marker needs to be cleared
* Filestore access is not required

Success codes:
* 0 = Success; marker removed or already absent

## Reset Step

Script:
Uninstall-M365PreCleanup-PDQ.ps1

Success codes:
0
