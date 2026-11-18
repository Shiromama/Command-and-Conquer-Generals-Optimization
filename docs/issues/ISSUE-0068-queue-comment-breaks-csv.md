# ISSUE-0068: Queue annotation breaks existing pathfinding analyzers

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-022

## Evidence

[VERIFIED] PathfindTelemetry.inc:39 inserts # queue=heap|list after the CSV header. tools/compare-pathfinding.py:16 rejects this as a malformed interior row. Both actual heap-default/default and heap-default/list request logs reproduce ValueError; receipts are in artifacts/2026-11-17-independent-review/telemetry-parser-review.json. analyze-pathfinding.py also reads the comment as a request and converts frame to int. Earlier EXP027 evidence predates this annotation; fresh verification is broken.

## Resolution / verification

Keep queue identity in a sidecar, or explicitly support this metadata row consistently before CSV parsing. Preserve strict rejection of other malformed interior rows. Reanalyze the retained new logs with both analysis entrypoints.

### 2026-11-18 verified resolution

[VERIFIED] Shared strict CSV reader accepts the single queue annotation and rejects malformed/duplicate/late metadata. Both analysis entrypoints read the retained new logs. `python tools/test-pathfinding-csv.py` passes 18 checks; `python tools/compare-pathfinding.py artifacts/2026-11-17-heap-default/list artifacts/2026-11-17-heap-default/default --output artifacts/2026-11-18-review-fixes/default-parity.json` exits 0 with identical requests, paths and CRC: 8,816 requests and 15 CRC samples per arm through logic frame 1411. Single-run analyzer also exits 0. Receipts: artifacts/2026-11-18-review-fixes/.
