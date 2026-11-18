# EXP-027: Stable pathfinding heap on registered movement workloads

- **Date:** 2026-11-17
- **Author/agent:** Codex
- **Task:** T-022
- **Status:** Complete
- **Decision:** [ADR-0012](../decisions/ADR-0012-stable-heap-experimental-singleplayer.md)

## Hypothesis and baseline correction

[VERIFIED] EXP-025's first fixture did not call onBuildComplete/addObjectToPathfindMap for its power-plant blockers (ISSUE-0055). Those traces remain reproducibility evidence for that earlier fixture; they cannot establish congestion behavior. Corrected fixture registers buildings, reserves adjusted unit goals, validates all 200 starts and checks a 40-world-unit opening between actual building footprints. All six corrected 30-second captures pass these checks. Open-list maxOpen is median 10 / p95 94-95 / max 246 without blockers; median 16-18 / p95 184-205 / max 359 with five blockers. Every observed request selects the retail-compatible branch.

[UNKNOWN] A stable indexed heap may reduce sorted-insertion cost in the congested fixture while preserving exact queue semantics. Existing free-list allocation does not justify a pool rewrite.

## Method

[VERIFIED] Map northamerica; eight groups of 25 mobile units; seed 1; move interval 90 logic frames; four phases (opposite side, choke opening, building-center objective, moving-unit objective). Six corrected list baseline captures (three open, three blocked) log real insert/remove/head operations; their 1280x720 resolution predates the user's native-resolution instruction. Common-frame prefixes match across all three repetitions: 17,433 open requests through frame 2,062 and 5,647 blocked requests through frame 922. Timing with operation logging is excluded from engine performance evidence.

[VERIFIED] Offline recorded-operation replay verifies observed heads and sorted cleanup using both a proxy and the actual production heap header. Corrected blocked/open traces contain 8,552,378 / 3,355,149 events. Offline ratios approximately 0.50 / 0.86 justified integrating an opt-in candidate; they are not in-game gains. Earlier unregistered-fixture offline regressions are superseded for congestion analysis.

[VERIFIED] Native timing uses the same measured executable SHA256 6A6094426AAB5D94E87B9DC6D2AF5726081CE502B2C2B3F52223275F3CF9220C, 1920x1080, 20 seconds, no operation logging, explicit experimental singleplayer, request/frame logs and game CRC every 90 logic frames. Three Heap-then-List pairs use the common logic interval 90-855 (4,951 requests and nine CRC samples per run). All command, request/route/expansion, per-frame work and sampled CRC comparisons match. Pair order is the same in all three, which limits control for temporal drift; no compilation overlaps these measurements. User reported heavy apps closed.

Reproduce a single run with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/benchmark-pathfinding.ps1 -Width 1920 -Height 1080 -DurationSeconds 20 -Runs 1 -BlockerCounts 5 -QueueMode Heap -ArtifactDir artifacts/<fresh-run>` (announce first). Repeat with List. Analyze using `python tools/compare-pathfinding.py <list-run> <heap-run> --through-frame 855 --output <comparison.json>`; pass each parent artifact folder containing its blockers-5-run-1 directory.

## Measurements

[VERIFIED] Sum of matched-frame timers in milliseconds, not FPS:

| Pair | List pathfinding | Heap pathfinding | List update | Heap update |
|---|---:|---:|---:|---:|
| 1 | 6,352.74 | 5,761.98 | 7,955.90 | 7,561.58 |
| 2 | 6,358.60 | 5,481.87 | 8,000.20 | 7,115.18 |
| 3 | 6,445.40 | 5,442.39 | 8,098.13 | 7,087.88 |

[VERIFIED] Aggregate Heap/List = 0.8710 pathfinding (12.9% less), 0.9048 whole update (9.5% less). Every heap result is below the list range. Whole-update timing includes command issuance and ends before optional CRC computation; instrumentation is identical on both sides. This does not measure overall rendered FPS.

[VERIFIED] A native no-blocker pair through frame 1,420 matches 10,678 requests and 15 CRC samples. Heap/List = 1.0406 pathfinding and 0.9980 update: no useful overall gain in this lighter fixture.

## Correctness and integration

[VERIFIED] `python tools/test-pathfinding-heap.py` compiles actual extracted insertion/removal/cleanup methods with the actual heap and mode-guard headers, enables assertions in Release, and passes 10 retail/fixed queue cases and 13 mode/token guards. Cases cover ties, seed insertion, arbitrary removal/reinsertion, sorted cleanup and over 5,000 open cells. Production-header replay independently verifies heads and cleanup. `tools/test-optimization-fixes.ps1 -ArtifactDir artifacts/2026-11-17-queue-replay/launcher-tests` passes 62 mocked launch/staging/environment assertions, including rejecting Heap without explicit mode and defaulting to List. No game is launched by that suite. Build-engine-heap.log records the successful full engine build.

## Result and limitations

[VERIFIED] Retain Heap as an experimental congested-singleplayer option, default List. No cost/heuristic/search-cap/pool-layout change and no network/replay certification. Local deterministic fixture evidence meets the scoped T-022 acceptance criteria; no broader workload or universal speedup claim. Long-session and broad game coverage remain future work.

## Artifacts

`artifacts/2026-11-17-queue-replay/manifest.md` identifies raw CSVs, operation binaries, comparisons, build/test logs and the preserved measured executable. EXP-025 retains the earlier workload history; this report supersedes its pending algorithm decision.

## Default-on follow-up (2026-11-17)

[VERIFIED] The heap is now the singleplayer default (ADR-0016); network and replay still fall back to List through `allowed()`. `ZH_PF_HEAP=0` restores List. In-game runs with the variable absent record `# queue=heap`, and with `ZH_PF_HEAP=0` record `# queue=list` (`artifacts/2026-11-17-heap-default`). The measured parity and gain above are unchanged.
