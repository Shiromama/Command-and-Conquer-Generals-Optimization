# Is the pathfinding algorithm itself the remaining limit?

- Date: 2026-11-20
- Task: T-113 (opened from T-112)
- Baseline: 21.95 FPS / 45.568 ms, 12.235 ms above the 30 FPS budget
- Evidence: [T-112 expansion trace](../../artifacts/2026-11-19-last-stand-search-overlap/manifest.md),
  [T-113 expansion analysis](../../artifacts/2026-11-20-last-stand-algorithm-limit/manifest.md),
  `AIPathfind.cpp`, `PathfindCell.cpp`
- Question: is the remaining gap dominated by the search algorithm, not by
  per-search cost or request duplication?

## Answer

[VERIFIED] The search is not standard A*. It uses a geometric heuristic that
overestimates diagonal moves, adds turn costs that the heuristic ignores,
inserts half-cost line-of-sight successors on every expansion, and reopens
closed cells when that line finds a cheaper `g`. In the measured window,
**41.8% of unit-search pops are re-expansions of a cell already popped**.
Successful formation searches pop 15-60x the straight-line distance, and the
largest failed formation searches each pop more than 11,000 cells.

[INFERRED] The evidence supports the hypothesis. Request-level reuse remains
useful, but it treats a symptom: the algorithm asks for and repeats far more
work than a standard goal-directed search would. The per-pop cost is also not
a hardware floor (743-1,100 ns), so there is room above the inner loop.

## What the algorithm actually does

[VERIFIED] Source facts in `AIPathfind.cpp` / `PathfindCell.cpp`:

| Rule | Implementation |
|---|---|
| Heuristic | `10*max(dx,dy) + 5*min(dx,dy)` (`PathfindCell::costToGoal`) |
| True octile cost | `10*max + 4*min` with `COST_DIAGONAL=14`; the heuristic overestimates by `min` |
| Turn cost | `g` adds 4/8/16 for 45/90/135-degree turns; `h` ignores turns |
| Line insertion | Every expansion scans the line to the goal; each cell enters at parent cost + 5 (`0.5*COST_ORTHOGONAL`) |
| Reopen | The line callback removes a closed cell from the closed list and reinserts it when the line is cheaper |
| Layer change | `checkChangeLayers` inserts a connected layer at the parent cost |
| Hierarchical fallback | If the coarse path fails, all zones are marked passable and the fine search runs anyway |

[INFERRED] The line insertion is a deliberate shortcut, but it breaks the
closed-set invariant. The exact search reopens cells constantly; the group
search reopens less because its width-6 line is usually blocked early.

## Cost per popped cell

[VERIFIED] The earlier note that the inner loop costs "about 2.5 ns" per
expansion was unit confusion: 17.708 ms/tick divided by 7,148,775 total pops
over 300 ticks. Per tick the cost is far higher:

| Search | Traced searches | Pops | Pops/tick | ms/tick | ns/pop |
|---|---:|---:|---:|---:|---:|
| Formation | 2,185 | 7,148,775 | 23,829 | 17.708 | **743** |
| Unit exact | 1,522 | 1,945,147 | 6,484 | 7.131 | **1,100** |
| Closest | 628 | 1,933,500 | 6,445 | 3.659 | **568** |
| All | 4,335 | 11,027,422 | 36,758 | 28.498 | 775 |

The pops are counted from the T-112 overlap trace; the clocks are the
current GTX operation budget. The exact trace covers the detailed searches,
not all 2,515 census unit searches.

## Finding 1: unit searches re-expand 42% of their pops

[VERIFIED]

| Unit exact | Searches | Pops | Distinct | Duplicate pops | Share |
|---|---:|---:|---:|---:|---:|
| Returned a route | 1,045 | 1,168,346 | — | 493,349 | 42.2% |
| Returned null | 477 | 776,801 | — | 320,336 | 41.2% |
| Total | 1,522 | 1,945,147 | 1,131,462 | 813,685 | **41.8%** |

The worst failed search popped 24,153 cells but visited only 11,847 distinct
cells: 12,306 re-expansions in one search. The worst successful search is
similar in character.

