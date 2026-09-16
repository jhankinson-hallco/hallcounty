---
name: PersonalizationCSP — Node Access Types, Pro Edition Restriction, LockScreenImageStatus
description: CRITICAL — LockScreenImageStatus is Get-only (readback); LockScreenImageUrl is the settable node; Pro SKU only supported in Shared PC mode; direct registry writes may bypass CSP access enforcement
type: reference
---
## Status

Confirmed against live Microsoft Learn PersonalizationCSP documentation (April 2026).

---

## CRITICAL — SKU Restriction

> "Personalization CSP is supported in Windows Enterprise and Education SKUs. It works in Windows Professional only when SetEduPolicies in SharedPC CSP is set, or when the device is configured in Shared PC mode with BootToCloudPCEnhanced policy."

**Hall County fleet is Windows 11 Pro (non-Shared PC).** The PersonalizationCSP is officially unsupported on these devices via the MDM CSP API path. Lock screen deployment via Intune's native CSP mechanism may silently fail or not apply.

**However:** Direct registry writes to the `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP` key bypass the CSP API and write directly to the registry store. Whether Windows honors or ignores these values on Pro SKUs without the Shared PC flag is not definitively documented. Field testing required to confirm actual behavior.

---

## Node Access Types (from Microsoft Learn)

| CSP Node | Access | Notes |
|----------|--------|-------|
| `LockScreenImageUrl` | Add, Delete, Get, Replace | **This is the settable URL node** |
| `LockScreenImagePath` | Add, Delete, Get, Replace | Settable; file path to the image |
| `LockScreenImageStatus` | **Get** | Readback only — 1=success, 2=in progress, 3=failed, 4=policy update, 5=not provisioned |
| `DesktopImageUrl` | Add, Delete, Get, Replace | Settable URL for desktop |
| `DesktopImagePath` | Add, Delete, Get, Replace | Settable file path for desktop |
| `DesktopImageStatus` | **Get** | Readback only, same codes as LockScreen |

---

## CRITICAL — LockScreenImageStatus

`LockScreenImageStatus` is **Get-only** per Microsoft documentation. Do not write this value.

**Current Device Branding behavior (v2.0.6+):** `System-Device_Branding.ps1` does NOT write
`LockScreenImageStatus`. It was removed in v2.0.6 after this reference confirmed it is a
Get-only readback node. `Detect.ps1` does not check it either.

Only `LockScreenImagePath` is written by the install script.

---

## Registry Key Path

```
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP
```

Values typically written for lock screen:
- `LockScreenImagePath` (REG_SZ) — full file path to lock screen image
- `LockScreenImageStatus` (REG_DWORD) — readback status (Get-only per CSP docs)
- `LockScreenImageUrl` (REG_SZ) — URL source (if used)

---

## Practical Implication for Hall County

1. If lock screen via this registry path works on Hall County Pro devices → current approach may be fine despite the CSP doc restriction
2. If it silently fails → an alternative mechanism is needed (e.g., Intune Wallpaper/Lock Screen configuration profile, which uses MDM directly)
3. **Field test required**: Apply the branding package to one device and confirm the lock screen actually changes. Check both immediately after install (SYSTEM context) and after a reboot.
4. Intune has a native "Device restrictions > Lock screen" profile that may work on Pro via a different MDM channel — this is worth evaluating as an alternative or parallel mechanism.
