# ISSUE-0136: Worker policy treated a build macro as a C++ identifier

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The initial syntax check rejected `RTS_GENERALS` as an
undeclared C++ identifier in the Zero Hour build.

## Resolution / verification

[VERIFIED] The adapter uses the same preprocessor branch as the
original footprint checks. `check-syntax.cmd` compiled the Win32
adapter under the Zero Hour flags with exit code zero.
