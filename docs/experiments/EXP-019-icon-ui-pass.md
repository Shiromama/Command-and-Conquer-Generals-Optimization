# EXP-019: icon-pass ON/OFF A/B (`ZH_NO_ICON_UI`)

> **Status:** complete · **Date:** 2026-11-16 · **Task:** T-070 (follow-up to T-059)
> **Related:** [EXP-015](EXP-015-heal-repair-icon-cost.md) (per-icon cost),
> [EXP-016](EXP-016-default-on-package.md), [EXP-013](EXP-013-original-vs-optimized.md) §5.2

## 1. Question

The engine patch added a diagnostic toggle — `ZH_NO_ICON_UI=1` sets `m_drawIconUI = FALSE` and skips
the per-drawable HUD icon pass (health bars, heal/repair icons, captions). EXP-015 measured a single
icon at ~0.0005 ms; this asks whether the **whole pass** is worth anything at 1,000 units, i.e.
whether shipping it off by default would be a real gain or just lost UI.

## 2. Setup

- Engine `68D23E4E…7246`, performance profile (AA 0 + Low), uncapped, stock copy, 1,000 tanks, 40 s.
- 2 alternating pairs: A = icons on (default), B = `ZH_NO_ICON_UI=1`.

## 3. Results

| run | icons | median | FPS | p95 | FPS@95 | p99 | max |
|---|---|---:|---:|---:|---:|---:|---:|
| A-1 | on | 6.94 ms | 144.0 | 9.74 | 102.7 | 13.75 | 186.2 |
| A-2 | on | 6.44 ms | 155.3 | 7.54 | 132.7 | 9.05 | 105.0 |
| **A mean** | | **6.69 ms** | **149.4** | **8.63** | **115.8** | **11.40** | 145.6 |
| B-1 | off | 6.66 ms | 150.1 | 7.71 | 129.7 | 9.17 | 102.5 |
| B-2 | off | 6.45 ms | 154.9 | 7.53 | 132.9 | 8.90 | 109.1 |
| **B mean** | | **6.56 ms** | **152.5** | **7.62** | **131.3** | **9.04** | 105.8 |
| delta | | −2.0% | +3.1 | −11.8% | +13.4 | −20.7% | −27.3% |

Client/draw split (median, ms):

| run | icons | client | draw | logic |
|---|---|---:|---:|---:|
| A-1 | on | 3.63 | 1.87 | 2.96 |
| A-2 | on | 3.36 | 1.71 | 2.77 |
| B-1 | off | 3.40 | 1.71 | 2.95 |
| B-2 | off | 3.38 | 1.79 | 2.73 |

## 4. Reading it

- **Pair 2 is the clean pair** and shows no difference at all: median 6.44 vs 6.45 ms
  (155.3 vs 154.9 FPS), draw 1.71 vs 1.79 ms.
- Pair 1's A run was slow across **every** phase (client 3.63 vs 3.36 in A-2, logic 2.96 vs 2.77),
  so the headline −11.8% p95 / −20.7% p99 / −27% max in the table is that one noisy run, not the
  icon pass.
- Consistent with EXP-015: 1,000 healthy idle tanks raise almost no icons, so the pass has nothing
  to draw. The measurement cannot speak for a damaged/healing army under sustained fire.
- **Decision:** icons stay **on** by default. `ZH_NO_ICON_UI` remains a diagnostic switch only.

## 5. Artifacts

`artifacts/2026-11-16-icon-ab/` — `A-1`, `A-2`, `B-1`, `B-2` (`frames-run1.csv`,
`split-run1.csv`), `summary.json`, `manifest.md`, `analyze.py` (`tools/analyze-ab.py` run).
