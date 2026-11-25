# CPU/GPU resource profile of the 7 FPS Last Stand window

- Date: 2026-11-22
- Task: T-121 (resource utilization investigation)
- Status: measured; single-thread CPU wall confirmed; GPU is waiting, not saturated
- Evidence: [resource profile](../../artifacts/2026-11-22-t120-deploy-fixture/replay-resource-heavy2/),
  [first sample](../../artifacts/2026-11-22-t120-deploy-fixture/replay-resource-profile/),
  [retained 7 FPS attribution](../../artifacts/2026-11-21-t116-group-relax/live-combined-attr.csv)

## Question

The game runs at about 7 FPS in the late Last Stand window, but Task Manager shows low overall
CPU and GPU use. Is the engine failing to use the machine, and where does the frame time go?

## Method

| Item | Value |
|---|---|
| Host CPU | Intel Core i5-10300H, 4 cores / 8 logical, 2.50 GHz |
| Power plan | High performance |
| RAM | 25 GB visible, 11.8 GB free during the run |
| GPU | NVIDIA GTX 1650 Ti and Intel UHD; the game used the Intel path (GTX 0% / 0 MiB) |
| Engine | `0D3A2819...` playtest build |
| Workload | New-mode Last Stand replay, `-ignoreReplaySyncErrors`, 1920x1080, uncapped |
| Sampling | `tools/profile-game-resources.ps1`: process/per-thread CPU, total/per-core CPU, GPU Engine counters, nvidia-smi, memory |
| Retained slow window | T-116 `live-combined-attr.csv` / `live-combined-pf-frame.csv`, frames 16,978-17,277 |

## Measurements

### Live process sample (frame ~8,000, still ~70 FPS)

[VERIFIED] Across 20 one-second samples the process consumed **100-105% of one logical core**
(100% = one core in this measurement). The same thread (ID `211884`) held **98-104%**; every
other engine thread stayed below 2%. Total system CPU was **25-48%**, and the maximum single
logical core was **37-54%** because the busy thread migrates/HT shares.

[VERIFIED] GPU Engine utilization for the process fell from the loading burst (60-76%) to
**9-18%** in steady state. `nvidia-smi` reported **0% GPU, 0 MiB** on the GTX 1650 Ti, so the
frame was on the Intel UHD path. There is no `d3d8.dll` wrapper in `game/last-stand-replay`.

[VERIFIED] Working set was **350-400 MB**, with 11.8 GB free. There is no memory pressure,
paging, or GPU-memory pressure.

### The actual 7.5 FPS window

[VERIFIED] The retained 300-frame window (frames 16,978-17,277) has:

| Metric | Value |
|---|---:|
| Frame interval | **133.3 ms** (7.5 FPS) |
| Logic | **120.5 ms** |
| Path search (`ZH_PF_FRAME`) | **97.1 ms** |
| AI (`l_ai`) | **28.0 ms** |
| Draw | **10.6 ms** |
| Client | **12.0 ms** |
| Object updates | **7.0 ms** |
| Partition | **0.8 ms** |
| Path requests / frame | **27.8** |
| Expansions / frame | **33,423** |

[INFERRED] The 133 ms frame is almost entirely the serial logic/path stage. The GPU would need
only the draw/client portion (~10-12 ms), which is consistent with 9-18% GPU utilization during
the slower sample.

## Why Task Manager looks underutilized

[VERIFIED] The engine's main loop is serial:
`GameEngine::execute()` (`GeneralsMD/.../Common/GameEngine.cpp:1156`) calls `update()`
(`:1039`); `update()` runs `TheGameClient->UPDATE()` (`:1090`), then `TheGameLogic->UPDATE()`
(`:1115`), then `TheFramePacer->update()` (`:1226`) on the same thread.

[VERIFIED] `GameLogic::update()` (`GeneralsMD/.../GameLogic/System/GameLogic.cpp:3795`) invokes
AI and object updates; `AI::update()` dispatches `Pathfinder::processPathfindQueue()`
(`Core/.../AI/AI.cpp:360`), and `Pathfinder::processPathfindQueue()` (`AIPathfind.cpp:3085`)
runs requests serially on that same thread. `ProcessPathfindQueue()` dispatches each
`ai->doPathfind(this)` in a loop; there is no worker pool or per-request thread.

[VERIFIED] A source search finds only one `CreateThread` in the engine sources, for asynchronous
DNS in `MainMenuUtils.cpp`; the gameplay, pathfinding and draw submission have no worker threads.
The process has 12-16 threads, but only the main thread is busy.

[INFERRED] This is why Task Manager's whole-system CPU percentage is misleading. One fully busy
logical core is 12.5% of an 8-thread CPU; the remaining threads add little, so the total can sit
around 25-48% including the OS. The GPU is idle because the CPU spends 120 ms preparing the frame
before the 10 ms draw. Opening Task Manager's per-logical-processor view, Resource Monitor, or
Process Explorer shows the single hot core.

## External practice check

