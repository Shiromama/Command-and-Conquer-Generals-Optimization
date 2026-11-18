# EXP-021: shipping configuration — full default-on package and what moved the tail

> **Status:** complete · **Date:** 2026-11-16 · **Tasks:** T-064 (defaults-on), T-065, T-067
> **Related:** [EXP-016](EXP-016-default-on-package.md) (earlier package run, partition env-off),
> [EXP-017](EXP-017-destroy-path.md), [EXP-018](EXP-018-disabled-scan.md),
> [EXP-013](EXP-013-original-vs-optimized.md) §5.2 (reference)

## 1. Question

Every optimisation is now default-on and read from `Options.ini`. The earlier package measurement
(EXP-016) still exported `ZH_COSMETIC_PARTITION=0` from the ShockWave harness, so it measured the
package **with the debris partition skip disabled**. What does the configuration that will actually
ship do, and which change owns the tail improvement?

## 2. Setup

Two independent pieces of evidence, both on the ShockWave copy, 1,000 units × 5 spawn/nuke cycles,
45 s measured, performance profile (AA 0 + Low), uncapped:

1. **Shipping configuration** — engine `68D23E4E` (T-065 + T-067), no optimisation env overrides
   except the harness's `ZH_DEBRIS_BROADPHASE=1` (also the default) and `ZH_DEBRIS_PAIR_FILTER=0`;
   `CosmeticPartition` left at its default (**on**). 2 runs (`run-1`, `run-2`).
2. **Controlled attribution** — the same binary, same scene, only `ZH_COSMETIC_PARTITION` differs:
   A = 0 (skip off), B = 1 (skip on), 2 alternating pairs.

## 3. Results

### 3.1 Shipping configuration

| run | median | FPS | p95 | FPS@95 | p99 | FPS@99 |
|---|---:|---:|---:|---:|---:|---:|
| run-1 | 4.30 ms | 232.7 | 22.15 ms | 45.2 | 34.59 ms | 28.9 |
| run-2 | 4.61 ms | 217.1 | 22.30 ms | 44.8 | 35.64 ms | 28.1 |
| **mean** | **4.46 ms** | **224.9** | **22.23 ms** | **45.0** | **35.12 ms** | **28.5** |

### 3.2 Controlled partition A/B (same binary `68D23E4E`)

| run | skip | median | FPS | p95 | FPS@95 | p99 | FPS@99 |
|---|---|---:|---:|---:|---:|---:|---:|
| A-1 | off | 4.49 ms | 222.9 | 28.36 | 35.3 | 41.76 | 23.9 |
| A-2 | off | 4.64 ms | 215.6 | 26.30 | 38.0 | 40.19 | 24.9 |
| **A mean** | | **4.56 ms** | **219.2** | **27.33** | **36.6** | **40.98** | **24.4** |
| B-1 | on | 4.58 ms | 218.2 | 21.28 | 47.0 | 33.06 | 30.2 |
| B-2 | on | 4.72 ms | 212.1 | 21.45 | 46.6 | 32.83 | 30.5 |
| **B mean** | | **4.65 ms** | **215.1** | **21.37** | **46.8** | **32.95** | **30.4** |
| delta | | +2.0% | −1.9% | **−21.8%** | **+27.9%** | **−19.6%** | **+24.6%** |

### 3.3 Where the tail went (all ShockWave, 1,000 × 5, p95)

| configuration | p95 | FPS@95 | p99 | FPS@99 |
|---|---:|---:|---:|---:|
| pre-T-065 engine, skip **off** (EXP-016) | 49.59 ms | 20.2 | 67.87 ms | 14.7 |
| T-065 + T-067, skip **off** (§3.2 A) | 27.33 ms | 36.6 | 40.98 ms | 24.4 |
| T-065 + T-067, skip **on** — shipping (§3.1) | 22.23 ms | 45.0 | 35.12 ms | 28.5 |

## 4. Reading it

- The debris partition skip is worth **~6 ms of p95** (27.3 → 21.4 ms, **36.6 → 46.8 FPS**) and
  ~8 ms of p99 (24.4 → 30.4 FPS) on the same binary, at no median cost (+2.0% ms, inside spread).
  This is the single biggest tail lever measured in the project so far.
- T-065's destroy-path fix is the other half: it removed the 92 ms destroy spike (EXP-017), which is
  why the same "skip off" scene sits at 27 ms p95 now instead of 50 ms.
- Together, the shipped configuration takes the nuke-scene tail from **20.2 → 45.0 FPS at p95** and
  **14.7 → 28.5 FPS at p99**, while the median stays ~220–230 FPS.
- Note the two rows are not a single paired experiment (different engines/sessions); the *attribution*
  claim rests on §3.2, which is a same-binary alternating A/B.

## 5. Artifacts

- `artifacts/2026-11-16-shw-full-package/` — `run-1`, `run-2` (`perf.csv`, `logic.csv`, `attr.csv`,
  `objects.log`), `manifest.md`.
- `artifacts/2026-11-16-cosmetic-partition-ab/` — `A-1`, `A-2`, `B-1`, `B-2`, `summary.json`,
  `manifest.md`.
