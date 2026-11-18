# ADR-0013: Batch rigid shadow geometry with explicit GPU light projection

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Codex (authorized T-035 prototype)
- **Related:** T-035, ADR-0011, ISSUE-0050, ISSUE-0058

## Context

[VERIFIED] Native prototype submits over10,000 material installs per depth/receiver pass. Seven bounded batches hold9,329 rigid meshes /248,043 triangles. Explicit vertex coordinates render, but CPU rebuilding takes12ms. Vertex shader1.1 plus world-vertex caching cuts depth/receiver submission to roughly1-2ms each while collection remains around10ms (native-cached-batch CSV). Receiver coverage remains incomplete because it shares caster exclusions.

## Decision

Keep the renderer opt-in. Use world-space rigid geometry batches bounded to60,000vertices for16-bit indices and an explicit vertex shader for main-view/light-space projection. Cache ordered mesh regions and their transforms/source identities. Reuse indices and unchanged world vertices; rebuild changed regions. Do not lower LOD, cull by a new distance, alter simulation or remove opaque caster geometry to claim a gain. Inspect fallback/error/resource behavior before acceptance.

Separate receiver coverage from caster eligibility; retaining current caster material exclusions does not establish receiver parity. Stencil remains default and capability fallback. This is a prototype architecture decision, not a finished visual or performance result.

## Consequences

[UNKNOWN] Cache invalidation for mutable rigid geometry, animated models, attachments, map/reset lifecycle and camera changes needs runtime validation. Skin/cutout and non-caster receiver coverage remains unresolved. CPU batching might still lose to stencil after full coverage is restored. T-035 remains In Progress.

- **Outcome (2026-11-17):** Rejected on measured cost; see [EXP-029](../experiments/EXP-029-shadow-map-rejected.md) and [ADR-0015](ADR-0015-reject-shadow-map-renderer.md). The renderer was not retained.
