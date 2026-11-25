# ISSUE-0109: Last Stand profiler build stalled in parallel MSBuild

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-025
- **Related:** [ISSUE-0080](ISSUE-0080-alpha-build-process-stall.md)

## Evidence

[VERIFIED] The isolated diagnostic source configured successfully. The sandboxed `cmake --build ... --parallel 6` log stayed at `Checking Build System` for over three minutes. An external, read-only process inventory showed the target MSBuild parent and worker nodes, with no compiler or linker running.

## Resolution / verification

[VERIFIED] Stopped that build tree by the verified CMake command line and reran the existing `z_generals.vcxproj` with Visual Studio Community MSBuild, `/p:Configuration=Release /p:Platform=Win32 /m:1 /nodeReuse:false`. Build completed in 3:20.88 with zero errors. Output SHA-256 `05394227CF557516E86C061BB1D5A267F56B7677A2D4E5DDE466216117A47C67`. Build logs and the diagnostic source diff are in `artifacts/2026-11-19-last-stand-replay/`.
