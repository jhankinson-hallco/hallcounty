# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-06-26 - Debloat Must Not Block White Glove For One Hour

- Decision: `Remove Bloatware - AppX` is best-effort cleanup during White Glove
  and must not be allowed to consume the full Intune 60-minute runtime ceiling.
- Status: Accepted
- Evidence type: proven from logs and code
- Rationale: WGDevice01 logs show Office removal, Outlook, and Teams completed
  successfully before `Remove Bloatware - AppX` started. The bloatware package
  then ran from 2026-06-25 16:57:22 to 17:57:22 and failed with Intune timeout
  error `-2016214839`, causing ESP to mark the app failed.
- Source or local evidence: `F:\Logs\WGDevice01\AppWorkload.log` lines
  2491-2526; `System-RemoveBloatwareAppX.ps1` v1.0.7.
- Recommended action: Keep the wrapper's internal timeout below Intune's max
  runtime and treat debloat timeout as non-fatal during White Glove.

### 2026-06-26 - Office Cleanup Belongs To Dedicated Office Packages

- Decision: The bloatware child script must not download or run Office
  Deployment Tool during White Glove.
- Status: Accepted
- Evidence type: proven from code and deployment architecture
- Rationale: `RemoveBloat.ps1` had an OOBE branch that downloaded ODT from
  `officecdn.microsoft.com` and waited on Office/OneNote cleanup. This overlaps
  the dedicated Office removal and install packages and adds a network/process
  wait inside an unrelated bloatware package.
- Source or local evidence: Removed from `Debloat\RemoveBloat.ps1` v1.0.4.
- Recommended action: Keep Office removal/install logic isolated in the Office
  packages; do not reintroduce ODT work into debloat.

### 2026-06-26 - Use IME Runtime Paths For New Debloat Outputs

- Decision: New wrapper-owned logs, markers, and staged script files for this
  project belong under `C:\ProgramData\Microsoft\IntuneManagementExtension`.
- Status: Accepted
- Evidence type: project standard
- Rationale: Current workspace standard places script-authored logs in IME
  `Logs`, detection markers in IME `AppMarkers`, and durable helper/script files
  in IME `ScriptFiles`.
- Source or local evidence: `AI Knowledgebase\reference_intune_paths.md`;
  `System-RemoveBloatwareAppX.ps1` v1.0.7 and `Detect.ps1` v1.0.7.
- Recommended action: Detection should check the current IME marker path first
  and only then legacy marker paths for already deployed older packages.

### 2026-06-26 - Failure Marker Written in Catch Prevents Retry (D1)

- Decision: The catch block writes a detection marker with `ScriptVersion=X` and
  `DebloatStatus=WrapperFailed:...`. Since `Detect.ps1` only checks the version line, the
  device is permanently marked "detected" after any hard wrapper failure — Intune does not
  retry. This is Codex's v1.0.9 design, confirmed and documented here.
- Status: Accepted (consistent with best-effort policy)
- Evidence type: proven from code
- Rationale: Hard wrapper failures (missing Debloat folder, 32-bit host assertion, unhandled
  exception) are unlikely to self-resolve on retry. Writing a failure marker and moving on
  is the correct White Glove posture for a non-critical debloat package. The `DebloatStatus`
  field records the failure reason for post-deployment log review.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.10 catch block;
  `Detect.ps1` v1.0.10 — checks only `ScriptVersion=` line, not `DebloatStatus=`.
- Recommended action: Acceptable as-is. If retry semantics are ever needed, `Detect.ps1`
  would need to check a `WrapperStatus=Success` field and return not-detected on
  `WrapperFailed`. Do not change without Jeremy's explicit decision.

### 2026-06-26 - Outer Catch Must Exit 0 (Best-Effort Debloat Policy)

- Decision: The outer `catch` block in `System-RemoveBloatwareAppX.ps1` must
  always exit 0, never exit 1.
- Status: Accepted
- Evidence type: proven from code and deployment architecture
- Rationale: This package is classified as best-effort cleanup. Any exit 1 from
  the outer catch — whether from the P22 ParameterBindingException, an unhandled
  error, or a deliberate throw — blocks ESP/White Glove. Debloat failure must be
  logged and the chain allowed to continue.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.8 outer catch;
  `AI-Audit-Decisions.md` 2026-06-26 entry "Debloat Must Not Block White Glove
  For One Hour."
- Recommended action: Every exit path that is not a deliberate "succeeded" exit
  in the outer try should use `exit 0`. The marker is only written on a clean run;
  absent marker causes Intune to retry, which is the intended remediation signal.

### 2026-06-26 - RemoveBloat Non-Zero Exit Is Non-Fatal

