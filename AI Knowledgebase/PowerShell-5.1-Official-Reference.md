# PowerShell 5.1 Official Reference

Last updated locally: 2026-04-30

Purpose: persistent local reference for PowerShell audits and script work in this workspace. This is not a copy of Microsoft Learn. It is a curated official-source map plus audit rules that force validation against Windows PowerShell 5.1 and current Microsoft documentation when behavior is version-sensitive.

## Source Of Truth Rules

- For Windows PowerShell 5.1 compatibility, prefer the local Windows PowerShell 5.1 engine over PowerShell 7 when validating syntax, binding, and command availability.
- Use `powershell.exe`, not `pwsh`, for compatibility checks:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable"
```

- Validate parser compatibility with the Windows PowerShell 5.1 parser:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('C:\Path\Script.ps1', [ref]$tokens, [ref]$errors) | Out-Null; $errors"
```

- Validate command syntax directly in Windows PowerShell 5.1:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-Command Some-Command -Syntax"
```

- For provider dynamic parameters, validate with a provider path. Static syntax output can miss dynamic parameters:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "(Get-Command Set-ItemProperty -ArgumentList 'HKLM:\Software').Parameters.Keys | Sort-Object"
```

- When Microsoft Learn and the local target engine disagree, treat the local Windows PowerShell 5.1 result as the runtime truth for that endpoint, then explain the documentation mismatch.
- Use Microsoft Learn pages with `view=powershell-5.1` when available. Some Windows modules such as Appx, DISM, and ScheduledTasks use Windows/Server documentation views instead of the PowerShell 5.1 view; verify locally in those cases.

## Official Microsoft Entry Points

- PowerShell docs usage/version selector:
  https://learn.microsoft.com/powershell/scripting/how-to-use-docs?view=powershell-5.1

- Windows PowerShell 5.1 overview:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_windows_powershell_5.1?view=powershell-5.1

- Microsoft.PowerShell.Core:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/?view=powershell-5.1

- Microsoft.PowerShell.Management:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/?view=powershell-5.1

- Microsoft.PowerShell.Utility:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/?view=powershell-5.1

- Microsoft.PowerShell.Security:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/?view=powershell-5.1

- Microsoft.PowerShell.Diagnostics:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/?view=powershell-5.1

- CimCmdlets:
  https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/?view=powershell-5.1

- Microsoft.WSMan.Management:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.wsman.management/?view=powershell-5.1

- PowerShellGet 2.x:
  https://learn.microsoft.com/en-us/powershell/module/powershellget/?view=powershellget-2.x

- PackageManagement:
  https://learn.microsoft.com/en-us/powershell/module/packagemanagement/?view=powershellget-2.x

- Appx module:
  https://learn.microsoft.com/en-us/powershell/module/appx/

- DISM module:
  https://learn.microsoft.com/en-us/powershell/module/dism/

- ScheduledTasks module:
  https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/

- Defender module:
  https://learn.microsoft.com/en-us/powershell/module/defender/

- Storage module:
  https://learn.microsoft.com/en-us/powershell/module/storage/

- NetTCPIP module:
  https://learn.microsoft.com/en-us/powershell/module/nettcpip/

- Windows Installer error codes:
  https://learn.microsoft.com/en-us/windows/win32/msi/error-codes

- Office Deployment Tool overview:
  https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-office-deployment-tool

- Office Deployment Tool configuration options:
  https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/office-deployment-tool-configuration-options

- OneDrive per-machine installation:
  https://learn.microsoft.com/en-us/sharepoint/per-machine-installation

## Language And Behavior References

- about_Parsing:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-5.1

- about_Operators:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-5.1

- about_Comparison_Operators:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comparison_operators?view=powershell-5.1

- about_Arrays:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_arrays?view=powershell-5.1

- about_Hash_Tables:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_hash_tables?view=powershell-5.1

- about_Functions:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions?view=powershell-5.1

- about_Functions_Advanced:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced?view=powershell-5.1

- about_Parameters:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parameters?view=powershell-5.1

- about_CommonParameters:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-5.1

- about_Automatic_Variables:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-5.1

- about_Preference_Variables:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-5.1

- about_Try_Catch_Finally:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-5.1

- about_Throw:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_throw?view=powershell-5.1

- about_Requires:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1

- about_Scopes:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes?view=powershell-5.1

- about_Execution_Policies:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1

- about_Signing:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_signing?view=powershell-5.1

- Get-Verb:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-verb?view=powershell-5.1

- Approved verbs:
  https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands

## PowerShell 5.1 Audit Checklist

Compatibility:

- Confirm the target is Windows PowerShell 5.1 Desktop Edition unless the user explicitly says otherwise.
- Avoid PowerShell 7-only syntax and parameters, including:
  - null coalescing operators: `??`, `??=`
  - null conditional/member access: `?.`
  - ternary operator: `<condition> ? <true> : <false>`
  - pipeline chain operators: `&&`, `||`
  - `ForEach-Object -Parallel`
  - `ConvertFrom-Json -AsHashtable`
  - `Join-Path -AdditionalChildPath`
  - common parameters that are PowerShell 7 additions, such as `-ProgressAction`
