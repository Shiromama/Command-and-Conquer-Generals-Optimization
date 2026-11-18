# ISSUE-0033: Launcher environment isolation omits newer gameplay diagnostics

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: The explicit cleanup list omits ZH_HEAL_PULSE, ZH_HEALERS, ZH_RADIATION, ZH_NO_ICON_UI, ZH_ATTR_LOG/SAMPLE and ZH_NOFPSLIMIT, among others. TestEnv accepts any ZH_ key, but finally restores only listed keys.

## Reproduction / evidence

[VERIFIED] Inspect `tools/launch-game.ps1:132-157,193-225; GameLogic.cpp:4071-4180` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[VERIFIED] Mock invocation confirms TestEnv and ZH_NOFPSLIMIT persist after launch (launcher-check.json). [INFERRED] Inherited diagnostics can alter a benchmark; arbitrary TestEnv keys and the FPS override can persist in the caller after launch. The mock-launch reproduction uses no game process.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Snapshot and restore the union of all existing ZH_ variables, accepted TestEnv keys and all variables set by the launcher; put setup inside try/finally.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] Launcher snapshots all inherited ZH_ variables, clears them for the child and restores the complete set in finally, covering accepted TestEnv keys and all setup/start failures. The direct stock benchmark uses the same complete namespace isolation.

[VERIFIED] Actual launcher invoked with mocked Start-Process: unknown inherited diagnostics excluded; explicit TestEnv passed; original values and absent keys restored after success, injected process failure and input rejection. Final safety suite passes 51 assertions. Stock benchmark smoke runs pass. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
