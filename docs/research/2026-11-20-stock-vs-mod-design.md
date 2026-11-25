# Stock vs ShockWave: design and architecture comparison

- Date: 2026-11-20
- Task: T-113 (design comparison)
- Evidence: [stock/ShockWave data census](../../artifacts/2026-11-20-stock-vs-mod-design/manifest.md),
  [Last Stand attribution](2026-11-19-last-stand-slowdown.md),
  [pathfinding algorithm note](2026-11-20-pathfinding-algorithm-limit.md),
  [ShockWave inventory](../game-inventory-shockwave.md),
  [EXP-013](../experiments/EXP-013-original-vs-optimized.md)
- Related: [stock-vs-mod replay check](2026-11-20-stock-vs-mod-replay.md)

## Short answer

[VERIFIED] ShockWave is a **data-only mod on the stock 1.04 engine**: its
`game.dat` has the same SHA-256 as vanilla (`F37A4929...`). There is no mod
engine architecture to compare. The difference is the **data and scenario
design**: a 1.3-2.8x larger INI surface, more units/weapons/FX, and a
narrow-lane survival map with continuous scripted group orders. That design
creates the pathfinding workload the stock engine was never stressed with on
its normal maps.

## 1. Architecture

| Layer | Stock Zero Hour | ShockWave | Consequence |
|---|---|---|---|
| Executable | 1.04 `game.dat` | Same 1.04 executable, unchanged | No mod engine code; all mod behavior is data |
| Data delivery | 21 `BIGF` archives | `!Shw_*.gib` renamed to `.big`; `!` prefix wins load order | Overlay/override, not a fork |
| INI data | 135 files, 549,507 lines | +758 overlay files, 740,339 lines | Larger rules/unit/weapon/FX surface |
| Models/textures/audio | stock archives | +`!ShwW3D`, `!ShwTextures`, `!ShwAudio`, etc. | More assets; rendering load only when used |
| Engine path | stock SAGE | same stock SAGE; the rebuilt engine is a separate optimization build | The mod does not change the pathfinder |

[VERIFIED] The mod launcher is a file renamer: it changes `!*.gib` to `*.big`,
then restores the names. The engine's sorted archive load makes the `!` entries
win. No executable patch is involved.

## 2. Data surface

[VERIFIED] Static block counts from the current archives:

| Block | Stock | ShockWave overlay | Scale |
|---|---:|---:|---:|
| Object | 3,179 | 4,101 | 1.29x |
| Weapon | 1,715 | 3,522 | 2.05x |
| ParticleSystem | 1,098 | 1,683 | 1.53x |
| FXList | 485 | 1,364 | 2.81x |
| ObjectCreationList | 295 | 833 | 2.82x |
| Upgrade | 192 | 331 | 1.72x |
| SpecialPower | 213 | 769 | 3.61x |
| CommandButton | 820 | 1,488 | 1.81x |
| Armor | 2,348 | 4,332 | 1.84x |
| Locomotor | 1,127 | 1,538 | 1.36x |
| DamageFX | 1,308 | 1,642 | 1.26x |
| AudioEvent | 1,410 | 2,555 | 1.81x |

[INFERRED] This is a bigger **design space**, not automatically a slower one.
The extra units/weapons/FX matter when a scenario fields them at density. The
Last Stand scenario does exactly that.

## 3. Scenario and map design

| Dimension | Stock benchmark / normal play | Last Stand |
|---|---|---|
| Map | `maps/northamerica/northamerica.map`, open stock map | custom user map, 350x200, narrow lanes/chokepoints |
| Players | benchmark harness, no AI group-order storm | 1 human vs 7 Hard armies, 50,000 cash |
| Units | 1,000 idle `AmericaTankCrusader` in the controlled benchmark | dense mixed armies, continuous waves |
| Orders | benchmark has no scripted group-order storm | 2,185 formation orders in 300 ticks, all from the GLA approach instruction |
| Duration | 40 s controlled run | 52,902 logic frames (~29:23 recording) |
| Frame budget | 6.62 ms / ~151 FPS (1,000 stock tanks, clean run) | 139.66 ms / 7.16 FPS in the original slow window; 45.6 ms / 21.95 FPS best optimized |

The stock benchmark is deliberately simple: spawn 1,000 tanks on an open map
and measure. It does **not** exercise the group pathfinder the way a survival
map with continuous scripted group orders does. Comparing its 6.62 ms with the
Last Stand 45-140 ms is a workload comparison, not an engine comparison.

## 4. Where the time actually goes

[VERIFIED] In the 300-frame Last Stand window:

| Cost | Mean |
|---|---:|
| Frame time | 139.66 ms |
| Simulation logic | 125.81 ms |
| Path searches | 98.45 ms (70.5%) |
| Other simulation | 27.36 ms |
| Draw | 11.50 ms (8.2%) |

[VERIFIED] The path work is dominated by the width-6 group clearance search:
2,185 formation searches in 300 ticks, 21.8x the straight-line distance on
average (p95 62.1x), and a p95 search bounding box covering 40.5% of the
350x200 map. Unit searches re-expand 41.8% of popped cells because the line
callback reopens closed cells.

[INFERRED] The mod's large particle/FX data is **not** the main cost in this
window. The map geometry, the unit density, and the scripted group-order
volume are. The extra FX data matters in nuke/explosion scenes, where the
draw and particle budgets rise, but the sustained 7-22 FPS slowdown is
pathfinding.

## 5. Why the stock game feels fine

[INFERRED] The stock game on its normal maps does not usually combine:

1. narrow lanes that force a width-6 clearance search to explore a wide area;
2. thousands of group orders in a short window;
3. dense friendly/enemy occupancy that turns every clearance check into a
   blocker decision.

Remove any one and the group pathfinder has much less to do. The controlled
1,000-tank benchmark removes 1 and 2, so it stays fast even on the stock
engine. The Last Stand map adds all three at once. That is a **scenario-design
stress case**, not proof that the base engine is generally slow.

## 6. What this means for optimization

- The target is the group pathfinder under narrow-lane, many-order density,
  not the renderer and not the INI loader.
- The no-reopen experiment confirms the line callback is a real lever
  (-42.33% pops), but it changes 45.5% of routes and 11.5% of goal costs; it
  needs the fresh-skirmish acceptance protocol.
- The standard-A* model did not reduce pops (+18.8% model expansions), so a
  textbook replacement is not the answer by itself. A faithful cell-cost A* or
  the clearance-field/D* Lite branch is the next algorithm test.
- A scenario-level fix is also valid: widen lanes, stagger waves, or reduce
  simultaneous group orders. That changes the mod's design and must be tested
  with the same acceptance protocol.

## 7. Limitations

- The INI census is a static count of declarations, not runtime usage; the
  overlay also overrides stock entries, so the effective set is not a simple
  sum.
- The stock 1,000-tank benchmark is a controlled spawn, not a real AI battle.
- The Last Stand replay is a diagnostic recording with matching skirmish
  policies; standard playback diverges.
- One map and one scenario; the conclusion is about this workload, not every
  ShockWave map.
- No new game run was needed for this comparison; the numbers come from the
  retained inventories and the T-107/T-113 traces.
