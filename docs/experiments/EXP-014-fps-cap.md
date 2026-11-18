# EXP-014: Removing the FPS cap — what it actually buys

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-057
> **Related:** [EXP-013](EXP-013-original-vs-optimized.md), [ISSUE-0022](../issues/ISSUE-0022-launcher-nofpslimit-noop.md)

## 1. Question

The engine renders at 30 FPS by default. If the cap is removed in the game itself (not just for a
benchmark), what changes — frame rate, smoothness, cost?

## 2. How the cap works

| Piece | Fact |
|---|---|
| Cap value | `TheGlobalData->m_useFpsLimit` + `FramePacer::m_enableFpsLimit`; preset list 30, 50, 56, 60, 65, …, 120, 144, 240, 480, Uncapped (`FrameRateLimit.cpp:69`) |
| Default | 30 FPS, applied at `GameMain.cpp:44` / `GameEngine.cpp:652` |
| Command line | `-noFPSLimit` (`CommandLine.cpp:1054`) and `-fps <n>` (`:1310`) |
| In game | `Ctrl + Numpad +` / `Ctrl + Numpad -` cycles the presets (`MetaEvent.cpp:810`); the HUD shows `▲30` … `▲X` for uncapped |
| INI | `UseFPSLimit` / `FramesPerSecondLimit` in GameData (`GlobalData.cpp:82`) |
| Simulation | Logic stays at 30 Hz (`LOGICFRAMES_PER_SECOND`); the pacer exposes `m_logicFramePhase` so rendering **interpolates** between logic frames |

So uncapping is a real, supported feature of this engine, not a hack — and it affects smoothness,
not simulation.

## 3. Sweep: same scene, same profile, only the cap changes

1,000 tanks, optimised profile (AA 0 + Low), 40 s runs, `ZH_FPS` fixed per run (test harness):

| Cap | median | FPS | p95 | p99 | frames > 33.3 ms |
|---:|---:|---:|---:|---:|---:|
| 30 (default) | 33.37 ms | 30.0 | 34.44 | 36.91 | **53.6%** |
| 60 | 16.65 ms | 60.0 | 17.62 | 20.42 | 0.3% |
| 120 | 8.31 ms | 120.4 | 9.24 | 10.67 | 0.0% |
| 240 (≈ uncapped) | **6.25 ms** | **160.1** | 7.32 | 10.30 | 0.1% |

The renderer can sustain ~160 FPS on this scene at Low detail; the 30 FPS cap was leaving 5× of
the hardware idle.

## 4. Verification of the in-game flag (not the harness variable)

Two launches through `tools/launch-game.ps1` on the same copy and scene, the only difference being
the new `-NoFPSLimit` switch (the launcher prints `FPS : uncapped for profiling (harness build)`):

| Launch | frames in 28 s | median | p95 | p99 |
|---|---:|---:|---:|---:|
| default (capped) | 689 | 33.36 ms (30.0 FPS) | 33.96 | 34.40 |
| `-noFPSLimit` | 2,730 | **9.58 ms (104.4 FPS)** | 12.27 | 13.88 |

`ZH_FPS` was explicitly unset for both, so this is the engine's own option doing the work.

## 5. What it changes, what it does not

- **Smoother:** the renderer interpolates between 30 Hz logic frames, so unit motion and camera
  panning are visibly smoother above 30 FPS.
- **Not faster gameplay:** aiming, pathing, damage and build timers still tick 30 times per second.
  Frame rate does not change simulation results, and it cannot be used to gain an advantage in a
  match (and retail online play stays stock anyway).
- **Cost:** at 30 FPS the GPU is ~20% busy on this scene; uncapped it renders continuously. That is
  more heat, fan and power for the same simulation. On weaker hardware, uncapping a heavy scene
  will just sit at the hardware's own limit (no gain).
- **No tearing change:** the engine does not add vsync by uncapping; present behaviour is unchanged.

## 6. Cap x profile matrix (measured and derived)

Frame time is the larger of the cap interval and the profile's own work, so the two measured
curves (original 25.04 ms uncapped in EXP-013; optimised 6.25/8.31/16.65 ms at 240/120/60 in §3)
determine every other cell. `M` = measured, `D` = derived by that rule.

| Cap | Original (AA 8 + High) | Optimised (AA 0 + Low) | Speed-up |
|---:|---|---|---:|
| 30 (default) | 33.35 ms (30.0 FPS) `M` | 33.37 ms (30.0 FPS) `M` | 1.00× — both cap-bound |
| 60 | 25.04 ms (39.9 FPS) `D` (work-bound) | 16.65 ms (60.0 FPS) `M` | 1.50× |
| 120 | 25.04 ms `D` | 8.31 ms (120 FPS) `M` | 3.01× |
| uncapped | 25.04 ms (39.9 FPS) `M` | 6.25 ms (160 FPS) `M` / 7.48 ms `M` | 3.35–4.00× |

The original profile cannot reach 60 FPS on this scene (it needs 25.04 ms), so from 30 → 60 the cap
only shortens the *optimised* frame; the gap widens as the cap rises. The uncapped optimised cell
has two measured values from two sessions (6.25 and 7.48 ms, ~20% apart); the honest headline is
**3.3–4.0×**, not a single figure.

## 7. Recommendation
- **60 FPS cap** is the best *gameplay* balance on this hardware (99.7% of >33 ms frames removed at
  about half the GPU time of uncapped).
- **Uncapped is the default for our own tooling** (T-058): `tools/launch-game.ps1`,
  `tools/benchmark-entity-heavy.ps1` and the ShockWave runner now pass `-noFPSLimit` unless you ask
  for a cap (`-WithFpsLimit`, `-MaxFps`). Benchmarks are more informative uncapped, and a capped
  run cannot show throughput gains at all (§3).
- For normal play, choose per session: `Ctrl+Numpad+` for smoothness, `Ctrl+Numpad-` for quiet.
  This is a preference, not a correctness or performance fix, and the retail/online profile
  cannot use it.

## 8. Artifacts

- `artifacts/2026-11-16-fps-cap-sweep/` — `cap-30/60/120/240` (harness sweep),
  `launcher-capped/`, `launcher-nolimit/` (engine-flag verification), `summarize.py`.
- Tools changed: `tools/launch-game.ps1` (`-NoFPSLimit` now applied — ISSUE-0022),
  `tools/play-shockwave-performance.ps1` (`-UnlockFps`).
