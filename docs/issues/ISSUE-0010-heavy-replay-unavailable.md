# ISSUE-0010: No compatible heavy replay for late-game validation

- **Status:** Workaround
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-025
- **Related:** [`../experiments/EXP-003-static-low-detail.md`](../experiments/EXP-003-static-low-detail.md), ISSUE-0009
- **Environment:** i5-10300H, 24 GB RAM, GTX 1650 Ti + Intel UHD; `game/engine-test` build `5CF4EA07…60F0`

## Symptom

The measured profiles are validated on the synthetic 1,000-unit scene, but there is still no
real late-game replay that loads and produces a heavy entity load in the rebuilt engine.

## Reproduction / evidence

With the upstream `-loadreplay` switch (visual playback; `-replay` is headless simulation):

| Replay | Result |
|---|---|
| `1v8 niggas.rep` (9.4 MB) | `REPLAY CANNOT BE LOADED — The replay file could not be opened or is invalid.` The 1,200 logged frames were the menu shell map, not replay data. `[VERIFIED]` |
| `00000000.rep` | Loads, but reports a CRC mismatch at frame 0. With `-ignoreReplaySyncErrors` it plays visually at the 30 FPS cap (median 33.32 ms, p95 36.00 ms); it is an early-game base, not entity-heavy. `[VERIFIED]` |

Commands used:

```powershell
Generals.exe -win -xres 1920 -yres 1080 -loadreplay "<replay path>"
Generals.exe -win -xres 1920 -yres 1080 -ignoreReplaySyncErrors -loadreplay "<replay path>"
```

`-replay` alone runs `ReplaySimulation::simulateReplays` headless (`GameMain.cpp:48-50`) and
does not exercise the renderer; it also stayed on the splash for 35 s and produced no frames.
`[VERIFIED]` source + run.

## Impact

T-025 cannot be completed: the Low-detail/MSAA gains are not yet confirmed on a real
late-game load. The profile is visually compatible with the known-good replay, but that replay
is capped at 30 FPS and does not stress draw submission.

## Root cause

`[INFERRED]` The heavy replay is invalid for this build (different game/mod version or a
corrupt/unsupported file), and the retail replay header does not match the source build's CRC
state, so it requires `-ignoreReplaySyncErrors`. Only two `.rep` files exist on the machine.

## Workaround

Use the synthetic 1,000-unit harness for performance claims (EXP-001/EXP-003), and the
known-good replay only as a compatibility/pacing check. Do not claim late-game performance
from it.

## Resolution / verification

Blocked on a valid late-game Zero Hour replay or save that loads in the rebuilt engine
(ideally recorded with the same game version, or with the map/mod it requires). Once provided:

```powershell
tools\benchmark-entity-heavy.ps1 -Runs 1 -ApplyProfile performance   # synthetic baseline
# replay: `-loadreplay <file>` with ZH_PERF_LOG; compare AA 0/High vs AA 0/Low
```

## History

- 2026-11-15 — `-loadreplay` identified as the visual playback switch; heavy replay rejected
  as invalid; known-good replay validated with `-ignoreReplaySyncErrors`.

- 2026-11-19 — [VERIFIED] The new ShockWave Last Stand replay is usable for
  profiling in a diagnostic copy with matching game data and both recording
  policies. [T-107](../research/2026-11-19-last-stand-slowdown.md) reproduced
  7 FPS. Standard playback compatibility remains tracked in
  [ISSUE-0108](ISSUE-0108-last-stand-replay-sync.md).
