# ADR-0003: Local git tracking with excluded binaries

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead
- **Related:** T-001, [`../../.gitignore`](../../.gitignore)

## Context

The workspace was not a git repository. For a multi-session, multi-agent project, progress
needs to be auditable: which files changed, when, and for which task. At the same time, the
workspace holds a 1.29 GB game installation plus large scratch outputs (traces, dumps,
extracted assets) that must not be versioned.

## Decision

Initialize a **local** git repository in the workspace root (no remote, no push). Commit the
documentation system and future source code. Exclude:

- `/Command and Conquer Generals Zero Hour/` (entire installation),
- `/artifacts/*` except `artifacts/README.md`,
- `/target/` and Rust build artifacts,
- editor/OS noise.

Commit messages include the task ID, e.g. `T-001 document agent interface`.

## Consequences

### Positive

- Every session can be reviewed via `git log`/`git diff`.
- Accidental modification of tracked docs is detectable.
- No large binaries in history.

### Negative / risks

- A local-only repository is not a backup; disk loss loses history.
- Ignored binaries mean hashes/versions must be documented in `docs/` (already done in
  [`../environment.md`](../environment.md)).

### Follow-ups

- If a remote is added later, re-check the ignore rules before pushing.
- Keep commits scoped to one task where practical.
