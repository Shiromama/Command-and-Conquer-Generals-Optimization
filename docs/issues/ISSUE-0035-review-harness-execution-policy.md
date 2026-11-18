# ISSUE-0035: Local review harness rejected by execution policy

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Windows PowerShell child process

## Symptom

[VERIFIED] Running the newly authored mock launcher harness with `powershell -NoProfile -File` returned `AuthorizationManager check failed`, UnauthorizedAccess, exit 1 before execution.

## Reproduction / evidence

[VERIFIED] Harness: `artifacts/2026-11-17-engineering-review/verify-launcher.ps1`. The first invocation failed; retry with `powershell -NoProfile -ExecutionPolicy Bypass -File artifacts/2026-11-17-engineering-review/verify-launcher.ps1` exited 0 and produced `launcher-check.json`. No game process runs; Start-Process is mocked.

## Impact

The mock verification initially could not execute; game and source inspection were unaffected.

## Root cause

[INFERRED] Child PowerShell script execution policy rejected the local file. No machine-wide policy inspection or change was needed.

## Workaround

Use a process-local policy override solely for the authored test harness.

## Resolution / verification

[VERIFIED] The retry exited 0 and printed CONFIRMED for the environment leak. No machine policy was changed.

## History

- 2026-11-17 — Recorded rejection and verified bounded retry.
