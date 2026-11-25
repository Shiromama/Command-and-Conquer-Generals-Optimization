# ISSUE-0134: Queue-window probe referenced the wrong local unit variable

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The Win32 syntax check found that the generated dispatch
hook used the tick-start scope's local name for the unit.

## Resolution / verification

[VERIFIED] The generator now uses the dispatcher-local `obj`.
`prepare.py` followed by `check-syntax.cmd` exited zero against the
Win32 engine flags.
