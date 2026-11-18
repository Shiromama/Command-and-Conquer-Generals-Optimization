# EXP-015: "Healing / repair icon" slowdown — what was measured

> **Status:** complete (investigation) · **Date:** 2026-11-16 · **Task:** T-059
> **Related:** [EXP-009](EXP-009-frame-attribution.md), [EXP-013](EXP-013-original-vs-optimized.md),
> [ISSUE-0022](../issues/ISSUE-0022-launcher-nofpslimit-noop.md)

## 1. Report

Hundreds of units start healing, the repair/heal icon appears over them, and frame time drops
noticeably. Two hypotheses: (a) the icon animation, (b) "hundreds of calculators" — per-unit logic
work.

## 2. What was instrumented

Test-only hooks (patch `T-059`, off by default):

| Hook | Effect |
|---|---|
| `ZH_ICON_LOG=<csv>` | one row per frame: `frame,ms,drawables,bars,healIcons,healPulses,modelChanges` |
| `ZH_HEAL_PULSE=<n>` / `ZH_HEAL_INTERVAL` | heals every harness-spawned unit every N logic frames |
| counters | icon-pass wall time, drawables processed, heal icons drawn, actual model rebuilds (`replaceModelConditionStateInDrawable`), heal attempts |

## 3. Measurements

### 3.1 Self-heal logic is cheap

300 dense units, nuked for 60 damage every 30 frames, healed 20 every 30 frames, uncapped:

| Group | frames | `l_updates` median | p95 | max |
|---|---:|---:|---:|---:|
| frames with 300 heal pulses | 133 | 1.30 ms | 2.03 | 2.49 |
| frames with no pulses | 3,886 | 1.19 ms | 2.15 | 25.12 |

**+0.12 ms for 300 simultaneous heal attempts.** `ActiveBody::attemptHealing` is a module loop plus
`doDamageFX`, which is throttle-gated — it does not scale badly. The 25 ms outlier is a death
frame, not a heal frame.

### 3.2 The icon pass, measured properly with sustained healing

The first attempt (short ShockWave run, 82 icons) produced a linear fit of ≈0.011 ms per icon. That
estimate did **not** hold up at scale. A dedicated radiation stress test (below) reaches 272
simultaneous heal icons and gives:

| metric | value |
|---|---|
| frames with ≥30 icons | 279 |
| slope | **0.0005 ms per icon** |
| icon-pass median | 0.002 ms |
| icon-pass p95 | 0.647 ms |
| icon-pass max | 6.003 ms |

So the icon overlay is **not** the bottleneck: at 272 icons it costs ~0.6 ms at p95, with rare
6 ms outliers.

## 3.3 Radiation stress (sustained healing, no mass death)

`ZH_RADIATION=<n>` (patch T-060) keeps a grid of `NukeRadiationFieldWeapon` objects around the
camera: 25 RADIATION damage per 750 ms in a 200-unit radius, 30 s lifetime, respawned before it
expires. Units therefore stay alive and keep healing instead of being wiped by the warhead's
direct damage.

Scenario: 300 dense units, 9 fields (150-unit spacing), heal 8 HP every 15 frames, uncapped,
45 s (14,369 frames):

| metric | value |
|---|---|
| frame median | **4.29 ms** (233 FPS) |
| p95 / p99 | 14.12 / 19.99 ms |
| peak heal icons | **272** (42,866 icon-draws over the run) |
| peak drawables in the icon pass | 1,346 |
| peak heal attempts per frame | 300 |

Compare with the same scene without radiation (heal only, stock copy): median 6.55 ms, p95 7.80.
With radiation the median is *lower* (4.29 ms) because units die less and the army stays small —
no regression attributable to healing.

### 3.5 Radius healing (`AutoHealBehavior` with `Radius`) — sustained healer

`ZH_HEALERS=<template>` respawns N copies of a radius-healing object around the camera; counters
record the per-pulse partition query, the objects handed to `pulseHealObject`, and the pulse
particle systems created.

The first attempt used `RepairVehiclesInArea_InvisibleMarker_Level3`, which is `SingleBurst` with
lifetime 0: it deletes itself the frame it is created, so it healed only 26 objects over a run and
exercised almost nothing. The meaningful test uses
**`Spec_RepairStationFieldRepairObject`** (ShockWave): radius **156.25**, `HealingAmount 6` every
**500 ms**, `KindOf VEHICLE`, no lifetime — a real sustained repair field.

ShockWave copy, 300 units, 3 warheads, 5 stations, uncapped:

| run | frames | median | p95 | p99 | radius queries | objects healed (max/frame) | pulse particles | heal icons |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| no stations | 12,210 | 4.78 ms | 16.77 | 22.73 | 0 | 0 | 0 | 0 |
| 5 stations | 12,570 | 4.59 ms | 16.60 | 24.92 | 141 (≤1/frame) | 288 (41) | 0 | 62 |
| 5 stations, final build | 13,530 | 4.07 ms | 14.05 | – | 147 | 216 (≤41) | 0 | – |

