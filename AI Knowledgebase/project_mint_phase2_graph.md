---
name: MINT Phase 2 — Microsoft Graph / Intune / Entra Integration Roadmap
description: MINT (current tool) is Phase 1 of a larger initiative; Phase 2 will use Microsoft Graph to integrate directly with Intune/Entra, but Graph is currently disabled tenant-wide, making Phase 2 work hypothetical/unverifiable until it's enabled
type: project
---

Canonical file (single source of truth for multi-AI collaboration):

C:\Users\jhankinson\OneDrive - Hall County Government\Intune Files\AI Knowledgebase\project_mint_phase2_graph.md

## Fact

Jeremy considers the current MIS Inventory Navigation Tool (MINT) build — the
WinForms PowerShell 5.1 tool at
`Inventory\Inventory Management Tools\MIS Inventory Navigation Tool Development\`
(the "Navagation" typo in this path was fixed under D-109, 2026-08-24; the
folder was also renamed with a " Development" suffix earlier, under D-102,
when a parallel Production folder was split off) — to be
**Phase 1** of a larger software initiative. **Phase 2** will expand the
software using **Microsoft Graph** to integrate directly with **Intune** and
**Entra ID**, with the goal of automating and simplifying endpoint management
tasks for Hall County MIS technicians (stated 2026-08-07).

As of the same date, **Microsoft Graph API access is disabled tenant-wide**
for Hall County. Any Phase 2 design or implementation work done before Graph
is enabled cannot be verified against real tenant data or real API calls —
it is necessarily hypothetical/best-guess as to whether a given function
actually works correctly.

Note: this "Phase 1 / Phase 2" framing is a strategic/organizational label
for the whole MINT initiative. It is unrelated to and should not be confused
with the internal numbered "Phase" build stages already used inside MINT's
own `AI-Project-Plan.md` Roadmap section (e.g. "Phase 6" referenced there for
the Import Files tab build) — those are sub-phases of Phase 1 itself.

## Why

Graph being disabled tenant-wide removes the ability to do this project's
own established real-live-testing standard (see the shared
`reference_script_dev_methodology.md` and this project's own
`feedback_ps_auditor_standard.md` conventions: real execution over mocks
wherever practical) for anything Graph-dependent. There is currently no way
to exercise a real `Invoke-MgGraphRequest`-style call, a real token/consent
flow, or real Intune/Entra object responses against the actual tenant.

## How to apply

- Do not treat any future Phase 2 (Graph-based) code as "working" or "tested"
  the same way Phase 1 (MINT) code has been throughout this project's
  history. Explicitly flag Graph-dependent work as unverified/hypothetical
  in any summary, decision write-up, or handoff note until Graph is actually
  enabled on the tenant and a real call has been exercised.
- If asked to mock or simulate Graph responses for design/development
  purposes while Graph remains disabled, say so plainly rather than letting
  a simulated pass read as equivalent to this project's real-testing bar.
- Before starting real Phase 2 implementation work, confirm with Jeremy
  whether Graph has since been enabled — this is tenant configuration state
  that can change independently of any conversation.
- When Phase 2 planning/design work begins, it likely deserves its own
  project folder and its own `AI-Project-Plan.md`/`AI-Audit-Handoff.md`
  pair (per this Knowledgebase's established per-project convention) rather
  than being folded into MINT's existing Phase 1 docs, since it is a
  distinct initiative that merely follows on from MINT chronologically.
