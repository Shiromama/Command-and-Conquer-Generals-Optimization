# ISSUE-0132: Early-queue syntax overlay could not find relative engine headers

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The Win32 syntax check for the isolated early-queue preview
found the overlaid `AIPathfind.h` and failed with C1083 for
`Pathfinder/Path.h`. The compiler no longer searched the original
header's directory for the relative include.
The next compile exposed a second Release-only problem. The existing
destination getter is defined only under `DEBUG_LOGGING`.

## Resolution / verification

[VERIFIED] The preview generator now adds the original header directory
to its isolated include search. The indexed request probe uses an
explicit accessor available to the Release preview. `prepare.py`
and `check-syntax.cmd` exited zero with the actual Win32 flags for
`AIPathfind.cpp`, `PathfindCell.cpp` and `GameLogic.cpp`. The native
build and isolated NVIDIA relink also completed.
