# AI-Audit-Handoff.md

## Current State

- Project: RingCentral Desktop Application
- Current version: Install 3.2.0 / Detect 3.2.0 / Uninstall 3.2.0 / Firewall helper 3.2.0
- Deployment type: Intune Win32 App, System context, machine-wide MSI
- Primary install script: Software\RingCentral\Install-RingCentral.ps1
- Firewall helper: Software\RingCentral\Set-RingCentralFirewallRules.ps1
- PDQ firewall-only script: Software\RingCentral\PDQ-Set-RingCentralFirewallRules.ps1
- PDQ active-user install wrapper: Software\RingCentral\Install-RingCentralPDQ.ps1
  v1.0.4 -- stages the signed RingCentral EXE from the Hall County file share,
  then runs a one-shot scheduled task in the active user's interactive session.
- Detection: Software\RingCentral\Detect.ps1 -- checks RingCentral EXE plus v3.2.0 firewall marker, helper file, scheduled task, machine firewall rule, and existing-profile per-user rules
- Uninstall: Software\RingCentral\Uninstall-RingCentral.ps1 -- msiexec /x {47B672BC-4AFF-4EF6-BADE-B59DEC4A8EA0} plus firewall/helper/task/marker cleanup
- Package artifact: RingCentral-x64.msi (machine-wide, APPLICATIONFOLDER = C:\Program Files\RingCentral\)
- Runtime helper location: C:\ProgramData\Microsoft\IntuneManagementExtension\IntuneFiles\RingCentral\Set-RingCentralFirewallRules.ps1
- Runtime scheduled task: Hall County MIS - RingCentral Firewall Rules (SYSTEM, AtLogOn)
- Detection marker: C:\IntuneAppMarkers\RingCentral.tag with ScriptVersion=3.2.0

## Active Risks

- **High - Audit finding 2026-06-23**: `Install-RingCentral.ps1` and
  `Uninstall-RingCentral.ps1` still contain `[CmdletBinding()]` / `[Parameter()]`
  helper functions. Parser validation passes, but this workspace has field-proven
  `ParameterBindingException` failures from decorated helper functions under
  Windows PowerShell 5.1 / IME / SYSTEM context (reference pitfall P22). Convert
  helper functions to simple functions before next packaging, or field-test this
  exact v3.2.0 build under the target Intune runtime before broad deployment.
- Portal detection must use the custom Detect.ps1 for v3.2.0+. MSI product-code detection proves only software presence and will skip existing devices that still need firewall remediation.
- PDQ "logged on user" run behavior does not grant the logged-on user
  pdqdeploy/admin rights. The RingCentral EXE is per-user; running it directly as
  pdqdeploy installs into the pdqdeploy profile. The PDQ install wrapper uses
  pdqdeploy only to stage the installer and register the active-user task.
- If the RingCentral EXE ever truly requires elevation during the per-user
  install, use the RingCentral MSI/machine-wide deployment path instead of
  trying to inject pdqdeploy credentials into another user's HKCU/profile
  context.
- Confirmed by Jeremy 2026-06-23: the Windows Security Alert path is
  `C:\Users\<user>\AppData\Local\Programs\RingCentral\RingCentral.exe`, matching
  the helper/detection per-user firewall path model.
- The SYSTEM AtLogOn helper should cover profiles created after device-targeted install, but timing must be tested on a freshly provisioned device where the first user logs in after install.
- If domain firewall policy disables or overrides local firewall rules, the local New-NetFirewallRule approach may not prevent prompts. That requires policy-level remediation.
- Build the .intunewin from a clean staging folder. Do not include AI Knowledgebase files, markdown notes, existing .intunewin files, logs, or other reference clutter.

## Recent Changes

### 2026-06-22 -- Codex audit and remediation to 3.2.0

- Superseded the 3.1.0 one-shot Add-RingCentralFirewallRules approach.
- Added Set-RingCentralFirewallRules.ps1 helper:
  - Creates managed firewall rules in group "Hall County RingCentral".
  - Adds machine rule for C:\Program Files\RingCentral\RingCentral.exe.
  - Enumerates S-1-5-21-* profiles from HKLM ProfileList and adds per-user rules for AppData\Local\Programs\RingCentral\RingCentral.exe.
  - Removes Claude-era legacy rules matching "RingCentral Allow Inbound *" on a best-effort basis.
