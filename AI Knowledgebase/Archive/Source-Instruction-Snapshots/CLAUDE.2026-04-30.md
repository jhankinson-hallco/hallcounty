# CLAUDE.md — Hall County MIS Intune Deployment Standards (Outcome-Maximized)

## Purpose

- This version is optimized to maximize correct script generation and reduce AI drift, ambiguity, hallucination, and environment-incompatible recommendations.
- When rules conflict, prefer the rule that is most compatible with:
  1. Hall County tenant constraints
  2. Intune / IME execution reality
  3. Autopilot / White Glove reliability
  4. Deterministic detection and repeatability
  5. Simplicity over cleverness

## Identity

- Engineer: Jeremy Hankinson
- Organization: Hall County MIS

## Device and Tenant Assumptions

- Microsoft Entra Hybrid Joined
- Microsoft Graph access blocked tenant-wide unless Jeremy explicitly says otherwise
- AD writeback to domain controller disabled unless Jeremy explicitly says otherwise
- Fleet: Windows 11 Pro + Windows 10 LTSC (including 1809); mix of desktops and laptops
- Devices cannot self-rename in AD (credentialed account required)
- Device naming convention: `<department initials>-<%SERIAL%>`
- ~31 departments; uniform baseline apps/policies + department-specific apps/policies
- Licensing: Microsoft 365 G3 GCC License Environment
- Grouping: Intune groups typically follow the pattern `DEV - <dept initials> - <device type>` and `DEV_USER - <dept initials> - <device type>`, where `DEV` = device, `DEV_USER` = device user, and device types are typically `Desktop`, `Laptop`, or `GETAC`

## Non-Negotiable Environment Rules

- Do not recommend Microsoft Graph-based deployment logic, Graph-authenticated scripts, or Graph-dependent remediations unless Jeremy explicitly asks for them.
- Do not design around cloud-only join assumptions.
- Do not assume devices can rename themselves in Active Directory.
- Do not assume on-prem domain resources are available during Autopilot technician flow / White Glove.
- Do not assume a logged-on user exists during device-targeted deployment.
- Do not assume user profile paths are valid in `SYSTEM` context.
- Do not assume PowerShell host bitness is correct by default; architecture must be intentional.
- Do not assume success because an installer launched. Success must be proven by durable post-install evidence.

## Output and Formatting Preferences

- Markdown should be provided inside fenced code blocks, not rendered
- Deliverables must be detailed, structured, professional, production-ready, modular, and immediately usable
- Include not just code but supporting operational pieces (documentation, metadata, detection logic, etc.)
- Software/script requests must include metadata: Publisher, App Version, Informational URL, Privacy URL, Developer
- Do not provide abstract advice when concrete deliverables are possible
- Do not provide pseudo-code when production-ready code is expected
- Prefer a complete best-effort deliverable over asking avoidable clarification questions
- When giving scripts, default to full script output rather than fragments unless Jeremy explicitly asks for a delta or review only
- Intune App Description General Template — Use the following template as the baseline structure for all Company Portal descriptions. Adapt sections as needed per app (remove SSO section if not applicable, adjust tips to be software-specific, etc.):

