# Architecture decision records (ADRs)

> **Status:** append-only log · **Last verified:** 2026-11-14
> One file per decision: `ADR-####-short-slug.md`, numbered monotonically, never rewritten.
> A changed decision gets a new ADR that supersedes the old one (both stay in the repo).

## Index

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](ADR-0001-agent-readable-docs.md) | Repository as the agent interface | Accepted | 2026-11-14 |
| [ADR-0002](ADR-0002-game-install-read-only.md) | Game installation is a read-only reference | Accepted | 2026-11-14 |
| [ADR-0003](ADR-0003-local-git-tracking.md) | Local git tracking with excluded binaries | Accepted | 2026-11-14 |
| [ADR-0004](ADR-0004-defer-big-tooling.md) | Defer BIG archive tooling | Accepted | 2026-11-14 |
| [ADR-0005](ADR-0005-source-based-hybrid.md) | Source-based hybrid optimization, not a clean-room rewrite | Accepted | 2026-11-14 |
| [ADR-0006](ADR-0006-baseline-work-copies.md) | Pristine baseline plus mutable work copy | Accepted | 2026-11-14 |

## Template

Copy the block below into a new file named `ADR-####-short-slug.md` and fill every field.
Use `<angle brackets>` only inside this README; real ADRs must have no placeholders.

```markdown
# ADR-####: <title>

- **Status:** Proposed | Accepted | Superseded by ADR-####
- **Date:** YYYY-MM-DD
- **Deciders:** <names/roles>
- **Related:** <task IDs, docs, experiments>

## Context

What is the situation and what forces are at play? Cite evidence.

## Decision

What was decided, stated as a single clear sentence, then details.

## Consequences

### Positive
- ...

### Negative / risks
- ...

### Follow-ups
- ...
```

## Rules

1. Record the decision **when it is made**, not retrospectively after implementing it.
2. Include the evidence that justified it (`[VERIFIED]`/`[SOURCED]`/`[INFERRED]`).
3. Link the ADR from the task that triggered it and from the log entry.
4. Never delete an ADR; supersede it.

| [ADR-0010](ADR-0010-correctness-before-speculative-gains.md) | Correctness before speculative optimization gains | Accepted | 2026-11-17 |

| [ADR-0011](ADR-0011-measure-pathfinding-and-gate-shadow-map.md) | Measure pathfinding; gate real shadow maps | Accepted | 2026-11-17 |

| [ADR-0012](ADR-0012-stable-heap-experimental-singleplayer.md) | Stable heap only by explicit experimental selection | Accepted | 2026-11-17 |

| [ADR-0013](ADR-0013-bounded-shadow-geometry-batches.md) | Bounded rigid shadow batches and GPU projection | Accepted | 2026-11-17 |

| [ADR-0014](ADR-0014-sampled-depth-shadow-receivers.md) | Sampled depth for complete opaque receivers | Accepted | 2026-11-17 |
| [ADR-0015](ADR-0015-reject-shadow-map-renderer.md) | Reject the shadow-map renderer; keep stencil | Accepted | 2026-11-17 |
| [ADR-0016](ADR-0016-default-pathfinding-heap.md) | Default the stable heap in singleplayer | Accepted | 2026-11-17 |
| [ADR-0017](ADR-0017-alpha-patcher-transactions.md) | Exact-profile singleplayer alpha patcher | Accepted | 2026-11-18 |
| [ADR-0018](ADR-0018-guard-range-floor.md) | Singleplayer human guard floor covers usable weapon range | Accepted | 2026-11-18 |
| [ADR-0019](ADR-0019-community-mod-overlay.md) | Community-compatible transactional mod overlay | Accepted | 2026-11-18 |

| [ADR-0020](ADR-0020-compatible-runtime-patcher-profile.md) | Compatible runtime profile for local mod data | Accepted | 2026-11-18 |
| [ADR-0021](ADR-0021-engine-optimization-scope.md) | Focus the project on C++ engine optimization | Accepted | 2026-11-18 |
| [ADR-0022](ADR-0022-prepared-mod-inputs.md) | Require prepared mod inputs in the alpha patcher | Accepted | 2026-11-18 |
