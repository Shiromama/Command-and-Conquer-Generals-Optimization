# ISSUE-0065: Grazing cube face has shadow-map acne

- **Status:** Investigating
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] calibration-screen-angled uses camera(120,-160,300) and map light(0.956,-0.050,0.289). Both geometry and fullscreen masks show striped false shadows on a grazing cube face:1,549and1,517stable mismatches respectively. Roof core remains correctly lit; INTZ sampled main depth agrees within readback quantization. Similar results on both receiver paths isolate a shared light-depth/bias limit, rather than accepting the framebuffer comparison as done.

## Resolution / verification

Pending a depth-format/bias method that handles per-polygon slope without erasing real contact/ground shadows. Do not loosen analytic acceptance or use a large global bias to claim success.

[VERIFIED] Optional INTZ light depth plus hardware slope1passes the same angled calibration:37/1,012,711stable mismatches (0.00365%), zero false roof-core shadows; slope1.5gives34. Both are below unchanged0.1%tolerance, with actual ground shadow retained. Most grazing stripes disappear. Keep Investigating for residual pixels, real scene extents/texel bias and visual coverage before accepting the renderer. See EXP028.
