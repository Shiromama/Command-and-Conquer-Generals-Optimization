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
