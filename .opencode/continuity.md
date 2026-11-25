# Session continuity

Updated: 2026-11-26
Phase: P2

## Current focus

T-112 is closed. The 481-frame Last Stand heavy window (1,000 units, 1920x1080) reaches **30.06 ms /
33.3 FPS** with the opt-in **66% ally-congestion price** and **29.01 ms / 34.5 FPS** with the three
visual trades. The 66% price is deterministic (`695F3403`, 523 commands) but gameplay-changing; the
replay still completes at 17,402. The **33% price is the user's feel choice** and the source playtest
default (`tools/play-t120.ps1 -AllyCost 33`); it resolves the replay at about frame 8,400.

T-129 published a tracked source/docs snapshot on public `main` and refreshed the README with the
Last Stand table, the heavy-window chart, the cost split, and the measured-and-rejected list. The
snapshot commit is `c4263ec`; small record and clarification commits follow it on `main`. The public
history was rewritten on 2026-11-26 to use the GitHub noreply identity; all reachable commits now use
noreply. Workspace paths, `%USERPROFILE%` tool paths, and the
retail vendor name are redacted in the public tree; the local evidence keeps the originals. A
tracked-file scan found no binaries, credentials, keys, tokens, email addresses, or real IPs.

## T-112 outcome and evidence

- **66% completes:** heavy 30.06 ms / 33.3 FPS, logic 25.52, path 9,684 us, client 4.30, calibration
  7,393 us. A repeat had identical CRCs and an identical 64,429-byte command file.
- **66% + visual trades:** heavy 29.01 ms / 34.5 FPS, p90 45.42, logic 25.40, client 3.26, draw
  2.29, path 9,770, calibration 7,522. Single best-case run; the 2.3% faster calibration means the
  matched gain over 36.80 is about 19%, not 21%.
- **Survival sweep:** 0% completes at 43.75 ms (slower, path 22,329); 33% resolves ~8,400; 50%
  ~15,600; 60% ~16,700 (200 short); 66% and 100% complete at 17,402. Lower is not monotonically
  better.
- **Baseline:** 36.80 ms / 27.2 FPS (logic 31.00, client 5.32, draw 4.49, path 14,680). Native
  D3D8/Intel matched pair: 46.87 ms (draw 12.55). `d3d8to9` v1.16.0 routes to the GTX 1650 Ti.
- **Tail:** the slowest 49 of 481 frames carry 22-23% of the time (logic 72.8 vs 26.3, `l_ai` 33.5
  vs 12.8, path 26,872 vs 13,297 us); worst frames are single 48.9-50.0 ms searches.
- **Path budget:** ~20 ordinary/closest/attack searches per frame at 500-700 us each, 0% exact
  repeats within 20 frames. The group kernel is only 0.51 ms/frame (3.4%), so caching/prefetching
  group searches cannot close the gap.
- **Live 33%:** 237-775 visible objects (~2x replay load), 38.07 ms mean, 55.01 p90, calibration
  7,542; the user judged it smoother than the replay variants.

## Measured negatives (do not repeat)

Group cache TTL >20, expansion caps, the 10k search cap (retry storm), prefetch-only workers, the
admissible heuristic, HUD string caching, triple buffering, full render-thread overlap, the
shadow-map renderer, and the closest-search swap (only 0.34 ms/frame). Cache/prefetch/completion-wait
were all sized and rejected; the remaining work is integration/playback, not another local lever.

## Builds and copies

- Staged playtest **`9660EB14...`** (`tools/play-t120.ps1`, `-AllyCost 100|66|33|0`, `-Performance`
  enables the three visual trades) in `game/last-stand-replay` with `d3d8to9` v1.16.0
  (`122928CF...`). `-Restore` puts the retail exe back.
- Previous playtests `52F56C99...`, `1EE75D56...`, `2BC7180B...`; memo candidate
  `build/engines/t120-memo-default.exe` (`C9147884...`).
- Active tree: `build/last-stand-profile-release` (source `build/last-stand-profile-source`).
  Env-gated diagnostics default off except the memo; `ZH_RENDER_THREAD`, `ZH_RENDER_SNAPSHOT`,
  `ZH_SKIP_*`, `ZH_UI_TEXT_CACHE`, `ZH_AB_INTERLEAVE` are opt-in.
- Cumulative patch `engine/patches/current-engine.patch` is **670,882 bytes** (`639DAAB9...`),
  `git apply --check` clean on `HEAD`.

## Test-environment state

- `d3d8to9` is installed in `game/last-stand-replay` (`d3d8.dll`, `122928CF...`). Remove with
  `tools/apply-d3d8to9.ps1 -Action Remove` for native-D3D8 comparisons.
- The test `GpuPreference` value is removed from `HKCU\...\UserGpuPreferences`.

## Next steps

1. Integration/validation: T-116 group-start failures, T-117 deploy guard/hold, T-128 live stuck
   groups. T-128 stays parked until a live `artifacts/live-formation-commands.csv` capture exists.
2. Decide the packaging story for the opt-in profile: 33% is the playtest default by feel, 66% is
   the benchmark value, and the published alpha predates both. Do not present the 66% result as
   behaviour-preserving.
3. Keep the public snapshot current after material doc changes; re-run `python tools/check_docs.py`
   and `python tools/check-workspace-size.py`.
4. T-025: re-confirm profiles on the checksum-checked diagnostic replay window.

## Constraints

Do not modify immutable game references. Do not commit game binaries, archives or extracted
assets. Every launch is announced. Update docs/state/log/BOARD and run `python tools/check_docs.py`
before ending work. Reuse builds/copies/artifacts
([ADR-0025](../docs/decisions/ADR-0025-no-fixed-workspace-cap.md)).
