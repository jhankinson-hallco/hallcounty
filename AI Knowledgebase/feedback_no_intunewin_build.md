---
name: Do Not Build .intunewin Packages
description: Never run IntuneWinAppUtil or build .intunewin packages; packaging is always a manual step done by Jeremy
type: feedback
---

Never build `.intunewin` packages or run `IntuneWinAppUtil.exe`. Packaging is always performed manually by Jeremy when scripts are ready.

**Why:** Jeremy explicitly instructed this on 2026-04-30. The packaging step is his decision point — he controls when sources are truly ready and when to pull the trigger on a new artifact.

**How to apply:** After completing all script work (edits, version sync, parse validation, BOM), stop and hand off. List the remaining manual steps (delete stale .intunewin, run IntuneWinAppUtil, upload to portal) but do not attempt to execute them. This applies regardless of whether a packaging tool is available on the path.
