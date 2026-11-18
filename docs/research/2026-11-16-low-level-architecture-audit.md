# Low-level architecture audit: where the engine still wastes work

- **Date:** 2026-11-16
- **Task:** T-064 (audit), spawns T-065…T-067
- **Status:** static audit + re-analysis of existing measurements. **No new runs** (machine busy).
- **Related:** [EXP-009](../experiments/EXP-009-frame-attribution.md), [EXP-013](../experiments/EXP-013-original-vs-optimized.md),
  [EXP-014](../experiments/EXP-014-fps-cap.md), [T-050 report](2026-11-15-low-level-optimization-validation.md)

## 1. Method

Read the vendored engine (`vendor/GeneralsGameCode`, GeneralsMD + Core) for per-frame work that
scales with object/drawable count, and cross-checked each finding against the phase timings we
already measured (EXP-009/EXP-013). Nothing here is a measurement; every claim is `[VERIFIED]`
source or `[INFERRED]` from the recorded timings, and every fix has a validation plan.

Reference numbers on the current engine (`B54939EB…B88C`):

| Scenario | median | p95 | where the time goes |
|---|---:|---:|---|
| stock 1,000 tanks, Low profile, uncapped | 6.62 ms | 7.96 | logic ~3.3 ms, draw ~1.85 ms |
| ShockWave 1,000 ×5 nuke cycles | 3.81 ms | 61.72 | most frames cheap; spawn/death bursts dominate the tail |
| 1,000 tanks, High detail (EXP-004) | 25.02 ms | – | draw ~14.5 ms, of which shadows ~7.4 ms |

## 2. Critical findings (ranked for the profile we ship)

### 2.1 `processDestroyList` is O(D × N) — mass-death burst cost  `[VERIFIED]`

`GameLogic.cpp:2574-2609`: for **every** destroyed object the code scans the **entire**
`m_sleepyUpdates` vector to collect that object's update modules, then erases them one by one.
With D destroyed objects and N sleepy modules, a 300-unit wipe is `300 × N` pointer comparisons in
one frame.

Verified details that tighten this:

- The `m_normalUpdates` scan above it (`:2573-2589`) is wrapped in `ALLOW_NONSLEEPY_UPDATES`, which
  is **not defined anywhere in this tree** — that half is compiled out.
- Every object already carries its behaviour modules (`Object::getBehaviorModules()` →
  `BehaviorModule**`), and `BehaviorModule::getUpdate()` (`BehaviorModule.h:110`) exposes the
  update interface. Every implementation returns `this` and derives from `UpdateModule`
  (`UpdateModule.h:170`, `BridgeBehavior.h:148`, `SpawnBehavior.h:147`).
- Each `UpdateModule` already knows its heap index (`friend_getIndexInLogic()`), which is what the
  erase path uses.

Measured relevance: the destroy phase peaks at **92.4 ms** in the five-cycle run (EXP-009), ~0.28 ms
per destroyed object.

**Refined fix:** replace the vector scan with an iteration over `currentObject->getBehaviorModules()`,
collect the update modules with `friend_getIndexInLogic() >= 0`, sort those indices descending and
erase — O(k log k) per object instead of O(N). This also removes the silent `MAX_SUO = 256`
truncation (`:2597`, objects with more than 256 update modules leak modules today).

**Validation:** add a counter of "modules considered" per destroy frame (expect `D×k`, not `D×N`),
assert the same set of modules is removed (compare object census and `ZH_OBJLOG`), and measure
destroy max + frame tail on the five-cycle scenario. Identical destructor order must be preserved
(erase descending by index does that).

### 2.2 Sleepy-update maintenance rebalances the whole heap per pop  `[VERIFIED]`

`GameLogic.cpp:4630-4635`: after each popped sleepy update the code pushes it back and calls
`rebalanceSleepyUpdate(0)`, which also allocates/sifts. At 1,000 units × several modules this is
O(modules · log N) per frame with churn.

**Refined fix:** bucket modules by next-call frame (the same idea `SleepyUpdate` already encodes):
keep a small array indexed by `frame - now` and only sort within the current bucket. **Validation:**
logic `updates` p95 on the 1,000-unit scene, plus a counter of sift operations.

### 2.3 Every logic frame scans all objects for disabled status  `[VERIFIED]`

`GameLogic.cpp:4682-4688`: `for (Object *obj = m_objList; ...) if (obj->isDisabled()) checkDisabledStatus();`
O(N) per frame to service a set that is empty most of the time.

**Refined fix:** maintain an intrusive list of disabled objects, push on `setDisabled`, pop when the
timer expires. **Validation:** `l_rest`/logic median on the 1,000-unit scene (expect small gain,
but it is pure waste removal).

### 2.4 Global critical sections on every allocation and every string copy  `[VERIFIED]`

- `GameMemory.cpp:1643,1728,1787,1808` take `TheMemoryPoolCriticalSection` on pool alloc/free;
  the DMA path takes a second section (`:2176,2292`).
- `AsciiString.cpp:122` takes `TheAsciiStringCriticalSection` on **every copy** and `:217` on release.
- These are release-active (only the pool *debug* checks are `RTS_DEBUG`-gated).

