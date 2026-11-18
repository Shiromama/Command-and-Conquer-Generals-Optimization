# EXP-016: default-on optimisation package

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-064
> **Related:** [T-026](EXP-002-scene-distance-cull.md), [T-030/T-032](EXP-004-architecture-headroom.md),
> [T-043](EXP-008-shockwave-nuke-performance.md), [T-046](EXP-008-shockwave-nuke-performance.md),
> [EXP-013](EXP-013-original-vs-optimized.md) §5.2 (reference), [docs/optimizations.md](../optimizations.md)

## 1. Question

The distance cull, shadow LOD, debris broadphase, cosmetic partition skip and uncapped rendering
used to be opt-in (profile/env). They are now **on by default** and read from `Options.ini`. What
is the measured effect on the two reference scenes?

## 2. Setup

- Engine `5FA73119…0168` (defaults-on build), performance profile (AA 0 + Low), uncapped.
- `Options.ini` contains **none** of the new keys, so every default applies.
- Scene A: stock copy, 1,000 tanks, 40 s, 3 runs. Scene B: ShockWave copy, 1,000 units × 5
  spawn/nuke cycles, 60 s, 2 runs.
- Reference = `EXP-013` §5.2 on engine `DCF51A29` (same profile/scene, features opt-in):
  6.62 ms (151.1 FPS) and 3.81 ms (262.4 FPS) median; p95 7.96 / 61.72 ms.

## 3. Results

### Scene A — 1,000 tanks

| run | median | FPS | p95 | FPS at p95 | p99 | FPS at p99 |
|---|---:|---:|---:|---:|---:|---:|
| stock-1 | 6.82 ms | 146.6 | 8.89 ms | 112.5 | 11.35 ms | 88.1 |
| stock-2 | 7.43 ms | 134.6 | 9.74 ms | 102.7 | 14.25 ms | 70.2 |
| stock-3 | 6.52 ms | 153.4 | 7.92 ms | 126.3 | 10.51 ms | 95.1 |
| **mean** | **6.92 ms** | **144.9** | **8.85 ms** | **113.0** | **12.04 ms** | **83.1** |
| reference | 6.62 ms | 151.1 | 7.96 ms | 125.6 | – | – |
| delta | +4.5% | −4.1% | +11.2% | −10.0% | – | – |

### Scene B — 1,000 units × 5 spawn/nuke cycles

| run | median | FPS | p95 | FPS at p95 | p99 | FPS at p99 | >33 ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| shw-1 | 4.06 ms | 246.4 | 52.06 ms | 19.2 | 71.96 ms | 13.9 | 12.4% |
| shw-2 | 4.06 ms | 246.2 | 47.13 ms | 21.2 | 63.78 ms | 15.7 | 10.6% |
| **mean** | **4.06 ms** | **246.3** | **49.59 ms** | **20.2** | **67.87 ms** | **14.7** | **11.5%** |
| reference | 3.81 ms | 262.4 | 61.72 ms | 16.2 | 85.50 ms | 11.7 | – |
| delta | +6.6% | −6.1% | **−19.7%** | **+24.7%** | **−20.6%** | **+25.6%** | – |

## 4. Reading it

- Scene A is **within run variation** (6.5–7.4 ms band). The 400-unit draw distance culls almost
  nothing there: the 1,000-tank grid is only ~540×510 world units, so nearly every tank is inside
  400 units. `CosmeticPartition` only affects debris, and this scene has none.
- Scene B gains clearly on the **tail**: p95 61.7 → 49.6 ms (**16.2 → 20.2 FPS**) and p99 85.5 →
  67.9 ms (**11.7 → 14.7 FPS**), while the median is 6% lower (262 → 246 FPS).
- Caveat: the ShockWave runner still sets `ZH_COSMETIC_PARTITION=0` in its test environment
  (`tools/benchmark-shockwave-attrib.ps1`), so the env override disabled that one feature for these
  runs. The tail gain therefore comes from the broadphase default and the draw distance, not from
  the partition skip. A follow-up run with the env removed would measure the full package.

> **Follow-up (EXP-021):** the shipping configuration (partition skip on, T-065 + T-067) measures
> **4.46 ms (224.9 FPS) median, p95 22.23 ms (45.0 FPS), p99 35.12 ms (28.5 FPS)** on the same
> scene, and a same-binary A/B attributes **−21.8% p95 / −19.6% p99** to the partition skip
> (27.33 → 21.37 ms). See [EXP-021](EXP-021-shipping-package-tail.md).

## 5. Artifacts

`artifacts/2026-11-16-defaults-on/` — `stock-1..3`, `shw-1..2`, `conditions.json`, `summary.json`,
`summarize.py`, `manifest.md`.
