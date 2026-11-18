# ISSUE-0095: Source launcher cannot find the packaged executable

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-087

## Evidence

[VERIFIED] The user's screenshot showed `patcher/Menu.ps1` looking for `patcher/zh-patcher.exe`. The source directory holds the console script. The built executable, engine payload and manifest live together in the extracted package under `artifacts/`.

## Resolution / verification

[VERIFIED] The source launcher resolves the packaged release recorded in `docs/state.json`. An extracted package uses the files next to its own launcher. A Windows PowerShell 5.1 harness ran both source menu actions with candidate 13, confirmed the picker had no assigned folder, and restored all 288 ShockWave file hashes. A separate missing-package run exited 1 with a concise message before opening the picker.
