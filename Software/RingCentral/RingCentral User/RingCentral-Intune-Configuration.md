# RingCentral — RingCentral User Folder (PDQ Deploy, Not Intune)

## Scope Of This Folder

This folder does **not** contain an Intune Win32 app package. It contains the **PDQ Deploy**
per-user installation path for RingCentral, which is a separate deployment tool from Intune.

| File | Purpose |
|------|---------|
| `Install-RingCentralPDQ-User.ps1` | PDQ PowerShell script. Runs under the `pdqdeploy` admin account, stages the per-user NSIS EXE installer, and creates a one-shot scheduled task in the active user's interactive logon session so the EXE installs into that user's profile (not the `pdqdeploy` profile). |
| `PDQ-Set-RingCentralFirewallRules.ps1` | PDQ companion firewall helper for the per-user install path. |
| `RingCentral-x64.msi` | Older MSI copy (2026-04-28), kept here only as a reference/fallback for the PDQ path. Not used by any Intune app. |
| `RingCentral Icon.png` | Icon asset. |

For the rationale behind the PDQ scheduled-task-at-logon design (rather than running the EXE
directly as `pdqdeploy`), see the `.DESCRIPTION` block in `Install-RingCentralPDQ-User.ps1`.

---

## Where The Intune Deployment Actually Lives

**The Intune Win32 app for RingCentral is machine-wide (System context) and lives in the sibling
folder:**

```text
..\RingCentral System\
```

That folder contains `Install-RingCentral.ps1`, `Uninstall-RingCentral.ps1`, `Detect.ps1`,
`Set-RingCentralFirewallRules.ps1`, and `RingCentral-x64.msi`. The authoritative Intune
configuration note lives one level up at `..\RingCentral-System-Intune-Configuration.md` so it is
not included in the package source folder.

### History

As of 2026-07-07, `Install-RingCentral-User.ps1`, `Detect.ps1`, and `Uninstall-RingCentral.ps1`
used to live in this folder. Despite the folder name and the `-User` suffix, those scripts had
already been converted (through their own version history) to a System-context, machine-wide
`msiexec` deployment — the MSI itself is confirmed machine-wide only
(`APPLICATIONFOLDER = C:\Program Files\RingCentral\`), and the scripts had no per-user or
logged-on-user dependency left in them. They were relocated to `RingCentral System\` and renamed
to remove the misleading `-User` suffix. If you are looking for that history, it is preserved in
the version tables of `..\RingCentral-System-Intune-Configuration.md`.

Do not recreate `Install-RingCentral.ps1` / `Detect.ps1` / `Uninstall-RingCentral.ps1` in this
folder — the true per-user deployment path for RingCentral is the PDQ mechanism above, not an
Intune user-context Win32 app.
