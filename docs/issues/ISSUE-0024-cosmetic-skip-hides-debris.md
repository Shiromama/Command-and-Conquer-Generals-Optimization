# ISSUE-0024: debris are never drawn while CosmeticPartition is on

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-073
- **Related:** [EXP-024](../experiments/EXP-024-debris-visible.md), [docs/optimizations.md](../optimizations.md),
  `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/PartitionManager.cpp` (`update`, `getShroudedStatus`)
- **Environment:** engine `912EC1EB…3965` (before), Zero Hour ShockWave copy, Low detail

## Symptom

Reported after the DrawDistance fix: when nukes go off, the wreckage/scrap thrown off the units is
never visible, although the units do die. Census (`ZH_OBJLOG`) showed thousands of `GenericDebris`
objects existing with `debrisD = debrisV = debris` (drawable and "visible"), and the debris draw log
(`ZH_DEBRIS_LOG`, which logs at the top of `W3DDebrisDraw::doDrawModule`) recorded **zero** calls —
not even missing-model errors.

## Reproduction / evidence

```
ZH_COSMETIC_PARTITION=1  -> ZH_DEBRIS_LOG file never created (doDrawModule never called)
                            census peak: debris 4957 at frame 1379, total 8585
ZH_COSMETIC_PARTITION=0  -> "draw AVScrap2 ... / AVScrap4 ... / NVBtMstr_D2 ..." lines
                            census peak: debris 5635 at frame 1379, total 9256
```

Root cause chain:

1. `PartitionManager::update` skips the whole dirty-module handling for `GenericDebris`/`KINDOF_HULK`
   when the cosmetic skip is on, so those objects never get any
   `CellAndObjectIntersection` (COI) entries.
2. `PartitionData::getShroudedStatus()` treats `m_coiInUseCount == 0` as *"stuff off the map"* and
   returns `OBJECTSHROUD_SHROUDED`.
3. `GameClient::updateDrawables` calls `draw->setFullyObscuredByShroud(ss >= OBJECTSHROUD_FOGGED)`,
   so every debris drawable is flagged fully obscured and never reaches its draw module.

## Impact

All debris/hulk wreckage is invisible whenever `CosmeticPartition=yes`, which T-064 had made the
default — i.e. the default build never showed wreckage. The "big tail win" that justified the default
(EXP-021: p95 49.7 → 22.2 ms) was partly the cost of *not drawing* the debris.

## Workaround

`CosmeticPartition = no` in `Options.ini` (or `ZH_COSMETIC_PARTITION=0`).

## Resolution / verification

Two changes (T-073):

1. `PartitionData::getShroudedStatus()`, zero-COI branch: cosmetic objects (`GenericDebris`,
   `KINDOF_HULK`) now report `OBJECTSHROUD_CLEAR` instead of `SHROUDED`, so they are drawn even
   though the skip leaves them without cells (they are cosmetic — a fog leak is harmless).
2. `getCosmeticPartitionEnabled()` now defaults to **off**: with debris actually drawn, the skip is
   no longer a win (same-session 1,000 × 5 nuke runs: skip off 3.78 ms / 264.2 FPS median, p95
   32.87 ms / 30.4 FPS; skip on 4.08 ms / 244.8 FPS, p95 37.30 ms / 26.8 FPS).

Verified: with `ZH_COSMETIC_PARTITION=1`, `ZH_DEBRIS_LOG` now records `draw AVScrap4 …` lines where
it previously recorded nothing.

## History

- 2026-11-17 — reported by the user; traced to the cosmetic skip → zero COIs → SHROUDED; fixed with
  the shroud exception and the default flipped to off.

## Follow-up (T-076): the feature is gone

The whole `CosmeticPartition` path was removed: the skip in `PartitionManager::update`, the
`ZH_COSMETIC_PARTITION` env switch, the `Options.ini` key, its `OptionPreferences` getter, and the
zero-COI shroud exception (the partition code is back to stock semantics). Tools no longer set the
variable. `DrawDistance` remains the only opt-in cull.

Verified: `ZH_COSMETIC_PARTITION` is absent from the built binary and no source or tool reference
remains; engine `059B5E7A…DC0F` staged in both copies, smoke run 6.89 ms (145.2 FPS).
