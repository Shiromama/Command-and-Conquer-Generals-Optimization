# ISSUE-0112: Memo fixture compile misparsed the output directory

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-111

[VERIFIED] MSVC interpreted the trailing backslash before the closing quote in the fixture's /Fo directory argument as an escaped quote. The first compile exited with C1083. Its receipt is in the T-111 artifact directory.

## Resolution / verification

[VERIFIED] Switched to an explicit, quoted object filename. The Win32 fixture in
`artifacts/2026-11-19-last-stand-graphical-cache/test-memo.cmd` compiled with `cl /O2 /W4`
and exited 0 after checking all 16 expected operations. See `memo-test.log`.
