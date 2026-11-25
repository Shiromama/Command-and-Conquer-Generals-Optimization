# ADR-0027: Keep the group kernel synchronous; gate a deferred ordinary worker on prefetch and snapshot cost

- **Status:** Accepted (scope decision)
- **Date:** 2026-11-23
- **Deciders:** Engine optimization lead
- **Related:** T-127, T-112, [resource profile](../research/2026-11-22-cpu-gpu-resource-profile.md), [T-122 overlap record](../research/2026-11-22-cpu-gpu-resource-profile.md#path-queueclient-overlap-rejected)

## Context

| Evidence | Decision it supports |
|---|---|
| [VERIFIED] The staged width-6 group kernel commit measures heavy 16,978-17,402 **43.98 ms (22.7 FPS)** and whole **31.92 ms (31.3 FPS)**, path 16,399 usec, `l_ai` 16.51; a repeat produced identical CRCs/commands with path 16,378 usec. | The group path commit is the correct synchronous optimization; keep it. |
| [VERIFIED] Heavy census: `internalFindPath` 6.25, `findGroundPath` 3.74 (90 serial fallbacks), `findClosestPath` 3.59, `findAttackPath` 2.37, hierarchy/move-away 0.78 ms/frame. | A worker must cover 12.2 ms of ordinary/closest/attack work, not just one search kind. |
| [VERIFIED] Exact `(object, from, to)` repeats exist but their median gaps are 20 (`internalFindPath`) and 45 (`findClosestPath`) frames; repeats within 2 frames are zero and within 5 frames save ~0.03 ms/frame. Same-frame destination sharing is negligible. | Request-level caching and one-frame deferred commit cannot recover the remaining work; the AI does not re-ask soon enough. |
| [VERIFIED] The earlier path/client overlap added a one-frame delay: 12,600 improved to 34.20 ms, but the heavy window regressed to **53.91 vs 52.29 ms** and commands changed 1,039 -> 2,599. | A one-frame deferred path is not behavior- or performance-safe for the heavy window. |
| [VERIFIED] The frozen route shadow's snapshot path costs **1.138 ms/tick** and covered **0.626 ms/tick** of original ordinary work; only 11/298 early candidates validated. | A worker around the current snapshot cannot pay for itself; the snapshot/coverage is the first blocker. |
| [VERIFIED] Committing the ordinary kernel route changed the match (ended ~frame 6,600); the AI-only subset preserved 17,402 but regressed to **51.72 ms / 19.3 FPS** with `zone_mismatch` 525 and 671 group misses. | The ordinary solver's routes feed group re-pathing; replacing it without parity/behavior work is not safe. |
| [VERIFIED] Relaxing the group zone validation to the serial clip rule ended the match at ~frame 15,853. | Even committing more group routes can flip the match; the strict validation is behavior protection. |

## Decision

Keep the width-6 group kernel synchronous and committed, with strict per-cell validation and serial fallback. Do **not** ship a deferred ordinary-path worker in the current engine. A worker is authorized only after a cheaper frozen input and a request-prefetch/ordered-commit design meet the acceptance criteria below.

The required worker design:

1. **Cover the measured kinds.** Submit normal, closest and attack ground queries; the group kernel already covers group routes.
2. **Freeze cheaper than the work.** A partial-region snapshot or double-buffered map with incremental occupancy pages must cost < 0.5 ms/tick at the heavy window; the current whole-page freeze is 1.138 ms/tick.
3. **Prefetch or same-frame queue.** The AI's requests are 20-45 frames apart, so a one-frame deferred result is stale. Either solve the queue's current requests on a worker before the main thread reaches them, or prefetch at command issue. A one-frame delay is rejected by the overlap measurement.
4. **Ordered, validated commit.** Apply results in request order; validate every route cell (clear, unpinched, serial zone rule) and fall back to the serial solver on stale/snapshot-mismatch/unsupported.
5. **Behavior gate.** The replay must reach `frame=17402 sync=ok` with a command mix no worse than the group build (`none` 686, `search_failed` 84) before any FPS claim.

## Consequences

### Positive

- The staged build keeps the verified 43.98 ms / 31.92 ms result and the 31.3 FPS whole-run mean.
- The remaining 30 FPS heavy target is stated as an architecture problem, not an unexplained regression.

### Negative / risks

- The heavy window remains 22.7 FPS; the target is unmet.
- A future worker touches the AI queue, snapshot and commit path; it is a multi-session project.
- The whole-run mean already exceeds 30 FPS; the heavy 425-frame window is the remaining outlier.

### Follow-ups

- Prototype a **partial-region freeze** (query bounding box + margin) or a double-buffered map and measure its cost/coverage before threading.
- Prototype a **same-frame queue worker** that prepares the current queue requests (not one frame later); the group kernel's `Workspace` is the solver.
- If the worker cannot meet criteria 2-5, treat the heavy window as a scenario/AI-burst limit and keep the whole-run result.
