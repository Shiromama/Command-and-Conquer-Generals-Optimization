# ADR-0014: Use sampled main depth for complete opaque shadow receivers

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Codex (authorized T-035 scope)
- **Related:** T-035, ADR-0011, ADR-0013, ISSUE-0058, ISSUE-0065

## Context

[VERIFIED] Per-caster receiver geometry cannot cover every visible non-caster material, and repeated receiver submissions add cost. EXP-028 proves INTZ creation/sample through the wrapper and a PS1.4fullscreen comparison core against analytic geometry. A normalized homogeneous matrix keeps constants valid; RGB carries required data across phases. Perspective diagonal comparison has0stable mismatches; angled map-light comparison with hardware-biased INTZ light depth has37/1,012,711stable mismatches, below unchanged0.1%tolerance, with no false roof-core shadow. Full live-scene capture remains unimplemented.

## Decision

Implement the real scene's opaque receiver stage from sampleable main depth and one fullscreen light comparison. Keep bounded rigid caster batches. Prefer sampled hardware light depth with slope bias over an un-biased color-depth representation for grazing surfaces. Probe INTZ, shader and forwarded slope-state support; reject unsupported configurations to the existing stencil path. Keep stencil default until real-scene coverage, lifecycle and native performance gates pass.

Capture/restore depth at the actual clear/render lifecycle. Preserve original depth/stencil state, handle resize/reset/map changes and ignore unrelated offscreen render targets. Do not clear a preserved-depth scene incorrectly or sample a texture while it is bound for depth writing. The registered callback, if used in the renderer library, must default to null and avoid a dependency on game-client code. Calibration must remain an isolated opt-in mode.

## Consequences

[UNKNOWN] Opaque world depth should cover receivers omitted by caster eligibility; actual material/decal/water ordering, transparent surfaces, sky rejection, offscreen shadows and scene transitions still need runtime verification. No final speedup or complete receiver coverage is accepted from a toy scene. Native system D3D8 rejects the probed INTZ target; wrapper requirement and stencil fallback stay explicit. R32F/geometry modes remain diagnostic alternatives, not a finished default.

- **Outcome (2026-11-17):** Rejected on measured cost; see [EXP-029](../experiments/EXP-029-shadow-map-rejected.md) and [ADR-0015](ADR-0015-reject-shadow-map-renderer.md). The renderer was not retained.