- Updated Install-RingCentral.ps1:
  - Bumped to 3.2.0.
  - Copies helper to ProgramData IntuneFiles.
  - Registers SYSTEM AtLogOn scheduled task for future user profiles.
  - Runs helper immediately after fresh install and on already-installed skip path.
  - Writes C:\IntuneAppMarkers\RingCentral.tag only after firewall support succeeds.
  - Moves script/MSI logs to C:\ProgramData\Microsoft\IntuneManagementExtension\Logs with APP_RingCentral_* names.
- Updated Detect.ps1:
  - Bumped to 3.2.0.
  - Requires RingCentral EXE, v3.2.0 marker, helper file, scheduled task, machine rule, and per-user rules for existing profiles.
- Updated Uninstall-RingCentral.ps1:
  - Bumped to 3.2.0.
  - Removes managed firewall rules, legacy Claude-era rules, scheduled task, helper folder, and marker after successful MSI uninstall or product-already-absent result.
- Updated RingCentral-Intune-Configuration.md:
  - SysNative install/uninstall commands.
  - Custom detection is now recommended for v3.2.0+.
  - Log locations and package file inventory updated.
- Converted all deployed .ps1 files to UTF-8 with BOM and ASCII-only content.

## Required Validation Before Deployment

- DONE 2026-06-22: Windows PowerShell 5.1 parser validation for Install, Detect, Uninstall, and Set-RingCentralFirewallRules -- all PARSE OK.
- DONE 2026-06-22: Encoding validation for all four deployed .ps1 files -- BOM=True and NonASCII=0.
- DONE 2026-06-22: Confirmed ScheduledTasks cmdlets and NetSecurity cmdlets are present locally.
- DONE 2026-06-29: Windows PowerShell 5.1 parser, BOM/ASCII encoding, static
  sweep, approved-verb sweep, ScheduledTasks object construction, generated
  user-runner parser/BOM/ASCII checks, and fake-installer runner E2E passed for
  Install-RingCentralPDQ.ps1 v1.0.3.
- DONE 2026-06-29: Windows PowerShell 5.1 parser (PARSE OK), BOM=True,
  NonASCII=0 confirmed for Install-RingCentralPDQ.ps1 v1.0.4.
- BLOCKED LOCALLY 2026-06-29: Install-RingCentralPDQ.ps1 -ValidateOnly could
  not complete in Codex's non-elevated local session. It failed at the intended
  administrative guard. Run -ValidateOnly from PDQ as pdqdeploy on a logged-in
  test endpoint to validate staging ACLs and runner generation under the real
  deployment account.
- DONE 2026-06-22: Read-only Detect.ps1 run on this workstation exited 1 as expected because v3.2.0 marker/helper/rules are not installed locally.
- Before upload: stage a clean package folder containing RingCentral-x64.msi, Install-RingCentral.ps1, Set-RingCentralFirewallRules.ps1, Uninstall-RingCentral.ps1, and Detect.ps1 only unless another artifact is deliberately required.
- Portal install command: %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File .\Install-RingCentral.ps1
- Portal uninstall command: %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File .\Uninstall-RingCentral.ps1
- Portal detection: use custom Detect.ps1, Run script as 32-bit process on 64-bit clients = No.
- Test an existing RingCentral device: new detection should fail before remediation, install should skip MSI, apply firewall support, write marker, then detection should pass.
- Test a fresh install with an existing user profile: confirm machine rule and per-user rule appear under the "Hall County RingCentral" firewall group.
- Test a device where the first user logs in after install: confirm AtLogOn task creates the new user's per-user firewall rule before RingCentral launch prompts.
- Test uninstall: confirm MSI removal, scheduled task removal, helper folder removal, marker removal, and firewall-rule cleanup.

## Latest Work Log

