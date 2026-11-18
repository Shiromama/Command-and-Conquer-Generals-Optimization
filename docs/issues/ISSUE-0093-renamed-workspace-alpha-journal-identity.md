# ISSUE-0093: Alpha test journals reference the previous workspace path

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-085

## Evidence

[VERIFIED] Candidate 10 `inspect` on the retained `game/alpha-stock-v010b` fixture returned `ERROR: Journal identity mismatch` after T-083 renamed the workspace. Its current file inventory matched the recorded uninstalled snapshot before the command. The journal binds the transaction to its canonical game path.

## Resolution / verification

Run the full-copy check on fresh disposable copies of the matching snapshots, excluding the relocated test journals. Preserve the old journals for evidence. See the [T-085 verification report](../research/2026-11-18-overlay-repair.md).
