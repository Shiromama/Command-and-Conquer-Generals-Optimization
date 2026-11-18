# ISSUE-0026: Entrypoint overview disagrees with canonical state

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-074
- **Related:** [Cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md)
- **Environment:** Local workspace; no runtime changes

## Symptom

[VERIFIED] AGENTS.md labels the project P1 and says the source build is blocked on dependency approval. docs/state.json labels it P2 and records staged source builds.

## Reproduction / evidence

See `artifacts/2026-11-17-cleanup-audit/details.json` and the audit report. For entrypoint state compare `AGENTS.md` with `docs/state.json`. Both were read during T-074.

## Impact

The entrypoint gives obsolete onboarding guidance. This costs negligible disk space and does not block the size audit.

## Root cause

[UNKNOWN] Historical output/documentation accumulated without matching provenance/overview updates.

## Workaround

Use docs/state.json as the canonical state, as AGENTS.md directs. Update overview prose in a separate focused documentation pass.

## Resolution / verification

[VERIFIED] T-092 removed the separate phase claim from AGENTS.md and linked to the
canonical state and source build instructions. It replaced the P0 summary in the root
README with the alpha scope and test evidence. Checked those files against
`docs/state.json` and the task ledger and ran `python tools/check_docs.py` successfully.

## History

- 2026-11-17 — Opened during T-074; no destructive cleanup performed.
- 2026-11-18 — Fixed in T-092.