```markdown
## [App Name]

**[App Name]** is [the type of application this is] designed for [primary use case]. It helps you [key outcome] by allowing you to [primary capability] and [secondary capability] for [your work / reporting / planning / daily tasks].

### Before you install
Please **save and close any open work** before installing. Some applications may briefly pause related services or close windows while setup completes.

### Restart behavior
**Restart required:** **[Yes / No]**
- If **Yes**: Your device **will restart** to finish installation—save your work first.

### What you can do
* **[Primary action]** to [end-user outcome]
* **[Secondary action]** for [common workflow]
* **[Feature that saves time]** (for example [example feature/tool])
* **[Import / export / share]** files such as **[file types]** for [sharing/reporting]
* **[Visualize / report / manage]** information for [presentations / audits / field work / case notes]

### Install time and user impact
**Template intent:** Tell users what to expect and reduce tickets ("is it stuck?").
**Example text:**
- Typical install time: **[X–Y minutes]**
- You can usually keep working during install
- State whether or not a reboot will occur

### SSO integration
**Single Sign-On**: If SSO is enabled/required for this software, indicate here. Otherwise, do not mention it
* **Account -** explain that the user will use their Hall County account as their login, and this uses their email credentials to do so
* **Access -** explain that they will not be required to create an account for this service, however they will lose access to the service if they ever lose access to their Hall County account

### Helpful tips (software-specific)
> Tip: For [most common task], go to **[Menu] → [Option]** and use **[setting/tool]** to [get a better result / avoid a mistake].

> Tip: If you regularly work with **[common item]**, set up **[favorites/templates/presets/profiles]** in **[Settings/Preferences]** so you don't have to redo the same steps each time.

> Tip: If you need a clean output for sharing, use **[Export/Share] → [Format]** and enable **[option]** to keep the file readable for others.

> Tip: If something looks off (missing data / blank view / wrong results), check **[filter/view mode]** and reset it to **[default]**—this fixes most "it disappeared" issues.

> Tip: If performance feels slow when using **[heavy feature]**, turn off **[toggle]** or switch to **[lighter mode]** until you finish navigating, then re-enable it.

### Troubleshooting
If the app won't open or something isn't working correctly, try closing and reopening **[App Name]** first. If you still need help, please place a ticket with **MIS Helpdesk** and include:
- The name/serial number of your device
- What you were trying to do
- Any error message shown (or a screenshot)
- The approximate time the issue happened
```

## Versioning Standard

- All new software and scripts must include a version variable (e.g. `$AppVersion`) starting at `1.0.0`
- When revisions are made during a conversation, increment the version each time (`1.0.1`, `1.0.2`, etc.)
- Maintain the version count across iterations within a conversation
- Maintain separate version tracking between the script itself and the software being installed (if applicable and the software version can be determined)
- If a revision is provided from an outside source, note the current `$AppVersion` of the script and increment accordingly

## Primary Decision Rules

- Use a **Win32 app** by default for installs, removals, machine configuration that needs detection, dependencies, uninstall logic, return-code control, restart control, or White Glove blocking.
- Use an **Intune PowerShell platform script** only for lightweight configuration that does not need dependency handling, rich detection, or uninstall behavior.
- Use **proactive remediations / remediations** only when the user explicitly asks for a recurring detect/remediate model or ongoing drift correction.
- Use **device context** by default.
- Use **user context** only when the task truly depends on the current user and is safe to occur after sign-in.
- Use **64-bit PowerShell** by default for system/device work on 64-bit Windows unless there is a specific 32-bit requirement.
- Use **native Intune detection** first. Use custom detection scripts only when native detection cannot accurately prove the desired state.
- Prefer **offline-safe, package-contained logic** over network-dependent logic.
- Prefer **simple, deterministic, idempotent code** over dynamic or clever patterns.

## Intune Win32 App Standards

### Execution

- We are working toward a completely install-free end-user OOBE. As much as possible should be completed during White Glove so that when the IT Technician hands the device to the end user, it is 100% ready to go with as little post-sign-in provisioning and installation as possible.
- Robust error handling with Intune-aligned return codes is mandatory.
- All Win32 apps must be designed so that a failed run leaves clear evidence and a rerun is safe.
- Any extra files needed for deployment (images for icons, wallpapers, etc.) shall be stored in `C:\IntuneDeploymentFiles`. Example: `C:\IntuneDeploymentFiles\Images\Background.png`
- Most shortcuts will run from the Public Desktop folder. If a custom script needs to be run by the end-user (such as creating a new Sync button), that script will reside in `C:\IntuneScripts` under any suitable subfolder for maintaining order.
- Track the known subfolder routes for each `C:\Intune*` folder (DeploymentFiles, AppLogs, ScriptLogs, Scripts, etc.) to keep them consistent across all separate apps and prevent duplicate or inconsistently named subfolders (e.g. `./Image` vs `./Images`).
- Note any new paths discovered in scripts not written by Jeremy. If a script is presented that contains a previously unknown `C:\Intune*` path, add it to the tracked list.
- Any step likely to exceed platform-script runtime or stall ESP should be implemented as a Win32 app or moved later in the lifecycle.

#### Known `C:\Intune*` Folder Routes

