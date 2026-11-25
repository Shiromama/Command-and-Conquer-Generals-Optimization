# Group field / D* Lite promotion assessment

- Date: 2026-11-20
- Task: T-113
- Status: not a drop-in solver; HPA*/HAA* is the stronger next prototype
- Evidence: [algorithm note](2026-11-20-pathfinding-algorithm-limit.md),
  [HPA* model](../../artifacts/2026-11-20-hpa-star-model/manifest.md),
  [T-111 cache report](2026-11-19-last-stand-graphical-cache.md)

## What exists

[VERIFIED] `GroupFieldShadow.inc` / `GroupRouteShadow.inc` already implement:

- a width-aware reverse goal field (`Grid`, `Field`);
- a live-blocker repair search (`LiveSearch`) that revalidates width, center
  blocks and zone passability;
- route materialization and optimized-node comparison;
- a measured native shadow: width-6 field coverage **116/1,633**, width-2
  repair **1,057** routes, modeled **19.71 FPS** at width two.

The `GroupClearanceMemo` (T-111) is integrated and the `GroupRouteShadow` grid
uses the same clearance data.

## Why it is not a drop-in solver

[VERIFIED] The width-6 field is sparse on the Last Stand map: only 116 of
1,633 formation queries had a width-6 field candidate. The 1,057 repaired
routes used **width two**. A width-2 path is not a valid width-6 group path;
using it for the real formation would change collision/validity, not just
route choice.

[INFERRED] Promoting the existing shadow as-is would therefore either:

- return unsafe width-2 paths for width-6 groups, or
- fall back to the original search most of the time.

That is not a performance win. The field/repair idea needs a **width-6
clearance-aware field** and a width-6 repair, or a hierarchical abstraction
where every portal/route is validated at width six.

## Where the idea is still useful

1. **D* Lite-style repair** is the right mechanism for dynamic blockers; the
   existing `LiveSearch` is a simplified version. It should be kept as the
   local repair layer under a width-6 field.
2. **HPA*/HAA*** addresses the sparse width-6 issue at the cluster level. The
   offline model shows **~51% fewer expanded cells** at **+0.4%** path cost on
   a 350x200 width-6 street grid (185/197 within 1%).
3. **Combination:** HPA* cluster graph + a clearance-aware field inside each
   cluster + `LiveSearch` repair for changed blockers. This reuses the existing
   `Grid`/`Field`/`LiveSearch` code and the zone hierarchy.

## Recommendation

- Do **not** promote the current width-2 field repair as the solver.
- Prototype **HPA*/HAA* on the existing zone hierarchy** first, with width-6
  portals and a local repair; use the HPA* model as the expected node-count
  target.
- Keep the field/repair as the local dynamic-blocker layer once the width-6
  abstraction exists.
- Screen the result with the fresh-skirmish protocol, not the replay exact
  route gate.

No game run was made for this note.
