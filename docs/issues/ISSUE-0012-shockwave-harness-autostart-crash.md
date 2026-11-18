# ISSUE-0012: Test harness auto-start crashes on ShockWave data

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-15
- **Task:** T-036
- **Related:** [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md), T-038
- **Environment:** rebuilt engine `E828613B…67DF`, ShockWave copy, `ZH_MAP` + `ZH_STRESS` auto-start

## Symptom

Starting a match through the test-only `ZH_MAP` path (`MSG_NEW_GAME` in
`GameLogic::update`) crashes on ShockWave data during map start, before the HUD appears. The
engine writes a minidump; the fault is deterministic.

## Reproduction / evidence

Command: launch the rebuilt engine with `ZH_MAP=maps\northamerica\northamerica.map` and
`ZH_STRESS=400` (any value).

- Exception `0xC0000005`, read at `0x24`, in `GameLogic::tryStartNewGame` (linker map:
  `?tryStartNewGame@GameLogic@@AAEX_N@Z+0x1408`).
- Disassembly at the fault:

```
0x004E6CB0  mov ecx, [0xA174DC]
0x004E6CB7  call 0x5CD430          ; PlayerList::findPlayerWithNameKey
0x004E6CC2  mov [ebp-0x2C4], eax
0x004E6CC8  push dword ptr [eax+0x24]   ; eax == null -> read at 0x24
```

- `0x5CD430` is `PlayerList::findPlayerWithNameKey(NameKeyType)`; the returned player is null.
  The retail singleplayer start path relies on the vanilla player templates/name keys; the
  mod's setup is not resolved at this point in the harness path.
- Dump: `…\Documents\Command and Conquer Generals Zero Hour Data\CrashDumps\CrashMZ-20261115-043706-…dmp`
  (analysis: `artifacts/2026-11-15-shockwave-analysis/crashMZ-adapter.txt`).

## Impact

Only the test harness's synthetic auto-start is affected. Matches started through the normal
menu (UI) run correctly and were used for all ShockWave measurements.

## Workaround

Start the match through the UI (`tools/ui-click.ps1` at 1920×1080) and let the harness env hooks
(`ZH_STRESS`, `ZH_NUKEFX*`, respawn, particle cap) act inside that match. `ZH_FPS` does not
apply on this path, which is why EXP-008 states it.

## Resolution / verification

**Workaround in use.** The harness is test-only (`T-036-shockwave-stress.patch`, not part of a
normal build) and does not affect players. If the auto-start is needed later, resolve the
mod's local player name key before `tryStartNewGame` or skip the reveal step when no player is
found; verify by auto-starting a ShockWave map and reaching the first logic frame.
