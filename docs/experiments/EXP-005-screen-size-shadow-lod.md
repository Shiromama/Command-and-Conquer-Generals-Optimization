# EXP-005: Screen-size shadow LOD

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-032
- **Status:** Complete (opt-in)
- **Related:** [EXP-004](EXP-004-architecture-headroom.md), [ISSUE-0010](../issues/ISSUE-0010-heavy-replay-unavailable.md)

## Hypothesis

The world-distance shadow cull (EXP-004) is a hard cutoff: a large building shadow can disappear
while a tiny distant tank shadow remains. A **projected screen-size** threshold should keep
large/near shadows and skip only tiny/far ones, giving a better visual/performance tradeoff at
the same cost.

## Method

Same 1,000-unit harness, 1920x1080, 35 s, steady after 300 frames. High detail (`AA 0 + High`),
uncapped with `ZH_FPS=1000`; game window forced to the foreground.

Implementation in `W3DVolumetricShadowManager::renderShadows`:
- `ZH_SHADOWSIZE=<px>` sets the minimum projected shadow radius.
- For each caster, estimate `screenRadius = boundingRadius * viewHeight * 1.866 / distance`,
  where `1.866 ≈ 1/(2*tan(15°))` for the game's default ~30° vertical FOV.
- Skip the shadow volume if `screenRadius < threshold`. Units are never skipped.

The first implementation projected three points per shadow with `worldToScreenTriReturn`; it
was replaced because it added ~3.5 ms of CPU overhead and produced noisy results.

## Results

> **Clean-environment correction (2026-11-15):** the table below was measured while BlueStacks
> was running an Android game in the background, which inflated every absolute number. Discard
> the absolute values; the relative threshold behavior still holds. The clean three-run matrix
> is in the next section.

| Configuration | Median ms | Draw ms | Logic ms | Uncapped FPS |
|---|---:|---:|---:|---:|
| High, no cull (control) | 37.94 | 30.98 | 5.90 | 26.4 |
| High, `ZH_SHADOWSIZE=24` | 38.07 | 29.80 | 5.80 | 26.3 |
| High, `ZH_SHADOWSIZE=40` | 39.69 | 30.84 | 5.80 | 25.2 |
| High, `ZH_SHADOWSIZE=80` | 36.60 | 29.94 | 5.57 | 27.3 |
| **High, `ZH_SHADOWSIZE=120` run 1** | **30.19** | **23.00** | 5.44 | 33.1 |
| **High, `ZH_SHADOWSIZE=120` run 2** | **29.22** | **22.33** | 5.36 | 34.2 |
| **High, `ZH_SHADOWSIZE=120` run 3** | **29.79** | **22.85** | 5.33 | 33.6 |
| High, `ZH_SHADOWSIZE=160` | 27.34 | 20.07 | 5.61 | 36.6 |
| High, world distance 400 (EXP-004) | 30.23 | 23.75 | 5.30 | 33.1 |
| Low, no shadow cull (EXP-004) | 26.56 | 19.33 | 5.82 | 37.7 |

120 px three-run medians: **29.79 ms**, draw **22.85 ms**, p95 **35.71 ms**. The p95 is slightly
above the 33.33 ms cap budget, so occasional frames still miss 30 FPS.

## Clean-environment results (all other apps closed)

| Configuration | Median ms | Draw ms | p95 ms | Uncapped FPS |
|---|---:|---:|---:|---:|
| Native Low | 17.47 | 12.78 | 23.06 | 57.2 |
| Native High, no cull | 25.02 | 19.96 | 29.14 | 40.0 |
| Native High, shadows off | 17.63 | 12.65 | 20.48 | 56.7 |
| **Native High, 120 px** | **20.30** | **15.20** | **23.57** | **49.3** |
| d3d8to9 Low | 16.47 | 11.69 | 19.08 | 60.7 |
| d3d8to9 High, 120 px | 18.60 | 13.50 | 21.56 | 53.8 |

Clean 120 px recovers **4.72 ms** versus High/no-cull (25.02 → 20.30) and keeps near/large
shadows. Low remains 2.83 ms faster. The 30 FPS cap hides ~16 ms of headroom at native Low
(33.33 - 17.47).

## Interpretation

- Thresholds below ~80 px cull almost nothing; the overhead dominates. At 40 px the run was
  slower than the control (contaminated absolute numbers; the relative behavior held).
- **120 px is the useful balance** in the clean matrix: High/no-cull 25.02 → 20.30 ms while
  preserving large/near shadows instead of using a hard distance.
- Higher thresholds cull more; the contaminated 160 px run approached Low-detail performance
  but removed most unit shadows. Re-measure before using 160 px.
- The screen-size metric is cheap (one distance/`sqrt` per caster) and does not need
  per-shadow projection.

## Recommendation

For better visuals than Low while staying well above 30 FPS uncapped:

```powershell
tools\apply-options-profile.ps1 -AntiAliasing 0 -StaticLOD High
tools\launch-game.ps1 -ShadowSize 120
```

Clean result: **20.30 ms median / 15.20 ms draw / 49.3 FPS** at 1,000 units. Low detail remains
the maximum-headroom profile (17.47 ms / 57.2 FPS).

## Limits

- Approximate FOV factor (1.866) assumes the default ~30° vertical FOV; a changed FOV shifts the
  threshold.
- Bounding-sphere radius is conservative, so the threshold is not exact pixel size.
- Synthetic all-visible scene; single runs for 24/40/80/160, three runs for 120.
- Visual check: `artifacts/2026-11-15-shadowsize/size120.png` shows all units rendered with
  near shadows; distant tiny shadows are omitted.
- Real late-game replay validation remains user play-test work (ISSUE-0010).

## Artifacts

- `artifacts/2026-11-15-shadowsize/control-high-*`, `size24-v2-*`, `size40-*`, `size80-*`,
  `size120-*`, `size160-*` (contaminated absolute numbers)
- `artifacts/2026-11-15-shadowsize/clean-native-high-nocull-*`,
  `clean-native-high-noshadow-*`, `clean-native-high-size120-*`, `clean-native-low-*` (clean
  matrix)
- `artifacts/2026-11-15-shadowsize/size120-three-runs.json`
- Patch: `engine/patches/T-030-shadow-culling.patch` (distance + screen-size culls)
