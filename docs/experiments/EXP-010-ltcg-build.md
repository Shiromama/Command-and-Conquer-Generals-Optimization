# EXP-010: LTCG as a whole-program build change

> **Status:** complete · **Date:** 2026-11-15 · **Task:** T-052
> **Related:** [T-050 validation report](../research/2026-11-15-low-level-optimization-validation.md) §"Additional bounded opportunities",
> [EXP-009](EXP-009-frame-attribution.md), [ISSUE-0020](../issues/ISSUE-0020-engine-hash-identifies-one-link.md)

## 1. Question

T-050 identified link-time code generation as the cheapest bounded, no-behaviour-change
experiment before any SIMD/threading/Rust work, but it was untested. Does LTCG give a
measurable whole-frame gain on the current engine and scenarios?

## 2. Method

Same source tree, same CMake options (`RTS_BUILD_OPTION_PROFILE=ON`, Tracy 0.13.1), same
toolchain, same game copy, same scenario; the only difference is
`-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON` (MSVC `/GL` on every target, `/LTCG:incremental` at
link).

```powershell
# baseline (already the default build)
.\tools\build-engine.ps1
# LTCG variant
.\tools\build-engine.ps1 -BuildDir build\engine-ltcg `
    -CmakeOptions @{ CMAKE_INTERPROCEDURAL_OPTIMIZATION='ON'; FETCHCONTENT_BASE_DIR='<build>\engine-vs-community\_deps' }
```

Verification that the flag took effect:

```
build\engine-ltcg\GeneralsMD\Code\GameEngine\z_gameengine.vcxproj:
    <WholeProgramOptimization>true</WholeProgramOptimization>
link.command.1.tlog:
    ... /OPT:REF /OPT:ICF /LTCG:incremental /LTCGOUT:...
exe size: 6,753,792 -> 7,813,120 bytes; .text hash changed
```

Runs alternate baseline/LTCG around a fresh stage of the same game copy
(`game/shockwave-engine`, d3d8to9, dGPU, 1920×1080 borderless). Frame times come from
`ZH_PERF_LOG` at present time; the first 30 presented frames are dropped.

## 3. Results

| run | frames | median | mean | p95 | p99 | max | >33.3 ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| nuke1 baseline #1 | 3,690 | 25.64 | 25.99 | 33.65 | 40.95 | 338.00 | 15.8% |
| nuke1 LTCG #1 | 3,690 | 24.98 | 25.74 | 33.55 | 39.94 | 315.92 | 15.7% |
| nuke1 baseline #2 | 3,570 | 26.13 | 26.20 | 33.59 | 39.95 | 339.62 | 17.1% |
| nuke1 LTCG #2 | 3,690 | 24.92 | 25.67 | 33.53 | 39.72 | 321.10 | 15.5% |
| 5-cycle baseline | 3,449 | 33.35 | 42.42 | 85.35 | 131.70 | 332.05 | 52.6% |
| 5-cycle LTCG | 3,809 | 33.33 | 38.27 | 73.72 | 116.77 | 320.66 | 47.7% |

Scenario `nuke1` = 1,000 `ChinaTankBattleMaster`, one real `NeutronMissileDUMMYObject`
warhead. `5-cycle` = the same army respawned five times with nine warheads per cycle.

| Scenario | median | p95 | p99 | mean |
|---|---:|---:|---:|---:|
| nuke1 (2 pairs) | **25.88 → 24.95 ms (−3.6%)** | 33.62 → 33.54 (−0.2%) | 40.45 → 39.83 (−1.5%) | 26.10 → 25.71 (−1.5%) |
| 5-cycle (1 pair) | 33.35 → 33.33 (−0.1%, capped) | **85.35 → 73.72 (−13.6%)** | **131.70 → 116.77 (−11.3%)** | 42.42 → 38.27 (−9.8%) |

## 4. Reading the numbers

- The `nuke1` median gain is consistent (both pairs ≈ −0.7 to −1.2 ms) and is the trustworthy
  result: **~3.6% median frame-time reduction**, about 0.4 FPS at 26 ms.
- The 5-cycle median cannot move because that scenario sits on the 30 FPS cap (33.33 ms is
  exactly the cap). Its p95/p99 improvement (−13.6%/−11.3%) is larger than the median gain and
  plausible for a build that inlines more across translation units, but it comes from a **single
  pair** and is reported as tentative, not established.
- No behavioural difference: same source, same INI, same game data. Only code generation
  changed. (The compiled binary is still not retail-CRC compatible; that constraint is unchanged
  and independent of the build flags.)

## 5. Costs and risks

- Binary grows 6.76 → 7.81 MB (+15.7%); build/link time grows (full LTCG build 222 s here after
  configure, versus ~900 s for a full baseline build — the baseline number includes compiling
  many more TUs, so do not read that as LTCG being faster to build overall).
- Debugging: PDB is still produced, but stepping through inlined code is worse.
- No new runtime dependencies, no config or data change.

## 6. Recommendation

Keep LTCG as an **optional build variant**, not the default: +3.6% median is real but small, and
it should be re-confirmed on a real replay (T-025) before becoming default. The stress-scenario
tail improvement is worth re-measuring with more pairs since it is larger than the median gain.

## 7. Artifacts

- `artifacts/2026-11-15-ltcg-ab/` — six runs, `perf.csv` each, `summary.json`,
  `summarize.py`, `manifest.md`.
- `build/engine-ltcg/` — the LTCG build tree (gitignored).
