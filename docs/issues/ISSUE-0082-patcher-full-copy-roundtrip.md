# ISSUE-0082: First full stock-copy round trip does not match original inventory

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] tools/test-patcher-copies.py install/verify/repeated-install/uninstall commands return 0, but the complete stock-copy hash inventory differs after uninstall. Runtime tests are deferred. Difference receipt: artifacts/2026-11-18-patcher-alpha/stock-roundtrip-diff.json. Only the disposable game/alpha-stock-v010 copy was mutated; immutable references were not changed.

## Resolution / verification

Determine the exact differing paths and correct restoration or the verification method, then repeat both complete-copy round trips before game smoke tests.

[VERIFIED] Difference is filename case only: original generals.exe is restored as Generals.exe with identical SHA256. Preserve the original engine/proxy filename spelling in each trusted profile, as well as script mapping spelling. Added a filename-case regression. Repeat on fresh v010b copies; earlier v010 copies and receipts retained for diagnosis.

### Verified resolution

[VERIFIED] Preserved actual target filename spelling in the journal, while validating the fixed trusted plan case-insensitively for Windows. Mixed-case filename regression passes. Fresh full-copy round trips restore all 1,914 stock and 288 ShockWave file hashes and original names; artifacts/2026-11-18-patcher-alpha/real-copy-roundtrips.json.
