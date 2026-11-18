# ISSUE-0018: Broadphase evidence names a nonexistent CSV

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-15
- **Task:** T-050
- **Related:** EXP-008 section 11; artifacts/shockwave-broadphase/manifest.md
- **Environment:** Local recorded benchmark artifacts

## Symptom

[VERIFIED] EXP-008 and the artifact manifest name `partition.csv`, but reading that path fails.
`Get-ChildItem artifacts/shockwave-broadphase` instead lists `broadphase.csv`.

## Reproduction / evidence

`Get-Content artifacts/shockwave-broadphase/partition.csv -TotalCount 3` reports path not found.
`Get-Content artifacts/shockwave-broadphase/broadphase.csv -TotalCount 3` returns
`frame,cellsMs,collMs,contactMs` and data rows.

## Impact

The recorded result needs its actual input filename before independent recalculation.
Research can continue; no task is blocked.

## Root cause

[VERIFIED] Documentation filename differs from the retained CSV filename.

## Workaround

Read the retained `broadphase.csv`; do not invent or recreate missing measurements.

## Resolution / verification

[VERIFIED] Corrected EXP-008 section 11 and the artifact manifest to `broadphase.csv`.
`python artifacts/2026-11-15-low-level-research/inspect.py` exited 0 and read 1,038 phase
rows, reproducing the 3.973 ms collision-pair maximum. No measurements were fabricated.

## History

- 2026-11-15 - Found while rechecking low-level optimization evidence.
