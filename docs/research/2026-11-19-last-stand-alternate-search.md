# Alternate pathfinding techniques for Last Stand

- Date: 2026-11-19
- Task: T-112
- Baseline: [30 FPS frame budget](2026-11-19-last-stand-30fps.md)
- Evidence: [local captures and model](../../artifacts/2026-11-19-last-stand-search-overlap/manifest.md)

## Where each technique fits

| Technique | Fit for this replay | First experiment |
|---|---|---|
| Goal-centered shortest-path field over static ground | [INFERRED] Best opportunity to remove formation work. Starts differ, while targets and movement profiles repeat. A field answers many starts from one build. | Build a reverse field for one frequent goal in a snapshot. Time build plus live path validation. Measure rejected routes, chokepoint throughput, and cost versus the current solver. |
| Portal routing with partial refinement | [INFERRED] A lighter option if building a full field costs too much or routes funnel awkwardly. A shared region corridor can guide the local solver. | Reuse the current hierarchy and refine one corridor segment at a time. Keep a full-solver fallback and measure how often live obstacles force it. |
| Landmarks or a terrain-aware A* heuristic | [INFERRED] Could cut expansions in exact and fallback searches that do not share goals. More plausible as guidance than a direct cut-and-paste replacement. | Compare expansion counts on a snapshot while preserving traversal rules. Verify route ties and failure behavior if search order changes. |
| Share collision checks between an exact search and its fallback | [INFERRED] Narrower change with little gameplay risk if the cached facts are independent of search order and include every policy input. | Measure cell overlap and compare memoizing the terrain/occupancy predicates with the current solver. Preserve fallback scoring and stopping behavior. |
| Packed clearance and rejection masks | [INFERRED] Can make each expansion cheaper and combine with the techniques above. The prior synthetic fixture validated the footprint results. | Compare compact terrain flags plus live fixed-occupancy masks against the legacy footprint scan. Include update costs after construction, destruction, movement and load. |
| Budgeted partial paths or choke reservations | [INFERRED] Useful for controlling spikes and congestion after reducing total work. A small reservation window is a possible treatment for formations repeatedly queueing through a narrow passage. | Measure delayed orders, stale job rate, completed movement and per-tick backlog. Reduce work first. |

## Source constraints

[VERIFIED] `Pathfinder::findGroundPath` already calls the hierarchical solver and
uses the resulting region flags in fine search. It penalizes narrow cells and
handles diagonal entry through neighbor flags. Its line callback can insert
successors at half the normal orthogonal move cost. `checkChangeLayers` can
enqueue a connected layer at the parent's existing cost. These are in
`AIPathfind.cpp`; the geometric heuristic is in `PathfindCell::costToGoal`.

[INFERRED] These rules matter for stronger search algorithms. A conventional
octile or landmark bound on a terrain grid must be proven against the effective
edges, including cheap line and layer transitions. A flow field or a different
search order can produce different routes even when each path is valid.
For the first field candidate, compare routes in diagnostic shadow mode.
If routes change, measure a deterministic fresh skirmish for response time,
paths blocked, arrivals and battle progression before treating it as a gameplay
replacement. A snapshot worker can help build a field, with explicit handoff
and stale-result checks. Running the existing solver concurrently is a separate
change to its shared open lists and scratch grid.