- Decision: A non-zero exit from the child `RemoveBloat.ps1` process must be
  logged as a warning and treated as non-fatal; the wrapper continues to marker
  write and exits 0.
- Status: Accepted
- Evidence type: proven from code and deployment architecture
- Rationale: `RemoveBloat.ps1` globally suppresses errors with
  `silentlycontinue` and performs best-effort community cleanup. A non-zero exit
  likely means the script itself errored, not that debloat is mission-critical.
  Blocking White Glove because a third-party community debloat script failed is
  not acceptable. The debloat status is recorded in the marker for diagnostic use.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.8 debloat
  result handler; OPEN risk item for RemoveBloat community-script defects in
  AI-Audit-Handoff.md.
- Recommended action: Keep `$debloatStatus = "FailedExitCode$(...)"` path
  writing the marker. Do not promote to `throw` or `exit 1` in future edits.

### 2026-06-26 - Assigned Helper Functions Must Not Write Status To Success Output

- Decision: Any helper function whose return value is assigned to a variable
  must not use `Write-Output` for status/log messages.
- Status: Accepted
- Evidence type: proven from code and harness tests
- Rationale: In PowerShell, every success-stream object emitted inside a
  function becomes part of the function return. Claude v1.0.8 still inherited
  Codex's `Invoke-ProcessWithTimeout` status output. `$debloatResult` therefore
  became an array of strings plus the result object, causing StrictMode property
  access failure on `$debloatResult.TimedOut` and preventing marker writing.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.9; safe
  wrapper harness run on 2026-06-26.
- Recommended action: Use a non-pipeline status writer such as
  `Write-StatusMessage` for helper diagnostics, or return a structured object
  containing both status and data.

### 2026-06-26 - Timed Start-Process Requires Handle Touch For ExitCode

- Decision: When using `Start-Process -PassThru` with manual
  `WaitForExit(timeout)`, touch `$process.Handle` before waiting if `.ExitCode`
  must be read after completion.
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 tests
- Rationale: Local tests showed `.ExitCode` remained blank after
  `$process.WaitForExit(5000)` unless the process handle was accessed before the
  wait. `Start-Process -Wait -PassThru` populates `.ExitCode`, but cannot enforce
  a custom timeout.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.9
  `Invoke-ProcessWithTimeout`.
- Recommended action: Keep `$null = $process.Handle` before timed waits in this
  wrapper, or replace the helper with a direct `System.Diagnostics.Process`
  implementation if more advanced process capture is needed.

### 2026-06-26 - OOBEComplete Return Value Is Boolean Success, Not HRESULT

- Decision: In `RemoveBloat.ps1`, treat the `OOBEComplete` API return value as
  a nonzero success/failure boolean and use the out parameter to decide whether
  OOBE is complete.
- Status: Accepted
- Evidence type: proven from local Windows PowerShell 5.1 test
- Rationale: A local direct probe on a completed device returned `apiResult=1`
  and `oobeComplete=1`. Treating `apiResult=1` as an HRESULT-style failure would
  incorrectly skip the OOBE-state result. A probe failure must default to
  skipping OOBE-only cleanup, not taking the OOBE branch.
- Source or local evidence: `Debloat\RemoveBloat.ps1` v1.0.7 OOBE block; local
  test on 2026-06-26 returned `apiResult=1 oobeComplete=1`.
- Recommended action: Keep `$isOobeIncomplete` defaulted to `$false`; only set
  it to `$true` when the API call returns nonzero and the out parameter is `0`.

### 2026-06-26 - Console.Error Is Also Discarded In IME SYSTEM Context (F1)

- Decision: `[Console]::Error.WriteLine` in the wrapper is discarded in IME's non-interactive
  SYSTEM service context, for the same reason as `[Console]::Out.WriteLine` (fixed in v1.0.10).
  Both `Console.Out` and `Console.Error` resolve to `TextWriter.Null` when no console is
  attached. Both must be replaced with `Write-Warning` or `Write-Host`.
- Status: Accepted
- Evidence type: proven from code; inferred by extension of v1.0.10 proven finding
- Rationale: In v1.0.10, local proof showed `Console.Out` in IME's SYSTEM context writes to
  `TextWriter.Null`. `Console.Error` uses the same `System.Console` infrastructure and the same
  null-sink assignment. The two remaining `[Console]::Error.WriteLine` calls were in the most
  diagnostic-critical code paths: `Write-DetectionMarker` catch (marker write failure) and the
  outer catch (any hard wrapper failure). `Write-Warning` targets PS stream 3, captured by
  `Start-Transcript` when active.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.12; v1.0.10 AGENTS.md lesson
  on `[Console]::Out.WriteLine` in IME SYSTEM context.
