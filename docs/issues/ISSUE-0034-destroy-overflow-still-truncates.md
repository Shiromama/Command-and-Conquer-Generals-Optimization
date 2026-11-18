# ISSUE-0034: Destroy-list overflow fallback still removes only 256 updates

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: The new path detects more than 256 modules, but its full-scan fallback stores only while numSUO < MAX_SUO. Extra registered modules remain in the scheduler when the object is deleted.

## Reproduction / evidence

[VERIFIED] Inspect `GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp:2598-2640` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[INFERRED] A sufficiently complex mod object can leave dangling scheduler pointers. The fixed-cap problem existed before this optimization; the new fallback and documentation incorrectly claim it prevents loss. No tested stock/ShockWave object is known to exceed this cap.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Use dynamically sized storage or repeatedly remove all matching updates; verify 257+ modules and scheduler integrity before claiming arbitrary-mod compatibility.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] Replaced fixed arrays and truncated fallback with a reusable per-batch vector, retaining descending-index removal and re-reading each live scheduler index.

[VERIFIED] Compiled extracted actual removal and erase methods pass 140 randomized cases for 0/1/2/255/256/257/1024 owned modules plus unrelated, non-update and unregistered modules. No owned registrations remain; unrelated registrations/indexes survive. Full engine compiles and smoke runs pass. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
