# Pathfinder occupant cache

- Date: 2026-11-22
- Task: T-118 (pathfinding performance, follows T-116/T-117)
- Status: implemented; cache accessor/oracle verified with the T-120 fixture;
  correct but **no timing gain** on the available path bench. Not recommended
  for default enablement until a fixed-goal-heavy workload is measured.
- Evidence: [Minecraft optimization mapping](2026-11-22-minecraft-optimization-inspirations.md),
  [T-116 combined run](../../artifacts/2026-11-21-t116-group-relax/manifest.md)

## Problem

[VERIFIED] The combined T-116/T-117 Last Stand window spent **97 ms/frame** in
path search (29.1 M us over 300 frames), and the T-116-off/T-117-on deploy-test
spent **124.7 ms/frame**. `clearCellForDiameter` is on every width query: goal
width, neighbour expansion and goal-offset search. For every cell flagged
`UNIT_PRESENT_FIXED` it called `TheGameLogic->findObjectByID(cell.getPosUnit())`
and then `getCrushableLevel`, `testStatus` (T-117 deployed avoidance) or
`getRelationship` (T-116 goal relaxation).

The object ID is a hash lookup on a hot path. It is invariant for the life of
the occupancy record: the pathfinder sets/clears the positioned unit when the
unit enters/leaves the cell.

## Change

- `PathfindCellInfo` now carries `Object *m_posObject`, the cached occupant for
  width queries. It is set in `PathfindCell::setPosUnit` when a positioned unit
  is recorded, cleared when the position is removed and nulled when the info
  record is recycled/released.
- `PathfindCell::getPosObject()` exposes it.
- `clearCellForDiameter` uses `cell.getPosObject()` instead of
  `findObjectByID(cell.getPosUnit())` in both the optimized footprint scanner
  and the legacy scan.
- The pointer is transient and not serialized; the pathfinder cells are rebuilt
  on load. `findObjectByID` still happens once in the set/clear path, not per
  width cell.

## Scope

- All ground-path width queries, including the group goal, the neighbour
  expansion and the goal-offset search.
- The T-116 goal-relax relationship check and the T-117 deployed-avoid status
  check now use the cached pointer.
- Expansion counts/routes are unchanged; this is a per-cell cost optimization,
  not an algorithm change.

## Expected

- Fewer hash lookups in the width scan; lower `usec_total` per path request.
- Measure with `ZH_PF_FRAME` (requests, usec, expansions, cmax_open) and
  `ZH_ATTR_LOG` (`l_ai`, interval). The expansion count should stay the same;
  a change means the cache altered occupancy state.
- The target is the 97-124 ms/frame path search. If the gain is small, the next
  candidates are the cross-group route cache and HPA*/flow field.

## Risks

- Object lifetime: the cached pointer is valid only while the pathfinder's
  occupancy record is valid. The pathfinder clears the position on object
  removal; the `PathfindCellInfo` release nulls it. A missed removal would leave
  a dangling pointer; the previous ID lookup would have returned null. This
  needs a careful test on unit death/removal.
- The pathfinder's frozen/T-112 snapshots copy cell state; the pointer is in the
  info record and is not serialized. The snapshots are same-process and the
  objects outlive the query.
- The `PathfindCellInfo` layout changed by one pointer; the info pool record size
  grows by 4 bytes. No CRC/save field was added.

## Test plan and result

1. Built `t116-path-cache.exe` (`63C2530F...`) and a dev fixture build with
   `ZH_PF_OCCUPANT_CACHE` (cache/ID switch), `ZH_PF_CACHE_ORACLE` (cached vs
   fresh pointer) and `ZH_PF_CACHE_SELFTEST` (inject 16 empty cache results).
2. [VERIFIED] The oracle self-test reported **16 mismatches** (100 cell queries,
   84 exact hits); the clean run reported **0 mismatches and 100/100 exact
   hits**. The cached pointer matched the fresh `findObjectByID` at every
   queried blocker cell.
3. [VERIFIED] Final path bench (8x25 movers + 100 stationary blockers):
   cache on 2,672 requests / 1,545,396 expansions / 2.912 s path time;
   cache off 2,707 / 1,546,477 / 2.880 s. The cache was **1.1% slower**, with
   no measured gain; the maintained formation-width scan resolves occupants
   through `findObjectByID` directly and dominates this workload.
4. The cache is correct on the covered cells but not a demonstrated speedup.
   Keep it behind the switch; do not enable it by default or claim a gain. A
   fixed-goal-heavy Last Stand window or a direct width-scan microbenchmark is
   needed before keeping it. The route cache/HPA* remains the next lever.
5. The switch and oracle now live permanently in `PathfindCell::getPosObject`
   (`ZH_PF_OCCUPANT_CACHE`, default **off**, `ZH_PF_CACHE_ORACLE`,
   `ZH_PF_CACHE_SELFTEST`). The dev fixture injects only GameLogic. The playtest
   engine `0D3A2819...` sets the cache off.

## Minecraft mapping

FerriteCore/Lithium both avoid repeated work on hot data structures. This is
the pathfinder equivalent: cache the occupant object once per occupancy change
instead of resolving its ID on every width query.
