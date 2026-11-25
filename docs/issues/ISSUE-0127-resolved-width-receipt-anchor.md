# ISSUE-0127: Resolved-width preview expected a different CSV header call

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The first resolved-width generator stopped before emitting
the pathfinder preview. Its CSV header anchor expected an extra stream
argument after the string. The live diagnostic uses `fprintf` with the
stream as its first argument. No active game or engine source changed.

## Resolution / verification

[VERIFIED] The generator now targets the actual `fprintf` header suffix.
`python prepare.py` emitted the staged sources and exited zero.