- Recommended action: Do not use `[Console]::` for any user-visible output in wrapper scripts.
  Use `Write-Host` (stream 6) or `Write-Warning` (stream 3); both are captured by transcript.

### 2026-06-26 - CLM Breaks Active Wrapper Process Supervision

- Decision: Active `System-RemoveBloatwareAppX.ps1` v1.0.12 is supported only
  when the package runs in FullLanguage mode. It must not be assumed reliable
  under Constrained Language Mode without signing for FullLanguage or refactoring
  the wrapper and bundled child to CLM-safe logic.
- Status: Accepted as open risk
- Evidence type: proven from sterile harness
- Rationale: A Windows PowerShell 5.1 sterile harness set
  `$ExecutionContext.SessionState.LanguageMode = 'ConstrainedLanguage'`, mocked
  AppX cmdlets, redirected the IME root to a temp folder, and ran the active
  wrapper with a fake child. The wrapper launched the child, then failed inside
  process supervision with `Cannot invoke method. Method invocation is supported
  only on core types in this language mode.` The outer catch wrote a
  version-matching marker with `DebloatStatus=WrapperFailed:...`, and the
  existing detection logic would report installed because it checks only
  `ScriptVersion=1.0.12`.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.12
  `Invoke-ProcessWithTimeout`; sterile CLM harness run on 2026-06-26.
- Recommended action: If Hall County devices enforce WDAC/AppLocker CLM for
  Intune scripts, either sign this package so it runs FullLanguage or replace
  the current wrapper/child architecture. Do not rely on the current timeout
  helper to supervise the child under CLM.

### 2026-06-26 - CLM Process Supervision Pattern For Wrapper v1.0.13

- Decision: `System-RemoveBloatwareAppX.ps1` v1.0.13 uses two process
  supervision paths. FullLanguage keeps direct process-object method calls
  (`Handle`, `WaitForExit`, `Refresh`) because that path preserves redirected
  stdout/stderr and reliable child exit-code capture. ConstrainedLanguage uses
  `Wait-Process -Timeout`, disables child stdout/stderr redirection, and uses
  `WindowStyle Hidden` instead of `NoNewWindow`.
- Status: Accepted
- Evidence type: proven from sterile harness
- Rationale: Testing showed a pure `Wait-Process` rewrite caused redirected
  child exit codes to come back blank, so FullLanguage children were incorrectly
  marked `FailedExitCode`. Testing also showed CLM with `Start-Process
  -NoNewWindow` produced blank exit codes when the parent process had redirected
  streams, while `WindowStyle Hidden` preserved exit code `42`. The split path
  preserves the best behavior in both language modes.
- Source or local evidence: `System-RemoveBloatwareAppX.ps1` v1.0.13
  `Invoke-ProcessWithTimeout`; sterile wrapper harness on 2026-06-26 passed
  FullLanguage and CLM success, nonzero exit, and timeout scenarios.
- Recommended action: Keep the split process-supervision path unless a future
  target-device SYSTEM test proves a better single implementation. Do not
  replace it with a pure `Wait-Process` rewrite while stdout/stderr redirection
  is still required in FullLanguage.

### YYYY-MM-DD - <Decision Title>

- Decision:
- Status: Accepted / Rejected / Partially accepted / Superseded
- Evidence type: proven from code/docs/logs / likely inference / recommendation
- Rationale:
- Source or local evidence:
- Recommended action:

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:

### 2026-06-26 - D1 Failure Marker Acceptance Does Not Cover CLM Supervision Failure

- Prior finding: D1 accepted version-matching failure markers in the wrapper
  catch because hard wrapper failures are unlikely to self-resolve and debloat
  must not block White Glove.
- Disagreement: Keep D1 for normal best-effort wrapper failures, but do not
  treat CLM process-supervision failure as fully covered by D1. In the CLM
  harness, failure happened after the child was launched and before the wrapper
  could wait, capture exit code, or enforce timeout. The marker then caused
  detection to pass, which can hide that the supervised timeout contract did not
  run.
- Evidence type: proven from sterile harness
- Supporting evidence: 2026-06-26 CLM harness produced exit 0 and marker
  `ScriptVersion=1.0.12` with `DebloatStatus=WrapperFailed:Cannot invoke
  method...`; `Detect.ps1` v1.0.12 checks only the script version line.
- Recommended action: If CLM support is required, detection should not accept a
  CLM-caused `WrapperFailed` marker as installed, or the package should be
  signed/refactored so CLM does not break supervision.
