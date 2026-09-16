# RingCentral Win32 App — Intune Configuration (System / Device-Wide)

## Application Information

| Field | Value |
|-------|-------|
| **Name** | RingCentral |
| **Publisher** | RingCentral, Inc. |
| **Developer** | RingCentral, Inc. |
| **App Version** | 26.2.3013.1602 |
| **Information URL** | https://www.ringcentral.com |
| **Privacy URL** | https://www.ringcentral.com/legal/privacy-notice.html |
| **Category** | Business |
| **Owner** | Hall County MIS |
| **Notes** | Unified communications client — voice, video, messaging, meetings. Deployed via one machine-wide MSI in the package source (System context). |

---

## Architecture Note (read before editing)

The `RingCentral System\` folder is the machine-wide / device-context deployment. The sibling `RingCentral User\`
folder holds only the **PDQ Deploy** variant (`Install-RingCentralPDQ-User.ps1`,
`PDQ-Set-RingCentralFirewallRules.ps1`) — a separate, non-Intune tool. It is not part of this
Win32 app package.

This configuration document intentionally lives outside `RingCentral System\` so it is not included
in the `.intunewin` payload when the System folder is packaged.

**ESP-blocking caution:** the firewall step is a required end state (`Install-RingCentral.ps1`
fails the whole app if it doesn't confirm the firewall rule, not just the MSI). Do not mark this
app "blocking" in an Autopilot ESP profile — a slow firewall/WMI provider under concurrent White
Glove installs should fail this one app's status, not stall the whole provisioning experience.

As of 2026-07-07, `Install-RingCentral.ps1`, `Detect.ps1`, and `Uninstall-RingCentral.ps1` were
relocated into this folder from `RingCentral User\` (they were originally misplaced there —
despite the old folder name, their own version history showed they had already been converted to
a System-context, machine-wide `msiexec` deployment; only the folder and file names were stale).
Do not recreate a "User context" variant of these three files without a specific vendor-driven
reason; the current MSI is machine-wide (`ALLUSERS=1`, `APPLICATIONFOLDER` under
`ProgramFiles64Folder\RingCentral`).

**How MSI version bumps actually reach already-deployed devices:** uploading a new
RingCentral MSI under the same Win32 app entry does **not** by itself push anything —
Intune only re-runs the install command when the detection rule reports "not installed" on a
device's next check-in. `Detect.ps1` proves this three ways (AND): the real executable's
embedded `FileVersionInfo` version, the firewall rule, and a plain-text **version marker file**
at `C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt`. The marker is
what actually forces a fleet-wide reinstall when the MSI is swapped: bump
`$script:RequiredMarkerVersion` in both `Install-RingCentral.ps1` and `Detect.ps1` (kept exactly
in sync — see the cross-reference comments in each file) to the new release's version whenever
the RingCentral MSI is replaced, even if the internal `ProductVersion` embedded in the MSI looks
similar. Do this together with updating `$script:RequiredProductVersion`, the MSI product code in
`Uninstall-RingCentral.ps1`, and this document's Version History.

The install script discovers the installer by requiring exactly one `.msi` file directly in
`RingCentral System\`. The MSI filename is not part of detection or install logic. If zero MSI
files or multiple MSI files are present, `Install-RingCentral.ps1` fails fast with a clear
package-source warning; remove extras before packaging.

---

## Description (Company Portal)

```markdown
## RingCentral

**RingCentral** is a cloud communications platform designed for unified business communications. It helps you stay connected by allowing you to make and receive HD voice and video calls, send messages, share files, and collaborate with your team from your desktop.

### Before you install
Please **save and close any open work** before installing. Setup will briefly pause any running RingCentral sessions while it completes.

### Restart behavior
**Restart required:** **Unlikely**
- Most installs complete without a restart. If RingCentral is open when the install runs, it may be closed or disrupted — save any active calls or chats before installation begins.

