# ISSUE-0117: Formation field diagnostic could not read a const Path

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first diagnostic build reported MSVC C2662. The shadow helper
received a const Path while the engine's `Path::getFirstNode()` is non-const.
The production pathfinder was outside this build.

## Resolution / verification

[VERIFIED] The rebuilt shadow accepts the existing non-const Path pointer
and traverses const nodes. Win32 Release built successfully. The 1080p
replay reached frame 17,402 with sync active and matched all 15,242 route
records. See the build and analysis receipts in the shadow field manifest.
