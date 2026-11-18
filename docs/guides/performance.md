# Guide: measuring and improving entity-heavy performance

> **Status:** method verified; baseline, profiles, and runner measured; date: 2026-11-15
> **Issues:** [`ISSUE-0006`](../issues/ISSUE-0006-entity-performance.md),
> [`ISSUE-0007`](../issues/ISSUE-0007-hybrid-gpu-default.md)
> **Triage:** [`../research/2026-11-14-system-and-engine-triage.md`](../research/2026-11-14-system-and-engine-triage.md)

## 1. Make the GPU explicit

The laptop has Intel UHD + GTX 1650 Ti. A high-performance preference was applied for the
real install on 2026-11-14 (see ISSUE-0007). Confirm at runtime with Task Manager â†’ Performance
â†’ GPU 1 engine, or the NVIDIA overlay, while the game is running.

Also set in the NVIDIA Control Panel (if needed): *Manage 3D settings â†’ Program Settings â†’
Command & Conquer Generals Zero Hour â†’ High-performance NVIDIA processor*, and
*Power management mode â†’ Prefer maximum performance*.

## 2. Fix the scenario before changing settings

Every measurement must use the same:

| Item | Value |
|---|---|
| Build | `game/engine-test/Generals.exe` (T-015 harness; SHA-256 `5CF4EA07...60F0`) |
| Launch | `-win -quickstart -xres 1920 -yres 1080` |
| Resolution | 1920x1080 |
| Map | `maps\northamerica\northamerica.map` |
| Units | `ZH_STRESS=1000` (`AmericaTankCrusader`) |
| Duration | 40 s per run; steady state excludes the first 300 frames |
| Repetitions | 3 runs; report median, p95, and p99 |
| Runner | `tools\benchmark-entity-heavy.ps1 -Runs 3` |
A saved replay is the most reproducible option because unit counts and camera are fixed.
Replays live in `%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data\Replays`.

## 3. Capture frame data

Options, in order of preference:

1. **PresentMon** (ETW-based, no injection): record frame times for `generals.exe`, export CSV.
2. **GenTool FPS display**: quick sanity check, not sufficient for percentiles.
3. **Source build + Tracy**: best for CPU hot spots (`win32-profile` preset).
4. **Windows Performance Recorder / ETW**: CPU sampling if PresentMon is unavailable.

Report: average FPS, 1% low, 0.1% low, frame-time p95, and the moment the unit count crosses
thresholds.

## 4. A/B settings tests (one change at a time)

| Test | Change | Hypothesis |
|---|---|---|
| A | `AntiAliasing = 14` â†’ `0` | 14 is an unusual/high value; may cost GPU time |
| B | `MaxParticleCount = 5000` â†’ `2000` | effects are a known late-game cost |
| C | `UseShadowVolumes`/`UseShadowDecals` â†’ `no` | shadow rendering scales with entities |
| D | `StaticGameLOD` High -> Low | shadow/lightmap/particle cost; measured 35.05 -> 33.36 ms median, draw 27.26 -> 18.45 ms (EXP-003) |
| E | GPU preference off/on | confirms ISSUE-0007 |

Do not change multiple values in one run. Restore the original `options.ini` between tests
(back it up first).

## 5. Engine work (source build)

The source build exists (`game/engine-test`):

1. Run the same replay/scenario on the source build and compare with the retail build.
2. Use the `win32-profile` preset + Tracy to rank CPU costs (simulation vs rendering).
3. Only then choose an optimization target. Candidate areas from upstream: render/logic
   decoupling, draw submission, particle updates, pathfinding.
4. Port a candidate module to Rust only if it is isolated and measurably faster (ADR-0005).

## 6. Reporting

Every result goes in `docs/experiments/EXP-###-slug.md` with the method table, raw CSV in
`artifacts/<date>-<slug>/`, and a summary here. No claim without the numbers.

## Known engine constraint

The game is capped at 30 FPS and its logic is tied to frame rate in single-player. Raising
the cap (GenTool/upstream) without decoupling changes game speed; the upstream source has a
merged decoupling change. `[SOURCED]` Do not treat "60 FPS" as free.

## Measured profiles

The portable profile tool controls anti-aliasing and the game detail preset:

```powershell
tools\apply-options-profile.ps1 -Profile performance   # AA 0 + Low: 59.41 -> 33.36 ms
tools\apply-options-profile.ps1 -Profile balanced      # AA 2 + Medium (not measured yet)
tools\apply-options-profile.ps1 -Profile default       # AA 8 + High
tools\apply-options-profile.ps1 -AntiAliasing 4 -KeepStaticLOD
```

Backups are written under `artifacts/options-backups/`; restore with `-Restore <path>`.

