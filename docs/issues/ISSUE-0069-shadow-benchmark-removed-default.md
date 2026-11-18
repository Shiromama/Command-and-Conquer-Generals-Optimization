# ISSUE-0069: Shadow benchmark defaults to a removed renderer

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] tools/benchmark-shadow-map.ps1:8 still defaults Backend to ShadowMap although the delivered engine removes the implementation. Line109 requires shadow-map.csv for that backend and throws after launching/stopping the game. The documented retained stencil tool therefore fails under its default invocation. This was established from current source and patch removal; no game launched during review.

## Resolution / verification

Default to Stencil. Reject removed ShadowMap/calibration modes before modifying settings or launching unless a deliberately supplied archived build is supported and identified. Add a preflight/default contract check.

### 2026-11-18 verified resolution

[VERIFIED] Benchmark defaults to Stencil and rejects removed backends, calibration/diagnostic modes and explicit renderer-only controls before changing settings, creating output or starting a process. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1` passes 93 assertions including default AST and preflight rejection checks; receipt: artifacts/2026-11-18-review-fixes/launcher-final.log. No game launched.
