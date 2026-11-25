# Maintaining formation clearance across searches

- Date: 2026-11-19
- Task: T-112
- Baseline: [move pipeline and dominated width](2026-11-19-last-stand-move-pipeline.md)
- Evidence: [packed and maintained fixtures](../../artifacts/2026-11-19-last-stand-packed-width/manifest.md) and [native candidate](../../artifacts/2026-11-19-last-stand-maintained-width/manifest.md)

## Check cost and update cost

[VERIFIED] A per-search packed-column prototype matched 240,000 randomized
clearance comparisons. Using 526,680 recorded expansion centers and
synthetic cell contents, it took 48.13–50.11 ms across the fixture batches,
versus 31.62–45.26 ms for the scalar scan with the same per-search memo.
Building packed data for every query scope outweighed the read savings
in that fixture.

[VERIFIED] A separate fixture maintains completed width values.
The eager mode recomputes every center touched by a cell edit. The lazy
mode invalidates those centers and computes only values requested again.
The full answer checksums matched for all modes and edit rates.

| Synthetic edits per batch | Scalar with memo | Eager width grid | Lazy invalidation |
|---|---:|---:|---:|
| 16 | 35.82–37.30 ms | 3.32–3.83 ms | 1.66–3.16 ms |
| 64 | 35.00–37.51 ms | 10.45–13.08 ms | 2.99–3.12 ms |
| 256 | 30.30–31.74 ms | 42.58–48.80 ms | 6.61–6.69 ms |

[VERIFIED] These are totals over all batches, and the maintained grid
startup is reported separately. The synthetic lazy startup took
6.31–7.19 ms at the listed edit rates. The fixture uses simple cells and
deterministic mock edits, so its timings do not predict native FPS.

## Native candidate

[VERIFIED] The candidate keeps one byte per center for the six-cell
noncrusher ground case. It invalidates affected entries on terrain or
fixed-flag changes. It uses recorded linear storage layout to filter
mutation hooks to the active ground map. Map setup, reset and recovery
drop the table. A query containing a fixed-unit flag or crossing the
grid edge uses the previous path, including the original occupant and
crushability lookup. This is a conservative condition for a terrain-only
answer.

[VERIFIED] The compiled fixture used the same table and mutation hook
against a stub cell. It matched all 148,437 offered answers and correctly
deferred the other 251,563 cases. Tests used randomized terrain edits,
fixed-flag transitions, sparse and dense changes, and varied map origins.

[INFERRED] Run native verify mode before using its answers to play the
replay. Native coverage, mutation overhead and higher-level synchronization
are the gating evidence. If coverage is poor, the next design can maintain
two inexpensive masks, for terrain and potentially fixed units, while
still resolving occupied cells with live data.

## Native shadow result

[VERIFIED] The 1920×1080 verify replay reached frame 17,402 with sync
active and identical graphics options. `analyze-maintained.py` matched
15,242 route and expansion records and 2,185 formation command receipts
against the previous native run. The original clearance answer controlled
every route.

| Shadow counters | 300 slow-window ticks | Entire recorded census |
|---|---:|---:|
| Tested interior six-cell memo misses | 11,376,522 | 18,394,443 |
| Widths offered and compared | 6,931,580 | 11,172,037 |
| Table entries refreshed | 427,587 | 710,200 |
| Width mismatches | 0 | 0 |

[VERIFIED] The candidate answered **60.9%** of the tested memo misses
in the slow window. This is coverage before moving the lookup ahead of
the memo, and the shadow is not a frame-time comparison.

## Combined native replay

[VERIFIED] The same Win32 Release executable ran both cases with the
dominated-neighbor shortcut enabled. The treatment used maintained
terrain widths before consulting the per-search memo. The binary,
arguments and Options.ini hashes matched. Both reached frame 17,402
with sync active at 1920×1080 and `analyze-combined.py` matched 15,242
path and expansion records and 2,185 formation commands. The treatment
used the maintained table for 20,335,656 of 33,309,119 eligible queries
in the measured window.

| 300-frame window | Control | Maintained width |
|---|---:|---:|
| Average FPS | 9.84 | 17.26 |
| Mean frame interval | 101.65 ms | 57.95 ms |
| p95 frame interval | 140.58 ms | 78.64 ms |
| Formation searches | 36.037 ms/tick | 20.250 ms/tick |
| Individual and closest-reachable searches | 19.010 ms/tick | 11.551 ms/tick |
| Draw scope | 12.860 ms/frame | 9.096 ms/frame |

[VERIFIED] The control was restored from a minimized window before the
timed section. The previous dominated-width treatment measured 17.18 FPS
and 21.163 ms/tick in formation searches. Its individual and closest
searches were 11.518 ms/tick, close to the new treatment. See
[window recovery](../issues/ISSUE-0118-last-stand-maintained-control-exit.md)
and the [timing variation issue](../issues/ISSUE-0116-last-stand-timing-variation.md).

[INFERRED] The wide changes in scopes outside the treatment make this
timing pair unreliable for estimating the clearance gain. The treatment
measurement is usable as a frame-budget reference and stands 24.61 ms
above the 30 FPS average budget. Preserve the binary for a reversed-order
pair with comparable draw and individual search times. Keep the maintained
variant diagnostic pending reproducible timing.

## Extend coverage to occupied footprints

[VERIFIED] The [mixed-width fixture](../../artifacts/2026-11-19-last-stand-mixed-width/manifest.md)
maintains terrain and potentially fixed units in separate masks. It checks
terrain first and resolves the live occupant only when an open cell can
still affect the returned width. It keeps the original single-cell rule.

[VERIFIED] `test-fixture.cmd` matched all 400,000 decisions against the
scalar reference, including live blocking changes with unchanged flags.
Testing candidate widths in descending order reduced live occupant checks
from 843,170 to 161,081 versus the eager mixed implementation. Both used
synthetic map contents and edit sequences.

[VERIFIED] `test-timing.cmd` replayed recorded search centers on synthetic
terrain. With 16 edits per batch, the scalar per-search memo took
44.94–45.57 ms and the maintained mixed masks took 26.30–26.36 ms across
all batches. With 256 edits, the respective times were 49.24–49.67 ms
and 42.32–42.98 ms. The timing includes edits and lookup time using a mock
object resolver. Native parity, coverage and frame-time effect require
separate replay evidence.

[VERIFIED] In the native shadow, `analyze-mixed.py` matched 55,451,639
clearance answers across the full census, including 21,395,588 occupied
footprint decisions, with zero differences. The replay reached 17,402
at 1920×1080 with sync active and matched all 15,242 path and 2,185
command records. Legacy widths controlled gameplay during the shadow.

| Mixed-width shadow | 300 slow-window ticks | Full census |
|---|---:|---:|
| Eligible widths compared | 33,309,119 | 55,451,639 |
| Occupied footprint decisions | 12,973,463 | 21,395,588 |
| Live occupant resolutions | 32,660,878 | 54,245,418 |
| Differences | 0 | 0 |

[INFERRED] The native check recorded about 109,000 live occupant
resolutions per slow-window tick when all occupied queries used the
shadow. The prepared timing variant runs occupied logic only on misses
in the existing per-search memo. Its terrain-only control and mixed
treatment share the same executable and mask maintenance. Both need to
match the recorded paths before using timing to retain the variant.

## Resolve fixed units once per search lane

[VERIFIED] The [scoped blocker fixture](../../artifacts/2026-11-19-last-stand-blocker-cells/manifest.md)
reused 526,680 recorded query centers at each of three synthetic fixed-unit
densities. The per-cell memo cut mock object resolutions by 86.6–92.7%,
but timing overlapped the existing occupied-width memo. The packed lane
variant resolves blockers for a 32-cell column segment when first touched
in a search, then reuses the bit mask to compute the width. It retains the
existing per-search width memo. Query results matched the scalar reference
for every tested center and density, including simulated flag and object
classification changes between searches.

| Nominal synthetic fixed occupancy | Existing occupied-width memo | Packed lane memo |
|---|---:|---:|
| 2% | 32.82–33.81 ms | 28.86–29.52 ms |
| 8% | 45.88–49.03 ms | 28.96–29.06 ms |
| 16% | 48.28–48.70 ms | 29.24–32.41 ms |

[VERIFIED] `start-lane-shadow.ps1 -Action Build` compiled the Win32 Release
preview and recorded its binary hash. The preview has a same-binary
terrain-only comparator. The native shadow must confirm parity before
timing with lane answers enabled. [INFERRED] Lane entries are valid while
the ground and object classifications stay stable within the owning
search. The fixture tests updates between searches. It does not establish
reentrant or concurrent mutation safety.

[VERIFIED] The packed-lane shadow reached frame 17,402 at 1920×1080 with
sync active. `analyze-native.py` matched all 15,242 searches and 2,185
commands. It reported zero differences in 55,451,639 width comparisons,
including 21,395,588 queries for occupied footprints. In the 300-frame
window the lane code resolved 853,898 live occupants, compared with
32,660,878 in the earlier mixed shadow for the same 12,973,463 occupied
queries. This is a **97.4%** reduction in live resolutions. Legacy widths
still controlled gameplay during the shadow. The subsequent timing pair
enabled lane answers in the treatment.

[VERIFIED] Both timing runs reached frame 17,402 at 1920×1080 and
matched all 15,242 searches and 2,185 commands. `analyze-native.py`
confirmed identical engine and graphics inputs except the width mode.

| Native width mode | Average FPS | Mean frame interval | p95 interval | Formation searches |
|---|---:|---:|---:|---:|
| Terrain-only control | 17.24 | 57.99 ms | 79.12 ms | 20.655 ms/tick |
| Packed lanes for occupied widths | 16.42 | 60.90 ms | 84.75 ms | 20.533 ms/tick |

