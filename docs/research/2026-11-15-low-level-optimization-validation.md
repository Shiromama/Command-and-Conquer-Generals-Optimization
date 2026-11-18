# Low-level optimization candidates: source and evidence validation

- **Date:** 2026-11-15
- **Author/agent:** lead
- **Task:** T-050
- **Status:** Reviewed (static analysis and retained-data reanalysis; no new engine benchmark)
- **Related:** T-016, T-021, T-022, T-035, T-046, T-048, T-049

## Question

Which of memory layout, SIMD, custom allocation, multithreading, pathfinding restructuring,
and Rust modules are justified by the current source, measured workloads, and primary research?

## Answer (short)

[INFERRED] Prioritize finer profiling of object lifecycle/update/cleanup and the residual nuke
event before choosing another implementation. Targeted allocation/data-structure work and a
moving-army pathfinding experiment have the best supporting evidence. SIMD and read-only
threaded culling are conditional candidates. Rust is an implementation option after a hot
algorithm and a useful boundary are identified; it is not a performance fix by itself.

[VERIFIED] The earlier chat statement needs qualification: **we have not added our own broad
replacements, but the inherited engine already has custom pools, contiguous pathfind storage,
improved pathfinding branches, and particle batching.** Availability in source does not prove
that every improved branch is active during normal play. No new speedup is established here.

## Method and evidence

[VERIFIED] Inspected the pinned vendor source and current working changes, generated Release
project, CMake options, earlier research, EXP-001/005/008 and the T-049 correctness audit.
Recomputed statistics from retained CSVs with Python 3.10.0. External sources below were
accessed on 2026-11-15; their results are not local measurements.

Reproduce from the repository root:

```powershell
python artifacts/2026-11-15-low-level-research/inspect.py
python tools/check_docs.py
```

Evidence: `artifacts/2026-11-15-low-level-research/manifest.md`, `source-excerpts.txt`,
`recalculated.json`, and `inspect.py`. The JSON includes raw-input hashes, sample counts,
percentile definitions and generated Release properties; source excerpts are stored separately.

### What the local measurements actually establish

| Observation | Evidence | Implication |
|---|---|---|
| AA off + Low improved the original all-visible 1,000-tank scene 59.41 to 33.36 ms | [VERIFIED] EXP-001/003 | A settings result, not evidence that a new allocator or SIMD will accelerate that scene |
| Clean High shadow LOD improved 25.02 to 20.30 ms | [VERIFIED] EXP-005 | Rendering/shadow work is an established target; arithmetic/vectorization is not yet isolated |
| Original debris pair-build maxima reproduce as 90.515 to 3.973 ms | [VERIFIED] retained baseline `filter-off.csv` and `broadphase.csv` | Avoiding unnecessary candidate work has already paid off |
| Historical broadphase frame p95 reproduces as 54.43 to 46.04 ms when `frame > 300` | [VERIFIED] 540 baseline vs 780 optimized wall-clock samples | Explicit population matters; these remain pre-T-049 measurements |
| Dense five-cycle run: frame median 38.16 ms, p95 79.19, p99 159.01, max 376.76 | [VERIFIED] all 1,800 retained wall-clock rows, linear interpolation | Tail latency remains substantial; slightly different rounding/percentile methods explain minor differences from EXP-008 |
| Dense run logic update maximum 149.951 ms; destroy maximum 91.948 ms; partition maximum 27.251 ms | [VERIFIED] all 1,726 logic rows | Lifecycle/update/cleanup deserves separate instrumentation, beyond pair building |

[VERIFIED] Largest update samples occur at logic frames 243/483/723/963; large cleanup samples
include 481/721/961. [INFERRED] This supports investigating the recurring spawn/cleanup cycle.
It does **not** identify allocation as the cause: constructors, registration, modules, spatial
updates and cleanup traversal may contribute. The logic timers start after some harness work;
wall-clock and logic frame numbers must not be joined as if they were the same timeline.

[VERIFIED] EXP-008 section 12 reports nuke-event spikes even when debris are heavily limited.
[UNKNOWN] Audio, effect/resource creation, main-loop waits and pacing remain hypotheses; the
evidence does not uniquely identify audio or particles. A shell-transition sample is not a
gameplay-nuke sample. These hitches need event-aligned measurement of their own.

## Candidate decisions

### 1. Memory layout: justified in bounded hot data, not an engine-wide rewrite

