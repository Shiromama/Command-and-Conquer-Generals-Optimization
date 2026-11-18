# ISSUE-0016: Test-harness environment and object state leak into later runs

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-049
- **Related:** T-036, T-041, T-043, T-046, T-047, T-048; [`../../tools/launch-game.ps1`](../../tools/launch-game.ps1)
- **Environment:** Windows 11; PowerShell 5.1; rebuilt engine `1915B8BF...4406`

## Symptom

(1) Demo and benchmark scripts set `$env:ZH_*` in the caller's PowerShell session. Those values
persist after the script exits, so a later ordinary `tools\launch-game.ps1` silently inherits
test behaviour: auto-spawned armies, nuke cycles, cull distances, logging, or an FPS cap. The
scripts overwrite only the variables they use; for example, after the army demo,
`ZH_STRESS=1000` and `ZH_REALNUKE=...` stay set for the next launch.

(2) The stress harness caches `Team*`, `ThingTemplate*` and `std::vector<ObjectID>` in function
statics. After leaving a game, a new map can free or replace those objects, and reused IDs can
make the harness destroy unrelated objects. `stressArmed` was never reset.

(3) `GameLogic::update()` created/truncated `nukefx.log` in the working directory on the first
logic tick even when `ZH_NUKEFX` was unset.

(4) `ThePlayerList->getNeutralPlayer()->getDefaultTeam()` was dereferenced without a null check.

## Reproduction / evidence

Source before the fix:

```cpp
// GameLogic.cpp ~3741: function-local statics survive map teardown
static Team *stressTeam = nullptr;
static const ThingTemplate *stressTemplate = nullptr;
static std::vector<ObjectID> stressIds;

// GameLogic.cpp ~3982: runs on every first logic update
FILE *nukeLog = fopen("nukefx.log", "w");

// launch-game.ps1: cleared only ZH_DRAWDIST/SHADOWDIST/SHADOWSIZE/ZH_FPS
```

Environment leak test with a stub `Generals.exe` that writes its `ZH_*` variables:
set `$env:ZH_STRESS='parent-value'`, launch with `-TestEnv @{ ZH_STRESS='7'; ZH_NUKEFX='2' }`;
the child saw exactly the three test values and the parent was restored. A normal launch with the
parent still set produced **no** `ZH_*` variables in the child.

## Impact

Benchmark/demo shells could make a normal game launch behave incorrectly (spawns, nukes, culls,
no shadows, capped FPS). The stress harness could crash or damage a new match after returning to
the menu. `nukefx.log` appeared in the game directory during ordinary play.

## Root cause

Harness settings were global process state with no scoping, and the harness kept map-lifetime
pointers in function statics. The launcher only cleared the subset of variables it owned.

## Workaround

Close the PowerShell window after a demo, or clear `ZH_*` manually before a normal launch.

## Resolution / verification

- `tools/launch-game.ps1` accepts `-TestEnv <hashtable>`, clears every known harness variable
  before starting the process, restores the caller's environment immediately after
  `Start-Process`, and scopes the settings to the child. Normal launches no longer inherit
  leaked test state.
- `tools/play-shockwave-performance.ps1`, `tools/demo-shockwave-army-nuke.ps1` and
  `tools/demo-shockwave-nukes.ps1` pass their settings through `-TestEnv`.
  `tools/benchmark-entity-heavy.ps1` saves/clears/restores the full harness-variable set.
- `GameLogic.cpp` resets `stressArmed`, `stressTeam`, `stressTemplate`, `stressIds`,
  `cyclesSpawned` and `cycleCounter` whenever `!isInGame()`, and null-checks the neutral player.
- `nukefx.log` is only opened when `ZH_NUKEFX > 0`.
- `ObjectCreationList.cpp` guards `firstObject` before the experience-sink block (reachable only
  in non-retail builds, but the per-frame budget can skip every object).
- Verification: stub-exe test (above); PowerShell parser check on all edited scripts (`OK`);
  engine rebuild exit 0, `F606E603...C007A3`; `artifacts/2026-11-15-copy-audit/build-fix.log`.

## History

- 2026-11-15 - Found during the T-049 audit; launcher/harness fixes applied and rebuilt.
