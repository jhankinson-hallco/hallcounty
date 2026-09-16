# PDQ Shortcut Deployment Guide (Tandem with Intune)

This is the canonical guide for every PDQ shortcut package under
`System Scripts\Shortcuts\<Project>\PDQ`. All project scripts are instances of
the Template pair in this folder.

## Core Rules (apply to the whole scripting ecosystem)

1. **Tandem parity.** PDQ and Intune deployments of the same item must leave the
   device in an identical state. Every detection artifact - files, markers,
   registry values, log locations, versions - must be mirrored so Intune
   detection cannot tell which channel performed the install. When either side
   changes the on-device footprint, update BOTH sides in the same change.
2. **Filestore hygiene.** Only deployment payload FILES (shortcuts, icons,
   installers) live on the filestore. Scripts and markdown stay in the local
   `PDQ` folder. Do not run development or validation commands against the
   filestore; keep share access to the absolute minimum to avoid EDR/Defender
   response on the server.
3. **Channel boundaries.** Only PDQ scripts may reach the filestore. Intune
   scripts rely exclusively on files bundled in their `.intunewin` package.

## Shared Repository

One repository serves every shortcut deployment, standalone or pack:

```text
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Shortcuts   (.url / .lnk files)
\\hallcounty\filestore\mis\CDS\Intune Management Applications\Shortcut Icons\Icons       (.ico files)
```

## On-Device Footprint (identical for PDQ and Intune)

```text
Shortcut:  C:\Users\Public\Desktop\<Shortcut File>
Icon:      C:\ProgramData\Microsoft\IntuneManagementExtension\Images\<Icon File>
Logs:      C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<AppName>_Install.txt (error-only)
           C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SCRIPT_<AppName>_Uninstall.txt (error-only)
```

The deployed shortcut's `IconFile=` line is rewritten to the local IME icon
path. PDQ log entries are tagged `[PDQ]` inside the shared log files.

## PDQ Package Setup

**Install package: ONE script only.**

| Setting | Value |
| --- | --- |
| Step type | PowerShell |
| Script | `Install-<Project>Shortcut-PDQ.ps1` for single shortcuts, or `Install-DesktopShortcuts-PDQ.ps1` for the default pack |
| Run As | Deploy User (needs READ on the repository share; NOT Local System) |
| Success codes | 0 |
| Additional files | None - the script pulls everything from the repository |

**Uninstall: a SEPARATE script** (`Uninstall-<Project>Shortcut-PDQ.ps1`, or
`Uninstall-DesktopShortcuts-PDQ.ps1` for the default pack), used as its own
package or as an added step. It does not need share access. This is the only
case where a second script exists per project.

## Adding a New Shortcut Deployment

1. Stage the `.url`/`.lnk` file in the repository `Shortcuts` folder and the
   `.ico` in the `Icons` folder (single copy operation; nothing else).
2. Copy `Install-Shortcut-PDQ.ps1` and `Uninstall-Shortcut-PDQ.ps1` from this
   Template folder into the new project's `PDQ` folder and rename to the
   project pattern.
3. Set the three CONFIGURATION values (`AppName`, `ShortcutFileName`,
   `IconFileName`) identically in both scripts, matching the Intune project's
   values exactly.
4. Build the Intune counterpart from the parent Template folder (which bundles
   its own copies of the same two payload files in the package).
5. Validate: PS 5.1 parse, UTF-8 BOM, ASCII-only, versions synchronized.

## Version Notes

- PDQ scripts version independently, starting at `1.0.0`. Each PDQ script's
  `.NOTES` records the Intune counterpart version it is tandem with; update
  that reference whenever the Intune side bumps.
- Detection scripts exist only on the Intune side. PDQ needs no detection; the
  Intune detection (Public Desktop shortcut + icon at IME or legacy location)
  passes identically after a PDQ install.
- Current note: the single-shortcut PDQ pairs are v1.0.1 and the default
  shortcut pack PDQ pair is v1.0.2 after PS 5.1 / IME binding-safety
  hardening. Keep each PDQ `.NOTES` counterpart reference aligned to the
  matching Intune script version.
