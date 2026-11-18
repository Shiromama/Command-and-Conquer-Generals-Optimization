# ISSUE-0043: Incremental pathfinding build cannot write the engine PDB

- **Status:** Workaround
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** MSVC Win32 incremental Release build

## Symptom

[VERIFIED] build-4.log ends with LNK1201 writing GeneralsMD/Release/generalszh.pdb. Previous successful build is staged; no failed build staged.

## Reproduction / evidence

`cmake --build build/engine-vs-community --config Release --target z_generals -- /m:1 /nodeReuse:false`; artifacts/2026-11-17-pathfinding/build-4.log.

## Impact

Corrected spawn binary not yet available. Investigating PDB/process state before retrying.

## Root cause

[UNKNOWN] Potential lingering link/PDB writer or sandbox process restriction.

## Workaround

None applied yet.

## Resolution / verification

Pending successful link and runtime smoke.

## Build recovery

[VERIFIED] 132.7 GB free disk; retrying with escalated build still produced LNK1201 (build-5.log). Preserved the failed PDB as link-failed.pdb under artifacts and retried; build-6.log records a successful link. [INFERRED] The PDB itself or its writer state was involved; no disk-space cause. CIM process introspection was unavailable inside the sandbox, so it was not used to justify process termination.

## T-035 recurrence

[VERIFIED] Shadow prototype build-2 compiles but LNK1201 recurs at link. Preserve/rename the existing PDB before relink works around the failure. Root cause remains unproven; issue is Workaround, not Fixed.