- Do not use `if` as an expression in Windows PowerShell 5.1, such as `exit (if ($x) { 1 } else { 0 })`.
- Verify cmdlet parameters locally before claiming they exist or do not exist, especially on provider cmdlets and Windows modules.

Syntax and binding:

- Parse with `[System.Management.Automation.Language.Parser]` under `powershell.exe`.
- For advanced functions, be cautious with parameter sets under Windows PowerShell 5.1 in Intune Management Extension or SYSTEM context; simple functions can be more reliable for deployment scripts when parameter validation is not needed.
- Avoid aliases in production scripts. Use full cmdlet names.
- Use approved verbs for function names. Verify with `Get-Verb`.

Runtime context:

- Confirm 64-bit vs 32-bit process behavior with `[Environment]::Is64BitProcess`.
- Use `%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe` from 32-bit launchers when a 64-bit host is required.
- Prefer `System32` paths only after verifying the process is 64-bit.
- Expect registry and file-system redirection in 32-bit PowerShell.
- In Intune Win32 apps, assume SYSTEM context unless configured otherwise.

Paths and files:

- Prefer `-LiteralPath` for exact file/registry paths.
- Avoid `Split-Path -LiteralPath -Parent` in known fragile contexts when `[System.IO.Path]::GetDirectoryName()` is sufficient.
- Validate package files before changing device state.
- Use stable machine paths for assets needed after IME extraction cleanup.

Errors and logging:

- Set `$ErrorActionPreference = 'Stop'` for deployment scripts when the failure model is explicit.
- Use `-ErrorAction Stop` on operations whose failure must be caught.
- Convert non-terminating errors to terminating errors where appropriate.
- Log actionable details: operation, path/key/package/product, exit code, exception type/message, line number, and category.
- Avoid noisy success logs unless required; error-only logs are acceptable for Intune packages when detection is strong.

External processes:

- Use `System.Diagnostics.Process` or `Start-Process -Wait -PassThru` with explicit timeout strategy when required.
- Quote arguments deliberately; do not rely on implicit shell parsing.
- Set working directory when installers expect relative files.
- Treat documented reboot-required exit codes explicitly.
- Do not write success markers before reboot-required states are settled.

Detection and idempotency:

- Detection must prove deployment state, not merely script execution, unless the app is intentionally a one-time prerequisite.
- Version-stamped marker files are acceptable for one-time pre-cleanup packages if the script performs a clean final scan before writing the marker.
- Use exact key/value checks for marker versions.
- Treat idempotent native exit codes as success only when documented and when post-checks prove final state.

Registry:

- Use 64-bit PowerShell for HKLM software inventory unless specifically auditing 32-bit registry views.
- Guard missing registry properties with `PSObject.Properties['Name']` under `Set-StrictMode -Version Latest`.
- For provider dynamic parameters, verify with provider-specific command binding.

Appx/provisioning:

- Use `Get-AppxPackage -AllUsers` for installed packages across users.
- Use `Get-AppxProvisionedPackage -Online` for future-user provisioned packages.
- Remove provisioned packages separately from installed packages.
- Use `Remove-AppxPackage -AllUsers` only from elevated context.
- Expect protected packages and access-denied results on newer builds; distinguish non-removable protected components from genuine failures.

MSI:

- Use official Windows Installer exit codes.
- Common cleanup success/idempotency codes:
  - `0`: success
  - `1605`: product not installed
  - `1614`: product uninstalled
  - `3010`: success, reboot required
  - `1641`: success, reboot initiated
- Do not continue broad MSI cleanup after a reboot-required result unless the script is intentionally designed for that risk.

Intune packaging:

- Do not package stale `.intunewin` files inside source folders.
- Rebuild `.intunewin` after source script changes.
- Keep install command, uninstall command, detection script, version marker, and package artifact in sync.
- Prefer custom detection when native rules cannot validate semantic correctness.

## Verification Commands

Check parser:

```powershell
$file = 'C:\Path\Script.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors) | Out-Null
$errors
```

Check command syntax:

```powershell
Get-Command Start-Process -Syntax
Get-Command Remove-AppxPackage -Syntax
Get-Command New-ScheduledTaskSettingsSet -Syntax
```

Check provider dynamic parameters:

```powershell
(Get-Command New-ItemProperty -ArgumentList 'HKLM:\Software').Parameters.Keys | Sort-Object
(Get-Command Set-ItemProperty -ArgumentList 'HKLM:\Software').Parameters.Keys | Sort-Object
```

Check module availability:

```powershell
Get-Module -ListAvailable Appx, Dism, ScheduledTasks, CimCmdlets
```

Check approved verbs:

```powershell
Get-Verb
```

Check 64-bit host:

```powershell
[Environment]::Is64BitProcess
$PSVersionTable.PSEdition
$PSVersionTable.PSVersion
```
