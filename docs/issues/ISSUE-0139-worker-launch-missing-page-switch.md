# ISSUE-0139: Worker replay launcher omitted the native page switch

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The GTX launch matched replay behavior and 135,525
footprint policy checks. The worker CSV contained only its header.
The launcher inherited a runner from before the native page switch,
so the immutable source snapshot was unavailable at submission.

## Resolution / verification

[VERIFIED] The generator now inherits the native page runner. The
combined raw-route trial explicitly checks for the page setting
before launching. The corrected `start.ps1` exited zero. The
receipt recorded 1,131 submissions across all four workers and 307
accepted claims with no predicate mismatch. Sync, commands, ordered
queue and all original search records matched.
