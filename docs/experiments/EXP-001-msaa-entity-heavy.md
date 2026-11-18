# EXP-001: MSAA cost in the entity-heavy benchmark

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-015, T-024
- **Status:** Complete

## Hypothesis

The user's `options.ini` has `AntiAliasing = 14`. The parser clamps it to 8× MSAA
(`OptionPreferences.cpp:70-80`, `ww3d.cpp:2031-2049`). In a 1,000-unit scene, 8× MSAA is the
dominant render cost; disabling it should produce a large, repeatable frame-time improvement.

## Baseline

| Item | Value |
|---|---|
| Engine | Source build with benchmark harness (`engine/patches/T-015-benchmark-harness.patch`) |
| Launch | `Generals.exe -win -quickstart -xres 1920 -yres 1080` |
| Scenario | `maps\northamerica\northamerica.map`, 1,000 `AmericaTankCrusader` units |
| Hooks | `ZH_MAP`, `ZH_STRESS=1000`, `ZH_PERF_LOG`, `ZH_PERF_SPLIT` |
| Settings | 1920×1080, High LOD, 5000 particles, shadows on, AA 14 (8×) |
| Repetitions | 3 × 40 s; steady state = frames after the first 300 |

## Baseline results (AA 14 → 8×)

| Run | Frames | Steady frames | Median ms | p95 ms | p99 ms |
|---:|---:|---:|---:|---:|---:|
| 1 | 600 | 300 | 59.41 | 67.02 | 81.10 |
| 2 | 480 | 180 | 62.62 | 69.19 | 87.98 |
| 3 | 600 | 300 | 58.57 | 66.33 | 86.55 |

Split timing (one run): `client` median 51.87 ms, `draw` median 50.32 ms, `logic` median
4.49 ms. The cost is render submission, not simulation.

## Variant results

| AA setting | Effective mode | Median ms | Draw median ms | Runs |
|---:|---|---:|---:|---|
| 14 | 8× MSAA | 59.41–62.62 | 50.32 | 3 |
| 4 | 4× MSAA | 48.39 | 39.44 | 1 |
| 2 | 2× MSAA | 45.01 | 36.11 | 1 |
| 0 | off | 34.76–36.50 | 27.26 | 3 |

Optimized (AA 0) runs:

| Run | Median ms | p95 ms | p99 ms |
|---:|---:|---:|---:|
| 1 | 34.76 | 39.45 | 44.86 |
| 2 | 35.05 | 40.20 | 46.38 |
| 3 | 36.50 | 41.95 | 43.81 |

Median-of-medians: **59.41 ms → 35.05 ms (1.70×)**; effective FPS **16.8 → 28.5** at 1,000
units. p95: 67.02 → 40.20 ms.

## Result

Supported. The AA setting is the dominant controllable cost in this scene. The fix is applied
as a portable profile (`tools\apply-options-profile.ps1 -Profile performance`), with the original
Options.ini backed up before the change.

## Interpretation / limits

- This is a settings optimization, not a code path change. `AntiAliasing = 14` was
  unintentionally selecting 8× MSAA; users who want AA can use the `balanced` profile (2×).
- The 30 FPS cap means the optimized scene is still below 30 FPS at exactly 1,000 units.
- The test scene places all 1,000 units in view; real late-game scenes have off-screen units
  and different costs. The improvement should be re-confirmed on a real late-game replay.
- Source-level follow-up: clamp/reject unsupported AA values and expose a performance default.

## Artifacts

- `artifacts/2026-11-14-engine-build-test/baseline-1000-run1.csv` … `run3.csv`
- `artifacts/2026-11-14-engine-build-test/optimized-aa0-run1.csv` … `run3.csv`
- `artifacts/2026-11-14-engine-build-test/split2-phases.csv`
- `artifacts/options-backups/options-2026-11-15-005413.ini` (pre-change Options.ini)
