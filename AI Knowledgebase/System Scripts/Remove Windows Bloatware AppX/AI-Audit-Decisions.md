# AI-Audit-Decisions.md

## Durable Decisions

Use this file for accepted/rejected findings that should not be relitigated
without new evidence.

### 2026-09-08 - Debloat\RemoveBloat.ps1 Gets Header-Only Standards Treatment

- Decision: When bringing System-RemoveBloatwareAppX.ps1 and Detect.ps1 up
  to the current IME logging/marker standard, `Debloat\RemoveBloat.ps1`
  (the third-party-derived child script) received ONLY a `.NOTES` header
  update (current format, plus an honest new `ERROR CODES` section) - its
  body (removal logic, script-wide `$ErrorActionPreference =
  'silentlycontinue'`, self-elevation block) was explicitly left untouched.
- Status: Accepted
- Evidence type: recommendation, confirmed directly by Jeremy via an
  explicit choice among three options (header-only / untouched entirely /
  full standards alignment)
- Rationale: `RemoveBloat.ps1` is ~3000 lines of community-derived
  bloatware-removal logic already carrying multiple documented, undecided
  issues (M1-M5, H1, H2, L-series in the handoff's Active Risks). A full
  rewrite of its error handling/logging to match shop standard is a
  large, high-blast-radius change to fleet-wide AppX/OEM-bloat removal
  logic, and the 2026-05-04 audits already left "fix vs. accept as
  best-effort" as an explicit open decision - this session did not
  reopen that decision, only the header/documentation layer.
- Source or local evidence: `AI-Audit-Handoff.md` Active Risks section
  (2026-05-04 entries); direct user confirmation this session.
- Recommended action: Do not extend this project's ERROR CODES documented for
  `RemoveBloat.ps1` beyond what it can honestly do today. Its ERROR CODES
  section (0 = normal completion, 1 = rare unhandled terminating
  exception) explicitly states the script defines no distinct codes of
  its own. If a future session decides to do the "full standards
  alignment" option, expect a large, separately-scoped change - do not
  fold it into an unrelated small fix.

## Disagreements

If an AI disagrees with a prior finding, add a new entry here instead of
overwriting the original.

### YYYY-MM-DD - <Disagreement Title>

- Prior finding:
- Disagreement:
- Evidence type:
- Supporting evidence:
- Recommended action:
