# EXP-025: Deterministic moving-army pathfinding workload

- **Date:** 2026-11-17
- **Author/agent:** Codex
- **Task:** T-022
- **Status:** Running
- **Decision:** [ADR-0011](../decisions/ADR-0011-measure-pathfinding-and-gate-shadow-map.md)

## Hypothesis

[UNKNOWN] The open list is large enough and costly enough to justify an algorithm change without affecting paths or retail compatibility.

## Baseline and method

[VERIFIED] Added peer-search telemetry and a logic-frame command harness. No search algorithm, cap, heuristic, cost, cell layout, allocation pool or CRC implementation changed. The workload requires explicit experimental singleplayer and excludes network/replay. The runner isolates/restores all ZH_ environment variables and rejects invalid spawns.

Command: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/benchmark-pathfinding.ps1 -ArtifactDir artifacts/2026-11-17-pathfinding/baseline-passable -DurationSeconds 150 -Runs 3`.

Default workload: 8 groups of 25 Crusaders; seed 1; orders every 90 logic frames; opposite-side, convergence, structure-footprint, moving-unit targets. Three runs each with zero/five power-plant blockers. Northamerica terrain bounds center; mobile positions adjusted onto passable terrain with deterministic nearby retries. Windowed 1280x720, uncapped, broadphase/filter off. No options file writes.

The convergence target is not yet a certified map choke. With no blockers, phase 2 is another center target, not an unreachable target. With blockers it lies inside the middle building; the engine may legitimately adjust the goal.

## Measurements

[VERIFIED] Fully passable smoke: 200/200 units, five blockers, zero off-map coordinates. First two no-blocker repetitions have identical prefixes over 28,000 commands and 130,145 requests (all columns except usec), including path and expansion fingerprints.

[UNKNOWN] Six-run summary pending. The batch overlaps initial prototype compilations, so timing is exploratory, not clean performance certification. Queue sizes and exact deterministic trace comparisons remain useful. No speedup will be claimed from these timings.

## Instrumentation limits

[VERIFIED] push/removes count insertion/removal operations, including decrease-key reinsertion; expansions count actual head selections in peer search loops. maxOpen tracks live queue length and includes the retail seed inserted via reset. Cleanup is not counted as search pops. fallback=1 denotes the original retail-compatible branch, not the fixed branch. Request timing excludes CSV writing/fingerprint iteration but includes counter overhead. Fingerprints cover float bit patterns and layer for every returned node.

[VERIFIED] The first baseline frame CSV has aggregate request time but no whole-update timer. The legacy logic-phase logger excludes harness command issuance, so PF/phase-sum is not whole-update share. A whole-update QPC denominator is being added for subsequent runs. Full expansion sequence sampling is not implemented; hashes identify a first divergent request, not a first divergent cell.

## Result and artifacts

[UNKNOWN] Optimization decision pending six-run analysis and whole-update attribution. No pathfinder rewrite retained.

Raw evidence, failures and build identity: `artifacts/2026-11-17-pathfinding/manifest.md`. Analyzer: [analyze-pathfinding.py](../../tools/analyze-pathfinding.py).

## Six-run result and whole-update follow-up

[VERIFIED] Six 150-second runs completed, 738,098 requests total. Four pairwise prefix comparisons show no differing command/request columns except usec: no-blocker through logic frame 11,898 (122,500 requests per comparison), blockers through frame 11,028 (111,647 requests per comparison). Every run validates all 200 mobile spawns. Peak queue per request: median 8, p95 85–86, absolute max 275. 24.79% of steady requests exceed 32 entries. Every recorded request selects the original retail-compatible branch (fallback=1). This does not justify modifying that branch without an exact-order prototype and separate differential evidence.

[VERIFIED] Follow-up final build adds update_usec around the entire update, including harness command issuance. Two 30-second runs show PF/whole-update ratios 15.61% without blockers and 15.56% with blockers; mean update 3.094/3.146 ms. Zero-unit 30-second control records 10,731 steady updates, zero path requests and mean update 0.213 ms. These are exploratory instrumented costs, not a speedup or a clean A/B.

[VERIFIED] User stated concurrent PC tasks may affect test data and requested notice before game launches. Future launches must be announced in chat; coordinate clean performance comparisons separately. Local compiled-source work overlapped this batch as already noted. Trace identity and queue sizes are useful despite background timing load.

Next: benchmark a stable-tie queue prototype on recorded real operations, retaining original retail logic until exact differential verification and a measured benefit. T-022 remains In Progress.

## Registered-fixture and native-resolution follow-up

[VERIFIED] ISSUE-0055 corrects missing blocker navigation registration. Six corrected baseline captures and native List/Heap comparisons are reported in [EXP-027](EXP-027-stable-pathfinding-heap.md). Historical numbers above describe the earlier fixture and are not final native performance evidence. A stable heap is retained only by explicit experimental-singleplayer selection (ADR-0012); List remains normal.
