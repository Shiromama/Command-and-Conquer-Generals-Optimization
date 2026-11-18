# ISSUE-0022: the FPS-unlock switch did nothing in release builds

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-16
- **Task:** T-058
- **Related:** [EXP-014](../experiments/EXP-014-fps-cap.md), `tools/launch-game.ps1`,
  `Core/GameEngine/Source/Common/CommandLine.cpp`, `Core/GameEngine/Source/Common/FramePacer.cpp`
- **Environment:** engine `4942093F…76E8` (before) vs `71FEA54D…0E8E` (after)

## Symptom

Two separate faults made "remove the FPS cap" impossible from our tooling:

1. `tools/launch-game.ps1 -NoFPSLimit` declared the switch but never added `-noFPSLimit` to the
   command line (it only set `ZH_FPS`, which the harness auto-start reads).
2. `-noFPSLimit` itself is compiled only under `#if defined(RTS_DEBUG)` in the option table
   (`CommandLine.cpp:1347`), and this is a Release build (`RTS_RELEASE`), so even a correctly
   passed flag was ignored.

## Reproduction / evidence

```
# direct launch, ZH_FPS unset, engine 4942093F
-  with -noFPSLimit : median 33.38 ms (30.0 FPS)   <- still capped
-  without          : median 33.34 ms (30.0 FPS)
```

Source evidence:

```
CommandLine.cpp:1297   #if defined(RTS_DEBUG)
...
CommandLine.cpp:1347   { "-noFPSLimit", parseNoFPSLimit },
CommandLine.cpp:1353   #endif
```

The Release build defines `RTS_RELEASE`, so the entry is not compiled in. `parseNoFPSLimit` itself
is outside the guards and simply sets `m_useFpsLimit = false`, which a later GameData/INI load can
overwrite anyway.

## Impact

No way to run uncapped from our scripts (benchmark or play), which also made capped comparisons
look like "no difference" (EXP-013 §3). The in-game `Ctrl+Numpad +/-` hotkey still worked, but that
is manual and not usable in automated runs.

## Root cause

Two independent gaps: the launcher never passed the flag, and the engine only accepts the flag in
debug builds. Additionally the flag's effect was not latched, so INI parsing could re-enable the cap.

## Resolution / verification

- `FramePacer.cpp`: `isActualFramesPerSecondLimitEnabled()` now also requires
  `!(g_zhForceUncappedFps || zhUncachedFromEnv())`. `g_zhForceUncappedFps` is latched by
  `parseNoFPSLimit` (debug builds); `ZH_NOFPSLIMIT=1` is the release-build equivalent.
- `tools/launch-game.ps1` and `tools/benchmark-entity-heavy.ps1` set `ZH_NOFPSLIMIT=1` by default
  (`-WithFpsLimit` / `-MaxFps` restore a cap).

Verification (engine `71FEA54D…0E8E`, `ZH_FPS` unset, same scene and copy):

```
capped    median 33.39 ms ( 30.0 FPS)
uncapped  median  6.68 ms (149.7 FPS)
```

See [EXP-014](../experiments/EXP-014-fps-cap.md) §4.

## History

- 2026-11-16 — found by comparing a capped vs `-noFPSLimit` launch; the flag turned out to be
  debug-only. First fix attempt (moving the table entries) broke the option array's preprocessor
  structure and was reverted; the env latch is the shipped fix.
