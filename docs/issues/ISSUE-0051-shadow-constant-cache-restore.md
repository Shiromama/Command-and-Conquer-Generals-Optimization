# ISSUE-0051: Cached shadow constants conflict with device state restoration

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** state-cached prototype v2, d3d8to9

## Symptom / evidence

[VERIFIED] map-v2-clean/scene.png shows most terrain and tanks black while flame sprites, trees and UI remain visible. This build is not visually acceptable and its timing is excluded.

## Root cause

[INFERRED] V2 switched pixel constants to DX8Wrapper's cache, but SavedState restores device constants via ApplyStateBlock without restoring that cache. Later installs can skip uploads because the cache says constants are unchanged although GPU constants were restored. The lit/shadow colors then become zero. Verify by explicitly uploading constants once per pass after state capture.

## Impact

T-035 remains In Progress. No renderer performance acceptance.

## Workaround

Stencil remains the default. Upload custom constants directly once per controlled pass; let the device state block restore original constants afterward.

## Resolution / verification

Pending corrected build and visible rerun. Existing engine-test remains an experimental copy; no other game copy was staged.

[VERIFIED] Build-8 succeeds; map-v3-verify/scene.png restores normal terrain/tank colors. Direct constant upload once per scoped pass corrects the cache/state-block conflict. The 30-second run completes and restores original options bytes and wrapper slot. This fixes the black-world regression only, not the independent performance failure ISSUE-0050.
