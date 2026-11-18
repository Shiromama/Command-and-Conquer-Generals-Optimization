# ISSUE-0062: Fullscreen comparison misses calibrated shadows

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] calibration-screen-perspective-state exports an all-white fullscreen mask despite correct geometry comparison and valid sampled INTZ depth. The fullscreen analytic comparison finds6,970stable interior mismatches (0.693%) and0actual shadow pixels vs11,850expected. Screen shader creation, depth sampling and readback return0. Exact evidence retained; cannot enable complete receiver path yet.

## Resolution / verification

Pending inspection of depth values, homogeneous reconstruction, phase/register behavior and texture projection. No default renderer change or performance acceptance.

[VERIFIED] calibration-screen-range fullscreen mask now matches the analytic reference with0mismatches over1,005,664stable pixels; roof core0/10,404incorrect shadow pixels. The homogeneous reconstruction normalization fixes the out-of-range coefficient (ISSUE0064). Full-scene depth capture/integration remains separate work.