[VERIFIED] `GeneralsMD/.../GameClient.cpp:861` walks the drawable linked list for region queries.
`GeneralsMD/.../PartitionManager.cpp:961,2476,2550` has linked contact records, hash-chain
duplicate checks, and a full contact-list scan when removing a specific partition object.
Repeated removal can therefore perform O(D*C) list checks for D removals and C contacts.
That is a source-level scaling risk; its share of the 92 ms cleanup sample is **unknown**.

[VERIFIED] `Core/.../PathfindCellInfo.cpp:22,45,77` already allocates 30,000 records together and
manages a free list. `W3DParticleSys.cpp:243` already has separate position, size, color and
angle buffers. "Convert everything to arrays" would duplicate existing work in some places.

[SOURCED] Intel's [vectorization guidelines](https://www.intel.com/content/www/us/en/docs/dpcpp-cpp-compiler/developer-guide-reference/2024-0/vectorization-programming-guidelines.html)
explain the value of contiguous accesses and structure-of-arrays for suitable loops.
[INFERRED] First candidates are a compact per-frame culling snapshot or contiguous contact
storage with stable indices, rather than changing the live Object/Drawable ABI or identities.

[SOURCED] NVIDIA's [broadphase discussion](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-32-broad-phase-collision-detection-cuda)
explains conservative candidate rejection and spatial subdivision. [INFERRED] This supports
reducing unnecessary work before accelerating individual tests; it does not justify importing
that article's GPU speedup into our CPU engine.

**Validation:** measure traversal time, contact-list length, removal visits and cache misses
where supported. Compare identical accepted candidate sets and collision processing order.
Keep stable object handles, callback/lifetime behavior and snapshot behavior. Reject the
change if copying/rebuilding the compact view costs more than it saves. Prioritize cleanup
indexing only if its timer is significant after T-046.

### 2. Custom allocation: already present; targeted tuning is plausible

[VERIFIED] `Common/GameMemory.h` and `Common/System/GameMemory.cpp` implement class pools and a
dynamic allocator. `PartitionContactListNode` derives from `MemoryPoolObject` and is created
with `newInstance`. The allocator uses free blocks, can grow blobs, takes a scoped critical
section at allocation/free, and its zeroing path calls `memset`. The selected ZH critical
section header wraps Windows critical sections when its pointer is non-null.

[INFERRED] Pool pre-sizing, fewer transient contact records, and bulk lifetime management may
help bursts. The existing broadphase already reduces some of this work. Replacing the whole
allocator with another allocator is not currently justified. Lock **presence** is not evidence
of lock **contention**; do not remove synchronization without proving thread ownership.

[VERIFIED] Although CMake cache memory-debug switches say ON, the inspected Release project
defines `RTS_RELEASE`, not `RTS_DEBUG`; `GameMemory.h:54-64` gates the debug macros on
`RTS_DEBUG`. The cache alone does not prove expensive pool-debug code runs in this binary.

**Validation:** count allocations/frees, blob overflows, zeroed bytes and allocation time by
object class during death/spawn/cleanup events. Separate allocator time from constructors,
drawable/module creation, partition registration and destruction. Preserve initialization,
pointer lifetime and destructor order; an arena is suitable only for proven frame-local data.

### 3. SIMD: technically plausible, payoff unverified

[SOURCED] MSVC's [auto-vectorizer](https://learn.microsoft.com/en-us/cpp/parallel/auto-parallelization-and-auto-vectorization?view=msvc-170)
is enabled by default and supplies `/Qvec-report:2` diagnostics. [VERIFIED] The current Release
project uses MaxSpeed and the cache has `/O2 /Ob2`; this does not prove which loops actually
vectorized. "No manual SIMD work by us" must not be read as "the binary has no SIMD."

[INFERRED] Batch frustum/sphere tests, particle-buffer preparation and pure transforms are
better first targets than pointer-heavy virtual object updates. Compact input data may be a
prerequisite. The scalar early-out broadphase should be profiled again before vectorizing it;
its original dominant cost was already removed.

[SOURCED] Microsoft's [floating-point reference](https://learn.microsoft.com/en-us/cpp/build/reference/fp-specify-floating-point-behavior?view=msvc-170)
documents that reassociation and FMA can alter rounding. [VERIFIED] `cmake/compilers.cmake`
explicitly disables FMA contraction for non-MSVC builds to maintain deterministic math parity.

