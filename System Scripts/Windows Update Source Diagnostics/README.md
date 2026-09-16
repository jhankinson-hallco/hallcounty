# Windows Update Source Diagnostics

This project contains a read-only diagnostic collector for determining why a
domain-joined, Intune-enrolled Windows device uses WSUS, Windows Update, or
Microsoft Update.

## Run order

Run the collector twice on `TA-PF47WVTR` so the staging state can be compared
with the final departmental state.

### Capture 1 - staging baseline

After imaging/OOBE and the rename are complete, leave the AD computer object in:

```text
CN=Computers,DC=hallcounty,DC=org
```

Run the collector before:

- `gpupdate`
- an Intune manual sync
- clicking **Check for updates**
- moving the AD computer object
- changing any GPO or Intune update setting

Preserve the first timestamped ZIP.

### Capture 2 - final Tax Assessors state

Move the computer object to:

```text
OU=Computers,OU=Tax Assessors,OU=Hall County Departments,DC=hallcounty,DC=org
```

Then run:

```powershell
gpupdate /target:computer /force
```

Restart the computer if requested, sign back in, and run the collector again.
Do not manually initiate an Intune sync or Windows Update scan between the two
captures. Preserve the second timestamped ZIP.

Open an elevated 64-bit Windows PowerShell 5.1 session in this folder and run:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Collect-WindowsUpdateSourceDiagnostics.ps1
```

The default output location is:

```text
C:\WindowsUpdateSourceDiagnostics
```

The collector creates a timestamped folder and ZIP archive on each run. Return
both complete ZIPs for comparison. Start local review with:

```text
00-README-FIRST.txt
00-Source-Diagnosis.txt
00-Source-Decision-Matrix.csv
00-Collection-Status.csv
```

The ZIP can contain device identifiers, user UPNs, tenant identifiers, domain
and OU names, network configuration, event logs, and policy details. Handle it
as internal administrative diagnostic data.

## Optional switches

Skip the MDM diagnostics CAB:

```powershell
.\Collect-WindowsUpdateSourceDiagnostics.ps1 -SkipMdmDiagnostics
```

Skip Windows Update ETL conversion:

```powershell
.\Collect-WindowsUpdateSourceDiagnostics.ps1 -SkipWindowsUpdateLog
```

Use a different output parent directory:

```powershell
.\Collect-WindowsUpdateSourceDiagnostics.ps1 -OutputRoot 'D:\Diagnostics'
```

The script deliberately does not refresh Group Policy, initiate an update scan,
install updates, change Update Agent service registration, or modify policy.