- `AntiAliasing = 14` is clamped to 8x MSAA; AA 0 removed ~21 ms (EXP-001).
- Low detail disables shadow/lightmap/heat passes and lowers particles; draw **27.26 -> 18.45 ms**
  with all 1,000 units visible (EXP-003). This is the visibility-preserving profile.
- Total against the original settings: **59.41 -> 33.36 ms (1.78x)**, 16.8 -> 30.0 FPS.

Reproduce with:

```powershell
tools\benchmark-entity-heavy.ps1 -Runs 3 -ApplyProfile performance
```

## Opt-in draw-distance cull

`ZH_DRAWDIST` / `tools\launch-game.ps1 -DrawDistance <units>` culls render objects beyond a
world-space distance. At 400 units it reduced draw submission 27.3 -> 18.1 ms, but it hides
distant units. Default is off; use the Low detail profile instead unless you need more
headroom. See EXP-002.

## Headroom and shadow cost (measured)

The 30 FPS cap hides real headroom. Clean uncapped matrix (`-NoFPSLimit`, harness build; sets
`ZH_FPS=1000`, all other apps closed):

| Profile | Median | Draw | Logic | FPS |
|---|---:|---:|---:|---:|
| AA 0 + Low | 17.47 ms | 12.78 | 4.1 | 57.2 |
| AA 0 + High | 25.02 ms | 19.96 | 4.14 | 40.0 |
| AA 0 + High, shadows off | 17.63 ms | 12.65 | 4.05 | 56.7 |
| AA 0 + High, `-ShadowSize 120` | 20.30 ms | 15.20 | 4.2 | 49.3 |
| d3d8to9, Low | 16.47 ms | 11.69 | 4.03 | 60.7 |
| d3d8to9, High + 120 px | 18.60 ms | 13.50 | 4.1 | 53.8 |

Shadow volumes are the High-vs-Low gap; lightmaps/particles/trees are not dominant. A
distance-limited shadow cull keeps all units visible and recovers most of the cost:

```powershell
tools\apply-options-profile.ps1 -AntiAliasing 0 -StaticLOD High
tools\launch-game.ps1 -ShadowDistance 400
```

`-NoFPSLimit` is for profiling only; the normal game stays at its 30 FPS logic-coupled cap.
See EXP-004.

### Screen-size shadow LOD (measured)

`-ShadowSize <px>` skips shadow volumes whose projected radius is below the threshold; units
stay visible and large/near shadows remain. At 1,000 units, High detail + 120 px:

```powershell
tools\apply-options-profile.ps1 -AntiAliasing 0 -StaticLOD High
tools\launch-game.ps1 -ShadowSize 120
```

Clean uncapped median **20.30 ms**, draw **15.20 ms** (vs 25.02 / 19.96 without shadow LOD),
**49.3 FPS**. Low detail remains the maximum-headroom profile (17.47 ms / 57.2 FPS). See EXP-005.

### Optional d3d8to9 wrapper

Clean A/B: `d3d8to9` v1.16.0 gives Low detail **17.47 → 16.47 ms** (5.7%) and High + 120 px
**20.30 → 18.60 ms** (8.4%), with no crash in six runs. It is still a third-party DLL and
conflicts with GenTool's proxy. Native D3D8 is the default; see EXP-006 before using it.
Install/remove it in a copy with:

```powershell
tools\apply-d3d8to9.ps1 -Action Install -GameDir game\engine-test
tools\apply-d3d8to9.ps1 -Action Remove  -GameDir game\engine-test
```

### Projected/decal shadow path (rejected)

The engine's existing `SHADOW_PROJECTION` path stalled at ~987 ms draw while creating
render-to-texture shadows; `SHADOW_DECAL` was fast but produced no clear unit shadow at this
scale. Both were reverted. A real shadow-map path needs depth targets and shader work (T-035);
use the 120 px LOD instead. See EXP-007.

## External cross-checks

- Upstream already merged particle batching (#3155) and render/logic FPS decoupling
  (#1451/#1528/#2699); our vendor contains both, so 30 FPS is configuration, not an engine
  ceiling.
- Upstream's drawable partition PR (#2044) is still open and has null-pointer caveats; it
  cannot show a gain in an all-visible scene.
- OpenSAGE (same SAGE lineage) replaced shadow volumes with shadow maps for modern hardware,
  matching our shadow-bound result.
- `d3d8to9`/`dxwrapper` may help driver overhead/Alt+Tab but has crash/VSync reports; it is an
  optional, reversible wrapper test (T-033) requiring a download.

Sources and caveats: [`../research/2026-11-15-external-performance-research.md`](../research/2026-11-15-external-performance-research.md).

