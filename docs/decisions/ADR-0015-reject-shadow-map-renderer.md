# ADR-0015: Reject the shadow-map renderer and keep stencil volumes

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** lead (T-035 acceptance)
- **Related:** T-035, ADR-0011, ADR-0013, ADR-0014, EXP-026, EXP-028, EXP-029, ISSUE-0058, ISSUE-0066

## Context

T-035 built an opt-in light-space depth renderer with capability fallback, bounded caster
batches and a validated depth/compare core. Its acceptance criterion was a verified improvement
over the existing stencil volume path.

[VERIFIED] In the retained dense scene (1,000 units, 1,023 casters) the shadow-map capture
measured 27.54 ms median versus 14.47 ms for stencil (1.90x). Three controlled alternating pairs
in a sparse scene measured 11.16/11.57/11.36 ms versus 7.90/7.84/7.81 ms (mean 1.4477x). Both
datasets say the path is slower. The renderer also requires d3d8to9: native system D3D8 rejects
the R32F and INTZ targets with `8876086c`, so without the wrapper the capability probe falls
back to stencil anyway. Receiver coverage was never complete (ISSUE-0058), and no real-scene
visual parity was accepted.

## Decision

Do not retain the shadow-map renderer. Remove its source from the engine, keep stencil volumes as
the only shadow path, and preserve the prototype and its measurements as artifacts
(`artifacts/2026-11-17-t035-rejected/`, EXP-026, EXP-028). Do not change any graphics default.

## Consequences

[VERIFIED] The cumulative engine patch no longer contains `ShadowMapPrototype.inc` or the
`renderShadowMap` hook; the rebuilt engine runs and renders normally (two 15 s probes completed
and produced frame logs). The stencil path keeps its existing T-030/T-064 tuning.

[UNKNOWN] A different architecture (live main-depth capture with a fullscreen receiver, ADR-0014)
was not built. It would have to erase several milliseconds of fixed submission cost before it
could beat stencil on this evidence, so it needs a new cost model rather than an incremental
step.

[VERIFIED] Measurement infrastructure stays: the passable/delay/pin stress options and the
`-Screenshot`/`-Map` benchmark switches are test-only, and ISSUE-0066 records that the stress grid
still fails to draw in this environment.

- **Clean dense confirmation (2026-11-17):** three alternating pairs with 1,000 tanks at 1920x1080 and the wrapper in both arms measure 1.1093x, 1.1669x and 1.1481x (mean 1.1415x) slower for the shadow map, replacing the earlier non-alternating captures as the acceptance evidence.

## Reproducibility follow-up (2026-11-18)

[VERIFIED] The local archive is additionally preserved as tracked source under engine/rejected/T-035with explicit bases/hashes and isolated reconstruction verification. Dense/rejected evidence manifests are reconstructed with provenance limits identified. The active engine remains stencil-only; this does not change the rejection decision or certify the unbuilt fullscreen design.
