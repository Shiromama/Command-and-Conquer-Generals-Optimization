# EXP-009: Where a frame actually goes (single-clock attribution)

> **Status:** in progress · **Date:** 2026-11-15 · **Task:** T-051
> **Related:** [T-050 validation report](../research/2026-11-15-low-level-optimization-validation.md),
> [EXP-008](EXP-008-shockwave-nuke-performance.md), T-043, T-046, T-048

## 1. Question

T-050 left one question open: the dense 1,000-unit run has a 149.95 ms update maximum, a
91.95 ms destroy maximum, and 100–350 ms frames that persist when debris are suppressed. The
existing loggers (`ZH_PERF_LOG`, `ZH_PERF_SPLIT`, `ZH_PERF_LOGIC`) measure different clocks and
different windows, so a spike could only be guessed at. This experiment answers:

1. Which phase of a frame holds a 100–350 ms spike?
2. What composes the update/destroy maxima?
3. Is the residual "nuke hitch" the nuke, the spawn, or something outside the measured phases?

## 2. Method

Test-only instrumentation (`ZH_ATTR_LOG`, patch `T-051`), one CSV row per rendered frame:

| Group | Columns |
|---|---|
| Frame | `interval`, `pre` (CRC/radar), `audio`, `client`, `msg`, `net`, `logic`, `pacer`, `gap` |
| Client | `shell`, `draw`, `particles`, `displaystr`, `ingameui` |
| Logic | `l_updates`, `l_ai`, `l_build`, `l_partition`, `l_destroy`, `l_rest` |
| Lifecycle | `slowest_update[_obj]` (opt-in), `destroyed`, `slowest_destroy`, `spawned`, `spawn_ms`, `nukes` |

`gap` is the residual (interval minus every measured bucket) so unmeasured time cannot hide.
`ZH_ATTR_SAMPLE=1` adds per-module and per-object timers for the worst offender of the frame.

Scenario: ShockWave, `game/shockwave-engine`, d3d8to9 + high-performance GPU preference,
1920×1080 borderless, `ChinaTankBattleMaster`, dense 32×32 grid, real
`NeutronMissileDUMMYObject` warheads. The mod cannot auto-start (EXP-008 §6), so matches are
started by the scripted UI clicks in `tools/benchmark-shockwave-attrib.ps1`.

## 3. Results

Frame times (steady state, first 30 presented frames dropped), from `perf.csv`:

| Run | median | p95 | p99 | max | >33.3 ms | >100 ms |
|---|---:|---:|---:|---:|---:|---:|
| 1,000 units, 1 warhead, all debris | 22.73 | 33.52 | 39.77 | 410.83 | 14.1% | 5 |
| 1,000 units ×5 cycles, 9 warheads, all debris | **33.33** | **77.42** | **116.53** | 337.87 | **48.9%** | **70** |
| same, `ZH_DEBRIS_PER_FRAME=1` (debris dropped) | 18.82 | 38.90 | 54.51 | 329.95 | 17.5% | 21 |

Phase composition of the five-cycle run (ms):

| bucket | median | p95 | p99 | max |
|---|---:|---:|---:|---:|
| pre (CRC + radar) | 0.00 | 0.00 | 0.01 | 0.05 |
| audio | 0.08 | 0.48 | 0.84 | 11.29 |
| client | 9.72 | 36.37 | 62.77 | 191.34 |
| messages | 0.02 | 0.07 | 0.14 | 3.20 |
| network | 0.00 | 0.00 | 0.00 | 0.00 |
| logic | 6.54 | 39.25 | 69.60 | 1694.37 |
| pacer | 0.14 | 32.73 | 32.75 | 42.01 |

Logic sub-phases: updates median 4.47 / p95 25.41 / max 151.10; partition 0.52 / 7.57 / 28.15;
destroy 0.47 / 5.42 / **92.42**.

## 4. What the numbers say

### 4.1 The biggest frames are the cycle boundaries, not the nuke

The four worst logic-update frames (151.1, 140.8, 138.7, 134.2 ms at logic frames 724/484/964/244)
are each the frame **after** a spawn. The slowest single module in those frames is 0.8–1.5 ms, so
the cost is the *count*: 1,000 fresh objects run their first `AIUpdateInterface` and
`PhysicsBehavior` tick in the same frame. There is no single hot object.

