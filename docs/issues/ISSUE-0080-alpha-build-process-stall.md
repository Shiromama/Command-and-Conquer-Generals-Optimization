# ISSUE-0080: Sandboxed alpha build parent stalls after child disappears

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] The alpha build log stops at PreRTS.cpp at 00:51:31 local time. Read-only unsandboxed Win32_Process inspection at 00:54 shows only build helper powershell PID 160840 with its exact tools/build-alpha-engine.ps1 command, and no cmake/MSBuild/cl/link children. Sandboxed process inspection itself lacks CIM access. The parent remains waiting without a successful build result.

## Resolution / verification

Stop only the verified stale helper parent and resume the isolated build directly outside the filesystem sandbox with one MSBuild worker. Active development build/source and games stay untouched. Verification pending.

### Verified resolution

[VERIFIED] Stopped only the verified stale build helper; direct unsandboxed single-worker build completes with exit 0 after the separate source declaration error was fixed. Receipt: build/alpha-engine-release/build-final.log.
