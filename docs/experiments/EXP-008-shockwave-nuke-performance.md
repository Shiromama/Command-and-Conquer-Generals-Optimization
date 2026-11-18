# EXP-008: ShockWave nuke and destruction cost, and the GPU adapter

> **Status:** complete · **Date:** 2026-11-15 · **Task:** T-038, T-039
> **Related:** [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md),
> [`../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md`](../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md),
> [`../decisions/ADR-0007-shockwave-two-profiles.md`](../decisions/ADR-0007-shockwave-two-profiles.md)

## 1. Question

ShockWave's late game drops frames when several nukes destroy an army. Which part of the frame
is responsible (draw, client, logic), how much of it is the GPU adapter, and which levers
improve it without changing the mod's assets?

## 2. Setup

- Mod copy: `game/shockwave-engine` (`.gib → .big` materialised, rebuilt engine
  `E828613B…67DF` installed, GenTool disabled).
- Wrapper: d3d8to9 v1.16.0 as `d3d8.dll` for the dGPU runs; system D3D8 for the iGPU run.
- GPU preference: `tools/set-gpu-preference.ps1 -Action Enable` (per-app, HKCU).
- Scenario: China Nuke General skirmish on `North America [ZH] (2)`, started through the UI
  (the harness auto-start path is broken on mod data — see §6). The test harness then:
  - spawns N `AmericaTankCrusader` around the camera (`ZH_STRESS`),
  - detonates the mod's real `WeaponFX_NukeCannon` every interval
    (`ZH_NUKEFX`, `ZH_NUKEFX_INTERVAL`, `ZH_NUKEFX_RADIUS`),
  - optionally applies damage **only to those tanks** (`ZH_NUKEFX_DAMAGE`,
    `ZH_NUKEFX_VICTIM`) so the base and match survive,
  - optionally respawns tanks (`ZH_STRESS_RESPAWN`) for a steady state.
- Instrumentation: `ZH_PERF_LOG` (frame times) and `ZH_PERF_SPLIT` (`draw`, `client`,
  `logic`). Statistics over the in-game window only; median/p95/p99.

## 3. GPU adapter comparison (same engine, same scenario)

400 tanks, 2 nukes every 4 s, no damage (pure FX), last 1,500 frames:

| Adapter path | median | mean | p95 | p99 | frames > 33.3 ms |
|---|---:|---:|---:|---:|---:|
| Intel UHD 630 (system D3D8) | **26.09 ms** (38.3 FPS) | 27.25 | 35.94 | 48.40 | 7.6% |
| NVIDIA GTX 1650 Ti (d3d8to9 + GPU pref) | **19.66 ms** (50.9 FPS) | 19.65 | 21.47 | 23.01 | 0.1% |

Median **1.33× faster**, p95 **−40%**, over-budget frames **7.6% → 0.1%**. The adapter change
is larger than any renderer tweak measured so far on this game. Evidence:
`artifacts/2026-11-15-shockwave-analysis/perf-400-igpu-nuke.csv` and
`perf-400-dgpu-nuke.csv`.

The same GPU path is available on the retail/online profile without the rebuilt engine:
GenTool chainloads `d3d8x.dll`, so d3d8to9 can sit behind GenTool (ADR-0009). With
`-win` + `window=3` the process loads `nvd3dum.dll` and survives the 120-cycle Alt+Tab stress
(handles 738→738). Retail has no frame logger, so that profile is verified by modules and
stability, not by the frame-time table above.

## 4. Steady destruction (400 tanks, deaths, debris)

400 tanks with respawn, 2 nukes every 3 s, lethal damage to tanks only, dGPU, 1,500 frames:

| Variant | median | p95 | draw (median) | client | logic |
|---|---:|---:|---:|---:|---:|
| Baseline | **19.62 ms** | 20.88 | 7.25 | 9.28 | 4.13 |
| Shadow LOD `ZH_SHADOWSIZE=120` | 19.61 ms | 20.86 | 7.20 | 9.04 | 4.01 |
| Particle cap `ZH_MAXPARTICLES=2500` | 19.65 ms | 20.98 | 8.22 | 10.38 | 3.59 |

At this scale the scene is comfortably inside the 30 FPS budget (p99 ≈ 23 ms), and neither the
shadow LOD nor the particle cap changes the median. They stay useful for weaker GPUs and the
iGPU path, but they are not the ShockWave fix. Evidence: `B-…`, `C-…`, `D-…` CSVs.

## 5. What the nuke impact actually costs

