# ISSUE-0053: Queue trace packer did not handle a killed-process CSV tail

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** diagnostic 15-second queue capture

## Symptom / evidence

[VERIFIED] pack-pathfinding-operations.py raises ValueError on an empty integer field. The subsequent replay command has no valid binary header; no replay result accepted. Raw evidence: artifacts/2026-11-17-queue-replay/capture-blockers/blockers-5-run-1/operations.csv.

## Root cause

[UNKNOWN] Inspect whether an abrupt process stop left a partial last record or whether the writer emitted an invalid interior record.

## Impact

Offline comparison cannot proceed until the trace format is validated. Game capture itself completed with expected output files.

## Workaround

If limited to a non-newline-terminated final record, report and discard only that tail and then exclude incomplete request scopes. Reject every malformed interior record.

## Resolution / verification

Pending strict pack and replay verification.

[VERIFIED] Only the final row is malformed and the file lacks a newline terminator. Packer now reports discarded trailing bytes, rejects malformed interior records, and excludes scopes without E. Packing succeeds and the replay verifies every observed head across 1,179,166 events / 7,041 completed scopes; list and heap checksums match. Raw source remains unchanged. Evidence: pack-blockers.json, result-blockers.json.
