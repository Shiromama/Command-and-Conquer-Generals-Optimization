# ISSUE-0121: Team-script syntax preview split a recorded source path

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first scratch `check-syntax.cmd` attempt reported C1083
on the words of an unquoted source path from the Win32 compile record.
No engine source, PGO input library or game binary was changed.

## Resolution / verification

[VERIFIED] `prepare-syntax.py` now removes the original source using
the compile record's entire path before parsing flags. It inserts the
quoted scratch source and redirects preview headers to a private include
directory. `check-syntax.cmd` then exited 0 for both Win32 sources.
