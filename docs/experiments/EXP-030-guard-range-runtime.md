# EXP-030: Guard range runtime validation

- **Date:** 2026-11-18
- **Author/agent:** DeepSeek lead
- **Task:** T-081
- **Status:** Complete

## Hypothesis

Raising `AIGuardMachine::getStdGuardRange` to `max(adjusted vision, usable automatic weapon range)` for a human player in singleplayer will let a guard acquire and fire at a target that is outside the legacy vision-based guard radius but inside weapon range, without changing the control build.

## Baseline

Legacy `getStdGuardRange` uses only `AI_VISIONFACTOR_OWNERTYPE | AI_VISIONFACTOR_MOOD | AI_VISIONFACTOR_GUARDINNER`. For the local stock reference with `GuardInnerModifierHuman=1.8`, Tomahawk/Scud/Nuke variants have legacy radius 324 and primary weapon range 347.5.

## Method

| Item | Value |
|---|---|
| Game build (control) | `90C208FA9E26CDF7C10F67C029586AEE65A0416734E5488FC1F208B9B5306574` (legacy guard, fixture) |
| Game build (variant) | `1CEFD1F4E8DA4D5C9861C64A89A8891CA9EABCE44791CC29CC8D60BDEAF8B766` (guard patch, fixture) |
| Production build | `4FD3B817F49F4EBAF87C4F30BB38AC8491BC9AED15AC208DDE3B742882702F42` |
| Command line | `tools/run-guard-fixture.py --label {control,fixed} --run {4,1} --package artifacts/2026-11-18-patcher-alpha/candidate-2/zh-patcher-0.1.0-alpha.1` |
| Settings | Native 1920x1080 borderless, `ZH_FPS=30`, shroud disabled in the fixture |
| Scenario | `barrenbadlands`, ordinary skirmish, slot 0 human America, slot 1 easy AI America, 80 s window, 1,500 logic frames |
| Tools | Dev-only `guard-range-fixture.inc` injected into the isolated alpha source; CSV probe; package-verified engine swap/restore |
| Repetitions | One control and one fixed run after the harness fix; control crashed twice before the weapon-FX fix |

The `--package` argument supplies the patcher used to verify and restore the managed executable; the tested engine itself is the development fixture build in `build/alpha-engine-release`, not the package's shipping `engine.exe`.

Steps:

1. Start a real skirmish with a human local player and a distinct AI opponent.
2. Spawn a guard-capable stock unit at map center, a target power plant at a controlled distance, and an unarmed spotter.
3. Issue `aiGuardPosition(..., GUARDMODE_GUARD_WITHOUT_PURSUIT, CMD_FROM_PLAYER)`.
4. Sample `getStdGuardRange`, legacy radius, primary range, distance, `can_attack`, `within_weapon_range`, last-shot frame and target health every 30 frames.
5. Compare legacy control and fixed resolver with the same map, slots and positions.

## Measurements

| Unit | Build | Guard radius | Legacy radius | Weapon range | Distance | First shot | Target health |
|---|---|---:|---:|---:|---:|---:|---|
| AmericaTankCrusader | control | 270 | 270 | 147.5 | 100 | 94 | 800 -> 440 |
| AmericaTankCrusader | fixed | 270 | 270 | 147.5 | 100 | 94 | 800 -> 440 |
| AmericaVehicleTomahawk | control | 324 | 324 | 347.5 | 335.75 | none | 800 (unchanged) |
| AmericaVehicleTomahawk | fixed | 347.5 | 324 | 347.5 | 335.75 | 486 | 800 -> 650 |
| GLAVehicleScudLauncher | control | 324 | 324 | 347.5 | 335.75 | none | 800 (unchanged) |
| GLAVehicleScudLauncher | fixed | 347.5 | 324 | 347.5 | 335.75 | 843 | 800 -> 500 |
| ChinaVehicleNukeLauncher | control | 324 | 324 | 347.5 | 335.75 | none | 800 (unchanged) |
| ChinaVehicleNukeLauncher | fixed | 347.5 | 324 | 347.5 | 335.75 | 1260 | 800 -> 400 |

In both control and fixed runs, `can_attack=3` and `within_weapon_range=1` for the three long-range units. Only the fixed resolver actually fires at 335.75, which is 11.75 units beyond the legacy 324 radius. The target health subsequently drifts upward in some samples, so only the first damage step is used as evidence.

## Result

Supported. The fixed build acquires and fires at targets outside the legacy guard radius but inside weapon range; the legacy build does not, even though the target is attackable and in range. The Crusader control is unchanged.

## Interpretation

The change addresses a real guard-ring/acquisition shortfall for human singleplayer units. It does not claim every stock variant was runtime-tested, does not validate multiplayer/network/replay behavior, and does not measure the visual radius decal at runtime. The UI ring uses the same resolver and is covered by 67 compiled actual-source cases, not by a screenshot.

## Artifacts

- `artifacts/2026-11-18-guard-range/control-4/guard.csv`
- `artifacts/2026-11-18-guard-range/fixed-1/guard.csv`
- `artifacts/2026-11-18-guard-range/manifest.md`

## Follow-ups

- Optional visual check of the guard-radius decal for a long-range unit.
- Broader unit/upgrade coverage if the alpha scope expands beyond the audited stock variants.
- Keep network/replay/AI behavior unchanged and uncertified.
