# Memory Index

## Methodology

- [Script Development Methodology — Build, Validate, Package, Deploy](reference_script_dev_methodology.md) — full stage-by-stage process: app type decision, mandatory script structure, simple function rule, validation checkpoints (parse, SYSTEM test, lint), packaging, portal config, deployment testing
- [Log Triage — Which Log Tells You What, In What Order](reference_log_triage.md) — triage sequence for Win32 failures; AppWorkload/AppActionProcessor/IME log patterns; diagnostic signatures for common failure modes; confirming deployed script version

## Reference

- [PowerShell Architecture — SysNative, WOW64, 32-bit vs 64-bit](reference_ps_architecture.md) — IME is 32-bit; use SysNative in portal commands; AppX crashes 32-bit PS host silently
- [Intune Detection — Types, Custom PS Semantics, Markers, Exit Codes](reference_intune_detection.md) — custom PS needs exit 0 + STDOUT; Write-Output not Write-Host; version-gated marker detection, Intune/PDQ marker check order
- [Intune Reusable Code Patterns — Logging, Markers, Hive Ops, Reg.exe](reference_intune_code_patterns.md) — copy-paste reliable code blocks: buffered logging, versioned marker writes, PDQ marker handoff, Default User hive mount/unmount, theme file writing
- [Intune Deployment Contexts — White Glove, Device Groups, User Groups, ESP](reference_intune_contexts.md) — what is available in each context; pre-first-login rules; ESP phases; SYSTEM vs User context
- [Intune Paths Reference — IME Runtime Folders, Logs, Registry Keys](reference_intune_paths.md) — current IME-rooted paths (Logs/Images/AppMarkers/ScriptFiles), legacy fallbacks, PDQ AppMarkers root, registry keys for lock screen/wallpaper/themes
- [Install-ExeTemplate.ps1 — Design Rules, Constraints, and Known Behaviors](reference_exe_template.md) — Process launch design, argument passing, timeout ceiling, marker pattern, uninstall limitations, derived app inventory
- [Set-ItemProperty -Type — Registry Dynamic Parameter (PS 5.1 Confirmed)](reference_ps51_set_itemproperty.md) — -Type IS valid on registry paths; RegistryValueKind values; reject audits claiming otherwise
- [ScheduledTasks Module — Confirmed Parameter Lists](reference_scheduledtasks_module.md) — DisallowStartIfOnBatteries/StopIfGoingOnBatteries do NOT exist; correct battery params; full New-ScheduledTaskSettingsSet list; SYSTEM task pattern
- [PersonalizationCSP — Node Access Types, Pro Edition Restriction](reference_personalization_csp.md) — LockScreenImageStatus is Get-only; LockScreenImageUrl is settable; Pro SKU requires Shared PC mode; direct registry write bypasses CSP enforcement
- [Windows 11 Start Layout — pinnedList JSON Schema, applyOnce Version Requirements](reference_start_layout_win11.md) — pinnedList is correct Win11 schema; applyOnce ignored pre-24H2; Shell folder copy path; taskbar.pinnedList reliability caveat

## Projects

- [MINT Phase 2 — Microsoft Graph / Intune / Entra Integration Roadmap](project_mint_phase2_graph.md) — MINT (current tool) is Phase 1; Phase 2 uses MS Graph for Intune/Entra automation; Graph disabled tenant-wide as of 2026-08-07, so Phase 2 work is unverifiable until enabled

## Standards

- [.NOTES Block Format — Required Layout for All Scripts](feedback_notes_format.md) — Version/ScriptType/Owner/WWW/CreationDate/Purpose + CHANGE LOG section; replaces old Author/Script Version/Revision Date format
- [Script Encoding Standard — UTF-8 BOM, ASCII-Only Content](feedback_script_encoding.md) — all scripts must be UTF-8 with BOM and contain only ASCII (0-127); BOM-less + non-ASCII caused 0x80070000 pre-execution crash in PS 5.1; includes verification command
- [Version Sync — Install / Detect / Uninstall Must Stay Aligned](feedback_version_sync.md) — on every version bump, update $RequiredScriptVersion in Detect.ps1 and $AppVersion in Uninstall; mismatch breaks detection gating

## Workflow

- [Do Not Build .intunewin Packages](feedback_no_intunewin_build.md) — never run IntuneWinAppUtil; packaging is always Jeremy's manual step after script work is complete

## Auditing

- [PowerShell Audit Standard — Core Function](feedback_ps_auditor_standard.md) — exhaustive PS 5.1 audit methodology: compatibility, error handling, edge cases, StrictMode traps, hardening checklist, simulation requirement, output format

## Pitfalls

- [Intune Scripting Pitfalls — Known Gotchas and Failure Modes](reference_intune_pitfalls.md) — 32 documented failure modes: stale hive mount, bare powershell.exe, CLM/.NET blocking, em dash parse errors, dependency cascade, [Parameter()] ParameterBindingException (P22), Split-Path -LiteralPath -Parent (P24), pipeline scalar unwrap breaks .Count (P25), direct registry property access under StrictMode (P26), @($genericListVariable) throws ArgumentException -- use .ToArray() instead (P27), .GetNewClosure() breaks live $script:-scoped variable/property access (P28), bare "return $array" collapses a 0-element array to $null across a function boundary (P29), [string]$Param = $null coerced to "" on bind defeats a "$null means leave unchanged" convention (P30), a P29-style "return ,$array" breaks a direct pipe into Select-Object -ExpandProperty (P35), CLM-safe timed process supervision exit-code traps (P36), marker never written, and more
