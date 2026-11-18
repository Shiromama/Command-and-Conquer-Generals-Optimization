# ISSUE-0099: The console stays silent during patch transactions

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-090

## Evidence

[VERIFIED] The user screenshot shows an empty console after choosing Uninstall. In candidate 14, the base uninstall invokes backup checks and restoration before printing its completion message. Install also scans and hashes the game before showing its completion message.

## Resolution / verification

[VERIFIED] Candidate 15 uses plain-text stages, periodic scan counts and a small bar for verified patch or restore paths. Both PowerShell menu operations reported progress before completion and all 288 ShockWave file hashes were restored. [Timed verification](../../artifacts/2026-11-18-patcher-alpha/candidate-15/manifest.md).