### 2026-06-29 - Claude - Fresh full-read audit of v1.0.3

- Files reviewed: Install-RingCentralPDQ.ps1 v1.0.3 full read,
  reference_intune_pitfalls.md, reference_scheduledtasks_module.md.
- Files changed:
  - Software\RingCentral\Install-RingCentralPDQ.ps1 (bumped to v1.0.4)
  - AI-Audit-Handoff.md
- Finding accepted and fixed:
  - Low: `Join-InstallerArguments` (lines 231-251 in v1.0.3) was defined in
    the wrapper but never called anywhere in the wrapper's execution path. The
    runner receives its arguments as a PS array literal via
    `ConvertTo-SingleQuotedArrayLiteral`, and the generated runner embeds its own
    `Join-InstallerArguments` copy. The wrapper-level function is a leftover from
    an earlier design. Removed in v1.0.4 to eliminate confusion for future
    maintainers.
- Confirmed clean (no change needed):
  - P22: no `[CmdletBinding()]` or `[Parameter()]` on any helper function. ✓
  - P24: no `Split-Path -LiteralPath`. ✓
  - P25: all `.Count` accesses are on script-scope `@()` literals or Generic List;
    none on pipeline-returned values. ✓
  - P26: no direct registry property access. ✓
  - ScheduledTask parameters: `AllowStartIfOnBatteries` and
    `DontStopIfGoingOnBatteries` match confirmed parameter list. ✓
  - v1.0.3 ACL hardening: `Reset-StageAcl` correctly uses
    `SetAccessRuleProtection($true, $false)` (strips inheritance and inherited
    ACEs) then removes any remaining explicit ACEs, then fresh SYSTEM/Admins/Users
    rules are applied. `Synchronize` bit included on all rights flags. ✓
  - Single captured `$activeUser` value (v1.0.3 Codex fix) used consistently. ✓
  - `InvocationInfo` null guards (v1.0.2 Claude fix) intact and correct. ✓
  - Generated runner: all logic paths, timeout math, do-while detection loop,
    reboot-code early exit, result file write/read, and encoding all correct. ✓
  - `Join-Path -Path` (not `-LiteralPath`) in generated runner: correct for PS 5.1. ✓
  - `UNC path` passes `Test-IsAbsoluteFilePath` via `IsPathRooted`. ✓
- Tests/validation performed:
  - Windows PowerShell 5.1 parser on v1.0.4: PARSE OK.
  - Encoding: BOM=True, NonASCII=0.
  - No `[CmdletBinding()]`, `[Parameter()]`, `Write-Host`, `Invoke-Expression`,
    `Split-Path`, `Join-Path -LiteralPath`, or PS7-only syntax found.

### 2026-06-29 - Codex - Independent full audit of PDQ active-user wrapper

- Files reviewed: Install-RingCentralPDQ.ps1 v1.0.2 full read,
  AI-Audit-Handoff.md, AI-Audit-Decisions.md, shared AGENTS.md, MEMORY.md,
  feedback_ps_auditor_standard.md, reference_exe_template.md,
  reference_scheduledtasks_module.md, reference_intune_pitfalls.md.
- Files changed:
  - Software\RingCentral\Install-RingCentralPDQ.ps1 (bumped to v1.0.3)
  - AI-Audit-Handoff.md
- Findings accepted and fixed:
  - Medium: the staging ACL functions only added or replaced a BUILTIN\Users
    allow rule. They did not disable inheritance, remove stale explicit write
    grants, or reset ACLs on the staged installer and generated user runner.
    This could leave the active user able to modify files that the parent
    process assumes are trusted if the folder already existed with broader
    permissions. v1.0.3 resets controlled ACLs to SYSTEM full control,
    Administrators full control, and Users read/execute for StageRoot, staged
    installer, and runner. Only the Results subfolder grants Users Modify.
  - Low: the active console user was queried repeatedly for context validation,
    task naming, and task principal registration. v1.0.3 captures the active
    user once and passes that value into validation and task-name generation,
    removing a small race window if the console user changes mid-run.
