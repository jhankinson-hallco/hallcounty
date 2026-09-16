# AI-Audit-Decisions.md

## Durable Decisions

### 2026-09-10 - WSUS-restricted devices retry against a bundled offline source; GPO change explicitly out of scope

- Decision: `Add-CapabilityWithFallback` (`Install-PrintFaxScan.ps1`, `PDQ\Install-PrintFaxScan-PDQ.ps1`) tries `Add-WindowsCapability` normally first. Only on failure does it check for offline source folders bundled under `.\Source\` (one per Windows build) and, if any exist, retry with `-Source <all subfolders> -LimitAccess`. If none exist, the original failure propagates unchanged. No change was made to the "Specify settings for installing optional components and repairing component" GPO or any other WSUS/Windows Update policy.
- Status: Accepted
- Rationale: A real target device failed with `Add-WindowsCapability failed. Error code = 0x800f0954` at line 142 of `Install-PrintFaxScan.ps1`, reported directly by Jeremy. This workspace's own `Windows Update Source Diagnostics` project already proved, on a different Hall County endpoint (`TA-PF47WVTR`), that domain devices here are under a `WSUS - Internal (TC18)` GPO with `UseWUServer=1` - and WSUS deployments typically do not sync Features-on-Demand content, which is the documented cause of this exact error code. The generic Microsoft-side fix (allow optional-component repair content to come directly from Windows Update via GPO) was considered and explicitly rejected by Jeremy: "Changing the GPO isn't an immediate possibility right now, so whatever fix needs to be implemented should not involve that." A local, scoped `-Source`/`-LimitAccess` retry achieves the same practical outcome without touching that policy, at the cost of Jeremy needing to obtain and stage the actual Features-on-Demand content per Windows build (a new manual step, not yet done).
- Evidence type: the WSUS-enforcement mechanism is proven from this workspace's own prior endpoint evidence; that this is proven from the actual error report Jeremy pasted (device, line number, and hex code match exactly). I do not have this device's own CBS/DISM log, so the specific chain from "WSUS enforced" to "this exact call failed" is a likely inference, but it matches the documented failure mode for `0x800f0954` exactly and there is no competing explanation on file.
- Recommended action: Do not attempt a GPO-based fix without Jeremy's explicit go-ahead - he has ruled it out for the near term. Stage `.\Source\<build>\` content (from the Microsoft Volume Licensing Service Center/admin center Features-on-Demand ISO, or a matching Windows installation ISO's `\sources\sxs` folder) for each Windows build actually deployed, then redeploy to the originally-failing device to confirm.

### 2026-09-10 - Both apps get the WSUS/Features-on-Demand fix, not just the one that errored

- Decision: The offline-source fallback was added identically to both `Install-PrintFaxScan.ps1`/`PDQ\Install-PrintFaxScan-PDQ.ps1` (this project, the one that actually errored) and `Install-PrintManagementConsole.ps1`/`PDQ\Install-PrintManagementConsole-PDQ.ps1` (the sibling project), even though the reported production error was only here.
- Status: Accepted
- Rationale: Jeremy observed that Print Management Console's apparent success on the same class of device is not proof its online path actually works - if the capability was already present on that device's image, the install script's idempotent "already Installed" fast path (see the 2026-09-09 marker/state decisions) never calls `Add-WindowsCapability` at all, so the WSUS/Features-on-Demand problem would never have been exercised for that app on that device. Both apps use the identical DISM mechanism and are deployed to the identical WSUS-managed fleet, so there is no reason to expect Print Management Console would behave differently on a device that genuinely needs to download it fresh.
- Evidence type: proven reasoning (the idempotent fast-path mechanics are directly visible in the code), applied as a preventive fix rather than waiting for a second production failure to confirm.
- Recommended action: Treat any future WSUS/Features-on-Demand-related fix as applying to both projects in this tandem by default, per the general tandem-parity expectation for this workspace.

### 2026-09-10 - Capability identity resolved by name prefix, not a hardcoded exact revision suffix

- Decision: `Get-CapabilityInfo`/`Detect.ps1` query `Get-WindowsCapability -Online -Name 'Print.Fax.Scan*'` (name-prefix wildcard), require exactly one result, and use that single match's own `.Name` for the rest of the run (state re-checks, the actual `Add-WindowsCapability`/`Remove-WindowsCapability` call). This refines, but does not reverse, the 2026-09-09 "Live capability state is detection authority" decision below - live state is still the sole detection authority; only the matching mechanism changed.
- Status: Accepted
- Rationale: The prior approach queried by the exact literal string including the revision suffix (`~~~~0.0.1.0`). This workspace's fleet spans Windows 11 Pro down to Windows 10 LTSC 1809 (per `AGENTS.md`); if that suffix ever differs on an older build, an exact-literal query finds zero matches and fails closed on every run for that build - a full deployment failure for that fleet segment, not a corner case. Resolving by prefix and asserting a single match keeps the safety property Codex added (guards against an ambiguous multi-match) while removing the dependency on a suffix value that has not been confirmed stable across Hall County's actual LTSC 1809 devices. I found only third-party (non-Microsoft) sources suggesting the suffix has stayed `~~~~0.0.1.0` on recent Windows 10/11 builds - nothing authoritative, and nothing covering 1809 - so this decision treats suffix stability as unverified rather than assuming either way.
- Evidence type: proven (the resolve-once-reuse mechanism was verified both via code review and a live run on this workstation); the underlying "does the suffix ever actually differ" question remains a likely inference, not proven either way.
- Recommended action: Keep detection and the install/uninstall scripts resolving the name dynamically rather than reintroducing a hardcoded exact literal. If a future device is ever found where the wildcard match returns 0 or more than 1 result, that is real evidence worth recording here either way.

### 2026-09-10 - UninstallPending is not a completed install

- Decision: Install scripts (`Install-*.ps1` and `PDQ\Install-*-PDQ.ps1`) treat only `InstallPending` as an in-flight reboot-pending install to report as success (exit 3010). `UninstallPending` observed as the *initial* state before any install action falls through to the existing "unexpected precondition, do not attempt install" `throw` (exit 1). This corrects the 2026-09-09 "Pending servicing states return reboot required" decision below, which grouped `InstallPending` and `UninstallPending` together in the install scripts' initial-state fast path.
- Status: Accepted
- Rationale: Per Microsoft's `DismPackageFeatureState` enumeration documentation, `UninstallPending` means a removal is pending completion via reboot - the opposite of what the install script's fast path assumed. The prior code would exit 3010 (and, on the Intune side, write an Intune marker claiming `Status=RebootRequired`) without ever calling `Add-WindowsCapability`, while the true post-reboot end state for a capability in `UninstallPending` is `NotPresent`/`Removed`, not `Installed`. The uninstall scripts' own handling of `UninstallPending` (exit 3010, no action needed since a removal is already in flight) was already correct and is unchanged.
- Evidence type: proven, confirmed against Microsoft Learn's `DismPackageFeatureState` enumeration reference.
- Recommended action: Do not re-merge `InstallPending` and `UninstallPending` into a single "reboot required, treat as success" branch in an install script. They mean opposite things.

### 2026-09-10 - Cross-channel marker cleanup is best-effort; the channel's own marker write stays mandatory

- Decision: `Remove-StalePdqMarker` (Install scripts) and the per-marker loop in `Remove-AllAppMarkers` (Uninstall scripts, Intune and PDQ) now catch and log a warning on failure instead of throwing. `Write-AppMarker` (the channel's own primary marker write) is unchanged and still throws on failure. This narrows the 2026-09-09 "Marker operations are verified and cross-channel cleanup is mandatory" decision below.
- Status: Accepted
- Rationale: By the time cross-channel/stale-marker cleanup runs, the actual capability install or removal has already succeeded and been independently verified via DISM state - the marker cleanup step is tidying up an administrative artifact, not proving this run's core result. Per this workspace's own `reference_intune_code_patterns.md` guidance ("Mandatory vs. best-effort"), a cleanup step protecting against reporting false success for THIS run's core action should be mandatory; a step tidying up an already-irrelevant leftover once the core action is independently verified should be best-effort. Since `Detect.ps1` is deliberately marker-independent (per the decision above), a missed cleanup causes no functional detection harm - but escalating it to `exit 1` on an already-successful capability operation is a real, misleading failure signal that could fail an entire blocking ESP phase during White Glove over a marker-file housekeeping hiccup (locked file, AV scan), per this workspace's White Glove/ESP notes.
- Evidence type: proven from reading the code and this workspace's own documented policy.
- Recommended action: Keep the channel's own marker write mandatory (it is the record this run owns); keep cross-channel/stale-marker cleanup best-effort (log and continue). As a side effect, `Remove-AllAppMarkers` now attempts both marker tiers independently instead of aborting the whole loop after the first failure.

### 2026-09-10 - Packaging-staging utility removed; packaging stays fully manual

- Decision: `New-PrintFaxScanIntuneSource.ps1` is deleted. This supersedes the 2026-09-09 "Intune packaging uses an isolated three-file source" decision below.
- Status: Accepted (per Jeremy's explicit direction: "What are the new scripts for? Are they even needed? If not, remove them.")
- Rationale: The real problem the utility solved was genuine - the project root also contains the `PDQ` subfolder, and pointing `IntuneWinAppUtil.exe` at the project root directly would sweep PDQ scripts into the Win32 payload. But this workspace already documents packaging as Jeremy's own manual step, not something to automate, and "copy three named files into a clean folder" does not need a hash-verifying utility script to do safely by hand. Removing it also removes an unrequested file that was scope beyond the original ask.
- Evidence type: proven (explicit user instruction).
- Recommended action: When building the `.intunewin`, copy `Install-*.ps1`, `Uninstall-*.ps1`, and `Detect.ps1` into a clean temp folder by hand first; do not package the project root or `PDQ` subfolder directly. This is now documented in the handoff's Required Validation section instead of automated.

### 2026-09-09 - Live capability state is detection authority

- Decision: `Detect.ps1` queries the exact identity `Print.Fax.Scan~~~~0.0.1.0`, requires exactly one result, and reports detected only when its state is Installed. Markers are not part of Intune detection.
- Status: Accepted
- Rationale: Windows servicing state proves the current end state and remains correct whether Intune, PDQ, or an administrator installed the capability. A marker records deployment-channel activity but is weaker evidence than the live capability state.
- Recommended action: Keep detection side-effect-free and marker-free. Change the exact identity only when the packaged capability version changes.

### 2026-09-09 - Dedicated PDQ marker companion runs last

- Decision: The PDQ capability install script does not write a marker. `Set-PrintFaxScanMarker-PDQ.ps1` is a separate final PDQ step. This supersedes the initial 1.0.0 decision to fold marker creation into the install script.
- Status: Accepted
- Rationale: The separation follows the workspace tandem-deployment standard and prevents marker bookkeeping from being confused with the capability installation result.
- Recommended action: Configure the PDQ package in this order: capability install, then marker companion. Keep the marker version synchronized with the capability version.

### 2026-09-09 - Pending servicing states return reboot required

- Decision: Install scripts accept Installed or InstallPending after a result that requires restart; uninstall scripts accept NotPresent, Removed, or UninstallPending. Valid pending states exit 3010. Unexpected and contradictory states exit 1.
- Status: Accepted
- Rationale: Windows servicing exposes pending states during reboot-required operations. Checking only the terminal state before inspecting `RestartNeeded` incorrectly converts successful reboot-required operations into failures.
- Recommended action: Preserve the state and restart-result checks together when modifying the servicing flow.

### 2026-09-09 - Marker operations are verified and cross-channel cleanup is mandatory

- Decision: Intune install removes a stale PDQ marker after writing its Intune marker. Both Intune and PDQ uninstall scripts remove both marker tiers and fail if a marker cannot be removed. Marker replacement uses a terminating delete before rewriting.
- Status: Accepted
- Rationale: A stale marker creates misleading administrative state. A failed cleanup must be visible rather than silently reported as a successful uninstall.
- Recommended action: Keep marker cleanup in already-absent and reboot-pending uninstall branches as well as the normal branch.

### 2026-09-09 - Intune packaging uses an isolated three-file source

- Decision: `New-PrintFaxScanIntuneSource.ps1` creates a unique folder under `C:\Temp\IntunePackageSource\PrintFaxScan` containing only the install, uninstall, and detection scripts, verifies their hashes, and does not build an `.intunewin` file.
- Status: Accepted
- Rationale: The project root also contains PDQ content and audit-adjacent material. Isolated staging prevents unintended files from entering the Win32 payload while leaving package creation as the requested manual step.
- Recommended action: Always package the returned staging folder, never the project root.

### 2026-09-09 - Generic exit codes remain sufficient

- Decision: Scripts use 0 for success, 3010 for success with reboot required, and 1 for failure rather than a custom project range.
- Status: Accepted
- Rationale: The scripts are intentionally small and the log message supplies the failure detail. Additional numeric failure codes would add bookkeeping without improving the current deployment workflow.
- Recommended action: Introduce a project-specific range only if future revisions add failure classes that deployment tooling must distinguish.

## Disagreements

None recorded.

