# Worker query/access contract for closest-reachable search

Status: **design, not implemented.** Records what `workerGroundSearch` must be able to answer before
`findClosestPath` can be wired to it, plus the parity harness and gates. Written 2026-11-25.

## Why this exists

`workerGroundSearch::Workspace::run(query, access)` currently answers *ground route* questions with a
deliberately minimal `Access` (see `AIPathfind.cpp:5643-5683`): admission is `CELL_CLEAR` only,
movement is a permissive default, width is hard-coded to `clearCellForDiameter(..., 6)`. That is
sufficient for the width-6 group kernel, which is why the group port worked.

`findClosestPath` (`AIPathfind.cpp:7840`) cannot use that contract. Its result depends on
object-level predicates the current `Access` cannot express, so a wiring attempt today diverges by
construction and would produce no usable parity signal.

## Predicates the closest search needs

| Predicate | Used for | Source in serial search |
|---|---|---|
| `checkDestination(obj, x, y, parent, ...)` | accept the goal only if it is a legal destination; otherwise take the closest legal cell | post-loop, `foundGoal` branch |
| `canPathThroughUnits` | permit a route through allied units and whether that is a hard block | `AIUpdateInterface::canPathThroughUnits()` |
| `crusher` | crush semantics in movement admission | `obj->getCrusherLevel() > 0` |
| locomotion surfaces / `validMovementPosition` | reject cells the locomotor cannot use | `locomotorSet.getValidSurfaces()`, `validMovementPosition(...)` |
| `goalOnObstacle` | when the goal sits on an ignored obstacle, treat the obstacle cell as valid | `m_ignoreObstacleID`, obstacle adjacency (`KINDOF_FS_AIRFIELD` special case) |
| dual distance (world + screen) | choose the closest cell when the goal is unreachable | `closestDistanceSqr`, `closestDistScreenSqr` |

Two of these (`checkDestination`, `validMovementPosition`) are *object* queries, not cell facts, so
they cannot be answered from a per-cell lambda without an object handle; the query must carry the
object identity and the predicates must be resolved against the pre-search snapshot.

## Proposed contract shape

Add one optional block to `Query`, default-constructed so every existing caller is unchanged:

```cpp
struct ClosestPolicy {
    bool enabled = false;          // caller opts in; existing callers leave it false
    bool canPathThroughUnits = false;
    bool countEveryAlly = false;
    bool crusher = false;
    unsigned surfaces = 0;         // locomotor valid surfaces mask
    unsigned ignoreObstacleId = 0; // 0 == none
    bool screenDistance = false;   // include the screen-space tiebreak
};
```

Add to `Access` a single optional resolver, so an `Access` that does not provide it keeps today's
behaviour:

```cpp
std::optional<ClosestDecision> closest(Point p);   // may return nullopt == "not answerable"
```

`ClosestDecision` carries `{ bool destinationOk; bool enterable; Real screenDistanceSqr; }`.
`run` consults `closest()` only when `query.closestPolicy.enabled`, tracking the best node by
`(worldDistanceSqr, screenDistanceSqr)` instead of the heuristic alone.

## Correction: the closest objective is cost-weighted, not a distance heuristic

[VERIFIED] `findClosestPath` does not select the nearest cell by distance. In the expansion loop
(`AIPathfind.cpp:8130-8175`) it maintains:

```
distSqr  = (goalX - cellX)^2 + (goalY - cellY)^2          // cell units
score    = distSqr + costSoFar^2 * COST_TO_DISTANCE_FACTOR_SQR * pathCostMultiplier
```

with `COST_TO_DISTANCE_FACTOR = 1.0f / 10.0f` (`PathfindConstants.h:48`), so `score` is effectively
`distSqr + (cost/10)^2 * pathCostMultiplier`. A candidate is accepted only when
`checkDestination(obj, x, y, layer, radius, centerInCell)` holds (and, when `startedStuck`,
`validMovementPosition(isCrusher, surfaces, cell)`), the screen distance is tracked separately as a
tiebreak (`distSqr < closestDistScreenSqr`), and expansion of a subtree is cut when
`distSqr > 4 * closestDistScreenSqr` under the `gotHierarchicalPath`/`count > 2000`/small-closest
conditions.

[INFERRED] The kernel's current fallback picks the closed node with the smallest **heuristic
distance**, which is a different objective, so a shadow built on it would mismatch by construction.
Parity requires the kernel to adopt this cost-weighted score — the policy needs `pathCostMultiplier`
and the kernel needs the constant and the pruning rule — before any `Access` richness matters. This
is a kernel change, not an Access contract change, and it must be implemented before the harness is
meaningful.

## Parity harness (must precede any behaviour change)

A shadow, not a replacement:

1. On each `findClosestPath` call, run the serial search exactly as today (behaviour unchanged).
2. If `ZH_CLOSEST_SHADOW=<path>` is set, also run `Workspace::run` with `closestPolicy.enabled`.
3. Log per call: frame, start, goal, radius, serial route hash, kernel route hash, serial cost,
   kernel cost, chain match, cost match, serial usec, kernel usec.
4. Expected failure modes to distinguish: chain mismatch (tie-break), cost mismatch (admission
   mismatch), kernel null (contract gap).

The shadow **must not be treated as a CRC oracle**: the page-snapshot diagnostic already showed that
adding allocation-heavy diagnostics can perturb the replay to `BD4F07ED` with a faithful snapshot
(0 audit mismatches at 15 checkpoints). Parity is therefore measured **per call**, not by replay CRC.
Production wiring, once parity holds, is gated by the exact `04C62655`/983 replay.

## Acceptance gates

1. **Shadow parity**: over the heavy window, kernel and serial produce the same route hash and cost
   for the same call, at a rate high enough to justify replacement (target: >95%, with every
   mismatch classified).
2. **Single-threaded replacement**: `ZH_CLOSEST_KERNEL=1` with exact `04C62655`/983 and heavy
   mean/p90/logic/path no worse than 36.80 ms / 14,680 us.
3. **Worker dispatch**: only after (2), through `SpeculativeWorkers` with per-search input and no
   serial fallback on the common path; report wall efficiency against the **~1.8x on 4 cores** bound
   (serial 14.68 ms -> <=11.2 ms wall including the 3.08 ms input cost).

## Risks

- **Object lifetime**: the serial closest search reads `obj` live; a worker needs a stable object
  identity and must treat a dead object as moot (the lane shadow measured 14.3% unknown-unit).
- **Per-search input cost**: 155 us measured with 100% parity; against a 738 us mean search that is
  21% overhead, so the worker must actually overlap it.
- **Tie-breaking**: the serial search's expansion order is not the kernel's; cost parity does not
  imply route parity, and route changes are a behaviour trade even in singleplayer.
- **Diagnostic divergence**: any allocation-heavy shadow can perturb the replay; do not use replay
  CRC to judge a shadow.

## Explicitly not in scope

- Replacing `internalFindPath` (that was rejected earlier: ended the match at ~frame 6,606).
- Capping, deferring, or TTL-extending closest searches (all measured negative).
- Any change to the 20-frame group-route TTL (measured: TTL 24 -> 42.91 ms, diverged).
