# Pathfinding workload and instrumentation spec (T-022 groundwork)

- **Date:** 2026-11-15
- **Task:** T-022 (T-053 sibling; produced from T-050's recommendation #4)
- **Status:** spec — no code, no measurements yet
- **Related:** [T-050 validation report](2026-11-15-low-level-optimization-validation.md) §5,
  [EXP-009](../experiments/EXP-009-frame-attribution.md) §6, [BOARD](../tasks/BOARD.md)

## 1. Why this exists

T-050 concluded that pathfinding is a strong source-level candidate (linked open-list insertion,
`PathfindCell.cpp:483-657`; upstream PR #3198 already removed path-tail walks) but that **we have
no workload that exercises it**. The stationary 1,000-tank scene never issues a path request, so
any open-list rewrite would be unmeasurable and unverifiable here. This spec defines the scenario,
the instrumentation, the acceptance tests and the experiment procedure *before* touching
`PathfindCell.cpp`.

Non-goals: changing path costs, search caps, heuristic weights, or retail guards. Those change
routes and are not performance work.

## 2. Current facts to build on

| Fact | Reference |
|---|---|
| Path entry point is `Pathfinder::findPath(Object*, const LocomotorSet&, const Coord3D* from, const Coord3D* to)` | `Core/GameEngine/Include/GameLogic/AIPathfind.h:84,114` |
| Internal search lives in `Pathfinder::internalFindPath` | `AIPathfind.h:256` |
| Open list is a linked list with sorted insertion (forward/reverse variants) | `Core/.../PathfindCell.cpp:483-657` |
| A 30,000-record `PathfindCellInfo` pool with a free list already exists | `PathfindCellInfo.cpp:22,45,77` |
| Path appends in O(1) through `m_pathTail` | `Path.cpp:204-236` |
| Units are commanded with `AICommandParms` + `aiDoCommand` | `GeneralsMD/.../Include/GameLogic/AI.h:415`, `AIUpdate.h:359` |
| Move command value is `AICMD_MOVE_TO_POSITION` (0) | `AI.h:351` |

## 3. Scenario definition

A **moving** army, unlike the stationary stress scenario. One new harness mode in
`GameLogic::update()`'s test block (same pattern as `ZH_STRESS`):

- Spawn `ZH_PF_GROUPS` groups of `ZH_PF_GROUP_SIZE` units on opposite sides of the map centre
  (default 8 × 25 = 200 units; mobile template, default `AmericaTankCrusader`).
- Every `ZH_PF_INTERVAL` logic frames (default 90), issue `AICMD_MOVE_TO_POSITION` for every unit
  to a target cycling through: (a) the opposite side, (b) a choke point, (c) an impassable
  objective (a position inside a structure footprint), (d) a moving blocker's position.
- Optional `ZH_PF_BLOCKERS=<n>` spawns immobile structures on the straight line between the two
  sides so paths must route around them.
- `ZH_PF_SEED` fixes target jitter so two builds get identical requests.

Requests must be issued from `GameLogic` (logic frame), not from a UI script, so the request
sequence is deterministic and identical across binaries.

## 4. Instrumentation

### 4.1 Per-request log — `ZH_PF_LOG=<csv>`

Written at the end of each `internalFindPath` call:

```
frame,fromX,fromY,toX,toY,found,expansions,pushes,pops,maxOpen,pathLen,usec,fallback
```

| Column | Source |
|---|---|
| `expansions` | count of nodes popped/expanded in the A* loop |
| `pushes` / `pops` | open-list insertions and removals |
| `maxOpen` | peak open-list length (the number that decides list vs heap) |
| `pathLen` | cells in the returned `Path` |
| `usec` | QPC delta for the whole call |
| `fallback` | 1 when the original (non-fixed) routine was selected |

**Why `maxOpen` decides the algorithm:** a sorted list beats a binary heap below roughly 16–32
entries. Without this number a heap rewrite is a guess.

### 4.2 Per-frame aggregate — `ZH_PF_FRAME=<csv>`

```
frame,requests,usec_total,usec_max,expansions_total,cmax_open
```

Joined with `ZH_PERF_LOGIC` so pathfinding time can be compared with updates/AI/partition.

### 4.3 Optional sampling

`ZH_PF_SAMPLE=<n>` logs every n-th request's full expansion sequence (cell x,y) to a separate
file, so two builds can be diffed for *route equality*, not just cost.

## 5. Experiments this workload enables

| # | Question | Variant | Pass condition |
|---|---|---|---|
| P7-a | How much CPU is pathfinding in a moving army? | baseline vs `ZH_PF_GROUPS=0` | measurable share with the same frame pacing |
| P7-b | Is the open list the cost? | baseline vs a prototype indexed heap | identical paths (or documented tie-order changes) and a real frame-time gain |
| P7-c | Is the fixed-pathfinding branch ever used? | log `fallback` | count > 0 or the branch is dead in practice |
| P7-d | Does mobile-blocker churn dominate? | blockers on/off | separates routing cost from repath cost |

## 6. Correctness and safety rules

1. **Paths must match** for the same request set unless the change is explicitly allowed to alter
   tie order; then compare expansion sequences and report the first divergence.
2. Never raise search caps, disable zone/A* fallbacks, or change costs to win a benchmark.
3. Keep `RETAIL_COMPATIBLE_CRC`-guarded paths untouched; this stays singleplayer/test-only, like
   T-043/T-046.
4. `ZH_PF_*` variables must be added to the harness cleanup list in
   `tools/benchmark-entity-heavy.ps1` so they cannot leak into later runs (ISSUE-0016).
5. Requests are issued from logic frames only; a UI-driven scenario is not reproducible.

## 7. Implementation order (when this is picked up)

1. Harness mode + `ZH_PF_LOG`/`ZH_PF_FRAME` (no engine behaviour change; one build).
2. Baseline runs: 200 units, blockers on/off, 3 runs each; record `maxOpen`, expansions/frame.
3. Decide from `maxOpen`/`expansions`: list tuning, heap, or "not worth it".
4. Only then prototype, with the differential path comparison in §5.

## 8. Effort estimate

| Step | Estimate |
|---|---|
| Harness mode + logging | ~150 lines, one build (~40 s incremental) |
| Baseline measurement | 6 runs × ~2.5 min |
| Heap prototype | ~80 lines in `PathfindCell.cpp` + differential harness |

Deliberately not started until the debris/attribution line (T-053) is settled, because both
compete for the same rebuild/measure slots and this one has no evidence of being the current
bottleneck.
