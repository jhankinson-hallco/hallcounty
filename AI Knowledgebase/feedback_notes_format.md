---
name: .NOTES Block Format — Required Layout for All Scripts
description: The required .NOTES section structure that must appear in every new script's comment-based help
type: feedback
---

Use this exact structure for the `.NOTES` block in all new scripts. The block sits between `.NOTES` and the `INTUNE CONFIGURATION` section:

```powershell
.NOTES
    Version:        1.0.0
    Script Type:    Microsoft Intune <Script or Win32 App>
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  DD/MM/YYYY
    Purpose:        One-line summary of what the script does

    CHANGE LOG
    Change: DD/MM/YYYY - Initial release -- ver. 1.0.0
```

**Why:** Jeremy standardized the Notes format to match the organizational template (Notes.txt). The prior format used different field names (Author, Script Version, Revision Date, Script Name, Paired script) and had no CHANGE LOG section.

**How to apply:** Every new script gets this block. For revisions, add a new `Change:` line. The `Version:` field replaces the old `Script Version:` field. Date format is `DD/MM/YYYY`. Script type should specify `Win32 App` or `Script` as appropriate.
