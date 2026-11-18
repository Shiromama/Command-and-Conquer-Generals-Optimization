# ADR-0016: Default the stable pathfinding heap in singleplayer

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** lead (user request to enable the heap by default)
- **Related:** T-022, ADR-0012, EXP-027, ISSUE-0066

## Context

T-022 retained a stable indexed heap as an opt-in experimental-singleplayer option because the
acceptance runs showed the largest gain in congested movement and no gain in a no-blocker
fixture. The user asked for the heap to be enabled by default.

[VERIFIED] Native three-pair evidence: pathfinding 0.8710 and whole update 0.9048 in the
congested fixture, with identical recorded paths, expansion fingerprints and sampled CRC
(EXP-027). The no-blocker fixture measured 1.0406 / 0.9980, i.e. no useful overall change.

## Decision

Make the stable indexed heap the default queue for **singleplayer** pathfinding. `allowed()`
already excludes network games and replays, and those modes keep the retail List automatically.
`ZH_PF_HEAP=0` (or any invalid token) restores List for tests and troubleshooting;
`ZH_PF_HEAP=1` forces Heap. The startup log record now names the active queue
(`# queue=heap|list`).

## Consequences

[VERIFIED] Compiled source tests updated: the default (variable absent) is Heap inside a
singleplayer game; multiplayer and replay return List even when `ZH_PF_HEAP=1`; `0` and invalid
tokens return List. 10 queue-semantics cases and 12 mode guards pass.

[VERIFIED] In-game runs with no `ZH_PF_HEAP` report `# queue=heap`; with `ZH_PF_HEAP=0` they
report `# queue=list` (artifacts/2026-11-17-heap-default).

[UNKNOWN] No network or replay certification follows from this. The parity evidence covers the
deterministic singleplayer fixtures only, so multiplayer and replay continue to force List and
remain uncertified for the heap.

[VERIFIED] The heap changes queue mechanics only: no search cap, heuristic, cost, cell layout or
allocation-pool change. Disable per launch with
`tools/launch-game.ps1 ... -TestEnv @{ ZH_PF_HEAP = '0' }` (allowed because the value is 0) or
`-PathfindingQueue List`.

## Launcher integration follow-up (2026-11-18)

[VERIFIED] The normal launcher now defaults to Auto and leaves ZH_PF_HEAPunset, preserving the engine's singleplayer default. List/Heap overrides are explicit and no longer require the unrelated experimental token; the engine still forces List in network/replay modes. Auto honors TestEnv.ZH_PF_HEAP. Conflicting explicit selectors are rejected, inherited diagnostics are excluded, and caller environment is restored. CSV readers recognize the queue metadata row without treating it as a request. See ISSUE0067/0068verification receipts and the review remediation report.
