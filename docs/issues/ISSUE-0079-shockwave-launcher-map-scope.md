# ISSUE-0079: Catalog assumes every ShockWave launcher mapping is an archive

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] Initial catalog generation fails on the retained Shockwave_Lnchr.dat because the map also contains bitmap swaps and stock loose-script disabling renames, not just .gib to .big. No game files changed. Supporting those script renames is necessary to follow the known launcher's data routing rather than treating arbitrary map rows as patcher instructions.

## Resolution / verification

Explicitly catalog the 11 archive mappings and the three known stock script renames; ignore launcher UI bitmap swaps. Journal both copied destinations and removed script originals, retaining backups. Only the raw exact ShockWave snapshot is accepted for a fresh install; already materialized arbitrary copies are refused. Verification pending.

### Verified resolution

[VERIFIED] Production script-routing regression passes; full real ShockWave install/verify/uninstall/reinstall round trip restores all 288 original file hashes/names. Receipts: artifacts/2026-11-18-patcher-alpha/real-copy-roundtrips.json and production-tests-final.log.
