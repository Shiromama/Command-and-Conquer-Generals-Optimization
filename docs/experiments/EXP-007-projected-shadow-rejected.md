# EXP-007: Projected/decal shadow prototype (rejected)

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-034
- **Status:** Rejected; prototype reverted
- **Related:** [EXP-004](EXP-004-architecture-headroom.md), [EXP-005](EXP-005-screen-size-shadow-lod.md)

## Hypothesis

The engine already has a projected-shadow/decal path (`SHADOW_PROJECTION`, `SHADOW_DECAL`) used
by trees and debris. If it is cheaper than stencil shadow volumes, it could keep a shadow for
every unit and avoid the High-detail cost.

## Method

Test-only override in `W3DModelDraw` (`ZH_SHADOWTYPE=projection|decal`) that changes unit model
shadows from `SHADOW_VOLUME` to the existing projected/decal path. High detail, 1,000 units,
1920x1080, uncapped, clean environment (other apps closed). Reverted afterward.

## Results

| Variant | Median | Draw | Result |
|---|---:|---:|---|
| High, stencil volumes (control) | 25.02 | 19.96 | baseline |
| High, `ZH_SHADOWTYPE=projection` | — | **987 ms** | stalled creating render-to-texture shadows; only 180 frames; rejected |
| High, `ZH_SHADOWTYPE=decal` | 20.37 | 14.72 | fast, but no clearly visible unit shadows at this scale; not better than 120 px LOD |
| High, 120 px shadow LOD (T-032) | 20.30 | 15.20 | validated alternative |

The projected path creates/caches a shadow texture per model and stalls on the first unit-heavy
scene. The decal path uses `shadow.tga`, but the default template size/offset produced no
clearly visible shadow under the tanks; its cost is comparable to the 120 px LOD, so it offers
no advantage.

## Decision

Reverted the prototype. Keep the **120 px screen-size shadow LOD** (T-032) as the validated
High-detail shadow budget. A real shadow-map path would require a renderer project (depth
target, light-space matrix, projective sampling in the W3D fixed-function/shader path), not a
model-draw override. That is tracked as a larger future task, not a quick tweak.

## Verification after revert

- `ZH_SHADOWTYPE` removed from the source; `W3DModelDraw.cpp` back to baseline.
- Rebuilt engine `7C3CE0AD24D6E8439E7994C923C838DB1EFF92DCE9944F8546B7D1D2A29ABE21`.
- Confirmation run, High + 120 px: **20.32 ms median, draw 15.46 ms, 49.2 FPS** (matches the
  clean 20.30 / 15.20 result).
- Options restored to AA 0 + Low.

## Artifacts

- `artifacts/2026-11-15-shadowtype/projection-*` (stalled render-to-texture)
- `artifacts/2026-11-15-shadowtype/decal-*`, `decal-topmost.png`
- `artifacts/2026-11-15-shadowtype/confirm-size120-*` (post-revert)