[INFERRED] Formation timing changed by just **0.122 ms/tick**. Draw and
other search clocks were both higher in the lane run, so the FPS difference
cannot be assigned to the lane logic alone. The saved occupant resolutions
did not establish a practical frame-time gain. The next experiment uses
the terrain-only control in both runs.

## Empty footprints in unit searches

[VERIFIED] The [unit-footprint mask](../../artifacts/2026-11-19-last-stand-unit-mask/manifest.md)
uses a separate ground-presence bit for every unit flag, including moving
units and reserved goals. The legacy movement check accepts an entirely
empty in-bounds footprint and leaves all its output flags clear. The
destination shortcut also requires clear terrain and excludes the
aircraft-specific destination branch. Occupied, clipped and non-ground
footprints still use the original check.

[VERIFIED] `test-fixture.cmd` matched 540,000 scalar decisions using the
same header, with live flag and terrain mutations, nonzero map origins,
word boundaries, and rectangles beyond the map edge. Generation of the
native validation source and script succeeded. Runtime eligibility,
parity, update overhead and frame-time effect remain open.

[INFERRED] This is independent of the formation-specific occupied-width
lookup. It targets part of the measured 11.55 ms/tick in ordinary and
closest-reachable pathfinding. The 300-frame native shadow will measure
coverage before spending two additional runs on an A/B.

## Successful searches still dominate

[VERIFIED] `residual-by-outcome.py` split the outer search scopes from
the completed native Direct3D 8 reference, which averaged 57.684 ms
per frame. Successful formation routes consumed 17.437 ms/tick across
1,629 searches. All failed searches together consumed 6.082 ms/tick.
Subtracting their full recorded cost would leave 51.603 ms per frame
(19.38 FPS). This is a bound from the observed trace with other work held
fixed. It prioritizes work that returns usable formation routes.

[VERIFIED] `measure-zone-geometry.py` found that 337,133 of 526,680 recorded
expansion centers in 90 sampled searches shared a 10-cell zone block with
all eight neighbors. This measures geometry, before checking the actual
zone passability and map layer. The prepared shortcut reuses a positive
zone decision in that case. It also uses direct ground addresses for all
eight neighbors of interior ground cells. The compiled fixture checked
all neighbor coordinates at 4,480 zone-interior and 4,928 map-interior
centers, including offsets and map edges.

[INFERRED] The next unit-footprint shadow also verifies the formation
neighbor guards and reports their actual coverage. The two checks share
one replay warmup. They leave the original neighbor and footprint behavior
in charge during verification.

[VERIFIED] The combined shadow reached frame 17,402 with sync active at
1920×1080. `analyze-unit-mask.py` matched all 15,242 searches and 2,185
commands. Empty ground footprints covered 20,401,496 of 29,139,645
movement checks (70.01%) and 967,740 of 7,366,863 destination checks
(13.14%), with zero output differences. Direct ground access applied to
7,125,247 of 7,147,146 group expansions. Of those, 4,573,275 could share
a passable zone decision. All checked addresses and zone results matched.
Legacy behavior controlled the replay. Timing with the shortcuts enabled
is a separate run.

## Heap position updates across all search types

[VERIFIED] The [heap prototype](../../artifacts/2026-11-19-last-stand-heap-slots/manifest.md)
stores a lookup-table slot in each queue entry. A sift can then update
positions at those slots directly. The Win32 entry still occupies 16 bytes,
and the queue still breaks equal costs by insertion order. The same-binary
preview passed every recorded head check and matched cleanup fingerprints
on the T-022 traces, covering 8,552,378 congested and 3,355,149 open-map
operations.

[VERIFIED] `test-fixture.cmd switch` ran four alternating pairs per trace.
The slot mode used 0.679–0.788 times the original elapsed time on the
congested trace and 0.713–0.788 on the open trace. These are queue-only
times on recorded operations with surrogate cell addresses. They do not
measure the share of Last Stand frame time spent in the queue.

[VERIFIED] A separate hole-shifting variant matched both operation traces.
It used 0.880–1.025 times the slot-heap time in the congested trace and
0.864–0.938 in the open trace. The paired diagnostic uses the simpler
slot variant first to isolate the larger, consistently measured change.

[INFERRED] The same-binary pair exercises the exact heap, footprint and
neighbor changes together. The treatment must match original routes,
expansion counts and sync. The combined pair establishes whether the stack
earns follow-up timing to isolate each contribution.

[VERIFIED] The treatment reached the native 1920×1080 checkpoint at
frame 17,402 with sync active. `analyze-first-arm.py` matched 15,242
searches and 2,185 commands against the previous native capture. The
treatment alone measured **16.39 FPS**, 61.02 ms mean and 85.70 ms p95.

[VERIFIED] `analyze-stacked.py` subsequently matched both 1920×1080
checkpoints, executable and graphics settings, and the original 15,242
paths and 2,185 commands. It measured the following paired timings.

| Stack | Average FPS | Mean interval | p95 interval | Formation | Ordinary and closest | Draw |
|---|---:|---:|---:|---:|---:|---:|
| Off | 16.84 | 59.40 ms | 83.39 ms | 20.977 ms | 12.978 ms | 8.208 ms |
| On | 16.39 | 61.02 ms | 85.70 ms | 20.403 ms | 13.826 ms | 8.690 ms |

[INFERRED] Formation searches were 0.574 ms/tick faster, while unit
searches and draw were slower. The combined treatment showed no net gain
in this pair and remained 27.69 ms above the 30 FPS budget. The residual
profiling run leaves the three changes off. The independently measured
17.34 FPS reference remains the best completed run in this configuration.

## Parallel jobs and rendering headroom

[VERIFIED] `parallel-after-clearance.py` aligned the treatment's frame
intervals with outer path timings over the 300-frame window. The
treatment spent 20.25 ms/tick in formation routing and 11.55 ms/tick in
ordinary and closest-reachable searches. Mean draw scope time was
9.10 ms/frame.

| Model using treatment timings | Mean time | Mean FPS | p95 time |
|---|---:|---:|---:|
| Remove all formation search cost | 37.69 ms | 26.53 | 57.27 ms |
| Distribute formation jobs over four lanes | 45.24 ms | 22.10 | 64.76 ms |
| Distribute all whole search jobs over four lanes | 36.98 ms | 27.04 | 50.12 ms |
| Divide all search work evenly over four lanes | 33.87 ms | 29.52 | 41.21 ms |

[INFERRED] The scheduling model assumes independent jobs and zero
transfer, synchronization and commit cost. At the modeled whole-search
average, the target needs another 3.64 ms/frame before accounting for any
real worker overhead. This supports pursuing cheaper search execution and
a separate pass over the rendering budget. If the measured 25.85 ms/frame
outside outer searches stays constant, there is about 7.48 ms/frame left
for all search work combined at 30 FPS. Keep one graphical replay per
machine for timed comparisons. Combine passive counters with a parity-only
replay when they can share the same warmup.

[VERIFIED] `DX8Wrapper` already caches identical render and texture-stage
state changes and exposes per-frame submission counters. The prepared
render census reads those counters after normal draw while the mixed-width
shadow verifies route parity. It records draw calls, D3D calls, and texture,
state and buffer changes without changing render order. The counters still
need capture before inferring any cost from them.

