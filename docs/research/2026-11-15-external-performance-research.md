# External research: SAGE/Zero Hour and RTS renderer performance

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Tasks:** T-020, T-021, T-030, T-031, T-032
- **Related:** [EXP-004](../experiments/EXP-004-architecture-headroom.md), [ISSUE-0010](../issues/ISSUE-0010-heavy-replay-unavailable.md)
- **Access date:** 2026-11-15

## Why this note exists

We measured that shadow volumes, not draw-call batching, dominate High detail, and that the
30 FPS cap hides ~7 ms of headroom at Low. This note checks those conclusions against the
upstream project and other RTS engine work, and records which ideas are already implemented,
which are still open, and which are not worth copying.

## 1. Upstream GeneralsGameCode work

### 1.1 Drawable iteration / partition manager — open, relevant to T-021

Issue [#1502](https://github.com/TheSuperHackers/GeneralsGameCode/issues/1502) (`xezon`,
2025-08-27) shows `GameClient::iterateDrawablesInRegion` walking **every** drawable and
suggests an octree or similar. PR
[#2044](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2044) is an open attempt using
`PartitionManager`; the author warns it can produce null `getDrawModules` results and needs
mitigations. The milestone
"[Runtime performance fixes & optimizations](https://github.com/TheSuperHackers/GeneralsGameCode/milestone/9)"
is 96% complete and lists this PR as the remaining issue.

Our source snapshot still has the linear loop (`Generals/Code/GameEngine/Source/GameClient/GameClient.cpp:763-780`),
so this is a real, upstream-recognized issue. **But** our 1,000-unit benchmark puts every unit
inside the view region, so a partition would still return essentially all of them; the scan is
not the measured draw cost. A partition is a map/off-screen optimization, not the fix for our
all-visible stress scene. `[SOURCED]` issue + PR; `[VERIFIED]` local code.

### 1.2 Particle batching — already merged upstream

PR [#3155](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3155) ("Batch same type
particles… 15 to 30%") was merged 2026-09-06. The technique: batch particles with the same
material/shader onto a common texture before sending to the GPU, flushing when the type
changes. Our vendor snapshot **already contains it** (`Core/GameEngineDevice/Source/W3DDevice/GameClient/W3DParticleSys.cpp:216-232`,
`W3DParticleSys.h:55-73`). Therefore T-020 is not new work; it is already in the baseline.
Our stress scene has no particle load, so it could not show the upstream gain.
`[SOURCED]` PR; `[VERIFIED]` local code.

### 1.3 Render/logic decoupling and high FPS — already merged upstream

PR [#1451](https://github.com/TheSuperHackers/GeneralsGameCode/pull/1451) decoupled the
non-network logic step, `WW3D::Sync`, camera/drawable timing, and the frame limiter;
[#1528](https://github.com/TheSuperHackers/GeneralsGameCode/pull/1528) refined it, and
[#2699](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2699) overhauled logic/render
FPS presets (1–960 logic FPS, 15/30 minimums). The source in our snapshot has
`FramePacer`, `m_logicFramePhase`, and `RenderFpsPreset::UncappedFpsValue`, which is why our
`ZH_FPS=1000` hook works. The 30 FPS behavior is a **configuration**, not an engine ceiling.
Our uncapped Low result (**37.7 FPS**) is direct evidence that the decoupling is active.
`[SOURCED]` PRs; `[VERIFIED]` local code + measurement.

### 1.4 AsciiString lock contention — contested, not merged

PR [#2663](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2663) claims replacing
`AsciiString` pass-by-value with `const&` raised a specific benchmark (AOD Cobalt Rush) from
14 to 87 FPS (1% low), by removing `RtlEnterCriticalSection` contention. It was **closed
without merging**; maintainers asked for evidence and noted many paths are not hot. It is a
useful profiling lead for real late-game AI/UI, not a validated general fix. Our logic is only
5.3–5.8 ms in the synthetic scene, so it cannot explain our draw bottleneck. `[SOURCED]` PR;
`[VERIFIED]` local timing.

### 1.5 Other upstream performance items

- [#2514](https://github.com/TheSuperHackers/GeneralsGameCode/commit/471dc26203ebd22549c43ff60947cfb3f4e20f4a)
  reduces 2D GUI render-element cost. Our draw split includes the control bar/minimap, but we
  have not isolated 2D cost. Candidate for UI-heavy replays, not the tank scene.
- The release notes also include memory allocator and network-frame changes; none target the
  measured shadow-volume cost.

## 2. OpenSAGE: the same engine family, modern renderer

OpenSAGE is a from-scratch SAGE reimplementation. Its 2018 review
([link](https://opensage.github.io/blog/year-in-review-2018/)) states:

- The original SAGE renderer used **shadow volumes** (Doom 3 style); OpenSAGE chose **shadow
  mapping** instead, because it is better suited to modern hardware, supports transparency,
  softening, and looks better.
- Frustum culling was parallelized with `Parallel.ForEach`; measured **5–10%** on a quad-core
  i5, with greater potential on more cores.

This directly supports our finding: High detail is shadow-volume bound, and replacing or
budgeting shadow volumes is the high-value architectural change. It also sets expectations for
threaded culling: a real but modest gain, not a 2× fix. `[SOURCED]`

## 3. openage: decoupled RTS renderer architecture

openage documents a renderer split into terrain/world/HUD/GUI stages, with gamestate and
renderer **in separate threads** and one-way gamestate -> renderer communication
([renderer level 2](https://git.xszz.org/SFTtech/openage/blob/master/doc/code/renderer/level2.md)).
It also discusses batching draw instructions to minimize texture/shader binding switches
([issue #1779](https://github.com/SFTtech/openage/issues/1779)).

This is the long-term architectural direction if we ever move off D3D8: decouple simulation and
render threads, sort/batch by state, and keep the renderer a consumer of snapshots. It is not a
small patch to the retail engine, and our measured logic cost (5.8 ms) means threading is not
the first win. `[SOURCED]`

## 4. Shadow-volume alternatives and budgets

General real-time shadow practice supports a **shadow budget** rather than drawing every
caster: prioritize the closest/largest casters, skip out-of-range geometry, bake static
shadows, and re-render only changed dynamic casters (see the
[GameDev SE answer](https://gamedev.stackexchange.com/questions/139545/how-do-modern-game-engines-handle-many-shadow-casting-lights)).
Our `ZH_SHADOWDIST=400` is a crude version of this: nearest shadows remain, distant ones are
skipped, and the frame drops from 37.23 to 30.23 ms at High detail. A screen-size threshold
(T-032) would be a better budget rule because it preserves large shadows instead of using a
hard world distance. `[SOURCED]` general technique; `[VERIFIED]` our measurement.

## 5. D3D8 -> D3D9 wrappers / modern API

Community reports for Zero Hour:

- `d3d8to9` translates D3D8 calls to D3D9; users report compatibility/stability changes and
  that VSync may become active, which can look like lower performance
  ([crosire/d3d8to9](https://github.com/crosire/d3d8to9)).
- `dxwrapper` wraps `d3d8to9` and adds window/Alt+Tab fixes; a Zero Hour user documents a
  working configuration ([dxwrapper issue #286](https://github.com/elishacloud/dxwrapper/issues/286)).
- DXVK has a Zero Hour config discussion with reports of large gains/crash fixes, but the
  maintainer notes the game is D3D8 and warns about memory settings
  ([DXVK PR #3710](https://github.com/doitsujin/dxvk/pull/3710)).
- An Intel Arc user reports stutter fixed by `d3d8to9`, but also crashes/mismatches
  ([Intel community thread](https://community.intel.com/t/constant-lags-in-the-game-command-conquer-generals-and-command-conquer-generals-zero-hour/136471)).

Our own data: GenTool's `d3d8.dll` proxy crashes the rebuilt exe (`0xC0000005`), and the system
D3D8 DLL works. A wrapper test is a **separate, reversible experiment** and requires
downloading a third-party DLL (ask first). It may help driver overhead/Alt+Tab, but it does not
address the shadow-volume cost. `[SOURCED]` community reports; `[VERIFIED]` local GenTool crash.

## 6. What applies to us

| External finding | Our evidence | Action |
|---|---|---|
| Particle batching is already merged upstream (#3155) | Our vendor contains the batching code; scene has no particles | **Do not duplicate T-020**; mark Done (upstream) |
| Render/logic FPS decoupling is merged (#1451/#1528/#2699) | Uncapped Low 37.7 FPS; `FramePacer` present | 30 FPS is config; use `ZH_FPS` only for profiling |
| Drawable partition is open and risky (#1502/#2044) | All 1,000 units visible; draw cost is submission | Keep T-021 Backlog; measure on an off-screen-heavy map first |
| SAGE-style shadow volumes are the High-detail cost | High 37.23 ms; shadows off 26.09; shadowdist 400 30.23 | **Prioritize shadow LOD/maps (T-032)** |
| OpenSAGE chose shadow maps | Same engine family, modern hardware | Prototype shadow maps/blob shadows; not a quick patch |
| Threaded culling gives 5–10% | Logic 5.8 ms; draw dominates | Long-term only |
| AsciiString contention claim (unmerged) | Logic 5.8 ms; claim contested | Profile real late-game AI before touching |
| `d3d8to9`/DXVK may help compat/perf | GenTool proxy crashes; no wrapper test yet | Optional reversible test — needs download approval |

## 7. Recommended next steps

1. **T-032: screen-size shadow LOD** — use projected size, not world distance, so large/near
   shadows stay and tiny/far shadows are skipped. Validate at High detail, uncapped and capped.
2. **T-021 only after a map with off-screen units** — the upstream partition PR is not merged
   and has null-pointer caveats; our all-visible benchmark cannot show its benefit.
3. **Optional wrapper test** — `d3d8to9` or `dxwrapper` in `game/engine-test`, measured with the
   same harness, only with explicit approval to download the DLL.
4. **Real late-game replay** — still the missing validation (ISSUE-0010), especially for AI/UI
   costs that the tank scene does not exercise.

## Caveats

- Upstream claims are not our measurements; they are marked `[SOURCED]`.
- The external PRs target different maps/scenes; AOD Cobalt Rush is not our tank stress test.
- Wrapper/DXVK reports are community evidence, often without controlled benchmarks.
- External content is treated as data; no instructions from those pages were followed.