### What you can do
* **Make and receive calls** using your Hall County phone extension from your desktop
* **Join or start video meetings** with screen sharing and recording
* **Send direct messages and files** to colleagues in team channels
* **Access voicemail and fax** from a single inbox
* **Integrate with Microsoft 365** for calendar and contact sync

### Install time and user impact
- Typical install time: **3–8 minutes**
- If RingCentral is already open, close it before the install runs
- A restart is unlikely but possible depending on the installer version

### SSO integration
**Single Sign-On:** If SSO is enabled for your organization, RingCentral will sign you in using your Hall County account credentials.
* **Account** — Sign in with your Hall County email address; no separate RingCentral password is required
* **Access** — You do not need to create a new account; however, losing access to your Hall County account will also remove access to RingCentral

### Helpful tips
> Tip: For fastest access to calls, right-click the RingCentral icon in your taskbar and pin it so it stays visible.

> Tip: If you regularly use video meetings, go to **Settings → Video** and set your preferred camera and microphone once so you don't reconfigure each time.

> Tip: If you use a headset, go to **Settings → Audio** and select your headset for both microphone and speakers to avoid echo.

> Tip: If calls are not ringing on your desktop, check **Settings → Phone → Incoming Calls** and make sure your desktop is set as a ringing endpoint.

> Tip: If something looks off (missed calls, blank contact list, wrong extension), sign out and back in under **Settings → Sign Out** — this resolves most first-login sync issues.

