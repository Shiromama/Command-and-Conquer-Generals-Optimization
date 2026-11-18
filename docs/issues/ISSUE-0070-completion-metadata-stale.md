# ISSUE-0070: Completion metadata predates the final heap build

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022
- **Related task:** T-035

## Evidence

[VERIFIED] Before this review, docs/state.json and continuity still identify AC321171...2771 as final, and continuity says Heap is experimental/List default. Latest commit7ce0636 and actual staged/built executable SHA2560C4C74CC71E4D36F5F13B830BF6FD900F778514E0168C72D91DC9E12A4477293 identify the newer engine-default change. This is documentation drift, separate from the launcher bug.

## Resolution / verification

Review checkpoint corrects the canonical hash and explains direct-engine versus launcher behavior. Verification: Get-FileHash on staged/built executables matches; documentation checker must pass after the correction.
