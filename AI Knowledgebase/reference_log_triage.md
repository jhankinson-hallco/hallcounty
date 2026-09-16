---
name: Intune Log Triage — Which Log Tells You What, In What Order
description: Triage sequence for Win32 app deployment failures; what each IME log file contains and what to search for
type: reference
---

# Intune Log Triage

## Log File Locations

All IME logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`

| Log File | What It Covers |
|---|---|
| `AppWorkload.log` | Win32 app workflow — detection, download, extraction, process launch, exit codes |
| `AppActionProcessor.log` | App applicability, dependency evaluation, which apps are blocked/skipped and why |
| `IntuneManagementExtension.log` | Policy check-in, download jobs, overall IME service flow |
| `AgentExecutor.log` | Platform PowerShell scripts execution |
| `HealthScripts.log` | Remediations, custom compliance, health script workloads |

Script-authored logs also live in
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`:

- Software Win32 app logs: `APP_<AppName>_Install.txt` and
  `APP_<AppName>_Uninstall.txt`
- System script logs: `SCRIPT_<ScriptName>_Install.txt` and
  `SCRIPT_<ScriptName>_Uninstall.txt`

Legacy fallback log folders for older packages:
`C:\IntuneAppLogs\` and `C:\IntuneScriptLogs\`.

---

## Triage Order

**Start with script-authored logs in
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`** — if the script ran
and logged an error, this gives you the exact failure message and line number
directly. Skip to the root cause immediately.

If the expected `APP_*` or `SCRIPT_*` log is missing, also check legacy
`C:\IntuneAppLogs\` and `C:\IntuneScriptLogs\` for older packages. If no
script-authored log exists anywhere, the script may not have executed. Then:

**1. `AppWorkload.log`** — determines whether the install process ran and what it returned

Search for: the app GUID, `lpExitCode`, `SetCurrentDirectory`, `Launch Win32AppInstaller`, `Installation is done`

Key entries to look for:

```
[Win32App] SetCurrentDirectory: C:\WINDOWS\IMECache\<GUID>_<version>
[Win32App] Launch Win32AppInstaller in machine session
[Win32App] process id = <PID>
[Win32App] lastWin32Error 0 after CreateProcess       ← process was created
[Win32App] lastHResult -2147024896 after CreateProcess ← HRESULT noise, normal
[Win32App] Installation is done, collecting result
[Win32App] lpExitCode <N>
[Win32App] hResultFromWin32 <N>
```

If `SetCurrentDirectory` appears but `Installation is done` never appears → process may have hung or been killed.
If `process id` appears and `lpExitCode` appears ~1-2 seconds later with no script log → script never executed (parse error, CLM, or 0x80070000).
If `lpExitCode 1` with a script-authored log entry → script ran and failed;
read the log.

**2. `AppActionProcessor.log`** — determines why apps were blocked without running

Search for: `failed processing`, `blocking`, `dependency`, `Marking app`

Key entry:
```
Marking app with id: <GUID> as executed to prevent execution attempts in this processing cycle 
since child dependency app with id: <DEP-GUID> has failed processing.
```

This means `<DEP-GUID>` is the root failure — everything else is cascade. Fix the dependency, not the dependent apps.

**3. `IntuneManagementExtension.log`** — for download/content problems

Search for: `Download`, `Unzip`, `job`, `Error`, `GRS`

```
GRS expired = True   ← app is in retry cooldown; won't run again until GRS clears
```

---

## Diagnostic Signatures

### Script never ran (no log file created, fast exit)

- No expected `APP_*` or `SCRIPT_*` log under IME Logs, and no legacy
  `C:\IntuneAppLogs\` or `C:\IntuneScriptLogs\` log
- `lpExitCode 1` in `AppWorkload.log` with 1-2 second process duration
- No `SetCurrentDirectory` visible in the log run

**Candidates in priority order:**
1. Parse error (P21) — run `Parser::ParseFile()` on the source script
2. Old package content in IMECache — was the `.intunewin` rebuilt before the last upload?
3. 32-bit PS host (P1) — is `SysNative` in the portal install command?
4. CLM blocking (P18) — `$PSLanguageMode` returns `ConstrainedLanguage`?

### Script ran but failed mid-execution

- Script-authored IME Logs file, or legacy log file, exists with content
- `lpExitCode 1` with a timestamp that matches the log entry timestamp
- Log contains the exception message and line number

Read the log entry. The line number and exception type are the root cause. Common:
- `ParameterBindingException` → P22 (advanced function decoration)
- `ItemNotFoundException` or path errors → wrong working directory or missing package file
- `UnauthorizedAccessException` → SYSTEM context permission issue

### Detection always returns "not detected" after successful install

- Install script exited 0
- Detection script exits 1 on every check-in
- Script-authored logs are clean (no errors)

**Candidates:**
1. Marker file never written by install script (P23)
2. Detection checking a 32-bit-redirected path from a 32-bit detection run — `Run as 32-bit: No` in portal?
3. Detection checking a user-profile path that resolves to the SYSTEM profile, not the user's
4. `Write-Host` used instead of `Write-Output` in Detect.ps1 (P5)

### Multiple apps failed without running (cascade)

- `AppActionProcessor.log` shows `failed processing` for a dependency GUID
- Dependent apps show InstallationState 4 (Error) with no install attempt logged

**Fix:** Find the dependency GUID, diagnose that app exclusively. All other failures are symptoms.

---

## Key AppWorkload.log Patterns

### Confirming which package version actually ran

```
[Win32App] Unzipping file on session 0 from C:\...\Staging\<GUID>_<N>\... to C:\WINDOWS\IMECache\<GUID>_<N>
```

The `_<N>` suffix is the package content version. Compare this to what you expect. A stale `_8` when you uploaded `_11` means the device is running old content.

### Confirming the exact install command that was executed

```
C:\WINDOWS\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\Remove-Office365.ps1
```

This line appears just before `Launch Win32AppInstaller`. Confirm it matches what you entered in the portal exactly.

### GRS (Grace Period) blocking a retry

```
[Win32App][GRSManager] Found GRS value: 04/14/2026 19:25:03 at key ...
```

If GRS shows a recent timestamp and `GRS expired = False`, Intune will not retry the app yet. Either wait for GRS to expire or force a sync after clearing GRS state.

---

## Confirming Script Version That Actually Ran

The script-authored log should include the version:

```
[2026-04-15 10:24:19] [v1.5.5] [App] Iteration 1 - C2R removal failed...
```

The `v1.5.5` here is `$script:AppVersion` from the deployed script — not the portal metadata. This is the ground truth for which script version ran on the device. If this doesn't match your current source version, the deployed content is stale and you need to rebuild and re-upload.
