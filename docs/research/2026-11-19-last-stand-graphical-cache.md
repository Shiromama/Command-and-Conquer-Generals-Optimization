# Last Stand group pathfinding at 1080p

- Date: 2026-11-19
- Task: T-111
- Baseline: [Last Stand pathfinding census](2026-11-19-last-stand-path-census.md)
- Evidence: [capture manifest](../../artifacts/2026-11-19-last-stand-graphical-cache/manifest.md)

## Matched replay comparison

[VERIFIED] Formation ground searches were the largest measured cost in this run. The engine
repeatedly checked whether a formation's footprint would fit while exploring alternative routes.
The cache reuses an identical clearance answer during one group search and starts fresh at the next
search. The original solver still selects each route.

| 300 rendered frames, 16979–17278 | Cache off | Cache on |
|---|---:|---:|
| FPS, from mean frame time | 10.05 | 14.98 |
| Mean frame time | 99.47 ms | 66.77 ms |
| Median frame time | 100.93 ms | 64.92 ms |
| p95 frame time | 133.48 ms | 92.44 ms |
| p99 frame time | 150.88 ms | 103.40 ms |
| Mean logic time | 90.85 ms | 58.05 ms |
| Mean group search time per tick | 60.87 ms | 28.31 ms |
| Mean draw time | 7.50 ms | 7.58 ms |

[VERIFIED] The two runs used the same executable, replay, graphics settings, resolution and
command line. They skipped rendering during the same first 16,800 ticks and exited at tick 17,402
with the replay sync check active. All 15,242 traced path searches matched after excluding elapsed
time, including results, expansions, route fingerprints and order. The per-frame group fingerprints
matched as well. The wider 460-frame comparison yielded 10.32 to 15.14 FPS. These results are from
one matched pair. The earlier [7.16 FPS capture](2026-11-19-last-stand-slowdown.md) used
a separate run and is context for choosing the window.

## Integration

[VERIFIED] The bounded table uses cell coordinates, layer, diameter and crusher policy as its full
key. Generation tags limit reuse to the current search. Reset, pathfinder recovery and re-entry
disable the active memo. The production hook enables it in local singleplayer and skirmish and
leaves the regular path in effect for the shell, multiplayer and replay viewing. The graphics
pipeline has no edits in this change. The diagnostic replay explicitly exercises the memo with sync
checking active.

[VERIFIED] The focused MSVC fixture covers full-key matching, hash collisions, changing
occupancy between searches, recovery, re-entry and disabled mode. The cumulative patch was checked
against both the modified vendor tree and a clean vendor index.

[VERIFIED] A third graphical run used the exact retained cache implementation with a diagnostic
replay opt-in. It reached frame 17,402 with sync checks active at 1920×1080 and matched all 15,242
search records and the group fingerprints. The 300-frame window measured 14.34 FPS and p95
97.83 ms. The Release build competed for CPU during part of this run's warmup, and this is a
different executable. Use the same-binary comparison for the controlled effect size.

[VERIFIED] `python tools/prepare-alpha-engine.py --output build/t111-alpha-source` prepared the
isolated release source, with 94 diagnostic reads disabled. The configured Visual Studio Win32
Release target `z_generals` built with exit code 0 and zero errors. The local executable at
`build/t111-alpha-release/GeneralsMD/Release/generalszh.exe` has SHA-256
`1B5A809CE27EEA3B56FD6D4F30236508A577A1B34EA11ED2A15EB9ABFC71962B`.
Candidate 17 remains the published pre-release.

[VERIFIED] The local Release candidate was launched at 1920×1080 from the isolated ShockWave copy.
The USA Solo Play mission loaded and ran with live effects and an advancing game clock.
The mission wrote the shared campaign difficulty preference. The original options were restored and
verified by SHA-256. The last replay and installed ShockWave executable hashes matched their
pre-test values. See [ISSUE-0115](../issues/ISSUE-0115-solo-smoke-options-rewrite.md).

[UNKNOWN] The gain on other maps and hardware has not been measured. Standalone replay compatibility
remains tracked under [ISSUE-0108](../issues/ISSUE-0108-last-stand-replay-sync.md).
