# EXP-022: T-068 allocator and AsciiString lock share — measured

> **Status:** complete · **Date:** 2026-11-17 · **Task:** T-068
> **Related:** [architecture audit](../research/2026-11-16-low-level-architecture-audit.md) §2.4,
> [EXP-021](EXP-021-shipping-package-tail.md), [EXP-013](EXP-013-original-vs-optimized.md) §5.2

## 1. Question

The audit's §2.4 flagged two global locks on hot paths: the object-pool critical section taken by
**every** allocation/free (`ObjectPoolClass::ObjectPoolCS`) and the `AsciiString` critical section
taken on string construction/copy. Are they a large enough share of frame time to justify changing
them (lock-free pool, per-thread string buffers)?

## 2. Method

- New `Core/Libraries/Source/WWVegas/WWLib/ZhLockStats.h`: cumulative counters plus a scoped timer.
  The timer is constructed **before** the lock guard, so destruction order times enter + body +
  leave. Everything is inert unless `ZH_LOCK_LOG=<path>` is set (one cached branch per lock).
- Sites instrumented: 2 pool sites (`Allocate_Object_Memory`, `Free_Object_Memory`), 3 `AsciiString`
  sites (the three `ScopedCriticalSection` guards in `AsciiString.cpp`).
- Dump: one cumulative row every 30 frames from `DX8Wrapper::End_Scene` (where the frame-time log
  already lives): `row,elapsed_ms,pool_calls,pool_ms,str_calls,str_ms,qpc_pair_us`.
- **Measurement-overhead correction:** each timed call costs a `QueryPerformanceCounter` pair. The
  engine measures that cost in-process at startup (0.0456 µs here) and writes it in the CSV; the
  analyser (`tools/analyze-lock-log.py`) subtracts `calls × pair` from the measured totals, so the
  reported numbers are the locks, not the stopwatch.

## 3. Setup

- Engine `D337B939…33D5` (instrumented), `-NoLtcg`, performance profile (AA 0 + Low), uncapped.
- Stock copy, 1,000 tanks, 40 s; window = frames 30–5340 (36,079.9 ms, 147.2 FPS average).

## 4. Results

| counter | calls/frame | measured | minus QPC overhead | true | share of elapsed |
|---|---:|---:|---:|---:|---:|
| Object pool CS | 19.3 | 14.0 ms | 4.7 ms | **9.4 ms** | **0.03%** |
| AsciiString CS | 1,587.1 | 740.6 ms | 384.3 ms | **356.3 ms** | **0.99%** |
| combined | 1,606.4 | 754.6 ms | 389.0 ms | **365.7 ms** | **1.01%** |

Per frame the two locks together cost **≈69 µs** (1.0% of a 6.8 ms frame). Per call: pool
≈0.11 µs, string ≈0.22 µs (after overhead correction).

## 5. Reading it

- **The pool lock is irrelevant: 0.03%.** Only ~19 allocations/free per frame at steady state, which
  is what the object pools exist to guarantee. Nothing to do.
- **The string lock is ~1%** — real but small. A lock-free string implementation could recover at
  most that 1%, i.e. ~0.07 ms/frame at this frame rate, in exchange for a rewrite of a class used
  everywhere. **Not worth it.**
- The interesting number is the *call rate*: **1,587 critical-section acquisitions per frame** from
  `AsciiString`. If string cost ever matters, the lever is reducing copies (const-ref parameters,
  cache the string form of hot template names), not replacing the lock.
- **Decision: no change.** `ZH_LOCK_LOG` + `ZhLockStats.h` stay as a diagnostic (inert unless the
  env var is set), so this can be re-measured cheaply if the string call rate changes.

## 6. Process notes (honest record)

- The first build linked without recompiling the TUs that instantiate the pool template (stale
  objects), so an early dataset undercounted pool calls; a clean rebuild was done before trusting
  the numbers. Two compile errors were fixed on the way: most-vexing-parse on
  `ZhLockTimer t(f());` (needs double parens) and a comment/class line accidentally joined by an
  edit.
- The first calibrated run wrote an empty `qpc_pair_us` column (format string missing a specifier);
  the reported table is from the corrected build, which prints it.
- One scene, one run — enough to answer "is this worth work?" (>10× margin on the decision), not a
  precision profile.

## 7. Artifacts

`artifacts/2026-11-16-t068/` — `zhlocks-final.csv` (calibrated), `final/` (`frames-run1.csv`,
`benchmark-parameters.json`), `zhlocks.csv` + `zhlocks-full.csv` (superseded partial runs),
`manifest.md`.
