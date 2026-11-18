# ISSUE-0090: Direct overlay activation accepts a changed base

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-082

## Evidence

[VERIFIED] On a disposable candidate 9 fixture, changing an unmanaged base archive caused `verify` to report `Runtime assets changed since installation`. Direct `mods activate` then succeeded and top-level `verify` returned exit 0 while the changed base archive remained.

## Cause and impact

[VERIFIED] Direct activation calls `mod_require_base`, which checks only the base journal's managed entries. The active-overlay branch of top-level `verify` checks the journal status and overlay entries. The documented exact-base compatibility gate and positive verification result can therefore disagree.

## Resolution / verification

[VERIFIED] Candidate 10 uses exact catalog verification under the transaction lock in both activation entry points. `test_mod_exact_base_gate_and_active_verification` confirmed that changed base files are rejected before activation and that Verify detects changes made outside the overlay while it is active. [T-085 verification](../research/2026-11-18-overlay-repair.md)