1,000 tanks, 2 nukes per second, radius 400, dGPU. Same scenario, three interaction levels:

| Damage setting | draw median | client median | logic median | frame median |
|---|---:|---:|---:|---:|
| `0` (visual only) | 22.09 | 24.24 | 6.39 | ~27 ms |
| `1` (hit reactions, no deaths) | 27.91 | 30.29 | 6.82 | 37.28 ms |
| `500` (mass deaths) | 50–90 | 50–90 | **155 p95 / 279 max** | **≈1 FPS** |

Interpretation:

- **Hit reactions are a rendering cost, not a logic cost.** Damaged-but-alive units spawn
  automatic smoke/fire particle systems; `draw` and `client` rise by ~6 ms while `logic` is
  unchanged. This matches the user's hunch that object behaviour matters at impact, but the
  cost lands in the particle/draw path.
- **Mass simultaneous deaths collapse the frame through the partition manager.** 1,000 tanks
  dying produce thousands of cosmetic debris/hulks; their per-frame cell/collision bookkeeping
  dominates (see section 7). Object simulation itself stays cheap.
- The engine's dynamic LOD only skips *generic* debris
  (`TheGameLODManager->isDebrisSkipped()` is checked only when `m_nameAreObjects` is false);
  ShockWave's named debris bypasses it.

Artifacts: `I0-impact-visual-*.csv`, `I1-impact-damage1-*.csv`, `I2-impact-lethal-*.csv`.

## 6. Harness caveat (recorded as a bug, not a game bug)

The test-only auto-start (`ZH_MAP` + `MSG_NEW_GAME`) crashes on ShockWave data in
`GameLogic::tryStartNewGame` because `PlayerList::findPlayerWithNameKey` returns null before
the mod's player templates are resolved (retail singleplayer start path). This is harness-only;
matches started through the UI run normally. The harness scenario is therefore driven by UI
automation at a fixed 1920×1080 (`tools/ui-click.ps1`), and `ZH_FPS` does not apply to those
runs.

## 7. Root cause and fix: cosmetic debris bypasses the partition manager (T-043)

Phase timing (`ZH_PERF_LOGIC`) of the unbudgeted 1,000-unit wipe showed the collapse is **not**
object simulation. With ~6,000 debris and 419 hulks:

| phase | median | max |
|---|---:|---:|
| object/sleepy updates | 0.00 ms | 23 ms |
| AI | 0.00 ms | 0.8 ms |
| build assistant | 0.00 ms | 0.01 ms |
| **partition manager** | **0.00 ms (mean 98.7)** | **1,380 ms** |
| destroy list | 0.00 ms | 8.7 ms |
| tail | 0.00 ms | 2.7 ms |

Per-frame `ThePartitionManager->UPDATE()` was therefore the ~1 s cost. It maintains cell
membership and collision candidates for every moving object; cosmetic debris is
`UNATTACKABLE` (generic) or `NO_COLLIDE` (hulks), and hulks live only ~1.5 s, yet they paid the
full churn. `[VERIFIED]` `I3-logic-phases.csv`.

**Fix (T-043):** `ZH_COSMETIC_PARTITION=1` makes `PartitionManager::update` detach
`GenericDebris` and `KINDOF_HULK` objects from the dirty list without recalculating cells or
collision candidates. They keep their drawables, positions, physics and lifetimes; only gameplay
partition bookkeeping is skipped. **No debris is removed or budgeted.**

Same scenario, unlimited debris:

| Variant | peak debris | peak hulks | partition p95 / max | frame median | frame p95 |
|---|---:|---:|---:|---:|---:|
| No fix | 5,771 | 421+ | ~1,000 / 1,380 ms | 33.3 ms | 201 ms |
| **Cosmetic partition skip (no budgets)** | **11,554** | **909** | **0.01 / 5.5 ms** | **19.6 ms** | **20.3 ms** |

The fixed run created *more* debris than the failing run and still held 51 FPS
(p99 20.75 ms, worst 25.7 ms). The mod's own ~2 s debris lifetime clears the field at normal
speed; the collapse-era screenshots looked denser only because game time was dilated.

Per-frame budgets (T-041, `ZH_DEBRIS_PER_FRAME` / `ZH_HULK_PER_FRAME`) remain available as a
fallback, but the performance profile now uses **`ZH_COSMETIC_PARTITION=1` with budgets
disabled**, keeping every debris piece. Evidence: `I3-logic-phases.csv`, `I3-objects.log`,
`I4-logic-phases.csv`, `I4-objects.log`, `I4-frames.csv`.

