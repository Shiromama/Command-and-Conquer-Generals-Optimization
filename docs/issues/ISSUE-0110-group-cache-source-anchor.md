# ISSUE-0110: Group cache script expected an absent include anchor

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-110

[VERIFIED] The diagnostic preparation command stopped with `StopIteration` while looking for an explicit `PreRTS.h` include in `PathfindCell.cpp`. That source uses the build's precompiled header settings and has a different include block.

[VERIFIED] Reconstructed the initial edits' diff, added the probe at the existing include block, and resumed build verification.

## Resolution / verification

[VERIFIED] The single-worker Win32 Release MSBuild retry completed with zero errors. Its receipt is in `artifacts/2026-11-19-last-stand-group-cache/build.log`.

[VERIFIED] The initial reconstructed diff also omitted the occupancy header hunk because it searched for an LF-only line in a CRLF file. The reconstructed diff now includes the header.

[VERIFIED] Applied the T-109 and corrected T-110 diffs to a minimal baseline copy. All four T-110 files match the files used for the build after line-ending normalization.
