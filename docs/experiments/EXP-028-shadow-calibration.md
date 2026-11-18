# EXP-028: Analytic shadow calibration and sampled-depth receiver core

- **Date:** 2026-11-17
- **Author/agent:** Codex
- **Task:** T-035
- **Status:** Complete
- **Decision:** [ADR-0014](../decisions/ADR-0014-sampled-depth-shadow-receivers.md)

## Hypothesis

[UNKNOWN] Production depth/compare shaders can match analytic visibility for a known box/plane, including perspective reconstruction from a sampled main-depth texture. This isolates correctness from the crowded1,000-unit scene; it does not establish final scene coverage or performance.

## Method

[VERIFIED] Explicit calibration flag builds a40x40x40box on a200x200plane. Light directions include45degree, diagonal, overhead and the map's actual normalized(0.956088,-0.049796,0.288818). Cameras include top-down orthographic/perspective and angled perspective at(120,-160,300). It uses the production write/compare shaders and GPU world/light projection. A separate experimental fullscreen receiver reads an INTZ depth texture, reconstructs homogeneous light coordinates and compares with the light-depth map. Sky depth1 remains lit. The regular game renderer has not yet connected this fullscreen receiver to live scene depth.

[VERIFIED] Main game viewport1920x1080 is recorded independently from the1024x1024offscreen shadow calibration target. Every20-second launch was announced. Temporary AA0/High options/wrapper are restored after each probe. Only engine-test is staged. The checker independently casts camera rays against box/plane, then casts surface-to-light rays against the box. It does not use the GPU's reconstruction matrix to compute expected visibility. A2.5-world-unit boundary band and outer border are excluded; acceptance remains less than0.1%stable mismatches plus zero roof-core false shadows. Sampled depth is additionally checked within1/255grayscale readback quantization. Earlier all-white masks and grazing acne fail this same test.

Reproduce using `powershell -NoProfile -ExecutionPolicy Bypass -File tools/benchmark-shadow-map.ps1 -ArtifactDir artifacts/<fresh-run> -Calibration -CalibrationCamera Angled -CalibrationLight 4 -DepthFormat INTZ -Units 1 -Wrapper -DurationSeconds 20` after announcing the launch. Run `python tools/check-shadow-calibration.py artifacts/<fresh-run>/light-depth.bmp --screen`; omit --screen for geometry receiver comparison.

## Measurements and corrections

| Case | Stable pixels | Mismatches | Roof false shadows | Result |
|---|---:|---:|---:|---|
| R32F, orthographic45degree, geometry | 974,736 | 0 | 0/23,716 | Pass |
| R32F, diagonal light, geometry | 965,038 | 0 | 0/23,716 | Pass |
| R32F, map light, geometry | 965,203 | 0 | 0/23,716 | Pass |
| R32F, perspective diagonal, normalized fullscreen | 1,005,664 | 0 | 0/10,404 | Pass |
| R32F, angled camera/map light, fullscreen | 1,012,711 | 1,517 | 0/5,225 | Fail: grazing face acne |
| INTZ light depth, slope1, angled fullscreen | 1,012,711 | 37 (0.00365%) | 0/5,225 | Pass at unchanged tolerance |
| INTZ light depth, slope1.5, angled fullscreen | 1,012,711 | 34 (0.00336%) | 0/5,225 | Little further improvement |

[VERIFIED] Original failed fixture produced no shadow because nested readback restored a pending cached engine view over the fixture camera (ISSUE-0060); flushing pending wrapper state fixes it. Color-only readback originally failed without a depth surface; SavedState now accepts D3DERR_NOTFOUND for that legitimate state (ISSUE-0061).

[VERIFIED] Fullscreen all-lit failure (ISSUE-0062) came from a reconstruction coefficient-1.04645 outside PS1.x constant range. Uniform homogeneous normalization0.477794707 fixes perspective projection while preserving division/comparison. All uploaded pixel constants are now within[-1,+1] (ISSUE-0064). Earlier delta gain64/debug gain128 constants were also invalid; those earlier images cannot support their assumed numeric amplification. Corrected diagnostics use instruction result scaling. GPU translated bytecode/disassembly and intermediate masks are retained; the disassembly-only build error is ISSUE-0063.

[VERIFIED] R32F comparison alone retains grazing stripes on the angled cube face. Optional INTZ light depth enables actual hardware triangle-slope bias; constant bias is not raised to hide this. It reduces stable mismatches to37without erasing the calibrated ground shadow. Residual pixels and real-scene quality remain relevant; ISSUE-0065 stays Investigating until broader validation. SavedState preserves both the legacy bias tracker and translated slope/depth states across readbacks. Separate receiver depth prevents overwriting the sampled light depth; readback unbinds it before sampling.

[VERIFIED] INTZ main-depth creation, binding and sampling succeed through pinned d3d8to9. Sampled depth maximum error0.00187213is below1/255A8readback quantization; this is not a raw depth precision claim. Native system D3D8 rejects the INTZ shadow target with8876086c, while1,320normal frame records continue. W3DShadow.cpp selects the existing volume renderer whenever renderShadowMap returns false; this is the source-supported fallback path, not native INTZ support.

## Result and limits

[VERIFIED] The isolated write/compare pipeline and homogeneous fullscreen receiver core have physically interpretable evidence. Final experimental engine5A9DAE8CE9FC2A4D1B5F5C0CD67D317501BC32872B3DC39DC72CE6364FF4E0B5 builds successfully. Stencil stays default. No accepted whole-game gain, real-scene fullscreen coverage, device reset or map-transition claim.

[UNKNOWN] Next: bind a sampleable main depth surface for the actual scene at the correct clear/render lifecycle, restore it safely, connect the fullscreen receiver and verify all opaque materials, alpha/decal/water interaction, offscreen casters, camera/map/reset behavior and full-coverage native stencil A/B. Hardware slope/texel bias and resolution need tuning at real scene extents. T-035 remains In Progress.

## Artifacts and sources

`artifacts/2026-11-17-shadow-depth/manifest.md` and inventory.json identify every build/probe, original failure, GPU BMP, independent reference image, comparison JSON and shader disassembly. [check-shadow-calibration.py](../../tools/check-shadow-calibration.py) is the analytic checker.

[SOURCED] [Microsoft PS1.x registers](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx9-graphics-reference-asm-ps-registers-ps-1-x) defines constant limits; [texcrd](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/texcrd---ps) and [texld1.4](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/texld---ps-1-4) define phase/projective rules. The implementation preserves required homogeneous values in RGB across phases. [D3D9 render states](https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3drenderstatetype) documents slope/depth bias. [Pinned wrapper source](https://raw.githubusercontent.com/crosire/d3d8to9/v1.16.0/source/d3d8to9_device.cpp) forwards the probed numerical D3D9 states175/195; these are capability-tested, not assumed native D3D8 support.
