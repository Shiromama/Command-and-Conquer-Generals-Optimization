# ISSUE-0030: Documented DebrisBroadphase=yes disables the optimization

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: The getter uses stricmp(value, "no") != 0 && atoi(value) != 0. atoi("yes") is zero. An absent key enables broadphase, but the documented explicit yes disables it.

## Reproduction / evidence

[VERIFIED] Inspect `Core/GameEngine/Source/Common/OptionPreferences.cpp:692` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[INFERRED] Copying the published performance preset silently loses broadphase acceleration. The ShockWave launcher forces environment value 1 and masks this defect.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Use numeric 1 temporarily; implement and verify consistent yes/no/1/0 parsing.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] Uses the shared validated boolean parser and defaults broadphase off. True tokens yes/true/1 and false tokens no/false/0 are case-insensitive; invalid values fail closed.

[VERIFIED] `tools/test-engine-optimization-fixes.py` compiles and executes the actual getter: missing/invalid/true/false tokens pass. Engine build exits 0. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