[SOURCED] RTS pathfinding guidance matches the measured shape: flow fields amortize repeated
goal searches across groups, and the expensive field/portal work is commonly split across
worker threads. The Game AI Pro flow-field chapter explicitly recommends capping grid work per
tick and spreading integration work across threads; the DHPA*/SHPA* paper emphasizes read-only
terrain during search to make searches multithread-friendly.
[HowToRTS flow fields](https://howtorts.github.io/2014/01/04/basic-flow-fields.html) ·
[Game AI Pro ch. 23](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf) ·
[DHPA*/SHPA*](https://cdn.aaai.org/ojs/12397/12397-52-15925-1-2-20201228.pdf) ·
[stack overflow discussion](https://stackoverflow.com/questions/72014167/flowfield-pathfinding-on-large-rts-maps)

[INFERRED] This supports the project's own conclusions: the existing `GroupFieldShadow`/HPA*
model is the right direction, and the worker path must use immutable/read-only search inputs.
It does not support "just use more GPU".

[SOURCED] Zero Hour Enhanced (a large ZH mod) credits "prioritised particle FX" for a substantial
FPS gain: unprioritised particle systems all render at equal weight, so many tiny effects cost full
price. Checked against our source: the engine **already** implements the mechanism --
`ParticlePriorityType` per system, a `Priority =` template INI field, `m_maxParticleCount` with
`removeOldestParticles(excess, priority)`, a field-particle cap, and dynamic-LOD thresholds
(`getMinDynamicParticlePriority` / `getMinDynamicParticleSkipPriority`).
[INFERRED] ZHE's gain is therefore data/settings (priority values, caps, dynamic LOD), not a
missing engine feature. With `DynamicLOD = no` the engine forces the very-high LOD level, so the
priority-based skip is inactive; lowering the cap or enabling dynamic LOD is a settings trade.
Measured cost of **all** particles on the GTX path is ~0.9 ms (queue 0.34 + sorted 0.55), so even a
perfect priority cull cannot close the ~3.5 ms gap.

## What this means for optimization

The user's intuition is correct about underutilization, but the resource to unlock is **the
serial logic thread**, not the GPU:

1. [INFERRED] A GPU upgrade or `d3d8to9` wrapper cannot remove the 97 ms path stage. Prior GTX
   work improved the wrapper pair to 21.93 FPS, but the remaining 12.2 ms frame gap and the
   30 FPS target are CPU-side.
2. [INFERRED] The best structural lever is a deterministic pathfinding worker pool: independent
   searches can run concurrently if inputs are immutable and results are dispatched in queue
   order. Prior modeling put four workers at 26.56-28.33 FPS before overhead; the existing
   native worker attempt was parked because snapshot/validation cost exceeded the covered work.
3. [INFERRED] The next cheapest lever is per-search work: 33k expansions/frame at ~97 ms means
   roughly 2.9 us per expansion. HPA*/flow-field, route reuse with a less conservative guard,
   fewer reopenings, and allocation/locality work all attack the same serial budget.
4. [INFERRED] Decoupling draw submission from logic could overlap the ~10 ms draw with the
   path stage, but it is a smaller, riskier gain than parallelizing or shrinking path work.
5. [INFERRED] `l_ai` is 28 ms inside the 97 ms path window; team/script work and generic updates
   are secondary but worth isolating once path work is reduced.

## Hierarchical-corridor prototype result

[VERIFIED] I implemented an opt-in `ZH_HIER_CORRIDOR` prototype in
`Pathfinder::findGroundPath`: the existing hierarchical route (previously deleted after zone
gating) is dilated into a cell corridor and the fine A* skips cells outside it. The playtest
`0D3A2819...` binary was not changed.

| Run | Median frame | p95 | Path requests/frame | Path usec/frame | Expansions/frame |
|---|---:|---:|---:|---:|---:|
| Baseline | 14.24 ms | 90.13 | 11.36 | 14,524 | 4,290 |
| Corridor radius 8 | 14.10 ms | 92.69 | 10.63 | 14,837 | 4,425 |
| Corridor radius 2 | 14.09 ms | 90.84 | 11.54 | 14,533 | 4,291 |

[VERIFIED] The corridor produced no measurable improvement at the sampled frame ~8,000 window;
radius 2 was effectively identical to baseline. It also produced no `ZH_FORMATION_COMMANDS`
rows. The prototype is **not promoted** and the playtest engine remains `0D3A2819...`. The likely
reason is that the existing hierarchical route is a zone/coarse route, not a width-6 formation
corridor, so it does not narrow the formation A* meaningfully; this is consistent with the
earlier finding that the width-6 field was sparse.

## Width-6 field prototype result

[VERIFIED] I promoted the existing width-aware reverse field and `LiveSearch` repair into an
opt-in `ZH_FIELD_SOLVE` candidate in `findGroundPath`. The field is built for width-6 group
paths, every candidate cell is revalidated against live width/blockers/zone, and A* remains the
fallback. The playtest `0D3A2819...` binary was not changed.

| Window | Baseline interval | Field interval | Baseline path usec | Field path usec | Expansions |
|---|---:|---:|---:|---:|---:|
| Frames 7,000-7,979 | 61.6 ms | 59.8 ms | 44,606 | 43,850 | **12,510.95 both** |
| Frames 10,000-11,800 | n/a | 104.97 ms | n/a | 84,889 | 20,023 |

[VERIFIED] The field-heavy replay reached frame **14,880** before the 900 s timeout, so it did
not reach the 16,978-17,402 window. No `ZH_FORMATION_COMMANDS` rows were produced. The identical
expansion count at frames 7-8k indicates the field candidate was not replacing the normal search
(most requests fell back to A*), so the 3% interval change is not a solver win.

[VERIFIED] The field prototype is **not promoted**; the playtest remains `0D3A2819...`. The next
lever is a true width-6 HPA* cluster/portal prototype or a committed worker that actually skips
the serial search, with a longer heavy-window benchmark.

## Cluster/portal HPA* prototype

[VERIFIED] A true cluster/portal corridor was added as an opt-in candidate: 10x10 ground
clusters, width-6 portals on shared cluster borders, coarse A* over the cluster graph, and the
normal width-6 fine A* restricted to the resulting cluster corridor, with a full-search retry if
the corridor fails. It is not the earlier hierarchical-route corridor.

At the frame ~8,000 sample (not the heavy window yet):

| Metric | Baseline `0D3A` | HPA cluster |
|---|---:|---:|
| Median frame | 14.24 ms | 14.77 ms |
| p95 | 90.13 ms | 90.41 ms |
| Path requests/frame | 11.36 | 11.23 |
| Path usec/frame | 14,524 | 14,274 |
| Expansions/frame | 4,290 | **3,077 (-28.3%)** |
| Formation commands | 0 | 0 |

[VERIFIED] The cached cluster abstraction cut fine-search expansions by 28% at the ~8,000
sample but added enough cluster/portal and corridor overhead to make the median frame slightly
slower there. I then ran the full replay through frame 17,402 on both the unchanged playtest
`0D3A2819...` and the HPA probe (`62D8F2AA...`), with identical logging and no playtest switches.

Heavy window 16,978-17,402 (425 frames, same replay):

| Metric | Baseline `0D3A` | HPA cluster | Delta |
|---|---:|---:|---:|
| Interval mean | **142.84 ms** | **102.08 ms** | **-28.5%** |
| Interval median | 141.65 ms | 105.32 ms | -25.6% |
| Interval p95 | 229.40 ms | 170.44 ms | -25.7% |
| FPS from mean interval | **7.0** | **9.8** | +40% |
| Logic | 128.70 ms | 92.78 ms | -27.9% |
| Path usec | 104,601 | 74,531 | -28.7% |
| Expansions | 25,644 | 11,373 | -55.7% |
| Requests/frame | 27.48 | 26.92 | -2.0% |
| `usec_max` mean | 43,243 | 47,873 | +10.7% |

[VERIFIED] HPA was faster on **326 of the 425** paired frames (mean paired delta -40.76 ms).
Full-run phases show where the trade changes:

| Frames | Baseline interval | HPA interval | Delta |
|---|---:|---:|---:|
| 0-4,999 | 16.66 ms | 15.05 ms | -9.7% |
| 5,000-9,999 | 69.91 ms | 63.35 ms | -9.4% |
| 10,000-11,999 | 100.61 ms | **149.15 ms** | **+48.2%** |
| 12,000-15,999 | 116.41 ms | 101.03 ms | -13.2% |
| 16,000-16,977 | 143.85 ms | 93.32 ms | -35.1% |
| 16,978-17,402 | 142.84 ms | 102.08 ms | -28.5% |
| Whole run | 74.76 ms | 70.62 ms | -5.5% |

[VERIFIED] Whole-run path usec is 52,710 baseline vs 53,518 HPA (+1.5%) while counted expansions
fall from 13,111 to 6,923 (-47.2%). The 10-12k phase is a real regression: `usec_max` there is
51,562 us vs 36,851 us baseline. The likely cause is the hard corridor's failure path: it
recursively runs a second full search, and a nested `zhpf::Trace` does not add that retry's
expansions to the frame total, so the expansion ratio overstates the saved work. This is
[INFERRED]; the soft-corridor variant (`ZH_HPA_SOFT`, which pays a per-step penalty instead of
retrying) and its `hpa_retries` frame counter are built (`t120-hpa3-soft.exe`) and running to
confirm it.

[VERIFIED] Command IDs diverge as expected with changed routes: baseline logged 2,427 rows and
HPA 2,015 in the 300-frame command window; only 41 group IDs are shared. Aligning on
`(frame, leader)` gives 102 shared attempts, of which 27 have the same member hash and 61 the
same returned/reason. The replay still reaches the graphical checkpoint with `sync=ok`, so the
candidate is a route-changing singleplayer build, not an exact-route parity build.

## Soft-corridor follow-up (not promoted)

[VERIFIED] To remove the hard corridor's double search on failure, I added `ZH_HPA_SOFT`: an
out-of-corridor step pays a tunable cost (default 20) instead of being pruned, so the search can
escape without a retry. The probe (`build/engines/t120-hpa3-soft.exe`, `2F403D55...`) ran with
`ZH_HPA_CORRIDOR=1 ZH_HPA_SOFT=1`. It logged 5,890 corridor attempts and zero retries in 4,312
frames, then left gameplay at logic frame **9,311**; the attr log continues at ~0.05 ms logic
(shell), and the path log stops, so the run never reached 16,978-17,402.

| Window | Baseline path usec | Hard HPA path usec | Soft HPA path usec |
|---|---:|---:|---:|
| 5,000-6,999 | 34,048 | 28,733 | 45,058 |
| 7,000-9,311 | 60,075 | 55,946 | 64,421 |

[VERIFIED] The soft variant is **not promoted**. It was slower than the hard corridor in the
overlap it did cover and its route divergence ended the recorded session early, so it cannot be
the playtest build. The hard cluster corridor remains the candidate; its 10-12k regression is
documented above rather than hidden by the endgame win.

## Default-on verification and the retry storm

[VERIFIED] The promoted default-on build (`build/engines/t120-hpa4-final.exe`,
`51451674...`) reached `frame=17402 sync=ok` with **no `ZH_HPA_*` environment variables**. Its
command CSV is byte-identical to the hard probe's
(`41696F9A3A02BC7FFC1B3C254A564FA131CD0FB60D3C9B35AAF77673F2CD4E8F`), so the two runs simulated
the same game. Their performance difference (heavy 102.08 vs 110.38 ms; whole run 70.62 vs
80.58 ms) is run-to-run machine drift, not a code difference.

[VERIFIED] The frame log now carries `hpa_attempts`/`hpa_retries`. In frames 10,000-12,591 the
default build averaged **3.7 attempts and 3.45 retries per frame** (93% of corridor searches
failed), 175.54 ms interval and 151,872 usec path vs 109.97 ms / 86,901 usec baseline. The hard
corridor's failure path runs a second full search whose nested trace is not counted in
`expansions_total`, so the 47% expansion drop overstates the saved work. This is the cause of the
10-12k regression, not route divergence.

[VERIFIED] A short per-thread failure memo was added (`ZH_HPA_FAIL_TTL`, default 5 frames): a
failed `(start cell, goal cell)` pair skips HPA on the next frames and runs the normal search
once, instead of paying the corridor plus a full retry. The 12,600-frame probe
(`build/engines/t120-hpa5-memo.exe`, `8D29C1D4...`) reached `sync=ok` and measured:

| Window | Baseline | Hard HPA `hpa4` | Memo `hpa5` |
|---|---:|---:|---:|
| 5,000-9,999 interval | 69.91 ms | 72.00 ms | **66.98 ms** |
| 5,000-9,999 path usec | 51,149 | 51,603 | **46,904** |
| 10,000-12,599 interval | **110.17 ms** | 175.77 ms | **128.33 ms** |
| 10,000-12,599 path usec | **87,074** | 152,083 | **107,644** |
| 10,000-12,599 retries/frame | — | 3.45 | **1.64** |

[VERIFIED] The memo removes most of the double search (retries -52%) and brings 5-10k below
baseline, but 10-12k remains **+16.5%** above baseline because the first failure of each distinct
pair still pays a retry.

[VERIFIED] The full memo run (`hpa6-final`) reached 17,402 but changed the simulation: it logged
2,483 command rows vs 2,015 for the hard build, and the heavy window rose to **180.59 ms**
(68/425 paired wins, 2.37 retries/frame) with an 83.95 ms whole-run mean. The memo is **rejected**:
it did not preserve the workload that the hard corridor wins on. The memo source was reverted.

## Promotion decision

[VERIFIED] The playtest is now the verified default-on hard-corridor build
(`build/engines/t120-hpa4-final.exe`, `51451674...`, staged in `game/last-stand-replay`). It
reached `frame=17402 sync=ok` with no `ZH_HPA_*` environment, and `tools/play-t120.ps1` also sets
`ZH_HPA_CORRIDOR=1` explicitly. The measured effect is:

| Metric | Baseline `0D3A` | HPA hard (best run) | HPA default-on rerun |
|---|---:|---:|---:|
| Heavy 16,978-17,402 | 142.84 ms | **102.08 ms** | 110.38 ms |
| 10,000-12,599 | 110.19 ms | 159.40 ms | 175.80 ms |
| Whole run | 74.76 ms | **70.62 ms** | 80.58 ms |

[VERIFIED] The two hard runs have byte-identical command CSVs, so the 102 vs 110 ms difference is
machine drift, not code. The real unresolved cost is the 10-12k retry storm: 3.3-3.5 of roughly
4 attempts per frame fail and pay a second full search. The next fix is live portal validation
(disable the corridor when its border openings are blocked) or a bounded expanded-corridor
fallback, not a failure memo. This is a route-changing singleplayer build; command IDs diverge
and exact replay parity is not claimed.

[VERIFIED] This build was **superseded** by T-123 (live portal validation) and T-124 (the
repeated-request cache); the playtest is now `8FEC201A...` below, with a 51.59 ms whole-run mean.

## Live portal validation (T-123)

[VERIFIED] The corridor now validates every coarse cluster edge against live width-6 clearance
before entering it: if any required border opening is blocked, it increments `hpa_rejected` and
runs the normal search once. The 12,600-frame probe (`build/engines/t120-hpa7-portal.exe`,
`D4B6B158...`) reached `sync=ok` with **zero retries** in both windows:

| Window | Baseline | Hard HPA | Portal validation |
|---|---:|---:|---:|
| 5,000-9,999 interval | 69.91 ms | 63.35 ms | **62.69 ms** |
| 5,000-9,999 `hpa_attempts` / `rejected` | - | 0.93 / - | 0.01 / **1.50** |
| 10,000-12,599 interval | **110.17 ms** | 159.38 ms | **123.01 ms** |
| 10,000-12,599 `hpa_attempts` / `rejected` | - | ~1.8 / 1.6 | 0.00 / **3.10** |
| 10,000-12,599 retries/frame | - | 1.6-3.5 | **0.00** |

[VERIFIED] Validation eliminates the double search, but in the 10-12k phase it rejects almost
every corridor because live units block the static openings, so the residual +12% over baseline
is validation cost plus a heavier workload, not a retry. The next lever is the repeated-request
cache below.

## Bigger-picture finding: the same group search is repeated every 3-4 frames

[VERIFIED] The `ZH_FORMATION_COMMANDS` logs show that the expensive width-6 searches are not
distinct problems. In the 300-frame command window there are only **85 distinct
`(member_hash, from_cell, to_cell)` keys**, but **2,427 attempts**. 2,340 (96.4%) are exact
repeats, and the gap between repeats is **always 3 or 4 frames** (never 1-2). The leader is
identical for 2,340/2,340 repeats, and each key has exactly one leader. The group object ID is
new each time, which is why group-ID caches and the earlier route-cell guard missed this.

[VERIFIED] The same shape appears in the HPA run: 53 keys, 2,015 attempts, 1,955 repeats (97.0%),
same leader every time. In the memo run: 2,483 attempts, 2,391 repeats.

[INFERRED] A short-TTL cache keyed by the exact request (leader, bit-identical from/to, diameter)
can return a copy of the previous `Path` or failure instead of re-running A*. Because the from
position is bit-identical on a hit, the leader is stationary; when it moves, the key changes and
the cache misses automatically. This is implemented in `findGroupGroundPath` as
`ZH_GROUP_PATH_CACHE_TTL` (default 10 frames, singleplayer-only) with `group_cache_hits/misses`
frame counters.

[VERIFIED] The TTL-5 probe (`build/engines/t120-hpa8-cache.exe`, `3C813EB9...`) reached 12,600
`sync=ok`:

| Window | Baseline | Portal only | Portal + cache |
|---|---:|---:|---:|
| 5,000-9,999 interval | 69.91 ms | 62.69 ms | 63.07 ms |
| 10,000-12,599 interval | **110.17 ms** | 123.01 ms | **113.06 ms** |
| 5,000-12,599 interval | - | - | 80.18 ms |
| 5,000-9,999 path usec | 51,149 | 44,466 | 46,004 |
| 10,000-12,599 path usec | 87,074 | 101,594 | 90,197 |

[VERIFIED] The cache hit rate is 42% at TTL 5 (2.3 hits / 3.14 misses per frame in 10-12.6k), as
expected from a fixed 5-frame window with a 3-4 frame repeat gap. It removes most of the
portal-only regression: 10-12.6k is now **+2.6%** over baseline instead of +11.7%.

[VERIFIED] TTL 10 is the decisive result. The same binary (`3C813EB9...`) ran the full replay to
`frame=17402 sync=ok` with `ZH_GROUP_PATH_CACHE_TTL=10`:

| Window | Baseline | HPA hard | **HPA + cache TTL 10** |
|---|---:|---:|---:|
| 5,000-9,999 | 69.91 ms | 63.35 ms | **50.75 ms** |
| 10,000-12,599 | 110.17 ms | 159.38 ms | **74.23 ms** |
| 12,600-16,977 | 119.02 ms | 86.62 ms | **78.62 ms** |
| 16,978-17,402 | 142.84 ms | 102.08 ms | **97.48 ms** |
| Whole run | 74.76 ms | 70.62 ms | **51.74 ms** |
| Whole-run path usec | 52,710 | 53,518 | **31,358** |

[VERIFIED] Cache hits are 57-62% in the mid-game and 57% in the heavy window (4.18 hits / 3.14
misses per frame); the longer TTL converts more of the 3-4 frame repeats into hits. The whole-run
mean interval falls **30.8%**, and the heavy window goes from 7.0 to **10.3 FPS** (31.8% shorter
frames). This is the largest single win in the task, and it comes from removing repeated identical
requests, not from a faster A*.

[VERIFIED] The promoted default-on build (`build/engines/t120-hpa10-final.exe`, `8FEC201A...`,
staged in `game/last-stand-replay`) reached `frame=17402 sync=ok` with **no `ZH_*` environment**:
whole run **51.59 ms** (logic 42.13, path 30,932 usec), heavy 16,978-17,402 **104.22 ms** (logic
90.0, path 65,732, cache 4.18 hits / 3.14 misses). The heavy window is 6.7 ms slower than the
env-set TTL-10 run (97.48 ms), but the cache counters and command CSV are identical and draw was
12.02 vs 9.37 ms, so that gap is machine drift. Phase means: 5-10k 48.83, 10-12.6k 73.76,
12.6-17k 78.40 ms.

## Census attribution of the remaining path budget

[VERIFIED] `ZH_PATH_CENSUS` on the promoted build (frames 16,978-17,401) logged 11,898 requests
(9,605 outer). Outer cost totals 24.74 s, or **58.2 ms/frame**:

| Kind | Calls | Total usec | Share | Mean | Expansions |
|---|---:|---:|---:|---:|---:|
| `findGroundPath` (group cache misses) | 1,331 | 17,026,031 | **68.8%** | 12,792 | 3,453,045 |
| `internalFindPath` | 1,659 | 3,695,748 | 14.9% | 2,228 | 1,387,062 |
| `findClosestPath` | 915 | 3,496,565 | 14.1% | 3,821 | 2,134,909 |
| `findAttackPath` | 178 | 314,569 | 1.3% | 1,767 | 220,259 |
| `getMoveAwayFromPath` | 3,863 | 153,924 | 0.6% | 40 | 159,384 |
| hierarchy | 1,659 | 52,856 | 0.2% | 32 | 33,891 |

[VERIFIED] The remaining group misses are only **28 unique keys**; a TTL-20 exact-request cache
would hit 67.9% of them and avoid 11.68 s of searches (**27.5 ms/frame**). By contrast,
`findClosestPath` and `internalFindPath` have **0% exact repeats within 20 frames** because the
actor's start cell changes every call (437/915 and 962/1,659 unique keys). A simple request cache
cannot remove them; they need a different approach.

[VERIFIED] `navigationRevision` changes only 5 times across the 425-frame window (3 frames have
more than one value), so adding it to the cache key is nearly free and invalidates exactly at
building/zone events. The census does **not** log which object caused a revision change; the
"Stinger Site" label came from the screenshot/HUD time and is [INFERRED], not proven. The user's
live session showed groups stopped by existing buildings without a new construction, so the
replay and the live match are not the same scenario - but the invalidation mechanism is the same.

[VERIFIED] The promoted build's 128-slot cache was collision-limited: a slot-level replay of the
command log gives 56.2% hits at 128 slots (matching the observed 56.6%), 65.2% at 256, and 70.2%
at 512. The next build uses 512 slots plus the revision key; a TTL-20 run is measuring the
combined effect.

[VERIFIED] The 512-slot + revision + TTL-20 build (`build/engines/t120-hpa12-final.exe`,
`D8357471...`) reached `frame=17402 sync=ok` and is the new playtest:

| Window | Baseline | 128/TTL10 (`8FEC201A`) | **512/rev/TTL20** |
|---|---:|---:|---:|
| 5,000-9,999 | 69.91 ms | 48.83 ms | **41.67 ms** |
| 10,000-12,599 | 110.17 ms | 73.76 ms | **50.16 ms** |
| 12,600-16,977 | 119.02 ms | 78.40 ms | **62.21 ms** |
| 16,978-17,402 | 142.84 ms | 104.22 ms | **67.24 ms** |
| Whole run | 74.76 ms | 51.59 ms | **40.60 ms** |
| Whole-run path usec | 52,710 | 30,932 | **21,672** |

[VERIFIED] The heavy window is **67.24 ms / 14.9 FPS** vs 142.84 ms / 7.0 baseline; whole-run
mean is 40.60 ms (24.6 FPS from per-frame means). Cache hits/misses in the heavy window are
3.53/1.39 per frame (72% hits) vs 4.18/3.14 at 128/TTL10. The construction event is visible as a
revision change at 17,213/17,214; the old build's 17,220 path frame was **252.7 ms**, the new build
is **19.0 ms**, and 17,208 drops from 119.2 to 66.0 ms. The revision key invalidates exactly at
the building/zone change instead of serving stale pre-construction routes.

## T-127 width memo and the blocked-route limit

[VERIFIED] Enabling the per-search width memo for width-6 ground paths (invalidated at search
exit) cut the same requests with identical expansions and cache counters:

| Window | 512/rev/TTL20 | **+ width memo** |
|---|---:|---:|
| 5,000-9,999 | 41.67 ms | **39.54 ms** |
| 10,000-12,599 | 50.16 ms | **45.94 ms** |
| 12,600-16,977 | 62.21 ms | **56.69 ms** |
| 16,978-17,402 | 67.24 ms | **62.89 ms** |
| Whole run | 40.60 ms | **37.60 ms** |
| Whole-run path usec | 21,672 | **18,988** |

[VERIFIED] The census's group misses are **989 successes (15.47 s, 15.6 ms mean)** and only
**342 failures (1.56 s, 4.6 ms mean)**. The replay's remaining cost is therefore mostly successful
long formations, not blocked routes. The user's live observation - groups stopped by existing
buildings - is a different mix: there the repeated failure cost dominates, and a failure-only TTL
or an AI-level give-up/re-target is the right lever. The two are not interchangeable; the cache
and revision key help both, but the replay cannot prove the live blocked-route case.

[VERIFIED] A failure-only 60-frame TTL was tested at 12,600: group misses fell from 0.92 to 0.73
per frame in 10-12.6k, but the interval rose slightly (45.94 -> 47.21 ms; 5-10k 39.54 -> 40.97).
It is **not promoted**: it does not pay for itself and it would delay recovery of the stuck units
the user observed. The width-memo build (`844A319E...`) is the playtest.

## T-128 blocked-route fixture results

[VERIFIED] The existing formation fixture now accepts `ZH_FIXTURE_BLOCKER_AT=leader|mid|goal`
(runner `-BlockerAt`) and places the blocker building at the leader, the leader-goal midpoint, or
the goal. Runs use the Last Stand map, `ChinaCommandCenter` blocker, `ChinaTankBattleMaster`
group, 6 units, frame 600.

| Blocker | `leader_usable` | `alternate_usable` | `last_failure` | `formation_moved` | Reading |
|---|---|---|---|---|---|
| leader | false | true | `zone_mismatch` | true | T-116 bad start; members fallback |
| mid | true | true | `none` | true | engine detours around an open midpoint building |
| goal (radius 8) | false | false | `goal_width` | true | destination inside the building; members fallback |
| goal (radius 24, reverted) | false | false | `none` | **false stacked / true separated** | four units spawned on the exact leader point; separating them moves the group |

[VERIFIED] The mid-route building does **not** stall the group: the path detours and moves. The
goal-blocked case fails at `goal_width`. Widening the goal search to 24 cells turns the failure
into a valid path (`none`).

[VERIFIED] The initial 24-cell `formation_moved=false` was a **fixture artifact**, not a game
bug: four units were spawned on the exact same leader coordinate. The separated-spawn control
(same blocker, distinct positions) moved (`formation_moved=true`, first unit ~150 units from
spawn) with 6/6 paths and a 147-node path whose first node was at the unit's spawn. Once the units
are not stacked, the engine follows the path normally.

[INFERRED] The live "nothing in path but not moving" symptom is therefore not reproduced by this
fixture. The likely live causes remain the T-116 leader/start footprint (`zone_mismatch`, mitigated
by start relax) or a guard/deployed unit pinning a choke. A general unit-vs-building blocker memory
and right-of-way request remains T-128; the engine currently only asks allies at the destination to
move (`moveAlliesAwayFromDestination`) and marks `blockedByAlly`. The 24-cell goal experiment was
env-gated and reverted; the playtest remains `844A319E...`.

[VERIFIED] A choke-wall fixture (8 `ChinaCommandCenter` buildings across the midpoint, distinct
unit spawns) was also bypassed: the command log at frame 600 has `returned=1`, `reason=none`,
6 members, `moving=0` at issue, and after 240 frames `formation_moved=true` with the first unit
~270 units from spawn. On this open map a synthetic wall is routed around. The fixture can now log
formation commands at any frame (`ZH_FORMATION_COMMANDS_ALL`, per-row flush) and place
`leader|mid|goal` blockers, but the live choke cannot be reproduced without map-specific terrain.

[BLOCKED] Implementing the blocker-aware give-up/re-target needs a faithful stuck-group repro.
The remaining input is a **live playtest `ZH_FORMATION_COMMANDS` log** from the user's session:
start `tools/play-t120.ps1 -FormationLog`, let a group stall behind buildings, then share
`artifacts/live-formation-commands.csv` (the playtest build logs frames 16,978-17,277) so the stuck
group's `returned`, `reason`, `moving` and `alt_leader` can be classified. The synthetic fixtures
show only detours and goal-width blocks, not the live stall.

## Playtest-switch replay check (invalid for the heavy window)

[VERIFIED] Running the staged `844A319E...` build with the actual playtest switches
(`ZH_GROUP_START_RELAX=1`, `ZH_DEPLOY_GUARD_HOLD=1`, `ZH_DEPLOYED_AVOID=1`,
`ZH_LONG_RANGE_VISION=1`, `ZH_HPA_CORRIDOR=1`, `ZH_GROUP_PATH_CACHE_TTL=20`) ended the replay at
logic frame **~12,011** on the score screen, short of 16,978. The process then rendered the score
screen uncapped: **121,440 render frames at ~10 ms**, Intel UHD at **99%**, GTX at **0%** - that is
the high GPU usage seen after the run, not pathfinding compute (the path stage is CPU-side). The
game was closed and the playtest exe restored.

[VERIFIED] Because the switches change the replay outcome, the heavy-window comparison is not
possible with this fixed input. The comparable performance measurement remains the no-switch run
(`844A319E`: 62.89 ms heavy / 37.60 ms whole). The playtest configuration must be validated in a
live session, not the replay.

## Remaining non-group cost and sliding-cache check

[VERIFIED] `internalFindPath` and `findClosestPath` do not call `clearCellForDiameter` (the only
clearance-scan caller is the width-6 ground/group path), and the census showed **0% exact repeats**
for them within 20 frames. A terrain-width cache therefore cannot remove their cost; they need a
different algorithm, not a wider memo.

[VERIFIED] A sliding group cache (refresh on hit, hard max age 60; `t120-hpa16-slide.exe`,
`B27DA263...`) cut group misses from 0.92 to **0.44/frame** and path usec from 26,371 to 24,224 in
10-12.6k, but the interval was flat: 10-12.6k 45.94 -> **46.06 ms**, 5-10k 39.54 -> **39.67 ms**.
The reduced search count did not translate into frame time, so it was rejected; the verified
playtest remains `844A319E...`.

[INFERRED] The remaining 62.89 ms heavy frame is roughly 30 ms path (group misses plus
non-cacheable per-request work), 20 ms other logic and 11 ms draw. Caching has plateaued; the next
structural lever is the committed path worker (snapshot/commit overhead) or reducing the other
logic, not another request cache.

## Cache-copy re-optimization (rejected)

[VERIFIED] Rebuilding the cached path's `nextOptimized` links with `optimizeGroundPath` on every
cache hit (`ZH_GROUP_PATH_REOPT=1`) was tested at 12,600: 5,000-9,999 **39.01 ms** vs 36.12,
10,000-12,599 **48.36** vs 40.63, 5,000-12,599 **42.21** vs 37.66. The smoothing cost outweighs
any following benefit, so it is rejected and the source reverted.

[VERIFIED] A longer fixed cache TTL (30 frames) was also worse: 5,000-9,999 **44.78 ms** vs 36.12,
10,000-12,599 **54.26** vs 40.63, 5,000-12,599 **48.03** vs 37.66, despite fewer misses
(0.57/0.54 vs 0.63/0.72). Longer reuse follows stale paths and changes behavior; TTL 20 stays.

## Closest-search cap (T-127 follow-up)

[VERIFIED] `findClosestPath` now stops after `ZH_CLOSEST_MAX_EXPANSIONS` expansions and returns
the closest reachable cell it has already recorded (it cannot return an invalid route). With a
4,000 cap on the `844A319E` base:

| Window | `844A319E` | **+ closest cap** |
|---|---:|---:|
| 5,000-9,999 | 39.54 ms | **35.75 ms** |
| 10,000-12,599 | 45.94 ms | **40.36 ms** |
| 12,600-16,977 | 56.69 ms | **56.22 ms** |
| 16,978-17,402 | 62.89 ms | **52.29 ms** |
| Whole run | 37.60 ms | **35.20 ms** |
| Heavy path usec | 29,955 | **22,935** |

[VERIFIED] The cap changes behavior: group command rows in the heavy window fall from 2,086 to
**1,039**, and `search_failed` rises from 79 to **230** (`none` 1,088 -> 663). The replay still
reaches `frame=17402 sync=ok`. This is a route/AI-changing singleplayer trade-off, accepted for
the playtest.

[VERIFIED] Promoted build `2BC7180B...` (`t120-hpa18-final.exe`, staged);
`tools/play-t120.ps1` sets `ZH_CLOSEST_MAX_EXPANSIONS=4000`. The heavy window is **52.29 ms /
19.1 FPS**, still short of 30 FPS; the remaining path is ~23 ms and other logic ~19 ms, so the next
structural lever remains the committed worker or other-logic reduction.

[VERIFIED] A lower path-queue cell budget (`ZH_PATH_QUEUE_CELLS=2000` vs the stock 5,000) was
tested at 12,600: the replay ended at logic frame **~9,501** on the score screen (path requests
starved and the match diverged). It was rejected; the stock 5,000-cell queue budget is required.

## Heavy-phase breakdown and the remaining structural step

[VERIFIED] The promoted `2BC7180B...` heavy window (16,978-17,402) measures **52.29 ms** interval:
logic **41.45**, draw **9.6**, client **10.44**; inside logic, `l_ai` **20.78**, `l_updates`
**8.57**, `l_partition` 1.22, destroy/rest 0.08; path usec **22.93** (15.63 requests/frame,
`usec_max` 13,785). The phase timers overlap (`l_ai` + path > logic), so the path is inside the AI
phase and the remainder is gameplay logic, not a separable serial block.

[INFERRED] There is no safe switch-level other-logic reduction left: object updates and AI state
machines are gameplay behavior, and lowering the path queue budget starved requests. Reaching
30 FPS (33 ms) needs the ~23 ms path stage **overlapped** with the ~19 ms other logic and draw, or
the path cut to ~5 ms. That is the committed-worker project: a frame snapshot, searches on a
separate pathfinder state, validation on commit and ordered dispatch. The existing speculative
worker is parked because snapshot cost (1.138 ms/tick) exceeded covered work (0.626 ms/tick) and
only 11/298 early candidates validated; a worker that covers the group paths is a structural
rewrite, not another cache.

[VERIFIED] `GroundSearch::Workspace::run` is a full per-lane A* kernel (own nodes, queue, seen
table) with immutable `Access` reads, so the per-lane state already exists for ordinary routes.
But `Query` and `Access` have **no width-6 footprint**: the kernel checks terrain/admission,
ally-fixed counts and pinched/cliff costs, not the 6-wide footprint or the group endpoint-relax
semantics. A same-frame committed group worker therefore needs a kernel/access extension plus
commit validation, not just a new dispatch loop.

[VERIFIED] The frozen route shadow is wired only into `internalFindPath` (`AIPathfind.cpp:4064`):
`frozenRouteShadow::submit`/`capture`/`finish` have no call in `findGroundPath` or
`findGroupGroundPath`. Its `Access` uses the actor's own radius/center, not a 6-wide footprint.
A width-6 worker therefore needs a **new** submit/snapshot/commit path for the group search, not
an option on the existing shadow.

## Cluster-size tuning (rejected)

[VERIFIED] `ZH_HPA_CLUSTER=6` was tested on the capped build at 12,600:

| Window | 10x10 | 6x6 |
|---|---:|---:|
| 5,000-9,999 | **36.12 ms** | 39.20 ms |
| 10,000-12,599 | 40.63 ms | **39.30 ms** |
| 5,000-12,599 | **37.66 ms** | 39.24 ms |

[VERIFIED] The narrower corridor helps 10-12.6k slightly but costs more in 5-10k and is net worse
over 5-12.6k, so 10x10 stays. `ZH_HPA_CLUSTER` remains an env-gated tuning knob (default 10).

## Path-queue/client overlap (rejected)

[VERIFIED] A minimal overlap was implemented: the path queue runs on a worker during
`TheGameClient->UPDATE` and joins before logic; `AI::update` skips the serial queue when
`ZH_PATH_OVERLAP=1`. At 12,600 it improves 5,000-9,999 to **32.55 ms** (36.12), 10,000-12,599 to
**37.94 ms** (40.63) and 5,000-12,599 to **34.20 ms** (37.66); the path moves into the client phase
(client 20.7, logic 11.6).

[VERIFIED] The full run tells a different story: 12,600-16,977 is flat/worse (**56.45** vs 56.22)
and the heavy window is **53.91 ms vs 52.29** (path usec 33,146 vs 22,935; command rows 2,599 vs
1,039). The one-frame path delay increases heavy-window path work and changes the command stream.
Whole run improves 33.99 vs 35.20 ms, but the target heavy window regresses. The overlap is
**rejected** and the source reverted; the playtest remains `2BC7180B...`.

## Group frozen-shadow result (rejected)

[VERIFIED] I wired a group-width query into `findGroundPath` for `pathDiameter == 6` using the
frozen A* kernel with `radius = 3` (a 6-wide footprint), the leader actor, and the serial
`goalCell` chain capture. After enabling the page snapshot (`ZH_EARLY_QUEUE_LOG` +
`ZH_NATIVE_PAGE_LOG`) so `nativePageSnapshot::live` is published, the heavy window produced:

| Metric | Value |
|---|---:|
| Submit calls (`G`) | 8,088 |
| Accepted jobs (`B`) | 142 |
| Compared (`C`) | 139 |
| Distinct group leaders | 22 of 25 |
| Unsupported | 3 |
| **Chain match** | **0 / 139** |
| **Cost match** | **0 / 139** |

[VERIFIED] The group queries do reach the kernel, but the radius-3 footprint does not reproduce
the serial width-6 group route or cost. The serial group search uses `clearCellForDiameter(6)` with
terrain/unit details, group start/goal relax and line-of-sight costs that the ordinary kernel does
not model. The existing frozen kernel therefore **cannot be committed** for group paths; a faithful
width-6 kernel/access plus group endpoint semantics is required.

[VERIFIED] The diagnostic source was kept env-gated (`ZH_FROZEN_ROUTE_SHADOW`,
`ZH_EARLY_QUEUE_LOG`, `ZH_NATIVE_PAGE_LOG`); the playtest remains `2BC7180B...`.

## Exact-width synchronous kernel (rejected)

[VERIFIED] To remove the radius-3 approximation, I ran `GroundSearch::Workspace` synchronously
before the serial group search with an Access whose `move` calls the live
`clearCellForDiameter(false, x, y, LAYER_GROUND, 6)` exactly, plus live cell/terrain/zone/height
reads. Over the full heavy run:

| Metric | Value |
|---|---:|
| Group queries | 8,088 |
| Kernel found a route | 8,088 |
| Serial success comparisons | 7,597 |
| Serial failures | 491 |
| **Chain match** | **4 / 7,597** |
| **Cost match** | **4 / 7,597** |

[VERIFIED] Exact width alone does not reproduce the serial group route. The serial width-6 search
has distinct cost/line/goal semantics (width penalties, `isBlockedByAlly`, line checks, endpoint
relax, goal-cell rules) that the ordinary kernel does not model. A committable group worker needs a
faithful port of those rules, not a kernel alignment tweak. The playtest remains `2BC7180B...`.

## Width-6 group kernel replacement (candidate)

[VERIFIED] The kernel now exposes `Access::width` backed by the live
`clearCellForDiameter(false, x, y, LAYER_GROUND, 6)` and applies the serial group cost rules:
the `0.6f * delta * COST_ORTHOGONAL` width penalty, no hard rejection of width 0/1 cells, and
pinched non-goal cells skipped. The exact-width synchronous diagnostic over the full replay
produced 8,088 group queries and 7,595 serial-success comparisons, with only **2 chain / 4 cost**
matches. Exact width alone still does not reproduce the serial group route.

[VERIFIED] The kernel is nevertheless much cheaper than the serial group search: **743 us mean**
per query (median 543), **251 heavy-window queries totalling 184 ms (0.43 ms/frame)**, p95 2.06 ms,
max 2.72 ms. The serial group misses in the same window cost roughly 15 ms each.

[VERIFIED] Committing the kernel route in the same frame, with per-cell validation
(`CELL_CLEAR`, unpinched, zone-passable) and a serial fallback, measured:

| Metric | `2BC7180B` | `kernelreplace` | `kernelreplace2` |
|---|---:|---:|---:|
| Heavy 16,978-17,402 interval mean | 52.29 ms | **43.98 ms** | **38.65 ms** |
| Heavy median | 44.75 ms | 40.03 ms | 34.04 ms |
| Heavy FPS | 19.1 | **22.7** | **25.9** |
| Whole-run interval mean | 35.19 ms | **31.92 ms** | **31.78 ms** |
| Whole-run FPS | 28.4 | **31.3** | **31.5** |
| Heavy path usec | 22,935 | **16,399** | **16,378** |
| Heavy `l_ai` | 20.78 ms | **16.51 ms** | **16.36 ms** |
| Heavy expansions/frame | 9,873 | 7,298 | 7,298 |
| Group cache hits / misses | 1,590 / 325 | 1,482 / 293 | 1,482 / 293 |
| Heavy serial fallbacks | - | 90 | 90 |
| Commands / `none` / `search_failed` | 1,039 / 663 / 230 | 983 / **686** / **84** | 983 / **686** / **84** |

[VERIFIED] The two replace runs produced identical CRC lines and byte-identical command rows, so
the route is deterministic. The second run's absolute interval was lower because the client and
draw phases measured 4.8/4.4 ms versus 10.8/9.9 ms in the first; the load-independent evidence is
the path usec (-6.5 ms) and `l_ai` (-4.3 ms), which match across both runs.

[VERIFIED] The behavior trade is a route change: 983 command rows vs 1,039, **more** `none`
(686 vs 663) and **fewer** `search_failed` (84 vs 230), with `goal_width` 129 vs 104,
`zone_mismatch` 41 vs 29 and `search_alloc` 43 vs 13. The replay still reaches
`frame=17402 sync=ok`.

[VERIFIED] The serial line-continue experiment (keep the width-6 line shortcut alive past cells
already on the open/closed list) cut expansions 9,873 -> 8,919 but path usec only
22,935 -> 22,336 and diverged behavior badly (1,551 command rows, `goal_width` 375,
`zone_mismatch` 175). It is **not promoted**; the kernel replace is the retained result.

[VERIFIED] Replacing ordinary `internalFindPath` with the same kernel is **rejected**: the match
ended at ~frame 6,606 (path telemetry stops) and the score screen then ran to frame 63,840. The
group-only build reaches 17,402.

[VERIFIED] Adding the serial `blockedByAlly` flag to the materialized ordinary path did not rescue
it: the corrected run also ended at ~frame 6,600. The ordinary replacement is rejected for behavior;
the group path, whose serial search never sets that flag, is unaffected.

[VERIFIED] The validated empty-footprint short-circuit `ZH_UNIT_MASK=on` is **neutral** on the
group build: identical CRCs, commands and expansions, path **16,520 vs 16,400 usec**, `l_ai`
16.53 vs 16.51. It is not promoted.

[VERIFIED] Lowering `ZH_CLOSEST_MAX_EXPANSIONS` to 2,000 is a **regression**: heavy **67.34 ms
(14.9 FPS)**, path 32,957 usec, commands 2,508 and group misses 928. A tighter cap makes the AI
re-path more, doubling the work; 4,000 stays.

[VERIFIED] The AI-only ordinary kernel (group kernel on, player units serial,
`ZH_ORDINARY_KERNEL_AI_ONLY=1`) preserved the 17,402 match but **regressed**: heavy 51.72 ms
(19.3 FPS), path 23,104 usec, `l_ai` 26.68, commands 2,098, `zone_mismatch` 525 vs 41 and group
misses 671 vs 293. Different AI routes cause more group re-pathing, so the ordinary kernel is
rejected even in the AI-only subset.

[INFERRED] The heavy window's remaining path is ordinary `internalFindPath`, `findClosestPath` and
cache copies, not the group search. The zero-path floor is ~27.6 ms (36 FPS), so 30 FPS needs path
<= ~5.7 ms. The group path is ~3 ms; the other ~13 ms is the remaining gap. Every serial lever
tried is neutral or negative: the ordinary kernel breaks the match or raises path cost, the unit
mask is neutral, and a tighter closest cap doubles the re-pathing. The 30 FPS heavy target needs a
worker/overlap or a faithful ordinary solver with exact parity, not another serial knob. The
whole-run mean is already **31.3-31.5 ms (31.3-31.5 FPS)**.

## Remaining path census and worker bound

[VERIFIED] With the group kernel staged, the heavy-window census (425 frames) splits the
**16.7 ms** path as:

| Kind | ms/frame | Share |
|---|---:|---:|
| `internalFindPath` | 6.25 | 37.4% |
| `findGroundPath` (incl. 90 serial fallbacks) | 3.74 | 22.4% |
| `findClosestPath` | 3.59 | 21.4% |
| `findAttackPath` | 2.37 | 14.2% |
| hierarchy + move-away | 0.78 | 4.6% |

[VERIFIED] Exact `(object, from, to)` repeats exist (846 `internalFindPath`, 313
`findClosestPath` rows), but their median frame gaps are **20 and 45 frames**; repeats within
2 frames are zero and within 5 frames save only ~0.03 ms/frame. Same-frame destination sharing
across objects is negligible (7-47 ms over the whole window). A short-TTL cache cannot capture the
remaining work; a longer TTL follows stale paths (TTL-30 already regressed).

[VERIFIED] Aligning the group commit validation with the serial clip-zone rule (accept a
zone-impassable cell if any +/-3 clip point is passable) reduced fallbacks but changed the match:
the replay ended at **~frame 15,853**, before the heavy window. The strict validation's fallbacks
are protecting behavior; the zone-aligned build is rejected.

[INFERRED] A worker must cover `internalFindPath` + `findClosestPath` + `findAttackPath`
(**12.2 ms/frame**) to matter, and the frozen snapshot must be cheaper than the covered work. The
existing snapshot path costs **1.138 ms/tick** and covered only **0.626 ms/tick** of ordinary work,
so the first requirement is a cheaper snapshot/validation mechanism, not another thread around the
current snapshot. The group kernel/commit design is the template; it is still same-thread.

[VERIFIED] Current frozen-worker shadow on the staged build: 4 lanes gave 731/1,131 submissions
(64.6%), 730/730 exact route parity, and 273/731 ready (37.3%) when submitted just before the
serial search. **8 lanes/8 submits** gave **1,027/1,131 (90.8%)**, **1,026/1,026 exact parity**, and
**467/1,027 ready (45.5%)**. The page freeze is only **9-14 us**; the per-submit input copy
(`resident` 65k cells + units + zone) is **512 us mean**, i.e. **1.10 ms/tick**. The old
1.138 ms/tick "snapshot" was this per-submit copy, not the freeze.

[INFERRED] Worker feasibility looked concrete: parity 100%, 90.8% coverage, and a cheap freeze; the
limits were the submit point and the 512 us per-submit input copy. The shared per-frame input was the
proposed production design, tested next.

[VERIFIED] The shared per-frame input was implemented and is **not parity-safe**: one page/resident/
zone snapshot plus a per-actor unit cache cut the submit cost from **511.6 to 348.2 us** (1.10 to
0.75 ms/tick), but route parity fell from **100% to 59.1%** (565/956) and readiness from 45.5% to
24.8%. The path input is dynamic within a frame (units, resident records, zone), so a frame-start
snapshot changes 41% of routes; the per-search input at the search time is the parity-correct one.

[INFERRED] The worker bottleneck is **input dynamism**, not kernel/thread speed. A per-frame
snapshot loses parity; a per-search snapshot costs 512 us and the result is ready only at the serial
end (45.5%), too late to skip the serial. The worker is not viable without a per-search snapshot
cheaper than the search or an AI prefetch/deferred commit; the earlier prefetch validated only
11/298 and the one-frame overlap regressed the heavy window. The 30 FPS heavy target is structurally
blocked by this input/timing boundary, not by another kernel or cap.

[VERIFIED] The covered ordinary serial searches average **502 us** (543,658 us / 1,083) — essentially
the same as the **512 us** per-search input build. Even a free, instant kernel would cost the same
input plus the solve, so the worker cannot beat the serial search it replaces. The group paths won
because their searches are 5-15 ms; ordinary/closest/attack are ~0.5-5 ms and input-bound.

[INFERRED] The remaining 12.2 ms is **input-bound, not search-bound**. A per-frame shared input loses
41% parity; a per-search input costs the search; prefetch validated 11/298; the one-frame overlap
regressed the heavy window. The 30 FPS heavy target needs a persistent incremental world state
(delta updates with no per-search build) or an engine-level overlap, not another worker, region or
cap. The whole-run mean is already 31.3 FPS; the heavy 425-frame window is the outlier.

[VERIFIED] Correction: the per-search input is **not** 512 us once the redundant work is removed.
Computing the unit facts directly from the object list (no `findObjectByID`) and sharing an empty
resident grid (resident only gates new-record accounting, not the route) gives **154.6 us mean**
(median 146.2) with **100% route parity** (1,023/1,023) and 42.1% ready. The input is now **31% of
the 502 us covered search**, not equal to it.

[INFERRED] The input-bound conclusion is narrowed: the worker is potentially profitable on the
covered ordinary paths (155 us input + ~70 us kernel vs 502 us serial). The next step is the
queue-level prepare/apply commit (or a bounded per-path wait) with ordered validation and serial
fallback; the closest/attack searches remain separate.

[VERIFIED] The bounded per-path worker commit was implemented and is **rejected**: with the 154.6 us
input and a 400 us wait, the sample-window path is **16,692 vs 13,722 us/frame** for the group build
(1,085 submits, 1,015 accepted, 186 abandoned) and the full run diverges (CRC `9D9A905B...`, commands
981 vs 983, `zone_mismatch` 50 vs 41). The per-path wait serializes input + wait + serial fallback;
it is slower than the search it replaces. A queue-level prepare/apply (submit all current paths,
compute in parallel, commit once) is the remaining design, not a per-path wait.

## Regional parity gate (rejected)

[VERIFIED] A read bound of 32 cells around the start/goal (cap 128) on the ordinary shadow covered
**85.0%** of `internalFindPath` calls (961/1,131) with **100% exact chain/cost parity** (all 961
compared routes matched) at **70 us mean** versus ~1,430 us serial. The kernel and serial expansion
counts were identical (mean 56, median 2), so the bound selected the exact serial search.

[VERIFIED] Committing the region-gated kernel in the same frame did **not** preserve behavior.
Five variants (start-cell zone side effect, `canOptimize=true`, open+closed budget charge, AI-only)
all changed the CRC and command stream: heavy **57.38-70.30 ms**, path **29,558-41,010 usec**,
commands **2,081-2,817** versus the group build's 983. The final `Path::optimize`/queue timing still
diverges despite raw chain/cost parity. The region commit is rejected; the staged build remains
`1EE75D56...` (43.98 ms heavy / 31.92 ms whole).

[INFERRED] Raw chain/cost parity is not sufficient for a safe ordinary commit. A worker/commit
must match the final optimized `Path` and the per-frame queue timing, or run the serial solver as
the oracle. This strengthens ADR-0027's requirement: the ordinary worker needs full-path
equivalence, not just kernel coverage.

[VERIFIED] The final region commit (start-cell `blockedByAlly` exclusion + exact open+closed budget
charge + `canOptimize`) **is behavior-exact**: the CRC lines (`04C62655`, `AF9B0AD8`, ...) and the
122,319-byte / 983-row command stream match the group build. It is nevertheless **not a performance
win**: path **17,361 vs 16,399 usec**, whole **31.88 vs 31.92 ms**; the heavy 40.26 ms was measured
with client/draw 5.14/4.62 versus the baseline's 10.80/9.92, so the interval difference is load.

[INFERRED] The 85% region coverage is count-weighted, not cost-weighted: the covered searches are
the cheap ones, while the long `internalFindPath`/`findClosestPath`/`findAttackPath` searches
outside the region carry the remaining cost and are the ones the kernel does not parity-match. The
ordinary kernel/region commit is rejected for performance; behavior parity is achievable but not
profitable at this bound. The staged build remains `1EE75D56...` (43.98/31.92).

[VERIFIED] Cost-weighted coverage rises with the bound: cap 128 = 7.6% of serial cost (net
0.15 ms/frame), cap 192 = 38.4% (net 1.03 ms/frame), cap 256 = 56.1% (net 1.55 ms/frame); the
count coverage is 85.0/94.5/95.8% and the route parity is 100% at every bound.

[VERIFIED] The cap-256 ordinary commit (same exact-behavior build) is **behavior-exact**: CRC
`04C62655` and the 983-row command stream match. It is nevertheless **not a win**: path
**17,460 vs 16,399 usec**, whole **32.49 vs 31.92 ms**, expansions 6,116 vs 7,298. The kernel's
1.55 ms search saving is offset by the per-read region checks, path materialization and queue
accounting. The 4.2% excluded searches still cost ~2.4 ms/frame, and closest/attack remain ~5.96 ms.
The region/ordinary commit is closed for performance.

[VERIFIED] The staged playtest is now `1EE75D56...` (`build/engines/t120-idlestop.exe`) with
`ZH_GROUP_KERNEL_REPLACE=1`; `2BC7180B...` (`build/engines/t120-hpa18-final.exe`) remains the
rollback. The staged binary adds the benchmark-only replay-finish stop guard and the gated-off
ordinary kernel; the group commit code is the build that produced both confirmed runs.

[VERIFIED] Harness fix: `ZH_GRAPHICAL_REPLAY_STOP` now also stops when the engine leaves replay
mode after frame 100, and `tools/wait-replay.ps1` kills a benchmark when
`l_updates + l_ai < 0.2 ms` for 30 s or the clock expires. The `verifyidle` run ended with
`WAIT_RESULT=CHECKPOINT` and `Graphical replay checkpoint frame=100 sync=ok replay_finished`
instead of idling to frame 63,840.

## Module sleep attribution and event-driven question (T-127)

[VERIFIED] With `ZH_ATTR_SAMPLE=1` in the heavy window: **2,508 awake modules** vs **19,124 sleepy**
(88.4% asleep), `l_updates` 9.67 ms sampled (8.4 unsampled), slowest module update 508 us mean
(p95 973, max 1,422). The slowest module is `AIUpdateInterface` in **361/425 frames**
(`TransportAIUpdate` 46, `ChinookAIUpdate` 14); the slowest objects are GLA vehicles/infantry.

[VERIFIED] The d3d8to9 wrapper A/B on the staged build was load-confounded and slower (heavy 56.55
vs 43.98 ms, path 20,649 vs 16,399, client 13.88 vs 10.80, draw 12.75 vs 9.92); the wrapper was
removed and system D3D8 restored. Not promoted.

[INFERRED] The engine already implements the event/timer idea: 88.4% of module instances are parked
in the sleepy heap and skipped; only 2,508 of 21,632 update per frame, averaging 3.3 us each. A
dirty/event list cannot remove the awake work; it would only remove heap/traversal overhead, which
is small relative to 8.4 ms. The remaining `l_updates` is awake AI/physics/weapon work, with
`AIUpdateInterface` the hot type. The 30 FPS heavy target needs that awake work reduced or
parallelized, not a polling-to-event conversion.

[VERIFIED] The per-module-type aggregate attempt (`ZH_ATTR_MODULE_LOG`) was too heavy: the
per-update `KEYNAME`/unordered-map accumulation slowed the run to ~127 ms/frame, hit the
25-minute watchdog at frame ~11,800, and never reached the heavy window; `modules.csv` is empty.
The awake/sleepy counts and the slowest-module data above remain the valid attribution. A lighter
fixed-ID histogram (no per-update name lookup/allocation) is required for the per-type totals.

[VERIFIED] The fixed-slot histogram (`modulelog3`, frames 16,919-17,399, 481 frames) succeeded and
splits the awake module time: **`AIUpdateInterface` 2,570 ms total = 5.34 ms/frame** (63.5% of the
top-20 4,044 ms), `TransportAIUpdate` 267 ms, `WorkerAIUpdate` 229, `ChinookAIUpdate` 120
(AI total ~**6.6 ms/frame**), `ObjectWeaponStatusHelper` 328 (0.68), `PhysicsBehavior` 286 (0.59),
the rest below 65 ms. The module sum is 8.41 ms/frame vs `l_updates` 9.45 sampled (8.4 unsampled).
The run kept the group CRC `04C62655` and the 983-row command stream.

[INFERRED] The awake `l_updates` cost is **AI-state-machine-dominated**, not physics/weapons. The
next optimization target is the `AIUpdateInterface` state machine (5.34 ms/frame): state update,
target scanning and path-request bookkeeping, or a deterministic AI job system. The path worker is
closed. The heavy frame is logic-bound: `draw` is inside `client` (`TheDisplay->DRAW()` runs inside
`GameClient::UPDATE`), so client is ~5-10 ms, not a separate 20 ms addend.

## AI pending/apply split (rejected)

[VERIFIED] Implemented the deferred ordinary commit: prepare-only `internalFindPath` submits the
154.6 us frozen input and returns no path; `computePath` intercepts the null before the closest
fallback (`setQueueForPathTime(1)`); `doPathfind` applies the validated pending path at the next
dispatch with serial fallback. The run reached 17,402 but diverged: CRC `6BCE4A92...`, commands
**927 vs 983** (`none` 657 vs 686, `search_failed` 117 vs 84). The sample-window path is **17,640 vs
13,722 us/frame**; full path 19,987 vs 16,399. The one-frame deferral makes the path stale and
triggers re-requests; the deferred apply costs more than the serial search it skips. Rejected; the
staged build remains `1EE75D56...`.

## Same-frame queue batch (rejected)

[VERIFIED] Implemented prepare-all in `processPathfindQueue` plus one `applyBatch` at the queue
boundary, with AI `applyBatchPath`/`serialBatchPath` and serial fallback for misses. The heavy run
diverged: CRC `BD4F07ED...`, commands **877 vs 983** (`none` 595 vs 686, `goal_width` 164 vs 129,
`search_failed` 98 vs 84). The sample-window path is **14,651 vs 13,722 us/frame**; full path 18,524
vs 16,399. Applying the paths at the queue boundary changes the AI's path timing/order, and the
missed/invalid worker results pay the serial fallback; the batch is slower and behavior-changing.
Rejected; the staged build remains `1EE75D56...`.

## AI sub-phase, per-state, and residual attribution

[VERIFIED] `aiphase` (frames 16,919-17,399, exact `04C62655`/983 commands) splits the
`AIUpdateInterface` family: base `AIUpdateInterface` 5.31 ms/frame = state machine **5.16**,
locomotor 0.68, turret 0.48, bookkeeping 0.10. The phase timers also run inside the
Transport/Worker/Chinook/SupplyTruck subclasses, so the family total is **6.42 ms/frame**.

[VERIFIED] `aistate` (same CRC/commands) attributes the 5.16 ms state-machine total by the state
active at entry: **`AI_GUARD` 2.06**, **`AI_HUNT` 1.25**, **`AI_IDLE` 1.21**, waypoint-team 0.34,
`AI_DOCK` 0.15, `AI_ATTACK_MOVE_TO` 0.07, `AI_MOVE_TO` 0.05, `AI_ATTACK_OBJECT` 0.02, rest <0.02.
Guard/hunt delegate to sub-machines (inner/outer/return/attack), so their cost is sub-machine work,
not a per-frame guard enemy scan: `GuardEnemyScanRate` defaults to 15 frames.

[VERIFIED] The residual capture (`ZH_LAST_STAND_RESIDUAL`, ticks 16,978-17,277) closes the 5.9 ms
logic gap that the `l_*` buckets omitted: **script 5.445** (sequential 5.06, sides 0.32, team-state
0.07; terrain/CRC/stats/recorder/commands 0.02 total), **path queue 11.887** (dispatch overhead only
0.16), **players 3.192** (planner 1.412, of which base building 1.333; team generic scripts 1.727),
everything else <0.03. Within the script time, `script_search` 2.798 is synchronous pathfinding
issued from scripts; team generic actions cost 1.630 (their conditions only 0.062).

[INFERRED] Clean heavy frame (38.65 ms, `kernelreplace2`), non-overlapping split: path **16.6**
(queue 11.9 + script-issued 2.8 + other direct ~1.9, 43%), AI modules **8.4** (states 5.2, physics
0.6, weapons 0.7), script evaluation **2.6**, player/team scripts **3.2** (incl. base building 1.3),
partition 1.2, destroy/rest 0.4, client **4.9** (draw 4.4 inside it), audio/msg 0.3. Overlaps:
path searches can run inside AI module updates, so the path and AI buckets are not strictly
disjoint. Against the clean 38.65 ms, the 30 FPS heavy target is **5.3 ms away**, not the 10.7 ms
implied by the 43.98 ms background-load run.

[INFERRED] Unturned targets by measured size: path 16.6 (behavior-parity constrained; four commit
variants rejected), AI states 5.2 (guard/hunt/idle sub-machines), team generic actions 1.6 and
script evaluation 2.6 (never attributed per script/opcode), player/bookkeeping 1.7, client 4.9-10.9
(present-bound; the run-level bimodality is environmental). The next diagnostic is per-script
attribution of the team generic actions, then the guard/hunt sub-machine states.

## Team-script action attribution and idle dedupe (rejected)

[VERIFIED] Labeling each team generic action with its `ScriptActionType` (partial `teamtypes` run,
map-load labels are deterministic) shows the 1.37 ms/frame is dominated by **`TEAM_STOP` (type
175)** in the nine `GLA Attack Sequence Center/Back/Flank` scripts; the other labels are
`TEAM_APPLY_ATTACK_PRIORITY_SET` (43), `SET_RANDOM_TIMER` (147), `TEAM_GUARD_AREA` (204) and
`TEAM_EXIT_ALL` (55). `doTeamStop` creates a fresh group and calls `groupIdle` on every member
every frame, with no already-idle check; `internalSetState` always re-runs `onExit`/`onEnter`, so
an already-idle member re-enters `AI_IDLE` and resets its sleep timer.

[VERIFIED] Deduping that (`ZH_IDLE_DEDUPE=1`, skip `aiIdle` when `cmdSource==CMD_FROM_SCRIPT` and
`ai->isIdle()`) reaches `frame=17402 sync=ok` but diverges: CRC `969FAFE4` vs `04C62655`, commands
**2,722 vs 983**. It is also much slower: heavy logic 31.75 -> **53.09 ms**, `l_ai` 15.24 -> 32.72,
path 15,088 -> **28,510 usec**, expansions 6,758 -> 10,201, `usec_max` 9.1 -> 18.2 ms; only
`l_updates` falls (8.84 -> 6.75). Rejected: the repeated `TEAM_STOP` is load-bearing suppression —
removing it lets the teams accumulate attack/move state and floods pathfinding.

[VERIFIED] The first `teamtypes`/`movededupe` attempt was invalid: a second game process was
launched while the first still held `Generals.exe`, so `teamtypes` exited near frame 5,900 and
`movededupe` ran a build without the dedupe code (empty outputs). Only the map-load action labels
from `teamtypes` are used.

## Target-scan attribution

[VERIFIED] `guardhunt` (exact `04C62655`/983 commands) attributes the remaining AI states:
GUARD 2.034 = sub-state IDLE 1.795 + OUTER 0.108 + RETURN 0.076, and the inner-target scan is
**1.785 ms/frame** (88% of GUARD). HUNT 1.233 = enemy scan **0.637** + sub-machine 0.533
(`AI_ATTACK_OBJECT` 0.531). IDLE 1.192 = mood scan **1.096** (92%). All three are
`PartitionManager` target scans: **3.52 ms/frame total, 68% of the 5.16 ms AI state cost**. Health
of the scan path is now the single largest reducible AI cost.

[VERIFIED] `ZH_MOVE_DEDUPE=1` (skip an identical `CMD_FROM_SCRIPT` move while already in
`AI_MOVE_TO` within 2 world units) is behavior-identical (CRC `04C62655`, 983 commands) but not
faster: path 15,088 -> 15,985 usec, `l_ai` 15.24 -> 16.27, logic 31.75 -> 32.87; expansions and
group-cache counts identical. No performance signal; not promoted.

[VERIFIED] Reordering the reject filters before the distance proc in
`PartitionManager::getClosestObjects` (`ZH_SCAN_FILTER_FIRST=1`) is behavior-identical (CRC
`04C62655`, 983 commands) but immaterial: the three scans total 3.517 -> **3.439 ms** (-0.078),
GUARD 2.034 -> 2.086, IDLE 1.192 -> 1.121. The scan cost is the ring/cell traversal and the filter
checks themselves, not the distance math; not promoted.

[VERIFIED] A 2-frame per-(team, waypoint) dedupe at `ScriptActions::doMoveToWaypoint`
(`ZH_GROUP_MOVE_DEDUPE=1`) is behavior-identical (CRC `04C62655`, 983 commands) but not faster:
path 15,088 -> 16,032 usec, `l_ai` 15.24 -> 16.28, logic 31.75 -> 33.07; expansions (6,758) and
group-cache hits/misses (3.1/0.6) are identical. The group cache already absorbs the repeated
script moves: the path budget is the genuine ~0.6 new group searches per frame as leaders move,
plus unit-level requests. Script-side dedupe cannot reduce it; only route reuse, a larger budget
trade, or parallel dispatch would.

[INFERRED] The four behavior-preserving candidates (move dedupe, group dedupe, filter order) and
the behavior-changing idle dedupe all fail to improve the frame. The measured frame is now fully
explained: path 16.6 (43%, demand-driven and cache-served), AI 8.4 (3.5 of it necessary target
scans), script/team/planner 5.8 non-path, partition 1.2, client 4.9-10.9 present-bound. No local
behavior-preserving hotspot remains; 30 FPS requires a deterministic job system (path + AI), a
render thread, or a deliberate gameplay trade (path budget, scan rate, or route reuse) that needs
a live playtest decision.

## Partial-region freeze gate (ADR-0027 follow-up)

[VERIFIED] `pathbox` (exact `04C62655`/983 commands, census enabled) recorded the allocated-cell
box of every outer search in the heavy window: 9,568 outer searches over 481 frames (19.9/frame),
box area mean **2,006 cells** (p50 63, p90 5,904, max 41,328). Per frame the per-request box sum is
**39,911 cells** (p90 86,522) and the exact rectangle union is **18,567 cells** (p90 36,580). The
boxes contain 2.0M allocated cells for 3.25M expansions over the window.

[INFERRED] A union / rectangle-list freeze therefore costs approximately **0.09 ms/tick at
5 ns/cell, 0.19 ms at 10 ns, 0.28 ms at 15 ns**; a per-request freeze costs 0.20/0.40/0.60 ms. This
**passes ADR-0027's `< 0.5 ms/tick` snapshot gate** for a union freeze at 10-15 ns/cell, and is
marginal for a per-request freeze. The gate that now blocks the worker is the search state
isolation and ordered commit, not the snapshot cost. `internalFindPath` mutates ~10 `Pathfinder`
members (`m_openList`, `m_closedList`, `m_start`, `m_output`, `m_extent`, counter, memo) and the
per-cell `m_info` scratch, so a lane needs a private `SearchContext` over the shared grid before
any parallel dispatch is safe.

[VERIFIED] The scenario-limit trade (`ZH_PATH_CELL_BUDGET=3000`, `ZH_PATH_SEARCH_CAP=3000`, 60% of
the default) diverges and **ends the match at ~frame 16,513** (`replay_finished`), 900 frames
before the 17,402 checkpoint; the heavy window never occurs. Path starvation changes the outcome,
so the budget is not a usable smoothing knob for this scenario. Rejected.

## SearchContext slice and the inter-request grid mutation

[VERIFIED] The first `SearchContext` slice (open/closed lists as `inline static thread_local`)
kept exact `04C62655`/983 commands, but the timing control settles it: `baseline-now` (the pure
staged build, same machine state) measures heavy **37.69 ms / 32.09 logic / 15,232 usec path**,
while the thread-local slice measures **38.72 / 32.95 / 16,047**. The +5.4% path is the dynamic-init
TLS guard on `PathfindCellList`, not drift (the control is only ~1% above `kernelreplace2`). The
slice is reverted; a lane context must be a plain per-lane pointer/parameter, not a dynamic-init
`thread_local`.

[VERIFIED] A dispatch-scoped counter in `nativePageSnapshot::changed()` (the choke point for every
static-cell write: type, pinched, zone, layer, connect layer, obstruction) shows the heavy-window
**grid is mutable mid-dispatch**: 26,888 writes over 481 frames (77.5/frame, p50 64, p90 165, max
356), present on 347/481 frames — chiefly `updateGoal`/pinch/zone updates performed after each
request. Later searches therefore see earlier requests' static changes; a frozen-input parallel
search cannot be exact, which explains the earlier 59.1% shared-input parity.

[VERIFIED] From the `pathbox` boxes, disjoint-extent 2-lane batching is weak: only **67/481 frames
(14%)** are fully packable by the post-hoc explored boxes, the greedy second lane covers 23% of the
work, and the ideal speedup is **1.30x** (~3 ms of the 15.2 ms path). A dispatcher cannot know the
explored box before searching; using predictable start/goal rectangles with 4/8/16-cell margins,
only **49/34/26 frames (10/7/5%)** fully pack, with a **1.27-1.29x** ceiling. It cannot reach 30
FPS on its own.

[INFERRED] The realistic dispatcher ceiling is therefore ~3.2 ms of path (38.65 -> ~35.5 ms, 28.2
FPS) even with perfect lane isolation and zero fallback cost, while requiring the full
`doPathfind` prepare/apply pipeline and a per-lane `SearchContext` — a multi-session refactor. It
is not the right next step: the frame is bounded by serial dependencies, not by search arithmetic.

[INFERRED] The lane dispatcher is blocked by **inter-request static mutation**, not the scratch
lists. Exact parallelism needs each request's ~77 writes propagated into the frozen copy in request
order (page diff), or serial live-grid searches. Prefetch at command issue has the same staleness.
This is a multi-session architecture task with no behavior-preserving local win; the 30 FPS heavy
target remains unmet.

## Per-search unit memo (promoted)

[VERIFIED] `nativeUnitMemo` — a per-search cell cache of `TCheckMovementInfo` (ally/enemy counts,
moving/goal flags, movement allowed), invalidated on static-cell changes and self-checking 1 in 256
hits — was built but disabled. Enabling it (`ZH_NATIVE_UNIT_MEMO=1`) on the heavy replay with exact
CRC `04C62655`/983 commands:

| Run | Path usec | Logic | `l_ai` | Client |
|---|---:|---:|---:|---:|
| `memooff` (memo off, same build) | 16,154 | 32.97 | 16.39 | 10.37 |
| `unitmemo` (memo on) | **14,793** | **31.58** | **14.97** | 11.09 |

Path -8.4%, logic -1.39 ms, `l_ai` -1.42 ms, expansions identical (6,758/frame). The memo log shows
6.04M calls, **5.06M hits (83.7%)**, 19,408 live checks and **0 mismatches**. A third run of the
promoted default (`memodefault`, no environment variable) kept exact CRC with path **14,227** and
logic **30.35**.

[VERIFIED] The memo is now **default-on** (`ZH_NATIVE_UNIT_MEMO=0` disables), and the verified
candidate is `build/engines/t120-memo-default.exe` (`C9147884...`). The staged playtest build
remains `1EE75D56...` until a deliberate restage. This is the first behavior-preserving path win
since the group kernel: clean heavy ~38.65 -> ~37.2 ms, ~27 FPS; 30 FPS remains unmet.

## No-draw ceiling (render-thread opportunity)

[VERIFIED] Same-session heavy-window pair with the promoted memo build (`04C62655`/983 commands
both):

| Run | Interval | Logic | `l_ai` | `l_updates` | Client | Draw | Path |
|---|---:|---:|---:|---:|---:|---:|---:|
| `baseline-charger` | 39.16 | 31.19 | 14.69 | 9.06 | 7.40 | 6.67 | 14,438 |
| `nodraw` (`ZH_PROFILE_WARMUP_UNTIL=17402`) | **29.22** | 28.44 | 14.61 | 7.31 | 0.51 | **0.00** | 14,169 |

The no-draw ceiling is **29.22 ms / 34.2 FPS** with exact CRC/commands — the draw is simulation-
neutral. The interval drop is 9.94 ms, of which 6.67 is the draw and the rest is a lower
logic/`l_updates` regime. The conservative direct-overlap projection is 39.16 - 6.67 = **32.49 ms
(30.8 FPS)**; the measured ceiling leaves ~4 ms of headroom for thread synchronization.

[INFERRED] A render thread with device-thread ownership, a double-buffered drawable snapshot and a
frame handshake can reach 30 FPS; the measured headroom is sufficient. This is a multi-session
implementation, not a same-session patch, and the 30 FPS claim waits for a clean heavy run of the
threaded build.

## Render-thread handshake prototype (milestone 1)

[VERIFIED] Implemented `ZH_RENDER_THREAD=1`: a bounded two-frame slot with a condition-variable
handshake and serial fallback when unset. The real `DRAW()` is skipped (black-screen diagnostic);
the worker emulates a present-bound draw by sleeping `ZH_RENDER_WORK_US` microseconds. A startup
deadlock was found and fixed: the worker decremented `pending` without notifying the submit waiter,
and `ZH_RENDER_WORK_US=0` masked it because the main thread never had to wait. The fix adds
`m_cv.notify_all()` after the decrement.

[VERIFIED] Same-session heavy pair, exact `04C62655`/983 commands:

| Run | Interval | Logic | `l_ai` | Client | Draw |
|---|---:|---:|---:|---:|---:|
| `baseline-charger` | 39.16 | 31.19 | 14.69 | 7.40 | 6.67 |
| `nodraw` | 29.22 | 28.44 | 14.61 | 0.51 | 0.00 |
| `renderhandshake` (6.7 ms worker) | **29.24** | 28.47 | 14.60 | 0.51 | 0.00 |

The handshake overhead is **+0.02 ms (0.1%)** and the 6.7 ms present-bound worker is fully hidden.
Binary `build/engines/t120-rt-handshake.exe` (`9A1F6C66...`). This is **not** a performance
candidate — it does not render, and 30 FPS is not claimed.

[INFERRED] The bounded handshake costs effectively nothing against the ~4 ms headroom. Next
milestones: (1) drawable/display snapshot parity on the main thread (serial `DRAW()` from the
snapshot, exact CRC and visual check), (2) device/present ownership on the render thread, (3) heavy
validation of the threaded build.

## Render transform snapshot (serial slice)

[VERIFIED] `ZH_RENDER_SNAPSHOT=1` captures each drawable's `Matrix3D` into an ID-indexed side table
immediately before DRAW; `Drawable::draw` consumes the captured matrix instead of the live object
transform. Serial heavy replay: exact `04C62655`/983 commands, checkpoint 17402. The draw measured
4.51 ms in the fast client regime versus 6.67 ms in `baseline-charger`'s slow regime, so the
overhead is inside the known client bimodality; the capture itself is ~1,000 matrix copies plus
O(1) lookups.

[VERIFIED] A variant that stored the snapshot inside `Drawable` (two new members) **crashed early**
(~frame 5,000, no checkpoint, empty stdout); the Drawable layout is ABI-shared with the mod DLL.
It is reverted; the ID-indexed side table is the retained design.

[INFERRED] The transform snapshot is faithful by construction (the captured matrix is the value the
serial draw would have used), and it is the first draw-state slice. Remaining live reads are
opacity/stealth, effect positions, terrain/shroud, particles, projected shadows, water, camera
views, and UI; those must be covered before the worker can own the real DRAW.

## Device-thread serial draw and overlap

[VERIFIED] With `ZH_RENDER_THREAD=1`, `ZH_RENDER_DEVICE=1` and `ZH_RENDER_WAIT=1` (main thread
waits for the worker), the worker calls `TheDisplay->DRAW()` and the 300-frame replay completes
with exact CRC/commands. D3D8 tolerates the device call from the worker when serialized.

[VERIFIED] Removing `ZH_RENDER_WAIT` (overlap) crashes immediately after the first submit: the
attr file is empty and the stderr checkpoints stop at `submit 1`. Drawing live drawables/objects
while the main thread updates them is not safe without the full render-state snapshot.

[INFERRED] The handshake, the serial transform snapshot and the device-thread call are validated.
The complete render-state snapshot (opacity/stealth, effects, terrain, particles, projected
shadows, water, camera views, UI) is the remaining prerequisite for overlap; the 30 FPS claim
still waits for a clean threaded heavy run.

## First full overlap: draw during logic

[VERIFIED] With `ZH_RENDER_THREAD=1`, `ZH_RENDER_DEVICE=1`, `ZH_RENDER_WAIT=1` (submit after the
client update, wait at the end of the frame), the worker draws via `TheDisplay->DRAW()` while the
main thread runs logic. The full 17,402 replay completes with exact `04C62655`/983 commands. Heavy:
**37.20 ms (26.9 FPS)** vs `baseline-charger` 39.16 ms (25.5 FPS); client 0.49 and draw 0.00 on the
main thread, but **logic 31.19 -> 36.44 ms** and path 14,438 -> 15,726 usec.

[INFERRED] The draw overlaps logic, but the worker's CPU work (D3D8 submission) competes with the
simulation on this 4-core CPU: hiding 6.7 ms of draw recovers only **~2 ms** because the logic
slows by ~5 ms. The draw is **CPU-bound, not GPU-wait-bound**. A render thread alone cannot reach
30 FPS here; reducing the draw's CPU cost (batching/instancing) or moving it to genuinely idle
capacity is required. The 30 FPS target remains unmet.

## CPU draw profile

[VERIFIED] Per-frame draw split in the heavy window (serial draw, exact `04C62655`/983 commands):

| Phase | mean ms | Notes |
|---|---:|---|
| `drawViews()` (scene) | **2.10** | terrain, drawables/render objects, shadows, particles |
| — visibility check | 0.152 | frustum cull over all render objects |
| — per-object frame update | 0.006 | `On_Frame_Update` |
| — terrain | 0.284 | |
| — visible render loop | **0.038** | **120 visible objects/frame** |
| — WW3D camera/clear | 0.003 / 0.000 | |
| — color passes / light env | 0.000 / 0.001 | |
| — **RTS3DScene flush (real draw submission)** | **1.060** | 120 visible objects |
| —  — occluded/stencil pass | **0.446** | largest flush stage |
| —  — particles | 0.133 | |
| —  — sorted translucent | 0.087 | |
| —  — translucent | 0.036 | |
| —  — water/static lists | 0.010 | |
| —  — opaque mesh flush | 0.000 | |
| — `WW3D::Flush` (second, empty) | 0.007 | |
| — sorting flush | **0.002** | |
| — present (`End_Scene`) | **0.566** | |
| — WW3D/DX8 remainder (derived) | ~1.0-1.6 | scene/present overhead, not per-object |
| — volumetric shadows | 0.363 | shadow volumes (ShockWave) |
| — projected shadows | 0.057 | |
| — shadow prepare | 0.000 | |
| in-game UI total | 1.33-2.22 | `postWindowDraw` 1.63, `winRepaint` 0.55, preDraw/hints/postDraw ~0.03 |
| — player info list | **0.715** | observer player list |
| — game clock | **0.435** | formats/measures two strings every frame |
| — render FPS overlay | 0.060 | cheap |
| — system time | 0.030 | |
| `TheGameClient->DRAW()` | 0.001 | |
| mouse | 0.024 | |

[INFERRED] The draw is not dominated by one cullable waste: scene rendering 2.1 ms (volumetric
shadows 0.36, projected 0.06; only 120 visible objects; color/light setup ~0; **real draw
submission `RTS3DScene::Flush` 1.06 ms**; the second `WW3D::Flush` is empty at 0.007; present 0.57),
normal HUD text ~1.2 ms (observer list + clock; the FPS overlay is only 0.06), window repaint
0.55 ms. The earlier "mesh flush 0.006" was a misattribution of the wrong Flush. Draw-call
batching/state work can target the 1.06 ms flush, but halving it saves only ~0.5 ms — still short
of the ~3 ms gap to 30 FPS. The flush itself splits into occluded/stencil 0.446, shadows ~0.42,
particles 0.133, sorted 0.087, translucent 0.036, water 0.010, opaque 0.000; the stencil-occlusion
pass is the largest single stage and is a visual feature (behind-building markers).

## Windowed triple buffering (rejected)

[VERIFIED] Same-build heavy pair, exact `04C62655`/983 commands: windowed `BackBufferCount=2`
(`ZH_TRIPLE_BUFFER=1`) gives interval **36.40 ms**, client 4.84, draw 4.35; the off build gives
**36.32 ms**, client 4.74, draw 4.24. Triple buffering is +0.08 ms (neutral-to-worse), not
promoted; the gate remains off by default.

[VERIFIED] The earlier `baseline-charger` 39.16 ms was a slow-present run (client 7.40/draw 6.67);
the fast-regime heavy is **~36.3 ms (27.5 FPS)**. The run-level client bimodality (foreground/
present state) remains the dominant measurement variance.

## Occluded/stencil skip (visual trade, opt-in)

[VERIFIED] `ZH_SKIP_OCCLUDED=1` skips `flushOccludedObjects`/`flushOccludedObjectsIntoStencil`. Same-build heavy pair, exact `04C62655`/983 commands:

| Run | Interval | FPS | Logic | Client | Draw | `views` |
|---|---:|---:|---:|---:|---:|---:|
| `occcontrol` | 36.90 | 27.1 | 27.38 | 9.10 | 8.37 | 7.21 |
| `occskip` | **35.49** | **28.2** | 28.57 | 6.55 | **5.68** | **3.37** |

Draw -2.68 ms, views -3.84, interval -1.41 (logic +1.19 variance). The occluded stage measured **3.19 ms** in this regime (0.446 ms in the fast regime), so the skip's benefit is regime-dependent: ~0.45-3.2 ms. It removes behind-building markers/occluded rendering — a **visual trade**, kept opt-in (`ZH_SKIP_OCCLUDED=1`), not default. 30 FPS remains unmet (best heavy 35.49 ms / 28.2 in this pair).

## Measurement environment: settings profile and GPU path

[VERIFIED] Every run in this record used the project's `performance` options profile, not max
settings: 1920x1080, `AntiAliasing = 0`, `StaticGameLOD = Custom` / `IdealStaticGameLOD = Low`,
`TextureFilter = Bilinear`, `AnisotropyLevel = 2`, `TextureReduction = 0`, with shadow volumes,
shadow decals, `MaxParticleCount = 5000`, heat effects, extra animations, soft water edges, trees
and building occlusion all **on**. Retail-High equivalent (AA 8 + High LOD) was never measured.

[VERIFIED] The game ran on the **Intel UHD iGPU**, not the GTX 1650 Ti, for every earlier
measurement. Evidence while a replay ran: `nvidia-smi` showed 0% / 9 MiB on the dGPU and no
`Generals.exe` process, while the game's `engtype_3D` instance was busy on the non-NVIDIA adapter.
Three mechanisms failed to move it: an `NvOptimusEnablement` export verified present in the PE
(`dumpbin` RVA `0x67F4D8`), fullscreen (`DGPU_HAS_GAME=False`), and a per-app
`GpuPreference=2` Windows setting (`DGPU_HAS_GAME=False`). The cause is that the engine creates a
**native D3D8** device, which this NVIDIA driver does not route to the discrete GPU.

[VERIFIED] The `d3d8to9` proxy (v1.16.0, `122928CF...`) puts the game on the GTX 1650 Ti:
`nvidia-smi` then lists `...last-stand-replay\Generals.exe` as `C+G` at 32% / 74 MiB.

[VERIFIED] Matched-state heavy comparison (same binary, same flags, calibration 7,704 us Intel vs
7,697 us GTX -- machine speed equal within 0.1%), exact `04C62655`/983 commands:

| Stage | Intel D3D8 | GTX D3D9 | Delta |
|---|---:|---:|---:|
| occlusion/stencil | 6.042 | **0.873** | -5.17 |
| particles | 0.489 | 0.343 | -0.15 |
| sorted | 1.020 | 0.552 | -0.47 |
| translucent | 0.290 | 0.043 | -0.25 |
| `views` total | 11.214 | **3.227** | -7.99 |
| client / draw | 13.53 / 12.55 | 5.32 / 4.49 | -8.2 / -8.1 |
| logic | 32.85 | 31.00 | -1.85 |
| **heavy interval** | **46.87** | **36.80** | **-10.07** |

[INFERRED] The GPU path is a real ~8 ms draw lever and a ~1.9 ms logic lever (less GPU memory
contention), but it is **not sufficient alone**: 36.80 ms is still 3.5 ms short of 33.33. On the
GTX the occlusion pass is already cheap (0.87 ms), so the `ZH_SKIP_OCCLUDED` visual trade loses
most of its value there; the remaining wall is logic (~31 ms).

## Measurement variance and the calibration fix

[VERIFIED] Identical binaries produce widely different heavy windows. Same build, same flags,
full visuals: `allcontrol` 37.12 ms (logic 27.23, client 9.47, draw 8.70) vs `dgpucontrol` 46.87 ms
(logic 32.85, client 13.53, draw 12.55). The 30.5 FPS trade run did not reproduce: `alltrades`
32.76 ms vs `alltrades2` 42.19 ms (logic 37.09, path 16,308 us), exact CRC in both.

[VERIFIED] A fixed integer workload (2M multiply-adds, logged every 100 frames as
`ZH_CALIB_LOG`) varies **1.43x** in one run (7,208-10,337 us) and tracks little frame-to-frame
logic variation (corr -0.10 over 9,200 frames). Single-run deltas below ~2 ms are therefore not
conclusive; A/B must be repeated or interleaved.

[VERIFIED] Interleaved A/B implemented: with `ZH_AB_INTERLEAVE=1` each visual-trade gate flips on a
schedule, so both conditions are sampled inside one run and drift cancels. CRC is unaffected
(client-only gates).

[VERIFIED] One-frame alternation **aliases through the present pipeline**: in the GTX heavy window
the gates clearly worked (`flush` occluded 0.000 on skip frames vs 2.219 render, particles 0.007 vs
0.328, sorted 0.001 vs 0.586), yet `draw`/`client` appeared *higher* on the skip frames (6.42/7.36
vs 2.38/3.24) -- the heavy frame's cost was paid on the following frame's present. The schedule is
therefore **60-frame blocks**, not parity.

[VERIFIED] The registry per-app GPU preference was removed and the game still ran on the GTX
(`nvidia-smi` 30% / 74 MiB, `C+G`): the `d3d8to9` proxy alone is sufficient and portable. No
system/registry change is required for the discrete GPU.

## Block-interleaved A/B on the GTX (drift-free)

[VERIFIED] `ZH_AB_INTERLEAVE=1` now flips the three trade gates in 60-frame blocks. One GTX run,
heavy window, exact `04C62655`/983 commands:

| Metric | skip blocks (n=240) | render blocks (n=241) | Delta |
|---|---:|---:|---:|
| interval | **32.41** | 40.91 | -8.51 |
| logic | 28.62 | 32.81 | -4.19 |
| client | 3.34 | 7.52 | -4.18 |
| draw | 2.42 | 6.64 | -4.23 |
| `views` | 1.15 | 5.43 | -4.28 |
| flush occluded / particles / sorted | 0.000 / 0.007 / 0.001 | 2.226 / 0.366 / 0.784 | -3.37 |

[VERIFIED] The heavy window itself ramps hard: early blocks run 23-28 ms and late blocks 38-49 ms.
Adjacent skip/render pairs in stable phases differ by **+4.46, +4.47, +5.89 ms** (one pair straddles
the ramp at +19.5). The aggregate -8.51 is inflated by that boundary; the honest trade value is
**~4.5 ms** of which ~4.2 ms is client/draw and ~4.2 ms is logic contention.

[INFERRED] GTX + all three trades = **32.41 ms mean (30.9 FPS)** in the skip blocks with exact CRC.
That is the first paired, in-run, reproducible measurement above 30 FPS -- but it costs the three
visual features and the peak blocks still reach ~43 ms, so pacing is not smooth.

## Clean all-trades run on the GTX (corrects the block estimate)

[VERIFIED] All three trades on, no interleave, GTX, calibration 7,463 us, exact `04C62655`/983:
heavy mean **34.59 ms (28.9 FPS)**, p50 31.65, p90 54.99, p99 101.68; logic 30.99, client 3.26,
draw 2.34.

[VERIFIED] Same-build full-visuals GTX run (`wrapped`, calibration 7,697 us): 36.80 ms, logic
31.00, client 5.32, draw 4.49. At **matched logic (31.0)** the trades are worth **2.2 ms**, not the
4.5 ms implied by the block-interleave skip population -- that population sat at logic 28.62.

[INFERRED] Correction: overall the trade's draw saving ranges 2.2-4.2 ms depending on the draw
regime (2.34 vs 4.49 client/draw here; 2.42 vs 6.64 in the block run), and the clean all-trades
heavy mean is **28.9 FPS**, not 30.9. The 30 FPS target is not reached by the three trades alone.
p50 (31.65 ms = 31.6 FPS) is inside the budget; the mean is dragged by heavy spikes (p90 55 ms).

## Behaviour-preserving HUD cache (measured, negligible)

[VERIFIED] `ZH_UI_TEXT_CACHE=1` caches the game-clock and system-time strings (they change once per
second, the engine re-formats and re-measures them every frame). Block-interleaved A/B, full
visuals on the GTX, exact `04C62655`/983: client **3.254 vs 3.317 ms (-0.062)**, in-game UI
**0.594 vs 0.612 (-0.017)**. Real but negligible; it cannot contribute to the ~1.3-3.5 ms gap.

## Where the heavy mean comes from: a 49-frame tail

[VERIFIED] Same two GTX runs, heavy window split at the top-10% interval threshold:

| Frame class | Interval | Logic | `l_ai` | Client | Path |
|---|---:|---:|---:|---:|---:|
| slowest 49 (`wrapped`) | 78.9 | 72.8 | 33.5 | 5.41 | 26,872 us |
| fastest 432 | 32.0 | 26.3 | 12.8 | 5.31 | 13,297 us |
| slowest 49 (`allgtx`) | 76.6 | 72.7 | 33.3 | 3.44 | 28,143 us |
| fastest 432 | 29.8 | 26.3 | 12.9 | 3.24 | 13,192 us |

[VERIFIED] Those 49 frames carry **22-23% of the total heavy time**. They are not a request-count
burst (23.0 vs 19.5 requests/frame); they are heavy per-search and AI cost. The worst frames are
single searches: frame 17,343 path 62.5 ms with one **48.9 ms** search (17,059 expansions), frame
17,280 one **50.0 ms** search; `usec_max` averages 17,400 us on slow frames vs 7,396 on fast.

[INFERRED] **30 FPS is a tail problem, not an average-cost problem.** Bringing the slowest 10% to
fast-frame cost would save ~4.8 ms: `wrapped` 36.80 -> ~32.0 ms (31 FPS) and `allgtx` 34.59 ->
~29.8 ms (33.5 FPS). Roughly 2.1 ms of that is AI-state work and 1.5 ms path search. The remaining
levers are therefore (a) an expansion bound on the ordinary/internal search (behaviour trade, the
closest-search cap is precedent), or (b) smoothing the AI/path bursts. The HUD cache is not part of
it (0.06 ms measured).

## Ordinary-search cap (rejected: retry storm)

[VERIFIED] `ZH_PATH_SEARCH_CAP=10000` bounds the ordinary `internalFindPath` expansion loop (the
gate already existed, default 0 = unlimited). GTX, full visuals: heavy **45.00 ms (22.2 FPS)** vs
36.80 uncapped, logic **41.73** vs 31.00, p90 69.5 vs 56.3; CRC `99BEDEC5...`; commands
**2,331 vs 983** with `zone_mismatch` **652 vs 41** (`search_failed` 84 -> 14).

[INFERRED] Capping the tail's big searches is counterproductive: a failed search is re-issued
immediately, so the cap converts one long search into several short ones plus extra AI/command
work (+10.7 ms logic). This matches the earlier rejections (3,000-cell budget, closest cap 2,000).
The tail cannot be cut by bounding the solver; it would need a faster search (incremental/parallel,
multi-session) or a scenario-level change.

## Packaged configuration (staged playtest)

[VERIFIED] The verified engine is staged as `build/engines/t112-playtest.exe` and copied to
`game/last-stand-replay/Generals.exe`, SHA-256 `35442E24...`; build output, staged copy and the copy
in the game folder are byte-identical. The per-search memo is default-on, and `d3d8to9` v1.16.0
(`122928CF...`) is installed in the replay copy.

[VERIFIED] `tools/play-t120.ps1` gains `-Performance`: it sets `ZH_SKIP_OCCLUDED`,
`ZH_SKIP_VOLUMETRIC` and `ZH_SKIP_PARTICLES` as an **opt-in visual trade** (without the switch the
build keeps full visuals). Measured cost on the GTX: heavy **34.59 ms / 28.9 FPS** vs 36.80 / 27.2
full visuals; whole run **37.4 vs 34.7 FPS**.

[VERIFIED] A 300-frame smoke run of the staged build with the profile reached `frame=300 sync=ok`
at 1920x1080 (`SMOKE_EXIT=0`) and left the staged hash unchanged. GTX placement for this binary is
established by identity: it is byte-identical to the build output that `wrapped`/`allgtx` ran while
`nvidia-smi` listed `Generals.exe` as `C+G` at 30-32%.

[INFERRED] The packaged configuration is reversible: `tools/play-t120.ps1 -Restore` puts the retail
exe back, `-Performance` is opt-in, and `tools/apply-d3d8to9.ps1 -Action Remove` removes the proxy.

## Faster-solver feasibility: the group workload is 3 goals over 983 searches

[VERIFIED] The formation command log for the heavy window (all 983 rows fall in frames 16919-17399)
contains only **3 distinct destinations** (requested 452, 271 and 260 times) and **55 distinct
starts**, i.e. **55 unique (start, goal) pairs**. Average 327.7 searches per goal.

[INFERRED] The redundancy is in *goals*, which is the textbook case for a goal-rooted flow field or
backward Dijkstra: one search per goal could answer all starts. But two of this project's own
measurements constrain that design:

- `TTL-30` route reuse was **slower** (44.78/54.26/48.03 vs 36.12/40.63/37.66 ms for TTL-20)
  despite fewer misses: longer reuse follows routes computed against stale unit occupancy, and the
  downstream re-pathing/collision cost exceeds the saved search.
- The route-cell guard captured only 181 exact routes and rejected 596 as unsafe (0.19 ms/tick of
  777 opportunities), so exact reuse with a conservative guard is not viable either.

[INFERRED] Any faster solver must therefore model **dynamic occupancy** (units move), not just
terrain. That rules out a pure terrain-only flow field and points at an incremental search that
updates costs (D* Lite style) or a field rebuilt only when the occupancy stamp changes. This is a
multi-session project; the first milestone is to measure how often the local occupancy stamp changes
along the 55 cached corridors, which bounds how much reuse is safe.

## Group-cache miss anatomy: a one-frame TTL shortfall

[VERIFIED] `ZH_GROUP_KEY_LOG` (new per-call predicate logger; `ZH_GROUP_CACHE_LOG` was already taken
by an unrelated 20-column route-validation writer, so the first attempt produced a corrupted file)
over the heavy window: **1,764 calls, 1,472 hits (83.4%), 292 misses**. Revision was constant (563)
throughout, so revision changes cause **zero** misses. Of the 292:

| Cause | Count |
|---|---:|
| same key, TTL expired | **224** |
| -- age exactly 21 frames (TTL = 20) | 191 |
| -- age 24 | 25 |
| different key hashing into the slot | 68 |
| revision change | 0 |

[INFERRED] The 55 routes are re-requested on a ~21-frame cadence and the 20-frame TTL expires one
frame before each repeat. Raising the TTL to 24 should convert ~218 of 224 re-searches into hits
(~3-7 ms/frame of group search at 5-15 ms per miss). Whether that is safe depends on how often the
recomputed route differs from the cached one, which is the next measurement.

## TTL 24 rejected: the 20-frame TTL is the safety boundary

[VERIFIED] `ZH_GROUP_PATH_CACHE_TTL=24` on the GTX at full visuals: heavy **42.91 ms (23.3 FPS)** vs
36.80, p50 36.74 vs 33.57, p90 69.5 vs 56.3, logic 34.10 vs 31.00, path 16,424 vs 14,680 us. Cache
hits did **not** rise (1,476 vs 1,472) and misses rose (315 vs 292); behavior diverged
(`F64D5008` vs `04C62655`), with commands 966 vs 983 and `goal_width` 51 vs 129.

[INFERRED] Reusing a 21-frame-old route changes unit movement enough to diverge the simulation, which
in turn produces a different request mix -- so the extra reuse does not even show up as hits. The
20-frame TTL is therefore not an off-by-one defect: it is the boundary where a cached route stops
matching what the engine would recompute. The 292 misses are **necessary recomputations**, not
wasted work, and the group cache is at its safe limit.

[INFERRED] This settles the solver milestone-1 question in the negative for *avoiding* work: a faster
solver must make each of those ~292 re-searches **cheaper** (incremental state reuse across the
~21-frame cadence, D* Lite style) or run them in parallel. Extending cache lifetime is closed.

## Prefetch worker is capped at ~0.5 ms: the path budget is the ordinary searches

[VERIFIED] `ZH_GROUP_KERNEL_SYNC` logs every group-kernel run (the `replaceGroupKernel` path). In the
heavy window of the GTX full-visuals run: **90 kernel runs in 481 frames** (0.19/frame), total
**243.5 ms = 506 us/frame**, per-frame p50 1,350 us, p90 9,754 us, max 16,542 us. Total path there is
**14,680 us/frame**, so the group kernel is **3.4%** of the path budget.

[INFERRED] A prefetch worker that removes group-search latency entirely therefore buys at most
~0.5 ms/frame on average (and only on the ~19% of frames that run a kernel at all). It cannot close
the ~3.5 ms gap. The path budget is dominated by the ~20 small ordinary/closest/attack searches per
frame (~500-700 us each), and those have **0% exact repeats**, so they cannot be prefetched on a
recurrence cadence.

[INFERRED] That leaves only within-frame parallelism for the ordinary searches, whose blockers are
already measured: per-search input is 155 us with 100% parity but only **42.1% ready** in time, and a
bounded per-path wait was measured slower than serial (16,692 vs 13,722 us/frame; full run 19,987 vs
16,399, CRC `9D9A905B`, commands 981 vs 983). Prefetch (this milestone) and bounded-wait (already
rejected) are the two ways to use a worker here, and both are now measured as insufficient.

## Admissible heuristic (rejected: the overestimate is load-bearing)

[VERIFIED] Both searches use `10*max + 5*min`; with orthogonal 10 / diagonal 14 the admissible octile
bound is `10*max + 4*min`. Implemented behind `ZH_HEURISTIC_ADMISSIBLE=1` in **both**
`PathfindCell::costToGoal` (serial) and `workerGroundSearch::heuristic` (kernel). GTX, full visuals:
heavy **56.60 ms (17.7 FPS)** vs 36.80, logic **53.13** vs 31.00, `l_ai` **33.12** vs 14.94, path
**31,332** vs 14,680 us, expansions **10,955** vs 6,759 (+62%); CRC `F9AAA3E5`, commands **2,794**
vs 983 with `zone_mismatch` **954** vs 41.

[INFERRED] The retail overestimate is a deliberate greediness choice: it focuses the search at the
cost of optimality. Making the bound admissible expands far more nodes and changes routes, which
triggers mass re-planning. This closes the last algorithmic lever on the 14 ms path budget that did
not require a redesign.

## Redesign feasibility bound (what a working job system must achieve)

[VERIFIED] Heavy path budget 14,680 us/frame over 19.9 requests/frame = **738 us/search**; the
per-search input (155 us) is 21% of a search, so paying every input on the main thread costs
**3.08 ms/frame**.

[INFERRED] To recover the ~3.5 ms gap, the serial 14.68 ms must become **<=11.2 ms wall including
input preparation**, i.e. a **~1.8x speedup on 4 cores (~45% efficiency)**. That is modest, so the
prize is physically reachable. The three prototype failures (bounded wait 16,692 vs 13,722 us; batch
14,651 vs 13,722 with CRC divergence; shared input parity 59.1%) point at implementation quality --
worker efficiency, serial fallback on misses, and apply-order -- not at the arithmetic.

[INFERRED] Page-diff propagation into an immutable snapshot addresses only the input half (3.08 ms)
and not the three measured failure modes; parity is already 100% with per-search input. A redesign
must therefore be a real same-frame job system (bounded queue, no serial fallback on the common
path, deterministic apply order), which is a multi-month project.

## Page-diff validation outcomes: changed pages are only 8% of losses

[VERIFIED] The existing page-diff validation shadow
(`artifacts/2026-11-20-last-stand-worker-search/on-worker-search-workers.csv`, stage C, 495 claimed
jobs) resolves as:

| Outcome | Count | Share |
|---|---:|---:|
| accepted, exact `match=1` | 307 | **62%** |
| unknown-unit (object gone; job correctly moot) | 133 | 27% |
| **changed-pages (parity loss)** | **40** | **8%** |
| unfinished at claim (readiness) | 15 | 3% |

[VERIFIED] Per-job validation cost is small: 2.2 us accepted and 6.6 us changed-pages, against a
0.3-0.7 us reference.

[INFERRED] Page-diff propagation is **not** the dominant blocker for worker parity -- changed pages
account for 8%, while object lifetime (27%) and readiness (3%) dominate, and 89% of jobs already
resolve correctly (accepted plus moot). The earlier "shared-input parity 59.1%" figure measured a
*different* thing (shared per-frame input without per-job validation). A redesign should therefore
attack (a) the 3% unfinished/readiness timing and (b) the apply-order semantics, not spend its first
slice replaying page diffs. These numbers predate the current build and should be re-verified on the
heavy window before implementation.

## Re-verifying the lane-validation split (tooling note)

[VERIFIED] The native-worker lane shadow is gated by **three** environment variables, not one:
`ZH_NATIVE_PAGE_LOG` (creates `nativePageSnapshot::early`/`afterScripts`, without which
`submit()` returns before logging), `ZH_EARLY_QUEUE_LOG` (the queue-candidate probe), and
`ZH_NATIVE_WORKER_LOG` (the lane records). With only the worker log set, the run produces a
header-only `workers.csv` and no error; with page+queue+worker it captures frames 16800-17277.

[VERIFIED] With page and queue logs only, the probe captured 74,586 rows in the heavy window
(`L` 24,559 candidates before dispatch, `M` 20,795 at dispatch, plus `A`/`E`/`U`/`S`/`R`/`B`/`Q`/`K`)
while `workers.csv` stayed header-only -- proving the candidates exist and the missing gate was the
page snapshot, not an empty queue.

## Current-build lane validation: 77.7% accepted, 7.0% changed pages

[VERIFIED] With all three switches (`ZH_NATIVE_PAGE_LOG` + `ZH_EARLY_QUEUE_LOG` +
`ZH_NATIVE_WORKER_LOG`) the lane shadow ran on the staged `35442E24` engine: 973 validation events
resolved as **756 accepted with exact `match=1` (77.7%)**, 139 unknown-unit (14.3%), **68
changed-pages (7.0%)**, 10 unfinished (1.0%). Validation cost 1.5 us accepted, 5.1 us changed pages.

[VERIFIED] The shadow is **not parity-neutral**: the run's CRC is `BD4F07ED` (the same signature as
the earlier queue-batch divergence), so these are mechanism numbers from a perturbed trajectory, not
a stock-behaviour measurement.

[INFERRED] Page-diff remains a minor failure mode (~7%) on the current build, consistent with the
2026-11-20 log (8%), while acceptance is higher (77.7% vs 62%) and readiness loss is only 1%. A
worker redesign should therefore not spend its first slice on page-diff replay; the unresolved 14%
is object lifetime, and the prototypes' regressions point at apply order/worker efficiency.

## The lane shadow is not a parity oracle: the page snapshot alone diverges

[VERIFIED] Bisect of the `BD4F07ED` divergence:

| Run | Switches | CRC |
|---|---|---|
| `laneshadow2` | `ZH_EARLY_QUEUE_LOG` + `ZH_NATIVE_WORKER_LOG` (no page snapshot) | **`04C62655` exact** |
| `laneshadow4` | `ZH_NATIVE_PAGE_LOG` + `ZH_EARLY_QUEUE_LOG` (**no worker**) | **`BD4F07ED`** |
| `laneshadow3` | page snapshot + queue + worker | `BD4F07ED` |

[INFERRED] The queue probe is benign, the worker threads are **not** implicated, and the divergence
comes from the **page-snapshot path alone**. Reviewed suspects are read-only: `capture()` uses
null-safe accessors (`getType`/`getFlags`/`getZone`/`getPinched` are non-`m_info` fields;
`getPosUnit`/`getGoalUnit`/`getObstacleID` guard `m_info`), and the `changed()` memo-invalidation hook
runs identically with or without a snapshot. Remaining suspects are heap/allocation interaction or
the write-hook ordering; isolating it needs code instrumentation, not more runs.

[INFERRED] Consequence: the 77.7%/14.3%/7.0%/1.0% split and the older 62/27/8/3 split are
**mechanism-only** numbers from a perturbed trajectory. Any parity gate for a real worker must run
with the shadow off, or the shadow must first be made CRC-exact.

## The page-snapshot divergence is environmental, not corruption

[VERIFIED] The snapshot audits its frozen copy against the live pathfinder grid at 15 checkpoints in
`laneshadow4` (`pages.csv`): **`mismatches` is 0 at every one**, while `changed_cells` logs the
expected 452-655 cell diffs between the early and dispatch snapshots. The frozen copy is therefore
faithful and no writes are lost.

[INFERRED] Since `capture()` is read-only (null-safe accessors, pure `getObstacleID`), the audit is
clean, and only `changed()`'s memo-invalidation hook runs in both configurations, the `BD4F07ED`
divergence must be an **environmental** side effect of running the diagnostic -- building a 286-page
grid (about 18k cells) shifts heap/timing state, and something in the simulation is sensitive to it
(pointer-keyed container ordering is the usual culprit). It is not a defect in the validation
logic, and it is not fixable by "removing a state mutation".

[INFERRED] Practical consequence: the lane shadow cannot be a CRC-exact oracle as written, and the
splits stay mechanism-only. That does **not** block the solver work: a real worker's parity gate must
run with the shadow off, and page-diff was already shown to be ~7% by two independent logs.

## Kernel closest-reachable support (additive, verified neutral)

[VERIFIED] `workerGroundSearch` now supports nearest-reachable results, gated so no existing caller
changes: `Query::closest` (default false) makes an unreachable goal return the nearest reachable
chain; `Result::closest` marks it; `Workspace::run` tracks the closest closed node by the same
heuristic and reuses the goal-first parent walk, setting `goalCost` to that node's cost.

[VERIFIED] Regression gate on the staged engine with no caller opting in: exact `04C62655`/983
commands, path **14,556** vs 14,680 us control, heavy 34.18 vs 36.80 ms (fast-client regime:
client 3.27 vs 5.32). Behaviour is unchanged.

[INFERRED] The remaining port is the `findClosestPath` wiring: build the same Query/Access used by
the ground kernel, set `closest = true`, convert `raw` to a `Path`, and compare route/cost parity
against the serial search with the lane shadow off. The object-level predicates
(`checkDestination`, `canPathThroughUnits`, crusher/locomotion facts) must enter the query contract
before that comparison can be exact.

## Closest shadow: first parity data

[VERIFIED] Implemented `ZH_CLOSEST_SHADOW`: at each `findClosestPath` return it runs
`workerGroundSearch` with `closest.enabled`, the serial cost-weighted `pathCostMultiplier`, and an
`Access` built from the live cells/zone-manager/terrain, then logs start/goal cells, radius, serial
node count and cost, kernel steps/cost/usec, and both end cells. Unlike the page-snapshot diagnostic
it is **CRC-neutral**: the run reproduced exact `04C62655`/983.

[VERIFIED] Whole replay: 847 calls, kernel returned a chain on 100%, endpoint match 578/847 (68%);
for the 572 calls with more than one kernel step the endpoint match is **426/572 (74%)**. Cost match
is **0%** -- the two searches' cost accounting differs (sample: serial cost 5 vs kernel `goalCost` 0).
275 calls (32%) return a single step (no search). Kernel time p50 5 us, p90 31 us, max 5,023 us.

[VERIFIED] Heavy window (16,919-17,399): 56 calls, endpoint match **55/56 (98%)**, cost match 0,
kernel p50 9 us.

[INFERRED] The harness is working and is safe to run in production runs. The 74% non-trivial endpoint
match is a real gap, not a harness artefact: the remaining 26% need classifying by distance before
the `Access`/admission predicates can be corrected. Cost parity needs a like-for-like comparison
(kernel `goalCost` for the matched node vs the serial `costSoFar` at the same cell) rather than the
current cross-definition comparison.

## Closest mismatch classification: the kernel is one cell *better*, not wrong

[VERIFIED] Of the 572 non-trivial `findClosestPath` shadow calls, 146 (26%) chose a different end
cell. Every one is within **1.0-1.4 cells** of the serial end (p50 1.0, max 1.4; 100% within 1.5),
and in **146 of 146** the kernel's end is **closer to the goal** than the serial end -- never farther.

[INFERRED] This is not a routing or admission failure: the kernel finds a marginally better closest
cell and the serial search stops one cell farther out. The cause is the cost model. The shadow's
`Access` returns a default `Movement` and width `0`, so kernel costs omit the serial search's
terrain/width/ally terms; with a smaller cost penalty the kernel prefers the closer cell. The serial
`score = distSqr + cost^2 * factor * multiplier` trades a cell of distance for a cheaper route, and
that trade is what the shadow is missing.

[INFERRED] Parity therefore requires the `Access` to carry the **real movement terms** --
`clearCellForDiameter` width, ally fixed counts, pinched/cliff costs, and the admission predicates
(`checkDestination`, `canPathThroughUnits`, crusher/surfaces) -- not a scoring change. The remaining
gap is the contract work, now with a precise target: eliminate a 1-cell, cost-driven difference.

## Closest-search volume: 0.34 ms/frame, so the swap is not worth it

[VERIFIED] With `serial_us` logged for every `findClosestPath` call (this build), the heavy window
has **56 calls over 43 frames (1.3/frame)**. Serial cost per call p50 233 us, p90 784 us, p99 5,611
us, max 14.6 ms; **per frame mean 0.34 ms** (p90 0.71 ms). The kernel's equivalent is 0.054 ms/frame.

[INFERRED] A perfect closest-kernel swap therefore saves about **0.3 ms/frame** -- under a tenth of
the ~3.5 ms deficit, and not worth the behaviour trade or the wiring risk. The earlier census figure
of "findClosestPath 3.59 ms/frame" **does not hold for this heavy window**; it was not re-measured
before the swap was called promising. Correcting the record: the path budget is
ordinary/attack/other searches (~13.6 ms of 14.5 ms), not closest.

[INFERRED] This also explains why the kernel looked 50x faster: the per-call ratio is real, but the
call volume is 1.3/frame, so the frame-time effect is negligible. Any further path work must target
the ordinary searches, which have 0% exact repeats and measured readiness blockers.

## Scan-timer trade: aggressive values end the battle early

[VERIFIED] The AI scans were already scheduled, not polled: `GuardEnemyScanRate` defaults to 15
frames, staggered with `GameLogicRandomValue`, and the idle mood check is gated by
`m_nextMoodCheckTime` with `m_forceIdleFramesCount = 1` (idle units check every frame). Added
`ZH_FORCE_IDLE_FRAMES` and `ZH_GUARD_SCAN_RATE` overrides in `AI::reset`.

[VERIFIED] With `ZH_FORCE_IDLE_FRAMES=10` and `ZH_GUARD_SCAN_RATE=30` the replay **ends at about
frame 8,500** (score screen follows; `replay_finished`, no heavy window, `commands.csv` not written).
Slower detection does not just add lag -- it changes the battle outcome.

[INFERRED] The scan interval is a gameplay-sensitive lever, not a free performance knob. A usable
value must be the mildest one that still completes the replay; the sweep starts at idle every 3
frames with the guard rate untouched.

## Scan-timer trade: closed (both values end the battle early)

[VERIFIED] `ZH_FORCE_IDLE_FRAMES=10` + `ZH_GUARD_SCAN_RATE=30`: replay ends ~frame 8,500.
`ZH_FORCE_IDLE_FRAMES=3` alone: replay ends ~frame **9,300** (`replay_finished`, score screen, no
`commands.csv`, heavy window never reached).

[INFERRED] Changing the scan cadence changes the battle outcome, not just its speed, even at a 3x
interval. The idle/guard scan schedule is therefore **behaviourally load-bearing** and cannot be
traded for frame time within this target scenario: any value that saves measurable time also ends
the replay before the heavy window. Lever closed. Note the engine already does the hybrid the idea
describes (guard scans every 15 frames, staggered; idle mood checks gated by `m_nextMoodCheckTime`),
so the remaining scan cost is the scheduled scans themselves, not redundant polling.

## Congestion-pricing sweep: ally costs are load-bearing

[VERIFIED] `ZH_STATIC_ROUTING=1` (remove the ally congestion terms; terrain/buildings still priced):
the replay completes at 17,402 but is **worse** -- heavy **43.75 ms (22.9 FPS)** vs 36.80, logic
39.68 vs 31.00, `l_ai` 25.92 vs 14.94, path **22,329** vs 14,680 us, expansions **12,094** vs 6,759,
commands **1,758** vs 983 (`zone_mismatch` 392 vs 41).

[VERIFIED] `ZH_ALLY_COST_PCT=33` (congestion cost 3 -> 1 per ally): the battle **ends ~frame 8,400**
(score screen, no heavy window).

[INFERRED] The ally terms are not "traffic pricing" that can be deleted: they are the engine's only
congestion control. Removing them makes routes straighter but floods crowded cells, raising
expansions and re-planning; reducing them changes the battle outcome outright. The modern
static-routing model depends on its other half -- local steering/pushing -- which this engine only
has in a weak "move allies away" form. A static-model port therefore requires building that
avoidance layer, not just removing costs.

## Congestion-pricing sweep: 66% is a strong candidate

[VERIFIED] `ZH_ALLY_COST_PCT=66` (ally congestion cost 3 -> 2 per fixed ally) completes the full
replay (17,402) and measures heavy **33.74 ms (29.6 FPS)** vs the 36.80 ms control, with logic
**25.16** vs 31.00, `l_ai` **11.96** vs 14.94, path **9,778** vs 14,680 us (-33%), expansions
**5,036** vs 6,759 (-25%) and commands **523** vs 983 (`zone_mismatch` 20 vs 41, `search_failed` 14
vs 84). Calibration matched (7,644 vs 7,697 us, 0.7%), and the 66% run was in the *slower* client
regime (8.13 vs 5.32 ms), so the interval gain is if anything understated.

[INFERRED] Charging less for friendly congestion produces *simpler* routes and far fewer
re-planning events in this scenario, which is the opposite of the 0% result (43.75 ms) and different
from 33% (battle ends ~8,400). The response is not monotonic, so this must be confirmed by repeat and
then combined with the visual trades; if it holds, it is the first lever that attacks the 14.7 ms
path budget at unchanged visuals.

## Congestion pricing 66%: first configuration above 30 FPS at unchanged visuals

[VERIFIED] Two independent `ZH_ALLY_COST_PCT=66` runs produced **identical CRCs**
(`695F3403` at 17,100, `5B2954C4` at 17,200) and identical `commands.csv` (64,429 bytes) -- the
behaviour is deterministic and reproducible.

| Heavy window | control | 66% run 1 | 66% run 2 |
|---|---:|---:|---:|
| interval | 36.80 ms (27.2 FPS) | 33.74 (29.6) | **30.06 (33.3 FPS)** |
| logic | 31.00 | 25.16 | 25.52 |
| `l_ai` | 14.94 | 11.96 | 11.80 |
| path | 14,680 us | 9,778 | **9,684** |
| client | 5.32 | 8.13 | 4.30 |
| calibration | 7,697 us | 7,644 | 7,393 |

[VERIFIED] The second run had the faster client regime (4.30 vs 5.32) and a 4% faster machine
(7,393 vs 7,697 us calibration), which explains part but not all of the gap; the path (-34%) and
logic (-18%) reductions are regime-independent and reproduce exactly.

[INFERRED] This is the first lever that attacks the 14.7 ms path budget at **unchanged visuals**:
charging 2x instead of 3x diagonal per fixed ally simplifies routes (expansions 6,759 -> 5,036) and
cuts re-planning (commands 983 -> 523, `search_failed` 84 -> 14). Behaviour diverges from retail
(`695F3403` vs `04C62655`) -- it is a gameplay trade (units are less averse to friendly crowds) and
is the change the user preferred the feel of at 33%.

## Combination: 29.01 ms (34.5 FPS) with trades on top of 66%

[VERIFIED] `ZH_ALLY_COST_PCT=66` plus the three visual trades: heavy **29.01 ms (34.5 FPS)**, p90
45.42, logic 25.40, client 3.26, draw 2.29, path 9,770 us, calibration 7,522 us. All three 66% runs
share the same logic CRC (`695F3403`) because the trades are client-side only.

| Heavy | control | ally 66% | ally 66% + trades |
|---|---:|---:|---:|
| interval | 36.80 (27.2 FPS) | 30.06 (33.3) | **29.01 (34.5)** |
| logic | 31.00 | 25.52 | 25.40 |
| draw/client | 4.49 / 5.32 | 3.73 / 4.30 | 2.29 / 3.26 |
| path | 14,680 us | 9,684 | 9,770 |

[INFERRED] The gains stack: the path change is logic-side and the trades are draw-side. Part of the
29.01 comes from a faster machine (calibration 7,522 vs 7,697, 2.3%) and the fast client regime, but
the logic/path reductions reproduce bit-identically across runs.

[VERIFIED] Packaged for playtest: staged engine `9660EB14...`, and `tools/play-t120.ps1` gains
`-AllyCost 100|66|33|0` (default 100 = retail), combinable with `-Performance`.

## Survival sweep of the congestion price

[VERIFIED] Where the battle resolves, by `ZH_ALLY_COST_PCT` (each a full replay from frame 0):

| Ally cost | resolves at | heavy window reached |
|---|---|---|
| 0% | 17,402 (completes) | yes, but slower overall (43.75 ms) |
| 33% | ~8,400 | no |
| 50% | ~15,600 | no |
| 60% | ~16,700 | no (200 frames short) |
| **66%** | **17,402** | **yes** |
| 100% (retail) | 17,402 | yes |

[VERIFIED] The 33% variant is deterministic: two independent runs produced identical CRCs at every
checkpoint (`3F1588B4` @8,100, `BCAF974D` @8,200, `DA7B9F8B` @8,300, `92E4A144` @8,400).

[INFERRED] Between 33 and 66 the resolution frame rises monotonically with the price -- the less units
respect crowds, the earlier one side collapses. The 0% case completes for a different reason (the
search itself degenerates: expansions 6,759 -> 12,094). **66% is the lowest survivable value found**,
and the gap to 60% is only ~200 frames, so chasing 62-64 would buy a negligible feel difference for
more runs.

## Live skirmish at 33%: measured, and the user's decision

[VERIFIED] A live skirmish recorded at `ZH_ALLY_COST_PCT=33` (152,529 frames; 60,319 with logic
running): overall **38.07 ms mean (26.3 FPS)**; the top-decile load phase (visible objects 237-775,
versus 120 in the replay heavy window) measured **55.01 ms (18 FPS)** with logic 45.19, client 9.21,
draw 7.89. Calibration 7,542 us, comparable to the replay runs.

[VERIFIED] The live session carried roughly **twice the rendered objects** of the replay benchmark,
so its frame times are not comparable to the replay gate.

[VERIFIED] The user played it and judged it *smoother* than the replay variants they watched,
including during nukes and heavy animation; the logged frame times are higher, so the perceived gain
is not explained by the mean (likely steadiness: replay runs hitch at p90 while live play was even).

[DECISION] The user selected 33% as the winner for feel. `tools/play-t120.ps1` now defaults to
`-AllyCost 33`; 66% remains the benchmark value (completes the replay, heavy 30.06 ms / 33.3 FPS,
and 29.01 ms / 34.5 FPS with the three visual trades).

## Limitations

[VERIFIED] `ZH_DEFER_UNIT_READS=1` (defer zone/height reads until the cheap neighbor
checks pass) is behavior-identical (`04C62655`/983 commands) but measured heavy path
**15,194 usec** versus 14,208-14,438 in recent runs; not promoted (neutral-to-worse, within
run variance).

[VERIFIED] The write-log test ran twice and both runs **diverged** (`BD4F07ED`, 109,209-byte
command stream vs 122,319): the page-snapshot/early-queue diagnostics are not behavior-neutral (the
run without the early probe also diverged). The write data is therefore **indicative, not
baseline**. In that trajectory, 219 frames fully pack into two disjoint boxes; **188 have no
cross-lane static writes**, 31 do (630/1,675 writes, 37.6% of writes in packable frames). Combined
with 5-14% packing and a 1.27-1.29x ceiling, the exact 2-lane win is ~2-3 ms and still needs
per-lane state plus page-diff ordering; it is not the path to 30 FPS.

- The replay is CRC-diverged; the measurements are a representative workload, not exact parity.
- The live resource sample reached frame ~8,000, before the 7.5 FPS window; the 7.5 FPS numbers
  come from the retained T-116 attribution logs, not the same process sample.
- The heavy-window absolute interval depends on client background load (draw is inside client):
  `kernelreplace` measured client 10.8 (draw 9.9) and `kernelreplace2` client 4.9 (draw 4.4) on
  identical CRC/command output. The path usec and `l_ai` deltas are the load-independent comparison.
  The earlier "client+draw" sums double-counted the nested draw phase.
- `wpr.exe` could not start its CPU profile without elevation, so there is no function-level
  sampled stack yet. The phase attribution and source flow are sufficient to locate the serial
  logic/path wall.
- One machine (i5-10300H, Intel UHD path); GPU/CPU ratios will differ on other hardware.

## Next checks

1. Run `tools/profile-game-resources.ps1` against a played Last Stand run with Task Manager's
   logical-processor view open; confirm the same one-thread saturation at 7 FPS.
2. Capture an elevated WPR CPU trace with symbols and export `xperf -a profile` to name the
   hottest functions inside the 97 ms path stage.
3. Prototype the pathfinding worker pool with ordered result dispatch and a fixed-input
   validation gate; measure whole-frame FPS, not modeled FPS.
4. Re-test the GTX/d3d8to9 path only after CPU work, to separate the remaining draw cost.
5. Play the staged group-kernel build and compare the live stuck-group rate; the replay's
   command mix improved (`none` 686 vs 663, `search_failed` 84 vs 230) but is not a live result.
6. The heavy window is now 43.98 ms; reaching 30 FPS needs path <= ~4 ms or overlapping the
   ~20 ms draw/client pipeline. The ordinary-path kernel replace ended the match early and is not
   a safe substitute; a narrower ordinary/closest cache is the remaining search lever.
