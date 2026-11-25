# Repeated script move commands in Last Stand

- Date: 2026-11-19
- Task: T-112
- Related: [live repair shadow](2026-11-19-last-stand-live-field.md)
- Evidence: [formation command and unit-footprint replay pair](../../artifacts/2026-11-19-last-stand-unit-footprint/manifest.md)

## Command census

[VERIFIED] The first replay reached frame 17,402 at 1920×1080 with sync
active. All path records matched the preceding live-field replay outside
timing. The command analyzer joined 2,185 receipts to their formation
solver records by tick, exact origin and destination coordinates, and
returned result.

| Observed in 300 slow-window ticks | Count |
|---|---:|
| Formation searches originating from scripts | 2,185 |
| Distinct transient group IDs | 2,185 |
| Distinct ordered membership hashes | 31 |
| Searches with zero members reported moving by `AIUpdateInterface::isMoving` | 2,185 |
| Repeated members and destination within five ticks, regardless of group ID | 2,152 |
| Repeated members, destination, leader and bit-identical start within five ticks | 2,017 |

[VERIFIED] In that run the exact-start repeats cost **22.65 ms/tick**.
The membership-and-destination tier cost **23.61 ms/tick**. A same-group-ID
test finds no repeats. The logged `isMoving` value reflects the AI's
current locomotor state, and is not an independent measurement of physical
movement. It returns false for an idle AI, and otherwise checks the
locomotor goal and move flag.

[VERIFIED] Only 1,279 of the 2,017 exact-input repeats also matched the
previous route fingerprint and return status. Of those, 808 returned a
path and accounted for **7.76 ms/tick**. None of the exact-input repeats
matched the previous global fixed-occupancy stamp. The full 22.65 ms/tick
of repeat work is an opportunity to investigate. A cache keyed only on
the repeated command would return different results in this replay.

[VERIFIED] Several movement actions in `ScriptActions.cpp` create an
AIGroup, populate it with the team's members, and call
`groupMoveToPosition(..., CMD_FROM_SCRIPT)`. This explains why unique
group IDs are compatible with repeated orders for the same membership.
The census records command source, with no script ID or action call-site
tag, so it does not identify which script repeatedly issued the order.

[INFERRED] Reducing repeated route work at this origin deserves priority.
Suppressing a move outright could change how quickly the groups resume
after a blocker moves. A local fixed-blocker comparison is prepared to
measure how often the exact footprint inputs remain stable despite global
occupancy counters changing. It compares a bit vector over the previous
query's width-check rectangle with the current live cells, then checks
against the original route fingerprint. The rectangle is a conservative
superset for this predicate. Terrain, layer and allocator behavior require
separate checks before a route can be reused.

[INFERRED] This workload overlaps the repaired-field candidate. Do not
add both savings estimates together without assigning each request to a
single route method. The [local occupancy experiment](../../artifacts/2026-11-19-last-stand-local-occupancy/manifest.md)
keeps the original solver active.

## Paired unit-footprint timing

[VERIFIED] The same executable ran the shortcut on first, then off.
Both launches reached frame 17,402 with sync active at 1920×1080.
The graphics options hash matched. All 15,242 search records matched
outside clocks and all 2,185 formation command receipts matched.

| 300-frame slow window | Control | Unit footprint shortcut |
|---|---:|---:|
| Mean FPS | 15.76 | 15.73 |
| p95 frame time | 88.99 ms | 86.89 ms |
| Ordinary unit path plus closest-reachable search per tick | 14.12 ms | 11.88 ms |
| Group search census per tick | 23.31 ms | 24.07 ms |
| Draw per frame | 8.75 ms | 9.56 ms |

[VERIFIED] The targeted unit timers fell by **2.23 ms/tick**. This pair
shows no practical average FPS gain. Group and draw timings moved in
the opposite direction. The footprint shortcut remains diagnostic.

## Parallelism budget

[VERIFIED] The target machine has four physical cores and eight
threads. The legacy pathfinder uses one mutable set of open and closed
lists and cell search state. Formation calls are made inline while
dispatching script commands. Starting two copies of that solver on the
same Pathfinder would share the search scratch and game state.

[VERIFIED] `parallel-budget.py` reconstructed the measured control
frames as serial background plus timed outer search jobs. It then
scheduled those same recorded costs with zero dispatch, copy, stale-work,
or synchronization overhead. Each row is a model, with no engine
parallel execution measured.

| Parallel work model | Mean FPS | p95 frame time |
|---|---:|---:|
| Formation search jobs only, four workers | 20.41 | 74.61 ms |
| All indivisible search jobs, four workers | 25.41 | 57.85 ms |
| All search work freely divisible across four workers | 28.44 | 43.47 ms |

[VERIFIED] Grouping consecutive formation requests within one tick by
equal observed topology and fixed-occupancy stamps yielded 145 batches
with more than one request, with at most two in each. Even ideal
parallel execution of those batches would save approximately
0.08 ms/tick. Equal stamps are only a diagnostic grouping key.

[INFERRED] Overlap independent source work, builds, and analysis when they
do not distort a timed gameplay capture. Keep paired FPS runs sequential
with isolated inputs. In the engine, prototype parallel work on immutable
snapshots, with private scratch and single-threaded validation and result
commit. Start with one or two workers and measure snapshot cost,
stale work, delay and frame time. The model favors combining this with
less search work. Four-way division alone still leaves a gap in this
trace.

[SOURCED] Elijah Emerson describes distributing flow-field integration
across threads when its cost-field memory is separate. Microsoft notes
that fine-grained tasks can spend more time in scheduling than they
save. [Flow-field integration](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf)
· [Concurrency model comparison](https://learn.microsoft.com/en-us/cpp/parallel/concrt/comparing-the-concurrency-runtime-to-other-concurrency-models?view=msvc-170)