[INFERRED] If duplicate pops cost the average, they account for about
**2.98 ms/tick** of the 7.131 ms unit budget. That is an upper bound: a
consistent heuristic would avoid the reopens but could expand more distinct
cells. It is still the largest single algorithmic waste found so far.

### Offline no-reopen fixture

[VERIFIED] A deterministic 48x48 fixture with walls, pinches, obstacles and
allies ran 4,000 random queries through three independent `GroundSearch.h`
workspaces. The legacy kernel popped 940,065 cells and reopened 198,071. The
no-reopen variant popped 742,128 and reopened none: **21.1% fewer pops**, all
4,000 routes still found, 88.5% byte-identical routes, 98.5% equal goal costs,
5 lower and 54 higher (1.35%). A consistent-heuristic-only variant still
reopened 195,448 cells, because the line edge costs 5 while the heuristic step
is 10/14; it expanded 0.25% more than legacy.

[INFERRED] The line callback, not the heuristic, is the reopen source. The
no-reopen mode is the cheap first algorithm experiment; the 11.5% route
divergence and 1.35% higher-cost routes need the route-changing acceptance
protocol. [Fixture](../../artifacts/2026-11-20-last-stand-no-reopen/manifest.md)

## Finding 2: formation searches explore 15-60x the straight-line distance

[VERIFIED] For 2,185 formation searches:

| Metric | Mean | p50 | p95 | Max |
|---|---:|---:|---:|---:|
| Popped cells | 3,272 | 1,400 | 11,208 | 11,679 |
| Pops / Chebyshev distance | 21.8 | 15.2 | 62.1 | 68.3 |
| Bounding-box cells | 9,941 | 5,796 | 28,371 | 31,752 |
| Duplicate pops | 49.6 | 10 | 208 | 336 |

The p95 bounding box is 40.5% of the 350x200 map for one query. Only 1.5% of
formation pops are duplicates, so the cost is not reopens; it is the width-6
clearance search exploring a wide region, with the line-shortcut edges and
the turn costs steering it.

[INFERRED] A goal-directed search on this grid should not need 40% of the map
for a 187-cell query. This is the clearest evidence that a different search
algorithm or a shared clearance field could beat constant-factor tuning.

## Finding 3: the long failed formation searches are not cap-friendly

[VERIFIED] Of 556 failed formation searches, 448 expand zero cells (early
rejects). The other 108 each pop more than 8,192 cells, totalling 1,231,743
pops, about **3.05 ms/tick** at the measured per-pop cost. They all exhaust a
large region after the hierarchical path fails and `setAllPassable()` removes
the zone restriction.

[VERIFIED] A naive effort cap cannot separate them from successes:

| Cap | Successful formation routes lost | Failure pops saved |
|---:|---:|---:|
| 8,192 | 310 of 1,629 | 1,231,743 |
| 12,288 | 0 | 0 |

The long failures and the long successes overlap. A fail-fast cap is rejected
until a better reachability test exists.

## What this does and does not prove

- [VERIFIED] The algorithm's own edge/cost rules create the 42% unit
  re-expansion waste and the 15-60x formation exploration.
- [VERIFIED] Per-pop cost is 568-1,100 ns, not a hardware floor.
- [INFERRED] A standard or consistent search could remove a large part of
  this waste, but it would change routes. The current route-parity gate
  cannot certify such a candidate.
- [UNKNOWN] How much of the 15-60x exploration is inherent to width-6
  clearance in a crowded battle versus created by the line/turn rules.
  A standard-A* shadow on the same inputs would answer this.

## Alternatives

