# ISSUE-0041: Telemetry wrapper closed before the search function ended

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** MSVC source build

## Symptom

[VERIFIED] Build failed with C2760 at AIPathfind.cpp:3573. See artifacts/2026-11-17-pathfinding/build.log.

## Root cause

[VERIFIED] The edit script counted raw braces across mutually exclusive preprocessor branches; findGroundPath has different braces in those branches. The inserted lambda closed at an inner block.

## Impact

Instrumentation build cannot run yet. No engine staged.

## Workaround

Reconstruct only AIPathfind.cpp from vendor HEAD (source-before.patch verifies it had no prior changes), then use observed column-zero function terminators.

## Resolution / verification

Pending corrected build.

[VERIFIED] Corrected function boundaries; build-2.log records successful AIPathfind.cpp compilation and linking. All search wrappers are present, and centered runtime telemetry exercises four peer routine types.
