# ISSUE-0140: Unit memo runner generator expanded nested newlines too early

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The generated staging script failed its Python syntax
check because a newline escape expanded inside a quoted string.

## Resolution / verification

[VERIFIED] The containing template now preserves the downstream
escape until the generated script inserts the PowerShell lines.
The staging generator and PowerShell parser passed, and the
control started with the memo flag off.