- Findings rejected / not changed:
  - The generated runner still uses `Join-Path -Path` for path construction.
    That remains correct for Windows PowerShell 5.1; `Join-Path -LiteralPath`
    does not exist.
  - The generated runner still uses direct `System.Diagnostics.Process` calls.
    That is acceptable for the expected PDQ FullLanguage runtime and preserves
    reliable timeout/exit-code behavior. If WDAC/CLM is enforced against the
    PDQ or user runner context, this design needs separate target proof or a
    CLM-specific rewrite.
  - Results remains a Users-writable folder by design so the limited active
    user can return status to the elevated PDQ wrapper. StageRoot and the
    executable/script payload are no longer Users-writable.
- Tests/validation performed:
  - Parent script Windows PowerShell 5.1 parser: PARSE OK.
  - Parent script encoding: BOM=True and NonASCII=0.
  - Static sweep: no `[CmdletBinding()]`, `[Parameter()]`, `Write-Host`,
    `Invoke-Expression`, `Get-WmiObject`, `Split-Path`,
    `New-Item -LiteralPath`, `Join-Path -LiteralPath`, or PS7-only syntax.
  - Approved verb sweep: passed.
  - ScheduledTasks object construction: LogonType=Interactive,
    RunLevel=Limited, MultipleInstances=IgnoreNew.
  - Generated user runner parser: PARSE OK; BOM=True; NonASCII=0.
  - Generated user runner E2E harness: used powershell.exe as a fake installer,
    created a harmless test file under `%LOCALAPPDATA%\CodexRingCentralPDQTest`,
    wrote `Status=Success`, `ExitCode=0`, and detected the fake executable.
    Harness artifacts were removed.
  - `Install-RingCentralPDQ.ps1 -ValidateOnly`: still exits 1 at the intended
    local non-elevated admin guard in the Codex session.
  - Full `Copy-InstallerToStage` ACL harness could not complete locally after
    StageRoot was locked down because the Codex session is not elevated. This
    matches the script's target requirement: run from elevated pdqdeploy.
  - PSScriptAnalyzer is not installed locally.
- Remaining risks or human decisions:
  - Run `Install-RingCentralPDQ.ps1 -ValidateOnly` from PDQ as elevated
    pdqdeploy on a logged-in test endpoint. That is still the required proof for
    UNC access, signer/hash validation, staging ACLs, and runner generation
    under the real deployment account.
  - Run a full PDQ deployment while the intended employee user is logged on and
    confirm RingCentral lands under that user's LocalAppData, not pdqdeploy.
  - If the endpoint enforces PowerShell Constrained Language Mode for PDQ or the
    interactive user runner, expect this version to fail until a CLM-specific
    process/result-file implementation is built and tested.

### 2026-06-29 - Claude - Fresh full-read audit of v1.0.1

- Files reviewed: Install-RingCentralPDQ.ps1 (v1.0.1 full re-read, 979 lines),
  AI-Audit-Handoff.md, AI-Audit-Decisions.md, reference_intune_pitfalls.md.
- Files changed:
  - Software\RingCentral\Install-RingCentralPDQ.ps1 (bumped to v1.0.2)
- Finding accepted:
  - Low: `Get-ExceptionSummary` (L158, L162) accessed `$ErrorRecord.InvocationInfo.ScriptLineNumber`
    and `.Line` without first null-guarding `InvocationInfo`. Under StrictMode, if InvocationInfo
    is null (e.g., .NET exception thrown without a script context), this throws PropertyNotFoundException
    from inside `Get-ExceptionSummary`, replaces the original error with a confusing StrictMode
    message in the outer catch, and loses the real failure diagnostic. Fixed with
    `$null -ne $ErrorRecord.InvocationInfo` guards before both property accesses.
- Informational (no change):
  - `Get-ActiveConsoleUserName` is called three times (Assert-DeploymentContext, main block L906,
    Get-TaskName L800), each making a CIM query. No correctness impact.
