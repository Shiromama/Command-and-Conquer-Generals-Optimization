# Patches

Tracked patches against `vendor/GeneralsGameCode` @
`0ff1220caf8dbcf254e4ad63ea8e907f22089624`. The vendor tree itself is gitignored; these files
are the durable record.

> **Use [`current-engine.patch`](current-engine.patch), not this table's patches, to reproduce
> the current build.** The per-task files are historical snapshots generated against partially
> patched trees; later files contain earlier changes and they do not apply as a series. See
> [`../../docs/issues/ISSUE-0015-engine-patch-series-not-reproducible.md`](../../docs/issues/ISSUE-0015-engine-patch-series-not-reproducible.md).

| Patch | Task | Status |
|---|---|---|
| [`current-engine.patch`](current-engine.patch) | T-049 | Cumulative current engine; applies to a clean index and reproduces `F606E603...C007A3` |
| [`T-023-dpi-awareness.patch`](T-023-dpi-awareness.patch) | T-023 | Verified: 1920x1080 physical client, exclusive fullscreen works |
| [`T-015-frame-logger.patch`](T-015-frame-logger.patch) | T-015 | Verified: produces `frame,frame_ms` CSV |
| [`T-015-benchmark-harness.patch`](T-015-benchmark-harness.patch) | T-015 | Test-only: `ZH_MAP`, `ZH_STRESS`, `ZH_PERF_SPLIT`, `ZH_FPS`, `ZH_NOSHADOW`; verified with 1,000 units |
| [`T-021-scene-distance-cull.patch`](T-021-scene-distance-cull.patch) | T-026 | Opt-in `ZH_DRAWDIST`; verified draw 27.3 -> 18.1 ms at distance 400 |
| [`T-030-shadow-culling.patch`](T-030-shadow-culling.patch) | T-030/T-032 | Opt-in `ZH_SHADOWDIST` / `ZH_SHADOWSIZE`; High uncapped 37.23 -> 30.23 ms at distance 400, or 30.76 ms at 120 px, units visible |
| [`T-036-shockwave-stress.patch`](T-036-shockwave-stress.patch) | T-036/T-038 | Test-only nuke/destruction harness; verified with ShockWave at 400/1,000 units (EXP-008) |
| [`T-039-adapter-selection.patch`](T-039-adapter-selection.patch) | T-039 | Adapter selection + adapter-correct mode queries; no-op on a one-adapter D3D8 system (verified with `tools/adapter-probe.cpp`) |
| [`T-041-debris-hulk-budget.patch`](T-041-debris-hulk-budget.patch) | T-041 | `ZH_DEBRIS_PER_FRAME` / `ZH_HULK_PER_FRAME`; verified on a 1,000-unit nuke wipe (logic max 5.7 ms); optional fallback. Also carries test-only per-call creation timing (`ZH_OCL_LOG`). |
| [`T-043-cosmetic-partition.patch`](T-043-cosmetic-partition.patch) | T-043/T-046 | `ZH_DEBRIS_BROADPHASE=1` (default): 3D bounding-sphere early-out keeps every collision, pair build 90.5 -> 4.0 ms max, frame p95 54.4 -> 46.0. `ZH_DEBRIS_PAIR_FILTER` (physics change, default off) and `ZH_COSMETIC_PARTITION` (blunt skip) are fallbacks. `ZH_PARTITION_LOG` timers. |
| [`T-047-perf-diagnostics.patch`](T-047-perf-diagnostics.patch) | T-047 | Test-only `ZH_DEBRIS_LOG` draw/model logging and `ZH_PERF_SPLIT` client phase timers; used to prove debris render and to attribute the nuke-event spikes. |

## Apply / revert

```powershell
# from the repository root (clean vendor checkout)
git -C vendor\GeneralsGameCode apply --ignore-space-change engine\patches\current-engine.patch

# revert
git -C vendor\GeneralsGameCode apply -R --ignore-space-change engine\patches\current-engine.patch
```

`--ignore-space-change` is needed because the vendor blobs are CRLF and Git strips CR from patch
context by default. Do not apply the per-task patches as a chain.

Then rebuild with `tools\build-engine.ps1`.

## Rules

- One patch = one measurable or verified behavior change.
- Rebuild and re-test after each patch; record results in `docs/research/` and `docs/log.md`.

