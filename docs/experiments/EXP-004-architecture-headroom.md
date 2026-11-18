# EXP-004: Architecture headroom and shadow-volume cost

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Tasks:** T-030, T-031
- **Status:** Complete (research); shadow distance is opt-in
- **Related:** [EXP-001](EXP-001-msaa-entity-heavy.md), [EXP-003](EXP-003-static-low-detail.md), ISSUE-0010

## Question

The 30 FPS cap hides whether architecture/design changes can still buy performance. Which part
of the frame is the real limit at 1,000 units, and which structural change is worth doing?

## Method

Same harness scene as EXP-001/003: `maps\northamerica\northamerica.map`, 1,000
`AmericaTankCrusader`, 1920x1080 unless noted, 35 s, steady after 300 frames.

The harness gained a test-only `ZH_FPS` argument (sets `MSG_NEW_GAME`'s FPS cap) because the
`-noFPSLimit` command line is overwritten when the detail preset applies. `ZH_NOSHADOW` and
`ZH_SHADOWDIST` are test-only hooks in the engine build; `0`/unset keeps retail behavior.

| Build | SHA-256 |
|---|---|
| Uncapped/headroom build (T-030) | `C635317198910918FBDAE7CCFB2FDD9CF348A5CEB2388C3BD678C9F5B837187E` |

## Results

> **Clean-environment correction (2026-11-15):** the table below was measured while BlueStacks
> was running an Android game in the background. It inflated every absolute number. The relative
> conclusions held, but use the clean matrix at the end of this section for current numbers.

| Configuration | Cap | Median ms | Draw ms | Logic ms | Effective FPS |
|---|---:|---:|---:|---:|---:|
| AA 0 + Low | 30 | 33.36 | 18.45 | 5.74 | 30.0 (capped) |
| AA 0 + Low | uncapped | **26.56** | 19.33 | 5.82 | **37.7** |
| AA 0 + Low, 1280x720 | uncapped | 21.79 | - | - | 45.9 |
| AA 0 + High | 30 | 35.05 | 27.26 | 4.49 | 28.5 |
| AA 0 + High | uncapped | 37.23 | 29.86 | 5.73 | 26.9 |
| AA 0 + High, 1280x720 | uncapped | 31.07 | - | - | 32.2 |
| AA 0 + High, shadows off | uncapped | **26.09** | 19.08 | 5.35 | **38.3** |
| AA 0 + High, shadow distance 400 | uncapped | **30.23** | 23.75 | 5.30 | **33.1** |
| AA 0 + High, shadow distance 600 | uncapped | 32.96 | 26.30 | 5.44 | 30.3 |

Single runs for the uncapped variants; the capped Low result is the 3-run median from EXP-003.
The frame logger flushes per frame, so uncapped numbers include logging overhead.

### Clean-environment matrix (all other apps closed)

| Configuration | Median ms | Draw ms | p95 ms | Uncapped FPS |
|---|---:|---:|---:|---:|
| Native Low | 17.47 | 12.78 | 23.06 | 57.2 |
| Native High, no cull | 25.02 | 19.96 | 29.14 | 40.0 |
| Native High, shadows off | 17.63 | 12.65 | 20.48 | 56.7 |
| Native High, 120 px shadow LOD | 20.30 | 15.20 | 23.57 | 49.3 |
| d3d8to9 Low | 16.47 | 11.69 | 19.08 | 60.7 |
| d3d8to9 High, 120 px | 18.60 | 13.50 | 21.56 | 53.8 |

The clean data confirms the conclusion: High/no-cull is 7.55 ms slower than Low, shadows-off is
essentially Low, and 120 px recovers 4.72 ms of that gap. The 30 FPS cap hides ~16 ms of
headroom at Low (33.33 - 17.47); architecture changes matter for larger battles or higher FPS,
not for the displayed 30 FPS at 1,000 units.

## Findings

1. **The 30 FPS cap hides ~16 ms of headroom at Low detail.** Clean uncapped Low is 17.47 ms
   (57.2 FPS) versus the 33.33 ms cap. At 1,000 units the engine has spare time; further
   architecture work only helps larger battles, higher FPS, or lower power/latency.
2. **High detail is genuinely renderer-bound.** Clean uncapped High is 25.02 ms (40.0 FPS), so
   the capped 30 FPS is not a pacer artifact at high detail.
3. **The High-vs-Low gap is ~7.5 ms clean** (25.02-17.47), so it is not simply a frame-pacer
   effect. The earlier resolution sweep showed fill is only part of it.
4. **Shadow volumes are that gap.** Clean High + shadows off is 17.63 ms (56.7 FPS),
   essentially identical to Low. Lightmaps, clouds, trees, and particles are not the dominant
   cost in this scene. This matches the shadow manager building and drawing two stencil passes
   per caster (`W3DVolumetricShadow::renderShadows`).
5. **A shadow budget recovers most of it.** Clean High + 120 px shadow LOD is 20.30 ms
   (49.3 FPS) with large/near shadows kept; the contaminated distance-400 run pointed the same
   way. This is a shadow-only tradeoff, not a unit cull.
6. **The renderer already batches by FVF/texture.** `DX8MeshRenderer` groups draw work into
   FVF/texture categories and flushes in sorted passes; draw calls are not per unit. Per-object
   shadow-volume work and per-object render/lighting setup are the remaining costs.
7. **Logic is not the bottleneck.** It stays 5.3-5.8 ms across all configurations. A spatial
   index for drawable iteration would not help a scene where all 1,000 units are visible, and
   multithreading logic has a small ceiling here.

## Architecture options, ranked by evidence

| Option | Expected gain | Risk / cost | Verdict |
|---|---|---|---|
| Screen-size shadow LOD (tested: 120 px) | **~4.7 ms at High** | Low; only tiny/far shadows removed | **Validated (EXP-005)** |
| Replace stencil volumes with shadow maps or blob decals | Potential ~7–8 ms, keeps a shadow | Medium-high; new renderer path, visual change | Prototype candidate |
| Disable shadows at High detail | ~7.4 ms, matches Low | Visual loss; user-facing setting | Already available |
| Batch/instance identical units | Unknown, likely small | High; D3D8, animations/per-unit transforms | Low priority after shadow evidence |
| Drawable spatial index | ~0 in this scene | Medium; existing region lists | Only for off-screen-heavy maps |
| Multithread logic/particles | <5.8 ms ceiling | High CRC/compatibility risk | Not justified yet |
| D3D8 -> D3D9/11/Vulkan backend | Potentially large | Very high; new backend | Long-term, not a tweak |

## Recommendation

Do **not** rewrite the renderer architecture yet. The measured levers are:

1. **Low detail** for maximum headroom: 17.47 ms uncapped, ~16 ms under the cap.
2. **High detail + `-ShadowSize 120`** for better visuals while still above 30 FPS uncapped:
   20.30 ms; keeps lightmaps, trees, particles, and near/large shadows (EXP-005).
3. If more headroom is needed at High detail, prototype **shadow maps or blob shadows** (T-034)
   rather than further shrinking the stencil path, then measure it on a real late-game replay.

## Limits

- Synthetic scene; all units are clustered and visible. Real maps have off-screen units and
  buildings, where shadow distance and spatial partitioning behave differently.
- `ZH_SHADOWDIST` is a world-space approximation; a screen-size threshold would preserve
  visuals better. The 400/600 thresholds are single-run comparisons.
- Test-only hooks (`ZH_FPS`, `ZH_NOSHADOW`, `ZH_SHADOWDIST`) are not for normal play.
- Late-game replay validation is still blocked (ISSUE-0010).

## External comparison

See [`../research/2026-11-15-external-performance-research.md`](../research/2026-11-15-external-performance-research.md).
Upstream already merged particle batching and render/logic decoupling; the drawable-partition
PR is open. OpenSAGE replaced SAGE shadow volumes with shadow maps for the same
modern-hardware reason. Our shadow-bound result is consistent with both.

## Artifacts

- `artifacts/2026-11-15-architecture-research/manifest.md`
- `zhfps1000-low-*`, `zhfps1000-high-*`, `zhfps1000-high-720p-*`,
  `zhfps1000-low-720p-*`
- `high-noshadow-*`, `high-shadowdist400-*`, `high-shadowdist600-*`
- Patch: `engine/patches/T-030-shadow-culling.patch`

