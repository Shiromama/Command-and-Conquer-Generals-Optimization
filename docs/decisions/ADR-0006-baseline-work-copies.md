# ADR-0006: Pristine baseline plus mutable work copy

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead
- **Related:** T-018, T-019; [`../game-copies.md`](../game-copies.md), [`../../game/README.md`](../../game/README.md)

## Context

Baselines must be trustworthy: a measurement or fix is only meaningful against a known,
unmodified game state. The only complete installation is under
`Program Files (x86)\R.G. Mechanics\...`, which is ACL-protected and must never be edited.
Earlier experiments showed how easy it is to leave config or test artifacts behind.

At the same time, fixes must not depend on this specific PC. Hardcoded paths, registry GPU
preferences, or editing the installed copy do not scale to another machine.

## Decision

1. Copy the complete installation into two labeled local directories:
   - `game/baseline-pristine/` — byte-exact copy, every file marked read-only, covered by a
     tracked SHA-256 manifest in `docs/manifests/`.
   - `game/work/` — mutable copy where every fix, patch, or test setup is applied.
2. Never edit the source installation or `baseline-pristine/`.
3. Apply fixes through small, portable profiles and parameterized scripts
   (`tools/prepare-game-copies.ps1`, `tools/launch-game.ps1`), not registry or absolute-path
   tweaks.
4. Keep the baseline manifest in git; keep the multi-gigabyte copies out of git.
5. Treat user settings under `%USERPROFILE%\Documents\...` as a separate, backed-up input.

## Consequences

### Positive

- A verifiable "before" state exists for every measurement.
- Fixes can be tested without risking the installed game.
- The copy/profile/launch workflow is reproducible on another PC by changing `-SourceGameDir`.
- Hash drift in the baseline is immediately detectable.

### Negative / risks

- Requires roughly 2× the installation size locally (about 3.8 GB for this build).
- The baseline is only as good as its manifest; regeneration must use a new label.
- User data (Options.ini, saves) is outside the copies and still needs separate control.

### Follow-ups

- T-014: build the source against the work copy's data.
- T-015: capture the entity-heavy baseline from `baseline-pristine` and compare with `work`.
- Any new fix must land in `game/work/` or a tracked source patch, never in the baseline.
