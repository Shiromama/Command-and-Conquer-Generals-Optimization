# ISSUE-0050: First shadow-map prototype is slower than stencil

- **Status:** Investigating
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** wrapper, AA0/High, centered 1,000-unit scene, visible window

## Symptom / evidence

[VERIFIED] After the user closed heavy apps, wrapper-visible-clean records median 35.1961 ms / p95 45.7071; stencil-visible-clean records median 14.46975 / p95 19.6047, after excluding 300 render frames. Different durations and a camera-scale action in the map run make this diagnostic rather than a controlled final A/B, but the prototype clearly has not met its gain criterion.

## Impact

Prototype stays opt-in and T-035 remains incomplete.

## Root cause

[VERIFIED] Pass::Install_Materials repeats raw texture-stage, render-state and constant setup per mesh; UnInstall resets it per mesh. [UNKNOWN] How much of the regression this explains versus extra geometry/passes and GPU fill.

## Workaround

Use stencil. Cache repeated state and keep custom state within explicit flush scopes, then repeat identical fixed-camera comparisons.

## Resolution / verification

Pending state-setup optimization, image check and paired measurement.

## Batched phase follow-up

[VERIFIED] Seven rigid geometry batches replace about10,000per-mesh material installs. CPU-side explicit projection median submission21.59ms drops to13.03ms with vertex shader1.1 and cached world vertices; ordered region reuse further reduces collection. Native phase records and medians are retained in artifacts/2026-11-17-shadow-depth/batch-phase-comparison.json. These compare evolving diagnostic implementations and incomplete coverage, not an accepted matched stencil A/B. Keep Investigating until full coverage and final paired timing pass.
