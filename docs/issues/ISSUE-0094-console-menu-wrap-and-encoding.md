# ISSUE-0094: Console menu wraps and its title renders incorrectly

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-086

## Evidence

[VERIFIED] The user-supplied screenshot showed the candidate 10 console menu wrapping its action list across lines and displaying a garbled dash in the title. The menu script used a non-ASCII dash in a UTF-8 script read by Windows PowerShell 5.1.

## Resolution / verification

[VERIFIED] Candidate 11 uses an ASCII title and lists Install and Uninstall on separate lines. A Windows PowerShell 5.1 harness with a simulated folder selection passed both menu choices through the actual script and patcher. The disposable fixture's original managed files were restored. The packaged menu matches the tested script byte for byte.
