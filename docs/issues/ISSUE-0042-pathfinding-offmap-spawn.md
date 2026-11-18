# ISSUE-0042: Movement harness spawned around an edge camera

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** first telemetry smoke build

## Symptom

[VERIFIED] The 20-second smoke command log contains negative Y positions (for example object 214 at y=-135.901901). The camera-centered grid is not a valid workload on the initial northamerica map camera.

## Reproduction / evidence

artifacts/2026-11-17-pathfinding/smoke/blockers-5-run-1/commands.csv and requests.csv. Smoke is excluded from baseline evidence.

## Impact

Baseline collection requires valid on-map placement; current smoke must not justify an optimization.

## Root cause

[VERIFIED] Used the current tactical camera rather than terrain bounds when centering a moving army with a 900-unit span.

## Workaround

Center on terrain bounds, adjust mobile spawn positions to passable destinations, log the resulting spawn locations and extents.

## Resolution / verification

Pending corrected smoke and bounds checks.

## Centered-smoke follow-up

[VERIFIED] Centered smoke has 200 units + 5 blockers and zero off-map spawns, but five units failed the passability adjustment at x=1475. Added deterministic nearby retries. The preliminary baseline was interrupted before acceptance and is excluded; a fully passable spawn is required.

[VERIFIED] smoke-passable completed with 200/200 adjusted units, five blockers and zero off-map coordinates. Runner now rejects count, passability or bounds failures at 11 seconds. Command and source evidence in artifacts/2026-11-17-pathfinding.
