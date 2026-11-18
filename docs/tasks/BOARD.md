# Task board

> **Status:** living ledger Â· **Last verified:** 2026-11-18
> Rules: IDs are `T-###`, monotonic, never reused. Statuses: `Backlog`, `Todo`, `In Progress`,
> `Blocked`, `Done`. Every Done task links its evidence. Update this file whenever status
> changes; details go in [`../log.md`](../log.md).

## Active / upcoming

| ID | Task | Phase | Status | Owner | Evidence / notes |
|---|---|---|---|---|---|
| T-083 | Rename the project root to C&C generals optimization | P2 | Done | lead | [ISSUE-0088](../issues/ISSUE-0088-project-folder-rename-locked.md); Git root uses the requested name and the old directory is absent |
| T-084 | Independently review DeepSeek’s alpha patcher, guard fixes and mod overlay | P2 | Done | Codex | [Review and verification](../research/2026-11-18-deepseek-engineering-review.md); three candidate 9 findings reproduced |
| T-085 | Repair overlay transactions while retaining the command-prompt installer | P2 | Done | Codex | [Candidate 10 repair report](../research/2026-11-18-overlay-repair.md). ISSUE-0089–0091 fixed. |
| T-086 | Simplify the console installer to Install and Uninstall | P2 | Done | Codex | [Candidate 11 verification](../../artifacts/2026-11-18-patcher-alpha/candidate-11/manifest.md), [ISSUE-0094](../issues/ISSUE-0094-console-menu-wrap-and-encoding.md) |
| T-087 | Fix the source launcher and prepare an exact writable ShockWave copy | P2 | Done | Codex | [ISSUE-0095](../issues/ISSUE-0095-source-menu-cannot-find-package.md), [Game copies](../game-copies.md#patcher-ready-shockwave-copy) |
| T-088 | Expand patch compatibility to recognized Zero Hour engines with local mod data | P2 | Done | Codex | [ADR-0020](../decisions/ADR-0020-compatible-runtime-patcher-profile.md), [Candidate 13 verification](../../artifacts/2026-11-18-patcher-alpha/candidate-13/manifest.md) |
| T-089 | Separate skirmish speed from render FPS and default to windowed presentation | P2 | Done | Codex | [24 source cases and native capture focus verification](../../artifacts/2026-11-18-skirmish-speed/manifest.md), ISSUE-0097, ISSUE-0098 |
| T-090 | Show progress during console Install and Uninstall | P2 | Done | Codex | [Candidate 15 verification](../../artifacts/2026-11-18-patcher-alpha/candidate-15/manifest.md), ISSUE-0099 |
| T-091 | Assess GitHub publication readiness | P2 | Done | Codex | [Audit evidence](../log.md#2026-11-18---t-091-github-publication-readiness). README updated in T-092 and privacy snapshot checked in T-093. License notices and binary release review are pending. |
| T-092 | Describe the project as C++ engine optimization and retire the language-driven roadmap | P2 | Done | Codex | [Public README](../../README.md), [ADR-0021](../decisions/ADR-0021-engine-optimization-scope.md), ISSUE-0026. |
| T-093 | Prepare a privacy-checked source snapshot for a fresh public repository | P2 | Done | Codex | [Local snapshot manifest](../../artifacts/2026-11-18-source-privacy-snapshot/manifest.md). Keep existing Git history private. |
| T-094 | Sweep source and alpha artifacts before GitHub publication | P2 | Done | Codex | [Sweep evidence](../log.md#2026-11-18---t-094-pre-publication-security-sweep). Hold the binary package on ISSUE-0100 and review ISSUE-0101 before promoting archive support. |
| T-095 | Fix local path disclosure and unbounded archive extraction | P2 | Done | Codex | [Candidate 16 verification](../../artifacts/2026-11-18-patcher-alpha/candidate-16/manifest.md), [ADR-0022](../decisions/ADR-0022-prepared-mod-inputs.md), ISSUE-0100 and ISSUE-0101 fixed. |
| T-096 | Prepare the current source for a fresh GitHub repository | P2 | Done | Codex | [Root license notices](../../LICENSE.md), [source snapshot verification](../../artifacts/2026-11-18-github-source/manifest.md). |
| T-001 | Create agent-readable docs scaffolding (AGENTS, index, state, log) | P0 | Done | lead | [`../../AGENTS.md`](../../AGENTS.md), [`../INDEX.md`](../INDEX.md), validator PASS |
| T-002 | Record verified environment + install baseline | P0 | Done | lead | [`../environment.md`](../environment.md), [`../game-inventory.md`](../game-inventory.md) |
| T-003 | Define evidence labels + documentation update protocol | P0 | Done | lead | [`../../AGENTS.md`](../../AGENTS.md) Â§4/Â§6, ADR-0001 |
| T-004 | Add docs validator with self-test | P0 | Done | lead | [`../../tools/check_docs.py`](../../tools/check_docs.py); `--self-test` passes |
| T-011 | Add issue/bug register with lifecycle, template, and validator checks | P0 | Done | lead | [`../issues/README.md`](../issues/README.md); ISSUE-0001â€¦0009 |
| T-005 | Establish reproducible launch profile (command line, settings, GenTool state) | P1 | Done | lead | [`../../tools/launch-game.ps1`](../../tools/launch-game.ps1), [`../game-copies.md`](../game-copies.md) Â§4 |
| T-006 | Capture performance baseline (frame time, load time, memory) | P1 | Done | lead | [`../experiments/EXP-001-msaa-entity-heavy.md`](../experiments/EXP-001-msaa-entity-heavy.md); 3 baseline runs |
| T-007 | Determine how to read `INIZH.big` and other archives | P1 | Done | lead | [`../../tools/big-archive.py`](../../tools/big-archive.py); ADR-0008 supersedes ADR-0004; verified on stock `INIZH.big` and all 13 ShockWave `.gib` archives |
| T-008 | Survey instrumentation/profiling tools | P1 | In Progress | lead | Source has Tracy (`win32-profile`); PresentMon not installed |
| T-009 | Choose first optimization surface and write an ADR | P1 | Done | lead | ADR-0005 (source-based hybrid); [`../research/2026-11-14-engine-digestion.md`](../research/2026-11-14-engine-digestion.md) |
| T-010 | Reverse-engineer hot paths / render submission | P2 | Backlog | unassigned | Source map supersedes binary-only RE; see T-017 |
| T-012 | Fix fullscreen on the work copy | P1 | Done | lead | `fullscreen` profile + work-copy test: client 1920Ã—1080; ISSUE-0005 |
| T-013 | Force high-performance GPU (machine-specific) | P1 | Backlog | unassigned | Registry approach rejected for portability; use T-023 |
| T-014 | Build GPLv3 source (win32) with Tracy | P1 | Done | lead | [`../../engine/README.md`](../../engine/README.md); `BUILD_EXIT=0`, `generalszh.exe` |
| T-015 | Define and capture entity-heavy benchmark | P1 | Done | lead | [`../experiments/EXP-001-msaa-entity-heavy.md`](../experiments/EXP-001-msaa-entity-heavy.md); 1,000-unit harness, 3+3 runs |
| T-016 | Scaffold Rust tooling workspace | P2 | Done | lead | The [patcher crate](../../patcher/Cargo.toml) shipped in T-080. [ADR-0021](../decisions/ADR-0021-engine-optimization-scope.md) retires the broader standalone tooling plan. |
| T-018 | Create pristine baseline + mutable work copy | P1 | Done | lead | [`../game-copies.md`](../game-copies.md); 1,914 files, read-only, manifest verified |
| T-019 | Add portable copy/launch/verify scripts | P1 | Done | lead | [`../../tools/prepare-game-copies.ps1`](../../tools/prepare-game-copies.ps1), [`../../tools/launch-game.ps1`](../../tools/launch-game.ps1) |
| T-017 | Instrument source hotspots | P2 | Done | lead | `ZH_PERF_LOG`, `ZH_PERF_SPLIT` draw/client/logic timing; EXP-001 |
| T-024 | Add portable MSAA performance profile | P1 | Done | lead | [`../../tools/apply-options-profile.ps1`](../../tools/apply-options-profile.ps1); 1.70Ã— median improvement; EXP-001 |
| T-025 | Re-confirm the profiles on a real late-game replay | P2 | Blocked | unassigned | ISSUE-0010: heavy `1v8` replay is invalid; known-good replay is early-game only |
| T-026 | Add opt-in scene distance cull | P2 | Done | lead | [`../experiments/EXP-002-scene-distance-cull.md`](../experiments/EXP-002-scene-distance-cull.md); draw 27.3 â†’ 18.1 ms |
| T-027 | Visibility-preserving LOD/batching | P2 | Backlog | unassigned | Distance LOD measured no gain (28.8 vs 27.3 ms); Low detail preset now covers the visibility-preserving case (T-028); batching/spatial index still needed |
| T-028 | Add low-detail performance profile | P2 | Done | lead | [`../experiments/EXP-003-static-low-detail.md`](../experiments/EXP-003-static-low-detail.md); AA 0 + Low: median 35.05 â†’ 33.36 ms, draw 27.26 â†’ 18.45 ms, all units visible |
| T-029 | Add portable entity-benchmark runner | P2 | Done | lead | [`../../tools/benchmark-entity-heavy.ps1`](../../tools/benchmark-entity-heavy.ps1); validated 33.37 ms median, draw 17.50 ms |
| T-030 | Add opt-in shadow-volume distance cull | P2 | Done | lead | [`../experiments/EXP-004-architecture-headroom.md`](../experiments/EXP-004-architecture-headroom.md); High uncapped frame 37.23 â†’ 30.23 ms at distance 400, units visible |
| T-031 | Validate architecture/design headroom | P2 | Done | lead | [`../experiments/EXP-004-architecture-headroom.md`](../experiments/EXP-004-architecture-headroom.md); Low has ~7 ms headroom; shadow volumes are the High-detail cost |
| T-032 | Prototype screen-size shadow LOD | P2 | Done | lead | [`../experiments/EXP-005-screen-size-shadow-lod.md`](../experiments/EXP-005-screen-size-shadow-lod.md); clean 120 px: High 20.30 ms, draw 15.20 ms, near shadows kept |
| T-033 | Test a D3D8->D3D9 wrapper in engine-test | P2 | Done | lead | [`../experiments/EXP-006-d3d8to9-wrapper.md`](../experiments/EXP-006-d3d8to9-wrapper.md); clean Low 17.47 â†’ 16.47 ms (5.7%), High+120 20.30 â†’ 18.60 (8.4%); installer [`../../tools/apply-d3d8to9.ps1`](../../tools/apply-d3d8to9.ps1) |
| T-034 | Prototype shadow-map or blob-shadow path | P2 | Done | lead | [`../experiments/EXP-007-projected-shadow-rejected.md`](../experiments/EXP-007-projected-shadow-rejected.md); projected path stalled (987 ms draw), decal had no clear visual gain; reverted |
| T-035 | Implement a real shadow-map path | P2 | Done | lead | Rejected on clean dense evidence: 1,000 tanks, 1920x1080, wrapper in both arms, three alternating pairs 1.1093/1.1669/1.1481x slower (mean 1.1415x); [EXP-029](../experiments/EXP-029-shadow-map-rejected.md), [ADR-0015](../decisions/ADR-0015-reject-shadow-map-renderer.md). Renderer source tracked in `engine/rejected/T-035/`; retained evidence in `artifacts/2026-11-17-t035-rejected/` and removed from the engine; stencil remains the shipped default. |
| T-020 | Optimize particle sorting/batching | P2 | Done | lead | Upstream PR [#3155](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3155) merged; batching is present in our vendor (`W3DParticleSys.cpp`). Not measured locally (tank scene has no particle load). |
| T-021 | Add a drawable spatial index | P2 | Backlog | unassigned | Upstream [#1502](https://github.com/TheSuperHackers/GeneralsGameCode/issues/1502) / PR [#2044](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2044); unmerged, null-risk, no gain in an all-visible scene |
| T-022 | Improve pathfinding open list/allocation | P2 | Done | Codex | [EXP-027](../experiments/EXP-027-stable-pathfinding-heap.md); native congested PF -12.9%, update -9.5%, recorded paths/CRC match; Heap is the singleplayer default (ADR-0016), network/replay keep List, `ZH_PF_HEAP=0` restores List; launcher Auto/CSV integration verified in [review fixes](../research/2026-11-18-review-fixes.md); ADR-0012 |
| T-023 | Fix adapter selection and fullscreen source path | P2 | In Progress | lead | DPI + exclusive fullscreen verified; adapter/format pending; [`../research/2026-11-14-fullscreen-source-plan.md`](../research/2026-11-14-fullscreen-source-plan.md) |
| T-036 | Add ShockWave nuke/destruction stress harness | P2 | Done | lead | [`../../engine/patches/T-036-shockwave-stress.patch`](../../engine/patches/T-036-shockwave-stress.patch); `ZH_NUKEFX*`, `ZH_STRESS_RESPAWN`, `ZH_MAXPARTICLES`; real `WeaponFX_NukeCannon` + damage/deaths |
| T-037 | Isolate ShockWave in a copy and read its archives | P2 | Done | lead | [`../../tools/prepare-shockwave-copy.ps1`](../../tools/prepare-shockwave-copy.ps1), [`../../tools/big-archive.py`](../../tools/big-archive.py), [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md); 1,642 particle systems vs 1,087 stock |
| T-038 | Measure ShockWave particles and destruction | P2 | Done | lead | [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md); dGPU 19.62 ms steady destruction; mass-wipe logic 155 ms p95 |
| T-039 | Fix hybrid-GPU selection (D3D8 limitation) | P2 | Done | lead | [`../../engine/patches/T-039-adapter-selection.patch`](../../engine/patches/T-039-adapter-selection.patch), [`../../tools/set-gpu-preference.ps1`](../../tools/set-gpu-preference.ps1); D3D8 exposes 1 adapter, d3d8to9 + pref loads `nvd3dum.dll`; 26.09â†’19.66 ms; ADR-0007 |
| T-040 | Find and verify the Alt+Tab crash fix | P2 | Done | lead | [`../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md`](../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md); exclusive crashes (GenTool or system D3D8), borderless + GenTool and d3d8to9 + engine survive 120 cycles |
| T-041 | Add a debris/OCL budget for mass-death frames | P2 | Done | lead | [`../../engine/patches/T-041-debris-hulk-budget.patch`](../../engine/patches/T-041-debris-hulk-budget.patch); optional fallback (keeps fewer objects). The profile now uses T-043 instead |
| T-043 | Skip partition churn for cosmetic debris/hulks | P2 | Done | lead | [`../../engine/patches/T-043-cosmetic-partition.patch`](../../engine/patches/T-043-cosmetic-partition.patch); root cause: partition manager ~1,000 ms/frame; with the skip: 11,554 debris, partition 0.01 ms, frame 19.6 ms/p95 20.3 |
| T-044 | Enable edge scrolling and focus in the borderless profile | P2 | Done | lead | [`../../tools/set-screen-edge-scroll.ps1`](../../tools/set-screen-edge-scroll.ps1); ISSUE-0013; edge pan pixel diff 0.01 â†’ 40.5 after `ScreenEdgeScrollEnabledInWindowedApp=yes`; launcher focuses the game |
| T-045 | Validate the real nuke warhead against 1,000 units | P2 | Done | lead | `ZH_REALNUKE=NeutronMissileDUMMYObject` runs the real 8-wave warhead: 4,230 debris, median 28.94 ms / p95 35.29; [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md) Â§10; [`../../artifacts/shockwave-real-nuke/`](../../artifacts/shockwave-real-nuke/) |
| T-046 | Add conservative debris collision broadphase | P2 | Done | lead | 3D bounding-sphere reject before pair allocation; all collisions kept; pair build 90.5 ? 4.0 ms max, frame p95 54.4 ? 46.0; EXP-008 §11; `artifacts/shockwave-broadphase/` |
| T-047 | Verify debris visibility and attribute residual nuke spikes | P2 | Done | lead | Debris render (draw log + screenshot); `GenericDebris` is UNATTACKABLE not NO_COLLIDE; with debris suppressed the same 100-350 ms frames remain, and logic phases peak at 61.5 ms; EXP-008 12; `artifacts/shockwave-debris-visual/`, `artifacts/shockwave-nodebris-ab/` |
| T-048 | Dense 1,000-unit spawn with 5 nuke cycles | P2 | Done | lead | Dense grid + cycle runner (`ZH_STRESS_DENSE/SPACING/CYCLES`, `ZH_NUKEFX_OFFSET`); 5 cycles, debris peaks 5,944-9,579 all drawable/visible; frames median 38.2 ms / p95 79.2; worst frames are spawn+cleanup; EXP-008 13; `artifacts/shockwave-1000x5/` |
| T-042 | Find a GenTool-compatible discrete-GPU path | P2 | Done | lead | [`../decisions/ADR-0009-gentool-dgpu-path.md`](../decisions/ADR-0009-gentool-dgpu-path.md); GenTool + d3d8to9 as `d3d8x.dll` + borderless loads `nvd3dum.dll`, 120 cycles, handles 738â†’738; earlier exit was the missing `window=3` |
| T-049 | Audit working copies and engine source against the pristine baseline; fix divergence | P2 | Done | lead | [`../issues/ISSUE-0014-broadphase-z-center.md`](../issues/ISSUE-0014-broadphase-z-center.md), [`../issues/ISSUE-0015-engine-patch-series-not-reproducible.md`](../issues/ISSUE-0015-engine-patch-series-not-reproducible.md), [`../issues/ISSUE-0016-harness-env-and-state-leaks.md`](../issues/ISSUE-0016-harness-env-and-state-leaks.md), [`../issues/ISSUE-0017-validator-artifact-links.md`](../issues/ISSUE-0017-validator-artifact-links.md); `artifacts/2026-11-15-copy-audit/`; baseline 1,914/1,914 unchanged, `work` only `d3d8.cfg`; rebuilt engine `F606E603...C007A3` |

| T-050 | Validate low-level optimization candidates against source, measurements and primary research | P2 | Done | lead | [Validation report](../research/2026-11-15-low-level-optimization-validation.md); source + retained CSV reanalysis; no new runtime gain claimed; ISSUE-0018/0019 fixed |

| T-051 | Attribute the mass-death and nuke frames on one clock | P2 | Done | lead | `ZH_ATTR_LOG`/`ZH_ATTR_SAMPLE`; [EXP-009](../experiments/EXP-009-frame-attribution.md); verified `gap` = 0.26 ms; [ISSUE-0020](../issues/ISSUE-0020-engine-hash-identifies-one-link.md) |
| T-052 | Evaluate LTCG/PGO as a whole-program gain | P2 | Done | lead | [EXP-010](../experiments/EXP-010-ltcg-build.md); `build/engine-ltcg`, `-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`; median -3.6% (2 pairs), p95 -13.6% (1 pair, tentative) |
| T-053 | Prototype a deferred, keep-every-piece debris queue | P2 | Done | lead | [EXP-012](../experiments/EXP-012-deferred-debris-rejected.md); `ZH_DEBRIS_DEFER`, 0 debris lost, but mean/p95 +1.2%/+0.9% and updates max +16% ? **rejected** (opt-in only) |
| T-054 | Add a broadphase collision-set differential harness and soundness probe | P2 | Done | lead | `ZH_COLLISION_LOG`, `ZH_BROADPHASE_CHECK`, `ZH_STRESS_STRUCTS`; [EXP-011](../experiments/EXP-011-broadphase-correctness.md) |
| T-055 | Fix the broadphase cylinder bounding radius | P2 | Done | lead | [ISSUE-0021](../issues/ISSUE-0021-broadphase-cylinder-radius.md); 0 rejected-but-colliding pairs in 3,667 frames; engine `11A4F523…F5E8` |
| T-056 | Measure original vs optimised profile under identical conditions | P2 | Done | lead | [EXP-013](../experiments/EXP-013-original-vs-optimized.md); 1,000 units uncapped 25.04 ? 7.48 ms (**3.35×**); nuke scene p95 214 ? 85 ms (-60%) |
| T-057 | Study removing the render FPS cap; fix the inert launcher switch | P2 | Done | lead | [EXP-014](../experiments/EXP-014-fps-cap.md), [ISSUE-0022](../issues/ISSUE-0022-launcher-nofpslimit-noop.md); 30/60/120/240 ? 33.4/16.7/8.3/6.3 ms; `-noFPSLimit` verified 33.4 ? 9.6 ms |
| T-058 | Make uncapped the default for our tools; re-run the A/B uncapped | P2 | Done | lead | `ZH_NOFPSLIMIT` engine latch; [EXP-013](../experiments/EXP-013-original-vs-optimized.md) §5: 21.86 ? 6.47 ms (**3.38×**), nuke p95 177 ? 62 ms |
| T-059 | Measure the healing / repair-icon slowdown | P2 | Done | lead | [EXP-015](../experiments/EXP-015-heal-repair-icon-cost.md); heal logic +0.12 ms/300 units; icons 0.0005 ms each (272 at once); sustained radius station =1 query/frame; `ZH_ICON_LOG`/`ZH_HEAL_PULSE`/`ZH_HEALERS` |
| T-062 | Re-run the 1,000-unit scenarios on the final engine | P2 | Done | lead | [EXP-013](../experiments/EXP-013-original-vs-optimized.md) §5.1; taken under background load — superseded by T-063 |
| T-063 | Clean 1,000-unit re-run with background apps closed | P2 | Done | lead | [EXP-013](../experiments/EXP-013-original-vs-optimized.md) §5.2; stock 1,000 tanks **6.62 ms** (3 runs, 151 FPS), ShockWave 1,000×5 **3.81 ms** / p95 61.7 (2 runs) |
| T-064 | Audit low-level architecture for scaling inefficiencies | P2 | Done | lead | [Audit](../research/2026-11-16-low-level-architecture-audit.md); 5 critical findings with file:line + validation plans; no new runs |
| T-065 | Make destroy-list module removal O(k) instead of O(D×N) | P2 | Done | lead | [EXP-017](../experiments/EXP-017-destroy-path.md); destroy max 92.9 ? 8.2 ms (-91%), p95 50.4 ? 48.2 ms (19.8 ? 20.7 FPS), census identical |
| T-066 | Shadow-volume rebuild throttle (light/transform change instead of every frame) | P2 | Done | lead | [EXP-020](../experiments/EXP-020-shadow-rebuild-throttle.md); 33 ms throttle at High detail: median 7.85 → 7.77 ms (127.3 → 128.7 FPS), p95 +1.9% → **rejected, source reverted**; rebuild is not the cost, rendering is (T-035) |
| T-067 | Skip the per-frame disabled scan when nothing is disabled | P2 | Done | lead | [EXP-018](../experiments/EXP-018-disabled-scan.md); counter-guarded scan; median 7.32 → 7.13 ms (136.6 → 140.3 FPS, 2 pairs, not proven, no regression) |
| T-068 | Measure allocator/string lock share before changing them | P2 | Done | lead | [EXP-022](../experiments/EXP-022-lock-share.md); pool CS 19.3 calls/frame = **0.03%**, AsciiString CS 1,587 calls/frame = **0.99%** (QPC overhead removed) → **no change**; `ZH_LOCK_LOG` stays as a diagnostic |
| T-069 | Bucket sleepy updates instead of rebalancing per pop | P2 | Backlog | lead | Audit §2.2; needs a wake-order measurement first — a bucketed scheduler changes ordering |
| T-070 | Icon UI pass ON/OFF A/B (`ZH_NO_ICON_UI`) | P2 | Done | lead | [EXP-019](../experiments/EXP-019-icon-ui-pass.md); clean pair 6.44 vs 6.45 ms (155.3 vs 154.9 FPS), draw 1.71 vs 1.79 ms — **no effect**, icons stay on |
| T-071 | Measure the shipping configuration and attribute the ShockWave tail | P2 | Done | lead | [EXP-021](../experiments/EXP-021-shipping-package-tail.md); full package 4.46 ms (224.9 FPS), p95 22.23 ms (45.0 FPS); same-binary A/B: partition skip −21.8% p95 / −19.6% p99 |
| T-072 | Revert the DrawDistance default after a user-visible pop-out | P2 | Done | lead | [ISSUE-0023](../issues/ISSUE-0023-draw-distance-hides-units.md), [EXP-023](../experiments/EXP-023-draw-distance-default.md); default 400 → 0 (opt-in), docs/presets updated |
| T-073 | Fix invisible debris: shroud status for cosmetic objects with no cells | P2 | Done | lead | [ISSUE-0024](../issues/ISSUE-0024-cosmetic-skip-hides-debris.md), [EXP-024](../experiments/EXP-024-debris-visible.md); debris now draw; `CosmeticPartition` default → off (skip is not faster once debris render) |
| T-076 | Remove the dead/harmful opt-ins (`CosmeticPartition`, T-053 deferred queue) | P2 | Done | lead | Code + env vars + tool flags removed; `ZH_COSMETIC_PARTITION`/`ZH_DEBRIS_DEFER` absent from the binary; DrawDistance stays as the one real opt-in |
| T-077 | In-game hover help for the performance settings | P2 | Done | lead | `OptionsMenu.cpp`: tooltips on AA, Detail, Unlock FPS, particle cap, heat effects, cloud shadows (the .wnd TOOLTIP field is a placeholder, so they are set from code) |

| T-074 | Audit workspace size and classify cleanup candidates | P2 | Done | lead | [Cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md); 24.36 GiB workspace, ~8.02 GiB review candidates; no deletions; ISSUE-0025/0026 |

| T-075 | Clean secondary build intermediates and redundant screenshot sequences | P2 | Done | lead | [Cleanup results](../research/2026-11-17-cleanup-results.md); 3,260 files / 6.99 GiB removed, 396 retained hashes match, 16,477 protected metadata records unchanged |

| T-078 | Independently inspect optimization correctness and universal-patcher readiness | P2 | Done | Codex | [Engineering review](../research/2026-11-17-optimization-engineering-review.md); ISSUE-0029–0034 Open; raw CSV reanalysis and mocked launcher verification; no runtime changes |

| T-079 | Resolve T-078 correctness, configuration and staging findings | P2 | Done | Codex | [Remediation](../research/2026-11-17-optimization-remediation.md), ADR-0010; ISSUE-0029–0034 Fixed; build, 51 safety assertions, compiled regressions, stock smoke and baseline verification pass |

| T-080 | Deliver reversible v0.1 singleplayer alpha patcher | P2 | Done | Codex | [ADR-0017](../decisions/ADR-0017-alpha-patcher-transactions.md); latest package candidate 15 `artifacts/2026-11-18-patcher-alpha/candidate-15/zh-patcher-0.1.0-alpha.1`; engine `76099735...FA17`; 43 production / 43 debug cases; 1,914 stock + 288 ShockWave round trips; native 1920x1080 stock/ShockWave smokes |

| T-081 | Correct stock-unit guard radius to cover usable weapon range | P2 | Done | Codex | [EXP-030](../experiments/EXP-030-guard-range-runtime.md), [ADR-0018](../decisions/ADR-0018-guard-range-floor.md), ISSUE-0083; control 0 shots vs fixed fired at 335.75 beyond 324; 67 compiled cases; production engine includes guard + weapon-FX fixes |

| T-082 | Community-compatible transactional mod overlay | P2 | Done | Codex | [Candidate 10 fixes and verification](../research/2026-11-18-overlay-repair.md). Original delivery: [ADR-0019](../decisions/ADR-0019-community-mod-overlay.md), [research](../research/2026-11-18-community-mod-installation.md), [delivery report](../research/2026-11-18-mod-overlay-delivery.md); 31 debug/31 production tests; ZIP/7z/.big/.gib; 1,914/288 hashes restored; native 1920x1080 `.big` overlay smoke |

## Blocked

| Task | Reason | Unblock |
|---|---|---|
| T-007 archive parser | `INIZH.big` parser deferred by ADR-0004 | Start T-007 when data-level tuning is needed |
| T-025 real-replay validation | ISSUE-0010: heavy replay is invalid; known-good replay is early-game and CRC-mismatched | Provide a compatible late-game replay/save |

## Recently completed

See Done rows above; details in [`../log.md`](../log.md).

## Conventions

- One task = one reviewable outcome. Split anything that cannot be verified in one session.
- Link to the doc section, artifact folder, or commit that proves completion.
- A task moves to Done only when its evidence exists in the repository.
- If a task changes direction, add an ADR rather than rewriting the original entry.
