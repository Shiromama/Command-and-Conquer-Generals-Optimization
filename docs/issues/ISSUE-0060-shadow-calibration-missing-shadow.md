# ISSUE-0060: Isolated box calibration produces no ground shadow

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] calibration-light1 uses the production depth/compare shaders and a40x40x40box on a200x200plane. Main viewport1920x1080. Both BMP exports return0, but the mask is entirely white:0actual shadow pixels vs41,820analytic expected pixels;31,862stable interior mismatches (3.27%). `python tools/check-shadow-calibration.py artifacts/2026-11-17-shadow-depth/calibration-light1/light-depth.bmp` exits nonzero. Original evidence retained.

## Impact

Physical correctness remains unproven. The fixture may expose a shader/state bug or a calibration setup error; do not infer accepted shadowing from earlier grid screenshots. T035stays In Progress.

## Resolution / verification

Pending depth/constant/transform inspection and corrected calibration against independent analytic geometry.

[VERIFIED] Root cause is the fixture's nested readback restoration: Set_Render_State marks VIEW_CHANGED pending; the subsequent pass applies the old engine camera over a raw calibration view. Flush pending wrapper state before setting the fixture camera. calibration-light1-view then passes with0mismatches across974,736stable pixels,42,025shadow pixels vs41,820analytic before boundary exclusion, and0incorrectly shadowed roof-core pixels out of23,716. Both exports return0; GPU projection and bias constants recorded. Same production shaders are used. Original failed evidence remains.
