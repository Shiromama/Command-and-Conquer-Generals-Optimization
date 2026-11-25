# Last Stand congestion pricing: above 30 FPS at a gameplay cost

- **Date:** 2026-11-25
- **Author/agent:** Codex
- **Task:** T-112
- **Status:** Reviewed

## Question

Can the 481-frame, 1,000-unit Last Stand heavy window reach 30 FPS, and what does the ally
congestion price trade away?

## Answer (short)

[VERIFIED] The 66% ally-congestion price reaches **30.06 ms / 33.3 FPS** in the heavy window
(path 9,684 vs 14,680 us/frame), and **29.01 ms / 34.5 FPS** when combined with three visual
trades. It is a **gameplay trade**, not a behaviour-preserving default: the replay still reaches
frame 17,402 but produces a different, deterministic command stream (CRC `695F3403`, 523 commands
vs the reference `04C62655`, 983 commands).

[VERIFIED] The 33% price is the user's preferred feel and the source playtest default, but it ends
the replay at about frame 8,400. The response is non-monotonic: 0% completes but is slower (43.75
ms); 50% and 60% resolve early; 66% is the lowest value found that both completes and improves.
The **alpha.2 package (2026-11-26) ships the 33% default**; the 66% benchmark configuration and the
visual trades remain source/playtest options, so the 30.06 ms / 33.3 FPS and 29.01 ms / 34.5 FPS
benchmarks are not the package default.

## Method

- Replay: the 17,402-frame Last Stand `newmode` replay; heavy window frames 16,919-17,399.
- Load: 1,000 units, 1920x1080, the project `performance` options profile (AA off, Low detail,
  bilinear, anisotropy 2; shadows, particles and effects on).
- Renderer: `d3d8to9` v1.16.0 on the GTX 1650 Ti (the wrapper routes the hybrid laptop off the
  Intel UHD path).
- Measurement: `ZH_ATTR_LOG` frame/phase CSV, `ZH_ALLY_COST_PCT` for the congestion price, and
  `ZH_CALIB_LOG` fixed-work calibration to compare runs.
- Gate: heavy mean, p90, logic and path time, replay resolution frame, command count and CRC.

## Evidence

| Claim | Label | Where verified |
|---|---|---|
| 66% completes with heavy 30.06 ms / 33.3 FPS, path 9,684 us, logic 25.52 ms | `[VERIFIED]` | `docs/log.md`, entries dated 2026-11-25 |
| 66% is deterministic: identical CRCs and a 64,429-byte command file across repeats | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| 66% + three visual trades: heavy 29.01 ms / 34.5 FPS, p90 45.42, draw 2.29 ms | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| 29.01 ms run was 2.3% faster-calibrated than the 36.80 ms baseline (7,522 vs 7,697 us) | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| The 66% price is a different simulation (CRC `695F3403`, 523 commands) | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| 33% resolves at about frame 8,400; 50% about 15,600; 60% about 16,700 | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| 0% static routing completes but at 43.75 ms / 22.9 FPS, path 22,329 us | `[VERIFIED]` | `docs/log.md`, 2026-11-25 |
| The user judged the 33% live skirmish smoother than the replay variants | `[VERIFIED]` | `artifacts/2026-11-25-live-33/` and `docs/log.md` |

## Survival sweep

All runs use the same replay and build. "Resolved" means the battle reached the score screen; the
heavy window only exists when the battle reaches frame 17,402.

| `ZH_ALLY_COST_PCT` | Battle resolution | Heavy mean | Heavy FPS | Path (us/frame) |
|---:|---:|---:|---:|---:|
| 0 (static routing) | 17,402 | 43.75 ms | 22.9 | 22,329 |
| 33 | ~8,400 | not reached | not reached | not reached |
| 50 | ~15,600 | not reached | not reached | not reached |
| 60 | ~16,700 (200 frames short) | not reached | not reached | not reached |
| 66 | 17,402 | **30.06 ms** | **33.3** | **9,684** |
| 100 (retail price) | 17,402 | 36.80 ms | 27.2 | 14,680 |

## Cost decomposition

| Configuration | Interval | Logic | Path | Client | Draw | Commands |
|---|---:|---:|---:|---:|---:|---:|
| Full visuals, retail price | 36.80 ms | 31.00 ms | 14,680 us | 5.32 ms | 4.49 ms | 983 |
| Ally price 66% | 30.06 ms | 25.52 ms | 9,684 us | 4.30 ms | not recorded | 523 |
| Ally 66% + visual trades | **29.01 ms** | 25.40 ms | 9,770 us | 3.26 ms | 2.29 ms | 523 |

The 66% run had a 4% faster calibration and a faster client regime than the 36.80 ms baseline, so
part of the interval gap is machine state. The path and logic reductions reproduce across the 66%
runs and are the attributable part.

## Why lower prices are not free

[VERIFIED] Removing the ally terms entirely (`ZH_STATIC_ROUTING=1`) completes the replay but is
**slower**: 43.75 ms, path 22,329 us, 1,758 commands, 392 `zone_mismatch` failures. Charging less
(33%) changes who wins and ends the battle at about frame 8,400. The 66% value is the lowest
survivable price found.

[INFERRED] The ally terms are the engine's only congestion control. Removing them floods cells and
raises re-planning; reducing them changes group routing enough to change the battle. A port of the
modern static-navigation/local-avoidance model would need to add the avoidance half first.

## Limitations / open questions

- One replay, one laptop, one engine build. The absolute milliseconds are not a cross-machine
  prediction.
- The 66% configuration is a benchmark value; the user's live feel test used 33%. A live 66% test
  has not been run.
- The 33% live skirmish had 237-775 visible objects (about twice the replay load) and measured
  38.07 ms mean / 55.01 ms p90 with a 7,542 us calibration. It is not the heavy window.
- The visual trades were measured separately and combined once; the 29.01 ms run is a single
  best-case run, not a distribution.
- The published `0.1.0-alpha.2` package (2026-11-26) bakes the 33% default; the 66% benchmark and
  visual trades remain source-only. The earlier `0.1.0-alpha.1` predates this work.

## Artifacts

- `artifacts/2026-11-25-live-33/` - live 33% skirmish capture (`attr.csv`, `calib.csv`,
  `frames.csv`, `pf-frame.csv`, `scene-split.csv`, `sync.csv`).
- `build/engines/t112-playtest.exe` (`9660EB14...`) - staged build with the ally-cost switch and the
  three visual-trade switches.
- The 66% benchmark runs are recorded in `docs/log.md`; their raw per-frame logs were not retained
  as a separate artifact folder.
