# ISSUE-0021: Debris broadphase rejects real collisions against tall cylinders

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-055
- **Related:** [EXP-011](../experiments/EXP-011-broadphase-correctness.md), [EXP-008](../experiments/EXP-008-shockwave-nuke-performance.md) §11, T-046
- **Environment:** engine `2496E18B…2906` (pre-fix) vs `11A4F523…F5E8` (fixed)

## Symptom

T-046's debris broadphase is documented as "conservative ... keeps every collision". With tall
cylinder geometry in the scene, the broadphase rejects pairs that the narrow phase then reports as
collisions.

## Reproduction / evidence

Test-only probe (`ZH_BROADPHASE_CHECK=1`, `ZH_BROADPHASE_CHECK_LOG`) runs every *rejected* pair
through `PartitionData::friend_collidesWith`:

```
frame,this,that,geomThis,geomThat,majorThis,heightThis,majorThat,heightThat,dist
153,GenericDebris,TreeOakFall5,0,1,1.00,1.00,3.00,15.00,8.77
345,GenericDebris,TreePine,0,1,1.00,1.00,3.00,15.00,8.52
```

Scenario: 300 tanks, 20 command centres, three real warheads
(`artifacts/2026-11-15-broadphase-diff/probe/`). The off/on collision-hash differential differed
on 1,597 of 3,169 frames by ~2 pairs from the first frame
(`artifacts/2026-11-15-broadphase-diff/off/` vs `on/`).

## Impact

Cosmetic debris passing through tall trees/structures instead of bouncing off them; the documented
"keeps every collision" guarantee was false for cylinder geometry. No gameplay-rule effect
(debris are cosmetic), so severity is Medium.

## Root cause

`GeometryInfo::calcBoundingStuff()` computes the cylinder bounding sphere as
`max(majorRadius, height/2)` (`Geometry.cpp:497-505`) instead of the true half-diagonal
`sqrt(r² + (h/2)²)`. For r=3, h=15 that is 7.50 versus 8.08 — 7% too small — so
`dx²+dy²+dz² > (r1+r2)²` rejected touching pairs before the narrow phase ran.

## Workaround

Run with `ZH_DEBRIS_BROADPHASE=0` (loses the optimisation).

## Resolution / verification

`PartitionManager::addPossibleCollisions` now uses a local conservative radius
(`zhConservativeBoundingRadius`): the true half-diagonal per geometry type, taking the larger of
that and the stored value, plus a margin of `×1.02 + 0.25` to absorb float rounding and the narrow
phase's contact tolerance. `GeometryInfo` itself is unchanged, so culling and other users keep
their existing numbers.

Verification (`artifacts/2026-11-15-broadphase-diff/probe-final/`):

```
frames 3667, sum_collisions 128888, sum_candidates 675079, sum_bp_misses 0
miss checks: 0 distinct pairs: 0
```

See [EXP-011](../experiments/EXP-011-broadphase-correctness.md) §3.2-3.3 for the residual
order-sensitivity caveat.

## History

- 2026-11-15 — found and fixed during the T-050 recommendation #1 differential; probe added as
  `ZH_BROADPHASE_CHECK` / `ZH_COLLISION_LOG` so the guarantee can be re-checked after any change.