[SOURCED] A* with landmarks uses precomputed graph distances and triangle
inequality bounds on directed graphs. Partial-Refinement A* uses an abstract
path to refine and execute a limited segment at a time. [Goldberg and Harrelson](https://www.microsoft.com/en-us/research/publication/computing-the-shortest-path-a-search-meets-graph-theory/)
· [Sturtevant and Buro](https://cdn.aaai.org/AAAI/2005/AAAI05-221.pdf)

[SOURCED] Weighted Jump Point Search prunes symmetries by changing
tie-breaking in its weighted grid. Its proof does not directly cover Zero
Hour's formation, layer, or line-insertion rules. Windowed Hierarchical
Cooperative A* distributes short-horizon space-time planning along routes.
Incremental anytime search can reuse planning work between local cost changes.
[Weighted JPS](https://pathfinding.ai/pdf/cmhse-aaai23-jpsw.pdf)
· [Silver](https://ojs.aaai.org/index.php/AIIDE/article/view/18726)
· [Likhachev et al.](https://publications.ri.cmu.edu/storage/publications/pub_files/pub4/likhachev_maxim_2005_1/likhachev_maxim_2005_1.pdf)

## Shared reverse search model

[VERIFIED] `reverse-field-model.py` feeds 2,185 actual formation requests, in
replay order, to independent A* and a lazy shared reverse Dijkstra search.
The fixture uses invented terrain and symmetric grid costs. It has 122
distinct start/goal/revision combinations and 14 goal/revision fields.
Both methods produced the same minimum cost for every fixture query.
The reverse model also verified each reconstructed route's legal steps and cost.

| Synthetic comparison | Expanded nodes |
|---|---:|
| Independent A* per request | 4,784,341 |
| Lazy reverse fields, rebuilt across fixture revisions | 870,109 |
| A* with perfect reuse of identical requests on immutable fixture terrain | 255,100 |

[INFERRED] A goal field is worth testing on the live map. It may pay an
upfront expansion cost even with repeated requests. Perfect same-start reuse
is cheaper in this fixture, where dynamic occupancy is absent. The original
native results show why the corresponding whole-route cache could not reuse
them under its global occupancy check. The 81.8% reduction against independent
A* describes node counts on the synthetic graph only.

## Can scheduling alone reach 30 FPS?

[VERIFIED] `queue-budget.py` replays the measured cost arrivals and non-search
time for the 300 target frames. The model allows free, arbitrarily fine
preemption and carries every unfinished search millisecond forward. It supplies
an average of **8.43 ms/tick** of usable search time at the 33.33 ms budget.
Measured search arrivals average **44.27 ms/tick**. Fourteen frames already
exceed 33.33 ms due to work outside the timed searches.

| Hypothetical search reductions | Unfinished work after 300 ticks | Modeled p95 wait for completed per-tick work |
|---|---:|---:|
| None | 10,751.6 ms | 236 ticks |
| 80% formation and 70% other | 565.7 ms | 54 ticks |
| 85% formation and 85% other | 0.0 ms | 4 ticks |
| 90% formation and 90% other | 0.0 ms | 2 ticks |

[INFERRED] Scheduling can smooth the remaining work once throughput is high
enough. With today's workload it would postpone a large share of orders, even
with a perfect scheduler. Simulated waits apply to aggregated work that
finished in this interval. Game orders have additional dependencies and
deadlines, so this is a limit on the idea, not a prediction of control latency.

## Search overlap experiment

[VERIFIED] The isolated diagnostic build adds a binary coordinate trace for
formation, exact and closest-reachable searches. It records the full
`(x, y, layer)` of each expansion and joins by existing search ID. The capture
is restricted to the existing 300-tick slow window.

[VERIFIED] The replay reached frame 17,402 with sync active at 1920×1080 and
matched all 15,242 path records in the previous inner-loop run outside
timing. The analyzer checked all 4,335 expansion lists against the counts in
the path census.

| Native result in the slow window | Count |
|---|---:|
| Distinct formation cells visited per search, summed over 2,185 searches | 7,040,438 |
| Previously visited for the same goal and topology stamp | 6,873,754 (97.6%) |
| Previously visited for the same goal and topology stamp within five ticks | 6,834,703 (97.1%) |
| Unit failure/fallback pairs | 477 |
| Unit pairs whose first pass expanded zero cells | 438 |
| Unit pairs with a nonempty intersection | 39 |

[VERIFIED] In the 39 nonempty pairs, 190,866 distinct cell visits overlapped.
Across all 477 pairs this is 41.8% of exact-pass visits and 11.1% of
fallback visits. The 39 pairs together averaged 7.05 ms/tick in the prior
T-112 inner-loop timing run. This is the total work in those pairs. Only the
coordinate sets are shared evidence of reuse opportunity. The trace does
not measure equal traversal decisions, edge validity, or CPU time saved.

[INFERRED] Prototype a lazy reverse field for one dominant goal in an isolated
snapshot first. Compare its build and query work with the observed visits,
and audit live validation near blockers before using its routes. Profile
shared collision and traversability facts in the 39 expensive unit pairs
as a separate optimization. Avoid allocating fallback scratch on early
rejects. Keep instrumented timings outside the speed comparison.
