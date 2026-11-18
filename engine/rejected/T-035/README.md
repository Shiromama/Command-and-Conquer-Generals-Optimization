# Rejected T-035 renderer source

This is a source archive, excluded from the active engine build. Stencil remains the active renderer.

[VERIFIED] ShadowMapPrototype.inc and renderer-hooks.patch are exact copies of the retained local archive. source.json pins their SHA256, the upstream vendor base, and the root checkpoint supplying base-engine.patch. The base patch predates the later default-heap change. Keeping these files tracked preserves the calibrated source on a fresh clone.

## Reconstruction

Use an isolated checkout of the vendor commit in source.json, with the normal project build dependencies available. Do not apply to a game installation or the active vendor checkout.

1. Apply base-engine.patch, excluding the three hook_paths listed in source.json.
2. Apply renderer-hooks.patch. It is relative to the pinned upstream files, not the already modified versions of those three files.
3. Copy ShadowMapPrototype.inc into prototype_path from source.json.

`python tools/verify-rejected-shadow-source.py --output artifacts/<fresh-directory>` performs these operations on only the affected source files in an isolated scratch tree, validates hashes and patch applicability, and records the resulting file hashes. It never changes the active vendor tree. For a full build, perform the same steps on the full pinned upstream checkout and follow engine/README.md.

[UNKNOWN] This reconstructs the archived source with explicit provenance; it does not claim a new historical build attestation or bit-identical executable. Generated binaries, game data and performance traces remain outside Git. Test methods: tools/test-shadow-batches.py now uses this source by default; tools/check-shadow-calibration.py reads retained GPU fixture artifacts. Neither enables the renderer in the shipped engine.
