# EXP-026: Opt-in global light-depth shadow-map prototype

- **Date:** 2026-11-17
- **Author/agent:** Codex
- **Task:** T-035
- **Status:** Running
- **Decision:** [ADR-0011](../decisions/ADR-0011-measure-pathfinding-and-gate-shadow-map.md)

## Hypothesis and baseline

[UNKNOWN] A global light-space depth pass plus depth comparison can replace the stencil-volume cost with acceptable image quality and a reproducible performance improvement. Baseline is the current stencil renderer; earlier cost evidence is EXP-004 and rejected rebuild-throttle EXP-020.

## Prototype method

[VERIFIED] Source prototype compiles and links (build-3.log). It is disabled unless ZH_SHADOWMAP=yes. It probes a numerical R32F format through the D3D8 device, a D16 depth surface and pixel shader 1.4. On capability failure it returns to the existing stencil path. Resources are tied into manager ReleaseResources. Orthographic light-depth pass draws registered shadow-caster objects; receiver passes apply a depth comparison to terrain tiles and visible registered shadow meshes. Target size defaults to 1024, with ZH_SHADOWMAP_SIZE accepting powers of two from 256 to 4096. ZH_SHADOWMAP_LOG records resource failures and CPU submission time; optional ZH_SHADOWMAP_DUMP requests one DDS depth-target dump.

## Unverified acceptance gates

[UNKNOWN] Runtime resource creation, depth-target contents, shader behavior, state restoration, reset/map changes and camera movement are not yet tested. Alpha-cutout geometry, non-caster receivers, terrain diagonals, water/player-color stencil interactions, offscreen casters, PCF/filtering and large-map coverage need explicit inspection. Single-tap comparison and constant bias are prototype choices, not final visual acceptance. Receiver draw failures require further fallback validation. No performance claim or default-enable decision.

## Artifacts and follow-up

`artifacts/2026-11-17-shadow-map/manifest.md`: compile diagnostics and successful link. Run capability/visual tests after the T-022 benchmark batch; do not run two games against one GPU during measurements.

## First runtime probes

[VERIFIED] Engine ABAD3E88E9BDA86D203DD95BA01FD888866C0F898FF0607BF09BB09190DF9389 built and staged only in engine-test. System D3D8 rejects R32F with HRESULT 8876086c and falls back. Pinned d3d8to9 accepts the float target and both PS1.4 shaders; frame records show 1,023 casters and nine terrain tiles. The DDS target dump fails with E_FAIL (ISSUE-0046 follow-up); no target-content acceptance. Twenty-second capability runs restore Options.ini byte-for-byte (F756DE96...86B5C) and remove the temporary wrapper. The 60-second wrapper-visual run used a hidden window, so no visual inspection occurred (ISSUE-0047).

[UNKNOWN] CPU submission times are exploratory under user background load; no speedup is claimed. User requires a heads-up before each future game launch. Full image validation remains open.

## Visible review and submission prototype

[VERIFIED] After the user closed heavy apps, explicit foreground activation allowed capture of wrapper-visible-clean/scene.png and scene-camera-change.png and stencil-visible-clean/scene.png. Basic terrain/tanks/UI render, but a complete shadow mask/coverage comparison is not yet established. Initial map median 35.20 ms vs stencil 14.47 ms is a regression (ISSUE-0050); duration and camera-action differences prevent treating it as a final paired comparison.

[VERIFIED] V2 cached repeated state setup and scoped material cleanup, but produced a black world (map-v2-clean/scene.png). ISSUE-0051 traced the cached pixel constants versus raw state-block restoration; V3 uploads custom constants once per pass directly. Build-8 succeeds and map-v3-verify/scene.png restores colors. V3 diagnostic median 27.54 ms / p95 34.05 over 1380 render frames after 300 warmup frames. It has not met the performance criterion.

[VERIFIED] Current experimental engine: `68D68B11146D74353231959D00967766B8EF7DA56EB137AAB1EE492CD089B01D`, staged only into engine-test; shockwave-engine remains on the earlier T-079 build. Stencil stays the default and the wrapper/profile are restored after every permitted probe. Final source patch reverse-check and clean-index apply-check pass. Native D3D8 float support (ISSUE-0046 Workaround), depth export (ISSUE-0048) and submission regression (ISSUE-0050) remain open work. Next: known-format depth/mask visualization, receiver/caster coverage verification, then reduce/batch additional geometry passes and repeat fixed-camera alternating runs.

## Depth readback and native diagnostic follow-up

[VERIFIED] ISSUE-0048 is resolved by sampling R32F into A8R8G8B8 and exporting a raw BMP with a system-memory readback. D3DX8 PNG/DDS failures remain historical evidence. The visible scene's depth image contains the tank grid. Earlier hidden-window captures used a different camera/visible box; they do not demonstrate absent tank casters or isolate an improvement from sort routing. See artifacts/2026-11-17-shadow-depth/manifest.md.

[VERIFIED] All new tests use the user's native 1920x1080; the scene diagnostic records main_viewport=1920,1080. Engine 913AAEF061B72490996BDB42CD14DFD8B5CDC95FB084B272406CC3F1644935E4 adds depth-difference and bias diagnostics. Native delta, bias 0.004 mask and normal-color views are captured. The larger bias clears broad terrain bands but leaves vehicle-shaped black regions in the mask. Their relationship to surfaces versus ground shadows requires the native stencil reference; a screenshot alone is not acceptance. ISSUE-0054 remains Investigating. No native renderer speedup claimed.

