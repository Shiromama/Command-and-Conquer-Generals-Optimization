# EXP-024: debris visibility, the cosmetic skip, and what the tail win really was

> **Status:** complete · **Date:** 2026-11-17 · **Task:** T-073
> **Related:** [ISSUE-0024](../issues/ISSUE-0024-cosmetic-skip-hides-debris.md),
> [EXP-021](EXP-021-shipping-package-tail.md), [EXP-023](EXP-023-draw-distance-default.md)

## 1. Question

After the DrawDistance fix the user reported that the wreckage thrown off units by a nuke is never
visible. Earlier work (EXP-021) had credited the debris partition skip with a large tail win
(p95 49.7 → 22.2 ms). Are the two related?

## 2. Diagnosis

- Census (`ZH_OBJLOG`) in a 5-cycle nuke run: peak **4,957 debris** objects, all with drawables and
  flagged visible — so the pieces exist.
- Debris draw log (`ZH_DEBRIS_LOG`, logged at the top of `W3DDebrisDraw::doDrawModule`):
  - `ZH_COSMETIC_PARTITION=1` → **no log file at all** (the function is never called);
  - `ZH_COSMETIC_PARTITION=0` → `draw AVScrap2/4 …`, `draw NVBtMstr_D2/D3 …`.
- Cause: the cosmetic skip leaves debris with zero cell intersections; `PartitionData::getShroudedStatus()`
  maps "no COIs" to `OBJECTSHROUD_SHROUDED`; `GameClient` then flags the drawable fully obscured, so it
  never draws. See ISSUE-0024 for the code path.

## 3. Fix

`PartitionData::getShroudedStatus()`, zero-COI branch: cosmetic objects (`GenericDebris`,
`KINDOF_HULK`) report `OBJECTSHROUD_CLEAR` instead of `SHROUDED`. With the fix, the skip-on build
records debris draws again.

## 4. Measurements (engine `556CB3DC`, 1,000 units × 5 nuke cycles, Low detail, same session)

| configuration | median | FPS | p95 | FPS@95 | p99 |
|---|---:|---:|---:|---:|---:|
| skip **off** (debris visible via cells) | 3.78 ms | 264.2 | 32.87 ms | 30.4 | 43.77 ms |
| skip **on** + shroud fix (debris visible via exception) | 4.08 ms | 244.8 | 37.30 ms | 26.8 | 53.62 ms |
| (reference) skip **on**, debris invisible (pre-fix, `D337B939`) | 4.46 ms | 224.9 | 22.22 ms | 45.0 | 35.16 ms |
| **shipping after the fix** (`B8F73520`, skip off by default) | **4.13 ms** | **241.9** | **36.38 ms** | **27.5** | **48.72 ms** |

## 5. Reading it

- The old "tail win" was largely **not drawing the debris**: once the pieces actually render, the
  skip is slightly *slower* than not skipping (p95 37.3 vs 32.9 ms) — the cell churn it avoids is
  cheaper than the always-clear draw set it creates.
- So the feature does not pay for itself in its correct form. `CosmeticPartition` now defaults to
  **off**, remains available as an option, and the shroud fix stays so it is not a bug if enabled.

## 6. Heal/repair effect check (side question)

A no-nuke radiation session (300 units, 9 radiation fields, heal pulse every 15 logic frames,
`ZH_ICON_LOG`) ran for 7 minutes:

| counter | max | frames > 0 |
|---|---:|---:|
| `healIcons` | **272** | 19,677 of 56,052 (35%) |
| `healPulses` | 300 | 1,317 (2%) |
| `bars` | 0 | 0 |

The heal-icon pass is working: it drew up to 272 icons and did so on a third of all frames, so the
"can't see healing" report is not a broken path. `bars` staying at 0 is expected (health bars show
for selected/hovered units, not for the whole army).

## 7. Artifacts

`artifacts/2026-11-17-debris-diag/` — `run5`/`run6` (draw logs `d5.log`/`d6.log`), `p1`, `p2`
(skip on + fix), `off1`, `off2` (skip off), `perf1`, `perf2` (first-registration variant);
`artifacts/2026-11-17-heal-watch/` — `icons.csv` (56k frames), `perf.csv`, `objects.log`.

## 8. Follow-up (T-076): feature removed

`CosmeticPartition` was deleted outright after this report: skip block, env switch, `Options.ini`
key, `OptionPreferences` getter and the shroud exception. `DrawDistance` stays as the only opt-in
cull. Binary `059B5E7A…DC0F` no longer contains `ZH_COSMETIC_PARTITION`.
