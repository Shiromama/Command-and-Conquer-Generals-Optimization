# ISSUE-0025: Artifact provenance missing for screenshot runs

- **Status:** Open
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-074
- **Related:** [Cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md)
- **Environment:** Local workspace; no runtime changes

## Symptom

[VERIFIED] The bounded audit found 46 of 83 pre-existing artifact directories without a top-level manifest.md; 24 also have no literal folder-name mention in the searched documentation/tools.

## Reproduction / evidence

See `artifacts/2026-11-17-cleanup-audit/details.json` and the audit report. For entrypoint state compare `AGENTS.md` with `docs/state.json`. Both were read during T-074.

## Impact

Cleanup cannot safely equate undocumented output with disposable junk. The audit itself is not blocked.

## Root cause

[UNKNOWN] Historical output/documentation accumulated without matching provenance/overview updates.

## Workaround

Retain the runs pending review; classify them using saved details.json, preserve cited visual evidence and timing CSVs, and reconstruct provenance before deletion.

## Resolution / verification

Open. Verify all retained artifact runs have provenance, or verify the entrypoint matches canonical state, respectively, before closing the corresponding issue.

## History

- 2026-11-17 — Opened during T-074; no destructive cleanup performed.

- 2026-11-17 — T-075 added cleanup inventories/manifests to 24 reviewed runs and sampled 17 image sequences. Original capture provenance is still unknown where absent; 22 of the original 83 runs still lack manifests. Issue remains Open. See [cleanup results](../research/2026-11-17-cleanup-results.md).
