# ISSUE-0023: units pop out of view when the camera moves (DrawDistance default-on)

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-064
- **Related:** [EXP-002](../experiments/EXP-002-scene-distance-cull.md) ("opt-in … hides distant units"),
  `Core/GameEngine/Source/Common/OptionPreferences.cpp` (`getDrawDistance`),
  `GeneralsMD/Code/GameEngineDevice/Source/W3DDevice/GameClient/W3DScene.cpp` (~line 469),
  [docs/optimizations.md](../optimizations.md)
- **Environment:** engine `D337B939…33D5` (before fix), performance profile, 1,000-unit scenes

## Symptom

In the 1,000-unit scenes the tanks are present in the simulation but disappear on screen as the
camera is panned toward them; minimising the control bar (which recentres the view) brings them
back. The reported screenshot showed an empty patch of terrain where the army stands, with a nuke
blast above it.

## Reproduction / evidence

Run the stock 1,000-tank scene with no `DrawDistance` key in `Options.ini`, then pan the camera
across the grid: units beyond ~400 world units from the camera's eye position vanish while remaining
in the simulation.

Cause is the cull added in T-021/T-026:

```cpp
// W3DScene.cpp, RTS3DScene::Visibility_Check
if (dx * dx + dy * dy > maxDrawDistance * maxDrawDistance)
    isVisible = false;
```

with `getDrawDistance()` returning 400 when the key was absent. The camera sits behind and above its
target, so its horizontal distance to on-screen units already exceeds 400 at normal zoom.

## Impact

Visible regression in normal play for anyone running the default configuration: armies blink out as
the camera moves. No simulation effect (units still exist, still shoot), so it is purely a rendering
and usability fault — but it makes the default build look broken.

## Root cause

T-064 made every optimisation default-on and set `DrawDistance` to the value used by the stress
harness (400). EXP-002 designed that cull as **opt-in precisely because it hides distant units**, and
the benchmark scene (a dense grid around the camera) did not expose the pop-out.

## Workaround

Set `DrawDistance = 0` in `Options.ini` (or `ZH_DRAWDIST=0`), or use the Quality preset.

## Resolution / verification

`getDrawDistance()` now returns **0 (off)** when the key is absent; the key still works when set:

```cpp
OptionPreferences::const_iterator it = find("DrawDistance");
if (it == end())
    return 0;  // OFF by default: this cull hides distant units (EXP-002), so it stays opt-in.
```

`docs/optimizations.md` documents the trade-off: the shipped Performance preset uses
`DrawDistance = 0`, and an "Aggressive" preset keeps 400 for the stress harness. Engine rebuilt and
re-staged into both copies; the fresh demo runs (stock + ShockWave, retail vs shipping) are recorded
in `artifacts/2026-11-17-demo-1000/` and summarized in
[EXP-023](../experiments/EXP-023-draw-distance-default.md).

## History

- 2026-11-17 — reported by the user during a simulation run; diagnosed to the T-021 cull default;
  default set to 0, docs updated, engine rebuilt and re-measured.
