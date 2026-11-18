# ISSUE-0074: Review closeout script used implicit text encoding

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-035

## Evidence

[VERIFIED] The closeout helper used Path.read_text() without an encoding while reading UTF-8 docs/log.md. Windows cp1252 raised UnicodeDecodeError before the log/manifest writes. Artifact inventory verification had already passed (63 dense records and 3 rejected records). No game launched or historical log content altered.

## Resolution / verification

[VERIFIED] Corrected the same implicit-decoding corruption in BOARD and issue register text before commit. Reran closeout writes using explicit encoding='utf-8'; writes completed and the manifest inventory was generated. Final tools/check_docs.py result is recorded in docs/log.md.
