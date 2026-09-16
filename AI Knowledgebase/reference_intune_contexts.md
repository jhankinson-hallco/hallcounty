---
name: Intune Deployment Contexts — White Glove, Device Groups, User Groups, ESP Phases
description: What is available and what constraints apply in each Intune deployment context
type: reference
---

## Execution Context Summary

| Context | Who/When | Available | Not Available |
|---|---|---|---|
| White Glove / Technician Phase | SYSTEM, no user logged in | HKLM, Default User hive, System32, machine-wide installs | User profiles (%APPDATA%, %LOCALAPPDATA%), domain resources (unreliable), Graph API |
| Device-targeted, post-enrollment | SYSTEM, may be no user | HKLM, machine-wide paths | User-specific paths, interactive UI |
| User-targeted, post-login | Running as logged-on user | User profile, HKCU, user apps | Machine-wide changes without elevation |
| Platform scripts | SYSTEM or User (configured) | Same as above per context | Win32-style detection, dependency control |

---

## White Glove (Autopilot Pre-Provisioning) — Technician Phase

**What it is:** Technician-phase of Autopilot pre-provisioning. Device runs through Device Setup ESP phase with no user ever logged in. Performed before device is handed to end user.

**Context:** SYSTEM, 64-bit PowerShell (if SysNative used), no logged-on user

**What IS available:**
- `HKLM:\` (all machine-wide registry)
- `C:\Users\Default\NTUSER.DAT` (Default User hive — mutable via reg.exe)
- `C:\Windows\System32\` and native OS tools
- Files copied from the Intune package (via `$PSScriptRoot`)
- Local disk writes to stable machine paths
- Machine-wide service/scheduled task creation
- Local user account creation
- IME-rooted runtime folders:
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`,
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Images`,
  `C:\ProgramData\Microsoft\IntuneManagementExtension\AppMarkers`, and
  `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles`

**What is NOT reliably available:**
- Any user profile (`C:\Users\<username>\`) — no user has ever logged in
- `%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%` — expand to SYSTEM's paths, not end-user paths
- Domain controller access (not guaranteed during WG technician flow with hybrid join)
- Microsoft Graph (blocked tenant-wide at Hall County unless explicitly authorized)
- Assigned user information (user not yet linked to device during WG)
- Interactive prompts, UAC dialogs, or any UI

**Design rules:**
- Use `SYSTEM` context (Install behavior: System)
- Use `$PSScriptRoot` for package-relative paths
- Use IME-rooted runtime folders for files that persist after package completes
- Write all config to `HKLM` or Default User hive (never HKCU)
- Script must complete in < ~30 minutes; anything longer risks ESP timeout
- Must exit deterministically (no infinite loops waiting on remote state)
- Must leave a marker or reliable evidence so detection does not re-trigger unnecessarily

---

## Standard Device-Group Deployment

**What it is:** Win32 app or platform script assigned to a device group; runs after device checks in to Intune, possibly before any user logs in.

**Context:** SYSTEM (for Win32 apps with "System" install behavior)

**Differences from White Glove:**
- Domain controller may be available (device already enrolled and on-network)
- May run while a user is actively logged in (no UI interactions, but user activity is concurrent)
- Still runs as SYSTEM; user profile paths still invalid
- Detection runs on every Intune sync; must be idempotent

**Design rules:** Same as White Glove for the most part. Treat it as SYSTEM with no user assumptions.

---

## Standard User-Group Deployment

**What it is:** Win32 app or platform script assigned to a user group; runs in the context of that user after they log in.

**Context:** User's own session

**What IS available:**
- `HKCU:\` for that specific user
- `%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%`
- User's own installed apps
- User profile paths

**What is NOT available:**
- `HKLM` write access (unless elevated, which user-context Win32 apps are not by default)
- Machine-wide configuration
- Other users' profiles
- White Glove — user-targeted apps are not processed during WG technician phase

**When to use:**
- App that requires user identity (per-user license, per-user config file in %APPDATA%)
- App that cannot be installed machine-wide
- NOT for anything that must be ready before first login

---

## ESP Phases

### Device Setup Phase
- Runs during White Glove AND during standard OOBE
- Device-targeted apps and policies enrolled here
- Blocking apps must complete before the phase advances
- Running as SYSTEM, no user logged in

### Account Setup Phase
- Runs after user first logs in during OOBE
- User-targeted apps and policies enrolled here
- Running in user context
- Do NOT put White Glove-required work here

**ESP Blocking:**
- Only apps marked as blocking actually hold the ESP at that phase
- Non-blocking apps install in background and don't prevent ESP from completing
- Every blocking app adds failure risk; minimize blocking app count
- A blocking app that returns non-zero (and is not a recognized success code) fails the entire ESP phase

---

## Code That Must Run Before First User Login

Requirements for "pre-first-login" execution:

1. **Device-targeted** (not user-targeted) — device groups, not user groups
2. **SYSTEM context** — Install behavior: System
3. **No user profile dependencies** — no `%LOCALAPPDATA%`, no `%APPDATA%`, no `HKCU`
4. **Idempotent and fast** — must complete before user starts session; must not block indefinitely
5. **Default User hive for per-user config** — the only safe way to set "new user profile defaults" before any user logs in
6. **HKLM for machine-wide policy** — affects all users present and future

**Pattern for setting per-user defaults before first login:**
- Mount `C:\Users\Default\NTUSER.DAT` via `reg.exe load`
- Write target registry values via `reg.exe add`
- Unload hive via `reg.exe unload`
- This stamps the Default User template so every future profile created on this machine inherits those values
- Does NOT retroactively affect existing profiles (they already have their own NTUSER.DAT)

---

## SYSTEM Context Behavior

Scripts run as SYSTEM have:
- Full `HKLM` read/write
- Full filesystem access (except EFS-encrypted user files)
- NO access to end-user `HKCU` (SYSTEM's own HKCU is `HKU\.DEFAULT`, not the user's)
- `%USERPROFILE%` expands to `C:\Windows\system32\config\systemprofile` (not the user's folder)
- `%LOCALAPPDATA%` expands to a System path, not a user path

Never use user-profile-relative environment variables in SYSTEM-context scripts.

---

## Deployment Phase Recommendation Decision Tree

```
Does it need to be ready before the user's first desktop experience?
  └─ YES → Device-targeted Win32, SYSTEM context, target Device Setup ESP or pre-enrollment
  └─ NO → Continue...

Does it require the logged-on user's identity?
  └─ YES → User-targeted, User context
  └─ NO → Device-targeted, SYSTEM context (safer, runs earlier)

Does it need uninstall / detection / dependency control?
  └─ YES → Win32 app
  └─ NO → Platform script acceptable if lightweight and no retry dependency

Must it succeed during White Glove?
  └─ YES → Must be device-targeted, SYSTEM, no domain/Graph/user-profile dependencies
  └─ NO → Standard device or user deployment
```
