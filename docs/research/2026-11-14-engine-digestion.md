# Engine digestion: binary, source, and community findings — 2026-11-14

- **Date:** 2026-11-14
- **Author/agent:** lead
- **Tasks:** T-009, T-014, T-015, T-017, T-020…T-023
- **Status:** Draft (static analysis complete; runtime profiling pending)

## Question

Where does Zero Hour actually spend time with many entities, which inefficiencies are visible
at the binary/source level, and which known community fixes apply to this 1.04 + GenTool
installation?

## Answer (short)

The engine has two separate scaling problems:

1. **Render/UI-side O(N) scans** — every drawable is iterated per view, culled, updated, and
   given icons; the projected-shadow and behind-building passes add more full-scene work.
2. **Logic-side pathfinding** — a sorted linked-list open list with O(n) insertion and a
   retail 30,000-cell allocation cap; community measurements put pathfinding at up to 80% CPU
   in large free-for-alls.

The 30 FPS story is also more specific than "capped at 30": the source has a decoupled
render/logic loop, but the release logic-time-scale preset cannot go below 30 FPS
(`FrameRateLimit.h:67-71`). Most community "performance flags" are debug-only.

## Binary-level facts

`Generals.exe` = `game.dat`, SHA-256 `F37A4929…D344495B`:

| Property | Value |
|---|---|
| Format | PE32, x86, image base `0x400000`, entry `0x4E0778` |
| Build timestamp | 2005-03-10 (1.04 era) |
| Sections | 5; `.text` 5.47 MB, entropy 6.68 — **not packed** |
| Characteristics | `0x010F` — **not Large Address Aware** |
| DllCharacteristics | `0` — no ASLR/NX declaration |
| Imports | MSVCRT (138), KERNEL32 (90), USER32, GDI32, DINPUT8, mss32, binkw32 |
| D3D8 | **No static import**; loaded via `LoadLibrary("D3D8.DLL")` at `dx8wrapper.cpp:317-321` |

Consequences: a 2 GB address space, old CRT allocation, and a dynamic D3D8 entry point that
can be proxied. A Rust component should chainload as `d3d8x.dll` (GenTool’s documented proxy
hook) rather than replace `d3d8.dll`.

## Source hotspots

| # | Subsystem | Evidence | Scaling |
|---|---|---|---|
| 1 | Drawable region scan | `Core/GameEngineDevice/Source/W3DDevice/GameClient/W3DView.cpp:1688-1689`; `GeneralsMD/.../GameClient.cpp:801-818` | Every drawable per view per frame; explicit `@todo` region partition |
| 2 | Per-drawable client update | `GeneralsMD/.../GameClient.cpp:634-684` | Full draw-module update + shroud status per drawable per render frame |
| 3 | Scene cull | `GeneralsMD/.../W3DScene.cpp:396-537` | O(N) frustum test/bucketing every frame |
| 4 | Pathfinding A* | `Core/GameEngine/Source/GameLogic/AI/Pathfinder/PathfindCell.cpp:485-650` | Sorted linked-list insertion; O(n) insert, ~O(n²)/path |
| 5 | Particle sort | `Core/Libraries/Source/WWVegas/WW3D2/sortingrenderer.cpp:324-337` | Linear insert per translucent poly; explicit `@todo bucket sort` |
| 6 | Projected shadows | `W3DProjectedShadow.cpp:324-343,1315-1373` | Per-shadow terrain triangulation/texture update |
| 7 | Behind-building pass | `W3DScene.cpp:1344-1409`; default `TRUE` (`GlobalData.cpp:665`) | Extra scene pass |
| 8 | Partition contacts | `GeneralsMD/.../PartitionManager.cpp:2501-2511,2768-2816` | O(contact-list) removal → quadratic on mass death |
| 9 | Particle update | `ParticleSys.cpp:3246-3302` | Two full passes, second rebuilds smudges |
| 10 | Per-drawable icons | `Drawable.cpp:2731-2778` | Health/ammo/veterancy UI per visible drawable |

Pathfinding constants:

- `PATHFIND_QUEUE_LEN = 512`, `PATHFIND_CELLS_PER_FRAME = 5000`
  (`PathfindConstants.h:22,44`).
