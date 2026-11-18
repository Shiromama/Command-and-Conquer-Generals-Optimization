# ISSUE-0056: Extracted heap integration test build needs stub correction

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** standalone actual-method integration tests

## Symptom / evidence

[VERIFIED] tools/test-pathfinding-heap.py fails at its CMake build step. Compiler output is retained in artifacts/2026-11-17-queue-replay/integration-tests/build.log. The full engine build and native smoke pairs completed separately.

## Root cause

[UNKNOWN] Inspect the compiler diagnostics for a missing standalone stub/API match. Do not change engine behavior to satisfy the test.

## Impact

Boundary/mode verification is incomplete. No test pass is claimed.

## Workaround

Correct only the isolated test harness, then compile and run the actual extracted methods again.

## Resolution / verification

Pending corrected test run.

[VERIFIED] Isolated stubs lacked TRUE and Int aliases. Corrected only the test generator; original extracted engine methods unchanged. The generator explicitly enables assertions before cassert. Actual-method tests pass 10 retail/fixed cases including the 5,000-cell cap, ties, reinsertion and cleanup; 13 actual heapAllowed mode/token cases pass. Initial failed compiler log preserved as build-initial-fail.log.
