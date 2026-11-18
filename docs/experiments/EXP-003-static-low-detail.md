# EXP-003: Low detail preset for visibility-preserving draw cost

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-028
- **Status:** Complete (profile applied)
- **Related:** [EXP-001](EXP-001-msaa-entity-heavy.md), [EXP-002](EXP-002-scene-distance-cull.md), [ISSUE-0006](../issues/ISSUE-0006-entity-performance.md)

## Hypothesis

After anti-aliasing is off, draw submission is still ~27 ms at 1,000 units. The engine's
built-in **Low** detail preset (`StaticGameLOD = Low`) disables shadow volumes/decals,
lightmaps/cloud maps, heat effects, tree sway, and soft water edges, and lowers the particle
budget. Unlike the distance cull, it **does not remove units**, so if those render passes are
the cost, Low detail should reduce draw time while keeping every entity visible.

## Method

| Item | Value |
|---|---|
| Engine | `game/engine-test/Generals.exe`, SHA-256 `5CF4EA0717FE38A11A1CB1007C6DA930D3BC75EA468CFC59E601CFFBAB1160F0` |
| Options | `performance` profile: `AntiAliasing = 0`, `StaticGameLOD = Low`, `IdealStaticGameLOD = Low` |
| Launch | `-win -quickstart -xres 1920 -yres 1080` |
| Scenario | `ZH_MAP=maps\northamerica\northamerica.map`, `ZH_STRESS=1000` |
| Hooks | `ZH_PERF_LOG` (frame CSV), `ZH_PERF_SPLIT` (draw/logic), no `ZH_DRAWDIST` |
| Repetitions | 3 × 40 s; steady state = frames after the first 300 |
| Runner | `tools/benchmark-entity-heavy.ps1 -Runs 3 -ApplyProfile performance` |

The Low preset is applied through `tools/apply-options-profile.ps1`, which backs up
Options.ini first. No game binary, archive, or installation file is modified.

## Baseline (EXP-001: AA 0, High detail)

| Run | Median ms | p95 ms | p99 ms |
|---:|---:|---:|---:|
| 1 | 34.76 | 39.45 | 44.86 |
| 2 | 35.05 | 40.20 | 46.38 |
| 3 | 36.50 | 41.95 | 43.81 |

Draw median **27.26 ms**; logic median **4.49 ms**.

## Results (AA 0, Low detail)

| Run | Frames | Median ms | p95 ms | p99 ms | Draw median ms | Logic median ms |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 780 | 33.31 | 36.67 | 42.50 | 18.09 | 5.71 |
| 2 | 780 | 33.36 | 36.94 | 43.09 | 19.14 | 5.89 |
| 3 | 780 | 33.39 | 36.85 | 38.78 | 18.45 | 5.74 |

Run median: **33.36 ms**; p95 **36.85 ms**; draw **18.45 ms**; logic **5.74 ms**.

## Comparison

| Metric | AA 0 / High | AA 0 / Low | Change |
|---|---:|---:|---:|
| Median frame time | 35.05 ms | 33.36 ms | **4.8% lower** |
| p95 frame time | 40.20 ms | 36.85 ms | **8.3% lower** |
| Draw median | 27.26 ms | 18.45 ms | **32.3% lower** |
| Effective FPS | 28.5 | 30.0 | 30 FPS cap |

Against the original settings (AA 14 → 8× MSAA, High detail): median **59.41 → 33.36 ms
(1.78×)**, effective FPS **16.8 → 30.0**.

This matches the opt-in distance cull (median 33.30 ms, draw 18.1 ms) **without hiding any
units**, so Low detail is the better general profile. The cull remains available for systems
that need more headroom.

## Visual verification

`static-low-clean.png` was captured during run 3: the 1,000 Crusaders are all rendered, the
in-game counter shows 30 FPS, and the control bar/minimap are intact. Shadows, lightmaps, and
heat effects are reduced by the Low preset; entity geometry and counts are unchanged.

## Measurement note

An earlier 3-run set was captured while background source searches were running. One run
showed p95 53.93 ms / p99 66.32 ms, inconsistent with its 33.42 ms median, so the whole set
was discarded and re-captured undisturbed. Only the clean set above is used.

## Limits / follow-ups

- Low detail is a visual-quality tradeoff (no shadows/lightmaps/heat effects, fewer particles).
  It does not affect simulation or replay determinism; it is a rendering preset.
- `balanced` (AA 2 + Medium detail) is wired in the profile tool but **not measured** yet.
- Real playback compatibility was checked with the upstream `-loadreplay` switch.
  `00000000.rep` loads but needs `-ignoreReplaySyncErrors`; it then plays at the 30 FPS cap
  (median 33.32 ms, p95 36.00 ms), but it is early-game. The heavy `1v8 niggas.rep` is rejected
  as invalid, so real **late-game** validation remains blocked under ISSUE-0010 (T-025).
- The remaining draw submission cost needs source-level batching or a spatial index
  (T-020/T-021) for a fix that keeps High detail.

## Artifacts

- `artifacts/2026-11-15-static-lod/clean-frames-run1.csv` … `run3.csv`
- `artifacts/2026-11-15-static-lod/clean-split-run1.csv` … `run3.csv`
- `artifacts/2026-11-15-static-lod/clean-three-runs.json`
- `artifacts/2026-11-15-static-lod/comparison.json`
- `artifacts/2026-11-15-static-lod/static-low-clean.png`
- `artifacts/options-backups/options-2026-11-15-011459.ini` (AA 0 / High, pre-Low)
- `artifacts/options-backups/options-2026-11-15-005413.ini` (original AA 14 / High)
- `artifacts/2026-11-15-replay-retry/manifest.md` (real playback compatibility; heavy replay invalid)
