# Last Stand group path cache prototype

- Date: 2026-11-19
- Task: T-110
- Baseline: [T-109 search census](2026-11-19-last-stand-path-census.md)
- Evidence: [capture manifest](../../artifacts/2026-11-19-last-stand-group-cache/manifest.md)
- Source: [cumulative diagnostic patch](../../engine/patches/T-110-last-stand-group-cache-probe.patch), against the prepared candidate 14 recording source

## Result

[VERIFIED] Caching a formation's repeated footprint clearance checks inside each group search cut the average search time in the slow window from **8.258 to 3.907 ms**, a **52.7% reduction** in this headless experiment. Cache hits covered 68.50% of clearance lookups. The solver still ran its original hierarchy, search order, path selection and cleanup.

| Logic frames | Control search mean | Memoized search mean | Control p95 | Memoized p95 |
|---|---:|---:|---:|---:|
| 15000–15299 | 7.167 ms | 3.191 ms | 21.383 ms | 10.436 ms |
| 16978–17277, the recorded 7 FPS window | 8.258 ms | 3.907 ms | 25.794 ms | 12.601 ms |

[VERIFIED] Each adjacent ordinal pair was assigned one control and one memoized search with deterministic rotation of pair order. The slow window contained 1,093 control and 1,092 memoized searches. A secondary check stratified by exact directional query, observed navigation revision, returned-path fingerprint and expansion count. The slow-window strata present in both modes had 394 weighted observations per mode and recorded 1.075 to 0.486 ms (54.8% reduction). This cross-check describes the recurring-query subset. The main table covers the entire window.

[VERIFIED] The across-tick whole-route guard had **zero eligible hits**. In the slow window, 778 queries with identical endpoint bits, route policy and observed navigation revision returned the same full-path fingerprint within five ticks. Every one of those pairs had a different observed global fixed-occupancy stamp. This stamp watches fixed occupant changes at the position and goal setters. It is a coarse rejection signal and does not establish every dependency a finished-route cache would need. The shadow comparison never returned an earlier path to the game.

## What changed in the probe

[VERIFIED] `Pathfinder::clearCellForDiameter` is called repeatedly as the group solver evaluates cells. It checks terrain and fixed unit occupancy across the formation's footprint. The prototype memoizes the original return value by cell, layer, requested width and crusher policy. It uses bounded storage and a fresh generation for each search. It bypasses the memo after `forceCleanCells` recovery. No cached clearance survives the end of a group search. There is no render-side code in the cache change.

[INFERRED] Use the per-search clearance memo as the first candidate for an all-on graphical A/B. Further across-tick work can test a local occupancy dependency guard if the remaining bottleneck justifies it. The global stamp experiment gives no evidence that the coarse whole-route guard is useful on this workload.

## Verification

[VERIFIED] The Win32 Release rebuild completed with zero errors. The bounded headless replay, using the recorded skirmish heap and guard settings, exited 0 at frame **17,402** with sync checking active. The capture contains the T-107 slow window from logic frames 16978–17277 inclusive. The trace comparer matched **all 80,049 search records** against T-109 after excluding clock readings. This includes route fingerprints, expansions, results and call ordering. In the first 30 captured ticks, the probe also recomputed **7,291,976 memo hits** and found zero disagreements.

[VERIFIED] The cumulative patch applied to copies of the candidate 14 source files and reconstructed all 13 built files after whitespace normalization. The T-110 incremental delta also reconstructed its four files on a T-109 copy. The shipped test executable retained SHA-256 `76099735FEDB1331E88700C257FC7A3A572518DADCCD24C7FC9E9FC2C5BEFA17`.

[VERIFIED] The recorded timings come from one headless mixed-mode run. They measure native group-search duration, excluding the probe's input setup and CSV writes around that duration. Rendered FPS, repeated runs, alternate maps and release validation remain open. The executable used for this study is an isolated diagnostic build.
