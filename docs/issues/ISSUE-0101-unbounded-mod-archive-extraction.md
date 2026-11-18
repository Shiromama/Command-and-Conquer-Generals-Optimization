# ISSUE-0101: Mod inspection and import have no archive resource limits

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-094
- **Environment:** Windows patcher archive inspection and import

## Symptom and evidence

[VERIFIED] In `patcher/src/main.rs`, `mod_add` and `mod_inspect` both call
`extract_archive` for compressed mod packages. The helper captures the entire
listing in memory, checks names, then extracts to the user's temporary volume.
The code sets no entry-count, expanded-size, or time budget before starting
these operations. Inspection totals file sizes only after extraction.

## Impact

[INFERRED] An untrusted archive can consume the user's disk space or memory when
inspected or imported. It requires the user to select the archive. The path and
post-extraction link checks do not bound resource use. This is based on source
review. No hostile archive was created or executed.

## Resolution / verification

[VERIFIED] T-095 removed compressed archive extraction from both commands.
`mod_source` accepts prepared directories and individual `.big`, `.gib`
and `.zbig` files. Both test builds rejected ZIP, 7z and RAR inputs during
inspection and import, then successfully activated and restored the prepared
folder and individual `.big` controls. Both suites collected 43 cases and
exited 0. See [ADR-0022](../decisions/ADR-0022-prepared-mod-inputs.md).
