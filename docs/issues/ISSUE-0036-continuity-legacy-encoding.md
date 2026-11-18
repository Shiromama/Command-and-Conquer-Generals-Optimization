# ISSUE-0036: Continuity checkpoint is not UTF-8

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Python 3.10 documentation update

## Symptom

[VERIFIED] Reading .opencode/continuity.md as UTF-8 raised UnicodeDecodeError at byte 215 (0x97). The update script stopped after saving report, board and state; it did not append the intended log entry.

## Reproduction / evidence

[VERIFIED] `Path('.opencode/continuity.md').read_text(encoding='utf-8')` fails. Its existing bytes predate this review. No engine/game files were involved.

## Impact

The documentation update needed an encoding-preserving append.

## Root cause

[VERIFIED] The existing file contains a byte sequence that is invalid UTF-8. Its original encoding is not established.

## Workaround

Append the ASCII checkpoint as bytes, retaining all existing bytes.

## Resolution / verification

[VERIFIED] ASCII byte append completed successfully and the new T-078 marker is present. The log update was performed separately. This fixes the update operation; no encoding conversion or claim of UTF-8 conformance is made.

## History

- 2026-11-17 — Failed UTF-8 read recorded; completed an encoding-preserving append.