**Validation:** inspect vectorization diagnostics/disassembly, compare scalar and vector outputs
including boundary/touching cases, and benchmark the whole frame including packing costs.
Keep a scalar fallback and CPU feature checks. Do not globally enable fast-math or AVX-only
instructions. For conservative collision rejection, preserve potentially colliding pairs even
near floating-point thresholds; visual tolerance is insufficient for simulation data.

### 4. Multithreading: restrict the first experiment to read-only preparation

[VERIFIED] The vendor already decouples render and logic timing (earlier research and
EXP-004/005). Decoupled timing does not establish concurrent simulation/render execution.
Build `/MP` and a multithreaded CRT also do not mean simulation work runs in parallel.

[SOURCED] [OpenSAGE](https://opensage.github.io/blog/year-in-review-2018/) reported 5-10% from
threaded frustum culling on its own quad-core i5 system. This validates feasibility, not a gain
estimate for this code. [Microsoft](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-differences)
warns that making D3D9 thread-safe adds significant synchronization overhead, relevant to our
optional D3D8-to-D3D9 path; it is not evidence about every D3D8 call's precise cost.

[INFERRED] Build immutable culling inputs on the owner thread, evaluate them in workers, and
merge by original stable order; keep D3D calls on the render owner. Do not initially parallelize
damage/death callbacks, shared RNG, partition mutation, or A* over changing terrain.

**Validation:** include snapshot copy, job dispatch, synchronization, stable merge and extra
memory in timing. Test one/two/four workers and small scenes. Preserve lifetimes while workers
read snapshots. Require a sizeable measured preparation cost before paying this complexity.

### 5. Pathfinding: strong source/upstream case, wrong existing workload

[VERIFIED] `PathfindCell.cpp:483-657` retains linked-list sorted insertion, including an
improved forward/reverse version. `s_useFixedPathfinding` starts false; with the current retail
guards the original routine is selected until fallback. The 30,000-info array and allocation
guards are not absent features waiting to be invented. Improved code being compiled does not
prove normal paths use it.

[SOURCED] Upstream [PR #3198](https://github.com/TheSuperHackers/GeneralsGameCode/pull/3198)
merged September 15, 2026. It removes path-tail walks and redundant neighbor computations;
its author reports substantial pathfinding CPU share in large FFAs and replay checks.
[VERIFIED] Our `Path.cpp:204-236` already appends via `m_pathTail`. Those improvements must not
be counted as a new local proposal or credited with an unmeasured local gain.

[INFERRED] An indexed min-heap or a bounded integer-cost queue can reduce open-list search
work, but only after measuring queue lengths, insertion visits, decrease-key/removal behavior
and fallback frequency. O(log n) is not automatically faster than short lists, and a heap's
different tie order can change selected routes. Hierarchical/group pathfinding is a larger
behavior change than preserving the existing queue's semantics.

**Validation:** create a scripted movement workload with choke points, impassable goals, moving
blockers and many simultaneous requests. Preserve cost calculation, equal-cost order,
per-frame search budgets and cancellation semantics. Differentially compare expansion/pop
sequences and paths, then replay/CRC outcomes where compatible. Raising the cap or toggling
all retail guards is not a performance result. T-022 remains unimplemented; T-025's missing
compatible late-game replay still limits real-game validation.

### 6. Rust modules: viable integration, no language-based speedup claim

[VERIFIED] ADR-0005 already requires a narrow C ABI and benchmark evidence; there is no Rust
game module in this project. The current engine and runtime layout are 32-bit MSVC.
[SOURCED] The [Rust FFI reference](https://doc.rust-lang.org/nomicon/ffi.html) documents C-compatible
layouts, ownership and unwinding requirements.

[INFERRED] A pure batched culling kernel or isolated queue is a feasible comparison target.
Use the same algorithm and inputs in optimized C++ and Rust first, then separately compare
algorithm/layout changes. Batch calls; avoid crossing FFI per object. Keep ownership on one
side, match the 32-bit ABI/toolchain, use explicit layouts/lengths, and contain panics/errors.
Reproducing legacy floating-point results is an additional requirement, not an ABI guarantee.

**Validation:** scalar C++ reference vs optimized C++ vs Rust, identical accepted outputs and
frame workload, including packing/copy/FFI costs. Tooling in Rust can improve workflow without
improving game FPS; record those outcomes separately. No automatic Rust speed multiplier is
justified.

## Additional bounded opportunities

[VERIFIED] The inspected Release project has `/O2`/MaxSpeed; no explicit whole-program/LTCG
setting appears in its compiler properties. The reviewed CMake compiler configuration does
not establish a PGO workflow. [SOURCED] MSVC supports
[LTCG](https://learn.microsoft.com/en-us/cpp/build/reference/ltcg-link-time-code-generation?view=msvc-170)
and [PGO](https://learn.microsoft.com/en-us/cpp/build/profile-guided-optimizations?view=msvc-170),
including x86 native targets. [INFERRED] A separate LTCG build, followed by representative PGO
training, is a bounded experiment before a broad rewrite. Check all relevant targets, linking
dependencies and floating-point behavior; this is not yet a tested build or promised gain.

[VERIFIED] `AsciiString` copying takes a scoped critical section and changes a reference count.
[SOURCED] [PR #2663](https://github.com/TheSuperHackers/GeneralsGameCode/pull/2663) was closed
without merging, and maintainers questioned the contention evidence. [INFERRED] Measure copy
counts/lock time in real hot callers before targeted reference-lifetime changes. Do not repeat
the PR's dramatic FPS claim as a validated local opportunity.

## Recommended experiment order and acceptance

1. **Current-engine baseline:** rerun corrected T-049 broadphase on/off, with tall structures,
   different object heights and touching boundaries. Its source/build fix has not had this
   in-game differential test. Preserve every valid collision and actual visible debris.
2. **Lifecycle and nuke-event attribution:** time factory construction, first updates, module
   setup, partition registration/removal, pool growth/free, FX resource work, audio calls,
   presentation/waits and harness operations separately. Use event markers on the same clock.
3. **One bounded data/allocation change** only after step 2 attributes the cost. Prefer avoiding
   repeated scans/temporary records before allocator replacement or manual SIMD.
4. **Movement/pathfinding workload:** profile the existing normal and fallback paths before
   choosing a stable heap/queue prototype. Independent of the stationary tank result.
5. **Separate LTCG A/B**, then SIMD or read-only culling workers only if their measured share
   warrants it. Consider Rust after establishing the algorithm and input/output contract.

[INFERRED] For each experiment use at least three alternating control/variant pairs, same
binary/config except the tested option, fixed scenario seeds/events, foreground/resolution/GPU,
and clean background load. Keep simulation rate unchanged. Report median, p95/p99, frames above
33.33 ms, event-window maxima, memory and output correctness; save input hashes and raw CSVs.
Report capped gameplay and uncapped render headroom separately. Retain a variant only when its
gain exceeds run variation and its behavior checks pass. A faster isolated kernel is not
enough if whole-frame timing regresses.

## Expected gains and limits

[INFERRED] No defensible new total FPS estimate follows from source feasibility. For serial
frame work, `total speedup = 1 / ((1-f) + f/s)` where f is the original time fraction and s the
subsystem speedup. These are illustrative calculations, not predictions:

| Assumption | Whole-frame speedup |
|---|---:|
| Double a subsystem consuming 20% of the frame | 1.111x (11.1%) |
| Double a subsystem consuming 40% of the frame | 1.250x (25.0%) |
| Perfect four-way parallelism for 10% of the frame | 1.081x (8.1%), before overhead |

Do not add unrelated gains from different benchmarks or apply these examples to median/p95
phase statistics as if their peaks occurred together. FPS caps may hide a real reduction in
work while event stutters improve; uncapping can also change CPU load, so use controlled rates.

[UNKNOWN] Cache-miss share, allocator share, vectorized-loop inventory, real moving-army
pathfinding share and worker scheduling cost are not established. This study validates
mechanisms and next experiments, not future benchmark outcomes. No game files, engine source
or executable were changed, and no new runtime experiment was performed.

## Documentation corrections

[VERIFIED] ISSUE-0018 corrects the broadphase evidence filename to `broadphase.csv`.
ISSUE-0019 was resolved by reconstructing `frame > 300`, which reproduces the historical
54.4/46.0 ms p95 pair; all-row populations give different values. Source/build-level verification
of the T-049 sphere-center correction must remain distinct from the older performance runs.

## Artifacts

- `artifacts/2026-11-15-low-level-research/manifest.md` - inputs, tools, outputs and hashes.
- `artifacts/2026-11-15-low-level-research/inspect.py` - reproducible static/CSV inspection.
- `artifacts/2026-11-15-low-level-research/recalculated.json` - raw statistics and sample counts.
- `artifacts/2026-11-15-low-level-research/source-excerpts.txt` - line-numbered source evidence.
