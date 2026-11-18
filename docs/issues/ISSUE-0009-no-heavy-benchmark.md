# ISSUE-0009: No valid entity-heavy benchmark scenario

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-015
- **Related:** [`../experiments/EXP-001-msaa-entity-heavy.md`](../experiments/EXP-001-msaa-entity-heavy.md), ISSUE-0006
- **Environment:** Rebuilt engine with frame logger; retail replays/saves

## Symptom

The available automated scenarios do not reproduce the user’s “many entities” slowdown, so
there is no trustworthy before/after performance metric yet.

## Reproduction / evidence

- `00000000.rep`: runs, 5,280 frames over 180 s; median **33.35 ms**, p95 **34.31 ms** across
  all 30-second windows — pinned at the 30 FPS cap. `[VERIFIED]`
- `1v8 niggas.rep` (map `Last Stand`, 119,440 bytes): source build shows a black window and
  produces no frame log, even with the map present. `[VERIFIED]`
- Debug maps (`allbuildingsallsidesunittest_save`, `art review new units`) load but do not
  create a heavy unit scene in the visible area. `[VERIFIED]`
- Saves under `Documents\...\Save` are 186–765 bytes (empty/short), not late-game states.
- A test-only `ZH_STRESS` spawn hook was attempted in `GameLogic::update`; the debug map has
  no default team, teamless object creation crashed, and UI/map-load automation was unreliable.
  The hook was reverted and is not part of the shipped patches. `[VERIFIED]`
- A second attempt added `ZH_MAP` auto-start plus deferred spawning. It obtained a valid team
  (`team=1D14E5D0`, template `AmericaTankCrusader`) but `startNewGame` from the menu returned to
  the menu; units spawned only in the menu world, not a playable match. Reverted; not shipped.
  `[VERIFIED]`
- A third attempt used the working Debug Load Map UI plus the deferred spawn. UI selection still
  left the map list open (no `stress.log`), so no playable match was reached. Reverted; not
  shipped. `[VERIFIED]`

## Impact

Cannot measure pathfinding/drawable/particle optimizations against the user’s actual late-game
load. The frame logger and build are ready; the scenario is missing.

## Root cause

No accessible late-game replay/save that the rebuilt engine can play, and no scripted
entity-spawn harness in the source.

## Workaround

Use the 30 FPS-capped replay for pacing/regression checks only; do not claim entity-heavy
performance from it.

## Resolution / verification

**Fixed:** a self-contained scenario now exists and is reproducible:

```powershell
$env:ZH_MAP='maps\northamerica\northamerica.map'
$env:ZH_STRESS='1000'
$env:ZH_PERF_LOG='artifacts\...\frames.csv'
tools\launch-game.ps1 -Mode borderless -QuickStart
```

The test-only harness is in `engine/patches/T-015-benchmark-harness.patch`; it produced 1,000
visible tanks and three baseline runs (median 58.57–62.62 ms) plus three optimized runs
(median 34.76–36.50 ms). See EXP-001.

## History

- 2026-11-14 — benchmark attempts and evidence recorded; blocked on scenario.
- 2026-11-15 — `ZH_MAP` + deferred `ZH_STRESS` produced a repeatable 1,000-unit scene;
  baseline and optimized runs captured; issue closed.
