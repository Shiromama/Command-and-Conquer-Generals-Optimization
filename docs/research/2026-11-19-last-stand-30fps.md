# Getting the Last Stand stress window above 30 FPS

- Date: 2026-11-19
- Task: T-112
- Baseline: [T-111 graphical cache comparison](2026-11-19-last-stand-graphical-cache.md)
- Evidence: [T-112 artifact manifest](../../artifacts/2026-11-19-last-stand-30fps/manifest.md)

## Frame budget

[VERIFIED] The 300 drawn frames from 16979 through 17278 averaged 66.77 ms in the
matched cache-on run and 69.73 ms with the exact retained cache implementation. The
exact-implementation run had the following costs. The timers overlap the encompassing
logic or draw timers. Each search is counted once here using its outermost census scope.

| Exact retained cache, 1080p | Mean cost per tick |
|---|---:|
| Formation ground searches | 29.68 ms |
| Ordinary fine-grid search | 9.35 ms |
| Closest-reachable fallback | 4.92 ms |
| Other timed search | 0.32 ms |
| Everything outside those timed scopes | 25.46 ms |
| Full frame | 69.73 ms |

[VERIFIED] Align search frame `f - 1` with update/draw row `f`.
`t112-budget.py` summarizes the matched on/off and exact-cache captures, with
the group timer as a cross-check. `t112-query-mix.py` and `t112-destinations.py`
tabulate the candidates by search class and destination.

[INFERRED] In a fixed-work model, making formation search free yields **24.92 FPS**
in the exact-cache run. Making all timed searches free yields **39.28 FPS** and a
32.44 ms p95. A 30 FPS mean requires 36.40 ms of combined savings from 69.73 ms.
That is about 82% of the timed search budget if everything else stays constant.
For example, an 80% formation improvement plus a 70% ordinary/fallback
improvement would reach roughly 28 FPS. The remaining gap would be about 2.65 ms.
Draw submission averaged 8.00 ms, so changing graphics cannot close the gap on
its own. These subtractions estimate opportunity and have no effect on the replay.

| Modeled savings in the exact-cache trace | Mean FPS | p95 frame time |
|---|---:|---:|
| 50% formation and other timed search costs | 21.01 | 64.29 ms |
| 80% formation and 70% other timed search costs | 27.96 | 46.19 ms |
| 85% formation and other timed search costs | 31.15 | 40.59 ms |
| 90% formation and other timed search costs | 33.46 | 36.73 ms |

## Experiments in order

### 1. Cheaper exact work in the current solver

[VERIFIED] The formation neighbor loop checks footprint clearance before rejecting
a non-clear or pinched neighbor. In the legacy clearance scan, a blocker stops
the inner column scan. The remaining columns are still visited and can encounter
an off-map cell. `getCell` returns a direct grid element for an in-bounds ground
coordinate. The existing search also walks a line toward the goal on each expansion.

[INFERRED] The first native probe moves the neighbor rejection ahead of its
unused clearance query. It also scans an interior ground footprint directly,
where early recursion on a blocker preserves the original result. Edges and other
layers keep the original code. These are potential additive gains while the
larger changes are investigated. The active diagnostic probe is gated by
`ZH_GROUP_INNER_OPT`; it has no production changes.

[VERIFIED] The independent model matched 120,000 clearance cases, including
38,611 interior-ground fast-path cases. The same-binary 1080p diagnostic pair
reached frame 17,402 with sync active. All 15,242 search records matched outside
timings, including routes and expansions. In the 300-frame window:

| Cached solver | Original inner loop | Optimized inner loop |
|---|---:|---:|
| Mean FPS | 8.97 | 9.94 |
| Mean frame time | 111.46 ms | 100.61 ms |
| p95 frame time | 150.87 ms | 138.44 ms |
| Mean formation search per tick | 45.61 ms | 35.39 ms |
| Mean ordinary plus closest search per tick | 20.65 ms | 20.30 ms |
| Mean draw time | 12.33 ms | 12.59 ms |

[VERIFIED] The 460-frame sensitivity window moved from 9.28 to 10.23 FPS.
The new reference matched the earlier exact-cache route trace but had broader
timing drift, including draw time. Compare within this pair. These changes are
diagnostic pending a reversed-order replication. See
[ISSUE-0116](../issues/ISSUE-0116-last-stand-timing-variation.md).