- Findings from full re-read confirmed as clean:
  - Read-ResultFile: partial file produces empty hashtable -> correct failure path.
  - Wait-ForUserInstallResult exit path: finally block (Remove-InstallTask) executes on exit 1.
  - Invoke-InstallerProcess in runner: direct Process.Start() owns OS handle; ExitCode safe
    after WaitForExit returns $true without handle-touch.
  - Wait-RingCentralDetected: do-while guarantees at least one check; deadline from function entry.
  - Result file write/read race: WriteAllText on 6-line file; partial file safe failure path.
  - $matches access in Read-ResultFile: guarded by match conditional.
  - SkipInstallIfInstalledVersionAtLeast boolean emission: $true/$false correct PS 5.1 syntax.
  - ACL functions: SetAccessRule idempotent on re-runs.
  - Task ExecutionTimeLimit: 1110s covers all runner stages.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser on v1.0.2: PARSE OK.
  - Encoding: BOM=True, NonASCII=0.
  - No new [Parameter()], [CmdletBinding()], Write-Host, Invoke-Expression, or PS7 syntax found.

### 2026-06-29 - Codex - Audit of Claude PDQ installer audit

- Files reviewed: Install-RingCentralPDQ.ps1, AI-Audit-Handoff.md,
  AI-Audit-Decisions.md, shared AGENTS.md, MEMORY.md,
  reference_exe_template.md, reference_scheduledtasks_module.md.
- Files changed:
  - AI-Audit-Handoff.md
  - AI-Audit-Decisions.md
- Findings accepted:
  - M1 is already applied in Install-RingCentralPDQ.ps1 v1.0.1:
    `Exit-Failure` and the logging fallback now use `Write-Warning` instead of
    `[Console]::Error.WriteLine`.
  - L1 is already applied: `Stage-Installer` was renamed to
    `Copy-InstallerToStage`.
  - L2 is already applied: stale MSI-specific installer error descriptions were
    removed from `Get-ExitCodeDescription`; only success/reboot and NSIS abort
    wording remains.
- Findings rejected / corrected:
  - L3 is rejected. Windows PowerShell 5.1 `Join-Path` does not support a
    `-LiteralPath` parameter. Applying Claude's recommendation would create a
    parameter binding failure in the generated user runner. Keep
    `Join-Path -Path` for construction and use `-LiteralPath` on cmdlets that
    actually support it, such as `Test-Path`.
  - Claude's handoff entry below says the script fixes were pending and that
    only AI-Audit-Handoff.md changed. Current code inspection shows
    Install-RingCentralPDQ.ps1 is already v1.0.1 with M1/L1/L2 applied.
- Tests/validation performed:
  - Parent script Windows PowerShell 5.1 parser: PARSE OK.
  - Parent script encoding: BOM=True and NonASCII=0.
  - Static sweep: no `[CmdletBinding()]`, `[Parameter()]`, `Write-Host`,
    `Invoke-Expression`, `Get-WmiObject`, or PS7-only syntax found.
  - Windows PowerShell 5.1 `Get-Command Join-Path -Syntax`: confirmed no
    `-LiteralPath` parameter exists.
  - ScheduledTasks object construction: LogonType=Interactive and
    RunLevel=Limited.
  - Generated user runner: PARSE OK, BOM=True, NonASCII=0.
  - `Install-RingCentralPDQ.ps1 -ValidateOnly`: exited 1 at the intended local
    non-elevated admin guard; warning output was emitted through the PowerShell
    warning stream.
- Remaining risks or human decisions:
  - Run `-ValidateOnly` from PDQ as pdqdeploy on a logged-in test endpoint to
    validate staging ACLs, UNC access, and active-user task execution under the
    real deployment account.
  - Do not apply Claude L3 unless new evidence shows a different target shell
    with a compatible `Join-Path -LiteralPath` parameter.

### 2026-06-29 - Claude - PDQ active-user EXE installer audit

- Files reviewed: Install-RingCentralPDQ.ps1, AI-Audit-Handoff.md,
  AI-Audit-Decisions.md, shared AGENTS.md, reference_exe_template.md,
  reference_intune_pitfalls.md (P22, P24, P27, F1).
- Files changed: AI-Audit-Handoff.md only (findings documented; script fixes
  pending Jeremy decision on whether to apply before deployment).
