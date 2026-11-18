# ISSUE-0058: Batched receiver inherits caster exclusions

- **Status:** Investigating
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] native-batch-mask/scene.png shows colored vehicle parts among the white/black receiver mask. Scene metadata records 9,329 meshes / 248,043 triangles in seven batches and only one depth material install, replacing the previous 10,371 installs. The batch collector applies existing alpha/translucent/skin caster exclusions, then reuses that geometry as receivers. Therefore a surface can retain its original color because it was excluded from caster geometry; this is not proof of a depth-comparison error.

## Impact

Receiver coverage is incomplete. T-035 remains In Progress; the batched path is experimental and stencil remains default. Do not claim visual parity or compare partial coverage as an accepted speedup.

## Resolution / verification

Pending separate receiver geometry/material policy and coverage checks. Preserve original caster exclusions while deciding how lit alpha/cutout and skin materials receive shadows.

[INFERRED] Some colored opaque faces may also fail the repeated geometry depth test because CPU world transforms and original FFP transforms round differently. This is distinct from material exclusion. [SOURCED] Microsoft describes Z-bias for coplanar overlays: [Using Z-Bias](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/bb324464(v=vs.85)). Pinned [d3d8to9 v1.16.0 source](https://raw.githubusercontent.com/crosire/d3d8to9/v1.16.0/source/d3d8to9_device.cpp) maps D3D8 ZBIAS to depth bias. An independently parameterized receiver raster bias is being tested; it does not alter the light-depth comparison bias.

[VERIFIED] native-region-mask uses receiver raster bias1 and shows most previously colored opaque vehicle faces covered by the black/white pass. This distinguishes a depth-rounding problem from material exclusion; the initial colored-face screenshot alone did not identify which cause applied to each face. Skin/cutout/non-caster coverage remains unverified; no complete receiver parity claim. Camera zoom updates the mask without an obvious stale projection.

[VERIFIED] EXP028validates the fullscreen sampled-depth comparison core on calibrated geometry; it can receive shadows on a plane absent from caster batches. ADR0014chooses this architecture to cover the actual scene. Live frame-depth capture is not yet integrated, so this issue remains Investigating.