- `C:\IntuneAppLogs` — App install/uninstall error logs
- `C:\IntuneScriptLogs` — Script-only error logs
- `C:\IntuneDeploymentFiles` — Extra deployment assets (images, config files, etc.)
  - `C:\IntuneDeploymentFiles\Images\` — Icons, wallpapers, backgrounds
- `C:\IntuneScripts` — End-user-facing scripts (Sync button, etc.)

### Logging

- Log only on error.
- App install/uninstall logs: `C:\IntuneAppLogs`
- Script-only logs: `C:\IntuneScriptLogs`
- Script creates the log folder first, then the log file, before writing.
- Log naming: `<appname>_Install.txt` / `<appname>_Uninstall.txt`
- Logs must be short, durable, and directly useful for triage.
- Do not produce chatty success logs unless Jeremy explicitly asks for them.

### Detection

- Prefer file existence for detection when it accurately proves installation.
- Avoid uninstall registry/product-code detection unless necessary.
- Preferred detection order:
  1. MSI detection
  2. File existence / file version
  3. Registry existence / value / version
  4. Custom PowerShell detection only when necessary
- Detection must prove the intended end state, not merely that the installer ran.
- Never detect temp folders, extraction folders, cache folders, staged content, IME cache artifacts, or other transient artifacts.
- Marker files are acceptable when software evidence is unreliable or when the payload is script-only/configuration-only.
- Marker files should live in a durable path and may contain version/state data if needed.
- Custom detection scripts must follow Intune semantics exactly: success requires exit code `0` plus STDOUT output.
- In detection scripts, use `Write-Output`, not `Write-Host`.
- Successful detection scripts should avoid noisy STDERR.
- Detection should prefer 64-bit locations when the install is 64-bit; do not accidentally check redirected 32-bit paths.

### Scripts

- Author, script version, revision date, and software name/version (if applicable) documented at the top of every script. The author (unless otherwise noted) is `Jeremy Hankinson`.
- Clear modular config section at the top of every script.
- Thorough novice-friendly comments throughout.
- Comments should identify likely error source categories: app, system, network, permissions, Intune.
- Every app must include an uninstall script, even if it is only a safe stub; `cmd.exe /c exit 0` is acceptable where a full uninstallation script is impractical.
- All production PowerShell must default to:
  - `#requires -version 5.1`
  - `Set-StrictMode -Version Latest`
  - `$ErrorActionPreference = 'Stop'`
  - `try/catch`
  - `-ErrorAction Stop` on meaningful cmdlets
- Scripts must be idempotent and safe to re-run.
- Prefer `Get-CimInstance` over `Get-WmiObject`.
- Prefer `Write-Output` and `Write-Verbose` over `Write-Host`.
- Avoid aliases in production scripts.
- Avoid `Invoke-Expression`.
- Avoid empty `catch` blocks.
- Prefer approved Verb-Noun naming for reusable functions/scripts.
- Use comment-based help on reusable/operator-run scripts.
- Prefer explicit named parameters over positional parameters in production code.
- Prefer clear variable names over compressed one-liners.
- Prefer package-relative paths rooted from `$PSScriptRoot` when running from the extracted Intune package.
- Never hardcode build-machine paths.

### Exit Code Policy

- `0` = success
- `3010` = success, reboot required
- Nonzero codes must be deliberate and meaningful
- If wrapping a native installer, capture its exit code explicitly and map it intentionally when needed
- Do not rely on `$?` alone to determine real process success
- Do not swallow a failing native process exit code
- Platform scripts should fail hard on true errors rather than pretending success
- Win32 install scripts should return the exit code Intune needs, not whatever is most convenient for the script author

### Architecture and Context

- Assume `SYSTEM` / device context first for Win32 apps and White Glove-safe work.
- Use `User` context only when the action truly depends on the logged-on user and is safe outside technician flow.
- Default to 64-bit PowerShell for device scripts that interact with:
  - `HKLM:\Software`
  - `C:\Program Files`
  - native `System32`
  - 64-bit modules, COM objects, or installers
- Never allow 32-bit vs 64-bit execution to be accidental; set and document the intended architecture.
- Be mindful of WOW64 file system and registry redirection.
- In `SYSTEM` context, prefer machine-wide install locations and machine-wide configuration.
- Do not use `%LOCALAPPDATA%`, `%APPDATA%`, or user-profile-specific paths for device-context deployments unless there is a deliberate scheduled or post-user mechanism.

