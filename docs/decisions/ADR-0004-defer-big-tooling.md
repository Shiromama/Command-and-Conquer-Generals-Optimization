# ADR-0004: Defer BIG archive tooling

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead (per user direction)
- **Related:** T-007, [`../game-inventory.md`](../game-inventory.md) §2

## Context

The installation's game data lives in 22 `BIGF` archives, most importantly `INIZH.big`
(18.8 MB) which contains the INI rules. Reading those archives is a prerequisite for many
later tasks. During P0 setup the user explicitly directed that the archive file be ignored
for now because the current objective is project setup, not asset extraction.

Early observations (header starts `BIGF`, archive size at offset 4, file count and directory
entries near the start) are **not** sufficient to justify building a parser during setup.

## Decision

Do not build or ship BIG archive tooling in P0. Defer extraction/parsing work to P1 (task
T-007), where it will be scoped against a concrete need (e.g., reading INI rules), verified
against known archive contents, and recorded as its own experiment/tool with tests.

## Consequences

### Positive

- P0 stays focused on documentation and reproducibility.
- The parser will be designed with a real use case and verification data, not guesses.

### Negative / risks

- P1 cannot read game rules until T-007 completes.
- The partial header observations must be re-verified later; they are recorded in
  [`../game-inventory.md`](../game-inventory.md) as unverified.

### Follow-ups

- T-007: choose between a small first-party parser and an existing community tool; document
  the choice in an ADR.
