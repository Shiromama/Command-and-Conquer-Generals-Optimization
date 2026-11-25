# ISSUE-0137: Native worker staging used a protected helper and Windows macro name

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The Win32 checker rejected calling the protected footprint
sizing helper from the nonmember staging code. The local name
`far` also collided with Windows headers.

## Resolution / verification

[VERIFIED] The engine member supplies the existing measurement via a
callback. The local upper bound has a distinct name.
`prepare.py` and `check-syntax.cmd` both exited zero.