An uncontended `Enter/LeaveCriticalSection` pair costs ~20-40 ns; at tens of thousands of
allocations/copies per second that is measurable but not dominant. The exception is burst frames
(spawn 1,000 objects, mass death), where allocations spike.

**Refined fix (measure first):** add a counter/timer around the pool lock; if allocation is a
material share of the 85 ms spawn, introduce a single-threaded fast path (the simulation is
single-threaded) or a per-frame arena for transient modules. For strings, prefer `const&`/refcount
elision in hot loops (several hot paths copy template names).

### 2.5 Shadow volumes are rebuilt every frame, with heap churn and full buffer scans  `[VERIFIED]`

`W3DVolumetricShadow.cpp`:
- `:1669-1677` the time-based rebuild guard is **commented out**, and the surrounding comment says
  it should be built only when the light angle or the object rotation sufficiently changes;
- `:2182-2199` each rebuild sets `SHADOW_DYNAMIC`, `resetShadowVolume`, `allocateShadowVolume`
  (`NEW Geometry`) and `constructVolume` — heap allocation per mesh per frame;
- `:3642,3663,3685` the manager scans **every vertex buffer** three times per frame;
- `:3576-3598` distance culling exists only behind `ZH_SHADOWDIST` (default off).

This matches the measured High-detail cost: shadows off saves 7.4 ms of 25.0 ms at 1,000 units
(EXP-004), i.e. ~30%.

**Refined fix:** restore the rebuild-on-change guard (light direction delta / object transform
delta), keep the geometry allocation across rebuilds, replace the three VB scans with an intrusive
list of non-empty buffers, and make the distance cull default-on with a data constant.
**Validation:** High-detail 1,000 units, uncapped, shadows on: expect the 7.4 ms shadow cost to drop
substantially; visual check that shadows still track moving units.

**Note:** the recommended Low profile already disables shadows, so 2.5 does not help Low-profile
users — it helps High-detail users.

## 3. Secondary findings

| # | Finding | Where | Why it matters | Idea |
|---|---|---|---|---|
| 3.1 | Icon pass projects every drawable ~5-8 times (health, ammo, contained, veterancy, caption, text) | `Drawable.cpp:2674,2894,2961,3142,3678,3705,3765` | measured whole pass 0.65 ms p95 at 1,432 drawables — small, but 5-8× the necessary projection work | project once in `drawIconUI`, pass the screen point down |
| 3.2 | `iterateDrawablesInRegion` has no spatial index (world AABB test only) | `GameClient.cpp:875-892` | drives icons and hover picking; OK today, scales badly with drawables | partition-cell or render-list-driven enumeration |
| 3.3 | Hover/drag picking scans all drawables and projects each | `W3DView.cpp:2418-2456` (code TODO) | mouse-over cost grows with army size | same spatial index as 3.2 |
| 3.4 | `DisplayString::draw` flushes the 2D batch per string | `W3DDisplayString.cpp:232` | many captions/health texts = many draw calls | render into the persistent 2D batch, flush once |
| 3.5 | 2D batching exists but is only enabled for the HUD and one debug view | `Display.cpp:321-338`, `W3DInGameUI.cpp:391` | shell/windows/menus draw unbatched | enable batching at the display level |
| 3.6 | `drawImage` resolves textures by filename per call | `W3DDisplay.cpp:2896` | measured cheap for icons (0.0005 ms) but affects all GUI | cache on `Image` (must ref-count; earlier attempt crashed) |
| 3.7 | Two full RenderList passes + per-object light setup | `W3DScene.cpp:456,1195,709,730` | high object counts pay light setup twice | cache light environment per template; fuse passes |
| 3.8 | Shroud status resolved 3-4× per drawable per frame | `GameClient.cpp:689-719`, `W3DScene.cpp:648`, `W3DView.cpp:1248` | cheap per call, repeated | resolve once, store on `Drawable` |

## 4. What is *not* worth optimizing (measured)

- Heal/repair icons: ~0.0005 ms each ([EXP-015](../experiments/EXP-015-heal-repair-icon-cost.md)).
- Heal logic: +0.12 ms per 300 simultaneous heals.
- Repair-field queries: ≤1 per frame.
- Broadphase candidate work: already reduced 82% by T-046/T-055.

## 5. Recommended order (pending machine time)

1. **2.1 destroy-list indexing** — biggest measured burst (92 ms) and clearly O(D×U).
2. **2.5 shadow rebuild caching** — biggest measured steady cost at High detail (7.4 ms).
3. **2.2 sleepy heap bucketing** and **2.3 disabled list** — cheap, safe, steady-state wins.
4. **2.4 allocator/string locking** — measure first (counter), then decide.
5. Secondary items only if a phase measurement shows them.

Each needs the project's A/B rule: alternating pairs, gain beyond run variation, identical
behaviour (objects present, collisions, paths).

## 6. Caveats

- No new measurement was taken; impact estimates come from the recorded phase timings.
- Line numbers include our project patches, so they will drift from upstream.
- The `Share` wording above is deliberate: the destroy phase *includes* per-object destructor work
  (drawables, debris creation), not only the list scans. 2.1's validation must isolate the scan
  count with a counter before claiming the 92 ms.
