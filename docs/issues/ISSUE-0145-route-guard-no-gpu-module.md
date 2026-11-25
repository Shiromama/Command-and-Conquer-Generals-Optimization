# ISSUE-0145: Route-guard diagnostic ran without a D3D module

- **Status:** Open
- **Severity:** Medium
- **Date found:** 2026-11-20
- **Task:** T-112

## Summary

[VERIFIED] The route-guard diagnostic
(`artifacts/2026-11-20-last-stand-route-guard/nvidia/generalszh.exe`,
SHA-256 `C337ADD0...C094C2`) ran the full replay to frame 17,402 with
`sync=ok`, wrote 9,106 window searches and 2,185 commands, and rendered
frames at the end (`draw` is non-zero in `on-guard-attr.csv`). No
`d3d8.dll`, `d3d9.dll`, `nvd3dum.dll` or `igdumdim32.dll` module was
observed during the run, and `on-guard-modules.csv` was not written.

[VERIFIED] The earlier early-full run used the same harness and recorded
`D3D8.DLL` from the staged wrapper, `d3d9.dll`, `nvd3dum.dll`,
`igdumdim32.dll` and `nvgpucomp32.dll`.

## Impact

The route-guard logic data is valid: search and command parity match the
early-full reference. The GPU path is not established for this build, so
any frame-time comparison from this run is invalid until the driver
selection is explained.

## Candidate causes

- [UNKNOWN] With `ZH_PROFILE_WARMUP_UNTIL=16800`, drawing is skipped until
  frame 16,800. The display device may be created lazily at the first
  draw, after the runner's module polling has already ended.
- [UNKNOWN] The runner polls `Get-Process -Id $p.Id).Modules` while the
  32-bit game runs. The earlier harness observed the modules with the same
  call, so the call itself is not new.
- [UNKNOWN] The window may not be created on the active desktop, or the
  device may fall back to a renderer that does not load the expected
  modules.

## Next

Run a short graphical launch with drawing enabled from frame 0
(`ZH_PROFILE_WARMUP_UNTIL=0`, stop around frame 300) and record modules
and the window handle. Compare the exe, wrapper path and working directory
with the early-full run. Only then trust rendered FPS from this diagnostic.

## Resolution / verification

[UNKNOWN] Not resolved. Verification will be the short no-warmup graphical
launch above, with the module list and window handle recorded and compared
with the early-full run.

