# ADR-0011: Measure pathfinding and gate a separate shadow-map renderer

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** User (authorize both tasks), Codex (implementation)
- **Related:** T-022, T-035, ADR-0010

## Context

[VERIFIED] Current vendor defaults s_useFixedPathfinding=false. The first centered telemetry smoke exercised queues up to 234 cells and only the retail-compatible branch. This is diagnostic evidence; accepted baseline collection follows a fully passable placement smoke. Existing projected/decal shadows were rejected (EXP-007).

## Decision

Instrument peer search routines without changing costs, caps, ordering, pools or object layouts. Run a deterministic logic-frame workload behind experimental singleplayer gating. Compare request, expansion and path fingerprints across repetitions before evaluating algorithm changes. A measured no-change decision is an acceptable T-022 result when correctness risk outweighs evidence for a gain.

Build T-035 as a separate opt-in global light-depth renderer, leaving stencil volumes as capability/error fallback. Start with a floating-point color render target plus a conventional depth surface, orthographic light view, shader depth comparison, terrain and mesh receiver passes. Probe actual Direct3D 8 capabilities; do not assume D3D9 formats or shaders work through the legacy API. Do not enable the renderer by default until visual coverage, resource lifecycle and performance are verified.

## Consequences

[UNKNOWN] Floating-point target support, material coverage, bias, map coverage and speed remain to be tested. A successful build is not visual or performance acceptance. The first prototype may need a wrapper or a different depth representation. Rendering changes cannot justify simulation changes.

- **Outcome (2026-11-17):** Rejected on measured cost; see [EXP-029](../experiments/EXP-029-shadow-map-rejected.md) and [ADR-0015](ADR-0015-reject-shadow-map-renderer.md). The renderer was not retained.
