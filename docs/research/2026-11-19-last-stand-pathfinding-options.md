# Reducing Last Stand pathfinding work

- Date: 2026-11-19
- Task: T-108
- Baseline: [T-107 Last Stand trace](2026-11-19-last-stand-slowdown.md)
- Scope: research and experiment design for the patched ShockWave skirmish

## Recommendation

[INFERRED] Pursue three complementary layers. Suppress or coalesce demonstrably redundant AI retries. Reuse the coarse portion of compatible routes. Introduce bounded scheduling for the expensive searches that remain only if tail latency still warrants it. Retain the engine's per-unit local movement, collision checks and weapon-position checks. Start with a diagnostic census so the first prototype targets the branch that actually consumed the time.

## What the workload can tell us

[VERIFIED] Re-reading the visual attribution and path CSVs from the [T-107 evidence directory](../../artifacts/2026-11-19-last-stand-replay/manifest.md) gave the following results. The visual log records an updated game frame `f`, while path telemetry records the work as `f - 1`. Select frames 16979–17278, join on that offset, then average `interval`, `usec_total / 1000`, `usec_max / 1000`, and `(usec_total - usec_max) / 1000`. The report's existing `analyze-slow-slices.py ... --first 16979 --last 17278` independently reproduces the mean frame and total search timings.

| Quantity | 300 matched frames at 7.16 FPS |
|---|---:|
| Mean frame time | 139.66 ms |
| All timed path search scopes | 98.45 ms |
| Largest timed search scope per tick | 32.19 ms |
| Other timed search scopes | 66.26 ms |
| Rest of frame | 41.21 ms |
| Mean search scopes per tick | 21.46 |

[VERIFIED] These are outermost timed search scopes. A full unit order may invoke more than one scope or perform uninstrumented work around it. The aggregate capture has no per-request owner, retry reason or outcome. Its expansion counter and the engine's queued cell-allocation counter measure different things.

[INFERRED] A simple fixed-work model gives the investigation a scale. If the rest of the frame stays at 41.21 ms, eliminating only the largest measured scope per frame would yield about 9.3 FPS. A 10 FPS mean requires about 40% less timed search work, 15 FPS about 74%, and 20 FPS about 91%. Eliminating every timed search in this model leaves a ceiling near 24.3 FPS. These are counterfactuals based on mean frame time, with no allowance for scheduler, cache, or battle-state changes. Treat 10 FPS as a first milestone and 15 FPS as a stretch target for this window.

## Where changes fit

[VERIFIED] Source inspected in the recording build, `build/t089-alpha-source`.

| Existing behavior | Implication for a prototype |
|---|---|
| `AIUpdateInterface::requestPath/requestAttackPath/requestApproachPath/requestSafePath` already defer very quick repeats. `Pathfinder::queueForPath` already suppresses duplicate object IDs within the pending FIFO. The unit can update its requested destination before the pending entry runs. | Measure repeat *executions* across ticks and distinguish fresh orders, target drift, result-driven retries and collision-driven retries. A second duplicate-ID filter would miss the opportunity. An indexed FIFO membership check is worthwhile only if the linear scan is independently measurable. |
| `AIUpdateInterface::computePath` can patch a blocked path and fall back to `findClosestPath`. `computeAttackPath` can search again to unstack a unit and request that allies move. Attack search tests candidate firing positions with the weapon and current target. | Classify repair and fallback separately from ordinary movement. Cache coarse approach data before considering any reuse of weapon-specific results. |
| `Pathfinder::findPath` runs a cheap reachability gate, then uses a hierarchical search to mark passable regions before fine-grid search. `AIGroup` already has a shared ground path. | Try retaining work at the existing hierarchy or group-routing seam. Measure the hierarchical and fine-search costs separately. |
| `processPathfindQueue` checks the 5,000-cell allocation threshold before dispatching each whole queued job, so the final job can overshoot. `AIGroup` and `AIUpdateInterface::privateMoveAwayFromUnit` also have direct search calls. | Merely lowering the FIFO limit could add wait time and leave direct work untouched. Measure queue and direct traffic separately before designing a budget. |
| The stable heap is already the singleplayer default. It reduced pathfinding time 12.9% in the controlled congested fixture and had no useful overall gain in the lighter fixture. | Use Heap as the baseline. Further priority-queue tuning depends on evidence of queue operations dominating a measured search class. |

[VERIFIED] Source anchors are `Core/GameEngine/Source/GameLogic/AI/AIPathfind.cpp` (`queueForPath`, `processPathfindQueue`, `findPath`), `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/AIUpdate.cpp` (request, compute and move-away methods), and `GeneralsMD/Code/GameEngine/Source/GameLogic/AI/AIGroup.cpp`. See [EXP-027](../experiments/EXP-027-stable-pathfinding-heap.md) and [ADR-0016](../decisions/ADR-0016-default-pathfinding-heap.md) for the heap.

## Ranked experiments

### 1. Keep useful work and reduce repeat searches

