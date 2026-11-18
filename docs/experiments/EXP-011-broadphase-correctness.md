# EXP-011: Broadphase correctness differential (tall geometry, mixed heights)

> **Status:** complete · **Date:** 2026-11-15 · **Task:** T-054/T-055
> **Related:** [EXP-008](EXP-008-shockwave-nuke-performance.md) §11, [ISSUE-0014](../issues/ISSUE-0014-broadphase-z-center.md),
> [ISSUE-0021](../issues/ISSUE-0021-broadphase-cylinder-radius.md), [EXP-009](EXP-009-frame-attribution.md)

## 1. Question

T-046's debris broadphase claims it "keeps every collision". T-049 fixed its z-centre bug but the
fix was only verified at source/build level. This experiment asks, with a real scenario that has
tall and mixed-height geometry:

1. Does the broadphase ever reject a pair that the narrow phase would have collided?
2. Does the accepted collision set match a broadphase-off run?

## 2. Method

Test-only instrumentation (patch `T-054`/`T-055`):

- `ZH_COLLISION_LOG=<csv>` → `frame,candidates,collisions,hash,bp_misses`. `candidates` counts
  contact pairs that survived the broadphase; `collisions` counts narrow-phase acceptances;
  `hash` is an order-independent hash of the unordered object-id pairs.
- `ZH_BROADPHASE_CHECK=1` → every pair the broadphase **rejects** is still run through
  `PartitionData::friend_collidesWith`. A rejection that the narrow phase accepts is a real
  collision the optimisation dropped; it is counted in `bp_misses` and logged to
  `ZH_BROADPHASE_CHECK_LOG` with ids, template names, geometry types, extents and distance.
- Harness: `ZH_STRESS_STRUCTS` / `ZH_STRESS_STRUCT_COUNT` place tall immobile structures
  (default test: 20 × `ChinaCommandCenter`) on a ring around the tank grid.

Scenario: 300 `ChinaTankBattleMaster` (30-unit grid), 20 command centres on a 330-unit ring,
three real `NeutronMissileDUMMYObject` warheads, 35–45 s measured, ShockWave + d3d8to9 + dGPU.

| Run | Broadphase | Probe |
|---|---|---|
| `off`, `off2` | 0 | off |
| `on` | 1 (pre-fix build) | off |
| `probe` | 1 (pre-fix build) | on |
| `probe-fixed2` | 1 (conservative radius) | on |
| `probe-final` | 1 (conservative radius + margin) | on |

## 3. Results

### 3.1 The pre-fix broadphase drops real collisions

`probe` (build with the plain `getBoundingSphereRadius()`), 270 logged misses before the buffer
was truncated (the log had no `fflush`). Every logged pair was `GenericDebris` vs a tall tree:

```
frame,this,that,geomThis,geomThat,majorThis,heightThis,majorThat,heightThat,dist
153,GenericDebris,TreeOakFall5,0,1,1.00,1.00,3.00,15.00,8.77
345,GenericDebris,TreePine,0,1,1.00,1.00,3.00,15.00,8.52
```

Root cause: `GeometryInfo::calcBoundingStuff()` stores `max(majorRadius, height/2)` for
`GEOMETRY_CYLINDER` (`Geometry.cpp:497-505`). For a tree with r=3, h=15 that is **7.50**, while
the true half-diagonal is `sqrt(3² + 7.5²) = 8.08`. The reject radius was up to 7% too small, so
debris touching a tall trunk were filtered out before the narrow phase.

The off/on differential agrees: 1,597 of 3,169 common frames had a different collision hash,
always ~2 pairs, from the first frame onward.

### 3.2 Conservative radius removes the class of error

Patch `T-055` replaces the accessor with the true half-diagonal per geometry type
(`sqrt(major² + minor² + (h/2)²)` for boxes, `sqrt(major² + (h/2)²)` for cylinders, the stored
value otherwise) and adds a small relative+absolute margin (`×1.02 + 0.25`) for float rounding and
narrow-phase tolerance.

| Run | Frames | Distinct rejected-but-colliding pairs | `bp_misses` total |
|---|---:|---:|---:|
| `probe-fixed2` (radius only) | 3,656 | **2** (all within ~1 cm of the analytic bound) | 33,774 checks on 2 pairs |
| `probe-final` (radius + margin) | 3,667 | **0** | **0** |

`probe-final` processed 675,079 candidate pairs and 128,888 narrow-phase collisions with zero
rejected collisions.

### 3.3 Per-frame collision counts still differ slightly — and that is expected

The off/on differential on the final build still shows 1,729 of 2,619 common frames with a
different hash and a consistent ±1 collision count (e.g. 183 vs 182 at frame 1), while `bp_misses`
is 0. Both statements are true because `processContactList` evaluates `friend_collidesWith`
*lazily*, interleaved with `onCollide`, which moves objects. A smaller candidate set changes the
processing order, so a pair that was not touching at the start of the frame can be pushed into
contact by an earlier collision in one ordering and not the other. This is order sensitivity of
the physics, not a dropped pair.

Consequence: the broadphase cannot produce bit-identical simulation, which is why T-043/T-046 stay
singleplayer-only (CRC). It can and now does preserve every collision the narrow phase would have
reported for the same ordering.

## 4. Verdict

- **Fixed:** cylinder bounding radius was too small; tall trees lost real debris collisions.
  Patched with the true half-diagonal plus a small margin; 0 misses over 3,667 frames.
- **Documented:** per-frame collision counts are not identical with the broadphase on, by
  construction (order-dependent `onCollide`). Do not use "identical collision count" as the
  acceptance test; use the rejected-pair probe.
- **Cheap gain:** the conservative radius costs almost nothing — candidates fell from 3,603,940
  (off) to 675,074 (on) in the final run, an 81% reduction, versus 82% before the fix.

## 5. Artifacts

- `artifacts/2026-11-15-broadphase-diff/` — `off/`, `on/`, `off2/`, `on2/`, `probe/`,
  `probe-fixed2/`, `probe-final/`, `compare.py`, `manifest.md`.