[VERIFIED] A separate bit-plane model matched 50,000 scalar clearance results on
a 384×384 grid for widths 1, 2, 4 and 6 and both crusher policies. Eight packed
planes use 144 KiB before row padding. This checks the footprint calculation.

[INFERRED] A native version can precompute static terrain clearance and use
live fixed-occupancy row masks for the remaining check. Terrain edits, fences
and occupant changes must update the correct mask before it can answer a
query. Compare incremental maintenance cost with the work saved on real maps.

### 2. Share search work for common destinations

[VERIFIED] All **2,185** group searches targeted three bit-identical destinations,
each corresponding to a distinct snapped ground cell. The busiest two targets
accounted for 2,059 calls and 28.63 of 29.60 ms/tick of the group timer. The two
received searches from 16 and 23 distinct starting cells respectively. This is a
stronger reuse opportunity than the finished-route cache's zero valid hits with
global occupancy invalidation.

[VERIFIED] The observed navigation stamp changed in only five consecutive
group-query intervals. The separate fixed-occupancy stamp advanced 119,969
times and stayed equal in only 145 of 2,184 intervals. These are instrumented
stamp increments, so they do not count distinct blockers or prove complete
invalidation. The difference supports testing static corridors with live
clearance checks near each formation.

[VERIFIED] `AIGroup::friend_computeGroundPath` calls the group solver with a
diameter of six and crusher disabled. The current trace groups destination
properties and cannot identify which repeated requests belong to the same
command or formation. Record that identity in the next native shadow before
considering high-level command coalescing.

[INFERRED] Try a goal-centered field or shared corridor for the busiest ground
formation destinations. Start with the fixed navigation edges and separate
footprint rules. Shadow the current engine, logging candidate build time, eligible
cohorts, and per-query live clearance validation cost. A blocked group needs a
local detour or the ordinary solver. The field must account for the formation's
special line edges, layer transitions, and congestion before replacing route
selection. Start with one compatible movement profile. A static field can also be
evaluated as a search-order hint under the existing solver. Route ties and the
legacy solver's cost conventions still require a parity check.

[SOURCED] Elijah Emerson describes shared tile fields and using a portal graph for
long-distance routes in *Supreme Commander 2*. Koenig and Likhachev describe
incremental repair of earlier search work when navigation changes. These are
candidate designs for this workload. [Flow field chapter](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf)
· [D* Lite](https://publications.ri.cmu.edu/d-lite)

### 3. Reduce the cost of failed per-unit searches and fallback

[VERIFIED] Ordinary and closest-reachable paths together cost **14.28 ms/tick**
across 260 unit IDs. There were **477 failed** ordinary fine-grid calls worth
3.88 ms/tick. The five most expensive owners consumed 4.49 ms/tick and each
repeated search from one start cell. Exact repeats keyed by the recorded search
properties and route fingerprint within 15 ticks account for only **0.24 ms/tick**.
The heaviest individual search took 38.80 ms and returned no route. A constant
starting grid cell does not establish that a unit never moved within the cell.

[VERIFIED] Every failed fine-grid search was followed by a same-tick closest
search with the same recorded unit, start, goal and movement policy. The two
passes cost **8.21 ms/tick** and expanded **2.57 million** nodes in total over
the window. The trace pairs records by query properties. It does not count how
many cells the two passes visited in common. The fallback source has its own
candidate scoring and stopping checks.

[INFERRED] Profile the failed search and its actual caller's fallback together.
Measure whether failed exact searches and the fallback revisit the same reachable
region. If they do, reuse terrain or frontier information when the rules match.
Use deterministic retry backoff only for diagnosed unchanged blocked orders,
with a bounded wait and immediate service for new orders or a reopened route.
The current route, weapon state and moving targets need separate checks.

## Acceptance

[INFERRED] Use the same 1080p window with the same graphics settings and inputs.
For candidates intended to preserve behavior, compare route hashes, expansions,
order, and replay sync, with repeated paired timing runs before a release claim.
A route-changing prototype needs deterministic fresh-skirmish comparisons, including
time to movement, successful orders, congestion, and equivalent fight intensity.
Use mean frame time below 33.33 ms to claim above 30 FPS average. Report p95
separately to show whether slow frames still miss that budget.
