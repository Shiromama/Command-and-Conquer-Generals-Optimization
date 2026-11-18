# ISSUE-0048: D3DX8 cannot export the prototype R32F depth target

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** d3d8to9, R32F shadow target

## Symptom / evidence

[VERIFIED] wrapper-probe/shadow-map.csv and wrapper-visual/shadow-map.csv report depth_dump HRESULT 80004005 (E_FAIL) while resource/shader initialization and frame submission continue.

## Impact

DDS evidence is unavailable; target contents are unverified. This does not prove a sampling/render failure.

## Root cause

[UNKNOWN] The D3D8 D3DX surface exporter may not recognize the newer numerical R32F format. Actual readback remains to be checked.

## Workaround

Inspect rendered output and implement a known-format diagnostic visualization or explicit float readback without using D3DX8 format conversion.

## Resolution / verification

Pending successful diagnostic depth capture.

## Known-format preview attempt

[VERIFIED] The follow-up adds an A8R8G8B8 shader-sampled preview and delays export to render frame30. mask-v1/shadow-map.csv reports depth_png 8876086c; preview still unavailable. Add per-stage HRESULT logging and explicit system-memory readback to locate the failing API. The shadow-mask scene itself is captured as mask-v1/scene.png.

[VERIFIED] readback-v2 creates the standard preview, draws the sampling quad and copies it to a system-memory A8R8G8B8 image successfully. D3DXSaveSurfaceToFileA then returns 88760b59. Replacing only the final exporter with a raw top-down 32-bit BMP writer; surface creation/draw/readback are already verified by per-stage HRESULTs.

[VERIFIED] Raw BMP export succeeds after the verified preview draw and system-memory CopyRects. readback-bitmap/light-depth.bmp is 4,194,358 bytes, a valid 1024x1024 top-down 32-bit image, inspected with view_image; sidecar reports minimum4/maximum255/nonwhite4014. This closes exporter/readback availability only. The image exposes missing tank casters, tracked under ISSUE-0054.
