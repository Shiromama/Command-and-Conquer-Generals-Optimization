# Last Stand slowdown attribution

- Date: 2026-11-19
- Task: T-107
- Workload: the user's patched ShockWave 1.201 skirmish on Last Stand
- Evidence inventory: [T-025 replay artifacts](../../artifacts/2026-11-19-last-stand-replay/manifest.md)
- Replay compatibility: [ISSUE-0107](../issues/ISSUE-0107-stress-replay-map-path.md), [ISSUE-0108](../issues/ISSUE-0108-last-stand-replay-sync.md)

## Finding

[VERIFIED] CPU pathfinding was the main cost in the reproduced ~7 FPS slowdown. A contiguous 300-frame window around 9:26–9:36 on the game clock took 41.90 seconds to render, or 7.16 FPS. Path searches used 98.45 ms of the 139.66 ms mean frame time (70.5%). Drawing used 11.50 ms. Logic was the largest top-level phase on all 300 frames.

| 300-frame window | Mean cost or count |
|---|---:|
| Frame time | 139.66 ms |
| All simulation logic | 125.81 ms |
| Path searches, included in simulation logic | 98.45 ms |
| Other simulation work | 27.36 ms |
| Draw phase | 11.50 ms |
| Path searches per simulation tick | 21.46 |
| Recorded cell expansions per simulation tick | 37,204 |

## Replay and controls

[VERIFIED] The match records one human against seven Hard armies, 50,000 starting cash, and 52,902 logic frames at a nominal 30 ticks per second. The patched executable recorded in the replay loads the map after the user-data path repair. Its strict playback reaches 2:30 with the checksum-matching archived ShockWave scripts.

[VERIFIED] Built a separate diagnostic executable from the recording build's source. It can time frame phases and individual path searches. For this replay, two opt-in probes use the recording build's skirmish pathfinding queue and guard-range policies during replay. The strict headless run with both probes advanced to frame 10,851 without bypassing sync checks. The harness stopped at that checkpoint for the separate graphical run. The installed executable and the recording were preserved.

[VERIFIED] The graphical run uses the same archived scripts and both recorded skirmish policies. It renders at 1920×1080 from frame 9000. The analysis excludes the warmup and the first 30 rendered ticks. Render pacing is uncapped. The phase attribution CSV covers the engine loop, and the path search CSV aligns by the pre-increment logic frame. Path time is included within logic time.

## Headless trace

[VERIFIED] Path search grew from a mean 0.05 ms per tick before two minutes to 23.68 ms at 3:00–4:00 and 28.30 ms at 4:00–5:00. These latter intervals averaged 14,866 and 16,567 recorded search cell expansions per tick. Path searches consumed 78.3% and 76.8% of the total measured simulation tick time, respectively. These timings exclude rendering entirely.

## Graphical observations

[VERIFIED] Around 5:13, the profiled view showed a handful of buildings, trucks and infantry in the human base while the minimap showed large enemy concentrations elsewhere. The on-screen FPS readout was 14. Heavy on-screen geometry was unnecessary for the observed low frame rate.

[VERIFIED] At 9:21, the HUD read 7 FPS. The camera was still on the human base and the larger enemy concentrations were visible on the minimap. Across all 8,969 aligned rendered frames from roughly 5:00 to 10:00, path searches accounted for 64.5% of frame time. In the representative 300-frame window, 271 frames took at least 100 ms and 145 took at least 142.86 ms. The latter averaged 122.11 ms in path searches and 11.45 ms in drawing. Frame pacing averaged 0.36 ms across the full window.

[INFERRED] The visible movement of a few units is a poor proxy for the engine's AI workload. The simulation processes path searches for armies outside the current view. Timing directly implicates search work without establishing which route types, failed requests, or congestion patterns account for most of the expansions.


## Limits

[VERIFIED] These measurements are from an instrumented replay with the recording build's skirmish policies and matching mod scripts. The two policy switches were exercised together. Standard replay playback on the installed build still diverges, and the graphical capture covers the reproduced slowdown through approximately ten minutes of the 29:23 recording.

[UNKNOWN] The proportion of the original live match spent at 7 FPS, the distribution of path requests across individual units, and the runtime overhead of the detailed path trace. The study did not change or benchmark an optimization.

## Verification

[VERIFIED] Run `python analyze-slow-slices.py visual-live-policies-attribution.csv visual-live-policies-path.csv --first 16979 --last 17278` from the artifact directory. It reports all 300 contiguous frames, their phase timings and the slow-frame subsets. `run-profile.ps1`, the diagnostic source diff, the run parameters and the raw CSVs are listed in the artifact manifest.
