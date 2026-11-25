# Last Stand pathfinding search census

- Date: 2026-11-19
- Task: T-109
- Evidence: [capture manifest](../../artifacts/2026-11-19-last-stand-path-census/manifest.md)
- Related: [T-107 on-screen reproduction](2026-11-19-last-stand-slowdown.md), [T-108 research](2026-11-19-last-stand-pathfinding-options.md)

## Result

[VERIFIED] Group ground routing is the main search cost. `Pathfinder::findGroundPath` averaged 60.11 ms per simulation tick in the headless version of the 7 FPS window, accounting for 79.71% of the timed search work. The existing hierarchical solver averaged 0.13 ms per tick across all callers. Almost all of the group cost was incurred outside the per-unit path queue.

| Mean exclusive search time per tick | Comparison, frames 15000–15299 | Slow window, frames 16978–17277 |
|---|---:|---:|
| All timed searches | 53.58 ms | 75.41 ms |
| Group ground path, `findGroundPath` | 40.43 ms | 60.11 ms |
| Unit ground path, `internalFindPath` | 8.13 ms | 9.70 ms |
| Closest-path searches | 4.53 ms | 5.19 ms |
| Hierarchical search across all callers | 0.18 ms | 0.13 ms |
| Searches outside the per-unit queue, all types | 40.54 ms | 60.19 ms |

[VERIFIED] In the slow window, 2,185 group searches ran across 300 ticks. The shadow comparison found 778 later searches with the same start and goal cells, layers, observed navigation revision, and full-path fingerprint as the latest preceding query in the matching bucket. Those searches averaged 19.08 ms per tick, or 25.30% of total measured search time. All 778 recurred after three or four logic ticks, with 644 at three and 134 at four. The comparison window covered 699 such hits at 12.00 ms per tick (22.39%). Both windows had zero full-path matches in the same tick or within one tick.

[VERIFIED] Broader fingerprint agreement exposes additional research opportunities. In the slow window, the one-cell keys with a matching 16-cell corridor fingerprint covered 29.51 ms per tick, including the full-path matches. The two-null group outcome bucket covered 5.85 ms per tick. For identified individual units, repeats with the same start and goal cells and observed revision accounted for 6.70 ms per tick. The repeated requests whose unit was marked blocked accounted for 0.08 ms per tick even without requiring the same revision. These categories can overlap. The queue's scope-weighted p95 age was 20 ticks, about 0.67 seconds at the nominal simulation rate.

[INFERRED] These measurements prioritize the group ground search ahead of the generic unit retry throttle, a lower FIFO budget, or caching the existing coarse search alone. The hot repeated group calls returned routes. The capture does not establish which scripts repeatedly issued the commands or whether individual armies were stationary.

## First prototype

[INFERRED] Prototype short-lived reuse at the group-ground solver boundary with a four- or five-tick lifetime. Begin with exact directional inputs, including the unsnapped positions, movement layer, formation width and crusher policy. Keep the solver in charge while testing a conservative validity guard against the already observed three- and four-tick recurrence. Track cost-weighted eligible coverage after the guard, together with guard cost. The reported 19.08 ms is the gross time in later matching searches in the headless trace. Effective reuse and FPS gains require a runtime prototype.

[VERIFIED] The sole call site in the inspected Zero Hour source is `AIGroup::friend_computeGroundPath`, reached by `groupMoveToPosition`. It uses a six-cell clearance width. `clearCellForDiameter` in `AIPathfind.cpp` reads terrain and fixed unit occupancy and can consult a blocking object's crushability. The observed zone-dirty revision therefore does not cover all inputs to the fine search. `findGroundPath` also changes region passability and performs search cleanup. Those effects are part of the compatibility check.

[INFERRED] A reuse guard needs fixed-unit occupancy and topology validity, not merely a matching route fingerprint. Checking only cells on the returned route can miss a newly opened alternative. Start by measuring an intentionally conservative local revision or a versioned read set, and require exact output and downstream state agreement in the shadow experiment. Keep failures on the existing path. If churn makes across-tick reuse ineffective, profile and memoize repeated clearance checks within a single synchronous group search instead. That alternative retains the existing open list, path selection, and request cadence. Verify repeated input cells, return values, and invalidation during recovery before enabling it.

[INFERRED] Validate the winner with alternating 1080p runs around the T-107 window. Compare full path output and periodic CRCs for a behavior-preserving candidate, plus command-to-movement latency, queue age, and frame-time tails. Include a fixed blocking unit that moves, a changing wall or bridge, and a search returning no path. For a candidate that changes behavior, run a separate paired skirmish with identical seeds and scripted commands.

## Method and scope

[VERIFIED] The isolated capture built with zero errors and used the same ShockWave archive scripts and skirmish guard and heap policies as the T-107 diagnostic build. The headless replay exited 0 at the explicit frame-17402 checkpoint with sync checks enabled. The capture contains 80,049 search scopes across frames 14700–17400. The two analysis windows each contain all 300 requested logic frames. The slow window corresponds to T-107 visual frames 16979–17278 by the pre-increment offset. The census ran headlessly. The added instrumentation's absolute timing overhead remains unmeasured.

[VERIFIED] Nested timings were charged once by subtracting child scope times from their parent. Queue attribution describes execution inside the dispatcher and can include an induced search for a different actor. Group searches lack a unit ID, so the reuse counts identify matching queries without identifying the groups that issued them. The shadow model keeps the latest result per directional key and compares it to the next independently computed result. Its one-cell keys use snapped coordinates. It groups by layers, movement policy, player where available, and the observed revision. Its 16-cell corridor hash records the ordered sequence of distinct region/layer steps along returned path nodes. A real cache requires independent runtime validity checks.

[VERIFIED] Run `python analyze-path-census.py searches.csv --ttl 90` inside the artifact directory. The parser checks scope relationships, timing reconciliation and complete windows. The bounded replay, source diff, sensitivity runs from zero to 90 ticks, and exact hashes are retained in the manifest. The shipped ShockWave test executable still hashes to `76099735FEDB1331E88700C257FC7A3A572518DADCCD24C7FC9E9FC2C5BEFA17`. This was an instrumentation-only study.
