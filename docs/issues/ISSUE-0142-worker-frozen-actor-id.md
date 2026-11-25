# ISSUE-0142: Frozen worker actor ID lookup failed to compile

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The Win32 engine syntax check for the frozen worker shadow
failed with MSVC C3861 at the actor ID conversion. The converted type
is declared in the footprint policy namespace.

## Resolution / verification

[VERIFIED] Qualified the conversion with `footprintPolicy::Id`.
`artifacts/2026-11-20-last-stand-frozen-worker-search/check-syntax.cmd`
compiled `AIPathfind.cpp` and `PathfindCell.cpp` and returned 0.
