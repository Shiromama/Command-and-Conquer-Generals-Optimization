# ADR-0024: Workspace retention budget and reuse gate

- **Status:** Superseded by [ADR-0025](ADR-0025-no-fixed-workspace-cap.md)
- **Date:** 2026-11-20
- **Deciders:** lead
- **Related:** T-114, T-115,
  [workspace prune report](../research/2026-11-20-workspace-prune.md),
  [2026-11-17 cleanup audit](../research/2026-11-17-workspace-cleanup-audit.md)

## Context

[VERIFIED] The workspace grew from about **24.4 GiB** on 2026-11-17 to about
**56.3 GiB** on 2026-11-20. `build/` grew from 4.0 to 23.7 GiB and
`game/` from 10.4 to 22.5 GiB; `artifacts/` stayed near 6.85 GiB. Git
tracked content is 2.56 MB across 370 files; the size is ignored local
output, not history.

[VERIFIED] Each engine iteration created a new ~2.8 GB release tree. Eight
trees existed; five were obsolete. Each contained a 0.86 GB
`z_gameengine.lib` and a 0.22 GB `z_gameenginedevice.lib`, while the final
executable was only 6.8 MB. The patcher work created multiple 1.8-2.3 GB
game copies. Repeating the same build or test across task IDs produced
duplicate trees, copies and artifact runs.

[VERIFIED] The T-114 prune removed 19,090,138,009 bytes (17.78 GiB) across
five release trees and two older alpha copies, leaving about 38.5 GiB. The
final executables and hashes were preserved in `build/engines/`.

## Decision

Adopt a workspace retention budget and a reuse gate:

1. **One active and one published release tree.** Reuse the active tree
   for experiments instead of creating `build/<task>-release` per task.
   Archive final executables to `build/engines/` before removing a
   superseded tree; keep `build/engine-vs-community/` for dependencies.
2. **One active stock/ShockWave alpha pair.** Delete older pairs after
   their journals and evidence are recorded. Reference installs,
   `game/baseline-pristine/` and `game/work/` are never disposable.
3. **One canonical artifact folder per experiment.** Manifest required;
   keep settings, CSVs, summaries, hashes and representative images;
   do not keep full frame sequences, duplicate CSVs/PNGs or raw dumps
   after the doc claim is supported. Link existing evidence instead of
   recopying it.
4. **Reuse gate.** Before a build, game copy or artifact run, search the
   task ledger, research notes and artifact manifests for existing
   evidence. Reuse or extend it unless the new output is materially
   different; state what is new and keep only the delta.
5. **Budget.** Soft cap **45 GiB**, hard cap **50 GiB** for the whole
   workspace. Run `tools/check-workspace-size.py` at session start and end;
   record the size in `docs/state.json` (`workspace_budget`). Prune above
   the soft cap; stop and prune above the hard cap.

## Consequences

### Positive

- Bounded local growth and faster backups/copies.
- Less repeated building/testing, so agents spend work on new evidence.
- Clear retention rules for builds, game copies and artifacts.
- The final executables and hashes remain reproducible without the
  multi-gigabyte intermediates.

### Negative / risks

- A removed release tree needs a rebuild before reuse.
- Deleted game copies must be recreated for a future patcher test.
- Artifact pruning requires judgement; a cited raw file must not be
  removed before its summary/hash is retained.
- The 45/50 GiB caps are policy, not a hard filesystem limit; the checker
  reports and the agent must act.

### Follow-ups

- Run `python tools/check-workspace-size.py` in the session protocol.
- Review artifact evidence (about 1-3 GB potential) separately; do not
  blanket-delete artifacts.
- Keep the current release/copy names in `AGENTS.md` §8 synchronized when
  the active build or alpha pair changes.