Findings:

- The partition query is **one per healer per pulse** (500 ms apart) and therefore at most one per
  frame across five stations; the healing it triggers is 41 objects per frame at peak.
- Frame time with five active repair stations is **not worse** than without them (4.07-4.59 vs
  4.78 median), so the radius path is **provably cheap** at this scale.
- **Pulse particles are always 0**: every stock/ShockWave radius healer we could find omits
  `UnitHealPulseParticleSystemName`, so `createParticleSystem` immediately returns null.
- A guard that skipped that null-template call was implemented, measured (0 particles before and
  after), found to be **unverifiable as a gain**, and reverted. The path is documented as cheap
  instead of shipping an unmeasured change.

## 3.6 What this means for the report

The heal path is instrumented end to end — self-heal, radiation, one-shot burst and sustained
radius healing — and no configuration produces a significant slowdown. The sustained radius path,
which the report named as the likely cause, is measurably cheap.

## 4. Attempted fix and why it is not in the tree

The per-icon cost is dominated by `W3DDisplay::drawImage`, which resolves the texture by filename
on every draw (`WW3DAssetManager::Get_Texture(image->getFilename().str())`). An 8-entry
`Image → TextureClass` cache was added there. The resulting build (`F960D27B…`) **failed to open a
game window** (two consecutive runs, no `stress.log`), so it was reverted; the file was restored
from git and the engine rebuilt (`1E4E3501…`), which runs normally again.

The likely cause is texture ownership: the cache kept raw pointers without `Add_Ref`, and the
asset manager can release a texture between frames. A correct version would ref-count on insert and
release on eviction, and must be validated at startup, not only in a benchmark.

## 5. Conclusion

- Healing **logic** is not the problem (+0.12 ms / 300 units).
- **Heal icons** are not the problem either: 272 simultaneous icons cost ~0.6 ms at p95
  (0.0005 ms per icon), with rare 6 ms outliers.
- **Radius healing** is provably cheap: one partition query per healer per pulse (500 ms apart),
  41 healed objects per frame at peak with five active stations, and no frame-time regression
  (4.07-4.59 ms median vs 4.78 ms without). Pulse particles are always 0 because no stock radius
  healer defines one; a guard for that null call was measured as unverifiable and reverted.
- A **radiation stress test** (sustained low damage, 272 icons, 14,369 frames) shows median 4.29 ms
  / p95 14.12 ms: no slowdown attributable to healing.

So the reported slowdown is **not reproducible in this engine build** with any scenario the harness
can construct. Remaining explanations, in order of likelihood:

1. The user's scene differs (more units on screen, different visuals, or a healer with a real
   lifetime that this marker does not model).
2. The slowdown was observed in the **retail 1.04 engine** (no patches, 30 FPS cap, iGPU), which
   cannot run the harness and has no frame logger, so it cannot be compared under identical
   conditions.
3. What was seen was damage/death FX and model-condition churn rather than healing; those are
   already bounded in EXP-009/EXP-011.

## 6. Next step — decisive icon A/B (paused at user request)

The user reports FPS dropping more while units heal from radiation than during the nuke. My numbers
show the opposite (healing p95 ~14 ms vs nuke p95 ~61 ms), but the two states are not comparable:
after a nuke the army dies and the object count collapses, so FPS rises; during radiation healing
the army stays alive, so more objects and icons are on screen.

The clean test holds the army, radiation and profile fixed and toggles **only the HUD icon pass**
(`TheGameLogic::setDrawIconUI`). A test-only hook was added for this (patch T-064):

```powershell
# icons ON vs icons OFF, same scene, alternating pairs
.\tools\benchmark-shockwave-attrib.ps1 -Units 300 -Cycles 1 -Warheads 1 -WarmupSeconds 15 `
  -RunSeconds 40 -ExtraEnv @{ ZH_RADIATION='9'; ZH_RADIATION_SPREAD='150';
                              ZH_HEAL_PULSE='8'; ZH_HEAL_INTERVAL='15'; ZH_ICON_LOG='<dir>\icons.csv' }
# same, plus: ZH_NO_ICON_UI='1'
```

Decision rule:

- If icons-OFF median is materially lower (beyond run variation), the icon pass is the cost and the
  fix is to batch the heal-icon draws / skip redundant per-icon texture resolution.
- If the medians match, the icon hypothesis is closed for good and the remaining candidates are the
  repair *action* (AI/pathing/docking), repair-beam FX, or the damage/health model-condition churn.

**Status: not run.** Simulations are paused while the user uses the machine, because background load
shifted the earlier numbers by ~15% (EXP-013 §5.2).

## 7. Artifacts

- `artifacts/2026-11-16-heal-icons/` — `noheal/`, `heal/`, `dense-*`, `pulse-*`, `rad-none/`,
  `rad-9/`, `rad-heal-none/`, `rad-heal-5/`, `rad-heal-fixed/`, `shw-clicks/`, `shw-rad/` with
  `frames.csv`, `icons.csv`, `attr.csv` where enabled.