### Troubleshooting
If the app won't open or something isn't working correctly, try closing and reopening **RingCentral** first. If you still need help, please place a ticket with **MIS Helpdesk** and include:
- The name/serial number of your device
- What you were trying to do
- Any error message shown (or a screenshot)
- The approximate time the issue happened
```

---

## Program Settings

### Install Command
```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Install-RingCentral.ps1
```

### Uninstall Command
```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Uninstall-RingCentral.ps1
```

### Install Behavior
**System**

> System context is required and is the only supported mode for both scripts. `Install-RingCentral.ps1`
> and `Uninstall-RingCentral.ps1` both call `Test-IsAdministrator` (recognizing SID `S-1-5-18` /
> SYSTEM explicitly) and `[Environment]::Is64BitProcess`, exiting with a clear error if not elevated
> or not 64-bit, rather than letting msiexec fail unclearly. The current source MSI is confirmed
> machine-wide from the current MSI Property/Directory tables (`ALLUSERS=1`, `APPLICATIONFOLDER`
> under `ProgramFiles64Folder\RingCentral`) and requires admin privileges — SYSTEM satisfies this.

### Assignment — Required for White Glove / Autopilot

> **This app must be assigned to a Device group as Required**, not a User group and not "Available."
> White Glove technician phase runs in SYSTEM context before any user signs in and only installs
> Required apps assigned to the device (or device's group) — not user-targeted or "Available"
> Company Portal apps. This script has no dependency on a logged-on user, a user profile path, or
> any network/domain resource beyond the local `msiexec.exe` — it is safe to run during the
> technician phase pre-login.

### Device Restart Behavior
**Determine behavior based on return codes**
- Code 0 / 1707 = success, no restart
- Code 3010 = success, soft reboot required
- Code 1641 = success, installer initiated reboot

### Additional Return Codes

| Return Code | Type | Description |
|-------------|------|-------------|
| 1707 | Success | MSI-layer alternate success code |
| 3010 | Soft reboot | Success, reboot required |
| 1641 | Hard reboot | Success, installer initiated reboot |
| 1605 | Success | Product not installed (idempotent re-run) |
| 1614 | Success | Product uninstalled (idempotent re-run) |
| 1618 | Retry | Another installation is in progress |

### Installation Time Required
**10 minutes**

---

## Detection Rule

### Option A — Custom Detection Script (Recommended)

| Setting | Value |
|---------|-------|
| **Script file** | `Detect.ps1` |
| **Run script as 32-bit process on 64-bit clients** | No |
| **Enforce script signature check and run script silently** | No |

`Detect.ps1` checks for all required end-state items: `C:\Program Files\RingCentral\RingCentral.exe`,
RingCentral product/file version `26.2.3013.1602` or newer, the machine-wide firewall rule named
`Hall County RingCentral - Machine`, and a version marker file at
`C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt` containing exactly
`26.2.3013.1602`. Use this detection method when the firewall exception is part of the required
deployment result and/or you rely on the version marker to drive fleet-wide upgrades.

### Option B — MSI Product Code (App-Only Fallback)

| Setting | Value |
|---------|-------|
| **Rule type** | MSI |
| **MSI product code** | `{ED2A3952-3297-49CA-95FA-31AB3078C41C}` |
| **MSI product version check** | No |

Product code confirmed from the current source MSI Property table on 2026-07-07. MSI
detection proves the app install only; it does not prove the firewall rule exists.

---

## Requirements

### Operating System
- Windows 10 1607 (Anniversary Update) and later
- Windows 11 — supported
- 64-bit architecture

### Minimum Hardware

| Requirement | Value |
|-------------|-------|
| Disk Space | 500 MB free |
| RAM | 2 GB minimum, 4 GB recommended |
| CPU | Dual-core, 2.0 GHz or faster |

---

## Files in Package

| File | Purpose |
|------|---------|
| Exactly one `.msi` installer file | RingCentral installer (machine-wide MSI, installs to `C:\Program Files\RingCentral\`). Current source file is `RingCentral-x64.msi`; the filename is not hardcoded, but the source folder must contain only one MSI. |
| `Install-RingCentral.ps1` | Install script (v4.5.0) — elevation/64-bit checks, discovers exactly one package MSI, calls msiexec /i as SYSTEM when the required version is absent, verifies app install/version, requires the firewall helper (180s timeout) to confirm the machine-wide firewall rule, then writes the version marker file |
| `Uninstall-RingCentral.ps1` | Uninstall script (v3.3.0) — elevation/64-bit checks, calls msiexec /x with current product code, best-effort removes the firewall rule and the version marker file |
| `Detect.ps1` | Custom detection script (v4.5.0) — checks `C:\Program Files\RingCentral\RingCentral.exe`, version `26.2.3013.1602` or newer, the machine-wide firewall rule, and the version marker file |
| `Set-RingCentralFirewallRules.ps1` | Firewall helper (v4.2.0) — creates one machine-wide inbound allow rule for `RingCentral.exe`; spawned as a child process from `Install-RingCentral.ps1`, also safe to run standalone as SYSTEM |

> **Version marker:** `C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt`
> is a plain-text file containing exactly `26.2.3013.1602` — no extra formatting. `Install-RingCentral.ps1`
> writes it after both the fresh-install path and the already-satisfied fast path (so it stays
> current even when msiexec never runs). `Detect.ps1` requires it verbatim as one of four AND
> conditions. This is the mechanism that forces a fleet-wide reinstall on the next detection cycle
> when the RingCentral MSI is replaced with a newer version and this constant is bumped —
> without it, Intune has no reason to ever re-run install on a device that already passes the
> older detection criteria.
>
> `Install-RingCentral.ps1` spawns `Set-RingCentralFirewallRules.ps1` as a genuinely separate
> `powershell.exe` process (never dot-sourced, never called with `&` in-process). The firewall
> script ends with top-level `exit` statements; dot-sourcing or in-process `&` invocation would
> terminate the calling install script's host process prematurely in Windows PowerShell 5.1.

---

## Packaging

Packaging (`.intunewin` build) is a manual step performed by Jeremy after script work is
validated. Do not run `IntuneWinAppUtil.exe` as part of AI-assisted work.

Before packaging, confirm the source folder (`RingCentral System\`) contains only:
exactly one `.msi` installer file, `Install-RingCentral.ps1`, `Uninstall-RingCentral.ps1`,
`Detect.ps1`, and `Set-RingCentralFirewallRules.ps1`. No `.md` docs, logs, archives, or extra
MSI files should be included in the `.intunewin` payload. Multiple MSI files are treated as a
package-source error by `Install-RingCentral.ps1`.

---

## Log Locations

| Log | Path |
|-----|------|
| Install errors | `C:\IntuneAppLogs\RingCentral_Install.txt` |
| MSI verbose log (every run) | `C:\IntuneAppLogs\RingCentral_MSI.log` |
| Uninstall errors | `C:\IntuneAppLogs\RingCentral_Uninstall.txt` |
| Firewall helper errors | `C:\IntuneAppLogs\RingCentral_Firewall.txt` |
| IME policy/check-in | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` |
| Win32 app workflow | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log` |
| Detection/applicability | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppActionProcessor.log` |

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Install exits 1 with a "Permissions" category and elevation message | App is assigned User context or "Available" instead of Device-targeted Required/System — fix the assignment, not the script |
| Install fails with 1618 | Another installation is running — wait and retry |
| Install returns 0 but RingCentral not found | Check `RingCentral_MSI.log` for the actual `APPLICATIONFOLDER`; confirm it still matches `$script:DetectionPath` |
| Detection fails after install | Confirm `Detect.ps1` is configured as 64-bit detection, confirm `RingCentral.exe` exists, confirm version `26.2.3013.1602` or newer, check the machine-wide firewall rule, and confirm the version marker file exists with exactly `26.2.3013.1602` |
| Install exits before msiexec with a package-source warning | Confirm `RingCentral System\` contains exactly one `.msi` file. The script is filename-agnostic but intentionally fails when zero or multiple MSI files are present. |
| Uninstall script exits 1605 | This is treated as success (product already absent) — not an error |
| Uninstall exits 1 with a "PERMISSIONS" or "INTUNE" error code | Uninstall Command in the portal is missing the required SysNative 64-bit PowerShell prefix, or Install Behavior is not System — fix the assignment/command, not the script |
| Firewall rule missing after install | Check `C:\IntuneAppLogs\RingCentral_Firewall.txt`; re-run `Set-RingCentralFirewallRules.ps1` manually as SYSTEM — it is idempotent and safe to re-run |
| Version marker missing or wrong after install | Check `C:\IntuneAppLogs\RingCentral_Install.txt`; confirm `$script:RequiredMarkerVersion` matches between `Install-RingCentral.ps1` and `Detect.ps1` |
| Script exits before installer runs | Check `RingCentral_Install.txt` for configuration or elevation errors |

---

## Version History

| Script Version | Date | Change |
|----------------|------|--------|
| 1.0.x | 2026-04-08 / 09 | Initial EXE-based deployment with marker file detection |
| 1.1.0 | 2026-04-28 | Replaced EXE with RingCentral-x64.msi; msiexec call pattern; simplified uninstall |
| 1.2.x | 2026-04-28 | Switched to User context; per-user %APPDATA% detection; removed ALLUSERS=1; multiple rounds of ParameterBindingException fixes -- none resolved |
| 1.3.0 | 2026-04-28 | Eliminated Invoke-InstallerProcess wrapper entirely; inlined System.Diagnostics.Process directly in MAIN; added [CmdletBinding()] to all helper functions |
| 2.0.x | 2026-04-28 | Switched to System context; per-user install via scheduled task running as the logged-on user; WMI/ProfileList user resolution; staged MSI to C:\Windows\Temp; MSI verbose log added |
| 3.0.x | 2026-04-28 | MSI confirmed machine-wide (APPLICATIONFOLDER = C:\Program Files\RingCentral\); eliminated scheduled-task/user-resolution approach entirely; direct msiexec as SYSTEM |
| 4.0.0 (Install), 4.0.0 (Detect), 3.0.0 (Uninstall) | 2026-07-07 | Relocated from `RingCentral User\` into `RingCentral System\` (scripts were already device-context; only the folder/filenames were stale). Renamed `Install-RingCentral-User.ps1` to `Install-RingCentral.ps1`. Added explicit elevation check for fast, clear failure on misconfigured assignment. Discarded the generic `Install-exeTemplate.ps1` copy (incompatible — hard-rejects any non-`.exe` installer; canonical copy remains in `Software\.Generic Template\`). Trimmed `Set-RingCentralFirewallRules.ps1` (now v4.0.0) to a single machine-wide rule, removing unused per-user S-1-5-21 profile enumeration; wired it into `Install-RingCentral.ps1` as a separate child process. Added best-effort firewall rule cleanup to `Uninstall-RingCentral.ps1`. |
| 4.1.0 (Install/Detect/Firewall), 3.1.0 (Uninstall) | 2026-07-07 | Codex audit: verified current MSI metadata offline (`ProductCode={ED2A3952-3297-49CA-95FA-31AB3078C41C}`, `ProductVersion=26.2.3013.1602`, `ALLUSERS=1`, `APPLICATIONFOLDER` under `ProgramFiles64Folder\RingCentral`). Updated uninstall and portal detection product code. Made firewall rule creation part of install success and custom detection, including the already-installed path. Updated portal commands to the required SysNative 64-bit PowerShell format. |
| 4.2.0 (Install/Detect), 4.1.0 (Firewall), 3.1.0 (Uninstall) | 2026-07-07 | Codex remediation: install and detection now require RingCentral version `26.2.3013.1602` or newer, so an older existing executable cannot satisfy Intune detection or bypass the MSI upgrade path. Moved this configuration note outside the package source folder. |
| 4.3.0 (Install/Detect), 4.2.0 (Firewall), 3.1.0 (Uninstall) | 2026-07-07 | Audit follow-up: raised `FirewallTimeoutSeconds` from 60 to 180 (verified against the MSI's real `Upgrade`/`InstallExecuteSequence` tables and the extracted `RingCentral.exe` `FileVersionInfo` in this pass — a required, non-optional firewall step needs headroom for NetSecurity module autoload/CIM query latency under White Glove concurrency). Added cross-reference comments so the duplicated version-check constant/functions in `Install-RingCentral.ps1` and `Detect.ps1` stay in sync (Detect.ps1 cannot dot-source a shared file — Intune custom detection only accepts one self-contained script). Renamed the `$profile` loop variable to `$firewallProfile` in `Detect.ps1`/`Set-RingCentralFirewallRules.ps1` — `$profile` shadows PowerShell's automatic `$PROFILE` variable. Added an ESP-blocking caution to this doc. |
| 4.4.0 (Install/Detect), 4.2.0 (Firewall), 3.2.0 (Uninstall) | 2026-07-08 | Blind audit follow-up: hardened `Test-IsAdministrator` in `Install-RingCentral.ps1` to explicitly recognize SID `S-1-5-18` (SYSTEM), matching the PDQ script's pattern. Added the same `Test-IsAdministrator`/`Is64BitProcess` fail-fast checks to `Uninstall-RingCentral.ps1`, which previously had neither. Added a version marker mechanism at Jeremy's request: `Install-RingCentral.ps1` writes `C:\ProgramData\Microsoft\IntuneManagementExtension\Versions\RingCentral.txt` (initially `26.2.30`) on every successful install path; `Detect.ps1` requires it verbatim as a fourth AND condition; `Uninstall-RingCentral.ps1` best-effort removes it. This is the mechanism that makes a bare MSI-file swap under the same package actually reach already-deployed devices. |
| 4.5.0 (Install/Detect), 4.2.0 (Firewall), 3.3.0 (Uninstall) | 2026-07-08 | Codex remediation: changed the marker value to the full evidence-backed MSI/software version `26.2.3013.1602`, kept `RingCentral.txt` as the marker filename, and replaced hardcoded `RingCentral-x64.msi` lookup with filename-agnostic MSI discovery. `Install-RingCentral.ps1` now requires exactly one `.msi` in the package source and fails with a clear package-source warning when zero or multiple MSI files are present. |
