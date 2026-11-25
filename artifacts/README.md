# Artifacts

Large, machine-generated evidence lives here. The directory is **gitignored** except for this
README; artifacts are never committed.

## Layout

```
artifacts/
  YYYY-MM-DD-<slug>/
    manifest.md          # required: what, how, when, hashes
    raw/                 # logs, traces, dumps
    screenshots/
    extracted/           # extracted game data (never commit)
```

## Manifest requirements

Each run folder must contain `manifest.md` with:

1. Date, task ID, operator/agent.
2. Exact commands/tools and versions used.
3. Inputs (game build hash, GenTool state, map/scenario).
4. Output inventory with sizes and SHA-256 for anything reused as evidence.
5. Result summary and link to the doc/experiment that cites it.

## Rules

- Never store secrets, credentials, or personal data.
- Never copy the whole 1.29 GB installation unless the experiment requires it; prefer a
  manifest describing which files were copied and their hashes.
- Prefer text logs; compress large traces.
- Reference artifacts from docs by relative path so they remain findable.
- Retention: keep artifacts that back a claim in a doc; delete superseded scratch runs.

## Retention budget

- One canonical `YYYY-MM-DD-<slug>/` per experiment. Extend its manifest for a rerun; do not
  fork a second folder for a new task ID or a renamed run.
- Keep the manifest, settings, CSVs, summaries, hashes and a few representative screenshots or
  contact sheets. Do not keep full-resolution frame sequences, duplicate CSVs/PNGs or raw dumps
  after the doc claim is supported.
- Before creating a run folder, search `artifacts/*/manifest.md`, `docs/research/` and the task
  ledger for reusable evidence. Repeat a run only when the new output is materially different;
  record why and keep only the delta.
- When deleting a superseded run, keep its manifest/hashes and update the doc that cited it.
- Workspace budget: there is no fixed size cap. Run
  `python tools/check-workspace-size.py` to see growth; it is informational. Build/copy/artifact
  efficiency rules are in `AGENTS.md` §8 and
  [ADR-0025](../docs/decisions/ADR-0025-no-fixed-workspace-cap.md).
