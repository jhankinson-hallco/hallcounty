---
name: Version Sync — Install / Detect / Uninstall Must Stay Aligned
description: Whenever a script revision bumps the version, check and update the companion Detect.ps1 and Uninstall scripts to keep versions consistent
type: feedback
---
When any revision is made to an install script that increments `$AppVersion`, immediately check the companion scripts in the same package and update them as needed:

- **Detect.ps1** — Update `$script:RequiredScriptVersion` to match the new install version. Also update the `.NOTES Version:` field and add a CHANGE LOG entry. Detection gates on this version string; a mismatch means the package re-deploys endlessly or never re-runs when intended.
- **Uninstall script** — Update `$script:AppVersion` and the `.NOTES Version:` field. Add a CHANGE LOG entry describing what changed. Version doesn't gate detection, but must stay in sync for log readability and operational consistency.

**Why:** Detect.ps1 uses a hard version string comparison against the marker file. If the install writes `ScriptVersion=1.1.1` but Detect still checks for `1.1.0`, detection either fails (forces perpetual reinstall) or passes prematurely (misses the re-run). Mismatched versions also make log triage and support harder.

**How to apply:** After every version bump to any script in a package, scan the same folder for `Detect.ps1` and `Uninstall*.ps1` / `Remove*.ps1` and apply version + changelog updates before closing the task.
