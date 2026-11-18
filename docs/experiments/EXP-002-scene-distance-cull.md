# EXP-002: Scene-level distance cull for draw submission

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-026
- **Status:** Complete (opt-in)

## Hypothesis

At 1,000 units, after AA is off, `TheDisplay->DRAW` is ~27 ms. The scene cull still submits every
render object in view. Culling render objects beyond a configurable distance should reduce draw
submission. This is an **opt-in** performance setting because it hides distant units.

## Baseline (EXP-001, AA 0)

| Metric | Value |
|---|---|
| Median frame time | 35.05 ms (runs: 34.76 / 35.05 / 36.50) |
| p95 | 40.20 ms |
| Draw median | 27.26 ms |
| Scenario | `maps\northamerica\northamerica.map`, 1,000 tanks, 1920×1080 |

## Method

Added `ZH_DRAWDIST` to `RTS3DScene::Visibility_Check` (`W3DScene.cpp`): after the frustum test,
render objects farther than the threshold from the camera are marked invisible. `0`/unset keeps
retail behavior. The launcher exposes it as `-DrawDistance`.

```
Generals.exe -win -quickstart -xres 1920 -yres 1080
ZH_MAP=maps\northamerica\northamerica.map
ZH_STRESS=1000
ZH_DRAWDIST=400
```

Three runs, 40 s each, steady state after frame 300.

## Results (distance 400)

| Run | Frames | Median ms | p95 ms | p99 ms | Draw median ms |
|---:|---:|---:|---:|---:|---:|
| 1 | 780 | 33.34 | 36.51 | 37.55 | 18.06 |
| 2 | 780 | 33.26 | 36.68 | 38.15 | 17.75 |
| 3 | 780 | 33.30 | 36.65 | 38.29 | 18.15 |

Sweep (single runs): distance 600 → median 33.74, draw 24.07; 800/1200 → draw 27.75–28.42,
effectively no cull; 200 → draw 13.38, median 33.33.

## Result

Supported. Compared with the AA-0 baseline:

- Median **35.05 → 33.30 ms** (~5% faster; the scene is now at the 30 FPS cap)
- p95 **40.20 → 36.65 ms** (~9% better)
- Draw **27.26 → 18.1 ms** (~34% lower)

The frame-time gain is capped because the engine targets 30 FPS; the draw headroom is the
meaningful improvement.

## Visibility-preserving LOD attempt

A distance LOD (`ZH_LOD`, `HLodClass::Set_LOD_Level`) was implemented and measured:
draw median **28.8 ms** vs **27.3 ms** baseline, median **36.71 ms** vs **35.05 ms** — no gain.
LOD was reverted. The remaining draw cost is draw-call submission, not model detail; batching
or a spatial index (T-021) is still required for a visibility-preserving fix.

**Follow-up:** the built-in Low detail preset (EXP-003) reaches the same draw time
(**18.45 ms**) with **all units visible**, so it is the preferred general profile. The
distance cull remains available for systems that need more headroom than Low detail.

## Tradeoff / limits

- Units beyond 400 world units are not drawn; this is a **visual/gameplay tradeoff**, so the
  cull is opt-in (`-DrawDistance`, `ZH_DRAWDIST`), default off.
- Selected/force-visible render objects bypass the cull (retail branch).
- The threshold is world-space, not screen-space; a screen-size LOD would preserve visuals better.
- Re-confirm on a real late-game replay and choose a user-facing default (e.g. 600) before enabling.

## Artifacts

- `artifacts/2026-11-14-engine-build-test/optimized-cull400-run1.csv`…`run3.csv`
- `artifacts/2026-11-14-engine-build-test/split-cull400-run1.csv`…`run3.csv`
- Patch: `engine/patches/T-021-scene-distance-cull.patch`

## Follow-up (2026-11-17): made default-on, then reversed

T-064 turned this cull on by default at 400 units. That was wrong: the note above ("opt-in because
it hides distant units") held in real play — units pop out of view as the camera pans
([ISSUE-0023](../issues/ISSUE-0023-draw-distance-hides-units.md)). The default is back to **0 (off)**
and the setting stays opt-in; `docs/optimizations.md` now ships `DrawDistance = 0` in the performance
preset and keeps 400 only for the stress harness. The benchmark gain measured here (draw 27.3 ->
18.1 ms, median 35.05 -> 33.30 ms at the 30 FPS cap) is real but not worth a visible regression.