[INFERRED] If unchanged-goal retries dominate, keep a route that is still locally usable while deferring low-priority retries triggered by temporary blockers. Key the decision by unit, order generation, target or snapped goal, movement profile and failure reason. Wake a deferred request immediately on a fresh order, a meaningful target change, a changed route or a relevant topology change. Start with a deterministic maximum retry delay and a stable per-unit phase to avoid synchronized wakeups. Give a unit credit for actual movement, so repeated failure cannot prevent eventual replanning.

[INFERRED] A separate, lower-risk negative gate is available for requests with *proven* static disconnection. Validate that the connectivity model includes every valid movement layer and special transition. Invalidate on navigation changes. Keep temporary crowd blockage, search limits and partial results on the ordinary retry path. Distinguish missed firing opportunities and time to first movement from average FPS in acceptance.

### 2. Share coarse routes and let units finish locally

[INFERRED] If many units ask for similar long routes, first run a shadow cache keyed by start region, destination region or portal, movement capabilities and a conservative navigation revision. Record candidate hits, cost-weighted coverage and the cost of validating them while continuing to use the original results. For the first real prototype, reuse only a coarse region or portal corridor. Use the fine solver for joining the corridor, narrow passages, transient occupancy, formation slots and final weapon positions. Seed with ground-AI group moves. Fall back to the current solver for incompatible footprints, movement layers, ignored obstacles, or rejected corridors.

[INFERRED] Start with whole-topology invalidation for correctness. Introduce per-region invalidation after measuring how frequently construction and destruction invalidate useful entries. Preserve whether the corridor is directional and how portals are traversed. Track both route quality and crowd throughput so a shared corridor does not send every compatible group through the same saturated choke.

[SOURCED] Botea, Müller and Schaeffer cache cluster crossing distances in HPA*. This supports reuse at an existing coarse layer. Emerson describes shared portal flow fields in *Supreme Commander 2*. A later experiment could build short-lived reverse distance fields for heavily reused sectors, such as repeated approaches to a choke, if a corridor cache shows many compatible queries and fine-grid search still dominates. Test a single movement class first. [HPA* paper](https://webdocs.cs.ualberta.ca/~jonathan/PREVIOUS/Grad/Papers/jogd.pdf) · [Emerson's flow-field chapter](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf)

### 3. Bound the remaining bursts

[INFERRED] If one or more jobs still monopolize a simulation tick, start with deterministic admission control for deferrable, unchanged-goal AI retries. Include aging and retain service for new orders. Measure queue wait, backlog and completed work so a faster frame does not conceal delayed movement. Only then test resumable expansion budgets on one expensive request class. In-progress search needs private frontier state and a defined restart rule for stale navigation data. Use simulation work units for scheduling and wall time for measurement.

[INFERRED] Parallelize only isolated coarse planning or read-only navigation snapshots once reuse and scheduling are understood. Current shared search lists, obstacle overrides and mutable pathing state make concurrent calls to the legacy solver risky. A worker design needs revision checks, stable commit order and deterministic behavior when a result is unavailable. Incremental search such as D* Lite is a later option for repeatedly replanned fixed objectives with sparse changes. Standard Jump Point Search earns a trial only on a proven uniform-cost grid subset. [D* Lite paper](https://aaai.org/Papers/AAAI/2002/AAAI02-072.pdf) · [Original JPS paper](https://users.cecs.anu.edu.au/~dharabor/data/papers/harabor-grastien-aaai11.pdf)

## First capture and acceptance

1. [INFERRED] Instrument only the known slow slice plus a nearby control slice. Record parent order or request ID, player/AI, originating call site, queued/direct status, reason, goal or target, movement class, queue depth and age, navigation revision, outcome (exact, partial, blocked, exhausted, invalidated), search time and expansions. Attribute nested operations once in totals, while preserving their breakdown. Record path/route fingerprints and a progress flag for recently replanning units. Use counters or batched output and compare lightweight instrumentation against an uninstrumented timing pass.
2. [INFERRED] Report cost share by reason, time and number of retries for unchanged goals, and cost covered by conservative shadow-cache hits. A result dominated by blocked retries should prioritize experiment 1. Shared long-distance work should prioritize experiment 2. Isolated large bursts should prioritize experiment 3 after checking that steady-state throughput is adequate.
3. [INFERRED] Compare individual changes, then combine the winners. Use alternating 1080p runs on frames 16979–17278 for behavior-preserving work. Check order/path hashes, fallback selection and game CRCs, including queue service timing. For changes expected to alter movement, run paired fresh skirmishes with identical seeds and scripted commands, and compare clock-aligned windows together with unit counts and completed orders. Record mean, p95 and p99 frame time, tick time, search time, p95 order-to-movement delay, time stuck, route completion, failed attacks and queue age. Cover a blocked and then reopened choke, bridges or layered movement, changing targets, and new human commands during a large AI wave.
4. [INFERRED] Favor a candidate only when the timing gain exceeds run variation and workload and movement measures support it. Keep behavior-changing prototypes scoped to diagnostic singleplayer builds. Verify save/load and replay boundaries independently before proposing any broader use.
