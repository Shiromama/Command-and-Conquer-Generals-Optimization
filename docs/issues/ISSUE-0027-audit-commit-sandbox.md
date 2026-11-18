# ISSUE-0027: Audit report commit blocked by sandbox

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-074
- **Related:** [Cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md)
- **Environment:** Codex workspace-write sandbox; .git metadata read-only

## Symptom

[VERIFIED] Initial `git add` failed to create `.git/index.lock`: Permission denied.
The following commit command consequently could not find the untracked report in the index.

## Reproduction / evidence

`git add -- docs/research/2026-11-17-workspace-cleanup-audit.md` in the default sandbox exited 128.
No game files were involved.

## Impact

Documentation could not be committed in the default sandbox. The analysis was unaffected.

## Root cause

[VERIFIED] The session permissions grant read access to .git and require elevation for writes.

## Workaround

Run the narrowly scoped Git commands with require_escalated after automatic approval review.

## Resolution / verification

[VERIFIED] The approved retry of `git add` and `git commit --only` exited 0 and created
`c62c590` (T-074), one new report file, 71 insertions. Existing changes were not committed.

## History

- 2026-11-17 — Opened and fixed during T-074; approved Git retry succeeded.
