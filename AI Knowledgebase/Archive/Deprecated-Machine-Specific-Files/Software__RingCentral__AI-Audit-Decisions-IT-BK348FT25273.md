# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-22 - Custom Detection Required For Firewall Remediation

- Decision: Use custom Detect.ps1 for v3.2.0+ instead of MSI product-code-only detection.
- Status: Accepted
- Evidence type: proven from code and Intune detection behavior
- Rationale: MSI detection proves only that RingCentral is installed. It does not prove the firewall helper, marker, scheduled task, or firewall rules. It also skips existing MSI installs, preventing remediation.
- Source or local evidence: Software\RingCentral\Detect.ps1 v3.2.0; AI Knowledgebase\reference_intune_detection.md; Install-RingCentral.ps1 v3.1.0 previously exited before firewall work when the EXE already existed.
- Recommended action: Configure Intune Win32 detection to use Detect.ps1 with "Run script as 32-bit process on 64-bit clients" set to No.

### 2026-06-22 - Firewall Helper Is Required For Future User Profiles

- Decision: Install a SYSTEM AtLogOn helper for RingCentral firewall rules.
- Status: Accepted
- Evidence type: proven from deployment context constraints / likely inference for RingCentral bootstrap timing
- Rationale: Device-targeted Intune installs can run before any end-user profile exists. A one-time install script cannot pre-create a per-user firewall rule for a future profile path. A SYSTEM AtLogOn helper can create the rule after the profile exists without requiring user admin rights.
- Source or local evidence: AI Knowledgebase\reference_intune_contexts.md; Software\RingCentral\Set-RingCentralFirewallRules.ps1 v3.2.0; Install-RingCentral.ps1 v3.2.0.
- Recommended action: Keep the helper and scheduled task unless a tenant firewall policy or RingCentral machine-wide executable path eliminates the per-user prompt.

### 2026-06-22 - Firewall Failure Should Fail Install

- Decision: Treat failure to apply required firewall support as install failure.
- Status: Accepted
- Evidence type: recommendation based on requested end state
- Rationale: The package goal is not merely to install the MSI; it is to prevent the Windows Security Alert for non-admin users. Marking install success when firewall setup fails produces false compliance and leaves the user-facing problem unresolved.
- Source or local evidence: Install-RingCentral.ps1 v3.2.0 writes the marker only after helper success; Detect.ps1 v3.2.0 requires that marker and rules.
- Recommended action: Investigate APP_RingCentral_Firewall.txt and APP_RingCentral_Install.txt if the install fails during firewall setup.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### 2026-06-29 - Reject Claude PDQ Join-Path LiteralPath Finding

- Prior finding: "Generated runner Get-RingCentralDetectionPaths should use Join-Path -LiteralPath per P11 / AGENTS.md standard."
- Disagreement: Do not apply this change. Windows PowerShell 5.1 `Join-Path` does not have a `-LiteralPath` parameter. The generated runner is correctly using `Join-Path -Path` for path construction, then `Test-Path -LiteralPath` for filesystem existence checks.
- Evidence type: proven from local Windows PowerShell 5.1 command metadata and generated runner parser validation
- Supporting evidence: `powershell.exe -NoProfile` reports `Join-Path [-Path] <string[]> [-ChildPath] <string> ...` with no `-LiteralPath`; `Software\RingCentral\Install-RingCentralPDQ.ps1` generated runner parses cleanly with the existing `Join-Path -Path $localAppData -ChildPath $subPath`.
- Recommended action: Keep `Join-Path -Path` for construction in the PDQ runner. Continue using `-LiteralPath` only on cmdlets that support it, such as `Test-Path`, `Copy-Item`, and `Remove-Item`.

### 2026-06-22 - Supersede Claude 3.1.0 No-Version-Sync Finding

- Prior finding: "Detect.ps1 has no RequiredScriptVersion gate so no version sync needed there."
- Disagreement: That was only true while detection checked the RingCentral EXE alone. Once firewall remediation is part of the package end state, detection must gate v3.2.0 firewall support so existing MSI installs are remediated.
- Evidence type: proven from code
- Supporting evidence: Software\RingCentral\Detect.ps1 v3.2.0 requires ScriptVersion=3.2.0 in C:\IntuneAppMarkers\RingCentral.tag and validates helper/task/rules.
- Recommended action: Keep Install, Detect, Uninstall, helper, marker, and portal metadata synchronized on future revisions.
