# EXP-020: T-066 shadow-volume rebuild throttle — measured and rejected

> **Status:** complete (negative) · **Date:** 2026-11-16 · **Task:** T-066
> **Related:** [architecture audit](../research/2026-11-16-low-level-architecture-audit.md) §2.5,
> [EXP-004](EXP-004-architecture-headroom.md), [EXP-018](EXP-018-disabled-scan.md)

## 1. Question

The audit's §2.5 claimed the dominant High-detail shadow cost is the per-frame rebuild of every
mesh silhouette (`W3DVolumetricShadow::updateVolumes` → `buildSilhouette` + `constructVolume`),
quoting "3 full VB scans/frame" and a ~7.4 ms High-detail cost at 1,000 units. The original
developers had left the throttle commented out:

```cpp
// for now we will just rebuild a shadow volume every so often, this
// should be changed to be built only when the light angle sufficiently
// changes or when the object rotation sufficiently changes
//  currentTime = timeGetTime();
//  if( currentTime - lastTime >= delay )
```

Does rate-limiting that rebuild recover any of the 7.4 ms?

## 2. Change tested

Per-instance rebuild stamp (`m_lastVolumeUpdate`) plus `ZH_SHADOW_THROTTLE` (ms; the tested build
defaulted to 33, i.e. ~30 rebuilds/s). The **cheap** per-frame visibility/bounds tests still ran
every frame, so shapes outside their cull box were still skipped; only the expensive volume
reconstruction was rate-limited.

## 3. Setup

- Engine `F49ED05B…ED4D` (same binary both arms — only the env value differs), `-NoLtcg`.
- Profile: AA 0 + **High** (shadows on) so the shadow path is active.
- Stock copy, 1,000 tanks, 40 s, 2 alternating pairs.
- A = `ZH_SHADOW_THROTTLE=0` (rebuild every frame, previous behaviour);
  B = throttle active at 33 ms.

## 4. Results

| run | arm | median | FPS | p95 | FPS@95 | p99 | max |
|---|---|---:|---:|---:|---:|---:|---:|
| A-1 | every frame | 7.84 ms | 127.6 | 9.35 | 107.0 | 13.91 | 140.0 |
| A-2 | every frame | 7.87 ms | 127.1 | 9.39 | 106.5 | 13.15 | 136.1 |
| **A mean** | | **7.85 ms** | **127.3** | **9.37** | **106.8** | **13.53** | 138.1 |
| B-1 | 33 ms | 7.65 ms | 130.6 | 9.42 | 106.2 | 12.07 | 135.1 |
| B-2 | 33 ms | 7.89 ms | 126.8 | 9.67 | 103.4 | 12.89 | 148.8 |
| **B mean** | | **7.77 ms** | **128.7** | **9.54** | **104.8** | **12.48** | 142.0 |
| delta | | −1.1% | +1.4 | +1.9% | −1.9 | −7.8% | +2.8% |

## 5. Reading it

- Cutting the rebuild rate by ~5× (144 FPS → 30 rebuilds/s) moves the median by **−1.1%**, which is
  smaller than the run-to-run spread (7.65–7.89 ms). p95 is 1.9% *worse*, p99 7.8% better — a wash.
- Therefore the per-frame silhouette rebuild is **not** where the High-detail shadow milliseconds
  go. The ~7.4 ms is the cost of *rendering* the volumes (fill/vertex work), which this change does
  not touch. The audit's §2.5 premise is wrong on the mechanism.
- **Decision: rejected.** The throttle buys nothing measurable and would let shadows lag up to
  33 ms on fast units, so the source change was reverted (the shadow `.cpp` is back to only its
  pre-existing shadow-distance-cull patch; the header has no diff). The real lever stays
  **T-035 (shadow maps)**, which replaces the volume renderer rather than its update path.

## 6. Process note (honest record)

The first attempt at this A/B ran four times against the **old** binary (`68D23E4E`) because the
new build had not been staged; `benchmark-parameters.json` exposed it (`exe_sha256` identical in
both arms) and the run set was deleted. The numbers above are from the corrected run, where all
four runs report `F49ED05B`.

The planned screenshot verification could not be taken: the game window refused to come to the
foreground (the terminal stayed on top, so every capture was the desktop). It is moot here — the
change is reverted, so shipped rendering is unchanged.

## 7. Artifacts

`artifacts/2026-11-16-t066-shadow-throttle/` — `A-1`, `A-2`, `B-1`, `B-2`
(`frames-run1.csv`, `split-run1.csv`, `benchmark-parameters.json` with the exe hash),
`summary.json`, `manifest.md`.
