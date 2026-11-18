# EXP-029: Real shadow-map renderer — measured and rejected

- **Date:** 2026-11-17
- **Task:** T-035
- **Status:** Complete (negative) - dense alternating pairs confirm the rejection
- **Decision:** [ADR-0015](../decisions/ADR-0015-reject-shadow-map-renderer.md)
- **Supersedes:** [EXP-026](EXP-026-shadow-map-prototype.md) performance direction
- **Related:** [EXP-004](EXP-004-architecture-headroom.md), [EXP-020](EXP-020-shadow-rebuild-throttle.md), [EXP-028](EXP-028-shadow-calibration.md), [ISSUE-0058](../issues/ISSUE-0058-batched-shadow-receiver-coverage.md), [ISSUE-0066](../issues/ISSUE-0066-stress-scene-not-visible.md)

## Question

Can an opt-in light-space depth map replace the stencil volume renderer at High detail
without losing more time than it saves, and does it produce acceptable shadows?

## What was built

[VERIFIED] The prototype (development record in EXP-026/EXP-028) renders casters into a
light-space depth target, batches rigid casters into bounded draws, and applies a depth
comparison to terrain and registered receiver meshes. It is opt-in (`ZH_SHADOWMAP`), falls back
to the existing stencil path on capability failure, and was never the default. Native system
D3D8 rejects the probed R32F and INTZ targets (`8876086c`); only the pinned d3d8to9 wrapper
accepts them, so the path is wrapper-only by construction.

## Measurements

### Clean dense alternating pairs (final acceptance test, 2026-11-17)

[VERIFIED] Engine `87FC112DB3886AED91B2049899295AE2404575A9F4A4C57A97BE57769D59CCAF`, 1920x1080,
20 s per run, 1,000 stationary Crusaders on `barrenbadlands`, passable placement, spawn at frame 60,
camera pinned to the army for the whole run, d3d8to9 in **both** arms, screenshot captured inside
each run. Three alternating Stencil/ShadowMap pairs (`artifacts/2026-11-17-t035-dense/summary.json`):

| Pair | Stencil median | p95 | Shadow map median | p95 | Ratio |
|---|---:|---:|---:|---:|---:|
| 1 | 20.06 ms | 23.3 | 22.25 ms | 26.8 | 1.1093 |
| 2 | 19.91 ms | 23.1 | 23.23 ms | 27.7 | 1.1669 |
| 3 | 20.27 ms | 23.6 | 23.27 ms | 27.8 | 1.1481 |

[VERIFIED] Mean ratio **1.1415x** (range 1.1093–1.1669), every shadow-map run slower than every
stencil run. Raw frame counts differ by run (1,200/1,200, 1,320/1,080, 1,200/1,080); the
warm-up 300 frames are excluded. `A-3/scene.png` and `B-3/scene.png` show the same 1,000-tank
scene; the overlay reads 51 FPS for stencil and 43 FPS for the shadow map.

[VERIFIED] This replaces the contaminated sparse-scene pairs. The earlier dense captures below are
retained only as corroboration; the numbers above are the acceptance evidence.

### Retained dense scene (older, non-alternating; corroboration only)

[VERIFIED] Both captures are retained from the same 1,000-unit stress scene; the shadow-map run
drew 1,023 casters and nine terrain tiles.

| Backend | Frames (after 300 warm-up) | Median | p95 | p99 | Effective FPS |
|---|---:|---:|---:|---:|---:|
| Stencil (`stencil-visible-clean`) | 3,480 (45 s) | **14.47 ms** | 19.56 | 23.32 | 69.1 |
| Shadow map batched (`map-v3-verify`) | 1,680 (30 s) | **27.54 ms** | 34.04 | 37.33 | 36.3 |

[INFERRED] The shadow-map path costs about **1.90x** the stencil path in the dense scene
(27.54 / 14.47). The runs are not an alternating same-session pair and their capture durations
differ; that limits precision but not the direction or size of the result.

### Controlled alternating pairs, sparse scene (2026-11-17, wrapper on both arms)

[VERIFIED] Three alternating Stencil/ShadowMap pairs at 1920x1080, 20 s each, 1,000 units,
same options profile, same camera. `artifacts/2026-11-17-t035-ab/summary.json`:

