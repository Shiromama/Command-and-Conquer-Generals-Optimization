# EXP-013: Original vs optimised, side by side

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-056
> **Related:** [EXP-001](EXP-001-msaa-entity-heavy.md), [EXP-003](EXP-003-static-low-detail.md),
> [EXP-006](EXP-006-d3d8to9-wrapper.md), [EXP-008](EXP-008-shockwave-nuke-performance.md)

## 1. Question

What does the game actually gain from the optimised profile, measured on the same machine, same
scene, same engine build, same resolution — with only the settings profile changed?

## 2. What "original" and "optimised" mean here

| | Profile | Contents |
|---|---|---|
| **Original** | `default` | Anti-aliasing 8× + High detail — the retail-equivalent settings |
| **Optimised** | `performance` | Anti-aliasing off + Low detail (the project's recommended profile) |

Both columns run the **same binary** (engine `4942093F…76E8`), the same game copy, the same map,
the same harness scene and the same window mode. Our engine patches are off or opt-in by default,
so the original column is the retail-equivalent rendering path; the only difference is the options
profile.

**Why not the retail `Generals.exe` itself:** the 1,000-unit harness (`ZH_STRESS`) is compiled
only into the rebuilt engine, and the retail binary has no frame logger. A retail process cannot
be given the same scene, so a direct retail-vs-optimised run would compare two different scenes.
The retail-equivalent *settings* are the fairest controllable condition.

## 3. Setup

- Engine: `4942093F780F8A130E0985CD8B1AA895CCABE0E896E82DAA3C1CDEC74C4776E8` (all patches, no
  patch changes during the run).
- Resolution 1920×1080, borderless. Same map (`northamerica`), same camera, same spawner.
- **Scene A:** stock-ZH copy, 1,000 `AmericaTankCrusader`, 40 s, system D3D8. Run capped (default
  30 FPS) and with a 240 FPS limit (`ZH_FPS=240`), three alternating pairs each.
- **Scene B:** ShockWave copy (d3d8to9 + dGPU), 1,000 `ChinaTankBattleMaster`, five spawn/nuke
  cycles with nine real warheads, 90 s, two alternating pairs.
- Frame times from `ZH_PERF_LOG`; draw/logic from `ZH_PERF_SPLIT`; first 30 presented frames dropped.

## 4. Results

### How to read the tables

| Label | Meaning |
|---|---|
| **Original (AA 8 + High)** | The same rebuilt engine with 8× anti-aliasing and High detail. Anti-aliasing smooths jagged edges. |
| **Optimised (AA 0 + Low)** | The same rebuilt engine with anti-aliasing off and Low detail. |
| **Scene A / Scene B** | A is the stock Zero Hour test with 1,000 tanks. B is the ShockWave test with 1,000 units spawned per cycle over five spawn-and-nuke cycles. |
| **Alternating pairs** | One run per profile in each pair, alternating Original and Optimised. |
| **Capped / uncapped** | The capped runs target a maximum of 30 rendered frames per second, or about 33.3 ms per frame. The first high-limit run used `ZH_FPS=240`. Section 5 repeats the comparison with the cap disabled. |
| **Median / mean / worst** | The middle, average, and slowest measured frame times, in milliseconds (ms). |
| **p95 / p99** | Frame times at the 95th and 99th percentiles. About 5% and 1% of frames took longer, respectively. These columns show slow frames that the median can hide. |
| **FPS** | Frames per second at the reported median frame time, calculated as `1,000 ÷ median ms`. |
| **Draw / logic** | Median time in the measured rendering call and game simulation update, respectively. Each phase is timed separately from the full frame. |
| **Frames > 33 ms** | Share of frames taking longer than 33 milliseconds. |
| **Difference** | Change from Original to Optimised. Negative percentages mean less time. A speedup ratio divides the Original median frame time by the Optimised median. |

Lower frame times are better. Higher FPS is better.

### Scene A — 1,000 tanks, 240 FPS limit

| Profile | Median (ms) | FPS | p95 (ms) | p99 (ms) | Draw (ms) | Logic (ms) |
|---|---:|---:|---:|---:|---:|---:|
| **Original** (AA 8 + High) | **25.04 ms** | 39.9 | 30.35 | 47.37 | 14.49 | 6.8 |
| **Optimised** (AA 0 + Low) | **7.48 ms** | 133.7 | 8.99 | 13.17 | 1.85 | 3.3 |
| Difference | **3.35× faster** | | −70.4% | −72.2% | 7.8× less | 2× less |

Run-to-run spread is tight: original 25.24 / 25.26 / 24.62 ms, optimised 7.51 / 7.48 / 7.45 ms.

### Scene A — same scene, default 30 FPS cap

| Profile | Median (ms) | p95 (ms) | p99 (ms) |
|---|---:|---:|---:|
| Original | 33.35 | 34.90 | 53.28 |
| Optimised | 33.37 | 34.07 | 35.48 |

Both runs hit the 30 FPS cap. The median stays near 33.3 ms, while p99 falls by 33%.
The 240 FPS limit leaves enough headroom for the change to show up in the median.

### Scene B — 1,000 tanks ×5 spawn/nuke cycles (ShockWave, capped)

| Profile | Median (ms) | Mean (ms) | p95 (ms) | p99 (ms) | Worst (ms) |
|---|---:|---:|---:|---:|---:|
| Original | 33.43 | 74.42 | **214.19** | **248.76** | 435.70 |
| Optimised | 35.19 | 48.07 | **84.50** | **141.37** | 337.30 |
| Difference | +5.3% | −35% | **−60.5%** | **−43.2%** | −23% |

On the heavy combat scene the median is cap-bound in both, so the gain shows up as tail latency:
the worst frames drop from ~215–249 ms to ~85–141 ms. The median is slightly worse in this pair
(35.19 vs 33.43) because the optimised runs occasionally pull away from the cap.

## 5. Uncapped re-run (T-058) — the definitive numbers

The table in §4 used the harness `ZH_FPS=240`. After fixing the engine's real uncap path
(`ZH_NOFPSLIMIT`, ISSUE-0022), the whole comparison was repeated **uncapped on both sides**, same
build `71FEA54D…0E8E`, same scene, 3 alternating pairs (Scene A) and 2 (Scene B):

| Scene A (1,000 tanks) | Median (ms) | FPS | p95 (ms) | p99 (ms) | Frames > 33 ms |
|---|---:|---:|---:|---:|---:|
| **Original** (AA 8 + High) | **21.86 ms** | 45.7 | 27.12 | 40.4 | 2.8% |
| **Optimised** (AA 0 + Low) | **6.47 ms** | 154.5 | 8.26 | 12.4 | 0.1% |
| Difference | **3.38×** | | −69.5% | −69% | |

Per-run medians: original 21.78 / 21.39 / 22.42 ms, optimised 6.41 / 6.45 / 6.55 ms.

| Scene B (1,000 ×5 cycles, 9 warheads) | Median (ms) | FPS | p95 (ms) | p99 (ms) | Frames > 33 ms |
|---|---:|---:|---:|---:|---:|
| Original | 8.62 ms | 116.0 | **177.37** | ~216 | 13.9% |
| Optimised | 4.33 ms | 231.2 | **61.59** | ~84 | 12.4% |
| Difference | **1.99×** | | **−65.3%** | −61% | |

In the nuke scene most frames are cheap (8.6 vs 4.3 ms) but the spawn/death spikes drive p95,
which is where the optimisation actually shows: 177 → 62 ms.

Evidence: `artifacts/2026-11-16-uncapped-ab/` (`summary.json`, `summarize.py`, `manifest.md`).

### 5.1 Re-run on the final engine (T-062)

The same two scenarios were repeated on engine `DCF51A29…2839` after all the diagnostic work, to
confirm the numbers did not drift:

| Scenario | Runs | Median (ms) | FPS | p95 (ms) | p99 (ms) | Frames > 33 ms |
|---|---:|---:|---:|---:|---:|---:|
| stock 1,000 tanks, uncapped | 3 | **7.81 ms** | 128.0 | 9.38 | 13.02 | 0.1% |
| ShockWave 1,000 ×5 cycles, uncapped | 2 | **4.18 ms** | 239.4 | 63.01 | 92.13 | 10.5% |

The ShockWave result reproduces the table above (4.18 vs 4.33 ms median, 63.0 vs 61.6 ms p95). The
stock median sits at the top of the 6.3–7.8 ms session band for that scenario. Evidence:
`artifacts/2026-11-16-rerun-1000/`.

### 5.2 Clean re-run (background apps closed)

That run was taken while Edge/WebView2/Teams were still active (recorded: `msedge=6`,
`msedgewebview2=13`, `ms-teams=2`, free 11.1 GB, CPU load 36%). It was repeated with the same
engine and profile after the user closed the rest of their work:

| Scenario | Runs | Median (ms) | FPS | p95 (ms) | p99 (ms) | Frames > 33 ms |
|---|---:|---:|---:|---:|---:|---:|
| stock 1,000 tanks, uncapped | 3 | **6.62 ms** | 151.1 | 7.96 | 11.13 | 0.1% |
| ShockWave 1,000 ×5 cycles, uncapped | 2 | **3.81 ms** | 262.4 | 61.72 | 85.50 | 9.8% |

Per-run: stock 6.91 / 6.46 / 6.50 ms, ShockWave 3.65 / 3.98 ms.

The difference from §5.1 is background load, not the engine: stock 7.81 → 6.62 ms (−15%,
p95 9.38 → 7.96), ShockWave 4.18 → 3.81 ms (p95 63.01 → 61.72). **Use this table as the final
reference for engine `DCF51A29…2839`.** Evidence: `artifacts/2026-11-16-rerun-1000-clean/`.

## 6. Caveats

- These are **same-session** ratios. Absolute milliseconds differ from older records (e.g. EXP-003
  reported 18.45 ms draw at Low; today's draw is 1.85 ms), so use the ratio, not the absolute
  number, when comparing across sessions — GPU state, driver and background load changed.
- The capped runs are useless for comparing throughput; they are included to show why.
- Scene B has two pairs only; the p95/p99 gap is large and consistent (216/212 vs 86/83 ms) but the
  median difference is within noise.
- The adapter change (d3d8to9 → dGPU) is inside both Scene B columns; its own gain
  (26.09 → 19.66 ms, EXP-008) is separate and additional for profiles that use the wrapper.

## 7. Answer in one line

With identical scene and conditions, the optimised profile is **3.35× faster at 1,000 units**
(25.04 → 7.48 ms, ~40 → ~134 FPS with a 240 FPS limit), and on the heavy nuke scene it cuts
p95 by **~60%** (214 → 85 ms) while the median stays near the 30 FPS cap.

## 8. Artifacts

- `artifacts/2026-11-16-original-vs-optimized/` — `A-*`, `A-uncapped-*`, `B-*` run folders,
  `summary.json`, `summarize.py`, `manifest.md`.
- Runner: `tools/run-original-vs-optimized.ps1`; `tools/benchmark-entity-heavy.ps1 -MaxFps`.
