# ISSUE-0138: Worker search overlay included the bucket queue twice

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The first Win32 syntax check found two physical copies of
the same bucket-queue definition in the translation unit.

## Resolution / verification

[VERIFIED] The scratch ground kernel now includes the existing engine
header through the same qualified path as the original solver.
`check-fixture.cmd` matched all 512 cases and `check-syntax.cmd`
exited zero against the actual engine compile flags.
