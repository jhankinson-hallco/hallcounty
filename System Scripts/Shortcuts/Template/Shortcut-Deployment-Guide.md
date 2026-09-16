# Shortcut Deployment Guide - Intune Win32 App

This is the canonical Intune guide for shortcut projects under
`System Scripts\Shortcuts`. Use it with the Template install, detect, and
uninstall scripts, then apply the project-specific values shown in each
script's CONFIGURATION block.

## Core Rules

1. Intune packages bundle their own shortcut and icon payload files.
2. Intune scripts do not read from the filestore.
3. The deployed shortcut goes to `C:\Users\Public\Desktop`.
4. The deployed icon goes to
   `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`.
5. Logs go to
   `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<AppName>_<Action>.txt`.
6. Detection accepts the icon at the current IME Images path or at the legacy
   `C:\IntuneDeploymentFiles\Images` path so older deployments remain detected.
7. PDQ counterparts must leave the same on-device footprint so Intune
   detection cannot tell which channel installed the shortcut.

## Required Package Contents

Single-shortcut package:

```text
Install-<Name>Shortcut.ps1
Uninstall-<Name>Shortcut.ps1
Detect.ps1 or Detect-<Name>Shortcut.ps1
<Shortcut>.url or <Shortcut>.lnk
<Icon>.ico
```

Default shortcut pack:

```text
Install-DesktopShortcuts.ps1
Uninstall-DesktopShortcuts.ps1
Detect.ps1
All .url/.lnk files listed in $script:Shortcuts
All .ico files listed in $script:Shortcuts
```

Do not include stale `.intunewin` files, logs, AI notes, or guide files in the
source folder used for packaging. Build from a clean staging folder when needed.

## Intune Program Settings

Use the exact script names from the target project folder.

```text
Install command:
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\<InstallScript>.ps1

Uninstall command:
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\<UninstallScript>.ps1

Install behavior:
System

Device restart behavior:
No specific action
```

Return codes:

```text
0 = Success
1 = Failed
```

Detection rule:

```text
Rules format: Use a custom detection script
Script file: Detect.ps1 or the project-specific detect script
Run script as 32-bit process on 64-bit clients: No
Enforce script signature check: No
```

## Portal Metadata Defaults

```text
Publisher: Hall County MIS
Developer: Hall County MIS
Informational URL: https://www.hallcounty.org/
Privacy URL: https://www.hallcounty.org/
App version: match the install script .NOTES version
```

## Validation Before Packaging

Run these checks after any script edit:

```powershell
$files = Get-ChildItem -LiteralPath '<SourceFolder>' -Filter '*.ps1'
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors) | Out-Null
    if ($errors) { $errors }
}
```

Verify UTF-8 BOM and ASCII-only content for every deployed `.ps1`.

## Runtime Footprint

```text
Shortcut:
C:\Users\Public\Desktop\<Shortcut>.url

Icon:
C:\ProgramData\Microsoft\IntuneManagementExtension\Images\<Icon>.ico

Legacy icon detection only:
C:\IntuneDeploymentFiles\Images\<Icon>.ico

Install log:
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<AppName>_Install.txt

Uninstall log:
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<AppName>_Uninstall.txt
```

Uninstall scripts remove shortcuts only by default. Icon cleanup remains
disabled because multiple packages can share the same icon files.