- Findings accepted:
  - M1: `[Console]::Error.WriteLine($Message)` in `Exit-Failure` (L129) and in
    `Write-ErrorLog` catch (L112). If PDQ runs PowerShell without console handles
    attached, these calls go to TextWriter.Null and errors appear only in the
    local log. Replace with `Write-Warning $Message` (PS stream 3, always
    captured by the PowerShell host regardless of console attachment).
  - L1: `Stage-Installer` function (L542) uses a non-approved verb. AGENTS.md
    requires approved Verb-Noun names. Rename to `Copy-InstallerToStage` or
    `Invoke-InstallerStaging`.
  - L2: `Get-ExitCodeDescription` (L213) includes MSI exit codes (1601-1638)
    for an NSIS installer. NSIS does not emit these codes. Descriptions are
    misleading but not functionally incorrect. Remove or replace with NSIS codes.
  - L3: `Join-Path -Path` in generated runner `Get-RingCentralDetectionPaths`.
    Should use `-LiteralPath` per P11 / AGENTS.md standard.
- Findings rejected / not findings:
  - Missing $process.Handle before WaitForExit: P27 decision applies only to
    Start-Process -PassThru. The runner uses New-Object System.Diagnostics.Process
    and Process.Start() directly; handle is retained by the object, no touch needed.
  - C:\ProgramData\HallCountyMIS paths: legacy by IME standards but intentional
    for PDQ-specific separation. Not an error for a non-Intune-deployed script.
  - +10min scheduled trigger: documented defensive fallback, not a bug.
- Tests/validation performed: Codex 2026-06-29 pre-audit covered parse, BOM/ASCII
  encoding, static sweep (P22/P24/Write-Host/Invoke-Expression/Get-WmiObject/
  Split-Path/New-Item -LiteralPath/PS7 syntax), ScheduledTasks object
  construction, and generated runner parse + BOM/ASCII. All passed.
- Remaining risks or human decisions:
  - Apply M1 fix (Console.Error -> Write-Warning) before deployment to ensure
    PDQ UI shows error messages from all failure paths.
  - Apply L1-L3 if standards compliance is required; none affect runtime behavior.
  - Run -ValidateOnly as pdqdeploy on a logged-in test endpoint (blocked in
    Codex local session due to non-elevated admin guard).

### 2026-06-29 - Codex - PDQ active-user EXE installer wrapper

- Files reviewed: Install-RingCentral.ps1, Install-RingCentralPDQ.ps1,
  PDQ-Set-RingCentralFirewallRules.ps1, Set-RingCentralFirewallRules.ps1,
  RingCentral-Intune-Configuration.md, AI-Audit-Handoff.md,
  AI-Audit-Decisions.md, shared AGENTS.md, MEMORY.md, reference_exe_template.md,
  feedback_ps_auditor_standard.md, feedback_script_encoding.md,
  feedback_version_sync.md, targeted ScheduledTasks/P22/P24 references.
- Files changed:
  - Software\RingCentral\Install-RingCentralPDQ.ps1
  - AI-Audit-Handoff.md
- Findings accepted:
  - The supplied EXE is RingCentral product version 26.1.3015, signed by
    RingCentral, Inc., SHA256
    B6F22FAC8FE4A3597E9A305CE43E7F752525DD13A5E470377DF06853794F6BAC.
  - The EXE contains NSIS markers and supports the case-sensitive /S silent
    switch.
  - Running the EXE as pdqdeploy installs into the pdqdeploy profile, not the
    employee profile.
  - PDQ logged-on-user behavior does not loan pdqdeploy admin rights to the
    employee user.
- Rationale:
  - A per-user installer must run in the target user's token/profile context.
    The wrapper therefore uses pdqdeploy/admin only to validate and stage the
    EXE under ProgramData and to register a one-shot Interactive scheduled task
    for the active user. The task runs the staged EXE as the active user and
    writes a result file for PDQ to read.
  - StageRoot grants Users read/execute only. Only the Results subfolder grants
    Users Modify, preventing tampering with the staged installer or runner.
