# ISSUE-0028: Cleanup preflight misidentifies parent directories

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-075
- **Related:** [Cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md)
- **Environment:** PowerShell cleanup script

## Symptom

[VERIFIED] The cleanup preflight stopped with `Ancestor escaped workspace` before any deletion.

## Reproduction / evidence

`artifacts/2026-11-17-cleanup-execution/apply.ps1` exited 1 at line 23.

## Impact

Deletion was prevented. Preparation outputs and original files remained available.

## Root cause

[VERIFIED] Parent DirectoryInfo instances do not reliably expose the provider-added PSIsContainer property. The walk incorrectly used the FileInfo Directory property on a directory.

## Workaround

Use an explicit System.IO.DirectoryInfo type check when walking parents.

## Resolution / verification

[VERIFIED] Corrected the parent walk to use `-is [System.IO.DirectoryInfo]`. The apply script then exited 0, removing the 3,260 explicitly planned files. `python artifacts/2026-11-17-cleanup-execution/verify.py` exited 0: deleted paths absent, 396 retained hashes match, 16,477 protected metadata records unchanged.

## History

- 2026-11-17 — Opened after preflight failure; deletion loop had not started.
