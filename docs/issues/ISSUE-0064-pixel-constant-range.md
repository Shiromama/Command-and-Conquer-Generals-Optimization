# ISSUE-0064: PS1.x reconstruction constants exceed supported range

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] Fullscreen raster debug1 is entirely black (quad draws); debug3 shadow texture reads are entirely white. CPU reconstruction for the perspective fixture has coefficient-1.04645. [SOURCED] Pixel shader1.x constant registers range from-1to+1: [Microsoft register reference](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx9-graphics-reference-asm-ps-registers-ps-1-x). Out-of-range coefficients can change projected UVs; debug constants128 and earlier delta gain64 are also invalid, so their assumed numerical amplification was unverified.

## Resolution / verification

Uniformly normalize the homogeneous reconstruction matrix into the valid constant range; projection/division and comparison signs are unchanged. Replace debug/delta large constants with supported instruction scaling. Pending calibrated fullscreen mask verification. Original failed/debug evidence retained.

[VERIFIED] calibration-screen-range records homogeneous normalization0.477794707, all uploaded pixel constants within[-1,+1], and0analytic fullscreen-mask mismatches. Corrected large debug/delta gains use instruction result scaling. Earlier delta images were not numerically64x-amplified; do not use that assumed gain to interpret their differences.
