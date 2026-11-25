# ISSUE-0129: Unit-neighbor scratch batch used a forward-slash command path

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] After generating the scratch preview, invoking its batch
wrapper through `cmd.exe /d /c` with a forward-slash relative filename
failed before compiler startup.

## Resolution / verification

[VERIFIED] `cmd.exe /d /c 'artifacts\2026-11-20-last-stand-unit-neighbor\check-syntax.cmd'`
ran the actual Win32 compiler and exited 0. It reported only the existing
C5055 warnings for multiplying formation-direction enumerations by floats.
