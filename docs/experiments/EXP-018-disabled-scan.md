# EXP-018: T-067 skip the per-frame disabled scan

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-067
> **Related:** [architecture audit](../research/2026-11-16-low-level-architecture-audit.md) §2.3,
> [EXP-017](EXP-017-destroy-path.md)

## 1. Change

`GameLogic::update` walked **every object every logic frame** to call `checkDisabledStatus()` on the
disabled ones — O(N) per frame to service a set that is empty in normal play. A counter
(`g_zhDisabledObjects`) is now maintained in `Object::setDisabledUntil` / `Object::clearDisabled`,
and the loop is skipped while it is zero. The scan itself is unchanged when something is disabled.

## 2. Setup

- A = `F7E1E265…FE10` (T-065), B = `68D23E4E…7246` (T-065 + T-067). Same source otherwise, `-NoLtcg`,
  performance profile, uncapped.
- Stock copy, 1,000 tanks, 40 s, 2 alternating pairs (no disabled objects in this scene, i.e. the
  best case for the guard).

## 3. Results

| run | median | FPS | p95 | p95 FPS | p99 | max |
|---|---:|---:|---:|---:|---:|---:|
| A-1 | 7.71 ms | 129.7 | 9.47 | 105.6 | 13.50 | 144.4 |
| A-2 | 6.92 ms | 144.5 | 8.16 | 122.6 | 10.92 | 108.2 |
| **A mean** | **7.32** | **136.6** | **8.82** | **113.4** | **12.21** | – |
| B-1 | 7.14 ms | 140.1 | 9.02 | 110.9 | 11.98 | 106.2 |
| B-2 | 7.11 ms | 140.7 | 8.38 | 119.3 | 10.70 | 112.1 |
| **B mean** | **7.13** | **140.3** | **8.70** | **114.9** | **11.34** | – |
| delta | −2.6% | +2.7% | −1.4% | +1.3% | −7.1% | – |

## 4. Reading it

With two pairs the direction is favourable (median 7.32 → 7.13 ms, 136.6 → 140.3 FPS) but the A-run
spread (6.92–7.71 ms) is larger than the delta, so this is **not proven** as a speed-up. It is
strictly less work (an O(N) loop replaced by a counter test in the common case) and shows no
regression, so it stays.

The larger half of the audit's T-067 item — bucketing sleepy updates instead of rebalancing the
whole heap after each pop — was **not** implemented: the measured heap churn is small (the audit
put it in the microsecond range), and a bucketed scheduler changes wake ordering, which is exactly
the kind of risky rewrite the project rules ask to avoid without evidence. It is recorded as T-069
(backlog) with the measurement needed first.

## 5. Artifacts

`artifacts/2026-11-16-t067-ab/` — `A-1..2`, `B-1..2` (`frames-run1.csv`, `split-run1.csv`).

## 2026-11-17 remediation follow-up

[VERIFIED] T-079 follow-up: the counter optimization was removed after ISSUE-0029 exposed missing snapshot/destruction accounting. The original disabled-status scan is restored; its unproven gain did not justify derived lifecycle state. See [remediation](../research/2026-11-17-optimization-remediation.md).