- `CELL_INFOS_TO_ALLOCATE = 30000` (`PathfindCellInfo.cpp:22`).
- Source comment: reverse insertion sorting reduced pathfinding overhead by 50–66%
  (`PathfindCell.cpp:646-650`).
- Retail-compatible pathfinding/allocation can be disabled in source
  (`GameDefines.h:133-139`), but that changes logic CRCs and is unsafe for multiplayer.

## Timestep and flags

| Fact | Evidence |
|---|---|
| Render/logic decoupled with an accumulator | `GameEngine.cpp` loop; `GameCommon.h:66-67` |
| Release logic-time scale floor = 30 FPS | `FrameRateLimit.h:67-71` |
| `timeBeginPeriod(1)` + Sleep-based pacing | `FramePacer.cpp:36`, `FrameRateLimit.cpp:46` |
| `-lowDetail`, `-noDynamicLOD`, `-noStaticLOD`, `-fps`, `-noshadowvolumes`, `-nofx`, `-noFPSLimit` | **Debug-only**, `CommandLine.cpp:1299-1345` |
| `-win`, `-fullscreen`, `-xres`, `-yres`, `-forcefullviewport`, `-quickstart` | Work in release |
| Runtime INI knobs | `UseBehindBuildingMarker`, `MaxTranslucentObjects`, `UseFPSLimit`, `FramesPerSecondLimit` (`GlobalData.cpp:83-109,317`) |

## Community fixes that apply

| Item | Status | Relevance |
|---|---|---|
| [PR #3656](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3656) back-buffer format | Open | Fullscreen reset loop |
| [#28](https://github.com/TheSuperHackers/GeneralsGameCode/issues/28) + #801/#846 Alt-Tab reset | Merged | Fullscreen stability |
| [#3049](https://github.com/TheSuperHackers/GeneralsGameCode/issues/3049) 200 ms device-lost sleep | Open | 5–8 FPS after mode changes |
| [#100](https://github.com/TheSuperHackers/GeneralsGameCode/issues/100) 30k pathfind cap | Open | Unit pile-ups |
| [PR #3198](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3198) pathfind opts | Merged | Already in clone |
| [PR #3557](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3557) particle batching | Draft | Reported 5199→2700 draws, 86→111 FPS |
| [PR #3513](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3513) partition queries | Draft | Spatial-query cost |
| [PR #3582](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3582) frame deadlines | Open | Sub-30 drift |
| [#1468](https://github.com/TheSuperHackers/GeneralsGameCode/issues/1468) scripts per frame | Open | AI/script cost |

## Build-level opportunities

- Source CMake requires 32-bit (`CMakeLists.txt:56`) and fetches pinned dependencies:
  `min-dx8-sdk`, `GameMath`, `lzhl`, `stb`, `GameSpy`, optional Tracy.
- Release uses `/O2` + `/OPT:REF /OPT:ICF`; no LTCG/PGO found in the build files.
- `/LARGEADDRESSAWARE` is absent from the shipped PE; source build can add it.
- `RTS_BUILD_OPTION_RETAIL_COMPATIBLE_GAME` guards CRC-breaking changes. Single-player
  optimization builds can disable it; multiplayer compatibility cannot.

## Proposed order of work

1. Build source at `vendor/GeneralsGameCode` `0ff1220` with Tracy (`win32-profile`).
2. Add Tracy zones to drawable iteration, cull, sorting flush, and pathfinding queue.
3. Measure a fixed entity-heavy replay; split render vs logic time.
4. Fix particle sorting/batching (PR #3557 or bucket sort).
5. Add a spatial region index for drawables (biggest render O(N) scan).
6. Improve pathfinding open list/allocation in a non-retail single-player build.
7. A/B behind-building marker, translucent cap, LAA, LTCG/PGO.

## Limitations / open questions

- No runtime frame-time data yet; the ranking is source/community evidence, not local profiling.
- The shipped binary is patched by GenTool; source offsets may differ from retail.
- No build exists yet; dependencies require download approval.
- Multiplayer/replay compatibility limits pathfinding and CRC-breaking changes.

## Artifacts

- `docs/manifests/game-baseline-v104-gentool76-2026-11-14.sha256` — baseline identity.
- `game/work/` — mutable test copy.
- `artifacts/2026-11-14-work-fullscreen/result.json` — fullscreen verification (local, ignored).
