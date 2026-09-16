---
name: PowerShell Architecture — SysNative, WOW64, 32-bit vs 64-bit
description: Critical rules for ensuring 64-bit PowerShell execution from Intune IME, which is a 32-bit process
type: reference
---

## The Problem: IME Is a 32-Bit Process

The Intune Management Extension (IME) — `IntuneManagementExtension.exe` — runs as a 32-bit process on 64-bit Windows. When IME spawns `powershell.exe` using a plain, unqualified path, WOW64 file system redirection resolves it to:

```
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe   ← 32-bit PowerShell
```

This is NOT what you want for most scripts.

---

## The Fix: SysNative

From a 32-bit process, `%SystemRoot%\SysNative\` is a WOW64 alias that resolves to the real `System32` directory. Using it in the Intune portal install/uninstall command forces 64-bit PowerShell:

```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\YourScript.ps1
```

This is the **required install/uninstall command format** for any Win32 app script that uses:
- AppX / `Get-AppxPackage` / `Remove-AppxPackage`
- DISM or 64-bit COM components
- 64-bit registry paths (`HKLM:\Software` without WOW6432Node)
- `C:\Program Files` (not `Program Files (x86)`)
- 64-bit modules or native System32 binaries

---

## AppX Module: The Hard Crash Case

The AppX PowerShell module is 64-bit only. When loaded into 32-bit PowerShell:
- The **PowerShell host process crashes** before any script logic runs
- `try/catch` does NOT protect against this — the crash is at the process level, not a terminating exception
- Exit code is 1
- Runtime is typically < 1 second (just startup + module load + crash)
- No useful error in STDERR; process just terminates

**Diagnostic signature in AppWorkload.log:**
```
lpExitCode 1
[process duration ~0.85 seconds]
[install command shows: powershell.exe  ← missing SysNative]
```

**Fix: Portal-only change** — update the install command. No repackaging needed unless the script itself must change.

---

## WOW64 File System Redirection

When running in 32-bit context, these path redirections apply:

| Path Written/Read | Actual Path Accessed |
|---|---|
| `C:\Windows\System32\` | `C:\Windows\SysWOW64\` |
| `C:\Program Files\` | `C:\Program Files (x86)\` |
| `HKLM:\Software\` | `HKLM:\Software\WOW6432Node\` |

If you need to write/read from the real 64-bit locations from a 32-bit process, you must use:
- `C:\Windows\SysNative\` (maps to real System32)
- `C:\Program Files\` only works correctly from 64-bit process
- Registry: use `HKLM:\SOFTWARE` from 64-bit process; from 32-bit, paths get silently redirected

---

## How to Verify Which PowerShell Bit-ness Is Running

```powershell
[System.Environment]::Is64BitProcess   # True = 64-bit, False = 32-bit
[System.Environment]::Is64BitOperatingSystem
$env:PROCESSOR_ARCHITECTURE             # AMD64 = 64-bit host, x86 = 32-bit process
```

---

## Detection Scripts: Bit-ness Setting

In the Intune portal, for custom detection scripts:
- **"Run script as 32-bit process on 64-bit clients"** → `No` for any script reading 64-bit registry paths or checking 64-bit install locations
- Default behavior depends on Intune version; explicitly set this to `No` for safety

---

## Standard Install Command Template

```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\ScriptName.ps1
```

Document this in every script's `.NOTES` block under `INTUNE CONFIGURATION`. The script header comment is authoritative — if the portal drifts from it, that is the root cause of failures.

---

## Real Incident: System-RemoveBloatwareAppX White Glove Failure

- Script: `System-RemoveBloatwareAppX.ps1` v1.0.11
- Portal command: `powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\System-RemoveBloatwareAppX.ps1`
- Failure mode: 32-bit PS → AppX module crash → exit 1 → Intune marks app failed → ESP fails White Glove
- Script header at line 58-59 had correct SysNative command; portal was wrong
- Fix: Portal-only install command update; no repackaging
