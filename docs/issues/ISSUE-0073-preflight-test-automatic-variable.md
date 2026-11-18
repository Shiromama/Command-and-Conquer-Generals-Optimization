# ISSUE-0073: Preflight regression uses PowerShell automatic args variable

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-035

## Evidence

[VERIFIED] New mocked preflight test fails with missing mandatory ArtifactDir because $args resolves to the function's automatic argument array inside MustReject. Failure retained in artifacts/2026-11-18-review-fixes/launcher-tests-initial-failure.log. No game launched.

## Resolution / verification

Renamed the task-specific parameter map to benchmarkParams. Pending rerun of the mocked suite.

### 2026-11-18 verified resolution

[VERIFIED] Renamed the parameter map to benchmarkParams. Final mocked suite `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1` passes 93 staging/environment assertions; receipt: artifacts/2026-11-18-review-fixes/launcher-final.log. Initial failure is retained. Removed only the verified inert test fixture left by that failure. No game launched.
