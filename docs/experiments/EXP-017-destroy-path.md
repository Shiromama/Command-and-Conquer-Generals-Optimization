# EXP-017: T-065 destroy-path O(k) — measured

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-065
> **Related:** [architecture audit](../research/2026-11-16-low-level-architecture-audit.md) §2.1,
> [EXP-016](EXP-016-default-on-package.md), [EXP-009](EXP-009-frame-attribution.md)

## 1. Change

`GameLogic::processDestroyList` used to scan the **entire** `m_sleepyUpdates` vector for every
destroyed object (O(D×N)) and silently truncated at 256 modules. It now asks the dying object for
its own behaviour modules (`getBehaviorModules()`), reads each module's heap index
(`friend_getIndexInLogic()`), sorts the indices descending and erases — O(k log k) per object. A
full-scan fallback remains for objects with more than 256 update modules (never observed).

## 2. Setup

- A = `5FA73119…0168` (baseline), B = `F7E1E265…FE10` (T-065). Same source otherwise, `-NoLtcg`
  for both, performance profile, uncapped.
- Scene: ShockWave copy, 1,000 units × 5 spawn/nuke cycles (9 real warheads), 45 s measured.
- 3 alternating pairs (A,B,A,B,A,B) via `tools/ab-engine-shockwave.ps1`.

## 3. Results

| run | median | FPS | p95 | p99 | max | destroy max | destroy p95 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A-1 | 3.98 ms | 251.1 | 48.98 | 68.16 | 360.1 | **81.09 ms** | 3.01 |
| A-2 | 4.09 ms | 244.4 | 50.57 | 70.59 | 365.9 | **104.92 ms** | 3.42 |
| A-3 | 4.43 ms | 225.5 | 51.61 | 71.34 | 356.8 | **92.71 ms** | 3.21 |
| B-1 | 4.28 ms | 233.9 | 48.97 | 66.96 | 350.4 | **7.87 ms** | 0.13 |
| B-2 | 4.20 ms | 237.8 | 48.11 | 65.24 | 344.5 | **8.28 ms** | 0.12 |
| B-3 | 4.19 ms | 238.9 | 47.60 | 67.15 | 358.3 | **8.31 ms** | 0.12 |
| **A mean** | **4.17** | **239.8** | **50.39** (19.8 FPS) | **70.03** (14.3 FPS) | 361.0 | **92.91** | 3.21 |
| **B mean** | **4.22** | **237.0** | **48.23** (20.7 FPS) | **66.45** (15.0 FPS) | 351.0 | **8.15** | 0.12 |
| **delta** | +1.2% | −2.8 | **−4.3%** | **−5.1%** | −2.7% | **−91.2%** | **−96.3%** |

Object census at the end of each run keeps every debris piece with a drawable and visible
(`debris = debrisD = debrisV`, 8,249–8,276 in the B runs), so nothing is lost by the new removal
path.

## 4. Reading it

- The **destroy spike** — the 92 ms burst the audit predicted — is gone: **92.9 → 8.2 ms
  (−91%)**, p95 3.2 → 0.12 ms.
- That shows up in the frame tail: p95 50.4 → 48.2 ms (**19.8 → 20.7 FPS**), p99 70.0 → 66.5 ms
  (**14.3 → 15.0 FPS**), worst frame 361 → 351 ms.
- The median is 1.2% slower (239.8 → 237.0 FPS), inside the A-run spread (3.98–4.43 ms); the
  per-object rebuild is not on the steady-state path.
- No behaviour change: same objects, same debris, same counts.

## 5. Artifacts

`artifacts/2026-11-16-t065-ab/` — `A-1..3`, `B-1..3`, `summary.json`, `summarize.py`, `manifest.md`.

## 2026-11-17 remediation follow-up

[VERIFIED] T-079 follow-up: the fixed 256-entry overflow fallback was still truncated (ISSUE-0034). It is replaced by a reusable unbounded vector; compiled actual-source tests cover up to 1024 modules. See [remediation](../research/2026-11-17-optimization-remediation.md).
