# ISSUE-0128: Standalone sample-PGO probe pulled in the security-cookie runtime

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The initial standalone DLL probe opted out of runtime
libraries and failed to link its compiler-generated security-cookie
reference. This affected only the tiny toolchain-detection artifact.

## Resolution / verification

[VERIFIED] The probe now disables the cookie only in its single
runtime-free arithmetic source. `check.cmd` links without unresolved
symbols. The engine inputs and compiler settings remain outside the probe.
