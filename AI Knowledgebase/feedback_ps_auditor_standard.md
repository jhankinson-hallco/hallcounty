---
name: PowerShell Audit Standard — Core Function
description: When Jeremy asks for a code audit or says "apply your core function," use this exhaustive PS 5.1 audit methodology. Also apply proactively when reviewing scripts for production readiness.
type: feedback
---
When auditing PowerShell code, apply this methodology in full. Do not skim. Do not assume original code is correct.

**Why:** Jeremy established this as the required standard for all code reviews on production Intune scripts. It was explicitly saved as a persistent "core function."

**How to apply:** Any time Jeremy asks for an audit, code review, or says "apply your core function," run every check below. Also apply the relevant subsets whenever reviewing scripts for production readiness even without an explicit audit request.

---

## Audit Objectives

Prioritize in this order: correctness → robustness → maintainability → best practices.

- Full PS 5.1 compatibility (no PowerShell Core-only features)
- Syntax, semantic, and execution correctness
- Error handling and exception safety
- Edge cases and boundary conditions
- Code quality, readability, naming conventions
- Consistency across the full script (not just the section under question)
- Modularity, separation of concerns, low coupling
- Documentation clarity

---

## Strict Requirements

- Only valid PS 5.1 cmdlets, verbs, nouns, parameters, aliases
- No deprecated or ambiguous constructs
- Approved PowerShell verb usage and naming conventions
- No aliases in production code unless explicitly justified
- All parameter usage must be explicit and correct

---

## Error Handling Checklist

- try/catch/finally where appropriate
- All meaningful failure points caught
- Errors are structured, actionable, and traceable
- No empty catch blocks
- `-ErrorAction Stop` on all meaningful cmdlets inside try blocks
- Error messages name the likely source category (App / System / Network / Permissions / Intune)

---

## Edge Case Checklist

- Null inputs and empty strings
- Missing files, folders, registry keys
- Objects that exist but have unexpected properties
- StrictMode property access on potentially null/incomplete objects
- Pipeline scalar unwrap: always wrap in `@()` before accessing `.Count`
- First-run vs reinstall vs upgrade scenarios
- SYSTEM context vs user context assumptions
- 32-bit vs 64-bit host assumptions
- Environmental differences across Windows 10 LTSC 1809 / Windows 11 22H2+
- Mandatory `[string]` / `[string[]]` parameters that may receive valid blank
  data fields need `[AllowEmptyString()]`; otherwise PS 5.1 binding can reject
  CSV rows with empty values before function logic runs
- When relaxing column-count validation, keep the semantic minimum needed to
  produce a valid output row; do not replace "too strict" with "accepts corrupt
  input"
- Windows PowerShell 5.1 can throw `Argument types do not match` when a
  generic list is wrapped directly in an array subexpression such as
  `@($entries)` under strict validation; emit list items through the pipeline
  and capture at the call site with `@(...)`
- Destructive output resets must happen after required inputs are validated,
  or the script can fail while erasing the previous useful output
- When a file is selected by filename but content is copied into an output
  artifact, validate that the content identity matches the filename/requested
  identity before appending

---

## Code Hardening Checklist

- No fragile implicit assumptions (e.g., "this path always exists")
- Defensive programming: check before act
- `-LiteralPath` everywhere (never `-Path` for variable inputs)
- `[string]::IsNullOrEmpty()` or `[string]::IsNullOrWhiteSpace()` for string guards
- No `$?` as sole success indicator for native processes
- No `Invoke-Expression`
- No positional parameters in production code

---

## Internal Simulation Requirement

Mentally execute every branch:
- Normal path
- All catch paths
- Edge inputs (null, empty, missing, unexpected type)
- Reinstall / re-run scenario
- SYSTEM context behavior vs admin user behavior
- What happens if a mid-script step succeeds but a later step fails (partial state)

---

## Optimization Guidelines

- Eliminate redundant operations
- No premature optimization
- Prefer readable over clever
- Remove unnecessary intermediate variables only if clarity is not harmed

---

## Output Format (Required)

1. High-Level Summary of Issues
2. Categorized Findings with explanations
3. Specific Code Improvements (before/after where helpful)
4. Fully Revised Code (clean, production-ready, PS 5.1 compliant) — full script output, not fragments, unless Jeremy explicitly asks for delta only
5. Additional Recommendations (testing, logging, deployment, structure)

---

## Tone Requirement

- Thorough, precise, uncompromising
- Do not skip minor issues; small flaws matter in production
- Do not assume original code is correct
- Prefer clarity and correctness over politeness
