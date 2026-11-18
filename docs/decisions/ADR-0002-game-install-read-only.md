# ADR-0002: Game installation is a read-only reference

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead
- **Related:** T-002, [`../environment.md`](../environment.md), [`../game-inventory.md`](../game-inventory.md)

## Context

The workspace contains a complete 1.29 GB Zero Hour installation already patched with
community tooling (GenTool 7.6 proxy `d3d8.dll`, patched `game.dat`/`Generals.exe`, `.bak`
backups). Any experiment can easily corrupt the only copy, and no original media is
guaranteed to be available for reinstallation. The installation also contains third-party
redistributable assets that must not enter version control.

## Decision

`Command and Conquer Generals Zero Hour/` is treated as an immutable, external reference.
It is gitignored, never modified in place, and never committed. Any task that needs a mutable
copy or a patched binary copies it into a per-run folder under `artifacts/`, records the copy
in a manifest, and verifies the reference installation's hashes afterward when relevant.

Baseline hashes of key binaries are recorded in [`../environment.md`](../environment.md) so
accidental changes can be detected.

## Consequences

### Positive

- The reference installation remains usable as evidence for every future session.
- No game assets or binaries enter git; repository stays small.
- Copy-on-write experiments are isolated and attributable.

### Negative / risks

- Experiments consume extra disk space (up to ~1.3 GB per full copy).
- Agents must remember to copy rather than edit; `AGENTS.md` §3 and the validator's
  reminders mitigate this.

### Follow-ups

- If a change to the reference is ever required, record an ADR first and take a full backup
  with hashes.
