# ISSUE-0084: BIG reader rejects a zero-length PatchZH archive marker

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-081

## Evidence

[VERIFIED] Read-only stock archive audit raises BigError on PatchZH.big Data/* with offset=0 and size=0. Existing reader requires every entry offset to follow the header even when there are no payload bytes. No game files changed.

## Resolution / verification

Accept zero-length offset-zero records without weakening nonempty-payload bounds checks; verify synthetic boundary cases and the actual stock archives before resuming the unit audit.

[VERIFIED] `tools/big-archive.py` now accepts zero-length offset-zero markers only when the entry has no payload; nonempty bounds checks are unchanged. `python tools/test-big-archive.py` passes 4 cases including five invalid-bounds subcases. The read-only audit then completed over 25 stock-reference archives: 149 first-match INI files, 2,103 object definitions, 354 guard unit variants, 47 base-floor candidates and 236 variants needing no change. Evidence: `artifacts/2026-11-18-guard-range/stock-guard-audit.json`, `big-reader-tests-final.log` and `audit-final.log`.