## 8. Conclusions

1. The largest safe win is the GPU: ShockWave was rendering on the Intel iGPU. d3d8to9 (D3D9)
   plus Windows' per-app High-performance preference puts it on the GTX 1650 Ti and improves
   median/p95 by 1.33×/−40% with no asset or gameplay change.
2. At 400 units with continuous nuke deaths, dGPU frame time is ~19.6 ms (51 FPS uncapped) and
   stays inside the 30 FPS budget; shadow LOD and particle cap are neutral there.
3. The failure mode the user sees is extreme simultaneous destruction: it is **partition-manager
   bound** (cosmetic debris cell/collision churn), not object simulation, shadows or particles.
   T-043 skips that churn for cosmetic objects and keeps every debris piece: 11,554 debris,
   partition 0.01 ms median, 19.6 ms/frame. Budgets (T-041) remain an optional fallback.
4. d3d8to9 on retail leaks ~1 handle per focus cycle; the rebuilt engine does not. Prefer the
   engine for long singleplayer sessions, d3d8to9 or borderless for the retail/online profile.

## 9. Online applicability: why T-041 stays singleplayer-only

The limiter changes how many objects exist, which multiplayer CRC treats as a desync:

- `GameLogic::getCRC` (`GameLogic.cpp:4410`) iterates **every** object in `m_objList` and folds
  `xferSnapshot(obj)` into the CRC (`:4462`). OCL debris and `Dead*Hulk` objects are ordinary
  objects in that list, so a client that creates fewer of them produces a different CRC than a
  stock client. `[VERIFIED]` source + line numbers.
- The partition manager is snapshotted into the same CRC (`xferSnapshot(ThePartitionManager)`),
  so T-043's skipped cell updates are also singleplayer-only for the same reason.
- GenTool's Game File Validator "checks all Game Files and verifies that the installation is
  legitimate"; its documentation classifies mods and "custom patches" as a modified install.
  `[SOURCED]` GenTool documentation (gamereplays.org portal, tab 9787603).
- The rebuilt engine is explicitly **not retail-CRC compatible** (MSVC 19.x vs VC6 SP6), so its
  fixes cannot be used in retail multiplayer at all; the online profile must run the stock
  1.04 `game.dat`.

Consequences:

- Online play can safely gain the **dGPU** (d3d8to9 behind GenTool) and **borderless** crash
  safety; it cannot gain the debris/hulk limiter without changing simulation state.
- A runtime-gated patch that disables the limiter in multiplayer would keep MP behaviour and CRC
  unchanged, but it still modifies a game file that GenTool validates. Whether that is
  acceptable is an anti-cheat/account decision for the user, not a technical one.
- A data-side change (reducing OCL `Count`) changes INI CRC and is not online-safe either.

## 10. Real superweapon chain validation (T-045)

Earlier tests used `FXList` calls plus direct damage. To exercise the real chain, the harness now
supports `ZH_REALNUKE=<template>`: it creates the warhead object and kills it, running
`NeutronMissileSlowDeathBehavior` (FX_Nuke, 8 blast waves at 300-2400 ms, radii 120/230,
400/250 damage, topple speed and push force) against the spawned army.

Scenario: 1,000 `ChinaTankBattleMaster`, one `NeutronMissileDUMMYObject` at the camera, budgets
off, cosmetic partition skip on, dGPU.

| metric | value |
|---|---:|
| peak debris | **4,230** (all with drawables, all visible) |
| frame median | 28.94 ms (34.6 FPS) |
| p95 / p99 | 35.29 / 75.78 ms |
| worst frame | 353 ms (load/first blast) |
| frames over 33.3 ms | 24.2% |

The real blast produces less debris than the synthetic 1,000-death wipe (4,230 vs 11,554) but
exercises damage, topple/push and the eight blast waves. Visual evidence:
`artifacts/shockwave-real-nuke/real-nuke.gif` (frames 30-80, 10 fps). It stays interactive and
keeps all debris; the 353 ms frame is a single one-off at startup/first blast, not a sustained
collapse.

Note: `CargoTruckNuke` and `NeutronMissileDUMMYObject` both use the same slow-death behavior;
the DUMMY object is the superweapon warhead. The user's retail replay still cannot be used for
this in the rebuilt engine (CRC desync), so this is the closest real-chain reproduction until a
retail-client replay or pre-nuke save is available.

## 11. Deeper fix: conservative broadphase, no physics compromise (T-046)

