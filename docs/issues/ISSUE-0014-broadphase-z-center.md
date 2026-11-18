# ISSUE-0014: Broadphase used bottom-center positions for the 3D sphere test

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-15
- **Task:** T-049
- **Related:** T-046, T-043, EXP-008; [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md)
- **Environment:** rebuilt engine `1915B8BF...4406`; vendor `0ff1220`; `ZH_DEBRIS_BROADPHASE=1` via `tools/play-shockwave-performance.ps1`

## Symptom

The T-046 comment and docs claimed the 3D bounding-sphere early-out "preserves all collisions
and therefore all physics". The test compared raw `Object::getPosition()` values in Z. In this
engine an object position is the **bottom center** of its geometry; the bounding sphere is
centered at `position.z + GeometryInfo::getZDeltaToCenterPosition()`. The engine's own sphere
test already adds that delta (`PartitionManager.cpp` `distCalcProc_BoundaryAndBoundary_3D`).

For objects with different heights, the raw-position distance can therefore be larger than the
center distance and the pair is rejected even though the spheres overlap. Example: a 40 m tall
structure at z=0 (sphere radius ~21.2, center z=20) and a 4 m unit at z=35 (radius ~4.5) overlap
in Z (33-39 vs 0-40) but the old test computed dz=35 > 25.7 and skipped the pair.

## Reproduction / evidence

Source review of the T-043/T-046 hunk:

```
const Real dz = p1->z - p2->z;   // p1/p2 are bottom centers
if (dx*dx + dy*dy + dz*dz > radius*radius) continue;
```

Engine reference for the correct center:

```
// note that object positions are defined as the bottom center of the geometry,
// thus we must add the radius to the z coord to get the proper center ...
diff.z = ((posB->z + geomB->getZDeltaToCenterPosition())
        - (posA->z + geomA->getZDeltaToCenterPosition()));
```

`PartitionManager.cpp` `distCalcProc_BoundaryAndBoundary_3D`; `GeometryInfo::getZDeltaToCenterPosition()`
in `Common/Geometry.h`.

The bare engine defaults `s_broadphase` to 0, so retail-like runs were unaffected. The performance
launcher (`tools/play-shockwave-performance.ps1 -DebrisBroadphase 1`, the default) and the demo
scripts enable it, so optimized play and the 1,000-unit tests used the flawed test. The tank tests
did not expose it because all spawned tanks have the same geometry height.

## Impact

When enabled, valid debris/unit/structure collisions could be dropped, changing physics. The
claim "keeps every collision" was false. This is a correctness bug in an optimization, not just
a diagnostic issue.

## Root cause

The bounding-sphere center offset was omitted from the early-out. The code compared object
origins instead of sphere centers.

## Workaround

Disable the broadphase (`ZH_DEBRIS_BROADPHASE=0`) until the fixed engine is staged.

## Resolution / verification

- `PartitionManager.cpp` now uses `getGeometryInfo().getZDeltaToCenterPosition()` for both
  objects, mirroring `distCalcProc_BoundaryAndBoundary_3D`. The test remains conservative
  (`>` rejects only definite separation; touching spheres are kept).
- The T-043 patch was updated with the same change so it cannot reintroduce the bug.
- Rebuilt engine: `F606E60374B662877407D40C0603DA2961981816C8F445A629AD7ABD60C007A3`
  (6,753,792 bytes); build exit 0 (`artifacts/2026-11-15-copy-audit/build-fix.log`).
- `artifacts/2026-11-15-copy-audit/source-working.diff` records the exact source review.
- `engine/patches/current-engine.patch` applies to a clean vendor index and reproduces the
  working tree exactly (empty `git diff` after apply; see ISSUE-0015).

Limitation: the fix was verified by reviewing the engine's own sphere math and by a clean build.
A tall-structure collision scene was not re-run in-game; the change only makes the broadphase
more permissive (it cannot reject a pair the old code kept).

## History

- 2026-11-15 - Found during the T-049 copy/source audit; fixed and rebuilt.