| Technique | What it changes | Expected effect | Route parity | First test |
|---|---|---|---|---|
| No-reopen / consistent exact search | Closed set is final; line callback cannot reopen | Up to ~3 ms/tick of unit work | Changes ties and detours | Shadow the exact search, compare pops and routes |
| Correct octile heuristic | `10*max + 4*min`, optionally turn-aware | Fewer reopens; may expand more distinct cells | Changes routes | Same shadow, measure net pops |
| Standard A* without line insertion | Remove half-cost line edges | Clean search; unknown net | Changes routes | Formation shadow on recorded inputs |
| Clearance-aware goal field + D* Lite | Shared width-6 field per destination, local repair | Removes repeated formation search | Changes routes | Reuse the T-112 field/repair artifacts |
| HPA* / partial refinement | Coarse zones, refine one corridor | Lower fine-grid expansions | Changes routes | Use the existing 10-cell zones |
| Subgoal graphs | Static guard/connection graph | Large symmetry cut | Changes routes | Offline prototype |
| JPS / JPS+ | Symmetry pruning | Not compatible with line, layer and turn edges | — | Not recommended |
| Request-level memo | Exact repeated routes | 5.99 ms/tick offline; the native guard captured only 0.19 ms/tick | Exact for 777 hashes, but the strict guard rejects most | Deprioritized |

## Recommended order

1. **The route-guard measurement is complete.** The strict diameter-6 cell
   guard captured only 154-181 exact routes (0.16-0.19 ms/tick) and rejected
   596-623 exact routes. The conservative route cache is deprioritized.
2. **No-reopen native shadow.** The offline fixture already passes: 21.1%
   fewer pops, all routes found, 88.5% route-equal and 98.5% cost-equal.
   Run the existing frozen-worker adapter and compare routes, expansions
   and receipts.
3. **Standard-A* formation shadow.** On the same native inputs, run a search
   without line insertion and with a consistent heuristic; compare pops,
   route length and route divergence. This answers whether the 15-60x
   exploration is algorithmic or inherent to width-6 clearance.
4. **Only then choose the behavior-change branch**: clearance-aware field /
   D* Lite or HPA* for formation, under the fresh-skirmish acceptance
   protocol.

## Existing pieces to reuse

| Proposal | Already in the repository | Still to build |
|---|---|---|
| No-reopen unit search | `GroundSearch.h` is a standalone copy of the legacy unit A* with an explicit `closed` flag and the same line-reopen at line 303. It already has 512 fixture cases, the frozen-worker native adapter, page snapshots and route/receipt comparison. `analyze-expansions.py` measures the baseline. The offline variant and fixture are built: 21.1% fewer pops, 88.5% route-equal, 98.5% cost-equal. | A native shadow through the existing frozen-worker adapter; route-divergence decision. |
| Standard A* / cleaner formation | `GroupFieldShadow.inc` / `GroupRouteShadow.inc` implement a reverse goal field with live repair. Native shadows measured width-6 coverage (116/1,633), width-2 repair (1,057 routes) and a modeled 19.71 FPS at width two. `reverse-field-model.py` modeled an 81.8% node cut. `GroupClearanceMemo` is integrated. | A width-6 standard-A* variant without line insertion, or promotion of the field/repair path under the fresh-skirmish protocol. |
| Route cache | T-110 `GroupCacheProbe.inc`; T-112 offline sizing (777 exact / 5.99 ms/tick); compiled `RouteGuard.inc`, `run-guard.ps1`, `review-guard.py`; the native guard run is complete: 181 exact captures, 53 false positives and 596 exact routes rejected at skip 8. The strict cell-center guard is too conservative. | A guard that mirrors the search's `validMovementPosition` or accepts a narrower width; otherwise the conservative route cache is deprioritized. |

[VERIFIED] Do not repeat these: the whole-route cache with a global occupancy
guard returned zero hits; the T-022 stable heap is already the singleplayer
default (12.9% less pathfinding in its congested fixture); the T-111 group
clearance memo is integrated; a naive effort cap loses 310 of 1,629
successful formation routes.

## Acceptance

[INFERRED] Behavior-preserving candidates still need route hashes, expansion
order, command order and replay sync. Route-changing candidates need the
deterministic fresh-skirmish comparison already defined in the 30 FPS plan:
time to movement, completed orders, congestion and fight intensity. A
search-algorithm change must not be certified by frame time alone.

## Limitations

- One replay window and one map.
- The expansion counts come from the inner-loop candidate run, not the
  current GTX stack. They are structural counts; the per-pop clocks come from
  the GTX operation budget.
