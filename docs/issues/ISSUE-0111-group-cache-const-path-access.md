# ISSUE-0111: Group cache diagnostic could not read a const Path

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-110

[VERIFIED] The first isolated MSBuild run exits 1 with C2662 because `Path::getFirstNode` requires a non-const Path. The diagnostic receives the original mutable Path pointer and reads its nodes.

## Resolution / verification

[VERIFIED] The single-worker Win32 Release MSBuild retry completed with zero errors. Its receipt is in `artifacts/2026-11-19-last-stand-group-cache/build.log`.