- Tests/validation performed:
  - Parent script Windows PowerShell 5.1 parser: PARSE OK.
  - Parent script encoding: BOM=True and NonASCII=0.
  - Parent script static sweep: no [CmdletBinding()], [Parameter()], Write-Host,
    Invoke-Expression, Get-WmiObject, Split-Path, New-Item -LiteralPath, or
    PS7-only syntax patterns.
  - ScheduledTasks cmdlets present and object construction succeeded with
    New-ScheduledTaskPrincipal -LogonType Interactive -RunLevel Limited.
  - Generated user-runner script parser: PARSE OK.
  - Generated user-runner encoding: BOM=True and NonASCII=0.
  - Install-RingCentralPDQ.ps1 -ValidateOnly in Codex local session failed at
    the expected non-elevated administrative guard, so real PDQ pdqdeploy
    -ValidateOnly field test remains required.
- Remaining risks or human decisions:
  - Run the PDQ package while the target user is logged on. No active user means
    the wrapper fails by design.
  - If the RingCentral EXE requires admin rights when run as the standard user,
    this EXE path is the wrong deployment primitive; use the RingCentral MSI
    machine-wide deployment instead.
  - Run PDQ-Set-RingCentralFirewallRules.ps1 separately as Local System or
    pdqdeploy/admin if firewall prompt remediation is also required for PDQ
    deployments.

### 2026-06-23 - Codex - PDQ standalone firewall exception script

- Files reviewed: Set-RingCentralFirewallRules.ps1, Detect.ps1, Install-RingCentral.ps1,
  AI-Audit-Handoff.md.
- Files changed:
  - Software\RingCentral\PDQ-Set-RingCentralFirewallRules.ps1
  - AI-Audit-Handoff.md
- Findings accepted:
  - PDQ requested scope is narrower than the Intune package: add RingCentral
    firewall exceptions only, with no MSI install, no Intune marker, no scheduled
    task, and no custom detection.
  - Jeremy noted PDQ likely runs as `pdqdeploy`; the standalone script documents
    that `pdqdeploy` is acceptable if it has local administrator rights on the
    target endpoint.
  - Script targets the confirmed prompt path:
    `C:\Users\<user>\AppData\Local\Programs\RingCentral\RingCentral.exe`, plus
    the machine MSI path `C:\Program Files\RingCentral\RingCentral.exe`.
- Rationale:
  - PDQ can run the script as Local System or an administrative deploy user, so
    the standalone script can directly create local firewall rules and return a
    simple success/failure exit code.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: PARSE OK.
  - Encoding: BOM=True and content NonASCII=0.
  - Static sweep: no `[CmdletBinding()]`, `[Parameter()]`, `Write-Host`,
    `Invoke-Expression`, `Get-WmiObject`, `Split-Path`, PS7-only syntax, or
    `New-Item -LiteralPath`.
- Remaining risks or human decisions:
  - This PDQ script is one-shot for existing profiles. Re-run it after new user
    profiles are created, or use the Intune scheduled-task helper model if future
    profiles must be handled automatically.
  - Default firewall profile is `Domain` only to match the reported prompt.
    Add `Private` to `$script:FirewallProfiles` if PDQ should also cover private
    network classification.

### 2026-06-23 - Codex path correction follow-up

- Files reviewed: Set-RingCentralFirewallRules.ps1, Detect.ps1, Install-RingCentral.ps1,
  RingCentral-Intune-Configuration.md, AI-Audit-Handoff.md.
- Files changed: AI-Audit-Handoff.md only.
- Findings accepted:
  - Jeremy confirmed the Windows Security Alert path includes
    `AppData\Local\Programs\RingCentral\RingCentral.exe`.
  - No deployed script path correction is needed. The helper and detection already
    use `AppData\Local\Programs\RingCentral\RingCentral.exe` for per-user rules.
- Remaining risks or human decisions:
  - Field testing is still needed for scheduled-task timing and domain firewall
    policy behavior, but not for the path spelling ambiguity from the earlier prompt.

