# ISSUE-0100: Alpha binaries disclose local build paths

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-094
- **Environment:** Candidate 15 local binary release ZIP

## Symptom and evidence

[VERIFIED] The outer release ZIP matches the SHA-256 recorded in `docs/state.json`.
An offline Python inspection of its PE members found absolute Windows user-profile
paths in both `engine.exe` and `zh-patcher.exe`. The engine's PE CodeView debug
directory includes a local PDB path. The patcher also contains local paths outside
that directory. The audit deliberately omits the values.

## Impact

[INFERRED] Publishing this package would disclose private build-machine path details
to anyone who downloads it. Per-file signatures or checksums do not remove the
embedded strings. The public-source snapshot is a separate artifact and its path,
email, and credential-pattern checks returned no matches.

## Resolution / verification

[VERIFIED] T-095 remaps patcher source paths, trims the engine source prefix,
and sets filename-only debug references. The packager rejected each candidate
15 executable individually. Both final candidate 16 executables passed the
path checks in the exact ZIP and their PE debug records had filename-only PDB
references. See the [candidate 16 manifest](../../artifacts/2026-11-18-patcher-alpha/candidate-16/manifest.md).
Candidate 15 still contains the original disclosure.
