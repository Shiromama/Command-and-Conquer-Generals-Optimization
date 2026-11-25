# ISSUE-0105: GitHub release asset upload timed out

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-102

## Evidence

[VERIFIED] The GitHub API created the pre-release draft. The Python HTTPS
client timed out while sending the verified ZIP to GitHub's asset upload host.
An authenticated read after the failure found the draft with an empty asset
list.

## Resolution / verification

[VERIFIED] A curl retry against the same draft completed. The GitHub API
reported the exact local ZIP SHA-256 and 21,220,347 bytes. Published the
verified draft as a pre-release. See the [candidate 17 manifest](../../artifacts/2026-11-18-patcher-alpha/candidate-17/manifest.md).
