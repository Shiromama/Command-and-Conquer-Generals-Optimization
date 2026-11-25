# ISSUE-0122: Fast PGO preparation lacked a training folder

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first isolated fast-profile preparation stopped in
`start-pgo.ps1 -Action Prepare`. The script checked for existing profile
files before the new training folder had been created.

## Resolution / verification

[VERIFIED] `prepare-fast.py` creates the training folder before invoking
the launcher. Running it and `start-pgo.ps1 -Action Prepare` then returned
zero and generated the independent trainer, control and hash receipt.
