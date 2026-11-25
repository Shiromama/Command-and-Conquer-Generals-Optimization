# ISSUE-0126: Pool-bucket scratch compile resolved an original header first

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The initial scratch compile included the original
`PathfindCell.h` through an engine header's relative include. A later
include of the preview also could not find its sibling
`PathfindCellInfo.h`. The original engine tree was outside this check's
outputs.

## Resolution / verification

[VERIFIED] `prepare-native.py` now copies `AIPathfind.h` and the sibling
pathfinder headers into the scratch include tree before overlaying the
edited header. `check-native-syntax.cmd` then returned zero for both
Win32 translation units.
