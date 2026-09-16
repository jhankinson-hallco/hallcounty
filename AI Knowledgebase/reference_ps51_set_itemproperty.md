---
name: Set-ItemProperty -Type — Registry Dynamic Parameter (PS 5.1 Confirmed)
description: Confirms -Type IS a valid dynamic parameter for Set-ItemProperty when targeting the Registry provider in PS 5.1; includes valid RegistryValueKind values
type: reference
---
## Status

Confirmed against live Microsoft Learn documentation (April 2026). The `-Type` parameter exists in PS 5.1 as a Registry-provider dynamic parameter.

## Key Fact

`-Type <RegistryValueKind>` is a **dynamic parameter** on `Set-ItemProperty` provided by the Windows Registry provider. It does NOT appear in the base FileSystem provider signature — auditors who test against `Get-Help Set-ItemProperty` from a filesystem path will not see it, but it is fully valid when the path targets the registry.

## Valid RegistryValueKind Values

| Value | Registry Type |
|-------|---------------|
| `String` | REG_SZ |
| `ExpandString` | REG_EXPAND_SZ |
| `Binary` | REG_BINARY |
| `DWord` | REG_DWORD |
| `MultiString` | REG_MULTI_SZ |
| `Qword` | REG_QWORD |
| `Unknown` | REG_NONE / raw |

## Correct Usage (PS 5.1, HKLM)

```powershell
Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\SomeKey' -Name 'MyValue' -Value 1 -Type DWord -Force -ErrorAction Stop
Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\SomeKey' -Name 'Path'    -Value 'C:\Foo' -Type String -Force -ErrorAction Stop
```

## Audit Implication

Any audit report claiming `-Type` is invalid on `Set-ItemProperty` in PS 5.1 is **incorrect**. Reject that finding. The parameter is dynamic and only appears in registry-path contexts.