### 2026-06-23 - Codex audit follow-up on Claude firewall prompt

- Files reviewed: Install-RingCentral.ps1, Set-RingCentralFirewallRules.ps1,
  Detect.ps1, Uninstall-RingCentral.ps1, RingCentral-Intune-Configuration.md,
  project handoff/decisions, shared AGENTS.md, MEMORY.md, targeted Intune
  detection/scheduled-task/P22 references.
- Files changed: AI-Audit-Handoff.md only.
- Findings accepted:
  - The v3.2.0 firewall model addresses the requested prompt: it creates inbound
    Domain/Private rules for `C:\Program Files\RingCentral\RingCentral.exe` and
    each existing `AppData\Local\Programs\RingCentral\RingCentral.exe` profile
    path, stages a SYSTEM AtLogOn helper for future profiles, remediates
    already-installed devices, and custom detection proves firewall support.
  - Parser, encoding, and required cmdlet availability checks passed locally.
  - High risk remains: install/uninstall helper functions still use
    `[CmdletBinding()]` / `[Parameter()]` despite known IME/SYSTEM P22 failures.
- Findings rejected:
  - No evidence that MSI-only detection is acceptable for the firewall prompt
    requirement; custom detection remains required.
- Rationale:
  - The Windows Security Alert is an inbound firewall prompt, so managed inbound
    allow rules are the right mechanism. The future-user scheduled task is needed
    because device-targeted installs can run before the first user profile exists.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: Install, Detect, Uninstall, and helper all
    PARSE OK.
  - Encoding: all four deployed .ps1 files BOM=True and content NonASCII=0.
  - Local command availability: NetSecurity and ScheduledTasks cmdlets used by
    the scripts are present.
  - Static sweep: no `Write-Host`, `Invoke-Expression`, `Get-WmiObject`,
    `Split-Path`, PS7-only syntax, or `New-Item -LiteralPath` found in deployed
    RingCentral .ps1 files.
- Remaining risks or human decisions:
  - Decide whether to convert install/uninstall helper functions to simple
    functions now, or deploy only after a target-runtime IME/SYSTEM field test.
  - Resolved by Jeremy clarification 2026-06-23: the actual user firewall prompt
    path includes `AppData\Local\Programs\RingCentral\RingCentral.exe`, matching
    the helper path model.

### 2026-06-22 - Codex

- Files reviewed: Install-RingCentral.ps1, Detect.ps1, Uninstall-RingCentral.ps1, RingCentral-Intune-Configuration.md, Claude 3.1.0 handoff/decisions, shared AGENTS.md, MEMORY.md, targeted PowerShell/Intune references.
- Files changed: Install-RingCentral.ps1, Detect.ps1, Uninstall-RingCentral.ps1, Set-RingCentralFirewallRules.ps1, RingCentral-Intune-Configuration.md, AI-Audit-Handoff.md, AI-Audit-Decisions.md.
- Findings accepted: RingCentral needs firewall rules for the machine path and per-user LocalAppData paths; ProfileList is the right source for existing real profiles from SYSTEM context.
- Findings superseded/rejected:
  - Rejected "Detect.ps1 has no RequiredScriptVersion gate so no version sync needed." Detection must now force v3.2.0 remediation and prove firewall support.
  - Rejected "firewall errors are non-fatal." Firewall support is the requested end state, so install fails if the helper cannot apply required rules.
  - Superseded "future users need separate GPO/script." The package now installs a SYSTEM AtLogOn helper for future profiles.
  - Superseded "no firewall rule cleanup on uninstall." Uninstall now removes managed and legacy rule names plus helper artifacts.
- Tests/validation performed:
  - Windows PowerShell 5.1 parser: all four .ps1 files PARSE OK.
  - Encoding: all four .ps1 files BOM=True and NonASCII=0.
  - ScheduledTasks cmdlets present locally.
  - NetSecurity cmdlets present locally.
  - Read-only Detect.ps1 invocation returned exit 1 on non-remediated workstation, as expected.
- Remaining risks: target-device testing still required for actual RingCentral first-launch behavior and any domain firewall policy that may override local rules.
