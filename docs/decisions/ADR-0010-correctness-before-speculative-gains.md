# ADR-0010: Correctness before speculative optimization gains

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Project user (authorize remediation), Codex (implementation)
- **Related:** T-079, ISSUE-0029 through ISSUE-0034, T-078

## Context

[VERIFIED] T-078 found an unmaintained disabled-object counter, unsafe staging paths, configuration defects, launcher leakage and a fixed scheduler-removal limit. EXP-018 reports that the counter optimization has no proven speed benefit; EXP-011 documents broadphase simulation divergence.

## Decision

Restore the original disabled-status scan rather than introduce lifecycle bookkeeping for an unproven gain. Make broadphase off by default, require an explicit experimental-singleplayer launch for simulation-changing settings, and exclude those settings from network/replay processing. Preserve the measured per-object destruction improvement while removing the fixed collection cap. Treat FPS overrides as startup inputs that live controls may change. Restrict staging to direct mutable children of the repository game directory and reject path aliases, reparse points and source overlap before mutation.

## Consequences

[INFERRED] This removes correctness risks with less new engine state. Disabled scanning and default collision processing may cost more than experimental settings; no new performance claim is made. The rebuilt engine is still not certified retail/network compatible. Broader mod, replay and multiplayer testing remains a separate acceptance gate.

## Follow-ups

Verify destination rejection without mutating protected directories, actual-launcher environment restoration on success/failure, compiled extracted source cases, engine build, patch reproduction and isolated smoke tests. Record exact limitations in T-079.
