# External pathfinding research: community, papers, and reusable options

- Date: 2026-11-20
- Task: T-113
- Scope: external techniques, upstream engine work, and community reports that
  can help the Last Stand group-pathfinding problem.
- No game run was made for this note.

## Problem signature

The target workload is not a generic grid search:

- 350x200 grid, 8-neighbour movement, width-6 group clearance.
- Dynamic friendly/enemy blockers and a limited pathfinding cell pool.
- 2,185 formation orders in 300 ticks, 21.8x straight-line exploration
  (p95 62.1x), 41.8% unit-search re-expansion.
- The diagnostic replay is **retail-compatible by design** to preserve sync.
- The live user scenario is singleplayer, where the T-022 heap and other
  non-retail singleplayer paths are allowed.

That last point matters: the replay is deliberately a worst case, not
necessarily the live frame rate.

## Community and upstream findings

| Source | Finding | Status / what we can reuse |
|---|---|---|
| [TheSuperHackers issue #100](https://github.com/TheSuperHackers/GeneralsGameCode/issues/100) | AI pathfinding lag on large maps: units pile on cliffs/obstacles; retail allocates only **30k pathfinding resources**; failed searches retry and compound the lag. Mauller's per-cell allocation fix removes the lockups (non-retail), but paths remain expensive. Skyaero reports a heap/skip-list can give **>25% late-game** pathfinding gain. | Still the core pathology. Our source has the per-cell allocation switch (`RETAIL_COMPATIBLE_PATHFINDING_ALLOCATION`) and the 2026 open-list work, but the **retail-compatible path** used by replay diagnostics still has the 30k pool and the List. |
| [PR #2140](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2140) | Late-game unit lockups and erroneous impassable terrain from `PathfindCell` pool exhaustion; per-cell obstacle data; merged 2026-01-22. | [VERIFIED] The pinned source contains `RETAIL_COMPATIBLE_PATHFINDING_ALLOCATION` and the obstacle-data path. The retail build keeps the 30k pool; the non-retail path is the interesting live-singleplayer lever. |
| [PR #3198](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3198) | Pathfinding micro-optimizations: O(1) path append (**-3.1%** pathfinding CPU), loop-invariant parent position and cached `isCrusher` (**-1.2%**). Tested against 1,500 ZH replays. | [VERIFIED] Already present in our pinned source: no `appendToList`; `Path.cpp` appends through `m_pathTail`. No cherry-pick needed. |
| Local source comment, `PathfindCell.cpp` | Reverse insertion sort for long/complex paths; comment claims **50-66%** less pathfinding overhead for those insertions. | [VERIFIED] Present in the pinned source. The remaining Last Stand cost is therefore not open-list insertion alone. |
| [Issue #2048](https://github.com/TheSuperHackers/GeneralsGameCode/issues/2048) | Multi-threading/performance roadmap: job system, parallel pathfinding, HPA*, data-oriented design, GPU flow fields. | Proposal, not merged. Useful direction; our worker track already showed that per-query snapshots are the hard part. |
| [Issue #2293](https://github.com/TheSuperHackers/GeneralsGameCode/issues/2293) | Pathfinding changes caused retail CRC mismatches. | Confirms our replay-parity gate. Any behavior-changing pathfinding work must be singleplayer/fresh-skirmish gated. |
| [Community v1.0 reports](https://www.reddit.com/r/generals/comments/szeucf/cc_generals_zero_hour_lag_problem_new_discoveries/) | Players report v1.0 handles cliffs/large maps better than 1.04; the common “downgrade to v1.0” fix exists. | Anecdotal but relevant. The pre-patch `.bak` binary may be v1.0; version and a stock-map A/B are unverified. This is a root-cause lead, not a confirmed fix. |
| [OpenSAGE](https://github.com/OpenSAGE/OpenSAGE) | SAGE reimplementation; pathfinding is still in progress. | No optimized implementation to borrow. Useful for format/behavior reference only. |

### The important consequence

[INFERRED] Our replay diagnostics set `ZH_PROFILE_MATCH_HEAP=1` and use the
retail-compatible path to match the recording. That path has the **30k
pathfinding pool** and the **O(n) List**. The user's live singleplayer game
uses the T-022 heap and can use the non-retail allocation. The measured
21.95 FPS and the 556 failed formation searches may therefore be
**pessimistic** for live play, and some of the “failed search” cost may be
retail pool exhaustion rather than A* waste. This should be measured before
more replay-only tuning.

## Techniques and papers

| Technique | Why it fits (or not) | Route effect | Existing reuse |
|---|---|---|---|
| **Flow fields** ([HowToRTS](https://howtorts.github.io/2014/01/04/basic-flow-fields.html), [Game AI Pro](http://www.gameaipro.com/), Supreme Commander 2 / Planetary Annihilation) | Many units to shared destinations; one field per goal, O(grid) generation, cheap per-unit lookup. The Last Stand has 122 distinct requests and 777 exact repeats among 2,185 orders. | Changes paths | `GroupFieldShadow` / `GroupRouteShadow` is already a reverse goal field; promote it |
| **D* Lite / LPA*** ([Koenig & Likhachev 2002](https://aaai.org/Papers/AAAI/2002/AAAI02-072.pdf)) | Incremental replanning when blockers change; avoids re-searching from scratch. | Changes paths | `GroupFieldShadow` live repair is a simplified version; formalize the repair |
| **HPA*** ([Botea et al. 2004](http://webdocs.cs.ualberta.ca/~mmueller/ps/2004/hpastar.pdf)) | Hierarchical search; paper reports up to **10x** faster near-optimal paths. The engine already has a zone hierarchy (`internal_findHierarchicalPath`) and a failed-hierarchy fallback. | Changes paths | Existing zone manager + hierarchy; upstream roadmap #2048 |
| **HAA*** ([Harabor & Botea 2008](https://harabor.net/data/papers/harabor-botea-cig08.pdf)) | Hierarchical annotated A* for different unit sizes/terrain capabilities; directly relevant to width-6 clearance. | Changes paths | New, but aligns with the `clearCellForDiameter`/zone model |
| **Anytime / ARA* / bounded suboptimal A*** | Return a usable path under a time budget, improve later. The naive effort cap lost 310 of 1,629 successful formation routes; an anytime fallback with repair is safer. | Changes paths / timing | New; the existing hierarchical fallback and open-list budget are the starting point |
| **Route/plan reuse** (local T-110/T-112) | 777 exact route repeats worth 5.99 ms/tick offline; the strict native guard only captured 0.19 ms/tick. | Route-preserving if exact | `GroupCacheProbe.inc`, `RouteGuard.inc`, `review-guard.py` |
| **Clearance-map preprocessing** | Precompute width/clearance/connected components/portals; avoid per-search clearance checks. | Usually route-preserving | `GroupClearanceMemo` (T-111) is the first step; `Grid` in `GroupRouteShadow` |
| **Parallel / GPU pathfinding** | Upstream roadmap; our four-worker track was parked because page snapshot/validation cost exceeded covered solver work. A shared read-only grid or field is the prerequisite. | None if parallel compute is deterministic | `SpeculativeWorkers.h`, page snapshots; not first |
| **JPS / JPS+** | Symmetry pruning assumes uniform costs; the engine has line insertion, turn costs, layers and dynamic blockers. | Changes paths | Not recommended (already noted in T-113) |
| **Theta* / any-angle** | Smoother paths with fewer waypoints; the engine already does line-of-sight optimization and the cost is search, not waypoint count. | Changes paths | Low priority |
| **Steering / local avoidance** ([Game Developer group movement](https://www.gamedeveloper.com/programming/group-pathfinding-movement-in-rts-style-games), StarCraft 2 navmesh+steering) | Good for group feel and traffic jams; does not solve the 70.5% search cost. | Changes movement | Existing unit steering/collision; not the first lever |
| **MAPF / CBS / ORCA** | Multi-agent optimality/avoidance is far heavier than RTS needs; not the bottleneck. | Changes movement | Not recommended |

## Ranked recommendations

1. **Measure the live/default path in a fresh skirmish.** Use the T-022 heap,
   T-111 memo, and the non-retail `RETAIL_COMPATIBLE_PATHFINDING_ALLOCATION`
   path. This can show whether the replay’s 21.95 FPS is a retail-compat
   worst case. No new algorithm. (Defer any game run while the PC is in use.)
2. **Promote the non-retail pathfinding allocation as a portable
   singleplayer option.** The code already exists from #2140; the question is
   whether the 30k pool exhaustion and the 108 long failed formation searches
   disappear, and what they cost. Replay/network stays retail-compatible.
3. **Promote the group field/flow field + D* Lite-style repair.**
   `GroupFieldShadow` already modeled 19.71 FPS at width 2 and repaired 1,057
   routes. This is the best algorithmic reuse; route changes require the
   fresh-skirmish protocol.
4. **Try HPA*/HAA* on the existing zone hierarchy.** The paper-level 10x
   reduction and the upstream roadmap make this the strongest “new algorithm”
   candidate, but it is a larger change than the field promotion.
5. **Scenario design:** copy the map, stagger the GLA approach waves, widen a
   few lanes. Quickest experiment; no engine code; the exact order origin is
   already known from T-113.
6. **Improve the route guard** to mirror `validMovementPosition`; unlock the
   T-110/T-112 cache prize (5.99 ms/tick offline).
7. **Investigate v1.0 vs 1.04** on a stock map with a stock replay/scenario.
   The community reports a cliff/pathfinding difference; the pre-patch `.bak`
   binary may be v1.0. This is a root-cause lead, not a confirmed fix.

## What not to do first

- Do not replace the search with textbook A*: the model expanded 18.8% more
  cells and matched 0/1,633 optimized routes.
- Do not use a naive effort cap: it lost 310 of 1,629 successful formation
  routes.
- Do not start with JPS or GPU/parallel pathfinding: dynamic clearance/turn
  costs and the parked worker snapshot cost make them poor first bets.
- Do not chase the renderer/INI loader for this window: drawing is 11.5 ms vs
  98.45 ms pathfinding.

## Limitations

- Community reports are anecdotal; the v1.0/1.04 difference and the `.bak`
  version are unverified.
- The upstream PRs are merged into a different revision; our pinned source is
  from 2026-11-09 and already contains #2140/#3198-style code, but exact
  binary equivalence is not claimed.
- The replay is a retail-compatible diagnostic, not live play; the fresh
  skirmish is the correct acceptance environment.
- No game run was made for this note.

## Live/default and non-retail result (added 2026-11-20)

[VERIFIED] The fresh 8-player Last Stand skirmish (human idle, UI-started from
`Skirmish.ini`) ran for 10 minutes per arm. Both arms had ~26.6k in-game logic
rows; the human idle means the skirmish ends early and the tail is the menu.

| Metric | Retail allocation | Non-retail allocation |
|---|---:|---:|
| Frame interval mean | 8.878 ms | **8.143 ms** |
| Perf p99 | 30.658 ms | **15.954 ms** |
| Frames >33 ms | 674 | **124** |
| Path requests | 37,537 | **21,723** |
| Path expansions | 12,155,658 | **2,628,136** |
| Path search time | 27.46 s | **6.84 s** |
| `l_ai` mean | 0.229 ms | **0.064 ms** |

[VERIFIED] The non-retail build did 75% less live pathfinding work and cut the
p99 tail by 48% in this AI-only skirmish.

[VERIFIED] This is a behavior-changing A/B; the AI/game state diverges. The
human is idle, so the T-107 human-driven GLA-approach stress (2,185 formation
orders/300 ticks) was not measured. The live AI-only run is ~112 FPS, not the
replay's 22 FPS; the missing input is the human/GLA-approach workload.

[INFERRED] The non-retail per-cell allocation is a promising opt-in
singleplayer candidate, but it needs a played fresh-skirmish stress test before
any 30 FPS claim. Replay/network remains on the retail path.

[VERIFIED] The synthetic `ZH_STRESS` 1,000-tank scenes are collision-bound
(`l_partition` 36-43 ms, 0 path expansions) and do not validate the allocation.

## Source list

- [TheSuperHackers issue #100](https://github.com/TheSuperHackers/GeneralsGameCode/issues/100)
- [PR #2140](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2140)
- [PR #3198](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3198)
- [Issue #2048](https://github.com/TheSuperHackers/GeneralsGameCode/issues/2048)
- [Issue #1984](https://github.com/TheSuperHackers/GeneralsGameCode/issues/1984)
- [OpenSAGE](https://github.com/OpenSAGE/OpenSAGE)
- [HowToRTS: Basic Flow Fields](https://howtorts.github.io/2014/01/04/basic-flow-fields.html)
- [D* Lite, Koenig & Likhachev 2002](https://aaai.org/Papers/AAAI/2002/AAAI02-072.pdf)
- [HPA*, Botea et al. 2004](http://webdocs.cs.ualberta.ca/~mmueller/ps/2004/hpastar.pdf)
- [HAA*, Harabor & Botea 2008](https://harabor.net/data/papers/harabor-botea-cig08.pdf)
- [Game Developer: Group Pathfinding & Movement in RTS Style Games](https://www.gamedeveloper.com/programming/group-pathfinding-movement-in-rts-style-games)
- [Community v1.0 lag thread](https://www.reddit.com/r/generals/comments/szeucf/cc_generals_zero_hour_lag_problem_new_discoveries/)
