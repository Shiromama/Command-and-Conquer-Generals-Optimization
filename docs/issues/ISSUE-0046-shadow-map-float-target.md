# ISSUE-0046: System D3D8 rejects the prototype floating-point shadow target

- **Status:** Workaround
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** current engine, system D3D8, AA0/High

## Symptom / evidence

[VERIFIED] system-probe-permitted/shadow-map.csv records r32f_target_unavailable, HRESULT 8876086c (D3DERR_INVALIDCALL). The game remains running through the 20-second probe and returns to stencil rendering. Options restore hashes match.

## Impact

The first target representation is unavailable through this backend; no shadow map was rendered and no visual/performance acceptance is claimed.

## Root cause

[VERIFIED] CreateTexture with numerical D3DFMT_R32F (114) fails through the system D3D8 API. [UNKNOWN] Whether the pinned D3D8-to-9 wrapper accepts it.

## Workaround

Keep stencil fallback; test the existing pinned wrapper. If that also fails, design and validate a native D3D8 color-depth encoding or explicit renderer/backend bridge.

## Resolution / verification

Pending wrapper capability test or an alternative representation.

[VERIFIED] Pinned d3d8to9 probe creates the R32F target and both pixel shaders and submits caster/receiver passes. System D3D8 continues using stencil. This is a backend workaround, not native-D3D8 shadow-map support.

[VERIFIED] INTZ hardware light-depth alternative is also rejected by native system D3D8(8876086c), while pinned wrapper creation/sample and hardware slope states succeed in EXP028. Native fallback run records1,320normal frames; W3DShadow.cpp routes false from renderShadowMap to existing renderShadows. No native INTZ support claim.
