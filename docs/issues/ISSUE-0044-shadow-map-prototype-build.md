# ISSUE-0044: Shadow-map prototype compile errors

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** MSVC Win32

## Symptom / evidence

[VERIFIED] First prototype build fails. Compiler diagnostics retained in artifacts/2026-11-17-shadow-map/build.log.

## Impact

Prototype not staged. Existing stencil renderer remains in the staged baseline engine.

## Root cause

[VERIFIED] Prototype log symbol conflicts with the math log overload after namespace import. Other compiler diagnostics are being checked before retry.

## Workaround

Qualify/rename the diagnostic file handle and correct actual API mismatches.

## Resolution / verification

Pending build retry and capability smoke.

[VERIFIED] Corrected actual ShaderClass enum, included dx8renderer.h and renamed log handle. build-3.log records a successful engine link. This closes compile errors only; runtime acceptance remains pending.
