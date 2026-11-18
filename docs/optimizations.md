# Optimization settings and compatibility boundary

[VERIFIED] T-079 fixes the configuration parser, removes the unmaintained disabled-object counter and treats FPS overrides as startup settings. The cumulative engine patch contains the implementation. See [remediation record](research/2026-11-17-optimization-remediation.md).

## Settings

The rebuilt engine reads these flat keys from its normal user `Options.ini` file. Ordinary launches honor the saved FPS preference; no profile is applied automatically.

[VERIFIED] In the packaged ShockWave menu, **Options → Detail → Custom** opens **Advanced Display Options** for controls such as particle cap, heat effects, and cloud shadows. Both shipped layouts mark Anti-Aliasing and Unlock FPS hidden. Use `AntiAliasing = 0` to turn AA off and `FPSLimit = no` to unlock the render cap in the user `Options.ini`. The standard ShockWave path is `%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data\Options.ini`. [ISSUE-0096](issues/ISSUE-0096-alpha-options-controls-hidden.md)

| Key | Default | Meaning |
|---|---|---|
| `DrawDistance` | `0` | Off. Positive world-unit distances hide distant meshes, so this remains an explicit visual tradeoff. |
| `ShadowScreenRadius` | `120` | Minimum projected shadow radius in pixels. `0` keeps all shadow volumes; positive values omit smaller shadows. |
| `DebrisBroadphase` | `no` | Experimental simulation optimization. Accepts yes/no, true/false and 1/0, case-insensitively. It additionally requires an explicit experimental-singleplayer launch and never operates in network games/replays. |
| `FPSLimit` | `no` | `yes` starts capped; `no` starts uncapped. The Options checkbox and render-FPS hotkeys can change it during play. |

**Pathfinding queue:** the stable indexed heap is the default in singleplayer (ADR-0016). Network
games and replays automatically keep the retail List, because the heap is only permitted when the
game is in a singleplayer session. Disable it for troubleshooting with
`launch-game.ps1 ... -TestEnv @{ ZH_PF_HEAP = '0' }` or `-PathfindingQueue List`; the request log
records the active queue as `# queue=heap|list` when pathfinding logging is enabled.

[VERIFIED] Candidate 14's **Skirmish → Game Speed** slider selects the simulation tick rate (15–60). The render cap uses the separate FPS preference and render-FPS shortcuts. Ordinary direct launches default to windowed presentation. A native test confirmed that ShockWave stayed visible when Snipping Tool took focus. [T-089 receipts](../artifacts/2026-11-18-skirmish-speed/manifest.md)

## Normal launch

```powershell
.\tools\launch-game.ps1 -GameDir game\engine-test -Mode borderless -QuickStart
```

[VERIFIED] The launcher clears inherited `ZH_*` diagnostics from the child and restores the caller's complete `ZH_*` environment on success or failure. It forces broadphase, collision-pair filtering and debris/hulk budgets off during normal launches, even if a prior shell or `Options.ini` enabled them. This removes those known experimental simulation changes; it is **not certification that the rebuilt engine interoperates with retail multiplayer or legacy replays**. Keep the existing retail/online path until those tests exist.

Use `-NoFPSLimit` or `-WithFpsLimit` for an explicit startup preference. These switches do not lock out subsequent live FPS controls. Ordinary launches no longer override the saved setting. Ctrl+Numpad +/- changes the render-FPS preset; simulation timing is separate.

## Experimental singleplayer only

```powershell
.\tools\launch-game.ps1 -GameDir game\engine-test -Mode borderless -QuickStart `
  -ExperimentalSingleplayer -TestEnv @{ ZH_DEBRIS_BROADPHASE = '1' }
```

[VERIFIED] This mode permits opt-in collision broadphase, pair filtering and debris budgets in singleplayer/skirmish. The engine checks the game mode dynamically and disables these paths in network games and replays, regardless of the startup request. `DebrisBroadphase=yes` in Options.ini is also honored only in this explicit mode; it remains off by default. For the ShockWave helper use `-ExperimentalSingleplayer -DebrisBroadphase 1`. Never use this mode as evidence of retail-compatible simulation: [EXP-011](experiments/EXP-011-broadphase-correctness.md) records collision-order divergence.

## Visual presets

Conservative simulation defaults with the existing shadow-size tradeoff:

```ini
DrawDistance = 0
ShadowScreenRadius = 120
DebrisBroadphase = no
```

Full distance/shadow rendering:

```ini
DrawDistance = 0
ShadowScreenRadius = 0
DebrisBroadphase = no
```

[VERIFIED] AA and detail are separate quality settings. Historical 3.38x profile results compare AA8/High against AA0/Low on the same rebuilt engine; they are not an isolated code-only gain. CosmeticPartition and the deferred-debris queue were removed in T-076. In-game video tooltips remain available. DrawDistance and ShadowScreenRadius are file-only numeric settings and require restart.

## Staging

[VERIFIED] `stage-engine.ps1`, `prepare-shockwave-copy.ps1` and `play-shockwave-performance.ps1` now restrict destinations to direct mutable children of this workspace's `game/` directory. Protected baseline/profile paths, ancestors, outside locations, source overlap, ambiguous Windows aliases, junctions/symlinks and hard-linked files are refused before mutation. This is local-copy tooling; a general end-user installer with identity detection and transactional rollback is still future work.

## 2026-11-18 review integration

[VERIFIED] Launcher `-PathfindingQueue Auto` (default) honors the engine singleplayer Heap default; explicit `List` restores List and `Heap` selects Heap. Engine network/replay guards remain authoritative. Rejected renderer source is preserved in `engine/rejected/T-035/`, excluded from the active build. Review receipts and limits: docs/research/2026-11-18-review-fixes.md.
