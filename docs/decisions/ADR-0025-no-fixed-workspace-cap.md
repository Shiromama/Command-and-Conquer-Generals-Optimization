# ADR-0025: No fixed workspace size cap; efficiency and reuse

- **Status:** Accepted
- **Date:** 2026-11-20
- **Deciders:** lead
- **Related:** T-114, T-115,
  [ADR-0024](ADR-0024-workspace-retention-budget.md) (superseded),
  [workspace prune report](../research/2026-11-20-workspace-prune.md)

## Context

ADR-0024 set a soft 45 GiB / hard 50 GiB workspace cap after the T-114 prune.
The user rejected a fixed cap: the goal is efficient work, and a cap can block
a legitimate large build, test copy or evidence set. The measured problem was
not one large workspace but **repeated generated output**: five obsolete
release trees, duplicate game copies and repeated artifact runs.

[VERIFIED] After the T-114 prune the workspace is about 38.52 GiB. The
reuse/retention rules remain useful; a numeric quota is not required to apply
them.

## Decision

Remove the fixed workspace size caps. Keep the efficiency rules:

1. Reuse the active build tree, documented game copies and existing evidence.
   Prefer one active release tree; keep additional trees only while actively
   needed.
2. Archive the final executable/hash to `build/engines/` before removing a
   superseded tree; remove generated intermediates when they are no longer
   needed.
3. One canonical artifact folder per experiment with a manifest; no duplicate
   runs or full frame sequences; link existing evidence.
4. Delete superseded output with an explicit plan, paths and hashes; never
   touch the immutable references.
5. `tools/check-workspace-size.py` is informational and always exits 0. It
   shows growth and the largest trees/copies/artifacts; it does not enforce a
   quota.

## Consequences

### Positive

- No artificial limit on a legitimate large build or test set.
- The rules target the actual waste: duplicate trees, copies and artifact
  runs.
- Agents can still see growth and prune deliberately.

### Negative / risks

- The workspace can grow past any previous target; no automatic failure
  catches it.
- Pruning depends on judgement and on reading the size report.
- The reuse gate and canonical artifact rule must be followed to avoid the
  old duplication pattern.

### Follow-ups

- Keep the size checker in the session protocol for visibility.
- Prune superseded output when practical; record the result and hashes.
- Review artifact evidence separately; do not blanket-delete cited files.