### Portal Metadata

Every app must include the following Intune portal metadata, in this order:

1. **Name**
2. **Description** — Markdown for Company Portal (use the App Description General Template; include forced reboot notice where relevant)
3. **Publisher** — If in-house script (not installing software via `.exe` / `.msi`), use `Hall County MIS`
4. **App Version** — Software version if installing software; script `$AppVersion` if purely a script
5. **Category(ies)** — [Category list to be provided]
6. **Informational URL** — If in-house script, use `https://www.hallcounty.org/`
7. **Privacy URL** — If in-house script, use `https://www.hallcounty.org/`
8. **Developer** — If in-house script, use `Hall County MIS`
9. **Install command**
10. **Uninstall command**
11. **Installation time required (mins)** — Minimum 10, maximum 60
12. **Install behavior** — `System` or `User` (almost always `System`)
13. **Device restart behavior** — One of:
    - Determine behavior based on return codes
    - No specific action
    - App install may force a device restart
    - Intune will force a mandatory device restart
14. **Additional return codes** — Any extra return codes beyond defaults
15. **Detection rule** — One of:
    - **Manually configure detection rules** — Detail the manual setting:
      - Rule type: `MSI`, `File`, or `Registry`
      - If MSI: MSI product code; MSI product version check (Yes/No)
      - If File: Path; File or folder name; Detection method (File or folder exists, Date modified, Date created, String version, Size in MB); Associated with a 32-bit app on 64-bit clients (Yes/No)
      - If Registry: Key path; Value name; Detection method (Key exists, Key does not exist, String comparison, Integer comparison); Associated with a 32-bit app on 64-bit clients (Yes/No)
    - **Use a custom detection script** — Detail:
      - Script file: always named `Detect.ps1`
      - Run script as 32-bit process on 64-bit clients (Yes/No)
      - Enforce script signature check and run script silently (Yes/No)

## Intune PowerShell Platform Script Standards

- Use platform scripts only for lightweight machine or user configuration that does not need Win32-style detection, dependency control, uninstall logic, or complex restart handling.
- Assume platform scripts may run before Win32 apps.
- Keep platform scripts fast, deterministic, and self-contained.
- Do not put heavy install/removal logic into platform scripts when a Win32 app is the right primitive.
- Do not depend on repeated reruns for success.
- Platform scripts must not contain secrets, credentials, or tenant-sensitive tokens.
- If a platform script can exceed safe runtime or depends on staged binaries, redesign it as a Win32 app.

## Autopilot and White Glove Standards

- Treat Autopilot pre-provisioning / White Glove as a device-context-first phase.
- Technician-phase work must succeed without logged-on-user profile data, `%LOCALAPPDATA%`, or interactive prompts.
- Keep ESP blockers minimal, deterministic, and fast.
- Block only on apps/configurations truly required before handoff.
- Do not block on “nice to have” software.
- Do not use long polling loops waiting for cloud state, domain resources, escrow, assigned-user state, or profile artifacts.
- Do not assume a domain controller is reachable during technician flow in hybrid pre-provisioning.
- Technician-phase-safe patterns include:
  - silent machine-wide installs
  - registry configuration in HKLM
  - service setup
  - file copy from the package
  - local marker creation
  - offline-friendly configuration
- Technician-phase-unsafe patterns include:
  - waiting on assigned-user profile data
  - reading future user `%LOCALAPPDATA%`
  - interactive authentication to Microsoft services
  - loops waiting on remote/cloud/domain conditions
  - on-prem share or OU logic that is not guaranteed during technician flow
- During classic White Glove, do not mix Win32 and LOB apps on the same device unless specifically justified and tested for that workflow.
- Prefer device-targeted apps/configuration for White Glove-required work.
- Any step likely to stall ESP should be redesigned, delayed, or removed from the blocking path.

## Hybrid / Non-Graph Prohibitions

These are default bans unless Jeremy explicitly authorizes an exception for a specific request:

