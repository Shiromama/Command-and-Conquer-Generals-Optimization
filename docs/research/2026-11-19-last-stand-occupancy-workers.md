# Local blockers and parallel worker costs

- Date: 2026-11-19
- Task: T-112
- Baseline: [script commands and parallelism budget](2026-11-19-last-stand-script-commands.md)
- Evidence: [local blocker replay](../../artifacts/2026-11-19-last-stand-local-occupancy/manifest.md) and [parallel fixture](../../artifacts/2026-11-19-last-stand-parallel-fixture/manifest.md)

## Local blocker guard

[VERIFIED] The shadow records the rectangular envelope of the width
checks performed by each formation search, including its footprint.
A second call with the same exact endpoints and observed topology
within five ticks compares the effective fixed-blocker bit vector
in the previous rectangle. It records the scan cost separately.
This checks the territory the earlier clearance calls actually touched.
The diagnostic does not return a cached path.

[INFERRED] The observed occupancy is only one part of a reusable
result. Static classifications, layer transitions, allocator recovery,
and the solver's state outside the return value also need coverage.

[VERIFIED] The Win32 Release replay completed at 1920×1080 with sync
active through frame 17,402. `analyze-occupancy.py` confirmed route
parity across the comparison runs and matched 2,185 occupancy receipts.
Of 1,942 exact endpoint/topology candidates, **626** had an unchanged
local fixed-blocker vector. All 626 had different global occupancy
stamps, but matched the previous route fingerprint and return status.
The median candidate rectangle contained 7,497 cells and the median
blocker change count was 15.5.

[VERIFIED] The matches covered just **0.385 ms/tick** of timed legacy
search work, including failed returns. The diagnostic validation scan
cost **0.610 ms/tick** and recording a baseline cost **0.503 ms/tick**.
These clocks and the reference search costs come from separate runs.

[INFERRED] This rectangle guard is too conservative and too expensive
to advance as a speedup. A narrower guard would have to validate the
actual clearance answers cheaply. The next priority is measuring how
much work the repeated move orders do after the pathfinder returns,
where there may be additional savings independent of route reuse.

## Combined modeled budget

[VERIFIED] The cost model combines the unit-footprint treatment's
measured frame times with the width-two repair shadow's measured
cost and eligible search IDs. It subtracts the same request only once
and charges repair and validation work on the original fallback cases.

| Modeled width-two configuration | Average FPS | Mean time | p95 time |
|---|---:|---:|---:|
| Unit shortcut plus live repair, serial | 20.66 | 48.41 ms | 70.09 ms |
| Three participants for repair jobs only | 21.21 | 47.14 ms | 68.08 ms |
| Four participants for all modeled search jobs | 26.30 | 38.02 ms | 52.65 ms |

[INFERRED] The four-participant model still needs 4.69 ms/frame to
reach 30 FPS. That model assumes even the remaining legacy work can
be run in independent jobs and excludes communication, snapshot and
result-commit overhead. It provides an optimistic planning number,
with no measured FPS claim. Parallelizing just the isolated repair
kernel has limited room because its measured native cost is already
small. Costs from the rest of the script move pipeline and frame need
measurement before choosing a broader worker design.

## Worker fixture

[VERIFIED] The MSVC fixture builds the same repair kernel used in the
shadow. It groups the native endpoint requests by tick, uses an
invented ground and occupancy layout, and gives each participant
its own mutable scratch. Grid data and goal fields are frozen during
each batch. Results are stored by input position. This fixture
measures worker handoff, search and join in the modeled kernel.
It does not benchmark engine snapshot or result-commit work.

[VERIFIED] The fitted workload contained 1,104 native request endpoints
in 299 batches on synthetic terrain. It ran one, two and three
participants in forward and reverse order. All six runs agreed on
status, modeled route cost, expansions, steps and minimum width for
each input position.

| Total participants, including main | Batch time summed over the fixture | p95 batch time |
|---|---:|---:|
| One | 137.73–163.45 ms | 0.910–1.188 ms |
| Two | 94.18–107.65 ms | 0.558–0.668 ms |
| Three | 75.85–79.73 ms | 0.475–0.517 ms |

[VERIFIED] One-time fixture preparation took 100.67 ms. The timed
region includes dispatch, repair and join and starts after preparation.
The fixture compares output summaries and cost. It does not compare
every route coordinate.

[INFERRED] The result supports the worker architecture for isolated
repair. A production experiment should measure the cost of extracting
current map state and waiting for workers, and handle results that
become stale before being applied. More workers cannot recover time
spent in unrelated serial portions of the frame.