| Pair | Stencil median | Shadow-map median | Ratio |
|---|---:|---:|---:|
| 1 | 7.90 ms | 11.16 ms | 1.41 |
| 2 | 7.84 ms | 11.57 ms | 1.48 |
| 3 | 7.81 ms | 11.36 ms | 1.45 |

[VERIFIED] Mean ratio 1.4477 (1.41–1.48). This scene contained trees/terrain (394 shadow
casters) but not the tank grid, so it is a renderer-cost comparison rather than the 1,000-unit
workload. It is still a same-session, same-camera pair with identical build and wrapper.

[VERIFIED] The shadow-map CPU submission in that scene was 2.4–3.5 ms/frame (gather 0.9–1.1,
depth 0.7–1.0, terrain 0.2–0.4, receivers 0.5–0.9, batched into three draws). Its cost exceeds
the ~0 ms it replaces in the stencil arm, which is consistent with the measured frame delta.

## Visual and coverage status

[VERIFIED] Basic terrain, trees, buildings and tanks render with the shadow-map path; the depth
target contains scene geometry (EXP-026/EXP-028). Full receiver coverage was never achieved:
batched receivers inherit caster exclusions (ISSUE-0058), so colored opaque surfaces can remain
unshadowed. Grazing acne needed hardware INTZ slope bias (1,517 → 37 mismatches in the isolated
fixture); the live path stayed on the R32F diagnostic default. No real-scene visual parity was
accepted.

## Decision

[VERIFIED] The renderer is **rejected** on the primary criterion — three clean dense alternating
pairs measure 1.1093x/1.1669x/1.1481x slower (mean 1.1415x) and the older retained captures agree
— and it additionally requires a third-party wrapper on hardware whose native D3D8 rejects the
formats. The experimental source
was removed from the engine (preserved as
`artifacts/2026-11-17-t035-rejected/renderer-hooks.patch` and `ShadowMapPrototype.inc`); stencil
shadows remain the shipped path and no gameplay or rendering default changed.

[UNKNOWN] Whether a different design (live main-depth capture with a fullscreen receiver, as
ADR-0014 proposed) could beat stencil is untested. Given the measured submission cost and the
1.90x dense-scene gap, that path would need to remove several milliseconds of fixed work, not
just receiver redraws; it is not pursued without a new cost model.

## Reproduction

- Paired runs: `tools/benchmark-shadow-map.ps1` (now stencil-only after the revert; historical
  shadow-map arms used `-Backend ShadowMap -Wrapper`) and
  `python tools/analyze-shadow-map-ab.py <artifacts> --output summary.json`.
- Retained dense evidence: `artifacts/2026-11-17-shadow-map/{stencil-visible-clean,map-v3-verify}`.
- Rejected renderer source: `artifacts/2026-11-17-t035-rejected/`.

## Limits

[VERIFIED] No network/replay or long-session certification was attempted.

[VERIFIED] The earlier sparse-scene pairs were a harness artefact, not game behaviour: the
240-frame camera pin expired before the screenshot, so captures showed the start area while the
1,000 units rendered off-screen. ISSUE-0066 is fixed by a configurable pin
(`ZH_STRESS_PIN_FRAMES` / `-PinFrames`); the 1,000-unit probe and all six dense runs capture the
army in both arms.

## Retained methods and tools

[VERIFIED] `tools/benchmark-shadow-map.ps1` is kept for stencil measurement, captured screenshots and map/harness options. `tools/test-shadow-batches.py` and `tools/check-shadow-calibration.py` target the removed renderer; they remain as the documented method for the archived source in `artifacts/2026-11-17-t035-rejected/` and are not part of the active verification suite.

## Review remediation (2026-11-18)

[VERIFIED] The retained benchmark now defaults to Stencil and rejects removed renderer-specific modes before touching preferences or launching. Future parameter receipts include the previously omitted map/harness/pin/delay/template details. Dense/rejected artifact manifests and SHA256inventories were reconstructed honestly from retained files; missing historical options remain identified as report-only claims. The frame-count sentence above is corrected from raw CSVs.

[VERIFIED] Rejected calibrated source is now tracked in [engine/rejected/T-035](../../engine/rejected/T-035/README.md), including pinned upstream/root bases, both patches and original source hashes. An isolated reconstruction verifies30affected files. The archived collector test defaults to that tracked source and passes17cases. This preserves the rejected experiment without restoring it to the active engine or claiming delivery of the unbuilt fullscreen architecture.
