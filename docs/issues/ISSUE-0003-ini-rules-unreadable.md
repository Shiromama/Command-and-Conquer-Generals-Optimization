# ISSUE-0003: Game rules in INIZH.big cannot be read yet

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-14
- **Task:** T-007
- **Related:** ADR-0004 (superseded by ADR-0008), T-037, [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md) §3
- **Environment:** Zero Hour install; `INIZH.big` 18,764,687 bytes

## Symptom

The game's INI rules (units, weapons, armor, AI, upgrades) are not available as loose files:
`Data/INI` contains 0 files. They live inside `INIZH.big`, and the project has no archive
reader. Any data-driven analysis or tuning is therefore blocked.

## Reproduction / evidence

```
Get-ChildItem "...\Data\INI" | Measure-Object   # Count: 0
INIZH.big magic: "BIGF"; size: 18,764,687
```

`[VERIFIED]` empty folder, archive size, and magic. Archive directory layout: `[UNKNOWN]`.

## Impact

Blocks reading/tuning gameplay data and any INI-based validation. Does not block runtime
profiling or binary instrumentation.

## Root cause

BIG archive format is not implemented in the project; parser work was intentionally deferred
during P0 (ADR-0004) at user direction.

## Workaround

None yet. Existing community tools may read BIG archives; if used, record tool name/version
and verify extracted content against known in-game values.

## Resolution / verification

**Fixed** by [`../../tools/big-archive.py`](../../tools/big-archive.py) (ADR-0008). Verified on
the stock `INIZH.big` (135 entries, `Data/INI/**` extracted) and on all 13 ShockWave `!*.gib`
archives (759-entry mod INI archive, 2,384-entry W3D archive, 968-entry texture archive). The
mixed endianness of the header (little-endian archive size, big-endian count/offset) matches
`BIGFileSystem.cpp` and is handled explicitly. Extractions go to
`artifacts/2026-11-15-shockwave-analysis/`; the installation is never written.

## History

- 2026-11-14 — recorded during P0 inventory; parsing deferred per ADR-0004.
- 2026-11-15 — fixed by the first-party reader; ADR-0008 supersedes the deferral.
