# Engine build

GPLv3 Zero Hour source build used for profiling and fullscreen fixes.

| Item | Value |
|---|---|
| Source | `vendor/GeneralsGameCode` @ `0ff1220caf8dbcf254e4ad63ea8e907f22089624` |
| Build dir | `build/engine-vs-community/` |
| Generator | Visual Studio 17 2022, Win32, MSVC 14.43 (Community, ATL installed) |
| Target | `z_generals` |
| Output | `build/engine-vs-community/GeneralsMD/Release/generalszh.exe` |
| Profile | `RTS_BUILD_OPTION_PROFILE=ON` + Tracy 0.13.1 |

Build with:

```powershell
.\tools\build-engine.ps1
# or a plain release build:
.\tools\build-engine.ps1 -BuildDir build\engine-release -Profile $false
```

## Current artifacts

> **Identity convention (ISSUE-0020):** a full SHA-256 identifies **one link**, not one source
> tree. MSVC writes a per-link PE timestamp, a per-link PDB GUID/age and an embedded
> `__DATE__`/`__TIME__` pair, so a rebuild of unchanged source has a different file hash with an
> identical `.text`. Use `tools/engine-identity.ps1` for the stable hash (link metadata zeroed)
> and per-section hashes; use `current-engine.patch` + the vendor diff to prove source identity.

| Artifact | SHA-256 | Notes |
|---|---|---|
| `build/engine-baseline-generalszh.exe` | `F8CAC4C0CC4B5051FEF6745502269BF995804C35F3D900959C1C65DE31020998` | Unmodified source build |
| `generalszh.exe` (DPI + logger + harness + culls + adapter selection + ShockWave stress + budgets + partition broadphase + debris/FX diagnostics + dense spawn/nuke cycle runner + T-049 fixes + T-051 frame attribution + T-055 conservative broadphase radius + T-053 optional deferred-debris queue + T-022 stable heap default in singleplayer + T-035 comparison-harness options) | `0C4C74CC71E4D36F5F13B830BF6FD900F778514E0168C72D91DC9E12A4477293` | Current: stencil-only renderer (T-035 rejected, EXP-029) plus test harness/diagnostics |
| `build/engine-ltcg/.../generalszh.exe` | `8943A2A9F17D81043F069405D6D2E071F3B2725A808049FA63D02F045961F87A` | Optional LTCG variant (T-052, EXP-010) |

## Patches

[VERIFIED] T-111 adds the per-search formation clearance cache to the cumulative source patch.
It runs in local Zero Hour matches. See the
[Last Stand 1080p comparison](../docs/research/2026-11-19-last-stand-graphical-cache.md)
and [focused Win32 fixture](../tools/test-group-clearance-memo.cpp).