[UNKNOWN] Correct caster/receiver coverage, useful slope/texel bias, alpha/skinning/water interactions, offscreen coverage, reset behavior and performance still gate T-035. Stencil remains default. A large constant bias can erase real ground shadows; do not promote the diagnostic 0.004 value as a finished setting.

## Bounded batches, explicit GPU projection and cache verification

[VERIFIED] Native batched prototype replaces10,371depth material installs with one install/seven geometry draws for9,329rigid meshes/248,043triangles. It retains selected model LOD and current caster material exclusions; it does not claim complete receiver coverage (ISSUE-0058). CPU explicit-coordinate submission initially spends21.59ms total shadow submission,13.49ms gathering,2.75ms depth,0.52ms terrain,4.62ms mesh receiving (medians after300records, native-batch-profile). These are phase diagnostics, not a paired accepted gain.

[VERIFIED] Vertex shader1.1 projects cached world vertices into main/light space, reducing vertex stride36to12bytes. Native-cached-batch median submission13.03ms:9.39gather,1.24depth,0.50terrain,0.92mesh receiving. Ordered mesh-region reuse subsequently avoids index rebuilding and unchanged vertex copies. native-region-mask records seven batches,8,384unchanged mesh-region hits at its initial dump, native1920x1080 viewport and a successful camera zoom capture. Its phase summary is retained in batch-phase-comparison.json; the camera change and mask mode preclude final performance acceptance.

[VERIFIED] Small receiver-only raster Z-bias removes most previously colored opaque faces from the mask; it addresses repeated-geometry depth rounding separately from the light comparison bias. Material exclusions remain a coverage limit. No self-shadow/placement correctness claim follows from this result. ISSUE-0054/0058 remain Investigating.

[VERIFIED] Actual-source standalone collector/cache regressions pass17cases (`python tools/test-shadow-batches.py`): movement, region ordering/hiding, layout/source/model changes, in-place shared vertex/topology mutation, LOD/attachments, caster exclusions,60,000vertex batching, invalid indices/deep hierarchy rejection and resource-cache clearing. A byte-exact shared-model snapshot/revision check once per frame fixes stale in-place geometry reuse (ISSUE-0059). Runtime map/reset and material coverage remain separate gates.

[VERIFIED] Build-region-raster.log exits0. Current staged experimental engine376EDCF3585F245753E513987200497B3DB01B0A5F086E078BCDF61F16E71903 is only in engine-test. All four new native probes finish, restore original Options.ini hash and remove temporary wrapper. Stencil remains the normal/default renderer. ADR-0013 records the batching architecture. Next: a physically interpretable isolated caster/receiver calibration, then coverage/material/bias correction, map/reset tests and fixed-camera native timing with full coverage.

[VERIFIED] Native-region-mask diagnostic medians after300records: total8.206ms, collection3.220ms, depth2.472ms, terrain0.654ms, mesh receiving1.878ms. This includes a manual camera zoom and mask output; it is not final performance acceptance.

## Analytic calibration checkpoint

[VERIFIED] [EXP-028](EXP-028-shadow-calibration.md) isolates box/plane visibility, validates the production shaders and a sampled-main-depth fullscreen receiver core. Orthographic/map-light geometry cases and perspective diagonal fullscreen comparison have0stable mismatches. Angled grazing acne is reduced from1,517to37stable mismatches by INTZ light depth with hardware slope bias, below unchanged0.1%tolerance, with no false roof-core shadows. This does not finish real-scene coverage or quality. Source/documented failures ISSUE0060..0065retain originals and fixes.

[VERIFIED] PS1.x constant limits invalidate the earlier assumed delta64/debug128amplification. Corrected result modifiers stay in range, and homogeneous reconstruction normalization fixes out-of-bounds lookup. Terrain now shares explicit GPU light projection. INTZ formats/forwarded slope states are capability-probed; native system D3D8 rejects the target and the source selects stencil fallback. Original options restored after all announced1920x1080runs. Engine5A9DAE8C...FF4E0B5onlyengine-test staged.

[UNKNOWN] ADR0014chooses actual scene-depth capture/fullscreen opaque receiving next. The helper currently executes only in isolated calibration; no real-scene callback is registered yet. Preserve correct clear/depth/stencil lifecycle and restore on reset/resize; then validate materials/sky/decal/water/offscreen cases and fixed-camera native A/B. Do not promote calibration success to whole-renderer acceptance.

## Rejection (2026-11-17)

[VERIFIED] Measured against stencil, the opt-in shadow-map path is slower in both the retained dense scene (27.54 vs 14.47 ms median, 1,023 casters) and three controlled alternating pairs (mean 1.4477x), and it requires d3d8to9 because native D3D8 rejects the depth formats. The experimental renderer was removed from the engine; stencil volumes remain the only path. See [EXP-029](EXP-029-shadow-map-rejected.md) and [ADR-0015](../decisions/ADR-0015-reject-shadow-map-renderer.md). The calibration and depth-sampling evidence above remains valid as research; it is not a shipped feature.
