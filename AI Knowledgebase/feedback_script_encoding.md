---
name: Script Encoding Standard — UTF-8 BOM, ASCII-Only Content
description: All Intune PS scripts must be saved as UTF-8 with BOM and contain only ASCII characters; non-ASCII in scripts caused 0x80070000 pre-execution crash in PS 5.1 under IME
type: feedback
---

# Script Encoding Standard — UTF-8 BOM, ASCII-Only Content

**This is the default for all new PowerShell scripts.** UTF-8 BOM + ASCII-only is not a remediation step for broken scripts — it is the starting point for every script written going forward. Do not wait for an encoding failure to apply it.

All production PowerShell scripts deployed via Intune must be:

1. **Saved as UTF-8 with BOM** (EF BB BF signature)
2. **Contain only ASCII characters** (code points 0–127) — no exceptions, including comments

**Why:** PS 5.1 reads BOM-less UTF-8 files using the system ANSI code page (Windows-1252). Non-ASCII bytes are misinterpreted before the script loads. This produces a pre-execution crash with exit code `0xFFFD0000` / `0x80070000` in ~160ms and no script-authored log output — identical to a packaging failure. The root cause is invisible in the script logic because the process never reaches it.

Confirmed field failure: Remove-Office365.ps1 with UTF-8 no-BOM + em-dashes in comments returned 0x80070000 across multiple White Glove attempts. Adding BOM and replacing all non-ASCII characters resolved the pre-execution crash class.

**How to apply:**

- **New scripts:** Save as UTF-8 BOM from the very first save — do not write the script first and fix encoding later
- **Every edit:** Re-verify BOM and ASCII after any edit session, especially edits made in tools that don't preserve BOM
- **External scripts:** Verify encoding before deploying any script received from an outside source, community repo, or AI generation
- **Never use:** em dashes (U+2014 `—`), right arrows (U+2192 `→`), curly quotes (`"` `"` `'` `'`), ellipsis (`…`), or any non-ASCII punctuation — use plain ASCII equivalents (`-`, `->`, `"`, `'`, `...`)
- Verification command (run before packaging):
  ```powershell
  $bytes = [System.IO.File]::ReadAllBytes('.\Script.ps1')
  $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $content = [System.IO.File]::ReadAllText('.\Script.ps1', [System.Text.Encoding]::UTF8)
  $nonAscii = 0; foreach ($c in $content.ToCharArray()) { if ([int]$c -gt 127) { $nonAscii++ } }
  "BOM=$hasBOM  NonASCII=$nonAscii"
  ```
  Both must be: `BOM=True  NonASCII=0`

**Common non-ASCII sources to watch for:**
- Em dash (`—`) pasted from documentation or AI output — replace with `-`
- Right arrow (`→`) in comment bullets — replace with `->`
- Smart/curly quotes (`"` `"` `'` `'`) pasted from Word or web — replace with `"` and `'`
- Ellipsis (`…`) — replace with `...`

**Why:** PS 5.1 + BOM-less UTF-8 = ANSI misread = pre-execution crash. No amount of code fixes helps when the host dies before any line of the script runs.
