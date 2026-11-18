# ISSUE-0039: Copy verifier default root fails under Windows PowerShell -File

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-079
- **Environment:** Windows PowerShell 5.1 -File invocation

## Symptom

[VERIFIED] `powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare-game-copies.ps1 -VerifyOnly` failed before verification: Split-Path could not bind an empty PSScriptRoot while evaluating the default Root parameter.

## Reproduction / evidence

Initial output: `artifacts/2026-11-17-t079-remediation/baseline-verify.log`.

## Impact

The documented default verification command could not execute in this invocation context. No baseline mutation occurred.

## Root cause

[VERIFIED] Root was derived from PSScriptRoot in the parameter default expression. It must be derived in the initialized script body instead.

## Workaround

Pass Root explicitly, or defer its default calculation to the script body.

## Resolution / verification

Pending default-command retry and manifest comparison.

## History

- 2026-11-17 — Recorded default-parameter failure; defer calculation and verify the actual command again.

## T-079 resolution (2026-11-17)

[VERIFIED] Deferred the default Root calculation from parameter binding into the initialized script body.

[VERIFIED] `powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare-game-copies.ps1 -VerifyOnly` exits 0 and reports all 1,914 baseline files match; baseline-verify-retry.log retained. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).

## Extended finding during final default-entrypoint checks

[VERIFIED] The same parameter-binding pattern affects launch-game.ps1 and play-shockwave-performance.ps1: their default -File -DryRun invocations fail before the body. The supplied-path regression cases were valid but did not cover this pre-existing default-path defect. Expanded the same deferred-initialization fix to all nine affected entrypoints touched by T-079; no extra engine change is required. Re-run actual default dry runs before closing this issue.

## Final extended verification

[VERIFIED] Default `powershell -NoProfile -ExecutionPolicy Bypass -File tools/launch-game.ps1 -DryRun` and the corresponding `play-shockwave-performance.ps1 -DryRun` both exit 0 after deferred default initialization. Logs are `default-launch-dryrun.log` and `default-performance-dryrun.log` in T-079 artifacts. All 12 touched PowerShell scripts parse, and the final safety suite still exits 0 with 51 assertions. No game, wrapper or registry writes occur in these dry runs. No further engine changes were needed.