[SOURCED] Direct3D documents batching and state changes as distinct avenues
for reducing submission work. Profile CPU, driver and GPU scope before
deducing render cost from call counts. [Direct3D performance optimizations](https://learn.microsoft.com/en-us/windows/win32/direct3d9/performance-optimizations)
· [Profiling Direct3D calls](https://learn.microsoft.com/en-us/windows/win32/direct3d9/accurately-profiling-direct3d-api-calls)

[VERIFIED] `analyze-render.py` matched all 300 frames to the passive
census. The shadow averaged **7.90 ms** in the draw scope, **937 draw
calls**, **8,228 D3D calls**, and **523 texture changes** per frame.
The loaded modules included the system D3D8 runtime and Intel user-mode
graphics driver. D3D call count and draw time had a correlation of +0.40
in this window, which does not establish where the time was spent.

[VERIFIED] `updated-portfolio.py` aligned the current treatment's timing
with field and repair scopes by replay tick, endpoints and route hash.
At minimum width two, the prior probe's covered calls now represent
14.95 ms/tick of measured legacy work. The following estimates retain
the prior probe's construction, validation and repair costs.

| Width-two field and repair model | Mean time | Mean FPS | p95 time |
|---|---:|---:|---:|
| Serial execution | 45.61 ms | 21.92 | 66.85 ms |
| Four search lanes | 35.91 ms | 27.84 | 50.35 ms |
| Four lanes and 2 ms less draw time | 33.91 ms | 29.49 | 48.35 ms |
| Four lanes and 4 ms less draw time | 31.91 ms | 31.33 | 46.35 ms |

[INFERRED] The last row illustrates a possible route to the average
target. It assumes independent jobs, no worker overhead, eligible field
routes with acceptable gameplay, and a renderer improvement still to be
measured. The p95 budget needs additional work even in that model.

[VERIFIED] The next renderer pair uses the preserved 17.26 FPS
executable and identical options with the pinned d3d8to9 DLL first and
the native runtime second. The first trial loaded the staged D3D8
wrapper, system D3D9, and Intel graphics. The run isolates API
translation on Intel if both sides stay on that adapter. Module receipts,
simulation sync and route parity are checked before considering frame and
draw timing. The [wrapper release](https://github.com/crosire/d3d8to9/releases/tag/v1.16.0)
and [prior engine trial](../experiments/EXP-006-d3d8to9-wrapper.md) record
the dependency and previous workload.

[VERIFIED] Both graphics runs reached frame 17,402 at 1920×1080 with
sync, identical executable and options hashes, 15,242 matching searches
and 2,185 matching commands. Both loaded Intel's graphics driver. The
wrapper module was absent from the native control. See
`analyze-wrapper-trial.py` and the paired receipts in the native artifact.

| Graphics path on Intel | Average FPS | Mean frame interval | p95 interval | Mean draw |
|---|---:|---:|---:|---:|
| Native Direct3D 8 | 17.34 | 57.68 ms | 80.52 ms | 8.27 ms |
| d3d8to9 | 16.97 | 58.93 ms | 82.82 ms | 9.02 ms |

[INFERRED] This pair provides no evidence for a draw-time saving from
the wrapper on Intel. The native result stands about 24.35 ms/frame over
the 30 FPS average budget. The same-settings test established simulation
parity. It did not compare rendered pixels or measure the GTX path.

[VERIFIED] `vulkaninfo --summary` enumerated the GTX 1650 Ti with Vulkan
1.4.312 and driver 580.88, plus Intel UHD with Vulkan 1.2.131. This
establishes a device-selection test path without altering Windows GPU
settings. A separate 32-bit replay smoke test would still need to prove
which device is used and check visual parity.

[SOURCED] DXVK implements D3D8 on Vulkan and documents explicit filtering
by Vulkan device name. Its supported scope is Linux/Wine. Windows
compatibility and the actual performance of a Zero Hour replay are open
for this experiment. [DXVK project documentation](https://github.com/doitsujin/dxvk/blob/master/README.md)

## Account for the remaining game logic

[VERIFIED] `measure-existing.py` used the same 300 native D3D8 frames as
the 17.34 FPS reference. Mean game logic was 48.165 ms/tick. The existing
AI scope accounted for 19.150 ms/tick and the object-update scope for
4.390 ms/tick. After subtracting all existing logic sub-timers,
**23.924 ms/tick** remained in the logic clock. It includes the script
phase and its formation searches, so the entire amount cannot be treated
as additional savings on top of pathfinding.

[VERIFIED] Released source calls the path queue and player updates inside
`AI::update`. The script phase runs separately in `GameLogic::update`.
The [residual diagnostic](../../artifacts/2026-11-19-last-stand-residual/manifest.md)
adds 300-tick timers for those phases and their children, including zone
rebuilds, queue dispatch, team scripts and player planning. It is staged
for a separate replay so its additional clocks do not perturb the paired
timing of the optimization stack.

[VERIFIED] The source preview assigns each outer search timer to its
enclosing script, queue, player or other scope without taking another
clock reading. The analyzer compares the summed result to the existing
path census. This supports a direct measurement of time outside searches
even when a script or player phase calls into the same pathfinding code.

[VERIFIED] The diagnostic reached frame 17,402 at 1920×1080 with sync
active and matched all 15,242 searches and 2,185 commands. The outer
search totals reconciled with the original census. Selected inclusive
times over the 300-tick window follow.

| Phase | Inclusive | Outside outer searches |
|---|---:|---:|
| Script engine | 25.608 ms/tick | 3.821 ms/tick |
| Path queue | 14.140 ms/tick | 0.222 ms/tick |
| Player updates | 7.321 ms/tick | 7.321 ms/tick |

[VERIFIED] Sequential scripts accounted for 25.182 ms/tick within the
script phase. Generic team scripts accounted for 5.985 ms/tick within
player updates. Zone rebuilds accounted for 0.026 ms/tick within the path
queue. The diagnostic mean interval was 62.704 ms and includes the added
instrumentation. The named top-level scopes left just 0.057 ms/tick
unassigned in the logic timer.

[INFERRED] Generic team scripts are the largest distinct non-search
target identified in this capture. The [team preview](../../artifacts/2026-11-19-last-stand-team-scripts/manifest.md)
times conditions, actions and debugger message creation separately. It
also stages a guard against formatting messages without a debugger sink,
subject to exact replay verification and A/B. The 5.985 ms phase is the
total available for inspection. Savings from the guard are unknown.

[VERIFIED] The Win32 syntax check passed for both team probe sources.
The compiled sampler shared its results across two translation units,
counted both in-window ticks, and excluded warmup and nested actions.
The staged replay reports generic condition, action and debugger-string
costs separately, then ranks condition and action opcodes using samples.
The current PGO run retains its original engine libraries throughout
training and optimized linking.

[VERIFIED] `model-team-budget.py` matched original search records across
the native 17.34 FPS reference, residual attribution and field shadow.
It recomputed the width-two field model with the measured 5.985 ms/tick
team-script budget. The results are modeled combinations with fixed
original frame inputs.

| Modeled combination | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|
| Field and repair, serial | 45.26 ms | 22.09 | 66.68 ms |
| Field with four workers, before overhead | 35.52 ms | 28.15 | 50.82 ms |
| Four workers, half the team cost, 1 ms worker overhead | 33.53 ms | 29.82 | 48.44 ms |
| Four workers, 75% less team cost, 2 ms worker overhead | 33.03 ms | 30.27 | 47.89 ms |

[INFERRED] If actual search jobs can run independently and the earlier
field candidates retain gameplay parity, the average target would need
about 3.19 ms/tick from teams alone at 1 ms of worker overhead. This is
about 53% of the measured team-script scope. In the model, reaching 30 FPS
on average still leaves slow frames above budget. The next probe measures
which team operations offer savings of that scale.

## Profile-guided whole-program relink

[VERIFIED] The Win32 diagnostics are already built with LTCG. The
[PGO preview](../../artifacts/2026-11-19-last-stand-pgo/manifest.md)
found the installed MSVC profiling runtime and exercised the toolchain.
`test-toolchain.cmd` recorded a real `.pgc`, relinked with `/USEPROFILE`
and printed identical program output. The linker reported profile-guided
optimization of all five functions in this smoke test.

[VERIFIED] The full-LTCG control and instrumented trainer linked from
the same hashed engine libraries and WinMain object. The trainer link
created the `.pgd`, and both executables were hashed in their isolated
output directories. The replay must generate the `.pgc` before optimized
relinking. Any performance conclusion requires the 1080p replay pair,
including original route, command and sync checks.

[VERIFIED] The instrumented game trainer launched and passed frame 4,139
with the original 1080p settings. Its serial session continues with
profile-use relinking and the native pair if training verifies.

[SOURCED] MSVC documents `/GENPROFILE` to collect training data and
`/USEPROFILE` with LTCG to use it. This changes compiler optimization
decisions beyond the existing LTCG build. [Generate a training binary](https://learn.microsoft.com/en-us/cpp/build/reference/genprofile-fastgenprofile-generate-profiling-instrumented-build?view=msvc-170)
· [Use a training profile](https://learn.microsoft.com/en-us/cpp/build/reference/useprofile?view=msvc-170)

## Worker scheduling with measured phase boundaries

[VERIFIED] `model-phase-workers.py` in the [route comparison artifact](../../artifacts/2026-11-19-last-stand-route-match/manifest.md)
matched the native and residual path records. For each of 300 ticks, it
reconciled inferred path attribution against the script and queue timers.
It kept queued searches for the same object on one worker and modeled
script formation searches and queued unit searches as separate phases.
The busiest queued object on each tick accounts for 9.80 of 11.94 ms/tick
(82%) in the timing reference. The corresponding formation call accounts
for 7.62 of 20.37 ms/tick (37%). These are observed workload distributions.

| Existing searches, modeled scheduling | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|
| Measured native reference | 57.68 ms | 17.34 | 80.52 ms |
| Four workers, queue only | 55.55 ms | 18.00 | 78.07 ms |
| Four workers, each of the two phases | 42.80 ms | 23.36 | 63.88 ms |
| Eight workers, each of the two phases | 42.79 ms | 23.37 | 63.88 ms |
| Four workers, both phases, 75% less team cost and 2 ms worker overhead | 40.31 ms | 24.81 | 60.79 ms |

[INFERRED] Four to eight workers offer little headroom at this job size.
Reducing the dominant searches themselves has more potential. A shared
reverse field addresses repeated work for formations with a common goal.
A parallel best-first search could address a single dominating job, but
worker synchronization and original tie order would need investigation.
Reducing job cost and exact route validation come before a dispatch change.
[Flow-field tiles by Elijah Emerson](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf)
· [Hash-distributed A* by Kishimoto, Fukunaga and Botea](https://arxiv.org/abs/1201.3204)

## Optimized formation-route diagnostic

[VERIFIED] `AIGroup.cpp` consumes the optimized waypoint chain. The earlier
field shadow measured traversability and lengths. The new diagnostic
captures allowed zone blocks before the legacy route expands them, builds
eligible candidates with stock waypoint coordinates and smoothing, then
compares optimized coordinates bit-for-bit along with layer and blocked-by-ally
state. The original solver still supplies the route during this diagnostic.

[VERIFIED] `check-syntax.cmd` passed with the recorded Win32 flags.
`test-fixture.cmd` passed for sampled zone snapshots and route comparisons.
The native runner and analyzer passed parser checks. The candidate coverage
in the native replay still needs measurement. Matching optimized waypoints
alone cannot establish equivalence of search side effects or game state.

## PGO trainer time limit and saved profile

[VERIFIED] The standard trainer timed out after 25 minutes. The last
attributed simulation tick was 13,225, before the measurement window.
`pgosweep /noreset` saved a 14,905,344-byte profile earlier in that run.
The [partial-profile experiment](../../artifacts/2026-11-19-last-stand-partial-pgo/manifest.md)
uses a hash-verified copy of those counters and the original LTCG control.
It can establish whether that profile helps, with separate 1080p sync and
timing checks for the optimized and control replays. See
[ISSUE-0123](../issues/ISSUE-0123-last-stand-pgo-training-timeout.md).

[VERIFIED] A separate `/FASTGENPROFILE` trainer and LTCG control linked
successfully, with a 60-minute training allowance. Full-window training
coverage remains open. [Microsoft PGO options](https://learn.microsoft.com/en-us/cpp/build/reference/genprofile-fastgenprofile-generate-profiling-instrumented-build?view=msvc-170)
· [Live counter capture](https://learn.microsoft.com/en-us/cpp/build/pgosweep?view=msvc-170)

[VERIFIED] The partial optimized link merged the saved `.pgc`, reported
no counter overflow, and reported using profile data. The optimized and
control replays both reached frame 17,402 with sync OK at 1920×1080.
`analyze-pair.py` matched all 15,242 search and 2,185 command records.
The linker's function coverage does not establish training coverage of the
late replay stress window.

| Same-input full-LTCG comparison | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|
| Control | 63.03 ms | 15.86 | 91.25 ms |
| Partial-profile build | 58.23 ms | 17.17 | 78.94 ms |

[VERIFIED] Formation time fell from 22.058 to 20.066 ms/tick. Ordinary and
closest searches fell from 13.691 to 11.135 ms/tick. Draw time increased
from 8.764 to 9.489 ms/frame. The result remains 24.90 ms above 30 FPS
and is slightly slower than the historical best of 17.34 FPS.

[INFERRED] The direction of the same-input pair supports more compiler
testing. Waiting for the combined native probe before recreating the fast
profile inputs allows its inactive probes to be shared by both later links.
Retention requires a repeat with representative training and a paired result.

## Cost inside the largest queued searches

[VERIFIED] `model-queue-retries.py` found 108 objects that supplied the
largest queued job on at least one of the 300 native ticks. The top object
led for 12 ticks. `findClosestPath` move results (3.014 ms/tick) and
`internalFindPath` failed move searches (2.296 ms/tick) were the biggest
parts of those jobs. At a 30-tick lifetime, a lookup by recorded grid
inputs and graph revision would encounter 726 repeats. 238 repeated
inputs produced different outcomes. The other repeats account for a
gross 0.883 ms/tick before any validation or cache overhead.

[VERIFIED] The closest fallback updates separate best screen distance and
best weighted route distance. It computes both after its destination
footprint check. The new counter records when neither score can improve,
while still running every original check. The Win32 scratch compile
passed. The [combined diagnostic](../../artifacts/2026-11-19-last-stand-combined-probe/manifest.md)
collects the team breakdown, formation-path comparisons and closest-path
scores in one warmup and replay. None of the three changes route selection.

## Combined native probe outcome

[VERIFIED] `start-combined-probe.ps1` ran one native 1920×1080 replay and
reached frame 17,402 with sync OK. Its analyzers matched the reference
15,242 searches and 2,185 commands. The route probe constructed 1,342 of
2,185 shared-field or repaired candidates, with zero exact optimized
waypoint matches. This excludes the current field from an exact formation
replacement. The instrumented materialization alone cost 2.893 ms/tick.

[VERIFIED] The closest-path probe counted 1,811,821 of 1,928,887 footprint
checks (93.9%) that could improve neither score across 628 fallback calls.
The [closest-path A/B](../../artifacts/2026-11-19-last-stand-closest-ab/manifest.md)
passed Win32 scratch compilation and is running serially with the score
guard on and off in the same executable. The 93.9% count concerns footprint checks
and does not represent the proportion of search time saved.

[VERIFIED] The team probe attributed 5.816 of 6.093 ms/tick to generic
actions. Conditions took 0.223 ms/tick and debugger messages 0.029.
`TEAM_EXECUTE_SEQUENTIAL_SCRIPT` dominated sampled action time with an
estimate of 5.682 ms/tick (241 samples / 7,214 calls). The independently
[prepared starter probe](../../artifacts/2026-11-19-last-stand-team-start/manifest.md)
passed the Win32 scratch check and will measure name lookup, temporary
group creation and idling, and sequential queue insertion. These timings
will distinguish where an index or less repeated work could help.

## Revised worker budget after the field comparison

[VERIFIED] `model-phase-workers.py --pgo` uses the timed partial-profile
build as its reference and allocates the remaining exact searches by
phase and queued object. Under the same zero-overhead independence
assumption, four workers model 22.91 FPS. Setting every generic team
action's measured time to zero and charging 1 ms for dispatch produces
25.75 FPS (38.83 ms mean and 58.89 ms p95). That still leaves 5.50 ms
above the 30 FPS mean budget. The earlier field-based combinations use
route savings that the optimized-waypoint check did not verify.

[VERIFIED] The script-origin and starter probes are staged together. The
origin scope links the sequential script name, opcode and instruction to
each formation receipt. Both origin translation units passed the Win32
syntax check after [ISSUE-0124](../issues/ISSUE-0124-command-origin-include-path.md).
The original command census saw zero group members reported moving in
all 2,185 formation searches. This records the path-time locomotor state.
The new probe will identify the actual script instructions behind those
orders. [Original command census](2026-11-19-last-stand-script-commands.md)

## Closest-path score shortcut timing pair

[VERIFIED] Both runs used the same Win32 binary and original 1080p
settings. Both reached frame 17,402 with sync OK. `analyze-pair.py`
matched all 15,242 searches and 2,185 formation commands against the
reference. The `findClosestPath` control scope averaged 4.918 ms/tick.
The score guard reduced it to 4.354 ms/tick, saving 0.564 ms/tick (11.5%).

| Same-binary closest-path test | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|
| Score guard off | 61.28 ms | 16.32 | 84.65 ms |
| Score guard on | 60.34 ms | 16.57 | 83.89 ms |

[INFERRED] The local improvement preserved gameplay receipts. The overall
change is small relative to earlier run variation and the 30 FPS target.
The best native reference still stands at 17.34 FPS. Keep the shortcut
experimental until it can be repeated or tested in a useful stack.

## Where the repeated formation orders and script queue work originate

[VERIFIED] `start-team-start.ps1` reached the 1080p frame-17,402 sync
checkpoint. `analyze-phases.py` matched 15,242 original search and 2,185
command records. `analyze-origins.py` attributed all 2,185 formation calls to
`SKIRMISH_MOVE_TO_APPROACH_PATH` in 11 GLA attack sequences. The engine
reported zero group members moving at each call. Three of the sequences
accounted for 19.170 of the 22.467 ms/tick in scripted searches.

| Sequential script | Searches | Search cost per tick |
|---|---:|---:|
| GLA Attack Enemy Base Flank3 | 492 | 10.251 ms |
| GLA Attack Enemy Base Center3 | 160 | 4.872 ms |
| GLA Attack Enemy Base Center6 | 274 | 4.047 ms |

[VERIFIED] The generic starter succeeded 7,214 times in 300 ticks.
`analyze-starter.py` measured 5.320 ms/tick in script allocation and queue
append combined. Team resolution, script lookup, group allocation and
assembling/idling the group added 0.325 ms/tick. The queue append scans for
the original head and then follows the linked list to its tail. The
[tail-index experiment](../../artifacts/2026-11-20-last-stand-sequence-tail/manifest.md)
keeps the head selection and uses the prior tail when available. The Win32
syntax and fixture checks passed. The native pair additionally compares
ordered queue fingerprints at frame 17,278.

## Sequential-script tail index timing pair

[VERIFIED] `analyze-pair.py` matched 15,242 searches, 2,185 formation
commands and both frame-17,402 sync checkpoints. It also matched the
ordered queue fingerprint at frame 17,278, with 34 heads and 111,149
pending scripts in both runs. Each completed 7,214 generic script starts
inside the 300-tick window.

| Same-binary queue tail comparison | Append per tick | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|---:|
| Original tail traversal | 5.117 ms | 62.77 ms | 15.93 | 87.91 ms |
| Indexed tail | 0.172 ms | 58.25 ms | 17.17 | 84.12 ms |

[VERIFIED] The index removed 4.945 ms/tick from measured append cost
and 4.52 ms from the overall mean interval in the pair. Graphics options
and resolution matched. The index remains a local diagnostic candidate.
The [low-telemetry repeat](../../artifacts/2026-11-20-last-stand-low-trace/manifest.md)
keeps the same candidate and binary. It disables detailed path and
script logs to measure their contribution, retaining native sync, frame
timing and the ordered queue receipt.

## Low-telemetry native repeat

[VERIFIED] `analyze-low-trace.py` matched the original optimized binary,
launch/options receipt and ordered queue snapshot. The repeat reached
frame 17,402 with sync OK at 1920×1080. With narrower telemetry it
averaged 18.04 FPS at 55.43 ms mean and 80.06 ms p95, compared with
17.17 FPS at 58.25 ms mean and 84.12 ms p95 in the full-census run of the
same candidate. The lower-telemetry run has no per-search trace. Exact
route and command parity was established in the full-census pair.

[INFERRED] This single repeat suggests diagnostic overhead contributes
to the measured interval. Timing variation remains possible. The best
observed interval still requires 22.10 ms of additional mean savings
to reach 30 FPS. The closest guard and PGO gains come from other pairs
and are not additive evidence. The scripted formation searches remain
the largest measured target for further game-compatible work.

## Formation search phase attribution

[VERIFIED] `start.ps1` in the [formation timing artifact](../../artifacts/2026-11-20-last-stand-formation-phases/manifest.md)
ran the same 1080p stress replay with the verified tail index. It matched
the ordered queue snapshot, the sync checkpoint, 15,242 search records,
and 2,185 commands. The breakdown accounts for 20.791 of the formation
solver's enclosing 20.914 ms/tick.

| Formation phase | Milliseconds per tick |
|---|---:|
| Grid search | 18.402 |
| Route smoothing | 1.268 |
| Cleanup | 0.818 |
| Hierarchy | 0.182 |
| Raw path reconstruction | 0.116 |
| Endpoint checks | 0.004 |

[VERIFIED] The grid loop made 7,147,146 straight-line walks. The sample
contained 112,649 walks, and 94,731 would reject on their first
continuation because it was already on the open or closed list. Scaled
sample clocks put those already-visited early returns at about 1.170
ms/tick gross. That is an upper estimate before adding a fast test.
`check-fixture.cmd` matched 66,049 first-step cases. The independent
direction-prefix smoothing fixture matched 2.6 million comparisons.
Neither fixture establishes a native speedup.

[INFERRED] With 18.402 ms/tick in the grid loop, its unmeasured neighbor
cost is a higher priority than smoothing. The [neighbor probe](../../artifacts/2026-11-20-last-stand-ground-loop/manifest.md)
passed scratch compilation and started a native replay. It measures
clearance, cell information allocation and list mutation on the same
sampled expansions to choose a larger target.

[VERIFIED] The follow-up replay matched all original search, command,
queue and sync receipts. Its 26.261 ms/tick projected neighbor span
exceeded the 19.102 ms/tick direct grid clock. The sample estimates are
excluded from the ranking until the projection is repaired and reconciled.
The coarse phase clocks from the earlier run remain valid.
[ISSUE-0125](../issues/ISSUE-0125-formation-neighbor-projection-overcount.md)

## Stable integer bucket queue

[VERIFIED] The [Win32 bucket fixture](../../artifacts/2026-11-20-last-stand-bucket-queue/manifest.md)
matched all recorded queue heads and both ordered cleanup fingerprints
against the direct-slot heap. It used 8,552,378 congestion-trace operations
and 3,355,149 open-map operations. The maximum observed costs were 61,118
and 61,115. In four alternating pairs per trace, buckets used 0.312–0.413
of slot-heap time in congestion and 0.418–0.499 on the open map. This
isolates queue operations with surrogate cell addresses.

[VERIFIED] The [native preview](../../artifacts/2026-11-20-last-stand-bucket-native/manifest.md)
uses FIFO chains with a bounded bitmap priority index. Its Win32 fixture
passed priority bounds, tie order, nested search isolation, high-cost seed
fallback and ordered cleanup. The native 1080p A/B is running with the
same queue-tail index on both sides. Only the formation search uses the
bucket candidate in this pair.

### Native result

[VERIFIED] `analyze-pair.py` matched both 1920×1080 checkpoints, the
configuration aside from the bucket flag, 15,242 search and 2,185
command records, and the ordered script queue snapshot.

| Formation queue | Mean interval | Average FPS | p95 interval | Formation per tick |
|---|---:|---:|---:|---:|
| Stable heap | 55.03 ms | 18.17 | 77.68 ms | 21.129 ms |
| Stable integer buckets | 51.65 ms | 19.36 | 74.28 ms | 17.794 ms |

[VERIFIED] Formation searches saved 3.335 ms/tick. Ordinary and closest
unit paths measured 12.943 and 12.942 ms/tick across the pair, while draw
measured 8.338 and 8.297 ms/frame. The bucket result is the best observed
native average. It leaves 18.32 ms of mean frame time above 30 FPS.

[VERIFIED] `model-remaining.py` reapplied phase-separated worker scheduling
to this captured arm. Four workers model 26.26 FPS before dispatch or
synchronization cost, or 25.59 FPS with 1 ms of overhead. Dividing all
search work perfectly across four workers models 35.26 FPS. The current
engine has no implementation of that subdivision, so neither projection
establishes a native speedup.

[VERIFIED] The independently staged [unit bucket pair](../../artifacts/2026-11-20-last-stand-unit-buckets/manifest.md)
passed the Win32 syntax check. Both runs keep formation buckets and the
tail index on. The experimental flag toggles buckets for ordinary,
closest and attack searches to isolate additional savings.

### Unit-search bucket result

[VERIFIED] The unit extension matched both 1080p checkpoints, 15,242
search records, 2,185 commands, and the ordered script queue snapshot.
`analyze-pair.py` measured 17.78 FPS with formation buckets alone and
18.22 FPS with unit buckets enabled. Ordinary and closest search clocks
fell from 14.286 to 12.594 ms/tick. The overall mean moved from 56.24 to
54.88 ms and p95 from 81.87 to 80.58 ms. The best earlier single run
remains 19.36 FPS. The next comparison keeps unit buckets on in both arms.

## Additional exact candidates

[VERIFIED] The [direct object-ID preview](../../artifacts/2026-11-20-last-stand-dense-object-ids/manifest.md)
partitions the existing lookup into dense and sparse ID ranges. Its
Win32 fixture matched 1,048,576 object reads across replacements,
removals, sparse IDs and resets. The real Win32 syntax check passed.
The same-binary 1080p comparison has started from the current stack.

[VERIFIED] The [pool-index bucket fixture](../../artifacts/2026-11-20-last-stand-pool-buckets/manifest.md)
matched the same 11,907,527 queue operations and cleanup orders. It used
0.688–0.870 of the hashed bucket implementation's fixture time across
eight alternating pairs. It uses surrogates for slot assignment. Native
time to derive a cell's pool slot remains unknown.

[VERIFIED] The [zone halo fixture](../../artifacts/2026-11-20-last-stand-zone-halo/manifest.md)
matched 3,686,400 decisions. With recorded expansion centers and synthetic
10% passable zones, it took 38.05–38.54 ms vs 101.24–122.57 ms for the
original predicate. At 95% passability, it took 37.43–44.87 vs 41.48–56.31
ms. The zone distribution and frame effect still require native evidence.

### Direct object-ID result

[VERIFIED] `analyze-pair.py` verified matching binary and graphics options,
both native sync checkpoints, 15,242 searches, 2,185 commands and the
ordered script queue. With both bucket modes and the tail index on in
both arms, the direct ID table moved the mean from 50.90 to 49.81 ms
(19.64 to 20.08 FPS). P95 moved from 71.49 to 68.80 ms.

| Search scope | Existing hash lookup | Direct ID lookup |
|---|---:|---:|
| Formation | 17.961 ms/tick | 17.605 ms/tick |
| Ordinary and closest paths | 11.458 ms/tick | 11.042 ms/tick |
| Draw | 8.842 ms/frame | 8.790 ms/frame |

[VERIFIED] The treatment is the best observed native replay average.
It remains 16.48 ms/frame above the 30 FPS mean budget. The dense lookup
is enabled in both arms of the next comparison.

[VERIFIED] The [combined grid preview](../../artifacts/2026-11-20-last-stand-grid-stack/manifest.md)
passed Win32 syntax for all three affected translation units. The
native pair switches the cached zone halo and compact pool-index queue
together to avoid two separate warmups. Both arms keep the earlier
closest-score shortcut, two bucket modes, queue tail index and direct ID
table. It measures the combined effect and keeps both exact replay gates.
The independent pool scratch-header issue was resolved before composing
the preview. [ISSUE-0126](../issues/ISSUE-0126-pool-bucket-scratch-headers.md)

### Combined grid result

[VERIFIED] `analyze-pair.py` matched both 1080p checkpoints, 15,242
searches, 2,185 commands and the ordered script queue. Switching
both grid changes on moved the mean from 51.39 to 52.96 ms (19.46 to
18.88 FPS), and p95 from 73.67 to 79.96 ms. Formation search moved
from 18.533 to 18.304 ms/tick. Ordinary and closest searches moved
from 11.086 to 11.391 ms/tick, and draw varied from 8.907 to
9.639 ms/frame. [Pair evidence](../../artifacts/2026-11-20-last-stand-grid-stack/manifest.md)

[INFERRED] This comparison leaves the grid flags off. The paired
toggle cannot establish each flag's independent cost. The earlier
20.08 FPS direct-ID run still leads by mean frame time.

[VERIFIED] Comparing the same replay ticks gave a median treatment-minus-control
change of -0.201 ms and five faster blocks out of ten consecutive 30-tick
blocks. The mean and p95 penalties reflect a change in the slower part of
the distribution during this pair.

## Worker limit on the best measured arm

[VERIFIED] `model-worker-budget.py` aligned the best direct-ID arm
to 300 matching attribution ticks and grouped all queued searches
for a unit together. It models the formation and unit-queue phases
separately. Within those phases, it assigns the longest available job
to the first available worker.

| Model | Mean interval | Average FPS | p95 interval |
|---|---:|---:|---:|
| Measured replay | 49.81 ms | 20.08 | 68.80 ms |
| Four workers on whole jobs, 1 ms overhead | 37.65 ms | 26.56 | 57.30 ms |
| Eight workers on whole jobs, 1 ms overhead | 37.63 ms | 26.57 | 57.30 ms |
| Four workers, earlier start picked by job history, 1 ms overhead | 35.30 ms | 28.33 | 52.74 ms |
| Four workers, earlier start picked with advance knowledge of actual costs, 1 ms overhead | 33.71 ms | 29.66 | 51.52 ms |
| Perfect formation division and whole queue jobs, 1 ms overhead | 35.55 ms | 28.13 | 55.54 ms |
| Whole formation jobs and perfect queue division, 1 ms overhead | 31.22 ms | 32.03 | 38.59 ms |

[VERIFIED] The largest queued unit job averaged 9.256 of 11.323
ms/tick for the entire queue. The biggest individual call inside
that job averaged 8.335 ms and 9,646 expansions per tick. Its two
largest categories were successful move fallbacks (2.242 ms/tick)
and failed ordinary moves (2.186 ms/tick). [Direct-ID evidence](../../artifacts/2026-11-20-last-stand-dense-object-ids/manifest.md)

[INFERRED] Whole-job dispatch still leaves 4.32 ms/frame over budget
with the modeled four-worker overhead. Additional lanes have little
effect once the largest unit search determines when a phase finishes.
Perfect queue division is an optimistic bound. The existing solver
uses shared mutable state and has no implementation of that division.
Prioritize reducing the cost within the largest unit searches.

[VERIFIED] In the trace, 299 ticks had previously queued unit work.
The earlier-start model gives one of the four lanes a job from that
set while the other three handle formation. Using the first queued
candidate modeled 27.01 FPS. A cost predictor that uses only past
timing for each unit modeled 28.33 FPS. Choosing from actual future
costs modeled 29.66 FPS. These models keep the original dispatch
phases for remaining work and charge the same fixed 1 ms.

[INFERRED] Starting a queued read-only search earlier uses existing
worker capacity more effectively than adding more lanes. It needs
private scratch, stable occupancy and command inputs, and comparison
before applying any result in the original queue order. The modeled
results exclude the cost of making and validating the snapshot or
falling back on a changed request. Prior queue age alone establishes
no such purity.

[VERIFIED] In the inspected engine, `GameLogic::update` executes scripts
and updates terrain and objects before it calls the AI queue. The queue
uses a 5,000-cell budget at job boundaries. `doPathfind` changes AI
state and can reserve a goal, alter retry state, wake a unit or request
other units to move. `requestPath` can replace the requested destination.
Any proposed overlap must isolate the solver and keep its surrounding
state updates at their original point in queue order.

## Isolated occupied-width and unit-search previews

[VERIFIED] The [resolved width preview](../../artifacts/2026-11-20-last-stand-resolved-width/manifest.md)
tries to reuse the result of 12,973,463 occupied footprint queries
that bypassed the earlier terrain-only fast path. Its cache is scoped
to one simulation tick, invalidates affected footprints on cell
changes and checks the object/template identity revision. The Win32
fixture matched 600,000 checks. Four affected translation units passed
Win32 syntax. The native pair compares only this candidate while
keeping the grid flags off. [ISSUE-0127](../issues/ISSUE-0127-resolved-width-receipt-anchor.md)

[VERIFIED] Both arms finished in sync at frame 17,402 at native 1080p.
`analyze-pair.py` matched all 15,242 searches, 2,185 commands and the
ordered script queue. The cache handled 12,973,463 occupied lookups
with 1,436,360 recomputations, an 88.9% hit rate. Formation fell from
17.819 to 16.928 ms/tick. The full interval increased from 49.74 to
51.06 ms (20.11 to 19.59 FPS) and p95 increased from 68.46 to 71.95 ms.
Ordinary and closest search time and draw also rose across the runs.
The median same-tick difference was -0.388 ms, with five faster
30-tick blocks out of ten.

[INFERRED] The cache saved targeted work in this pair and failed to
improve full-frame timing. Leave the flag disabled in the next test.
The control is now the fastest observed native replay and remains
16.40 ms/frame over the 30 FPS mean budget.

[VERIFIED] During replay warmup, an independent [unit-neighbor preview](../../artifacts/2026-11-20-last-stand-unit-neighbor/manifest.md)
passed Win32 syntax. It calculates the parent height only if slope
or cliff scoring needs it, and reads the zone mask only when the
neighbor reaches scoring. The same-binary 1080p pair started with the
resolved-width and combined grid changes disabled.
[ISSUE-0129](../issues/ISSUE-0129-unit-neighbor-command-path.md)

[VERIFIED] The pair matched both native checkpoints, 15,242 searches,
2,185 commands and the ordered script queue. Deferred reads moved ordinary
and closest searches from 10.785 to 10.683 ms/tick. Formation moved from
17.673 to 18.692 ms/tick and draw from 8.804 to 8.934 ms/frame. Overall
mean moved from 49.64 to 51.40 ms (20.14 to 19.46 FPS), and p95 from
69.14 to 73.45 ms. The treatment stays off. The control is now the
fastest observed native replay and remains 16.31 ms/frame above budget.

[VERIFIED] The isolated Win32 replay skips rendering until frame
16,800 and scores 300 frames after rendering resumes. While it
warms up, the worker model and the small candidate builds can run
without spending another replay startup. Timed windows retain a
single graphical workload at a time. This session used the warmup
to build the unit-neighbor preview and a separate adapter probe.

## Discrete GPU preflight

[SOURCED] NVIDIA documents an executable export that opts in to the
high-performance GPU on Optimus. Current Windows versions can set GPU
preference per application. The earlier same-renderer comparison used
Intel in both runs. [NVIDIA export](https://developer.download.nvidia.com/devzone/devcenter/gamegraphics/files/OptimusRenderingPolicies.pdf)
· [Windows preference behavior](https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/3D%20Settings/Setting_the_Preferred_Graphics_Processor.htm)

[VERIFIED] The [Optimus probe](../../artifacts/2026-11-20-last-stand-optimus-probe/manifest.md)
built two otherwise identical Win32 Direct3D 9 binaries and verified the
requested export in the treatment. Both hardware devices initialized.
The control selected Intel UHD and the export selected the GTX 1650 Ti.
Both Direct3D 8 probe variants selected Intel UHD. No system preference
was changed. The [replay link preview](../../artifacts/2026-11-20-last-stand-optimus-replay/manifest.md)
generated the two matched link responses from the same Win32 engine
inputs. It stages the existing Direct3D 9 adapter wrapper on both
sides to isolate the adapter choice. The first treatment link exposed
a conflicting default CRT directive. It was excluded and the corrected
pair linked cleanly. Raw code section hashes differ, and after masking
127,349 Win32 base-relocation operands the 5,541,888-byte sections match
exactly. At startup, the native GTX treatment loaded the pinned wrapper,
Direct3D 9 and the NVIDIA driver.
[ISSUE-0130](../issues/ISSUE-0130-optimus-object-default-library.md)

### Matched adapter result

[VERIFIED] Both replays reached frame 17,402 in sync and used the same
1920×1080 graphics options and pinned wrapper. The analyzer verified
the loaded drivers, 15,242 path searches, 2,185 commands and the ordered
script queue. No pixel comparison was performed.

| Adapter with pinned wrapper | Mean interval | Average FPS | p95 interval | Mean draw |
|---|---:|---:|---:|---:|
| Intel UHD | 50.15 ms | 19.94 | 71.18 ms | 9.047 ms |
| GTX 1650 Ti | 45.61 ms | 21.93 | 67.13 ms | 4.983 ms |

[VERIFIED] The GTX arm is the fastest observed native replay. It saved
4.54 ms/frame overall and 4.064 ms/frame in draw. Formation and ordinary
plus closest search clocks changed by only 0.064 and 0.032 ms/tick,
respectively. The mean remains 12.28 ms/frame above the 30 FPS budget.
The Windows module name case check was corrected and reran successfully
on the original receipts. [Adapter evidence](../../artifacts/2026-11-20-last-stand-optimus-replay/manifest.md)
· [ISSUE-0131](../issues/ISSUE-0131-adapter-module-name-case.md)

[INFERRED] On the same direct-ID trace, 4.32 ms/frame of draw savings
would close the modeled whole-job four-worker gap. The earlier-start
history model needs 1.97 ms/frame of further savings. Both figures
assume that switching adapters affects only draw and that a future
worker implementation reaches the modeled timelines. Actual native
timings and parity remain the acceptance criteria.

### Worker model using the measured GTX replay

[VERIFIED] `model-worker-budget.py artifacts/2026-11-20-last-stand-optimus-replay on-gpu-nvidia`
recalculated the worker model using the GTX arm's 300 recorded frames
and search clocks. Four whole-job workers with 1 ms assumed overhead
modeled 29.76 FPS. Eight modeled 29.77 FPS. Giving one of four workers an
earlier start based on the unit's past job cost modeled 32.02 FPS
(31.23 ms mean, 50.28 ms p95). The model still assumes independent jobs
and excludes snapshot, validation and fallback costs. The 32.02 FPS
case has 2.11 ms/frame of modeled headroom for those costs.

### Live queue observation and four-worker coordination fixture

[VERIFIED] The [early-dispatch diagnostic](../../artifacts/2026-11-20-last-stand-early-dispatch/manifest.md)
compiles against the real Win32 engine and runs on the same GTX path.
It selects from the live FIFO before scripts run. The replay records
whether the chosen job reaches the original dispatch point, how its
observed request fields change, whether navigation and occupancy
counters differ, and the selected legacy job's duration. Selection uses
only costs from previous dispatcher calls. The unchanged authoritative
solver supplies all routes. The request and counter checks cover only
the fields and mutators sampled by this diagnostic.
[ISSUE-0132](../issues/ISSUE-0132-early-queue-overlay-include.md)

[VERIFIED] The four-worker coordinator fixture checks that only the
main thread consumes results in original order. It accepted 96 exact
routes, discarded 48 stale routes and replaced 48 unfinished jobs
with serial execution. The stale route changed under the live grid.
The workers used copy-on-write grid pages and recorded every page their
solver read. The synthetic 64×64 fixture measured 0.625 us for snapshot
publication, 0.174 us for result claim and read-page validation, and
90.06 us per fallback. A separate 512×512 fixture verified 240 batches of
unrelated and touched mutations. Publication averaged 8.72 us, 120
writes took 2.06 us and validating 64 read pages took 0.10 us. These are
fixture clocks. The legacy engine input snapshot and route equivalence
remain open. [ISSUE-0133](../issues/ISSUE-0133-snapshot-page-publication.md)

### Live eligibility overturned the unrestricted picker estimate

[VERIFIED] `review.py` matched the original GTX replay's 15,242 searches,
2,185 commands, ordered script queue, sync and graphics receipt. Over the
300-tick stress window, the live history picker selected an already
waiting job on 299 ticks. Its median zero-based rank was 101. The
selected unit reached the original dispatcher on just 20 ticks, with a
median zero-based rank of 12.5 in that subset. All 20 differed in one or
more observed request fields and both occupancy counters. The whole-map
occupancy counters changed before queue entry on all 299 attempted ticks.
No job would pass the sampled full equality gate.

[VERIFIED] Reading the candidate and sweeping the FIFO took 11.37 us/tick
on average and 16.00 us at p95. Comparing the sampled request fields at
dispatch took 0.315 us on average and 0.400 us at p95. The chosen jobs
that did dispatch took 16.80 ms on average in the instrumented original
solver. These are diagnostic clocks. They do not measure copying native
solver state or executing and verifying an alternate exact route.

[INFERRED] The earlier 32.02 FPS projection chose among jobs known from
the trace to dispatch. The live selector faced the entire pending FIFO.
Restricting the choice to a serviced prefix and testing immutable local
dependencies addresses separate sources of speculative failure. The
[follow-up diagnostic](../../artifacts/2026-11-20-last-stand-queue-window/manifest.md)
captures actual tick-start ranks and raw position, coarse cell and
request-policy changes from a single replay. Its Win32 syntax passed.
[ISSUE-0134](../issues/ISSUE-0134-queue-window-dispatch-object.md)

### Narrower tick-start windows improved dispatch and rarely preserved the job

[VERIFIED] The follow-up matched 15,242 searches, 2,185 commands, ordered
script queue, sync and the GTX graphics receipt. Picking the first
waiting queue entry reached dispatch 241 of 241 times and preserved
the observed cells and policy 46 times. Choosing by history among the
first 16 entries dispatched on 189 of 297 attempts and kept cells and
policy on 19. That was the best gross result among the tested pickers
at 0.676 ms/tick of observed legacy job time, before snapshot or worker
cost. The original destination moved to a different coarse cell as
often as it changed in raw coordinates for all tested windows.

[VERIFIED] `upper-bound.py` chose the longest job with matching
observed cells and policy on each tick using hindsight. Even with
the full original FIFO it found candidates on only 175 of 300 ticks
and covered 1.899 ms/tick before grid or worker costs.

[INFERRED] Take the input after scripts, or issue a later queued job
while the earlier slots are running. The
[native page snapshot preview](../../artifacts/2026-11-20-last-stand-native-page-snapshot/manifest.md)
mirrors ground cells in immutable tiles and times publication against
actual mutations. It captures later candidate windows in the same
replay. The worker must eventually validate exact local reads and
preserve admission to the shared path-cell budget. Captured coarse
cells alone do not prove reuse eligibility. [ISSUE-0135](../issues/ISSUE-0135-native-page-overlay-mixed-headers.md)

### Native snapshots and later start points

[VERIFIED] The real GTX diagnostic matched 15,242 original route
records, 2,185 commands, ordered queue, graphics receipt and sync. All ten
audits of the 350×200 ground grid matched all sampled cell fields.
The 286-page mirror published in 4.180 us at tick start and 9.452 us
after scripts. By queue entry, an average of 70.0 pages and 1,514
ground-cell writes had changed since tick start. From the later
post-script publication, 46.3 pages changed on average. The whole-table
page comparison averaged 0.609 us. These clocks exclude constructing
per-unit snapshots for relationships, layers and the remaining
route-search state.

| Selection boundary and phase policy | Picked | Dispatched | Same sampled cells and request policy | Gross candidate work | Optimistic overlap |
|---|---:|---:|---:|---:|---:|
| After scripts, first 16 slots by history | 299 | 189 | 135 | 3.470 ms/tick | 1.299 ms/tick |
| Queue entry, first 16 slots by history | 296 | 192 | 192 | 4.240 ms/tick | 0.433 ms/tick |

[VERIFIED] The replay computes overlap as the smaller of the
selected original job time and the observed lead time. Lead time
includes earlier queue work and, for a post-script selection, the
elapsed interval before queue entry. Zero-cost scheduling and unchanged
sampled fields are intentionally optimistic. A result must still survive
local read validation, simulation budgeting and its own runtime costs.

[VERIFIED] The [worker footprint preview](../../artifacts/2026-11-20-last-stand-worker-policy/manifest.md)
passed its Win32 fixture and engine syntax checks. It schedules one
native worker immediately after scripts and can schedule three others
when the queue begins. Every job precomputes a ground destination
predicate from immutable pages. Queue-time claims compare the actual
actor and footprint and validate the pages used. Missing actor facts,
unfinished work and stale pages yield distinct fallbacks. The original
solver still determines all routes in the comparison. [ISSUE-0136](../issues/ISSUE-0136-worker-policy-build-variant.md)
· [ISSUE-0137](../issues/ISSUE-0137-worker-footprint-helper-scope.md)

### Worker-local ordinary ground expansion

[VERIFIED] The first footprint replay matched the original 1080p GTX
checkpoint, searches, commands and script queue. The game-thread
factoring returned identical results for 113,826 movement checks and
21,699 destination checks, with 47,110 and 20,316 object lookups
respectively. The worker CSV contained only its header because the
runner omitted native page activation. There is no worker performance
or parity evidence from that run.
[ISSUE-0139](../issues/ISSUE-0139-worker-launch-missing-page-switch.md)

[VERIFIED] The [ordinary ground kernel](../../artifacts/2026-11-20-last-stand-worker-search/manifest.md)
has private node storage and frontier state. It reproduces the
neighbor order, line probes, 16-bit scores, costs and ally-block
flags from the ground expansion code. `check-fixture.cmd` matched
512 route and no-route results across four concurrent workspaces,
including exact raw paths, costs, expansion and cleanup counts.
Unsupported cells, layers and pool pressure fell back in the fixture.

[VERIFIED] The native adapter and launcher passed syntax and replay
configuration generation. A combined GTX diagnostic now supplies
the missing worker snapshot setting and tests the raw route before
legacy smoothing. The raw adapter is a live-input, main-thread
comparison. Local worker snapshot inputs for hierarchy, actors, live
allocation pressure and work outside ordinary ground expansion remain
to be verified. [ISSUE-0138](../issues/ISSUE-0138-worker-search-bucket-header.md)

### Reduce repeated work inside a search

[VERIFIED] `operation-budget.py` aligned the 300 scored GTX intervals
with the outer search clocks. The three main scopes accounted for
28.498 ms/tick, or 62.5% of the mean frame. Formation accounted for
7,148,775 expansions and 17.708 ms/tick. Ordinary paths accounted for
1,945,147 and 7.131 ms/tick. Closest paths accounted for 1,933,500 and
3.659 ms/tick. At fixed costs elsewhere, those scopes need a 43.1%
time reduction to reach 30 FPS without a worker contribution.

[VERIFIED] `check-memo.cmd` tested reusing the complete movement
footprint answer by cell within one immutable search. The same scope
uses the same actor inputs for line probing and neighboring cells.
The synthetic fixture reduced 6,265,209 actual footprint evaluations
to 145,359, with identical raw paths, costs, expansion and cleanup
counts. Twenty-five jobs found a route and fifteen exhausted the
search. This measures operation count in the fixture. Native
hit rate, elapsed cost and interaction with the worker scheduler
remain to be measured. [Operation evidence](../../artifacts/2026-11-20-last-stand-worker-search/manifest.md)

### Native worker handoff and raw solver results

[VERIFIED] The corrected combined 1080p GTX replay matched all 15,242
original search records, 2,185 commands, ordered script queue and sync.
The factored policy matched 199,519 movement checks and 21,699
destination checks. The four workers logged 1,131 submissions and
495 claims. All 307 accepted claims matched the original result.
Another 133 lacked actor facts, 40 had modified read pages and 15
were unfinished. Publication averaged 6.995 us. Claim means ranged
from 1.513 to 6.549 us. The corresponding original footprint
predicates took 0.379 to 0.552 us. This is measured validation overhead
for small predicates, with no whole-route timing claim.
[ISSUE-0139](../issues/ISSUE-0139-worker-launch-missing-page-switch.md)

[VERIFIED] The ordinary ground adapter supported 857 of 872 native
entry points and matched 729 raw chains, costs, expansion and cleanup
receipts. The other 108 successful searches had matching expansion
and cleanup counts. The 20 original failures diverged on both counts.
The [correction preview](../../artifacts/2026-11-20-last-stand-worker-search-budget/manifest.md)
preserves the native start ally-block bit and measures real free
records after endpoint allocation. The fixture and syntax checks
passed. Native confirmation is pending.
[ISSUE-0141](../issues/ISSUE-0141-worker-raw-route-mismatch.md)

[VERIFIED] The [native unit-footprint memo](../../artifacts/2026-11-20-last-stand-native-unit-memo/manifest.md)
passed syntax and started its matched 1080p GTX pair. The baseline
stack, graphics and executable are shared. Control uses the original
footprint evaluator on every call. Treatment reuses exact outputs within
ordinary and closest ground searches, invalidates on cell mutation and
checks every 256th hit. Both suppress native worker and raw-search
diagnostics. [ISSUE-0140](../issues/ISSUE-0140-unit-memo-runner-newlines.md)

[VERIFIED] Both arms reached diagnostic checkpoint 17,402 with sync
at the original 1920×1080 settings on the GTX 1650 Ti. With the
memo off and on respectively, the same 300-frame stress window
averaged 21.84 and 21.95 FPS (45.788 and 45.568 ms per frame).
p95 fell from 66.665 to 63.935 ms and p99 rose from 76.558 to
84.787 ms (nearest rank, `interval` in the two attribution CSVs).
The memo skipped 19,083,596
legacy footprint checks out of 22,305,407 requests and checked
74,269 cached hits against the original predicate with zero
differences. All 15,242 recorded searches, 2,185 commands and the
ordered script queue matched both the other arm and the original
GTX control. Ordinary search fell from 7.494 to 5.712 ms/tick,
formation search rose from 17.449 to 18.310 ms/tick, and closest
search went from 3.704 to 3.761 ms/tick. The observed average
remains 12.235 ms above the 30 FPS frame budget.
[Timing and parity receipt](../../artifacts/2026-11-20-last-stand-native-unit-memo/early-summary.txt)

[INFERRED] A single 0.220 ms/frame reduction establishes the scale
of the observed change and is insufficient to establish repeatable
overall benefit. The cache stays off during the frozen-worker
diagnostic so its result receipts can be compared to the existing
GTX control.

### Full ordinary ground searches on frozen worker inputs

[VERIFIED] `check-fixture.cmd` ran 256 exact searches in four lanes
on an immutable tile snapshot. A change outside the pages read by a
result preserved validation. A change on a read page invalidated
that result, and missing actor facts triggered fallback. The
isolated Win32 engine syntax check passed after
[ISSUE-0142](../issues/ISSUE-0142-worker-frozen-actor-id.md).

[VERIFIED] The shadow dispatches from native fine-grid entry after
endpoint admission. A worker receives a frozen tile snapshot,
resident-record and zone flags, the actual endpoint record budget,
start ally state and actor-relative facts. The simulation thread
still applies the original route. The diagnostic separately records
snapshot and submission, worker compute, result claim, page
validation, and the original solver cost. Snapshot timing starts
after query construction and does not include the diagnostic scan
of native free records. The page check alone does not validate
actor facts, zone flags or endpoint state. No claim is
made for frame-rate gain or for dispatch before the request's turn
in the queue. [Prototype and verification commands](../../artifacts/2026-11-20-last-stand-frozen-worker-search/manifest.md)

[VERIFIED] The fine-grid entry diagnostic reached sync at frame
17,402 on GTX with the original 1080p graphics, and matched 15,242
searches, 2,185 commands and the ordered script queue. Workers
matched all 646 supported results out of 676 submissions. Another
189 supported live-input diagnostics matched, resolving
[ISSUE-0141](../issues/ISSUE-0141-worker-raw-route-mismatch.md).
In total, 835 supported entry points matched and 37 were unsupported.
The original solver remained in charge.

| Fine-grid entry diagnostic | Mean |
|---|---:|
| Publish and submit | 505.176 µs |
| Claim worker result | 0.300 µs |
| Validate read pages | 0.327 µs |
| Original solver on sampled jobs | 2,487.746 µs |
| Worker solver on sampled jobs | 3,888.985 µs |

[VERIFIED] The first three lanes processed 507, 168 and 1 jobs and
the fourth was unused with fine-grid dispatch. Only 282 of 676
results were ready even by original solver completion. Of these,
280 were exact. Their original solver scopes summed to 0.626 ms
per replay tick. The measured snapshot/submit work alone summed
to 1.138 ms per tick, excluding preparation and free-list scans.
[Native diagnostic receipt](../../artifacts/2026-11-20-last-stand-frozen-worker-search/early-summary.txt)

[INFERRED] Submitting only when the original solver starts leaves
too little overlap and spending roughly half a millisecond per
snapshot makes those late submissions a poor speed candidate. The
next shadow sends one queued request after scripts and before its
original turn, while caching repeated movement checks within each
immutable worker job. At the actual fine-grid entry it compares
query fields, available records, the pages and resident records
read, queried hierarchy zones and the worker's actor-relative unit
facts. It still runs the original solver for every result.
[Early prototype and verification commands](../../artifacts/2026-11-20-last-stand-early-full-worker/manifest.md)

### Early queued dispatch from the script boundary

[VERIFIED] The [early full-search shadow](../../artifacts/2026-11-20-last-stand-early-full-worker/manifest.md)
matched the 15,242 original searches, 2,185 commands, ordered
script queue, graphics receipt and sync at frame 17,402 on the
GTX 1650 Ti. The live policy adapter supported 250 of 252 native
eligible entry points, and all 250 matched raw chains, flags,
costs, expansion and cleanup receipts. The 835 worker submissions
averaged 736.845 µs for snapshot and submission and carried an
average of 1,206 actor-fact records.

| Early-lane verdict | Submissions | Mean claim and validation | Original fine solver |
|---|---:|---:|---:|
| Valid, worker input intact | 11 | 3.982 µs | 61.427 µs |
| Stale, unit facts changed | 41 | 13.790 µs | 1,102.802 µs |
| Unready, worker unfinished | 31 | 1.023 µs | 22,806.416 µs |
| Never dispatched | 215 | — | — |

[VERIFIED] Only 11 of 298 early submissions passed dependency
validation; all 11 matched the original route. The 215
never-dispatched picks produced no comparison. Lanes 0–2 ran
worker solvers at 6,873/1,376/1,341 µs against
9,071/1,875/1,684 µs for the original, with lane 3 unused.
Claim and page validation stayed near 0.4 and 0.3 µs.
[Native receipt](../../artifacts/2026-11-20-last-stand-early-full-worker/early-summary.txt)

[INFERRED] The valid, stale and unready candidates together carry
23.970 ms of original fine-solver work across 300 ticks, about
0.080 ms/tick. Even perfect eligibility and zero snapshot cost
would not fund the 12.235 ms gap. The 32.02 FPS projection assumed
that the picker could reach the large jobs; the live post-script
prefix does not contain them. Combined with the late-handoff pair,
which spent 1.138 ms/tick to cover 0.626 ms/tick, the worker track
cannot reach 30 FPS on this workload and is parked. The fixture,
page-mirror and parity receipts are retained for a future workload
with larger independent jobs.

### Next candidate: request-level group route reuse

[VERIFIED] The census found 778 later group searches with the same
start and goal cells, layers, revision and full-path fingerprint.
They carried 19.08 ms/tick, or 25.3% of measured search time, and
all recurred after three or four logic ticks. The 2,185 calls
target three destinations from 16 and 23 distinct starting cells,
and 97.1% of their expansion cells had been visited within five
ticks under the same goal and topology stamp.

[VERIFIED] The earlier whole-route cache returned zero eligible
hits because its guard required unchanged global occupancy, which
held in only 145 of 2,184 intervals. Group searches have no
cross-search route cache, and they bypass the per-unit queue that
deduplicates object IDs. The per-pop cost is 743 ns for formation
(17.708 ms/tick over 23,829 pops/tick), not 2.5 ns; the earlier
figure divided 300 ticks of work by total pops. The
[T-113 algorithm note](2026-11-20-pathfinding-algorithm-limit.md)
records the corrected math and the 41.8% unit re-expansion finding.

[VERIFIED] Offline sizing on the current GTX diagnostic
([analysis](../../artifacts/2026-11-20-last-stand-request-reuse/manifest.md))
found 122 distinct request keys and 42 endpoints across the 2,185
calls. At a four-tick TTL, 777 later searches returned the exact
same route, worth 5.99 ms/tick or 13.15% of the 45.568 ms frame.
Another 788 changed route or state (10.25 ms/tick), and 484
returned null both times (1.82 ms/tick). The exact hits recur
after three (644) or four (133) ticks. All share the navigation
revision, but none share the fixed-occupancy stamp: a fixed-stamp
guard would pass zero of them. Their straight-line span averages
92 cells (p95 184); even a twice-as-long route checked at 50 ns
per cell costs 0.024 ms/tick, far below the 5.99 ms/tick saved.

[INFERRED] The native route-cell guard was expected to pass the
777 exact hits because the later solver validated the same cells.
The result below shows the diameter-6 cell check is stricter than
the search's own validity and rejects most of them. A guard that
mirrors the search's movement checks, or accepts a narrower width,
would need a new measurement. Exact-dominated passes could use the
route-parity gate; material false positives need the
fresh-skirmish protocol.

### Native route-cell guard result

[VERIFIED] The compiled guard ran the replay to frame 17,402 with
`sync=ok` and matched 9,106 window searches and 2,185 commands.
No D3D module was recorded ([ISSUE-0145](../issues/ISSUE-0145-route-guard-no-gpu-module.md));
the logic receipts are valid. With a three-cell start skip, 154
exact routes were captured (0.16 ms/tick), 33 guard passes were
changed routes, 623 exact routes were rejected and 1,239 changed
routes were rejected. With an eight-cell skip, 181 exact
(0.19 ms/tick), 53 false positives and 596 false negatives. Guard
cost was 0.022 ms/tick.

[INFERRED] The diameter-6 cell-center check is stricter than the
search's own validity: route nodes can be usable even when
`clearCellForDiameter` returns less than six. The 777 exact route
hashes are not accessible with this guard. The conservative route
cache is deprioritized; the no-reopen unit search and the
formation algorithm are the next tests.

## Sample-guided compiler preflight

[SOURCED] MSVC sample-based profile-guided optimization uses hardware
or timed samples from a release binary. Its documented workflow
requires MSVC 14.51 or newer, `xperf`, `SPTAggregate` and `SPDConvert`.
[Microsoft SPGO tutorial](https://learn.microsoft.com/en-us/cpp/build/sample-profile-guided-optimization?view=msvc-170)

[VERIFIED] The installed Win32 MSVC 14.43 linker accepted `/SPGO` in
a standalone probe and reported falling back to an unprofiled link.
The probe emitted no SPD. `xperf` and `wpr` are available. Neither
converter was found in the installed Visual Studio or Windows
Performance Toolkit directories. No replay gain is measured for
sample-guided optimization. [Toolchain probe](../../artifacts/2026-11-20-last-stand-spgo-probe/manifest.md)
· [ISSUE-0128](../issues/ISSUE-0128-spgo-probe-runtime-dependency.md)
