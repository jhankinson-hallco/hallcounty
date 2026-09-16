---
name: ScheduledTasks Module — Confirmed Parameter Lists (PS 5.1, Windows 11)
description: Confirmed parameter lists for New-ScheduledTaskSettingsSet, New-ScheduledTaskPrincipal, and Register-ScheduledTask from live Microsoft Learn docs; includes battery parameter clarification
type: reference
---
## Status

Confirmed against live Microsoft Learn documentation (April 2026).

---

## New-ScheduledTaskSettingsSet — Battery Parameters

**CRITICAL:** `-DisallowStartIfOnBatteries` and `-StopIfGoingOnBatteries` do **NOT exist** in this cmdlet. These names have no parameter binding match and will cause `ParameterBindingException` at runtime.

The actual battery-related parameters (both switches):

| Parameter | Meaning |
|-----------|---------|
| `-AllowStartIfOnBatteries` | Allow task to start when device is on battery |
| `-DontStopIfGoingOnBatteries` | Do not stop task when device switches to battery |

**For SYSTEM account tasks these parameters are irrelevant** — SYSTEM tasks are not subject to battery constraints unless explicitly configured. Omit them entirely when battery behavior is not a concern.

## New-ScheduledTaskSettingsSet — Full Confirmed Parameter List (PS 5.1)

Key parameters (not exhaustive, focus on commonly used):

- `-AllowStartIfOnBatteries` (switch)
- `-Compatibility <CompatibilityEnum>`
- `-DeleteExpiredTaskAfter <TimeSpan>`
- `-Disable` (switch)
- `-DisallowDemandStart` (switch)
- `-DisallowHardTerminate` (switch)
- `-DontStopIfGoingOnBatteries` (switch)
- `-DontStopOnIdleEnd` (switch)
- `-ExecutionTimeLimit <TimeSpan>`
- `-Hidden` (switch)
- `-IdleDuration <TimeSpan>`
- `-IdleWaitTimeout <TimeSpan>`
- `-MaintenanceDeadline <TimeSpan>`
- `-MaintenanceExclusive` (switch)
- `-MaintenancePeriod <TimeSpan>`
- `-MultipleInstances <MultipleInstancesEnum>` (values: Parallel, Queue, IgnoreNew, StopExisting)
- `-NetworkId <String>`
- `-NetworkName <String>`
- `-Priority <Int32>`
- `-RestartCount <Int32>`
- `-RestartInterval <TimeSpan>`
- `-RunOnlyIfIdle` (switch)
- `-RunOnlyIfNetworkAvailable` (switch)
- `-StartWhenAvailable` (switch)
- `-WakeToRun` (switch)

## New-ScheduledTaskPrincipal — Key Parameters

- `-UserId <String>` — e.g. `'SYSTEM'`, `'NT AUTHORITY\SYSTEM'`
- `-LogonType <LogonTypeEnum>` — values: None, Password, S4U, Interactive, Group, ServiceAccount, InteractiveOrPassword
- `-RunLevel <RunLevelEnum>` — values: Limited, Highest
- `-Id <String>` — optional identifier string
- `-GroupId <String>` — for group-based principals

For SYSTEM service account tasks:
```powershell
New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
```

## Register-ScheduledTask — Key Parameters

- `-TaskName <String>`
- `-Action <CimInstance[]>`
- `-Trigger <CimInstance[]>`
- `-Settings <CimInstance>`
- `-Principal <CimInstance>`
- `-Description <String>`
- `-Force` (switch — overwrites existing task of same name)
- `-ErrorAction`

## Correct SYSTEM Task Registration Pattern (PS 5.1)

```powershell
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "C:\Path\Script.ps1"'
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'My Task' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop
```
