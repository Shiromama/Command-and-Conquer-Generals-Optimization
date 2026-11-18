# ISSUE-0076: Synthetic patcher fixture uses reserved Python keyword

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] Initial tools/test-patcher.py invocation fails parsing dict(from=...) because from is reserved. No tests or game launches ran.

## Resolution / verification

Use a dictionary literal for the fixture materialization map. Full black-box suite rerun pending.

### Verified resolution

[VERIFIED] Corrected fixture parses and runs; final production suite passes 22 tests with 3 debug-only skips (19 executed), artifacts/2026-11-18-patcher-alpha/production-tests-final.log.