- The exact trace covers 1,522 of 2,515 census unit searches.
- Duplicate pops may be necessary for the current non-standard cost model;
  removing them changes routes.
- No native run was performed for this note. No game process was started.

## Correction

[VERIFIED] The earlier T-112 note "the measured per-expansion cost is about
2.5 ns" divided 300 ticks of work by the total pops. The per-tick cost is 743
ns for formation, 1,100 ns for unit exact and 568 ns for closest. The
maintained-width report and the work log are corrected accordingly.

## Native no-reopen shadow (added 2026-11-20)

[VERIFIED] The no-reopen kernel ran as a native frozen-input shadow over the
same GTX Last Stand window. It submitted 676 searches; 644 were covered by the
worker kernel and 32 stayed with the original solver. The authoritative replay
reached frame 17,402 with `sync=ok`, and all 15,242 searches, 2,185 commands and
the ordered script tail match the verified reference exactly.

| Metric | Legacy | No reopen |
|---|---:|---:|
| Expanded cells | 696,330 | 401,546 (**-42.33%**) |
| Searches expanding fewer | — | 323 |
| Searches expanding the same | — | 318 |
| Searches expanding more | — | 3 |
| Route hash equal | — | 351/644 (54.5%) |
| Goal cost equal | — | 556/644 (86.3%) |
| Goal cost higher | — | 74 (11.5%) |

[VERIFIED] All 644 covered searches reported zero reopens. The 42.33% pop
reduction is consistent with the 41.8% duplicate-pop share in the expansion
trace and confirms that the line callback is the dominant reopen source on this
window.

[VERIFIED] The earlier "No native run was performed for this note" limitation
is superseded for the no-reopen unit kernel by this shadow; the formation
algorithm remains unmeasured natively.

[INFERRED] The no-reopen kernel is a real algorithmic lever, but 45.5% of
routes and 11.5% of goal costs change. It cannot pass the exact-route gate; it
is a candidate only for the fresh-skirmish acceptance protocol. The
standard-A* formation shadow is the remaining algorithm test. See the
[native shadow manifest](../../artifacts/2026-11-20-last-stand-no-reopen-native/manifest.md).

## Standard-A* formation shadow (added 2026-11-20)

[VERIFIED] A standard A* shadow (consistent octile heuristic, closed set
final, no line insertion) ran beside the reverse-field probe on the same live
formation queries. It covered 1,737 of the 2,185 field queries: 1,633 reached
the goal and 104 were unreachable. The authoritative replay still reached
frame 17,402 with `sync=ok`; all 15,242 searches, 2,185 commands and the
ordered script tail match the verified reference.

| Metric | Legacy | Standard A* | Delta |
|---|---:|---:|---:|
| Expanded cells (1,633 reached) | 7,139,913 | 8,479,758 | **+18.8%** |
| Searches expanding fewer | — | 17 | — |
| Searches expanding more | — | 1,616 | — |
| Route length, 1,525 comparable | 256,698.4 | 231,240.5 | **-9.9%** |
| Routes shorter / longer | — | 1,449 / 76 | — |
| Matching optimized nodes | — | 0 / 1,633 | 0% |

[VERIFIED] The standard search finds shorter geometric routes (median length
ratio 0.888) but expands more cells on the model grid. No route has an exact
optimized-node match to the original.

[INFERRED] This model does **not** support the hypothesis that removing line
insertion and using a consistent heuristic reduces formation search work. The
original line shortcut and overestimating `10*max + 5*min` heuristic are doing
useful goal-directed pruning on this grid, at the cost of longer routes. The
next step is either a faithful cell-cost A* (turn and line costs on the actual
`PathfindCell` grid) or the clearance-field/D* Lite branch, not a wholesale
replacement based on pop counts alone. See the
[standard-A* manifest](../../artifacts/2026-11-20-last-stand-standard-astar/manifest.md).

[VERIFIED] Model limitation: the A* expanded count is a pop count on the field
probe's clearance/occupancy grid, while `legacy_expansions` is the engine's
counter; the two are structural, not a like-for-like timing comparison.
