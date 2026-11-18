# ISSUE-0078: Alpha configure still attempts legacy LZHL population

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] Isolated alpha CMake configure fails in cmake/lzhl.cmake because its legacy direct FetchContent_Populate ignores the ordinary disconnected/source override path. The default generator also selects BuildTools rather than the Community ATL toolchain. Active development source/build and game copies were not modified.

## Resolution / verification

Alpha source preparation adds an existing-source guard around the legacy population call. Seed LZHL from the pinned existing cache, configure a fresh directory with explicit VS Community instance and disconnected source overrides. Build verification pending.

[VERIFIED] The next configure exposed the same legacy population pattern for zlib. An attempted build after incomplete configuration has no project file and exits 1. Added the same existing-source guard for zlib, cached-source seeding and explicit configure exit checking in tools/build-alpha-engine.ps1.

[VERIFIED] Windows PowerShell 5.1 treats native CMake stderr as NativeCommandError under Stop even for ordinary output. Switched to a hidden Start-Process with separate stdout/stderr files and checked exit codes, matching the existing build helper pattern.

### Verified resolution

[VERIFIED] Disconnected configuration and single-worker final alpha build exit 0. Both legacy guards and pinned cache seeding are in the recipe. Final engine SHA256 8BFF29D77947DD0AF92A131C020391115F9C1A71AEF75615B3EC3B4D5D9CD467. Logs: build/alpha-engine-release/configure.log and build-final.log.
