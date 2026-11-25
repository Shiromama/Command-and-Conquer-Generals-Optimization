# ISSUE-0135: Native page overlay picked two versions of PathfindCell.h

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The first isolated Win32 syntax check saw both the stock
header via a relative include and the overlaid header via a qualified
include. Compilation stopped on the duplicate type.

## Resolution / verification

[VERIFIED] The generator now places the including `AIPathfind.h` in
the same overlay so both include paths resolve the candidate header.
`check-syntax.cmd` exited zero for the pathfinder and cell translation
units with the actual engine compile flags.
