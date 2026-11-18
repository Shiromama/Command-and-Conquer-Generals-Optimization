# ADR-0012: Keep the stable heap as an experimental singleplayer option

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Codex (within the authorized T-022 scope)
- **Related:** T-022, ADR-0010, ADR-0011

## Context

[VERIFIED] Correctly registered blockers produce open queues up to 359 cells. Three native 1920x1080 congested-workload pairs on the same executable show 12.9% lower aggregate pathfinding time and 9.5% lower whole-update time with matching request/path/expansion fingerprints and sampled game CRCs. One no-blocker pair shows 4.1% higher pathfinding time and essentially unchanged total update time. See EXP-027 and artifacts/2026-11-17-queue-replay/manifest.md.

## Decision

Retain an explicitly selected stable indexed heap for experimental singleplayer only. The normal launcher selects List; Heap requires -ExperimentalSingleplayer -PathfindingQueue Heap. Engine guards additionally exclude network, replay, shell and out-of-game execution. Do not certify multiplayer/replay compatibility from these local tests.

Preserve costs, search limits, FIFO tie order, seed handling and sorted cleanup order. At the original 5,000-open-cell boundary, materialize the original sorted list and continue through its existing cap behavior. Keep PathfindCellInfo layouts and pool allocation unchanged. The existing RETAIL_COMPATIBLE_CRC-guarded statements remain; the opt-in branch precedes them and is disabled outside the authorized mode.

## Consequences

[VERIFIED] The optimization benefits this congested fixture; it is not a universal game speedup. Memory is allocated lazily only when requested. The six corrected operation-logging baselines are historical 1280x720 queue/correctness evidence; final engine timing uses 1920x1080 without operation logging. All future game tests use the user's native resolution and require a heads-up before each launch.

[UNKNOWN] Wider maps, armies, long sessions and other CPU architectures may change the tradeoff. Broader testing is required before considering a default change. Exact local sampled CRCs do not prove general compatibility.

- **Superseded in part (2026-11-17):** the heap is now the singleplayer default; multiplayer and replays still force List. See [ADR-0016](ADR-0016-default-pathfinding-heap.md).
