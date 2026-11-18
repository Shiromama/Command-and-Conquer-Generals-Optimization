# Engine build and fullscreen results â€” 2026-11-14

- **Date:** 2026-11-14
- **Author/agent:** lead
- **Tasks:** T-014, T-015, T-017, T-023
- **Status:** Build/DPI/fullscreen verified; entity-heavy benchmark and first optimization measured

## Summary

- The GPLv3 source builds successfully with VS2022 Community (MSVC 14.43 + ATL), Win32,
  `z_generals` â†’ `generalszh.exe`.
- The rebuilt engine launches against the real game data with the **system** `d3d8.dll`.
- GenToolâ€™s proxy causes an immediate `0xC0000005` with the rebuilt exe; staging now disables
  it by default (ISSUE-0008).
- A DPI-awareness patch makes the process per-monitor aware: borderless and exclusive both
  report a **1920Ã—1080 client area** (previously 1536Ã—864 at 125% scaling).
- Exclusive fullscreen works and survived two Alt+Tab cycles.
- A frame logger patch writes `frame,frame_ms` when `ZH_PERF_LOG` is set.
- The available replay stays at the 30 FPS cap; the 1v8 replay hangs black.
- The test-only `ZH_MAP` + deferred `ZH_STRESS` harness produced a repeatable 1,000-unit scene:
  baseline median 58.57-62.62 ms; `AntiAliasing = 14` was clamped to 8x MSAA.
- The portable performance profile (AA 0) measured **59.41 -> 35.05 ms median (1.70x)**;
  full method/results in `../experiments/EXP-001-msaa-entity-heavy.md`.

## Build evidence

```
CMAKE_CXX_COMPILER: .../2022/Community/VC/Tools/MSVC/14.43.34808/bin/Hostx64/x86/cl.exe
CMAKE_CXX_COMPILER_VERSION: 19.43.34808.0
Target: z_generals
Output: build/engine-vs-community/GeneralsMD/Release/generalszh.exe
BUILD_EXIT=0
```

First attempt used BuildTools 14.42 and failed with:
`PreRTS.h(47): error C1083: cannot open 'atlbase.h'`.
ATL was already present in Community 14.43; reconfiguring with
`-DCMAKE_GENERATOR_INSTANCE=...Community -T v143` fixed it without installing anything.

## Fullscreen evidence

DPI-aware query (Python process with `SetProcessDpiAwarenessContext`):

| Mode | Process awareness | Client | Window |
|---|---|---|---|
| borderless (`-win`) | 2 (per-monitor) | **1920Ã—1080** | `-9,-38 1938Ã—1127` |
| exclusive (`-fullscreen`) | 2 (per-monitor) | **1920Ã—1080** | `0,0 1920Ã—1080` |

Alt+Tab twice in exclusive mode: process remained alive, same title/handle.

Without the DPI patch, the process reported 1536Ã—864 client at 125% scaling; the patch is
required for 1:1 output.

## Frame timing evidence

`ZH_PERF_LOG` CSV, `00000000.rep`, borderless, 180 s:

```
n=5280  median=33.35 ms  p95=34.31 ms  p99=36.25 ms  max=245.26 ms
30-second windows: median 33.33â€“33.39 ms throughout
```

That is the 30 FPS cap; the replay does not create an entity-heavy load.

## Benchmark attempts

| Scenario | Result |
|---|---|
| `00000000.rep` | Runs; pinned at ~30 FPS for 180 s |
| `1v8 niggas.rep` (map `Last Stand` present) | Black window, no frames, no log |
| `allbuildingsallsidesunittest_save.map` | Loads two command centers; no heavy scene |
| `art review new units.map` | Loads to an empty/black area; no heavy scene |
| `ZH_MAP` auto-start + `ZH_STRESS` | Finds a valid team/template, but returns to the menu; no playable heavy scene |
| Debug UI + deferred `ZH_STRESS` | Map list stayed open on the retry; no playable match; reverted |
| Saves in `Documents\...\Save` | 186â€“765 bytes; not late-game |

## Changes

- `engine/patches/T-023-dpi-awareness.patch` â€” per-monitor DPI awareness at WinMain.
- `engine/patches/T-015-frame-logger.patch` â€” optional CSV frame logger.
- `tools/build-engine.ps1` â€” reproducible configure/build; uses the Community instance/ATL.
- `tools/stage-engine.ps1` â€” isolated `game/engine-test` copy, retail-exe backup, GenTool
  disabled by default, hash record.
- `docs/issues/ISSUE-0008`, `ISSUE-0009`.

## Limitations / next

- GenTool compatibility with rebuilt exes is unresolved.
- The entity-heavy scenario is still missing; request a late-game replay/save or implement a
  stress-spawn harness.
- Tracy is linked but the profiler GUI/capture is not yet built; current measurement uses the
  frame logger.
- The build is a profile build (`RTS_PROFILE_LEGACY` + Tracy); a plain Release A/B should be
  built before drawing performance conclusions.

## Artifacts

- `artifacts/2026-11-14-engine-build-test/dpi-query.json` â€” DPI/mode measurements.
- `artifacts/2026-11-14-engine-build-test/perf-long-replay.csv` â€” frame times.
- `artifacts/2026-11-14-engine-build-test/alt-tab-test.json` â€” Alt+Tab result.
- `artifacts/2026-11-14-engine-build-test/1v8-retry.png` â€” black replay evidence.
- `artifacts/2026-11-14-engine-build-test/main-menu.png`, `units-map.png` â€” UI evidence.