Research (upstream GeneralsGameCode, OpenSAGE, general physics practice) found no existing
partition fix; the standard approach is early rejection (collision layers/masks, bounding
volumes). Sub-timers (`ZH_PARTITION_LOG`) split `PartitionManager::update` into cell updates,
pair building and contact processing.

Same scenario: 1,000 `ChinaTankBattleMaster` + one real `NeutronMissileDUMMYObject` warhead.

| variant | cells max | pair build p95 / max | contact max | frame p95 | debris-debris collisions |
|---|---:|---:|---:|---:|---|
| baseline | 10.4 ms | 24.7 / 90.5 ms | 5.9 ms | 54.4 ms | yes |
| pair filter | 10.4 ms | - / 9.3 ms | 4.3 ms | 50.1 ms | **no** |
| **broadphase (default)** | 11.3 ms | **2.6 / 4.0 ms** | 3.7 ms | **46.0 ms** | **yes** |
| blunt skip | - | - | - | 35.3 ms | no (cells frozen) |

The broadphase checks the 3D bounding spheres of each candidate pair before hashing,
allocating a contact node or running the narrow phase. If the spheres do not overlap the pair
cannot collide, so the result set is identical and **all debris-debris, debris-unit and
debris-structure collisions remain**.

> **Correction (2026-11-15, T-055):** the "all collisions remain" claim was false for tall
> cylinder geometry until ISSUE-0021 was fixed. `GeometryInfo`'s cylinder bounding radius was
> `max(r, h/2)` rather than the true half-diagonal, so debris touching tall trees (r=3, h=15:
> 7.50 vs 8.08) were filtered out. After the fix the `ZH_BROADPHASE_CHECK` probe reports zero
> rejected-but-colliding pairs (EXP-011). Per-frame collision *counts* are still not identical to
> a broadphase-off run, because `onCollide` is order-dependent; see EXP-011 §3.3. This is both faster than dropping debris-debris pairs
and physics-preserving. It is the default in the performance launcher; the blunt skip and pair
filter remain available as fallbacks.

Evidence: `artifacts/shockwave-broadphase/` (broadphase.csv, perf.csv, objects.log);
`artifacts/shockwave-pairfilter/` (filter on/off); `artifacts/shockwave-real-nuke/`.

[VERIFIED] T-050 reanalysis (2026-11-15): the frame p95 comparison above uses wall-clock
rows with `frame > 300`: baseline 540 samples gives 54.43 ms and broadphase 780 samples
46.04 ms (linear interpolation). All-row p95 is 49.04/39.11 ms, a different population.
The retained pair-build maxima reproduce as 90.515/3.973 ms. The actual broadphase phase
CSV is `broadphase.csv`, not `partition.csv` (ISSUE-0018/0019). These measurements predate
the T-049 sphere-center correction; see
[the validation report](../research/2026-11-15-low-level-optimization-validation.md).

## 12. Debris visibility, and what the remaining spikes actually are (T-047)

The debris "invisible" reports were a measurement artifact, not a renderer bug. A controlled
kill with the unit at the camera and `ZH_DEBRIS_LOG` shows `W3DDebrisDraw::doDrawModule` running
with live render objects and real world positions:

```
draw CVGeneric_X07 pos=(2162.3,980.7,35.2) render=21681BB8 scale=1.00
draw AVScrap4    pos=(2149.7,1105.0,35.6) render=2B2DDCC98 scale=1.00
```

and `artifacts/shockwave-debris-visual/frames/frame0005.png` shows chunks tumbling through the
nuke smoke. Earlier captures missed them because the 1.5-1.9 s debris lifetime is shorter than
the capture interval, the camera was not over the spawn grid, and 3 clicks of zoom put the
camera past the terrain.

ShockWave's `GenericDebris` (mod `Data/INI/Object/System.ini`) is `KindOf = UNATTACKABLE`, **not**
`NO_COLLIDE`, and `PartitionData::collidesWith` rejects only `NO_COLLIDE`. Debris therefore do
collide with each other, which is why the T-043 pair filter (dropping debris-debris pairs) was a
physics change and T-046's broadphase replaced it.

Phase split of the same 1,000-unit + real-nuke scenario (`ZH_PERF_LOGIC`, `ZH_PERF_SPLIT`):

| phase | median | p95 | p99 | max |
|---|---:|---:|---:|---:|
| logic: updates | 0.12 ms | 8.63 ms | 11.35 ms | 47.9 ms |
| logic: partition | 0.01 ms | 3.20 ms | 4.77 ms | 14.5 ms |
| logic: destroy | 0.00 ms | 1.44 ms | 3.67 ms | 19.3 ms |
| draw | 2.41 ms | - | 29.2 ms | 51.9 ms |
| particles | 0.05 ms | - | 1.79 ms | 18.4 ms |
| client `TheShell->UPDATE` | 0.00 ms | - | - | 179.8 ms (shell transition only) |

