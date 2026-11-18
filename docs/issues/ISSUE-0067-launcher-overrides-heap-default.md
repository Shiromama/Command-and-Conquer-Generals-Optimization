# ISSUE-0067: Launcher overrides the new singleplayer heap default

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-022

## Evidence

[VERIFIED] tools/launch-game.ps1:72 defaults PathfindingQueue to List; line151 explicitly exports ZH_PF_HEAP=0 and the non-experimental simulation-key loop also forces0. Independent invocation of the actual launcher with Start-Process mocked records child flag0 (artifacts/2026-11-17-independent-review/mock-launcher.json). No game launched. Engine heapAllowed defaults to Heap only when the variable is absent. Therefore normal launches through the documented entrypoint keep List despite ADR0016's default-rollout claim. Existing launcher assertions explicitly expect the old List behavior.

## Resolution / verification

Align the launcher with the accepted singleplayer-default policy, keeping network/replay enforcement in the engine and explicit List override. Update the mocked normal-launch assertion and verify the combined entrypoint, not only direct-executable startup.

### 2026-11-18 verified resolution

[VERIFIED] Launcher Auto now leaves ZH_PF_HEAP absent by default, while explicit Heap/List and Auto TestEnv overrides remain available. Engine network/replay guards are unchanged. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1` passes 93 mocked staging/environment assertions, including default/explicit selectors and inherited-environment restoration; receipt: artifacts/2026-11-18-review-fixes/launcher-final.log. No game launched.