**Current engine:** apply [`patches/current-engine.patch`](patches/current-engine.patch), a single
cumulative diff generated from the complete working tree. It is the only patch that reproduces
the current build. The per-task patches below are **historical snapshots**, not a series: later
files embed earlier changes (for example T-015-benchmark-harness contains T-023's DPI block) and
do not apply together. See [`../docs/issues/ISSUE-0015-engine-patch-series-not-reproducible.md`](../docs/issues/ISSUE-0015-engine-patch-series-not-reproducible.md).

| Patch | Purpose |
|---|---|
| [`patches/current-engine.patch`](patches/current-engine.patch) | Complete current engine (DPI, logger, harness, culls, adapter, ShockWave stress, budgets, broadphase, diagnostics). Verified: applies to a clean vendor index and yields an empty `git diff` against the source that built `F606E603...C007A3`. |
| [`patches/T-023-dpi-awareness.patch`](patches/T-023-dpi-awareness.patch) | Per-monitor DPI awareness before window creation; fixes 1536×864 virtualization at 125% scaling |
| [`patches/T-015-frame-logger.patch`](patches/T-015-frame-logger.patch) | `ZH_PERF_LOG=<path>` writes frame-time CSV (`frame,frame_ms`) |
| [`patches/T-015-benchmark-harness.patch`](patches/T-015-benchmark-harness.patch) | Test-only `ZH_MAP`/`ZH_STRESS` scenario + `ZH_PERF_SPLIT` timing; do not ship in a normal build. Run it with `tools\benchmark-entity-heavy.ps1`. |
| [`patches/T-021-scene-distance-cull.patch`](patches/T-021-scene-distance-cull.patch) | Opt-in `ZH_DRAWDIST` scene cull; draw 27.3 ? 18.1 ms at distance 400. |
| [`patches/T-030-shadow-culling.patch`](patches/T-030-shadow-culling.patch) | Opt-in `ZH_SHADOWDIST` and `ZH_SHADOWSIZE` shadow culls; clean High uncapped 25.02 ? 20.30 ms at 120 px, units stay visible. |
| [`patches/T-036-shockwave-stress.patch`](patches/T-036-shockwave-stress.patch) | Test-only ShockWave stress: `ZH_NUKEFX`, `ZH_NUKEFX_INTERVAL/RADIUS/DAMAGE/VICTIM`, `ZH_STRESS_RESPAWN*`, `ZH_MAXPARTICLES`. Real `WeaponFX_NukeCannon` plus optional deaths/debris. |
| [`patches/T-039-adapter-selection.patch`](patches/T-039-adapter-selection.patch) | `ZH_ADAPTER=<n>` / automatic adapter choice by DXGI dedicated VRAM, plus adapter-correct mode enumeration. No-op where D3D8 exposes one adapter. |
| [`patches/T-041-debris-hulk-budget.patch`](patches/T-041-debris-hulk-budget.patch) | Opt-in `ZH_DEBRIS_PER_FRAME` / `ZH_HULK_PER_FRAME`: per-logic-frame budgets for cosmetic debris and dead-vehicle hulks (fallback; keeps fewer objects). Also carries test-only per-call debris creation timing for `ZH_OCL_LOG`. |
| [`patches/T-047-perf-diagnostics.patch`](patches/T-047-perf-diagnostics.patch) | Test-only: `ZH_DEBRIS_LOG` draw/model logging in `W3DDebrisDraw`, and `ZH_PERF_SPLIT` client phase timers (drawables, terrain, display, particles, draw, display string, shell, in-game UI). |
| [`patches/T-117-deploy-guard-hold.patch`](patches/T-117-deploy-guard-hold.patch) | Generic opt-in deploy-style guard hold. Applies to a clean vendor index; focused Nuke Cannon fixture verified. |
| [`patches/T-043-cosmetic-partition.patch`](patches/T-043-cosmetic-partition.patch) | `ZH_DEBRIS_PAIR_FILTER=1` drops NO_COLLIDE and debris-debris pairs (physics change; off by default); `ZH_DEBRIS_BROADPHASE=1` (default) rejects pairs whose 3D bounding spheres do not overlap before hashing/allocation, keeping every collision (pair build 90.5 -> 4.0 ms max). `ZH_COSMETIC_PARTITION=1` remains a blunt fallback. Includes `ZH_PARTITION_LOG` timers. |

Apply the current engine to a clean vendor checkout:

```powershell
git -C vendor\GeneralsGameCode apply --ignore-space-change engine\patches\current-engine.patch
```

`--ignore-space-change` is required because the vendor blobs are CRLF while `git apply` strips
CR from patch context by default; the applied file content keeps the correct line endings.
Revert with `git -C vendor\GeneralsGameCode apply -R --ignore-space-change engine\patches\current-engine.patch`.

Do not try to apply the per-task patch files as a chain; they overlap and are kept only as a
per-task history.

### Alpha feature patches (T-080/T-081)

The isolated alpha source applies two additional tracked patches on top of the copied
development tree:

| Patch | Purpose |
|---|---|
| [`patches/guard-range.patch`](patches/guard-range.patch) | Singleplayer human guard floor `max(adjusted vision, eligible automatic weapon range)` and UI radius refresh; AI/network/replay/enter-guard stay legacy. |
| [`patches/model-fire-fx-recoil.patch`](patches/model-fire-fx-recoil.patch) | Bound the weapon barrel index and rebuild recoil storage before indexing; fixes the null recoil-vector crash during weapon fire. |

`tools/prepare-alpha-engine.py` applies both after copying the patched development tree; the
shipping alpha engine and the guard fixture builds use the same source hashes. These patches
are not part of `current-engine.patch` and are not applied to the active vendor tree.

## Verified behavior (2026-11-14)

- Rebuilt exe launches with the **system** `d3d8.dll` and the real game data.
- **Per-monitor DPI awareness = 2**; borderless client = **1920×1080**; exclusive client = **1920×1080**.
- Exclusive fullscreen survived two Alt+Tab cycles without crashing.
- GenTool’s `d3d8.dll` proxy causes an immediate `0xC0000005` with the rebuilt exe; use
  `tools\stage-engine.ps1` (it disables GenTool by default) or a compatible wrapper.
- The 1v8 replay is black/hangs in the source build; `00000000.rep` runs at the 30 FPS cap.
- The benchmark harness (`ZH_MAP=maps\northamerica\northamerica.map`, `ZH_STRESS=1000`) produced
  1,000 visible tanks; see `../docs/experiments/EXP-001-msaa-entity-heavy.md`.
- `AntiAliasing=14` is clamped to 8x MSAA; the performance profile (AA 0) improved the
  1,000-unit median frame time **59.41 -> 35.05 ms (1.70x)**.
- Adding the built-in Low detail preset (AA 0 + Low) reached **33.36 ms** median and
  **18.45 ms** draw while keeping all units visible; total **1.78x** vs AA 14 (EXP-003).
- Clean uncapped headroom (test-only `ZH_FPS`): Low **17.47 ms (57.2 FPS)**, High **25.02 ms
  (40.0 FPS)**. High detail is shadow-volume bound: shadows off **17.63 ms**; 120 px shadow LOD
  **20.30 ms** with units visible (EXP-004/005).
- `d3d8to9` gave clean **5.7%** Low and **8.4%** High+120 px gains; it is optional and not
  installed by default (EXP-006).
- **2026-11-15 (T-049):** broadphase now uses bounding-sphere centers (object positions are
  bottom centers) and the harness no longer leaks `ZH_*` settings between launches. Rebuilt
  `F606E603...C007A3`; `current-engine.patch` verified against a clean index. See
  [`../artifacts/2026-11-15-copy-audit/`](../artifacts/2026-11-15-copy-audit/).
- **2026-11-15 (T-051/T-052):** `ZH_ATTR_LOG`/`ZH_ATTR_SAMPLE` attribute every phase of a frame on
  one clock (EXP-009). Optional LTCG build (`-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`) gives
  -3.6% median on the 1,000-unit scene and -13.6% p95 in the 5-cycle stress run (EXP-010).
  Current engine `11A4F523...F5E8`; `current-engine.patch` regenerated from the working tree and
  verified with `git apply -R --check`.
- **2026-11-15 (T-055):** the debris broadphase is now verified conservative in-game
  (`ZH_BROADPHASE_CHECK`, EXP-011). `GeometryInfo`'s cylinder bounding radius was too small for
  tall shapes; the reject test now uses the true half-diagonal plus a small margin. 0
  rejected-but-colliding pairs in 3,667 frames (ISSUE-0021).

## Staging

```powershell
.\tools\stage-engine.ps1 -BuiltExe build\engine-vs-community\GeneralsMD\Release\generalszh.exe
.\tools\launch-game.ps1 -GameDir game\engine-test -Mode borderless -QuickStart
```

The stage script copies the verified baseline into `game/engine-test/`, backs up the retail exe,
applies the fullscreen profile, and records hashes in `engine.json`.









## T-079 correctness build (2026-11-17)

[VERIFIED] Engine `A0407A85...4609` fixes the T-078 findings: disabled scan restored, unbounded
per-object update removal, validated broadphase boolean parser, and mutable startup FPS state.
Simulation-changing broadphase/filter/budgets default off and require explicit experimental
singleplayer; the engine blocks them in network games and replays. The historical current-artifact
description above lists earlier diagnostic work; T-053 deferred queue and CosmeticPartition were
removed in T-076. Normal launch now honors saved FPS preferences. Both isolated copies staged.
Build, actual-source regression tests, patch clean-index reproduction, stock capped/uncapped smoke
and 1,914-file baseline verification pass. See [remediation](../docs/research/2026-11-17-optimization-remediation.md).
No multiplayer/arbitrary-mod compatibility certification or new performance claim is made.

## T-022 / T-035 outcome (2026-11-17)

[VERIFIED] T-022 is complete: the movement/pathfinding workload and request/frame telemetry are tracked, six baseline captures and three native congested pairs are recorded, and the stable heap is now the singleplayer default (ADR-0016) with network/replay falling back to List. Paths, expansion fingerprints and sampled CRCs match; pathfinding fell 12.9% and whole update 9.5%. See [EXP-027](../docs/experiments/EXP-027-stable-pathfinding-heap.md), ADR-0012 and ADR-0016.

[VERIFIED] T-035 is complete as a rejection: the opt-in shadow-map renderer measured 27.54 ms vs 14.47 ms in the retained dense scene (1,023 casters) and a mean 1.4477x slower in three controlled alternating pairs, and it only works through d3d8to9 because native D3D8 rejects the depth formats. The renderer source was removed; stencil volumes remain the only shadow path and no rendering default changed. See [EXP-029](../docs/experiments/EXP-029-shadow-map-rejected.md) and ADR-0015.

[VERIFIED] The staged engine `0C4C74CC...7293` is stencil-only plus test harness options (`ZH_STRESS_PASSABLE`, `ZH_STRESS_DELAY`, `ZH_STRESS_AT_CAMERA`, `ZH_STRESS_NOSHROUD`, `ZH_STRESS_PIN_FRAMES`, benchmark `-Screenshot`/`-Map`/`-PinFrames`). ISSUE-0066 was a capture-timing bug: the comparison camera pin expired before each screenshot, so the 1,000-unit grid rendered off-screen; the configurable pin now captures the army, verified by `artifacts/2026-11-17-t035-dense/A-0-probe/scene.png`.

User requires notice in chat before each game launch. `tools/benchmark-pathfinding.ps1` isolates all ZH_ variables; `tools/benchmark-shadow-map.ps1` preserves/restores the original options bytes and temporary wrapper slot.

## 2026-11-18 review integration

[VERIFIED] Launcher `-PathfindingQueue Auto` (default) honors the engine singleplayer Heap default; explicit `List` restores List and `Heap` selects Heap. Engine network/replay guards remain authoritative. Rejected renderer source is preserved in `engine/rejected/T-035/`, excluded from the active build. Review receipts and limits: docs/research/2026-11-18-review-fixes.md.
