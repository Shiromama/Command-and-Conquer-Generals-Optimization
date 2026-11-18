# ADR-0001: Repository as the agent interface

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead
- **Related:** T-001, T-003, [`../INDEX.md`](../INDEX.md), [`../../AGENTS.md`](../../AGENTS.md)

## Context

The project will be worked on across multiple sessions and possibly multiple AI agents with
fresh context. Chat history is not durable and cannot be inspected by a new agent. Without a
stable, self-describing repository, each session would re-discover the environment, repeat
mistakes, and leave no verifiable trace of progress.

## Decision

The repository itself is the project's interface. It must contain, at all times:

1. `AGENTS.md` — entry point with hard rules, evidence labels, and the update protocol.
2. `docs/state.json` — machine-readable phase, focus, next actions, blockers.
3. `docs/INDEX.md` — catalog of documents and conventions.
4. Verified environment/install facts, architecture model, roadmap, glossary.
5. Append-only `docs/log.md` and ADRs in `docs/decisions/`.
6. A validator (`tools/check_docs.py`) that fails on broken links, stale state, invalid
   schema, duplicate task IDs, or malformed ADR numbering.

Every working session must leave the docs consistent before it ends.

## Consequences

### Positive

- A new agent can become productive by reading the repository, with no chat handoff.
- Claims are traceable to evidence and dated log entries.
- Structural decisions remain explainable later.

### Negative / risks

- Documentation maintenance adds overhead to every task.
- Docs can drift if the validator is bypassed; the protocol makes the check mandatory.

### Follow-ups

- Extend the validator if new document classes are added.
