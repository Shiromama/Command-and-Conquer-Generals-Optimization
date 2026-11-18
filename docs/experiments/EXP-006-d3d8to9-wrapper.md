# EXP-006: d3d8to9 wrapper A/B

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-033
- **Status:** Complete (optional; not applied)
- **Related:** [EXP-004](EXP-004-architecture-headroom.md), [EXP-005](EXP-005-screen-size-shadow-lod.md), [ISSUE-0010](../issues/ISSUE-0010-heavy-replay-unavailable.md)

## Hypothesis

`d3d8to9` translates the game's Direct3D 8 calls to Direct3D 9. On modern Windows/GPU drivers
this can reduce driver overhead and improve compatibility. It is a third-party DLL, so it was
tested only in `game/engine-test`, never in the real install or pristine baseline.

## Method

| Item | Value |
|---|---|
| Wrapper | `d3d8to9` v1.16.0, `d3d8.dll`, 124,928 bytes |
| SHA-256 | `122928CFE225C25D30DECF7184A5D37E490CECF3B58256BA3206C7E1853F8AB8` |
| Install | copied as `game/engine-test/d3d8.dll` (no existing local DLL) |
| Remove | delete `game/engine-test/d3d8.dll`; the system D3D8 DLL is used again |
| Engine | `game/engine-test/Generals.exe` `7C3CE0AD24D6E8439E7994C923C838DB1EFF92DCE9944F8546B7D1D2A29ABE21` |
| Options | `AntiAliasing = 0`, `StaticGameLOD = Low` |
| Scenario | `northamerica`, 1,000 tanks, 1920x1080, 35 s, steady after 300, uncapped (`ZH_FPS=1000`) |
| Repetitions | 3 native + 3 wrapper |

## Results â€” Low detail (initial, contaminated)

> BlueStacks was running during part of this A/B. The clean re-run matrix is below; use the
> clean numbers for conclusions.

| Run | Native median | Native draw | Wrapper median | Wrapper draw |
|---:|---:|---:|---:|---:|
| 1 | 26.58 | 19.24 | 25.37 | 17.99 |
| 2 | 25.93 | 19.19 | 24.89 | 17.87 |
| 3 | 26.45 | 19.44 | 25.00 | 18.47 |
| **Median** | **26.45** | **19.24** | **25.00** | **17.99** |

- Median frame time: **26.45 â†’ 25.00 ms (5.5% lower)**
- Draw submission: **19.24 â†’ 17.99 ms (6.5% lower)**
- p95: 31.66 â†’ 31.21 ms (1.4% lower)
- No crash or visual difference in the three wrapper runs; screenshot at 39â€“40 FPS.

## Results â€” High detail + 120 px shadow LOD (indicative only)

Native (EXP-005): 30.19 / 29.22 / 29.79 ms; draw 23.00 / 22.33 / 22.85.
Wrapper: 22.62 / 25.74 / 26.16 ms; draw 16.36 / 19.20 / 20.84; p95 30.82 / 39.43 / 40.69.

The first wrapper run is a clear outlier; later runs still beat native on median but show worse
p95. BlueStacks was running an Android game in the foreground during the later High-detail
runs (screenshot `wrapper-high-size120.png`), so these High-detail numbers are **not clean**.
They are recorded as indicative, not as a validated 20%+ gain.

## Clean re-run (all other apps closed)

| Configuration | Median ms | Draw ms | p95 ms | Uncapped FPS |
|---|---:|---:|---:|---:|
| Native Low | 17.47 | 12.78 | 23.06 | 57.2 |
| Wrapper Low | **16.47** | **11.69** | **19.08** | **60.7** |
| Native High + 120 px | 20.30 | 15.20 | 23.57 | 49.3 |
| Wrapper High + 120 px | **18.60** | **13.50** | **21.56** | **53.8** |

- Low: **17.47 â†’ 16.47 ms (5.7% lower)**, draw **12.78 â†’ 11.69 ms (8.5% lower)**
- High + 120 px: **20.30 â†’ 18.60 ms (8.4% lower)**, draw **15.20 â†’ 13.50 ms (11.2% lower)**
- p95 also improves in both cases; no crash in six clean wrapper runs.

## Interpretation

- Clean A/B: wrapper gives a repeatable **5.7%** median gain at Low and **8.4%** at High + 120 px
  shadow LOD, with no crash in six clean runs.
- It does not address the shadow-volume cost by itself; the High gain is still driver-submission
  overhead, on top of the shadow LOD.
- p95 improves too (23.06 â†’ 19.08 Low; 23.57 â†’ 21.56 High), unlike the contaminated runs.
- It is a third-party binary. It may conflict with GenTool's `d3d8.dll` proxy and has community
  reports of VSync/crash issues. It is **not** applied to `game/work`, the baseline, or the real
  installation.

## Recommendation

Keep the native system D3D8 path as the default. Offer `d3d8to9` as an optional, reversible
experiment for copies without GenTool, using the pinned installer:

```powershell
tools\apply-d3d8to9.ps1 -Action Install -GameDir game\engine-test
tools\apply-d3d8to9.ps1 -Action Remove  -GameDir game\engine-test
```

Clean A/B was run with all other apps closed; re-confirm on the target machine before adopting.

## Artifacts

- `artifacts/2026-11-15-d3d8to9/d3d8.dll` (wrapper copy; not tracked)
- `native-run1..3-*`, `wrapper-low-*`, `wrapper-run2/3-*` (initial, partly contaminated)
- `clean-native-low-*`, `clean-wrapper-low-*`, `clean-native-high-size120-*`,
  `clean-wrapper-high-size120-*`, `clean-native-high-nocull-*`, `clean-native-high-noshadow-*`
- `clean-matrix.json`, `wrapper-high-size120-*`, `wrapper-high-size120.png`
- Wrapper removed from `game/engine-test` after the test.

