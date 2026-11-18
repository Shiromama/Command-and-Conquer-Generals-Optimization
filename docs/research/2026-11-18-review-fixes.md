# T-022 / T-035 review remediation, 2026-11-18

[VERIFIED] Resolved ISSUE-0067, ISSUE-0068, ISSUE-0069, ISSUE-0071 and ISSUE-0072. ISSUE-0070 was already fixed during review. The new test-only ISSUE-0073 was fixed and verified in this session. No game launched, gameplay source rebuilt or game executable changed.

## Delivered changes

- Launcher Auto honors the engine singleplayer Heap default; explicit List/Heap and Auto TestEnv overrides work. Conflicting selectors fail clearly. Network/replay enforcement remains in the engine.
- Both pathfinding analyzers accept the queue annotation through one strict reader. Unknown, misplaced or duplicate metadata and malformed interior records still fail. Default sidecars require actual queue metadata rather than guessing.
- Shadow benchmark defaults to Stencil. Removed renderer modes and renderer-specific switches fail before settings changes or process startup. New parameter records include the scene controls previously omitted.
- [Tracked rejected source](../../engine/rejected/T-035/README.md) pins the upstream base, base patch and exact retained calibrated prototype/hooks. Reconstruction is verified in scratch; it does not claim a bit-identical historical executable.
- Dense/rejected artifact manifests and hash inventories now describe retained evidence, reconstructed provenance and missing original parameters. EXP-029 corrects the unequal frame counts.

## Verification

[VERIFIED] Receipts are in artifacts/2026-11-18-review-fixes/manifest.md:

| Check | Result |
|---|---|
| tools/test-optimization-fixes.ps1 (mocked processes) | 93 staging/environment assertions passed |
| python tools/test-pathfinding-csv.py | 18 format, rejection and retained-log checks passed |
| tools/verify-rejected-shadow-source.py --output artifacts/2026-11-18-review-fixes/archive-check | 30 affected source files reconstructed |
| tools/test-shadow-batches.py --output artifacts/2026-11-18-review-fixes/batch-tests | 17 actual-source batch/cache cases passed |
| compare-pathfinding.py, retained heap-default List/Default pair | 8,816 requests and 15 CRC samples per arm match through logic frame 1411 |
| analyze-pathfinding.py, retained Default run | Exit 0 |
| analyze-shadow-map-ab.py, retained dense evidence | Exit 0, rejection unchanged |
| tools/prepare-game-copies.ps1 -VerifyOnly | Baseline matches all 1,914 files |
| Active vendor reverse patch check | Exit 0 |
| Built/staged SHA256 | Both 0C4C74CC71E4D36F5F13B830BF6FD900F778514E0168C72D91DC9E12A4477293 |

[VERIFIED] Final documentation validation is recorded in docs/log.md. The initial test failure involving PowerShell's automatic args variable is preserved and tracked as ISSUE-0073; the corrected suite passes.

## Limits

[VERIFIED] These are integration and provenance fixes with retained-log/CPU verification. No new runtime performance claim is made. The rejected per-mesh shadow prototype remains excluded from the active engine; stencil remains the only active path. The fullscreen main-depth design in ADR-0014 remains unbuilt. T-025 remains blocked on a compatible late-game replay (ISSUE-0010). The old long-running goal has not been resumed.