With debris capped at 24 (`ZH_DEBRIS_PER_FRAME=1`) the same wall-clock spikes remain
(max 370.6 ms vs 347.0 ms with all 5,854 debris), and draw/particles maxima are unchanged. The
residual 100-350 ms frames are therefore **not debris**: they coincide with the nuke event but
survive debris suppression, and the largest client sample is a shell transition, not gameplay.
They are a separate nuke-FX/audio/main-loop item, recorded here so it is not re-investigated as
debris.

Evidence: `artifacts/shockwave-debris-visual/` (screenshot + draw log),
`artifacts/shockwave-logic-split/` (logic.csv), `artifacts/shockwave-phase-split2/` and
`artifacts/shockwave-client-split/` (split.csv), `artifacts/shockwave-nodebris-ab/` (debris
suppressed A/B), `artifacts/shockwave-final-verify/` (5,854 debris drawable/visible).

## 13. 1,000-unit dense spawn, nuked 5 times (T-048)

Harness additions: `ZH_STRESS_DENSE` (square grid), `ZH_STRESS_SPACING` (units between
centres), `ZH_STRESS_CYCLES` / `ZH_STRESS_CYCLE_INTERVAL` (respawn the army every N logic
frames, clearing the previous cycle's survivors) and `ZH_NUKEFX_OFFSET` (phase the periodic
nuke mid-cycle).

Scenario: 1,000 `ChinaTankBattleMaster`, 32x32 grid at 30-unit spacing (~930x930), spawns at
logic frames 1/241/481/721/961, nine real `NeutronMissileDUMMYObject` warheads per cycle
(±400 spread) firing at frames 119/359/599/839/1079. All debris kept, broadphase on.

| cycle | logic median | logic p95 | partition p95 / max | destroy p95 / max | debris peak (census) | survivors cleared |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0.77 ms | 16.6 ms | 4.5 / 14.0 ms | 0.6 / 14.2 ms | 5,944 | 0 |
| 2 | 7.56 ms | 29.1 ms | 6.0 / 17.9 ms | 3.8 / 24.8 ms | 7,745 | 271 |
| 3 | 25.05 ms | 38.9 ms | 7.6 / 26.8 ms | 5.4 / 63.7 ms | 9,361 | 216 |
| 4 | 30.08 ms | 52.1 ms | 7.6 / 18.0 ms | 15.7 / 70.9 ms | 9,579 | 297 |
| 5 | 30.78 ms | 58.1 ms | 7.4 / 27.3 ms | 30.4 / 91.9 ms | - | - |

Every census row reports `debrisD == debrisV == debris`, i.e. every debris piece has a
drawable and is visible. Wall-clock frame times over the run: median 38.16 ms (~26 FPS),
p95 79.17 ms, p99 158.89 ms, max 376.8 ms; 72.7% of frames exceed 33.3 ms.

Observations:
- The worst frames are the **spawn/cleanup** frames, not the nuke: 1,000 objects created in one
  logic frame cost ~140 ms of `updates` (frames 243/483/723/963), and the cleanup + partition
  re-insert of ~300 survivors cost up to 92 ms of `destroy`.
- Partition stays bounded: p95 4.5-7.6 ms, max 27.3 ms for 5,900-9,600 debris (broadphase
  holding); baseline cost for this scene was 90 ms of pair building alone.
- Debris lifetime (~4-5 s including the 8 blast waves) is close to the 8 s cycle, so batches
  overlap and the per-cycle debris peak grows (5.9k -> 9.6k); that drives the cycle-to-cycle
  rise in `updates`, not a leak.

Note on the first 5,000-unit attempt: it ran at ~1 FPS because `ChinaTankBattleMaster` has no
`Geometry` block in the ShockWave INI (the template keeps the default 1-unit sphere), so
auto-spacing produced 4-unit spacing and stacked 5,000 26-unit tanks in a ~284x284 clump. It
was not a valid measure of unit count; `ZH_STRESS_SPACING=30` fixes the footprint.

Evidence: `artifacts/shockwave-1000x5/` (perf.csv, logic.csv, objects.log, spawn1.png,
end.png), `artifacts/shockwave-5000x5/` (invalid spacing, kept as the diagnosis).
