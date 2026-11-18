# ISSUE-0029: Disabled-scan counter omits snapshot loading and object lifecycle

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: The new counter is incremented only in setDisabledUntil and decremented only in clearDisabled. Snapshot transfer restores m_disabledMask directly, without adding loaded disabled objects to the counter. No destructor or game-reset accounting exists.

## Reproduction / evidence

[VERIFIED] Inspect `Object.cpp:2155,2215,2398,4265; GameLogic.cpp:4727` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[INFERRED] In a fresh process loading timed-disabled objects can leave the counter zero, preventing the normal expiry scan. Destroying disabled objects can instead leave a stale positive count, losing the optimization. Runtime save/load reproduction remains required.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Revert the guard pending lifecycle and snapshot tests, or maintain/rebuild the count on every state transition.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] Removed the unproven counter optimization and restored unconditional servicing of disabled timers. Object.cpp is byte-for-byte equivalent to upstream after Git line-ending normalization.

[VERIFIED] `git -C vendor/GeneralsGameCode diff --exit-code -- GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Object.cpp` exits 0; compiled regression asserts counter/guard absence; full engine build and stock smoke tests pass. No derived lifecycle state remains to restore on load. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
