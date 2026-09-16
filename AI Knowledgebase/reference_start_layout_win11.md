---
name: Windows 11 Start Layout - pinnedList JSON Schema, applyOnce Version Requirements
description: Windows 11 Start JSON has distinct OEM image and managed-policy schemas; Device Branding uses a pragmatic pinnedList shell-folder hybrid that requires target-build proof
type: reference
---
## Status

Confirmed against live Microsoft Learn Start layout deployment documentation (April 2026; rechecked May 2026).

---

## Windows 11 JSON Schema Distinction

Microsoft documents two closely related but different Windows 11 Start JSON paths:

- OEM image customization uses `LayoutModification.json` in `%LOCALAPPDATA%\Microsoft\Windows\Shell`, with OEM members such as `primaryOEMPins`, `secondaryOEMPins`, and `firstRunOEMPins`.
- Managed Start pin policy uses JSON with `pinnedList`; `Export-StartLayout` on Windows 11 produces this style and it is used by `ConfigureStartPins` policy/CSP/GPO flows.

Device Branding currently places a managed/exported `pinnedList` JSON file in the Default User and per-user Shell folders. This is a pragmatic hybrid, not a fully documented Microsoft policy channel. It must be proven on the exact Windows builds Hall County deploys.

```json
{
  "pinnedList": [
    { "desktopAppId": "MSEdge" },
    { "packagedAppId": "Microsoft.WindowsCalculator_8wekyb3d8bbwe!App" },
    { "desktopAppLink": "%ALLUSERSPROFILE%\\Microsoft\\Windows\\Start Menu\\Programs\\MyApp.lnk" }
  ]
}
```

Item types:
- `desktopAppId` — Win32 app by AUMID (e.g., "MSEdge", "Microsoft.Windows.Explorer")
- `packagedAppLink` — path to a `.lnk` shortcut targeting a packaged app
- `desktopAppLink` — path to a `.lnk` shortcut for a Win32 app (supports environment variables)
- `packagedAppId` — UWP/Store app by package family name + app ID

---

## applyOnce — Version Restriction (CRITICAL)

> "`applyOnce` property is supported starting with Windows 11, version 24H2 with KB5062660. It's ignored on earlier versions of Windows 11."

**Behavior on pre-24H2 Windows 11:**
- The `applyOnce` field is silently ignored
- Windows applies the `pinnedList` layout but may or may not treat it as sticky across user customizations
- Without `applyOnce`, the layout may be re-applied on each logon in some configurations, overriding user changes

**Hall County implication:** If the fleet includes Windows 11 builds prior to 24H2, `applyOnce` is a no-op on those devices. The layout still deploys but the "apply once then defer to user" behavior is absent. This may or may not be acceptable depending on whether re-application on logon is desired.

---

## Deployment via Shell Folder (Current Device Branding Approach)

The `Set-UserBranding.ps1` helper copies `LayoutModification.json` to:
```
%LOCALAPPDATA%\Microsoft\Windows\Shell\LayoutModification.json
```
(i.e., `<UserProfile>\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json`)

This is the documented Shell-folder path used by OEM image customization. Because Device Branding uses `pinnedList` rather than the OEM `primaryOEMPins` / `secondaryOEMPins` members, treat this path as best-effort until a target-build first-logon test proves that Windows consumes the file as intended.

---

## Deployment via Intune CSP (Alternative)

Intune "Configure Start Pins" CSP can push the same JSON as a policy. This is an alternative to the file-copy approach and may be more reliable for ongoing enforcement, but:
- Requires a separate Intune profile (Device Restrictions or OMA-URI)
- CSP-pushed layout may be enforced (not just applied once) depending on policy type
- Less flexible for per-user variation

---

## taskbar.pinnedList

Device Branding currently includes a `taskbar` section in `LayoutModification.json`:

```json
{
  "taskbar": {
    "pinnedList": [
      { "desktopAppId": "MSEdge" },
      { "desktopAppLink": "%ALLUSERSPROFILE%\\Microsoft\\Windows\\Start Menu\\Programs\\MyApp.lnk" }
    ]
  }
}
```

Microsoft's public taskbar documentation describes XML-based taskbar configuration through `TaskbarLayoutModification.xml`, policy, provisioning package, GPO, or image-time `LayoutXMLPath`. It does not clearly document `taskbar.pinnedList` inside Start JSON as a supported offline post-OOBE mechanism. Keep this as best-effort only and validate on target builds.

---

## TaskbarLayoutModification.xml (Reference - NOT Active Post-OOBE)

The `LayoutXMLPath` mechanism (pointing to a `.xml` file) is **image-time only** — applies during OOBE/Windows setup. It is not a supported post-OOBE taskbar apply path. If a package keeps a reference XML file on disk, store it under `C:\ProgramData\Microsoft\IntuneManagementExtension\ScriptFiles\<PackageName>\`; do not copy or activate it at runtime unless a supported apply path is proven.