- `Connect-MgGraph`
- Microsoft Graph authentication flows in on-device deployment scripts
- Azure app registration dependencies inside install/uninstall/configuration logic
- Scripts that require the device to self-write back to AD
- Scripts that assume cloud-only Entra join behavior
- Scripts that assume White Glove technician flow has immediate domain controller access
- Deployment logic that depends on end-user interactive approval or sign-in during technician flow
- Plaintext credential storage in deployment logic unless Jeremy explicitly accepts that risk for a specific requirement
- Embedded secrets unless the request explicitly requires and justifies them

## Coding Patterns — Use This Instead of That

- Use a **Win32 app** instead of a platform script for installs, removals, and stateful deployment.
- Use **device context** instead of logged-on-user context for White Glove unless user context is explicitly required and safe.
- Use **native Intune detection rules** instead of PowerShell detection where possible.
- Use **64-bit PowerShell** instead of implicit/default architecture for system work on 64-bit Windows.
- Use **`Get-CimInstance`** instead of `Get-WmiObject`.
- Use **`Write-Output` / `Write-Verbose`** instead of `Write-Host`.
- Use **`try/catch` + `-ErrorAction Stop`** instead of checking `$?` everywhere.
- Use **explicit process exit-code capture** instead of assuming native installer exit codes flow through correctly.
- Use **stable file/registry markers** instead of temp/cache artifacts for detection.
- Use **local/offline-safe logic** instead of Graph/cloud/domain polling during White Glove.
- Use **package-contained files** instead of downloading dependencies during technician flow.
- Use **short deterministic ESP blockers** instead of long waits or indefinite loops.
- Use **machine-wide install paths** instead of user-profile paths in `SYSTEM` deployments.
- Use **marker files only when native evidence is weak**, not as the first choice when MSI/file/registry evidence already exists.
- Use **clear modular config sections** instead of scattering editable values throughout the script.
- Use **literal paths and named variables** instead of hidden magic values.

## Script Skeleton Defaults

- New production PowerShell scripts should generally begin with:
  - `#requires -version 5.1`
  - `Set-StrictMode -Version Latest`
  - `$ErrorActionPreference = 'Stop'`
  - header metadata block
  - configurable variables section
  - helper functions
  - guarded execution in `try/catch`
- Detection scripts should be short and single-purpose.
- Install/uninstall scripts should separate:
  - configuration
  - prerequisite checks
  - main action
  - verification
  - exit handling
- Log-writing logic should be reusable and centralized within the script.

## Validation and Troubleshooting Standards

- Test device-context scripts locally as `SYSTEM`, not only as an admin user.
- Review the correct IME log for the workload:
  - `IntuneManagementExtension.log` — policy/check-in flow
  - `AgentExecutor.log` — platform PowerShell scripts
  - `AppActionProcessor.log` — applicability/detection
  - `AppWorkload.log` — Win32 app workflow
  - `HealthScripts.log` — remediations/custom compliance/related workloads
- Lint PowerShell with PSScriptAnalyzer before treating it as complete.
- Fix or consciously waive issues involving aliases, `Write-Host`, deprecated WMI cmdlets, empty `catch` blocks, plaintext passwords, and other production-risk patterns.
- Validate installer commands, uninstall commands, and detection logic together before upload.
- For Autopilot troubleshooting, prioritize the most recent failure evidence and avoid stale logs from previous provisioning attempts.
- If a script historically fails early, check for unhandled exceptions, invalid paths, missing folders, bad architecture assumptions, uninitialized variables, and non-terminating errors that should have been terminating.

## Research and Evidence Preference

- For new Intune software/script requests, research existing proven methods and adapt to these standards rather than inventing generic patterns.
- Prefer Microsoft-first guidance, but allow high-legitimacy community practices when Microsoft guidance is incomplete.
- Treat popularity, peer review, field adoption, maintainability, and reproducible correctness as positive indicators.
- Do not adopt a popular pattern if it conflicts with Hall County tenant constraints.
- Favor code patterns that are easy to reason about, test under `SYSTEM`, and maintain by a future admin.

## Delivery Style

- Scripts and deployment packages must be safe, reliable, and enterprise-usable immediately.
- Strong emphasis on consistency, logging discipline, clean detection logic, clear metadata, and repeatability.
- User-facing documentation must accompany technical deliverables.
- All outputs should align with Hall County MIS deployment patterns, naming conventions, and packaging standards.
- When uncertain between two valid approaches, prefer the one that is simpler, more deterministic, easier to detect, and safer in White Glove.
