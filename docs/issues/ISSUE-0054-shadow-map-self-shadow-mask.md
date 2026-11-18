# ISSUE-0054: Diagnostic mask blacks out the visible tank surfaces

- **Status:** Investigating
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** R32F/PS1.4 shadow-map diagnostic

## Symptom / evidence

[VERIFIED] artifacts/2026-11-17-shadow-depth/mask-v1/scene.png shows large black tank silhouettes in the white/black receiver mask. Lit roof surfaces are not clearly distinguishable; normal-colored output alone was insufficient evidence of correct depth comparison.

## Root cause

[UNKNOWN] Self-shadow precision/bias, incorrect depth coordinates, or receiver state. Depth preview is not yet available (ISSUE-0048).

## Impact

Visual correctness gate is not met. No performance acceptance or default enablement.

## Workaround

Use stencil; validate depth values and receiver coordinates before choosing bias or changing quality.

## Resolution / verification

Pending depth preview and a physically interpretable lit/shadow mask.

## Depth evidence

[VERIFIED] readback-bitmap/light-depth.bmp shows only a few static structures, no 1,000-tank grid, despite frame logs counting1,023 caster objects. The mask is not backed by complete caster depth. [VERIFIED] Mesh::Render defers nonzero static sort levels before preserving additional material passes; Pass also disabled additional passes on translucent meshes, and SHADOW_RENDERING permits alpha base passes to bypass the depth shader. Investigate with static-sort deferral disabled inside the controlled pass, explicit mesh-renderer camera binding, and depth-only additional passes on vehicle materials.

## Native diagnostic follow-up

[VERIFIED] native-delta metadata confirms a 1920x1080 framebuffer; native-bias004 mask removes the broad bands but retains black vehicle-shaped regions. native-color004 retains normal colors. Each 45-second probe exits successfully, restores Options.ini SHA256 F756DE96...86B5C and removes the temporary wrapper. See artifacts/2026-11-17-shadow-depth. The visible depth BMP contains the tank grid; hidden-camera evidence did not establish missing casters. No isolated sort-routing fix is proven.

[UNKNOWN] The remaining mask could include valid ground shadows and self-shadow error; compare the same native stencil view and inspect registration before choosing a correction. Bias alone is not accepted as a fix.

[VERIFIED] EXP028proves isolated box/plane depth comparison and a sampled-depth fullscreen core against independent analytic rays. Earlier delta amplification64was invalid under PS1.x constant limits (ISSUE0064), so its gray values cannot quantify a tiny error. Angled geometry exposes genuine grazing-face acne, reduced by hardware-biased INTZ depth (ISSUE0065); crowded-grid black regions alone still do not distinguish neighbor occlusion from self-shadow. Real-scene validation remains pending.
