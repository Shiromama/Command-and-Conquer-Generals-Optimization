# EXP-023: DrawDistance default reverted to off (user-visible pop-out)

> **Status:** complete · **Date:** 2026-11-17 · **Task:** T-072
> **Related:** [ISSUE-0023](../issues/ISSUE-0023-draw-distance-hides-units.md),
> [EXP-002](EXP-002-scene-distance-cull.md) (the cull), [EXP-016](EXP-016-default-on-package.md)

## 1. Question

The default-on package set `DrawDistance = 400`. During a live demo run the user reported that tanks
vanish when the camera moves toward them, and reappear when the control bar is minimised (which
recentres the view). Is the default wrong, and what does turning it off cost on the two reference
scenes?

## 2. Cause

`RTS3DScene::Visibility_Check` hides any render object whose **horizontal distance from the camera
eye** exceeds `DrawDistance`. The camera sits behind/above its target, so at normal zoom, on-screen
units are already farther than 400 units from the eye and get culled. EXP-002 designed this as
opt-in *because it hides distant units*; T-064 made it default-on without re-testing that.

## 3. Change

`OptionPreferences::getDrawDistance()` now returns **0 (off)** when `Options.ini` has no key. The key
still works when set (env `ZH_DRAWDIST` > `Options.ini` > default 0). `docs/optimizations.md` ships
`DrawDistance = 0` in the Performance preset and keeps 400 only in the "Aggressive" preset used by
the stress harness.

## 4. Measurements (with the cull at 400, before the fix)

Same harness, engine `D337B939`, performance profile (AA 0 + Low), uncapped; stock copy 1,000 tanks
40 s, ShockWave copy 1,000 units × 5 nuke cycles 45 s.

| scene | config | median | FPS | p95 | FPS |
|---|---|---:|---:|---:|---:|
| stock | retail-equivalent (AA 8 + High) | 22.79 ms | 43.9 | 27.41 ms | 36.5 |
| stock | shipping (cull on) | 9.23 ms | 108.4 | 11.50 ms | 87.0 |
| nuke | retail-equivalent (AA 8 + High) | 8.77 ms | 114.0 | 54.58 ms | 18.3 |
| nuke | shipping (cull on) | 4.50 ms | 222.1 | 23.22 ms | 43.1 |

## 5. Post-fix demo (default off, engine `912EC1EB`)

Same commands, `Options.ini` with **no** `DrawDistance` key, engine rebuilt with the default at 0.
2 runs per cell.

| scene | config | median | FPS | p95 | FPS | p99 | FPS |
|---|---|---:|---:|---:|---:|---:|---:|
| stock 1,000 | retail-equivalent (AA 8 + High) | 22.54 ms | 44.4 | 24.78 ms | 40.4 | 36.32 ms | 27.5 |
| stock 1,000 | shipping (cull off) | 9.28 ms | 107.7 | 10.95 ms | 91.3 | 12.18 ms | 82.1 |
| nuke 1,000×5 | retail-equivalent (AA 8 + High) | 8.43 ms | 118.6 | 79.25 ms | 12.6 | 93.83 ms | 10.7 |
| nuke 1,000×5 | shipping (cull off) | 3.95 ms | 253.3 | 27.23 ms | 36.7 | 39.83 ms | 25.1 |

Per-run spread is tight (stock ship 9.21/9.37 ms; nuke ship 3.96/3.94 ms).

**Impact:** stock **44.4 → 107.7 FPS** (2.43×) at the median, p95 **40.4 → 91.3 FPS** (2.26×);
nuke **118.6 → 253.3 FPS** (2.14×) at the median, p95 **12.6 → 36.7 FPS** (2.91×).

## 6. What the cull was actually worth

| scene | cull off (shipping now) | cull at 400 (previous default) | difference |
|---|---:|---:|---|
| stock 1,000 | 9.28 ms / 107.7 FPS | 9.23 ms / 108.4 FPS* | none |
| nuke 1,000×5 | 3.95 ms / 253.3 FPS | 4.50 ms / 222.1 FPS* | noise, favours off |

*From the pre-fix demo in §4. The stock comparison here is the same-session pair; earlier sessions
measured 7.1 ms for the cull-on build, but that run had a different scene load, so it is not used as
the comparison.

**Conclusion:** in these two scenes the object-distance cull buys nothing measurable beyond noise —
there is no reason to pay for it with units popping out of view. It stays available as an opt-in
setting (`DrawDistance = 400`, "Aggressive" preset) for anyone who wants to try it on a weak GPU.

## 7. Verification

- Engine `912EC1EB…3965` staged into both game copies; `Options.ini` had no `DrawDistance` key during
  the runs (the harness only pins `ZH_COSMETIC_PARTITION=1`).
- `python tools\check_docs.py` exits 0.
- Artifacts: `artifacts/2026-11-17-demo-1000/` (8 run folders + `summary.json`),
  `artifacts/2026-11-17-demo-1000-prefix-summary.txt` (pre-fix reference).