The spawn frame itself costs 82–86 ms in `TheThingFactory->newObject` alone, and a further
61–92 ms destroying the previous cycle's 234–325 survivors (0.28 ms each; the slowest single
object is 0.8 ms).

### 4.2 The nuke is a damage cascade, not a scan

Nuke-tick frames show `slowest_update = NeutronMissileSlowDeathBehavior` at 12.5–14.3 ms per
warhead. Nine warheads fired on one frame therefore cost ~80–90 ms of logic. The source
(`NeutronMissileSlowDeathBehavior::doBlast`) iterates the partition range and calls
`topple()`/`attemptDamage()` per object; the time is the resulting damage/death/debris cascade,
not the iteration itself. A real game fires one warhead, so the gameplay cost is ~13 ms, not 90.

### 4.3 Debris lifecycle dominates the mass-death frame

Suppressing debris creation (`ZH_DEBRIS_PER_FRAME=1`) changes the same scenario from
33.33/77.42 to 18.82/38.90 ms median/p95 and cuts destroy max 92.4 → 30.3 ms and updates max
151.1 → 82.5 ms. So ~60 ms of the destroy burst and ~70 ms of the update burst are debris
creation and debris simulation. This confirms EXP-008 §7 from the other direction: debt is paid
when cosmetic objects are *created and simulated*, not when they are merely registered.

### 4.4 Nothing hides outside the phases

With the corrected logger, the only unmeasured time is the loop gap between the previous frame's
pacer exit and the next frame's start: median 0.02 ms, p95 0.04 ms, max 0.26 ms over a 30 s run
(`artifacts/2026-11-15-attrib-fixed2/`). `pre`, `msg` and `net` are noise; audio peaks at 11 ms,
not 300. The largest single client sample is `shell` at 189.5 ms, a shell/UI transition rather
than gameplay — matching EXP-008 §12's 179.8 ms shell sample. Every large *gameplay* frame is
inside a measured phase.

The first capture build computed `interval` from the previous frame's start, so its `gap` column
was meaningless; that is fixed (see §5).

## 5. Caveats

- `ZH_ATTR_LOG` adds two QPC reads per phase (and, with sampling, per module). Absolute numbers
  are therefore a few percent above a logger-free run; all comparisons here are between runs of
  the same binary with the same logger on.
- The capture build computed `interval` from the *previous* frame's start, so its `interval` and
  `gap` columns are shifted by one row and `gap` is not meaningful. Phase buckets are same-frame
  and correct, so the phase tables above stand. All frame-time tables use `perf.csv`, which is
  taken at present time and is unaffected. Both defects (interval origin and a reset that ran
  before logic instead of before the client, zeroing the client sub-phases) are fixed in the
  shipped T-051 patch; the analyzer reports the residual directly.
- Logic frame numbers do not advance on frames where `canUpdateGameLogic()` is false, so the
  `frame` column repeats across rendered frames; `row` is the render-frame index.
- The match-start frame (first present after `MSG_NEW_GAME`) is ~1.7 s of asset loading and is
  excluded from the steady-state table.
- Single-player ShockWave on a test engine; not a retail/online measurement.

## 6. Consequences for the roadmap

1. Debris creation/simulation is the only large, removable cost in this scenario; the existing
   T-041 budget removes it by dropping pieces, which T-048 rejects. A **deferred** debris queue
   (create all pieces, spread over frames) is the next candidate, and needs its own validation.
2. The spawn burst is harness-shaped (1,000 objects at once) and not a normal gameplay cost.
3. The nuke tick cost scales with warheads × victims; at one warhead it is ~13 ms and not worth
   restructuring the damage cascade for.

## 7. Artifacts

- `artifacts/2026-11-15-attrib-nuke1/` — 1,000 units, 1 warhead.
- `artifacts/2026-11-15-attrib-5cycle/` — 1,000 units ×5 cycles, 9 warheads.
- `artifacts/2026-11-15-attrib-5cycle-nodebris/` — same, debris capped at 1/frame.
- `artifacts/2026-11-15-attrib-summary.json` — consolidated statistics.
- `tools/analyze-attr-log.py`, `artifacts/2026-11-15-attrib-consolidate.py` — reproduction.
