# ISSUE-0081: Excluding the harness also removes shared declarations

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] Alpha compile fails with missing zh::parseBoolean, zhPfCompleteObject and zhPfLogCrc after replacing the PathfindHarness.inc include. That include also supplied OptimizationPolicy.h and two diagnostic helper declarations used by inactive branches outside the harness. Failure is retained in build/alpha-engine-release/build-resume.log. No game launched.

## Resolution / verification

Retain the shared policy include and replace all three harness/diagnostic entrypoints with no-ops in the isolated alpha source. Rebuild pending.

### Verified resolution

[VERIFIED] Shared policy include and diagnostic no-op declarations compile successfully. Final alpha build exits 0 and links the versioned payload; receipt build/alpha-engine-release/build-final.log.
