# EXP-012: Deferred, keep-every-piece debris creation (T-053)

> **Status:** complete — **rejected** (behaviour correct, net frame time unchanged to slightly worse)
> **Date:** 2026-11-15 · **Task:** T-053
> **Related:** [EXP-009](EXP-009-frame-attribution.md) §4.3, T-041 (drops debris), T-043 (partition
> skip), T-046/T-055 (broadphase)

## 1. Question

EXP-009 showed the mass-death cost is debris lifecycle: with debris suppressed the five-cycle run
improves from median/p95 33.33/77.42 to 18.82/38.90 ms, and the destroy phase peaks at 92 ms.
T-041 removes that cost by **dropping** debris, which T-048 rejects. Can we keep every piece and
still cut the peak by **deferring** creation to the following logic frames?

## 2. Implementation

`ZH_DEBRIS_DEFER=<n>` (off by default) in `ObjectCreationList.cpp`:

- The unit of deferral is one cosmetic OCL nugget invocation (one death's debris cluster) — the
  finest granularity reachable through the public nugget interface.
- Per logic frame at most `n` clusters are created. Excess clusters are queued with their
  template, position, angle, lifetime and producer id.
- `zhFlushDeferredDebris()` runs at the start of each `GameLogic::update()` and replays queued
  clusters with the same budget, resolving the producer by id (it may already be destroyed).
- Bounded queue (20,000 clusters). If it ever fills, the cluster is created immediately instead
  of being lost, and `dropped` is incremented.
- `ZH_DEBRIS_DEFER_LOG=<csv>` → `frame,objects_created,clusters_flushed,queued,dropped`.

Correctness properties: no debris is dropped by the patch (queue-full fallback creates instead),
and the queue drains to zero within a frame budget after the last death.

Known limitation: deferring moves the RNG draws that pick debris model/health/lifetime, so a
deferred run diverges from a non-deferred one after the first overflow. Like T-043/T-046 this is
a singleplayer/visual optimisation, not a CRC-preserving change.

## 3. Setup

ShockWave `game/shockwave-engine`, d3d8to9 + dGPU, 1920×1080 borderless, 1,000
`ChinaTankBattleMaster`, five spawn/nuke cycles, nine real warheads per cycle,
`ZH_DEBRIS_DEFER=40` vs unset. Six alternating runs (base, defer, base, defer, base, defer),
90 s measured window, first 30 presented frames dropped. Frame times from `perf.csv`, phase
maxima from `ZH_PERF_LOGIC`.

## 4. Results

| run | frames | median | mean | p95 | p99 | >33.3 ms | destroy max | updates max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| base 1 | 3,330 | 33.39 | 41.29 | 75.86 | 122.06 | 55.2% | 95.73 | 145.43 |
| defer 1 | 3,329 | 33.35 | 40.99 | 74.69 | 108.61 | 51.8% | 78.10 | 200.78 |
| base 2 | 3,330 | 33.35 | 41.16 | 75.80 | 108.86 | 52.5% | 83.03 | 184.19 |
| defer 2 | 3,330 | 33.36 | 41.18 | 75.30 | 107.31 | 52.3% | 80.84 | 183.34 |
| base 3 | 3,330 | 33.34 | 40.78 | 73.40 | 104.60 | 50.7% | 82.62 | 202.16 |
| defer 3 | 3,210 | 33.38 | 42.60 | 76.98 | 110.07 | 54.4% | 79.78 | 232.87 |

¹ this run recorded 3,210 frames instead of ~3,330 (its window ended slightly early); its numbers
are still included, and the three-run averages below do not depend on it.

| metric (mean of 3) | base | defer | delta |
|---|---:|---:|---:|
| median | 33.36 | 33.36 | 0.0% (30 FPS cap) |
| mean | 41.08 | 41.59 | **+1.2%** |
| p95 | 75.02 | 75.66 | **+0.9%** |
| p99 | 111.84 | 108.66 | −2.8% |
| destroy max | 87.13 | 79.57 | −8.7% (baseline spread 82.6–95.7) |
| updates max | 177.26 | 205.66 | **+16.0%** |

The three baseline runs alone span 82.6–95.7 ms (15%), so the −8.7% is inside run variation.

Deferral integrity in all three variant runs:

```
created 25169  flushed clusters 12187  max queued 2049  final queued 0  dropped 0
created 25181  flushed clusters 12232  max queued 2051  final queued 0  dropped 0
created 25106  flushed clusters 12201  max queued 2048  final queued 0  dropped 0
```

## 5. Verdict: correct, and rejected

The behaviour checks pass: every queued cluster is replayed, the queue drains to zero, nothing is
dropped, and no assert/crash occurs over five cycles.

The performance result is **negative**, and it matches what the mechanism predicts:

- The median cannot move (30 FPS cap), and mean/p95 are slightly **worse** (+1.2% / +0.9%).
- `destroy max` drops 8.7%, but the three baseline runs alone span 82.6–95.7 ms (15%), so this is
  inside run variation.
- `updates max` rises **+16%**: the cost is moved into the next frame, not removed. Deferral buys a
  flatter death burst at the price of a taller update burst; net frame time is unchanged to
  slightly worse.

Why the ceiling is low: the deferral only touches debris creation. EXP-009 showed the biggest
single chunk of a cycle frame is **spawning** 1,000 objects (85 ms, `TheThingFactory::newObject`)
and the 134–151 ms of first AI/physics ticks on the following frame. Neither is debris and neither
is addressed here.

Kept as an opt-in experiment (`ZH_DEBRIS_DEFER`, off by default) because it is correct and might
matter on a death-dominated scene without spawn bursts; **not** enabled in any profile, and not
recommended.

## 6. What would actually move the needle

1. The spawn burst is harness-shaped (1,000 objects at once); a real game produces units
   continuously, so optimising it would mostly flatter the benchmark.
2. The first-tick burst (134–151 ms of `AIUpdateInterface`/`PhysicsBehavior` over ~1,000 objects)
   could be amortised across frames at production time, but that is a gameplay-timing change, not
   a rendering optimisation.
3. For real late-game play the remaining lever is still T-025 (replay validation) and T-035
   (shadow maps), not debris.

## 7. Artifacts

- `artifacts/2026-11-15-defer-ab/` — six runs, `perf.csv`, `logic.csv`, `defer.csv` (variant),
  `objects.log`, `summary.json`, `summarize.py`, `manifest.md`.
- `artifacts/2026-11-15-defer-smoke/` — first smoke run (queue drains, 0 dropped).

## Follow-up (T-076, 2026-11-17): code removed

The rejected queue was deleted rather than left opt-in: `zhMaybeDefer`, `zhFlushDeferredDebris`,
the queue struct/statics, the `ZH_DEBRIS_DEFER`/`ZH_DEBRIS_DEFER_LOG` env reads, its call sites in
`ObjectCreationList.cpp` and the flush call in `GameLogic::update`, plus `<deque>`. `ZH_DEBRIS_DEFER`
is absent from binary `059B5E7A…DC0F`. The measurement and conclusion above stand as the record.
