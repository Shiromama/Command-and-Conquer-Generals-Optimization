# ISSUE-0001: Reference installation may be mutated by a normal game launch

- **Status:** Workaround
- **Severity:** Medium
- **Date found:** 2026-11-14
- **Task:** T-018
- **Related:** ADR-0002, ADR-0006, [`../game-copies.md`](../game-copies.md), [`../game-inventory.md`](../game-inventory.md) §4
- **Environment:** Windows 11 26200; Zero Hour install with GenTool 7.6

## Symptom

The installation is the project's only reference copy and is supposed to stay immutable, but
running the game normally may write to it — configuration (`d3d8.cfg`), logs, and possibly
saves. No launch has been performed from this repository, so the actual write locations are
unknown.

## Reproduction / evidence

Not yet reproduced (deliberately). Evidence for the risk:

- `d3d8.cfg` exists in the install root and is GenTool-owned config. `[VERIFIED]`
- RTS titles of this era commonly write config/saves next to the executable and in the user
  profile. `[SOURCED]` general knowledge.
- Exact write locations for this build: `[UNKNOWN]`.

## Impact

A baseline run could silently change the reference installation, invalidating the recorded
hashes and violating ADR-0002. Subsequent comparisons would no longer be against a known
state.

## Root cause

`[UNKNOWN]` until the first instrumented launch.

## Workaround

All work now happens in a separate copy, never in the source installation:

- `game/baseline-pristine/` — exact, read-only, hashed baseline.
- `game/work/` — mutable copy for fixes and tests.
- The source install stays untouched; `docs/game-copies.md` records its identity.

A fullscreen test on `game/work/` confirmed that the real installation and the Documents
settings were unchanged (`options.ini`, `Skirmish.ini`, `ReleaseCrashInfo.txt` hashes and
timestamps unchanged). `[VERIFIED]`

## Resolution / verification

Workaround active: baseline/work copies plus the manifest verification
(`OK: baseline matches manifest (1914 files)`) prevent silent mutation of the reference.
Close only if a run proves an unavoidable write to the source installation.

## History

- 2026-11-14 — recorded during P0 setup after reviewing the launcher/config layout.
- 2026-11-14 — baseline/work copies created; source install verified untouched after a work-copy launch.
