# ISSUE-0061: Fullscreen mask readback assumes a bound depth surface

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] calibration-screen-perspective geometry mask passes with0stable mismatches and sampled INTZ depth agrees within1/255readback quantization. Screen shaders/INTZ creation/sample all return0, but screen_mask export returnsE_FAIL. The screen comparison therefore cannot be claimed. SavedState currently requires GetDepthStencilSurface success even when the sampling pass intentionally binds no depth surface.

## Resolution / verification

Pending accepting the legitimate D3DERR_NOTFOUND/no-depth state and rerunning the same fullscreen comparison. Preserve original failed calibration folder.

[VERIFIED] Rerun calibration-screen-perspective-state logs GetDepthStencilSurface=88760866(D3DERR_NOTFOUND) for the intentionally color-only target. Updated SavedState accepts that state; screen-mask export now returns0. The exported fullscreen mask is still all lit, a separate shader/reconstruction issue recorded as ISSUE0062; this issue resolves export only.
