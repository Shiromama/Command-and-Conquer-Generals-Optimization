# ISSUE-0092: Restricted shell prevents patcher link fixture creation

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-084

## Evidence

[VERIFIED] Debug and packaged production runs of `tools/test-patcher.py` in the restricted shell failed during creation of two junction fixtures and one hardlink fixture with Windows access-denied errors.

## Resolution / verification

[VERIFIED] Both suites passed when rerun with permission for these disposable fixtures. Debug ran 31 tests with one production-only skip. Candidate 9 ran 31 tests with five debug-only skips. Both exited 0.
