# ISSUE-0038: Sandboxed MSBuild workers do not start compilation

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-079
- **Environment:** VS 2022 MSBuild, sandboxed exec

## Symptom

[VERIFIED] The incremental CMake build produced only the MSBuild version header for several minutes. Unsandboxed process inspection showed the root and repeated low-CPU workers, no cl/link compilation. Sandboxed process inspection could not see them.

## Reproduction / evidence

`cmake --build build/engine-vs-community --config Release --target z_generals -- /m:4 /nodeReuse:false`; initial output retained in `artifacts/2026-11-17-t079-remediation/build.log`.

## Impact

The build must be stopped and retried in a context where workers can communicate. Source and launcher regression work continues.

## Root cause

[INFERRED] Worker startup/IPC restrictions in the sandbox. The exact MSBuild diagnostic cause is not yet established.

## Workaround

Verify the owned CMake root identity, stop only its process tree, and retry the same incremental build outside the sandbox with one MSBuild node.

## Resolution / verification

Pending build exit and compiler output.

## History

- 2026-11-17 — Recorded worker startup stall after inspecting processes and log before retry.

## T-079 resolution (2026-11-17)

[VERIFIED] Stopped only the identity-verified stalled CMake tree and rebuilt outside the sandbox with one MSBuild node.

[VERIFIED] `cmake --build build/engine-vs-community --config Release --target z_generals -- /m:1 /nodeReuse:false` exits 0; build-retry.log records compilation and linking. The prior stall remains documented; its precise platform IPC cause is inferred. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
