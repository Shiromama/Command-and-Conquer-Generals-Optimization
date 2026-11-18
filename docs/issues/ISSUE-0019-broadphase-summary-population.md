# ISSUE-0019: Broadphase frame p95 summary lacks a reproducible sample window

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-15
- **Task:** T-050
- **Related:** EXP-008 section 11; T-046
- **Environment:** Retained pre-T-049 benchmark CSVs

## Symptom

[VERIFIED] Recalculating all retained wall-clock rows with linear interpolation gives baseline
p95 49.04 ms and broadphase p95 39.11 ms; EXP-008 section 11 records 54.4 and 46.0 ms.
The pair-building maxima do reproduce: 90.515 and 3.973 ms.

## Reproduction / evidence

`python artifacts/2026-11-15-low-level-research/inspect.py` records input hashes, row counts,
method and results in `recalculated.json`. Inputs: `shockwave-pairfilter/filter-off-perf.csv`
and `shockwave-broadphase/perf.csv`. The report does not assume all-row and steady-state
statistics refer to the same population.

## Impact

[VERIFIED] A `frame > 300` population reproduces the earlier frame p95 summary.
This does not invalidate the reproduced pair-building maxima or prove a regression. Do not
present the historical frame p95 pair as a freshly reproduced current-engine result.

## Root cause

[VERIFIED] The missing warmup specification explains the difference: retaining wall-clock
frames strictly greater than 300 reproduces 54.42955 and 46.04418 ms.

## Workaround

Use explicit all-row results for reanalysis and retain old numbers as historical summaries.
No task is blocked; research and experiment design remain possible.

## Resolution / verification

[VERIFIED] Added the explicit `frame > 300` population to EXP-008 section 11.
`python artifacts/2026-11-15-low-level-research/inspect.py` exited 0 and reproduced
baseline p95 54.42955 ms (540 samples) and broadphase 46.04418 ms (780 samples).
Raw inputs are unchanged; the JSON includes their hashes. This verifies the historical
summary population, not the corrected current engine performance.

## History

- 2026-11-15 - Found by independent CSV recalculation during T-050.

- 2026-11-15 - Fixed: recovered warmup selection and documented exact sample counts.
