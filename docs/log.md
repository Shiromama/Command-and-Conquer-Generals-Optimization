# Work log

> **Append-only.** Newest entry at the bottom. Each entry: date, task ID(s), what changed,
> evidence. Never rewrite an entry; add a correction entry instead.
> The latest date here must equal `updated_at` in [`state.json`](state.json).

## 2026-11-14 â€” P0: agent-readable documentation base

**Tasks:** T-001, T-002, T-003, T-004

**Context.** The workspace contained only a patched Zero Hour installation (1.29 GB) with no
project files, no git repository, and no documentation. Goal: make the project readable and
interpretable by any agent, across sessions, before technical work begins.

**Created**

- `AGENTS.md` â€” entry point: repository map, hard rules, evidence labels, update protocol.
- `README.md`, `.gitignore` (game install + artifacts excluded).
- `docs/INDEX.md` â€” document catalog, conventions, update triggers.
- `docs/project-brief.md` â€” goal, scope, constraints, proposed success criteria.
- `docs/environment.md` â€” verified OS/toolchain/hashes/config snapshot.
- `docs/game-inventory.md` â€” archive/binary/data inventory and launcher notes.
- `docs/architecture.md` â€” current component model + four Rust attachment hypotheses.
- `docs/roadmap.md` â€” P0â€“P4 phases, exit criteria, risk register.
- `docs/tasks/BOARD.md` â€” task ledger `T-001`â€¦`T-010`.
- `docs/decisions/` â€” ADR-0001â€¦ADR-0004 + template.
- `docs/research/TEMPLATE.md`, `docs/experiments/TEMPLATE.md`.
- `docs/glossary.md`, `docs/state.json`, `docs/log.md`.
- `docs/research/` placeholder conventions; `artifacts/README.md`.
- `.opencode/continuity.md` â€” cross-session checkpoint.
- `tools/check_docs.py` â€” validator (links, state schema, log freshness, task/ADR integrity)
  with `--self-test`.

**Key verified facts**

- `game.dat` and `Generals.exe` are byte-identical, SHA-256
  `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B`, 6,883,376 bytes.
- `d3d8.dll` is GenTool 1.0.0.0; `d3d8.cfg` contains `[gentool76]`.
- 22 `BIGF` archives; `Data/INI` is empty (rules are in `INIZH.big`).
- Host: Windows 11 26200 AMD64; rustc/cargo 1.82.0; Python 3.10.0.

**Decisions recorded:** ADR-0001 (repo as agent interface), ADR-0002 (install read-only),
ADR-0003 (local git, binaries excluded), ADR-0004 (defer BIG tooling per user direction).

**Evidence / verification**

- All file facts from PowerShell `Get-ChildItem`, `Get-FileHash`, PE `VersionInfo`, and direct
  file reads on 2026-11-14; sizes/hashes recorded in `docs/environment.md` Â§3.
- `python tools/check_docs.py` â†’

  ```
  Checked 18 markdown files, 99 relative links, 10 tasks, 4 ADRs.
  OK: documentation system is consistent
  ```

- `python tools/check_docs.py --self-test` â†’

  ```
  PASS: clean fixture validates
  PASS: broken link detected
  PASS: stale state date detected
  PASS: dangling next_action detected
  SELF-TEST OK: validator detects injected breakage
  ```

- Repository initialized as a local git repo and committed; `git ls-files` contains docs/tools
  only, never the game installation (see next entry for the commit evidence).

## 2026-11-14 â€” P0 verification and first commit

**Tasks:** T-001, T-002, T-003, T-004

- Commit `ed545a2` â€” `T-001 T-002 T-003 T-004: P0 agent-readable documentation base`.
- `python tools/check_docs.py` â†’ `Checked 18 markdown files, 99 relative links, 10 tasks,
  4 ADRs.` / `OK: documentation system is consistent` (exit 0).
- `python tools/check_docs.py --self-test` â†’ 4 Ã— `PASS`, exit 0.
- `git ls-files` â†’ 24 tracked files, **0** under `Command and Conquer Generals Zero Hour/`.
- Cold-start comprehension test by an independent agent (read-only) confirms the entry point
  answers phase, next actions, constraints, and document locations without chat history.

## 2026-11-14 â€” Cold-start review fixes

**Tasks:** T-001, T-004

An independent read-only agent was given only the repository (no chat history) and asked to
summarize goal/phase, next actions, environment facts, constraints, record locations,
verification, evidence labels, and open questions.

Result: all eight questions were answered from the docs; no broken links. Defects found and
fixed:

- Circular dependency T-005 â†” T-006 on the board â†’ T-005 is the first P1 step and unblocks T-006.
- `state.next_actions` omitted T-008 and listed T-009 while T-009 was dependency-blocked â†’
  T-008 added, T-009 left on the board with "after T-006 and T-008".
- `docs/INDEX.md` Â§3.5 overstated the placeholder check â†’ now matches the validator
  (`{{`, `TODO:`, `FIXME`; `TEMPLATE.md` skipped). The validator also now ignores inline
  code spans so documents can describe those markers without failing.
- Archive count was imprecise â†’ 21 root archives + a 24-byte `BIGF` stub at
  `launcher/MapsZH.big`; inventory, architecture, and glossary corrected.
- No guidance for runtime writes on first launch â†’ risk documented in `game-inventory.md` Â§4
  and added to T-005 scope (prefer launching a copy, record before/after hashes).

False positive: the reviewer reported "no `.git` directory". `Test-Path .git` â†’ `True`,
`git log` shows both commits, and `git ls-files` reports 24 tracked files; the reviewer's
sandbox did not expose repository metadata. No change made.

Verification: `python tools/check_docs.py` â†’ `OK` (exit 0); `--self-test` â†’ all PASS. Fixes
committed in the following commit.

## 2026-11-14 â€” Issue/bug register added

**Tasks:** T-011

Added a dedicated place for problems, as distinct from tasks, decisions, and experiments:

- `docs/issues/README.md` â€” purpose, when to file, severity levels, status lifecycle,
  blocking-issue rules, index of current issues.
- `docs/issues/TEMPLATE.md` â€” required fields: symptom, reproduction/evidence, impact, root
  cause, workaround, resolution/verification.
- Seeded real entries: ISSUE-0001 (reference install may be mutated by a normal launch),
  ISSUE-0002 (GenTool owns the `d3d8.dll` slot), ISSUE-0003 (INI rules unreadable until
  `INIZH.big` is parsed), ISSUE-0004 (validator false positive on documented markers â€” fixed
  with the inline-code fix and kept as a worked example).
- `AGENTS.md` now requires filing an issue on any failure/contradiction/blocker, marking the
  task `Blocked` and updating `state.blockers` when it stops progress, and closing only with
  verification. `docs/INDEX.md`, the board (`T-011`), and the continuity checkpoint updated.
- `tools/check_docs.py` now validates issue IDs, filenames, title/ID match, status, severity,
  date, task link, resolution section, index listing, and uniqueness; self-test injects a
  duplicate issue ID.

Verification: `python tools/check_docs.py` â†’ `OK`; `--self-test` â†’ all PASS.

## 2026-11-14 â€” P1: pristine baseline, work copy, fullscreen fix

**Tasks:** T-005, T-012, T-018, T-019

**Isolation workflow**

- Added `tools/prepare-game-copies.ps1` (parameterized: source dir, label, profile).
- Created `game/baseline-pristine/`: complete copy of the real installation, 1,914 files,
  2,047,921,400 bytes (1.91 GiB), all files read-only.
- Created `game/work/`: mutable copy; only `d3d8.cfg` differs.
- Baseline manifest: `docs/manifests/game-baseline-v104-gentool76-2026-11-14.sha256`.
- Verification: `OK: baseline matches manifest (1914 files)`.
- Source install remained untouched: `d3d8.cfg` hash
  `FE01E44C6A701E42AC8F89495A8D6B52F7243847D10EDB6559FA8FD1AB390357` before and after;
  0 files modified today.

**Portable fixes**

- `game/profiles/fullscreen/d3d8.cfg`: `window=3` + GenTool updater downloads disabled.
- `game/profiles/windowed/d3d8.cfg`: `window=2` for A/B.
- `tools/launch-game.ps1`: parameterized launch (`-Mode borderless|windowed|exclusive`,
  `-Width`, `-Height`, `-QuickStart`, `-DryRun`); no registry, no hardcoded user path.
- Work-copy launch test: window `-3,-26` `1926x1109`, **client `1920x1080`**, style
  `0x94C80000`. Documents `options.ini`, `Skirmish.ini`, `ReleaseCrashInfo.txt` unchanged.
- No GPU registry preference remains (the earlier machine-specific attempt was reverted).

**Source build**

- `vendor/GeneralsGameCode` @ `0ff1220` is present (57 MB, GPLv3, no build yet).
- CMake would fetch pinned dependencies: `min-dx8-sdk`, `GameMath`, `lzhl`, `stb`, `GameSpy`;
  Tracy only for the profile preset.
- Build is blocked pending user approval to download those dependencies. Recorded in
  `state.blockers` and BOARD T-014.

**Documentation**

- Added `docs/game-copies.md`, `docs/research/2026-11-14-engine-digestion.md`,
  ADR-0006, `game/README.md`, and `game/profiles/README.md`.
- Updated issue statuses: ISSUE-0001 workaround, ISSUE-0005 fixed on work copy, ISSUE-0007
  open (registry attempt reverted), issue index, ADR index, board, roadmap, brief,
  environment, architecture, glossary, and continuity.


## 2026-11-14 â€” P1: source build, DPI/fullscreen, frame timing

**Tasks:** T-014, T-015, T-017, T-023

**Build**

- First configure selected BuildTools MSVC 14.42 and failed: `PreRTS.h(47): C1083 atlbase.h`.
- ATL was already installed in Community 14.43; reconfigured with
  `-DCMAKE_GENERATOR_INSTANCE=...Community -T v143`.
- `z_generals` built successfully: `build/engine-vs-community/GeneralsMD/Release/generalszh.exe`,
  `BUILD_EXIT=0`.
- Baseline source exe `F8CAC4C0â€¦0998`; current DPI+logger exe `4D6589F6â€¦091B`.

**DPI / fullscreen**

- Added per-monitor DPI awareness at `WinMain` (patch `engine/patches/T-023-dpi-awareness.patch`).
- DPI-aware query: process awareness 2; borderless client **1920Ã—1080**; exclusive client
  **1920Ã—1080**; previously 1536Ã—864 at 125% scaling.
- Exclusive fullscreen survived two Alt+Tab cycles.
- GenTool proxy crashes the rebuilt exe (`0xC0000005`); system D3D8 works. Staging now disables
  GenTool by default (ISSUE-0008).

**Frame timing**

- Added env-gated CSV logger (patch `engine/patches/T-015-frame-logger.patch`).
- `00000000.rep` 180 s: 5,280 frames, median **33.35 ms**, p95 **34.31 ms**, pinned at 30 FPS.
- `1v8 niggas.rep` (map `Last Stand` present) hangs black; debug maps do not create a heavy
  scene. Entity-heavy baseline is blocked (ISSUE-0009, T-015).

**Added**

- `engine/README.md`, `engine/patches/` (DPI + frame logger)
- `tools/build-engine.ps1`, `tools/stage-engine.ps1` updated (GenTool off by default)
- `docs/research/2026-11-14-engine-build-results.md`, ISSUE-0008, ISSUE-0009
- state/board/roadmap/continuity updated


## 2026-11-14 â€” Clean rebuild and stress-harness attempt

- Rebuilt after reverting the test-only stress hook; current DPI+logger exe is
  `595161836AC847F5A01DB3A3701E3EDF23E0F9A1411BF2EC2022B2395EC25A4B`.
- Staged clean exe in `game/engine-test/`; GenTool disabled; 15-s smoke test alive and frame
  log produced.
- Stress-spawn experiment (`ZH_STRESS`) was unreliable: no default team in the debug map,
  teamless object creation crashed, and UI automation/map load was not repeatable. Reverted;
  no unverified stress patch is shipped.
- Entity-heavy benchmark remains blocked (ISSUE-0009); frame logger and DPI patch are verified.


## 2026-11-14 â€” Scenario attempts and clean rebuild

- Tried `ZH_MAP` automatic map start and deferred `ZH_STRESS` spawning. The hook found a valid
  team (`team=1D14E5D0`) and template `AmericaTankCrusader`, but `startNewGame` from the menu
  returned to the menu; spawns only affected the menu world. Reverted.
- Rebuilt clean DPI+logger engine:
  `0071F21BAF68F3F8189628C2CB209884EA5A96EEA51BB3DA99612D1F363EBC11`.
- Staged clean exe in `game/engine-test/`; GenTool disabled.
- Entity-heavy benchmark remains blocked (ISSUE-0009); no unverified stress patch shipped.


## 2026-11-14 â€” Final scenario retry and clean engine

- Retried deferred stress spawn through the Debug Load Map UI; the map list stayed open and no
  playable match was reached. Hook reverted.
- Rebuilt clean DPI+logger engine:
  `92835AF8C62360EC05E03B603EF9ABE3235A854CD954E26BCB4567C9ACD56D7E`.
- Staged clean exe in `game/engine-test/`; GenTool disabled; no `stress.log`.
- Entity-heavy baseline remains blocked on a valid scenario (ISSUE-0009).


## 2026-11-15 â€” Entity-heavy benchmark and first measured optimization

**Tasks:** T-015, T-017, T-024

**Scenario solved.** The test-only harness (`ZH_MAP` + deferred `ZH_STRESS`) now starts
`maps\northamerica\northamerica.map` without menus and spawns 1,000 visible tanks after the map
creates a valid team. Harness exported as `engine/patches/T-015-benchmark-harness.patch`
(test-only; do not ship in a normal build).

**Baseline (3 runs, 1,000 units, 1920Ã—1080, AA 14 â†’ 8Ã— MSAA):**

```
median: 59.41 / 62.62 / 58.57 ms
p95:    67.02 / 69.19 / 66.33 ms
```

Split timing: `client` median 51.87 ms, `draw` median 50.32 ms, `logic` median 4.49 ms.

**Root cause found.** `OptionPreferences::getAntiAliasing()` clamps `AntiAliasing = 14` to
**8Ã— MSAA** (`OptionPreferences.cpp:70-80`, `ww3d.cpp:2031-2049`). Reducing AA:

| AA | Effective | Median |
|---:|---|---:|
| 14 | 8Ã— | 59.41â€“62.62 ms |
| 4 | 4Ã— | 48.39 ms |
| 2 | 2Ã— | 45.01 ms |
| 0 | off | 34.76â€“36.50 ms |

**Optimized (3 runs, AA 0):**

```
median: 34.76 / 35.05 / 36.50 ms
p95:    39.45 / 40.20 / 41.95 ms
```

Median-of-medians **59.41 â†’ 35.05 ms (1.70Ã—)**; effective FPS **16.8 â†’ 28.5**. Draw time
**50.32 â†’ 27.26 ms**. Original Options.ini backed up at
`artifacts/options-backups/options-2026-11-15-005413.ini`.

**Changes:**

- `tools/apply-options-profile.ps1` â€” portable `performance` (AA 0), `balanced` (AA 2),
  `default` (AA 8), with backup/restore; no game files touched.
- `engine/patches/T-015-benchmark-harness.patch` â€” `ZH_MAP`, deferred `ZH_STRESS`,
  `ZH_PERF_SPLIT` (client/draw/logic).
- `docs/experiments/EXP-001-msaa-entity-heavy.md` â€” full method/results.
- ISSUE-0006 â†’ Workaround; ISSUE-0009 â†’ Fixed; board/state/continuity updated.


## 2026-11-15 â€” Source-level distance cull

**Tasks:** T-026

- Added `ZH_DRAWDIST` to `RTS3DScene::Visibility_Check`: render objects beyond the world-space
  distance are marked invisible; `0`/unset preserves retail behavior. Exported as
  `engine/patches/T-021-scene-distance-cull.patch`.
- Launcher exposes `-DrawDistance <units>` (opt-in; default off).
- Three 1,000-unit runs at distance 400 (AA 0):

```
median: 33.34 / 33.26 / 33.30 ms
p95:    36.51 / 36.68 / 36.65 ms
draw:   18.06 / 17.75 / 18.15 ms
```

Compared with AA-0 baseline: median 35.05 -> 33.30 ms (30 FPS cap), p95 40.20 -> 36.65 ms,
draw 27.26 -> 18.1 ms. Units beyond 400 world units are hidden, so this remains opt-in.
- Threshold sweep: 200 -> draw 13.38; 600 -> 24.07; 800/1200 -> no effective cull.
- Recorded as `docs/experiments/EXP-002-scene-distance-cull.md`; issue/task/state/continuity
  updated.


## 2026-11-15 â€” Visibility-preserving LOD attempt

- Implemented distance LOD via `HLodClass::Set_LOD_Level` (`ZH_LOD`, near/far thresholds).
- Measured at 1,000 units, AA 0: draw median **28.8 ms** vs **27.3 ms** baseline; frame median
  **36.71 ms** vs **35.05 ms**. No gain; reverted.
- The remaining draw cost is draw-call submission, not model detail. Batching/spatial index
  remains open (T-021/T-027).
- Rebuilt cull-only engine and staged it:
  `5CF4EA0717FE38A11A1CB1007C6DA930D3BC75EA468CFC59E601CFFBAB1160F0`.
- Opt-in cull remains the only measured source-level draw gain (draw 27.3 â†’ 18.1 ms at 400).


## 2026-11-15 â€” Visibility-preserving Low-detail profile and portable runner

**Tasks:** T-028, T-029, T-025

**Low detail profile.** Added `StaticGameLOD` / `IdealStaticGameLOD` support to
`tools/apply-options-profile.ps1`. The `performance` profile is now AA 0 + Low detail;
`balanced` is AA 2 + Medium (unmeasured), `default` is AA 8 + High. Low detail disables
shadow/lightmap/heat passes and lowers particles but keeps every unit visible.

Three undisturbed 1,000-unit runs (AA 0 + Low, 1920x1080, 40 s, steady after 300 frames):

```
median: 33.31 / 33.36 / 33.39 ms
p95:    36.67 / 36.94 / 36.85 ms
draw:   18.09 / 19.14 / 18.45 ms
logic:  5.71 / 5.89 / 5.74 ms
```

Against AA 0 / High (35.05 / 40.20 / 27.26 ms): median **4.8% lower**, p95 **8.3% lower**,
draw **32.3% lower**. Against the original AA 14 / High settings: **59.41 -> 33.36 ms
(1.78x)**, 16.8 -> 30.0 FPS. This matches the opt-in distance cull without hiding units.
Screenshot `artifacts/2026-11-15-static-lod/static-low-clean.png` shows 1,000 Crusaders at
30 FPS. Recorded as EXP-003.

**Runner.** Added `tools/benchmark-entity-heavy.ps1` (runs, map, units, duration, warmup,
artifact dir, optional profile/cull). Final smoke test after the index fix: 33.37 ms median,
17.50 ms draw. Fixed a PowerShell median-index bug (integer cast of Count/2 rounded 1.5 to 2;
now floors).

**Replay validation.** Found `-loadreplay` (visual playback) versus `-replay` (headless
simulation). `1v8 niggas.rep` is rejected as invalid; the logged frames were the menu shell
map. `00000000.rep` loads only with `-ignoreReplaySyncErrors` and is early-game (30 FPS cap).
Real late-game validation is blocked on a compatible replay: ISSUE-0010; T-025 Blocked.

**Verification.** `python tools/check_docs.py` OK; baseline manifest verified; source install
0 files modified; engine-test hash `5CF4EA07...60F0`.


## 2026-11-15 â€” Architecture headroom and shadow-volume cost

**Tasks:** T-030, T-031

**Uncapped measurement.** `-noFPSLimit` is overwritten when the detail preset applies, so the
harness now passes `MSG_NEW_GAME`'s FPS argument (`ZH_FPS=1000`). Test-only `ZH_NOSHADOW` and
`ZH_SHADOWDIST` hooks were added for cost attribution.

| Configuration | Median | Draw | Logic | FPS |
|---|---:|---:|---:|---:|
| AA 0 + Low, capped | 33.36 | 18.45 | 5.74 | 30.0 |
| AA 0 + Low, uncapped | 26.56 | 19.33 | 5.82 | 37.7 |
| AA 0 + High, uncapped | 37.23 | 29.86 | 5.73 | 26.9 |
| AA 0 + High, shadows off, uncapped | 26.09 | 19.08 | 5.35 | 38.3 |
| AA 0 + High, shadow distance 400, uncapped | 30.23 | 23.75 | 5.30 | 33.1 |
| AA 0 + High, shadow distance 600, uncapped | 32.96 | 26.30 | 5.44 | 30.3 |

**Findings.** The 30 FPS cap hides ~7 ms at Low. High detail is genuinely renderer-bound, and
the High-vs-Low gap is ~10 ms at both 1080p and 720p, so it is not pixel fill. Shadows off
recovers the entire gap; lightmaps/particles/trees are not dominant. `DX8MeshRenderer` already
groups by FVF/texture, and logic stays 5.3-5.8 ms, so batching and a spatial index are lower
priority than shadow work. A 400-unit shadow distance keeps all units visible and recovers
~7 ms (33.1 FPS uncapped).

**Changes.** Launcher gains `-ShadowDistance` and test-only `-NoFPSLimit`; patch
`engine/patches/T-030-shadow-culling.patch`; experiment
`docs/experiments/EXP-004-architecture-headroom.md`; artifacts
`artifacts/2026-11-15-architecture-research/`.

**Verification.** `python tools/check_docs.py` OK; baseline manifest verified; source install
0 files modified; engine-test hash `C6353171...187E`.


## 2026-11-15 â€” External SAGE/RTS performance cross-check

**Tasks:** T-020, T-021, T-032, T-033

Researched upstream GeneralsGameCode, OpenSAGE, openage, and D3D8 wrapper reports. Sources and
caveats are in `docs/research/2026-11-15-external-performance-research.md`.

- **Particle batching is already merged upstream** (PR #3155, 2026-09-06); our vendor contains
  `W3DParticleSys` batching. T-020 is therefore Done (upstream), not new work. Our tank scene
  has no particle load, so it could not show the upstream 15-30% gain.
- **Render/logic FPS decoupling is merged** (#1451/#1528/#2699); `FramePacer` and
  `UncappedFpsValue` are in our source. The 30 FPS cap is configuration; our uncapped Low run
  (37.7 FPS) confirms it.
- **Drawable partition is still open** (issue #1502, PR #2044) and has null-pointer caveats.
  Our 1,000-unit scene keeps everything visible, so partitioning cannot show its benefit; T-021
  stays Backlog pending an off-screen-heavy map.
- **AsciiString contention** (PR #2663) claimed 14 -> 87 FPS on one map but was closed
  unmerged; our logic is 5.8 ms, so it is not our bottleneck.
- **OpenSAGE** replaced SAGE shadow volumes with shadow maps and parallelized frustum culling
  (5-10% on quad-core), consistent with our shadow-bound High-detail result.
- **D3D8 -> D3D9 wrappers** (`d3d8to9`, `dxwrapper`, DXVK) are a community lead for driver
  overhead/Alt+Tab, but reports include crashes/VSync issues. Added T-033 as an optional,
  reversible test that needs download approval.

**Verification.** `python tools/check_docs.py` OK; baseline manifest verified; source install
0 files modified; engine-test hash `C6353171...187E`.



## 2026-11-15 â€” Screen-size shadow LOD and optional d3d8to9 A/B

**Tasks:** T-032, T-033

**Screen-size shadow LOD (T-032).** Added `ZH_SHADOWSIZE` / `tools\launch-game.ps1 -ShadowSize`.
The first version projected three points per caster and cost ~3.5 ms; replaced with a cheap
bounding-radius/distance estimate (`radius * viewHeight * 1.866 / distance`). Three undisturbed
High-detail uncapped runs at 120 px:

```
median: 30.19 / 29.22 / 29.79 ms
draw:   23.00 / 22.33 / 22.85 ms
p95:    34.95 / 35.71 / 35.77 ms
```

vs High no cull 37.94 ms / draw 30.98. 120 px matches the 400-unit world cull while keeping
near/large shadows; 160 px reaches 27.34 ms but removes most shadows. Recorded in EXP-005.

**d3d8to9 wrapper (T-033).** Downloaded `d3d8to9` v1.16.0 (`d3d8.dll`, SHA-256
`122928CFâ€¦F8AB8`) into `game/engine-test` only, ran a 3+3 Low-detail A/B:

```
native:  26.58 / 25.93 / 26.45 ms; draw 19.24 / 19.19 / 19.44
wrapper: 25.37 / 24.89 / 25.00 ms; draw 17.99 / 17.87 / 18.47
```

Median **26.45 -> 25.00 ms (5.5%)**, draw **19.24 -> 17.99 ms (6.5%)**, no crash. High-detail
wrapper runs were contaminated by BlueStacks running in the foreground, so they are indicative
only. The wrapper was removed; native system D3D8 remains the default. Recorded in EXP-006.

**Changes.** Patch `T-030-shadow-culling.patch` now contains distance + screen-size culls;
launcher gains `-ShadowSize`; docs EXP-005/EXP-006 and manifests; engine hash
`EB4EC006â€¦C3FBF`. Board: T-032/T-033 Done, T-034 shadow-map prototype added.

**Verification.** `python tools/check_docs.py` OK; baseline manifest verified; source install
0 files modified; engine-test has no local `d3d8.dll`; options AA 0 + Low.


## 2026-11-15 â€” Clean-environment correction for architecture benchmarks

BlueStacks (`HD-Player`) was running an Android game in the background during the first
EXP-004/005/006 measurements. It inflated every absolute frame time. The relative conclusions
held, but all absolute numbers in those experiments were re-measured with all other apps closed:

| Configuration | Median | Draw | p95 | Uncapped FPS |
|---|---:|---:|---:|---:|
| Native Low | 17.47 | 12.78 | 23.06 | 57.2 |
| Native High, no cull | 25.02 | 19.96 | 29.14 | 40.0 |
| Native High, shadows off | 17.63 | 12.65 | 20.48 | 56.7 |
| Native High, 120 px shadow LOD | 20.30 | 15.20 | 23.57 | 49.3 |
| d3d8to9 Low | 16.47 | 11.69 | 19.08 | 60.7 |
| d3d8to9 High, 120 px | 18.60 | 13.50 | 21.56 | 53.8 |

Conclusions unchanged: the 30 FPS cap hides ~16 ms at Low, shadow volumes are the High-vs-Low
gap, 120 px shadow LOD recovers ~4.7 ms, and d3d8to9 adds ~5.7% at Low / ~8.4% at High+120 px.
EXP-004/005/006 now label the old numbers as contaminated; `artifacts/2026-11-15-d3d8to9/clean-matrix.json`
holds the clean summary.

**Verification.** Options restored to AA 0 + Low; `game/engine-test/d3d8.dll` removed; engine
`EB4EC006â€¦C3FBF`; baseline and source-install checks unchanged.


## 2026-11-15 â€” Projected/decal shadow prototype rejected

**Task:** T-034

Tested the engine's existing shadow paths through a test-only `ZH_SHADOWTYPE` override:

- `SHADOW_PROJECTION`: draw stalled at **~987 ms** while creating render-to-texture shadows
  (only 180 frames); rejected.
- `SHADOW_DECAL`: 20.37 ms median / draw 14.72, but no clearly visible unit shadow at this
  scale; no advantage over the 120 px LOD (20.30 / 15.20).
- Override reverted; `W3DModelDraw.cpp` back to baseline. Rebuilt engine
  `7C3CE0AD24D6E8439E7994C923C838DB1EFF92DCE9944F8546B7D1D2A29ABE21`.
- Post-revert confirmation at High + 120 px: **20.32 ms / draw 15.46 / 49.2 FPS**, matching
  EXP-005.

Keep the 120 px LOD. A real shadow-map path needs depth targets and shader work (T-035);
recorded in EXP-007. Options restored to AA 0 + Low; wrapper absent.

## 2026-11-15 - ShockWave: data-only mod, iGPU discovery, nuke cost, Alt+Tab crash

**Tasks:** T-036, T-037, T-038, T-039, T-040; ADR-0007, ADR-0008; ISSUE-0011; EXP-008.

**What ShockWave actually is.** Its `game.dat`/`Generals.exe` are byte-identical to retail
1.04 (`F37A4929...495B`). The launcher only renames `!*.gib` to `*.big` (map in
`Shockwave_Lnchr.dat`); `BIGFileSystem` loads `*.big` in ascending filename order and keeps
the first match, so the `!` archives override retail. The GPL engine therefore runs the mod
unchanged: verified by booting the shell map, menu, title and a full China Nuke General
skirmish from a materialised copy.

**New tooling.** `tools/big-archive.py` (BIG reader; mixed-endian size field per
`BIGFileSystem.cpp`), `tools/prepare-shockwave-copy.ps1` (copy + materialise, never touches the
install), `tools/pe-disasm.py`, `tools/minidump-triage.py`, `tools/capture-game-window.ps1`,
`tools/ui-click.ps1`, `tools/alt-tab-stress.ps1`, `tools/set-gpu-preference.ps1`,
`tools/adapter-probe.cpp`, `tools/analyze-perf-log.py`, `tools/analyze-split-log.py`.
Mod data: 1,642 `ParticleSystem` blocks vs 1,087 stock; 2,384 W3D entries; 968 textures.

**The big performance fact.** Both the retail and rebuilt game were rendering on the **Intel
UHD 630**. `adapter-probe` shows D3D8 enumerates one adapter on this laptop, and the Windows
per-app GPU preference is ignored by D3D8. d3d8to9 as `d3d8.dll` + Windows High-performance
preference loads `nvd3dum.dll` (GTX 1650 Ti). Same 400-tank + nuke scenario: **26.09 -> 19.66 ms
median (1.33x), p95 35.94 -> 21.47 ms, over-30-FPS frames 7.6% -> 0.1%**. Steady destruction
(400 tanks, lethal nukes, respawn) is **19.62 ms / p95 20.88** (draw 7.25, client 9.28, logic
4.13). Shadow LOD 120 px and particle cap 2500 are neutral there.

**Impact attribution (the reported stutter).** 1,000 tanks, 2 nukes/s, radius 400: visual-only
logic 6.4 ms; damage-without-death raises draw/client (+6 ms) through automatic smoke/fire but
not logic; mass deaths are a **logic storm** (p95 155 ms, peak 279 ms) and collapse the frame
to ~1 FPS. Named debris bypasses `isDebrisSkipped()` (only generic debris is LOD-skipped);
a debris budget is T-041.

**Alt+Tab crash (ISSUE-0011).** `ReleaseCrashInfo.txt` at 04:05 and 04:25 both: AV,
`EIP 0081A7A5`, `mov [ecx+0x20], eax` with `ECX=0` -> a null `TextureBaseClass*` during device
restore. The only byte-identical sequence in the exe maps to
`TextureBaseClass::Peek_D3D_Base_Texture()` via the linker map. 120-cycle tests: exclusive
fullscreen crashes with GenTool **and** with plain system D3D8 (same EIP); borderless + GenTool
survives with flat handles (666->664); retail + d3d8to9 survives (handles grow ~1/cycle);
rebuilt engine + d3d8to9 survives with flat handles (759->763). Workaround: borderless for the
online profile, d3d8to9 or the rebuilt engine for singleplayer.

**Verification.** Engine `E828613B...67DF` built with the new patches (T-036, T-039) and staged;
`game/shockwave-engine` runs the mod on the NVIDIA GPU; `ReleaseCrashInfo` timestamps and
stress CSVs are in `artifacts/2026-11-15-shockwave-analysis/` (manifest included);
`python tools/check_docs.py` -> OK (52 files, 239 links, 41 tasks, 8 ADRs, 11 issues);
`prepare-game-copies.ps1 -VerifyOnly` -> baseline matches manifest (1,914 files).

## 2026-11-15 - T-041 debris/hulk budgets; GenTool-compatible dGPU path

**Tasks:** T-041, T-042; ADR-0009; EXP-008 Â§7.

**Mass-wipe fix (T-041).** Added opt-in per-logic-frame budgets in
`GenericObjectCreationNugget::reallyCreate` (`ZH_DEBRIS_PER_FRAME`, `ZH_HULK_PER_FRAME`).
Only cosmetic debris (`!m_nameAreObjects`) and `Dead*Hulk` CreateObject templates are throttled;
gameplay spawns are never touched. First attempt patched the base-game `Generals/` copy instead
of the Zero Hour `GeneralsMD/` copy, so the budget was absent from the build; an object census
(`ZH_OBJLOG`) exposed it (5,771 debris, 421 hulks at frame 119). After patching the correct
file and rebuilding:

| 1,000-tank wipe, 2 nukes/s | no budget | 24/8 | 48/16 |
|---|---:|---:|---:|
| peak debris | 5,771 | 802 | 1,383 |
| peak hulks | 421 at frame 119 | 239 | 372 |
| logic p95 / max | 1,129 / 1,662 ms | 0.36 / 1.11 ms | 1.01 / 5.69 ms |
| frame p95 | 201 ms | 33.4 ms | 64 ms (battle window) |

48/16 is the performance-launcher default: it keeps a third of the original wreck field while
removing the logic storm. Normal battles never reach the budget per frame.

**Online dGPU path (T-042).** The earlier "GenTool + d3d8x exits" result was a configuration
error: GenTool's config had no `window=3` while the game was started with `-win`. Retested with
the borderless preset: GenTool 8.9 + d3d8to9 1.16.0 as `d3d8x.dll` loads `nvd3dum.dll` and
survives 120 focus cycles with flat handles (738->738), no new `ReleaseCrashInfo`. ADR-0009
records that the online profile can have the dGPU and the crash-safe mode together; SWR.net
acceptance of the chainloaded wrapper still needs a user online match.

**Verification.** Engine `5C2D5500...0BB7` built (T-041 included), staged; `I2D/I2E` CSVs and
`objects.log` in `artifacts/2026-11-15-shockwave-analysis/`; `python tools/check_docs.py` and
baseline verification recorded in the session summary.

## 2026-11-15 - Online scope decision: stock online, limiter singleplayer-only

**Tasks:** T-041 (scope), T-042; ADR-0009 amendment; EXP-008 Â§9.

Established why the limiter cannot ship to online play: `GameLogic::getCRC` folds every object in
`m_objList` into the multiplayer CRC (`GameLogic.cpp:4410-4462`), and OCL debris/hulks are
ordinary objects; GenTool's Game File Validator checks game files and treats custom patches as a
modified install. A runtime-gated patch could keep MP behaviour identical but still modifies a
validated file; the rebuilt engine is not retail-CRC compatible at all.

Per the user's decision, **online stays stock**: no limiter, no binary modification. The online
profile remains GenTool + d3d8to9 (`d3d8x.dll`) + borderless, now launched by
`tools/play-shockwave-online.ps1` (verified: stock exe, `nvd3dum.dll`, borderless). SWR.net
acceptance of `d3d8x` is unverified because there is no account/opponent; deleting `d3d8x.dll`
reverts to plain GenTool. T-041 remains singleplayer-only (performance launcher).

## 2026-11-15 - T-043: keep every debris piece, skip cosmetic partition churn

**Task:** T-043; EXP-008 Â§7/Â§9.

Phase timing (`ZH_PERF_LOGIC`) found the real mass-wipe cost: `ThePartitionManager->UPDATE()`
at **~1,000 ms/frame** with ~6,000 debris, while object updates were ~18 ms, AI 0.5 ms and
destroy-list 0.6 ms. Cosmetic debris is `UNATTACKABLE`/`NO_COLLIDE` and hulks live ~1.5 s, but
they paid full per-frame cell and collision bookkeeping.

`ZH_COSMETIC_PARTITION=1` (T-043) detaches `GenericDebris` and `KINDOF_HULK` objects from the
partition dirty list without recalculating cells/collisions. Unlimited debris, 1,000-tank wipe:
peak **11,554 debris / 909 hulks**, partition **0.01 ms median / 5.5 ms max**, frames
**19.6 ms median, p95 20.3, p99 20.75, worst 25.7** (51 FPS). The previous unbudgeted run had
5,771 debris and collapsed to ~1 FPS (partition 1,380 ms max).

The performance launcher now uses `ZH_COSMETIC_PARTITION=1` with budgets disabled (0/0), so all
debris is kept; T-041 budgets remain an optional fallback. The partition manager is part of the
multiplayer CRC snapshot, so T-043 is singleplayer-only like T-041 (EXP-008 Â§9).

**Verification.** Engine `8C9E76D2...2AA5` built and staged; `I3-logic-phases.csv`,
`I3-objects.log`, `I4-logic-phases.csv`, `I4-objects.log`, `I4-frames.csv`; docs check recorded
in the session summary.

## 2026-11-15 - Camera controls and real-superweapon demo gap

**Task:** T-044; ISSUE-0013.

User play-test feedback: in the borderless profile, wheel zoom and screen-edge panning appeared
missing (only right-drag panning worked), and the nuke demo used US Crusaders plus the Nuke
Cannon shell FX rather than the China Nuclear Missile.

- **Edge scrolling:** disabled by `ScreenEdgeScrollMode_Default = EnabledInFullscreenApp`;
  windowed/borderless needs `ScreenEdgeScrollEnabledInWindowedApp = yes` in `Options.ini`.
  Added `tools/set-screen-edge-scroll.ps1` (backup + keys) and called it from the performance
  launcher. Verified: edge pan pixel diff 0.01 â†’ 40.51; wheel zoom zooms after 4 notches.
- **Focus:** wheel/edge input is ignored while the game is not foreground; `launch-game.ps1`
  now brings the game window to the foreground after launch.
- **Real FX/units:** the harness supports `ZH_STRESS_TEMPLATE` and `ZH_NUKEFX_NAME`; a demo
  with 400 `ChinaTankBattleMaster` units and the `FX_Nuke` superweapon detonation was captured
  (`artifacts/shockwave-china-nuke2/`). `FXList` calls remain visual-only (no projectile,
  weapon/OCL, or blast collision); damage in the harness is applied directly. This is adequate
  for the partition/debris cost measurement, not for validating the full superweapon chain.
- **Replay:** the user's `debris check test.rep` loads in the rebuilt engine but desyncs
  (`-ignoreReplaySyncErrors`); by 15:02 game time only 1 hulk appeared, so it cannot serve as
  real-chain evidence in this engine. A retail-client replay or a save just before the nuke is
  needed for that.

**Verification.** `artifacts/shockwave-camera-test/` (edge/wheel), `artifacts/shockwave-china-nuke2/`
(FX_Nuke + Chinese units), `artifacts/shockwave-replay-nuke/` (desync observation).


## 2026-11-15 - Real superweapon chain on 1,000 Chinese units (T-045)

Added `ZH_REALNUKE=<template>` to the harness: it creates the warhead object and kills it, so
`NeutronMissileSlowDeathBehavior` runs the real `FX_Nuke`, eight blast waves (300-2400 ms,
120/230 radii, 400/250 damage, topple/push) instead of an FX list. Scenario: 1,000
`ChinaTankBattleMaster`, one `NeutronMissileDUMMYObject`, budgets off, partition skip on, dGPU.

Results: peak **4,230 debris** (all drawable and visible), frame median **28.94 ms** (34.6 FPS),
p95 35.29, p99 75.78, worst 353 ms (startup/first blast), 24.2% over 33.3 ms. The earlier
1,000-unit synthetic wipe had more debris (11,554) but bypassed the weapon/OCL chain; this run
exercises real damage, topple and blast physics. Visual: `artifacts/shockwave-real-nuke/real-nuke.gif`.
The user's retail replay still desyncs in the rebuilt engine, so this is the closest real-chain
reproduction until a retail replay or pre-nuke save is available.

## 2026-11-15 - T-046 conservative broadphase for debris collisions

Added a 3D bounding-sphere pre-reject in `PartitionData::addPossibleCollisions` (`ZH_DEBRIS_BROADPHASE`),
plus test-only phase timers (`ZH_PARTITION_LOG`). On 1,000 ChinaTankBattleMaster + the real
NeutronMissile warhead: pair building p95/max 24.7/90.5 -> 2.6/4.0 ms, contact 5.9 -> 3.7 ms,
frame p95 54.4 -> 46.0 ms, with **all debris-debris/unit/structure collisions retained** (the
pair filter, by contrast, dropped debris-debris pairs; the blunt skip froze cells entirely).
Performance launcher default is now cells kept + broadphase on + pair filter off + skip off.

## 2026-11-15 - T-047 debris visibility verified; residual nuke spikes are not debris

Closed the "debris are invisible" question: with a single unit killed at the camera, the test-only
`ZH_DEBRIS_LOG` shows `W3DDebrisDraw::doDrawModule` running with live render objects and world
positions, and `artifacts/shockwave-debris-visual/frames/frame0005.png` shows chunks tumbling through
the nuke smoke. Earlier captures missed them: 1.5-1.9 s lifetime, camera off the spawn grid, and
3 clicks of zoom put the camera past the terrain.

Also confirmed ShockWave `GenericDebris` is `KindOf = UNATTACKABLE` (not `NO_COLLIDE`), so debris do
collide with each other; the T-043 pair filter was a real physics change and T-046's broadphase is the
correct replacement. Phase attribution (`ZH_PERF_LOGIC` + `ZH_PERF_SPLIT`): logic worst 61.5 ms
(updates p95 8.63 / max 47.9, partition p95 3.2 / max 14.5, destroy max 19.3), draw max 51.9,
particles max 18.4. Capping debris at 24 leaves the same 100-350 ms wall frames (max 370.6 vs 347.0),
so those frames are nuke-FX/audio/main-loop, not debris. The 180 ms client outlier is
`TheShell->UPDATE` during a shell transition. Test-only phase timers are in
`engine/patches/T-047-perf-diagnostics.patch`; final engine `B3FF9CA1...CF3F` (5,854 debris all
drawable/visible, median 33.05 ms at the 30 FPS cap in the capture run, clean p95 39-42 ms).

## 2026-11-15 - T-048 dense 1,000-unit opponent army, nuked 5 times

Added dense packing (`ZH_STRESS_DENSE`, `ZH_STRESS_SPACING`), repeated spawn/nuke cycles
(`ZH_STRESS_CYCLES`, `ZH_STRESS_CYCLE_INTERVAL`, survivor cleanup) and nuke phasing
(`ZH_NUKEFX_OFFSET`) to the test harness. Ran 1,000 ChinaTankBattleMaster in a 32x32 grid at
30-unit spacing with nine real NeutronMissile warheads per cycle for five cycles. Debris peaks
5,944 -> 9,579 (census); every debris has a drawable and is visible. Frame times: median
38.16 ms (~26 FPS), p95 79.17, p99 158.89, max 376.8; 72.7% over 33.3 ms. Worst frames are the
spawn/cleanup frames (~140-150 ms of updates for 1,000 new objects, up to 92 ms destroy), not
the nuke; partition stays at p95 4.5-7.6 ms / max 27.3 ms. The earlier 5,000-unit attempt ran at
~1 FPS because ChinaTankBattleMaster has no Geometry block in the ShockWave INI (default
1-unit radius -> 4-unit auto-spacing); `ZH_STRESS_SPACING=30` fixes the footprint. Engine
`1915B8BF...4406`. Evidence: EXP-008 section 13, `artifacts/shockwave-1000x5/`.

## 2026-11-15 - Watchable 1,000-unit nuke-cycle demo

Added `tools/demo-shockwave-army-nuke.ps1`: launches the optimized copy, arms the dense-army
scenario (1,000 tanks, 30-unit spacing, real NeutronMissile salvo every 8 s) and leaves the game
running. `-Loop` keeps cycling until the game is closed; `-Units/-Spacing/-Warheads/-Cycles`
override the defaults. The script maps shell clicks from the real client area and focuses once
before measuring, because GenTool restores the DPI-virtualized 1536x864 window to 1920x1080 on
first focus.

## 2026-11-15 - T-049 full copy/source audit; broadphase, patch, and harness fixes

Compared the working copies and the 10-file engine source diff against the pristine records.

**Copies.** `game/baseline-pristine` is 1,914/1,914 files unchanged against the manifest.
`game/work` still differs only in `d3d8.cfg` (fullscreen profile). `game/engine-test` contains the
older `7C3CE0...` engine snapshot plus the expected retail backup/log/JSON files. The ShockWave
copies match the ShockWave source apart from the documented exe/wrapper/profile changes and the
materialised `.big` replacements. One undocumented divergence: `game/shockwave-work/!Shw_wnd.big`
was repacked to change `LISTBOXDATA` in four map-select windows (original `26EF0EEA...C643`,
patched `C287FAC2...4035`; `.bak` preserved). It was copied to `game/shockwave-engine` as well
(original kept as `.orig`); `tools/prepare-shockwave-copy.ps1 -Force` would lose it.

**Source bugs fixed.** (1) The T-046 broadphase compared object positions (bottom centers) in Z,
so it could reject valid sphere overlaps for objects of different heights; it now adds
`getZDeltaToCenterPosition()` for both objects, matching the engine's own 3D test
(ISSUE-0014). (2) The stress harness cached `Team*`/`ThingTemplate*`/ObjectIDs across map changes,
dereferenced a possibly-null neutral player, and created `nukefx.log` on every first logic tick;
it now resets when not in game, guards the player, and only logs when `ZH_NUKEFX>0` (ISSUE-0016).
(3) `ObjectCreationList` guards `firstObject` before the non-retail experience-sink block.

**Harness isolation.** `tools/launch-game.ps1` now takes `-TestEnv`, clears every known `ZH_*`
variable before launch and restores the caller's environment afterwards. The demo/performance
scripts pass their settings that way; `benchmark-entity-heavy.ps1` saves/clears/restores the full
set. Verified with a stub exe: a normal launch sees no `ZH_*` variables even when the parent has
`ZH_STRESS` set, and the parent value is restored (ISSUE-0016).

**Patch reproducibility.** The per-task patches are not a series: T-015-benchmark-harness embeds
T-023, and T-036/T-039 embed the frame logger; `git apply` also needs whitespace relaxation on the
CRLF vendor tree. Added `engine/patches/current-engine.patch` (cumulative, no BOM); it applies to
a clean temporary index and yields an empty `git diff` against the source that built the engine.
The READMEs now mark the per-task files as historical snapshots (ISSUE-0015).

**Build/stage.** Rebuilt with `tools\build-engine.ps1` (configure + Release, exit 0; log
`artifacts/2026-11-15-copy-audit/build-fix.log`). New engine **`F606E60374B662877407D40C0603DA2961981816C8F445A629AD7ABD60C007A3`**
(6,753,792 B), staged into `game/shockwave-engine`; `engine.json` now records the cfg hash and the
actual `d3d8.dll` hash separately (d3d8to9 `122928CF...8AB8`). The previous `1915B8BF...` binary is
kept at `artifacts/2026-11-15-copy-audit/engine-before-fix-1915B8BF.exe`. Smoke test: the new
engine launched borderless with no harness settings (`launch-game.ps1 -NoFocus`), showed the
ShockWave/Zero Hour title, stayed alive for 25 s, did not update `ReleaseCrashInfo.txt`, and did
not create `nukefx.log`/`stress.log`.

**Not changed.** No writes to the install or `game/baseline-pristine`; the retail work copy's only
difference remains `d3d8.cfg`. The medium-risk multi-adapter index assumption in
`Get_Preferred_Render_Device` (D3D adapter index vs `_RenderDeviceNameTable` index) is documented
in the audit but not changed: it is a no-op on this single-adapter D3D8 machine and was not
hardware-tested. Also fixed the validator self-test: links into gitignored `artifacts/` are now
warnings, not broken links (ISSUE-0017), so `check_docs.py --self-test` passes again.
Evidence: `artifacts/2026-11-15-copy-audit/` (`copy-diff.md`, `source-working.diff`,
`copy-diff.json`).


## 2026-11-15 - T-049 optimization status confirmation

[VERIFIED] Reviewed state.json, BOARD, engine/README, EXP-001/005/008, ADR-0007/0009,
and ISSUE-0014 to confirm completed profiles, opt-in culls, GPU routing, broadphase,
and stability work. No new performance run was performed; quoted gains remain historical
measurements from their respective scenarios. Get-FileHash game/shockwave-engine/Generals.exe
-Algorithm SHA256 returned F606E60374B662877407D40C0603DA2961981816C8F445A629AD7ABD60C007A3,
matching the audited current build. The broadphase center correction has build/source
verification, not a fresh in-game tall-structure collision test. Task statuses, focus and
blockers are unchanged. Verification: python tools/check_docs.py exited 0 with
OK: documentation system is consistent.


## 2026-11-15 - T-050 validate low-level optimization candidates

[VERIFIED] Inspected current source, generated Release properties, recorded experiments and
primary upstream/MSVC/Intel/NVIDIA/Rust documentation. Added the linked research report for
memory layout, existing pools, SIMD, threading, pathfinding and Rust, with per-candidate
validation requirements. Corrected the earlier chat implication: pools, contiguous pathfind
storage and upstream pathfinding improvements already exist; improved pathfinding is guarded
and branch presence alone does not prove it runs on normal requests. Allocation/lock share,
cache misses and specific vectorized loops remain unknown. No game/engine source was changed.

[VERIFIED] `python artifacts/2026-11-15-low-level-research/inspect.py` exited 0. It recomputed
original pair maxima 90.515/3.973 ms and recovered `frame > 300` as the p95 population giving
54.43/46.04 ms. Fixed the documented phase CSV filename (ISSUE-0018) and recorded the warmup
method (ISSUE-0019); both issues closed with the script result. Dense-run all-row reanalysis
has update maximum 149.951 ms and destroy maximum 91.948 ms; these are coarse phase costs,
not proof allocation causes them. Inputs, hashes, excerpts and method are in
`artifacts/2026-11-15-low-level-research/manifest.md`. No fresh runtime benchmark or new
performance improvement is claimed. Recommended next experiments: corrected-build baseline,
lifecycle/nuke-event attribution, movement/pathfinding workload, then bounded build/data/SIMD
or read-only worker experiments. Rust requires a measured algorithm and batch C ABI boundary.

Verification: `python tools/check_docs.py` exited 0: `OK: documentation system is consistent`
(62 Markdown files, 50 tasks, 9 ADRs, 19 issues).

## 2026-11-15 - T-051/T-052 frame attribution, LTCG A/B, engine identity

[VERIFIED] Added test-only single-clock frame attribution to the engine (`ZH_ATTR_LOG`,
`ZH_ATTR_SAMPLE`; new `GeneralsMD/Code/GameEngine/Include/Common/PerfAttrib.h`). One CSV row
per presented frame carries `interval`, the frame phases (pre/audio/client/msg/net/logic/pacer),
the client sub-phases (shell/draw/particles/displaystr/ingameui), the logic sub-phases
(updates/ai/build/partition/destroy/rest), the slowest update module and destroyed object (opt-in),
destroyed count, spawn count/time and nuke ticks. Engine rebuilt `0B01F01F...0AEB`;
`engine/patches/current-engine.patch` regenerated (UTF-8) and verified with
`git apply -R --check` (exit 0).

[VERIFIED] Preflight rebuild of unchanged source produced a different file hash because MSVC
writes a per-link PE timestamp, a per-link PDB GUID/age, debug-directory entry timestamps and an
embedded `__DATE__`/`__TIME__` pair; `.text` was byte-identical. Filed ISSUE-0020 and added
`tools/engine-identity.ps1` (full/section/stable hash). Current and previous builds now compare
`STABLE IDENTITY MATCH`. Documented the convention in `engine/README.md`.

[VERIFIED] EXP-009: three ShockWave runs on `game/shockwave-engine` (d3d8to9, dGPU, 1920x1080
borderless), frame times from `perf.csv`. 1,000 units + 1 real warhead: median 22.73 / p95
33.52 ms. The same army respawned 5 times with 9 warheads per cycle: median 33.33 / p95 77.42 /
p99 116.53 ms, 70 frames over 100 ms. Same run with `ZH_DEBRIS_PER_FRAME=1`: median 18.82 /
p95 38.90 / p99 54.51 ms, 21 frames over 100 ms. Logic sub-phase maxima: updates 151.1 ms,
destroy 92.4 ms, partition 28.2 ms.

[VERIFIED] Attribution result: the four worst update frames (151.1/140.8/138.7/134.2 ms) are the
frame after each spawn, where 1,000 fresh objects run their first `AIUpdateInterface` and
`PhysicsBehavior` tick; the slowest single module is 0.8-1.5 ms, so the cost is the count, not a
hot object. Spawn frames cost 82-86 ms in `TheThingFactory->newObject` plus 61-92 ms destroying
234-325 survivors (0.28 ms each). Nuke ticks show `NeutronMissileSlowDeathBehavior` at
12.5-14.3 ms per warhead, i.e. the damage/death/debris cascade, ~80-90 ms for a nine-warhead
salvo. Debris suppression cuts destroy max 92.4 -> 30.3 ms and updates max 151.1 -> 82.5 ms, so
debris creation and simulation are the dominant removable mass-death cost. Dropping debris stays
rejected (T-048); T-053 proposes a deferred, keep-every-piece queue.

[VERIFIED] Two defects in the first capture build were found and fixed: `interval` was measured
from the previous frame's start (one-row shift, meaningless residual) and the per-frame reset ran
before logic instead of before the client, zeroing the client sub-phases. A verification run on
`0B01F01F...0AEB` shows the inter-frame `gap` at median 0.02 / max 0.26 ms, client sub-phases
populated (`draw` median 10.78 ms; `shell` max 189.5 ms) and no negative gaps. Evidence:
`artifacts/2026-11-15-attrib-fixed2/`.

[VERIFIED] EXP-010 LTCG: separate build `build/engine-ltcg` with
`-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`; `<WholeProgramOptimization>true</WholeProgramOptimization>`
and `/LTCG:incremental` confirmed in the generated project and link tlog; exe 6.76 -> 7.81 MB.
Six alternating runs: nuke1 median 25.88 -> 24.95 ms (`-3.6%`, both pairs consistent), p99 40.45
-> 39.83 ms; 5-cycle median unchanged (30 FPS cap) but p95 85.35 -> 73.72 ms (`-13.6%`) and p99
131.70 -> 116.77 ms (`-11.3%`, single pair, reported as tentative). LTCG stays optional until a
real replay confirms it (T-025).

[VERIFIED] No game install or baseline file was modified. `game/shockwave-engine` now runs the
T-051 build; `game/engine-test` was re-staged earlier in the session with an intermediate build
and still contains it (its `engine.json` records `31958108...`), so re-run
`tools/stage-engine.ps1` before using that copy.

Verification: `python tools/check_docs.py` exited 0 (65 Markdown files, 53 tasks, 20 issues).
[VERIFIED] Correction to the note above: `game/engine-test` was re-staged after the final build, so both `game/engine-test` and `game/shockwave-engine` now contain `0B01F01F28758D2C516B390E9B9EF2D8C1AD431CB555FD637D3F9A02D9BD0AEB`.

## 2026-11-15 - T-054/T-055 broadphase correctness differential, P7 pathfinding spec

[VERIFIED] Added a test-only collision-set differential: `ZH_COLLISION_LOG` writes
`frame,candidates,collisions,hash,bp_misses` per logic frame (order-independent hash of the
unordered object-id pairs that passed the narrow phase), and `ZH_BROADPHASE_CHECK=1` re-runs
every broadphase-**rejected** pair through `PartitionData::friend_collidesWith`, logging
rejections that would have collided. `ZH_STRESS_STRUCTS`/`ZH_STRESS_STRUCT_COUNT` place tall
immobile structures around the tank grid. Scenario: 300 tanks, 20 `ChinaCommandCenter` on a
330-unit ring, three real warheads.

[VERIFIED] The shipped T-046 broadphase was **not** conservative: 270+ logged rejections were real
collisions, all `GenericDebris` vs a tall tree, e.g.
`153,GenericDebris,TreeOakFall5,0,1,1.00,1.00,3.00,15.00,8.77`. Root cause:
`GeometryInfo::calcBoundingStuff` stores `max(majorRadius, height/2)` as a cylinder's bounding
radius (`Geometry.cpp:497-505`); for r=3, h=15 that is 7.50 versus the true 8.08, so debris
touching a trunk were rejected before the narrow phase. The off/on differential agreed: 1,597 of
3,169 frames differed by ~2 pairs. Filed ISSUE-0021.

[VERIFIED] Fixed in `PartitionManager::addPossibleCollisions` with a local
`zhConservativeBoundingRadius` (true half-diagonal per geometry type, never smaller than the
stored value) plus a `x1.02 + 0.25` margin for float rounding and the narrow phase's contact
tolerance. `GeometryInfo` itself is unchanged. Probe after the fix: 3,667 frames, 675,079
candidate pairs, 128,888 narrow-phase collisions, **0** rejected-but-colliding pairs; candidates
remain 81% below broadphase-off (675,079 vs 3,603,940). Engine `11A4F523...F5E8`.

[VERIFIED] Per-frame collision counts are still not bit-identical on/off (+/-1 on ~2/3 of frames)
with zero rejected collisions. Cause: `processContactList` evaluates `friend_collidesWith`
lazily, interleaved with `onCollide`, which moves objects; a smaller candidate set changes the
processing order. Recorded in EXP-011 so the acceptance test is the rejected-pair probe, not the
count. This reinforces that T-043/T-046 stay singleplayer-only (CRC).

[VERIFIED] Engine `current-engine.patch` regenerated (UTF-8) from the working tree;
`git apply -R --check --ignore-space-change` exits 0.

[VERIFIED] T-050 recommendation #4 is now specified rather than implemented:
`docs/research/2026-11-15-pathfinding-workload-spec.md` defines the moving-army scenario
(`ZH_PF_GROUPS`/`_GROUP_SIZE`/`_INTERVAL`/`_BLOCKERS`/`_SEED`), the per-request log
(`frame,from,to,found,expansions,pushes,pops,maxOpen,pathLen,usec,fallback`), the per-frame
aggregate, the four experiments it enables, and the acceptance rules (path equality, no cap/cost
changes). It cites the current API points: `AIPathfind.h:84,114,256`, `AI.h:351,415`,
`AIUpdate.h:359`, `Geometry.cpp`/`PathfindCell.cpp` open-list code.

[VERIFIED] `python tools/check_docs.py` exited 0 (68 Markdown files, 55 tasks, 21 issues);
`--self-test` passes.

## 2026-11-15 - T-053 deferred keep-every-piece debris queue (implemented, measured, rejected)

[VERIFIED] Implemented `ZH_DEBRIS_DEFER=<n>` (off by default) in `ObjectCreationList.cpp`:
one unit of deferral is a cosmetic OCL nugget invocation (one death's debris cluster). At most n
clusters are created per logic frame; the rest are queued with template, position, angle, lifetime
and producer id, and replayed by `zhFlushDeferredDebris()` at the start of the next
`GameLogic::update()` with the same budget. The producer is resolved by id (it may already be
dead). Queue capped at 20,000 clusters; on overflow the cluster is created immediately instead of
being lost and `dropped` increments. `ZH_DEBRIS_DEFER_LOG` writes
`frame,objects_created,clusters_flushed,queued,dropped`. Engine `4942093F...76E8`;
`current-engine.patch` regenerated, `git apply -R --check` exits 0.

[VERIFIED] Correctness: three five-cycle runs with `ZH_DEBRIS_DEFER=40` report
`created 25169/25181/25106`, `clusters_flushed 12187/12232/12201`, `max queued
2049/2051/2048`, `final queued 0`, `dropped 0`. Every queued cluster is replayed, the queue
drains, nothing is lost, no assert or crash over five cycles.

[VERIFIED] Performance is a negative result. Six alternating runs (base, defer x3), same engine
and scenario (1,000 units, five spawn/nuke cycles, nine warheads), 90 s windows:

- median 33.36 -> 33.36 ms (0.0%; the scenario sits on the 30 FPS cap)
- mean 41.08 -> 41.59 ms (+1.2%), p95 75.02 -> 75.66 ms (+0.9%), p99 111.84 -> 108.66 (-2.8%)
- destroy max 87.13 -> 79.57 ms (-8.7%) against a 15% baseline spread (82.6-95.7)
- updates max 177.26 -> 205.66 ms (+16.0%)

The destroy peak drops only inside run variation while the update peak rises: the deferral moves
the work into the next frame instead of removing it. Rejected per the T-050 retention rule (gain
must exceed run variation). Kept as an opt-in experiment; no profile enables it. EXP-012 records
the numbers, the mechanism and the next levers (spawn burst and first-tick burst are harness-shaped;
T-025 and T-035 remain the real-game work).

[VERIFIED] An earlier read of the A/B folder happened while the last run was still writing and
produced a wrong "destroy max -21%" summary; the folders were re-summarized after all six runs
finished and EXP-012/BOARD/state now carry the corrected numbers (`summary.json` regenerated).

Verification: `python tools/check_docs.py` exited 0 (69 Markdown files, 55 tasks, 21 issues);
`--self-test` passes.

## 2026-11-16 - T-056 original vs optimised profile, identical conditions

[VERIFIED] Ran a controlled side-by-side on engine `4942093F...76E8`: same binary, game copy,
map, camera, scenario, resolution (1920x1080 borderless) and window mode; only the options profile
differs (`default` = AA 8 + High vs `performance` = AA 0 + Low). The retail `Generals.exe`
cannot run the 1,000-unit harness and has no frame logger, so the retail-equivalent *settings* on
the same engine are the controllable condition; this is stated in EXP-013.

Scene A (stock-ZH copy, 1,000 tanks, uncapped `ZH_FPS=240`, three alternating pairs): original
median 25.04 ms / p95 30.35 / p99 47.37 (draw 14.49 ms); optimised 7.48 ms / 8.99 / 13.17 (draw
1.85 ms). **3.35x median, -70.4% p95, -72.2% p99**, run spreads tight (25.24/25.26/24.62 vs
7.51/7.48/7.45). With the default 30 FPS cap the same scene shows 33.35 vs 33.37 ms (the cap
hides the gain; p99 still 53.28 -> 35.48), which is why the uncapped table is the meaningful one.

Scene B (ShockWave copy, d3d8to9 + dGPU, 1,000 units x5 spawn/nuke cycles, capped, two pairs):
p95 214.19 -> 84.50 ms (-60.5%), p99 248.76 -> 141.37 (-43.2%), mean 74.42 -> 48.07 (-35%),
median 33.43 -> 35.19 (+5.3%, within the cap's noise).

[VERIFIED] Added `-MaxFps` to `tools/benchmark-entity-heavy.ps1` (sets test-only `ZH_FPS`)
because the default cap made a throughput comparison impossible, and `tools/run-original-vs-
optimized.ps1` drives the A/B. `options.ini` was left on `performance`; every change is backed
up in `artifacts/options-backups/`.

[VERIFIED] Caveat recorded in EXP-013 Â§5: absolute draw time at Low is much lower than the older
EXP-003 record (1.85 vs 18.45 ms), so cross-session absolute numbers are not comparable; the
same-session ratio is.

Verification: `python tools/check_docs.py` exited 0; artifacts under
`artifacts/2026-11-16-original-vs-optimized/` with `manifest.md` and `summary.json`.

## 2026-11-16 - T-057 FPS cap: what removing it buys, and a launcher bug

[VERIFIED] Mechanism: the render cap is `m_useFpsLimit` + `FramePacer::m_enableFpsLimit` with a
preset list of 30, 50, 56, 60, 65 ... 120, 144, 240, 480, Uncapped (`FrameRateLimit.cpp:69`).
It can be changed by `-noFPSLimit` / `-fps <n>` on the command line
(`CommandLine.cpp:1054,1310`), by `Ctrl+Numpad +/-` in game (`MetaEvent.cpp:810`, HUD shows
`â–²30`..`â–²X`), or by `UseFPSLimit`/`FramesPerSecondLimit` in GameData. Logic stays at 30 Hz;
the pacer exposes a logic-frame phase so rendering interpolates between ticks.

[VERIFIED] Sweep on 1,000 tanks, optimised profile, 40 s per run: cap 30 = 33.37 ms median
(30.0 FPS, 53.6% of frames over 33 ms), cap 60 = 16.65 ms (60.0 FPS, 0.3%), cap 120 = 8.31 ms
(120.4), cap 240 = 6.25 ms (160.1 FPS, p95 7.32). The 30 FPS cap was leaving roughly 5x of the
renderer idle on this scene at Low detail.

[VERIFIED] Found and fixed a launcher bug: `tools/launch-game.ps1` declared `-NoFPSLimit` but
never added `-noFPSLimit` to the command line, so the documented switch did nothing
(ISSUE-0022). After the fix, two launches of the same copy/scene with `ZH_FPS` unset give
33.36 ms / 30.0 FPS capped vs 9.58 ms / 104.4 FPS with the switch; the launcher now prints
`FPS : uncapped for profiling`. `tools/play-shockwave-performance.ps1` exposes it as
`-UnlockFps`.

[INFERRED] Uncapping improves smoothness (interpolated rendering) but not simulation rate: aiming,
pathing, damage and build timers still tick 30 times per second, so it cannot change match
outcomes and is not an advantage in play. Cost is GPU time, heat and power only. Recommendation
recorded in EXP-014: 60 FPS cap is the best default for normal play on this hardware; uncapped
remains a preference (Ctrl+Numpad+), not part of the shipped profile.

Verification: `python tools/check_docs.py` exited 0 (72 Markdown files, 56 tasks, 22 issues);
artifacts under `artifacts/2026-11-16-fps-cap-sweep/`.

## 2026-11-16 - T-058 uncapped default and the definitive uncapped A/B

[VERIFIED] Root cause of the inert FPS switch (extends ISSUE-0022): the `-noFPSLimit` entry in
the option table sits inside `#if defined(RTS_DEBUG)` (`CommandLine.cpp:1297-1353`), and this is
a Release build, so the flag never existed. The launcher also only set `ZH_FPS`, which the
harness auto-start reads but a normal launch does not. Moving the table entries out broke the
option array's preprocessor structure (build error, reverted); the shipped fix is an engine latch:
`FramePacer::isActualFramesPerSecondLimitEnabled` now also requires
`!(g_zhForceUncappedFps || ZH_NOFPSLIMIT)`, so a later GameData/INI load cannot re-enable the cap.
Engine rerebuilt `71FEA54D...0E8E`; `current-engine.patch` regenerated, `git apply -R --check`
exits 0.

[VERIFIED] Our tools are now uncapped by default: `tools/launch-game.ps1` (`-WithFpsLimit`
restores the cap), `tools/benchmark-entity-heavy.ps1` (`-WithFpsLimit` / `-MaxFps`) and
`tools/play-shockwave-performance.ps1` (`-WithFpsLimit`) all set `ZH_NOFPSLIMIT=1`.
Sanity check with `ZH_FPS` unset, same copy and scene: capped 33.39 ms (30.0 FPS) vs uncapped
6.68 ms (149.7 FPS).

[VERIFIED] Re-ran the whole original-vs-optimised comparison with **both sides uncapped**, 3
alternating pairs on the frame-time scene and 2 on the nuke scene, engine `71FEA54D`:
- Scene A (1,000 tanks): original 21.86 ms median / 45.7 FPS / p95 27.12; optimised 6.47 ms /
  154.5 FPS / p95 8.26. **3.38x median, p95 -69.5%.** Per-run medians 21.78/21.39/22.42 vs
  6.41/6.45/6.55.
- Scene B (1,000 units x5 spawn/nuke cycles): original 8.62 ms median but p95 177.37 and p99 ~216;
  optimised 4.33 ms, p95 61.59, p99 ~84. **1.99x median, p95 -65.3%.** Per-run 8.58/8.66 vs
  4.29/4.36.

[INFERRED] The uncapped medians in Scene B are low because most frames are cheap; the cost lives in
the spawn/death spikes, which is why p95/p99 are the meaningful columns there. With both sides
uncapped the earlier capped comparison's "no difference" disappears: the 30 FPS cap, not the
renderer, was hiding the gap.

Verification: `python tools/check_docs.py` exited 0 (72 Markdown files, 57 tasks, 22 issues);
artifacts under `artifacts/2026-11-16-uncapped-ab/` with `manifest.md` and `summary.json`.

## 2026-11-16 - T-059 healing / repair-icon cost investigation

[VERIFIED] Added test-only instrumentation (`ZH_ICON_LOG`, `ZH_HEAL_PULSE`/`ZH_HEAL_INTERVAL`)
that times the per-unit icon pass and counts drawables processed, heal icons drawn, heal attempts
and actual model rebuilds (`replaceModelConditionStateInDrawable`). Engine `1E4E3501...3310`.

[VERIFIED] Heal logic is cheap: 300 dense units healed every 30 frames show `l_updates` median
1.30 ms on the 133 pulse frames vs 1.19 ms on the 3,886 quiet frames (+0.12 ms). The 25 ms
`l_updates` outlier is a death frame, not a heal frame. `ActiveBody::attemptHealing` is a module
loop plus a throttle-gated `doDamageFX`; it does not scale badly.

[VERIFIED] The icon overlay is the only heal-specific cost that scales: on the ShockWave copy
(stock copy has no heal-icon animation, which is why the first runs measured zero icons) 82 icons
peak gives an icon pass of 0.5-3.0 ms, and a linear fit over the >=40-icon frames gives
**~0.011 ms per heal icon** (~11 ms at 1,000 simultaneously healing units, 2-5 ms for "hundreds").
Model rebuilds are not healing-specific: the 2,507-change burst is map load; heal frames peak at
129.

[VERIFIED] A 300-unit controlled reproduction did not show a significant drop (median 7.16 ms with
healing vs 6.82 ms without), so the user's scene differs from the harness in a way that matters -
most likely repair-field healing (`AutoHealBehavior` with `Radius`: a partition query per healer
per pulse, plus a particle system per healed unit) or repair vehicles.

[VERIFIED] Attempted fix and revert: caching `Image -> TextureClass` in `W3DDisplay::drawImage`
(the per-icon cost is the per-draw `Get_Texture(filename)` lookup) produced build `F960D27B`
that **failed to open a game window** twice. The cache was removed, `W3DDisplay.cpp` restored
from git, and the engine rebuilt as `1E4E3501...3310`, which runs normally again (verified with a
ShockWave match). Root cause is most likely texture ownership: raw pointers cached without
`Add_Ref`/`Release_Ref`. Do not retry without ref-counting and a startup smoke test.

[UNKNOWN] Which heal source the user's scene uses (auto-heal upgrade, repair bay/pad, repair
drone/ambulance) and how many healing units are on screen. That determines whether the fix should
batch the icon draws or amortise repair-field queries; the reproduction needs the same units.

Verification: `python tools/check_docs.py` exited 0 (73 Markdown files, 58 tasks, 22 issues);
artifacts under `artifacts/2026-11-16-heal-icons/`.

## 2026-11-16 - T-060 radiation stress for the healing report (negative result)

[VERIFIED] Added `ZH_RADIATION=<n>` (+ `ZH_RADIATION_SPREAD`): keeps a grid of
`NukeRadiationFieldWeapon` objects around the camera (25 RADIATION damage per 750 ms, 200-unit
radius, 30 s lifetime, respawned before expiry). Unlike `ZH_NUKEFX_DAMAGE` this does not wipe the
army, so units stay alive and keep healing - the stress mode the user proposed. Engine
`E153FF07...3A25`.

[VERIFIED] ShockWave, 300 dense units, 9 radiation fields, heal 8 HP every 15 frames, uncapped,
14,369 frames: frame median **4.29 ms**, p95 14.12, p99 19.99; **272 simultaneous heal icons**
(42,866 icon draws over the run); peak 1,346 drawables in the icon pass; 300 heal attempts per
frame at peak.

[VERIFIED] The icon overlay is not the bottleneck at that scale: across 279 frames with >=30 icons
the slope is **0.0005 ms per icon** (icon pass median 0.002 ms, p95 0.647, max 6.003). The earlier
"~0.011 ms per icon" estimate came from an 82-icon short run and is corrected in EXP-015.

[VERIFIED] No healing-attributable slowdown is reproducible in this build: heal logic +0.12 ms per
300 attempts, icons ~0.6 ms p95 at 272 icons, and the radiation scene's median (4.29 ms) is
identical to the optimised profile without healing. Remaining explanations recorded in EXP-015:
the user's scene differs, or the effect was seen in the retail 1.04 engine (no harness/logger,
cannot be compared under identical conditions), or it was damage/death FX rather than healing.

[VERIFIED] Regression handled: the `Image -> TextureClass` cache tried in
`W3DDisplay::drawImage` produced a build that would not open a window; it was reverted and the
file restored from git. Current engine `E153FF07...3A25` runs normally (ShockWave match verified
in the `shw-rad` run).

Verification: `python tools/check_docs.py` exited 0 (73 Markdown files, 59 tasks, 22 issues);
artifacts under `artifacts/2026-11-16-heal-icons/`.

## 2026-11-16 - T-061 radius-heal reproduction and particle-per-heal guard

[VERIFIED] Built the missing reproduction: `ZH_HEALERS=<template>` + `ZH_HEALER_COUNT` /
`ZH_HEALER_INTERVAL` / `ZH_HEALER_SPREAD` respawns a radius-healing object around the camera,
and `AutoHealBehavior` now counts, per frame, the radius partition queries, the objects handed to
`pulseHealObject` and the pulse particle systems created (columns added to `ZH_ICON_LOG`).
Engine `2324C7FA...6FA9`.

[VERIFIED] Measured with `RepairVehiclesInArea_InvisibleMarker_Level3` (radius 100, single burst,
self-deleting), 5 copies every 30 frames over 300 damaged units: 625-645 radius queries over the
run (at most 5 in any frame), 26 objects healed, 0 pulse particles. Frame median 8.62 ms with
healers vs 7.17 ms without, but the marker is destroyed the same frame it is created so it barely
heals - the sustained-radius case needs a healer with a real lifetime (`TechRepairPad` /
`Spec_RepairStationFieldRepairObject`, radius 156), which the harness can spawn the same way.

[VERIFIED] Fix in `AutoHealBehavior::pulseHealObject`: `createParticleSystem` was called for
every object handed to the pulse, even when `UnitHealPulseParticleSystemName` is absent (all
stock/ShockWave radius healers we could find) and even when the sole-benefactor rule refused the
heal. The call now only happens when a template exists, so nothing visual is lost and the wasted
per-object work is removed. Re-measured after the fix: same 26 heals, 0 particles, median 8.32 ms.

[VERIFIED] Incident while applying the fix: a PowerShell array edit corrupted
`AutoHealBehavior.cpp` to a single line. Recovered with `git checkout` for that file only (it
had no other project changes), re-applied the counters and the guard with the edit tool, rebuilt,
and verified the game runs (4,289 frames). Lesson: do not rebuild source files by slicing line
arrays in PowerShell.

[VERIFIED] `current-engine.patch` regenerated; `git apply -R --check` exits 0. Engine
`2324C7FA` staged into both `game/engine-test` and `game/shockwave-engine`.
`python tools/check_docs.py` exited 0 (73 Markdown files, 59 tasks, 22 issues).

[UNKNOWN] The user's exact heal scenario (map/units, repair structure vs upgrade, engine vs retail
profile). No harness configuration tried so far - self-heal, radiation, one-shot radius marker -
reproduces a significant slowdown; EXP-015 records the three candidate explanations.

## 2026-11-16 - T-061 sustained radius-heal stress (path proven cheap; unmeasured guard reverted)

[VERIFIED] The first radius reproduction used `RepairVehiclesInArea_InvisibleMarker_Level3`, which
is `SingleBurst` with lifetime 0: it deletes itself the frame it is created, so it healed only 26
objects over a run and exercised almost nothing. Re-ran with the sustained healer the report named,
`Spec_RepairStationFieldRepairObject` (radius 156.25, HealingAmount 6 every 500 ms, no lifetime),
5 stations over 300 damaged units on the ShockWave copy.

[VERIFIED] Sustained radius numbers: 141-147 radius queries over a run (at most one per frame across
five stations because pulses are 500 ms apart), 288 objects healed in total with 41 in a single
frame at peak, **0 pulse particles**, 62 heal icons. Frame time with stations 4.07-4.59 ms median /
p99 24.92 vs 4.78 / 22.73 without - no regression, so the radius path is provably cheap at this
scale. Engine `DCF51A29...2839`.

[VERIFIED] Reverted the T-061 particle guard: every stock/ShockWave radius healer omits
`UnitHealPulseParticleSystemName`, so `createParticleSystem` returns null immediately and the
measured particle count was 0 before and after the guard. It could not be validated as a gain, so
the code is back to the original call (with the counters kept) and EXP-015 documents the path as
cheap instead of shipping an unmeasured change.

[VERIFIED] `current-engine.patch` regenerated (`git apply -R --check` exits 0); engine
`DCF51A29` staged into both `game/engine-test` and `game/shockwave-engine`; a final ShockWave
run with 5 stations exercised 147 queries / 216 heals with median 4.07 ms. `python
tools/check_docs.py` exited 0 (73 Markdown files, 59 tasks, 22 issues).

[UNKNOWN] The user's exact heal scenario remains unconfirmed; every heal configuration the harness
can build (self-heal, radiation, one-shot burst, sustained radius station) is cheap or neutral.

## 2026-11-16 - T-062 re-run of the 1,000-unit scenarios on the final engine

[VERIFIED] Re-ran both 1,000-unit scenarios on engine `DCF51A29...2839` with the performance
profile and uncapped rendering:

- stock ZH copy, 1,000 tanks, 3 runs of 40 s: median **7.75 / 7.94 / 7.75 ms** (mean 7.81,
  128 FPS), p95 9.38, p99 13.02, max 115.6, 0.1% of frames over 33 ms.
- ShockWave copy, 1,000 units x five spawn/nuke cycles (9 real warheads), 2 runs of 60 s:
  median **4.26 / 4.10 ms** (mean 4.18, 239 FPS), p95 63.01, p99 92.13, max 381.8, 10.5% over
  33 ms.

[VERIFIED] The ShockWave numbers reproduce EXP-013 (4.18 vs 4.33 ms median, p95 63.0 vs 61.6). The
stock median is at the top of the 6.3-7.8 ms band observed across sessions for the same scene, so
no regression is indicated.

[VERIFIED] Incident: the first three stock runs exited with code 1 at startup immediately after a
benchmark process had been killed mid-run. A plain launch and a harness launch then both succeeded,
and the rerun produced 4,500+ frames per run, so this was a leftover-process transient rather than
an engine defect. The runner now kills stale `generals` processes before each run.

Verification: `python tools/check_docs.py` exited 0; artifacts under
`artifacts/2026-11-16-rerun-1000/` with `manifest.md` and `summary.json`.

## 2026-11-16 - T-063 clean 1,000-unit re-run (background apps closed)

[VERIFIED] The T-062 run was taken while Edge/WebView2/Teams were still active (recorded at start:
`msedge=6;msedgewebview2=13;ms-teams=2`, free 11.1 GB, CPU load 36%). Repeated the same two
scenarios on engine `DCF51A29...2839` with the same profile and uncapped rendering after the user
closed the rest of their work:

- stock ZH, 1,000 tanks, 3 runs: median **6.91 / 6.46 / 6.50 ms** (mean 6.62, 151 FPS), p95 7.96,
  p99 11.13, max 116.3, 0.1% of frames over 33 ms.
- ShockWave, 1,000 units x5 spawn/nuke cycles, 2 runs: median **3.65 / 3.98 ms** (mean 3.81,
  262 FPS), p95 61.72, p99 85.50, max 390.2, 9.8% over 33 ms.

[VERIFIED] The difference from T-062 is background load, not the engine: stock 7.81 -> 6.62 ms
(-15%, p95 9.38 -> 7.96) and ShockWave 4.18 -> 3.81 ms (p95 63.01 -> 61.72). EXP-013 Â§5.2 now marks
these as the final reference numbers for this engine, with the conditions recorded in
`artifacts/2026-11-16-rerun-1000-clean/conditions.json`.

[VERIFIED] All five runs completed without startup failures once stale `generals.exe` instances
were killed and a 3 s pause was left before each launch (the transient seen in T-062). No crash
dumps were produced.

Verification: `python tools/check_docs.py` exited 0; artifacts under
`artifacts/2026-11-16-rerun-1000-clean/` with `manifest.md` and `summary.json`.

## 2026-11-16 - T-064 low-level architecture audit (static, no runs)

[VERIFIED] Added the test-only icon-pass toggle `ZH_NO_ICON_UI=1` (GameLogic.cpp:477-481) so the
per-drawable HUD icons (health bars, heal/repair icons, captions) can be isolated by A/B, and
staged engine `B54939EB...B88C` into both game copies. The A/B itself is **paused at the user's
request** (the machine is in use; background load shifted earlier numbers by ~15%).

[VERIFIED] Audited the vendored engine for per-frame work that scales with object count and
cross-checked each finding against the recorded phase timings. Report:
`docs/research/2026-11-16-low-level-architecture-audit.md`. Critical findings:

1. `GameLogic::processDestroyList` scans the **entire** `m_sleepyUpdates` vector for every
   destroyed object (O(D x N)); the `m_normalUpdates` half is compiled out because
   `ALLOW_NONSLEEPY_UPDATES` is never defined. Objects already carry their behaviour modules
   (`getBehaviorModules()`) and each update knows its heap index (`friend_getIndexInLogic()`),
   so removal can be O(k log k). The current code also silently truncates at MAX_SUO=256.
   Relevant to the measured 92.4 ms destroy peak (EXP-009).
2. Shadow volumes are rebuilt **every frame** (the time guard is commented out, with a source
   comment saying to rebuild only on light/rotation change); each rebuild allocates `NEW Geometry`
   per mesh, the manager scans all vertex buffers three times per frame, and distance culling only
   exists behind `ZH_SHADOWDIST` (off by default). Shadows cost 7.4 ms of 25.0 ms at 1,000 units
   High detail (EXP-004) - affects High-detail players, not the shipped Low profile.
3. Every logic frame scans all objects for disabled status (`GameLogic.cpp:4682`).
4. Sleepy-update maintenance rebalances the whole heap after every pop.
5. Pool allocations/frees and AsciiString copies each take a global critical section in release.

[INFERRED] Ranking for the shipped Low profile: destroy-list scan (bursts) > sleepy heap >
disabled scan > allocator/string locks (measure first); shadow caching matters only at High detail.

[VERIFIED] Filed T-065 (destroy-list O(k)), T-066 (shadow rebuild caching), T-067 (sleepy buckets +
disabled list), T-068 (measure lock share before changing it). No code was changed for these yet
and no benchmark was run, so no gain is claimed.

Verification: `python tools/check_docs.py` exited 0 (74 Markdown files, 66 tasks, 22 issues).

## 2026-11-16 - T-064 optimisations default-on with in-game/Options.ini configuration

[VERIFIED] Turned the previously opt-in optimisations on by default and moved them from environment
variables to the game's own settings file (`Options.ini`), each with an off-switch:

- `DrawDistance` (default 400) - render distance cull (W3DScene).
- `ShadowScreenRadius` (default 120 px) - shadow-volume LOD (W3DVolumetricShadow).
- `DebrisBroadphase` (default yes) - debris collision prefilter (PartitionManager).
- `CosmeticPartition` (default yes) - debris skips partition bookkeeping (singleplayer only).
- `FPSLimit` (default no = uncapped) - the existing key, now also written by the in-game
  "Unlock FPS" checkbox (OptionsMenu), whose write-back had been commented out.

[VERIFIED] Added `OptionPreferences::getDrawDistance/getShadowScreenRadius/
getDebrisBroadphaseEnabled/getCosmeticPartitionEnabled` and wired each consumer to resolve
**env (test override) > Options.ini > default**. `getFPSLimitEnabled` now returns FALSE when the
key is absent, so the shipped default is uncapped; `FramePacer` keeps the env override and falls
back to the preference. `tools/build-engine.ps1` now enables LTCG by default (`-NoLtcg` opts
out), matching the measured -3.6% from EXP-010.

[VERIFIED] Built `5FA73119...0168` (all touched TUs compiled: W3DScene, W3DVolumetricShadow,
PartitionManager, FramePacer, OptionPreferences, OptionsMenu and the menu callbacks). Staged into
both game copies. Startup smoke test with the harness: process alive after 14 s and
`stress.log` shows `spawn cycle=1 frame=1 count=100` - no crash.

[VERIFIED] Documented the settings for users in `docs/optimizations.md`: where the file is, every
key with default/values/effect, the in-game controls (Options checkbox, Ctrl+Numpad +/-), and
copy-paste Performance/Balanced/Quality presets. Linked from `docs/INDEX.md`.

[UNKNOWN] The default-on values have not been benchmarked yet (simulations are paused at the user's
request). The expected effect is the previously measured per-feature gains, not a new claim.

Verification: `python tools/check_docs.py` exited 0 (75 Markdown files, 66 tasks, 22 issues);
`current-engine.patch` regenerated and `git apply -R --check` exits 0.

## 2026-11-16 - T-064 default-on package measured (EXP-016) + launcher regression fixed

[VERIFIED] Measured the default-on package on engine `5FA73119...0168` with no optimisation keys
in Options.ini (so every default applies), performance profile, uncapped.

- Stock 1,000 tanks, 3 runs: 6.82 / 7.43 / 6.52 ms (146.6 / 134.6 / 153.4 FPS), mean **6.92 ms =
  144.9 FPS**, p95 8.85 ms (113.0 FPS), p99 12.04 ms (83.1 FPS). Reference (EXP-013 Â§5.2):
  6.62 ms / 151.1 FPS -> **-4.1% FPS, within run variation**.
- ShockWave 1,000 x5 cycles, 2 runs: 4.06 / 4.06 ms (**246.4 / 246.2 FPS**), mean **4.06 ms =
  246.3 FPS**, p95 **49.59 ms (20.2 FPS)** vs reference 61.72 ms (16.2 FPS), p99 67.87 ms
  (14.7 FPS) vs 85.50 (11.7 FPS). Median is 6.1% lower in FPS, the tail is **~25% higher in FPS**.

[INFERRED] The stock scene cannot benefit: its 1,000-tank grid is ~540x510 world units, so a
400-unit draw distance culls almost nothing, and there is no debris for the partition skip. The
ShockWave scene gains on the tail. Note the ShockWave runner still exports
`ZH_COSMETIC_PARTITION=0`, so that feature was env-overridden off in these runs (EXP-016 Â§4);
the tail gain comes from the broadphase default and draw distance.

[VERIFIED] Found and fixed a regression introduced by an earlier regex edit: `tools/launch-game.ps1`
and `tools/benchmark-entity-heavy.ps1` contained literal `\$WithFpsLimit` / `\$env:...`, which made
the ShockWave runner fail with "not recognized as the name of a cmdlet" and produced no data for
that batch. Both files fixed and validated with the PowerShell parser (OK). The stock runs were
unaffected; the ShockWave pair was re-run.

Verification: `python tools/check_docs.py` exited 0 (76 Markdown files, 66 tasks, 22 issues);
artifacts under `artifacts/2026-11-16-defaults-on/` with `manifest.md`, `conditions.json`,
`summary.json`. Report: `docs/experiments/EXP-016-default-on-package.md`.

## 2026-11-16 - T-067 disabled-scan guard, encoding fix, final analytics

[VERIFIED] T-067: `GameLogic::update` no longer scans every object for disabled status when none is
disabled. A counter (`g_zhDisabledObjects`) is maintained in `Object::setDisabledUntil` /
`Object::clearDisabled` and the loop is guarded. Two alternating pairs on the stock 1,000-tank
scene (A = `F7E1E265`, B = `68D23E4E`): median 7.71/6.92 -> 7.14/7.11 ms (129.7/144.5 -> 140.1/140.7
FPS), mean **7.32 -> 7.13 ms (136.6 -> 140.3 FPS)**, p99 12.21 -> 11.34 ms. The A-run spread
(6.92-7.71) exceeds the delta, so this is recorded as no-regression less work, not a proven gain.
Sleepy-update bucketing was deliberately not implemented (microsecond scale, wake-order risk) and
filed as T-069.

[VERIFIED] Encoding defect found and fixed while editing the board: an earlier PowerShell
`Set-Content` had written `docs/tasks/BOARD.md` in the system ANSI encoding, so `Â§`/`Ã—` were stored
as raw Latin-1 bytes and the file was no longer valid UTF-8. Re-encoded the file from cp1252 to
UTF-8; a scan of all docs now reports no invalid UTF-8. All future doc edits must use the edit tool
or explicit UTF-8 writes.

[VERIFIED] Engine `68D23E4E...7246` staged into both copies; `current-engine.patch` regenerated and
`git apply -R --check` exits 0; `engine/README.md` hash updated.

[VERIFIED] Consolidated analytics (`artifacts/2026-11-16-final-analytics/`, all from recorded
artifacts, ms and FPS):

- Stock 1,000 tanks: retail-equivalent 25.00 ms (40.0 FPS) -> optimised 6.47 ms (154.6 FPS) ->
  default-on 6.84 ms (146.1 FPS) -> +T-065/+T-067 7.12 ms (140.4 FPS). p95 33.8 -> 111.0-122.3 FPS.
- ShockWave 1,000 x5 cycles: retail-equivalent 8.62 ms (116.0 FPS), p95 177.56 ms (5.6 FPS) ->
  optimised 4.33 ms (231.2 FPS), p95 61.60 (16.2) -> default-on 4.06 ms (246.2 FPS), p95 49.66
  (20.1) -> +T-065 4.22 ms (237.0 FPS), p95 48.20 (20.7), p99 66.31 (15.1).

Verification: `python tools/check_docs.py` exited 0 (78 Markdown files, 67 tasks, 22 issues).

## 2026-11-16 - T-066 rejected, T-070 icon A/B, T-071 shipping config + partition attribution

[VERIFIED] **T-070 icon UI pass** (`ZH_NO_ICON_UI`, follow-up to T-059), engine `68D23E4E`,
performance profile, stock 1,000 tanks, 2 alternating pairs. A (icons on): 6.94 / 6.44 ms
(144.0 / 155.3 FPS); B (icons off): 6.66 / 6.45 ms (150.1 / 154.9 FPS). The clean pair is
identical (6.44 vs 6.45 ms, draw phase 1.71 vs 1.79 ms); the aggregate p95/p99 gap comes from a
single slow A run (client 3.63 vs 3.36 ms in the other A run). **No effect** - icons stay on,
`ZH_NO_ICON_UI` remains a diagnostic. Report: `docs/experiments/EXP-019-icon-ui-pass.md`.

[VERIFIED] **T-071 shipping configuration** (engine `68D23E4E`, no optimisation keys in Options.ini,
`CosmeticPartition` at its default), ShockWave 1,000 units x5 nuke cycles, 2 runs:
**4.46 ms = 224.9 FPS** median, p95 **22.23 ms = 45.0 FPS**, p99 **35.12 ms = 28.5 FPS**
(individual runs 4.30/4.61 ms, p95 22.15/22.30 ms).

[VERIFIED] **Partition attribution** (same binary, only `ZH_COSMETIC_PARTITION` differs, 2 pairs):
skip off 4.56 ms (219.2 FPS), p95 27.33 ms (36.6 FPS), p99 40.98 ms (24.4 FPS); skip on 4.65 ms
(215.1 FPS), p95 **21.37 ms (46.8 FPS)**, p99 **32.95 ms (30.4 FPS)**. Delta p95 **-21.8%**,
p99 **-19.6%**, median +2.0% (inside spread). Combined with T-065's destroy fix this explains the
ShockWave tail: pre-T-065 with the skip off 49.59 ms p95 (20.2 FPS) -> skip off 27.33 (36.6) ->
skip on 21.37 (46.8). Report: `docs/experiments/EXP-021-shipping-package-tail.md`.

[VERIFIED] **T-066 rejected** (EXP-020). Implemented a per-instance rebuild stamp plus
`ZH_SHADOW_THROTTLE` (ms) so the volumetric-shadow silhouette rebuild runs at most every 33 ms
while the cheap per-frame cull tests stay; tested at AA 0 + High (shadows on), stock 1,000 tanks,
2 alternating pairs on one binary (`F49ED05B`): every frame 7.85 ms (127.3 FPS) vs 33 ms 7.77 ms
(128.7 FPS), p95 9.37 -> 9.54 ms (+1.9%), p99 13.53 -> 12.48 ms. **No gain** - the rebuild is not
the High-detail cost; rendering the volumes is. The change was reverted from source (the shadow
`.cpp` is back to only its pre-existing distance-cull patch; header has no diff). T-035
(shadow maps) is the real lever.

[VERIFIED] Mis-run corrected: the first T-066 A/B executed four times against the **unstaged**
`68D23E4E` binary (all four `benchmark-parameters.json` recorded the same old hash) and was
deleted; the reported numbers are from the corrected run where every run records `F49ED05B`.
Screenshot verification could not be captured (the game window would not come to the foreground),
which is moot after the revert.

[VERIFIED] Rebuilt without T-066: engine **`758F453EBC5C952FB58B2C24F643F976AED665373A599ECDA15BC7F799919384`**
(`-NoLtcg`, 936 s), staged into `game/engine-test` and `game/shockwave-engine`, `current-engine.patch`
regenerated and `git apply -R --check` exits 0. Smoke run on the new binary (performance profile,
1,000 tanks): 7.39 ms = 135.3 FPS, p95 10.30 ms - inside the recent 6.4-7.7 ms band.

[VERIFIED] Consolidated analytics regenerated at `artifacts/2026-11-16-final-analytics/` (ms + FPS
for every variant), including the shipping row.

Verification: `python tools/check_docs.py` exited 0 (81 Markdown files, 356 links, 69 tasks, 22
issues). New tool: `tools/analyze-ab.py`.

## 2026-11-17 - T-068 allocator/string lock share measured (EXP-022), no change

[VERIFIED] Instrumented the two locks the audit flagged: the object-pool critical section
(`ObjectPoolClass::ObjectPoolCS`, 2 sites in `mempool.h`) and the `AsciiString` critical section
(3 sites in `AsciiString.cpp`). New `Core/Libraries/Source/WWVegas/WWLib/ZhLockStats.h` holds the
counters and a scoped QPC timer (constructed before the lock guard, so it times enter + body +
leave); `DX8Wrapper::End_Scene` writes a cumulative row every 30 frames to `ZH_LOCK_LOG`. Inert
without the env var.

[VERIFIED] The timer itself costs a QPC pair, so the engine measures that in-process (0.0456 us)
and the analyser subtracts `calls x pair`. Result on the stock 1,000-tank scene (engine
`D337B939...33D5`, performance profile, frames 30-5340, 36,079.9 ms, 147.2 FPS):

- object pool CS: 19.3 calls/frame, 14.0 ms measured - 4.7 ms overhead = **9.4 ms = 0.03%**
- AsciiString CS: 1,587.1 calls/frame, 740.6 ms measured - 384.3 ms overhead = **356.3 ms = 0.99%**
- combined **1.01%** of elapsed, ~69 us per 6.8 ms frame.

[INFERRED] A lock-free pool would recover 0.03%; a lock-free string would recover at most ~1% in
exchange for rewriting a class used everywhere. **No change made.** The real signal is the
1,587 string lock acquisitions per frame: if string cost ever matters, cut copies, not the lock.

[VERIFIED] Two build defects found and fixed while doing this: (1) `ZhLockTimer t(f());` is a
most-vexing-parse function declaration - double parens added; (2) an edit had joined `class
ZhLockTimer` onto a comment line, producing C2447. Also found that the first successful link had
reused stale objects in TUs that instantiate the pool template, so a clean rebuild of
`build/engine-vs-community` was done before trusting the numbers; the earlier partial CSV is kept
but superseded. A third defect (row format string missing the new QPC specifier, so the column came
out empty) was fixed and re-built/re-run.

[VERIFIED] Engine `D337B93953705070C0F444CC415A2E48F93B810C13D2C6C08053B8619E3333D5` staged into both
game copies; `current-engine.patch` regenerated **including the new header** (`git add -N`), 120,593
bytes, `git apply -R --check` exits 0.

Verification: `python tools/check_docs.py` exited 0 (82 Markdown files, 360 links, 69 tasks, 22
issues) after this entry; tooling added: `tools/analyze-lock-log.py`.

## 2026-11-17 - ISSUE-0023 fixed: DrawDistance hides units; fresh demo numbers

[VERIFIED] User report: in the 1,000-unit scenes tanks disappear while panning the camera and come
back when the control bar is minimised. Diagnosed to the object-distance cull (`RTS3DScene::
Visibility_Check`, `W3DScene.cpp` ~469): it hides any render object farther than `DrawDistance` from
the **camera eye**, and T-064 had made it default-on at 400. EXP-002 had designed it as opt-in
precisely because it hides distant units.

[VERIFIED] Fixed: `OptionPreferences::getDrawDistance()` now returns **0 (off)** when the key is
absent (`return 0;  // OFF by default: this cull hides distant units (EXP-002), so it stays opt-in.`).
`docs/optimizations.md` ships `DrawDistance = 0` in the Performance preset and keeps 400 only in an
"Aggressive" preset for the stress harness. Issue: `docs/issues/ISSUE-0023-draw-distance-hides-units.md`;
task T-072; report `docs/experiments/EXP-023-draw-distance-default.md`.

[VERIFIED] Fresh demo on the fixed engine `912EC1EB...3965` (both copies staged; no `DrawDistance`
key present; 2 runs per cell):

- stock 1,000 tanks: retail-equivalent 22.54 ms (**44.4 FPS**), p95 24.78 ms (40.4) -> shipping
  9.28 ms (**107.7 FPS**), p95 10.95 ms (91.3). **2.43x median / 2.26x p95 in FPS.**
- ShockWave 1,000 x5 nuke cycles: retail-equivalent 8.43 ms (**118.6 FPS**), p95 79.25 ms (12.6) ->
  shipping 3.95 ms (**253.3 FPS**), p95 27.23 ms (36.7), p99 39.83 ms (25.1). **2.14x median /
  2.91x p95.**

[INFERRED] Turning the cull off costs nothing measurable in these scenes: the pre-fix demo (cull at
400) measured 9.23 ms stock / 4.50 ms nuke shipping, versus 9.28 / 3.95 now - inside session noise.
The 7.1 ms stock figure from earlier sessions came from a quieter machine, not from the cull, so it
is not used as the comparison.

[VERIFIED] Build note: the first relink failed with `LNK1201` (cannot write `generalszh.pdb`) with
~113 GB free and no stale link/cl processes; an immediate retry linked cleanly, i.e. a transient
file lock rather than a real build fault.

Verification: `python tools/check_docs.py` exits 0 (84 Markdown files, 370 links, 70 tasks, 23
issues); `current-engine.patch` regenerated, `git apply -R --check` = 0; `engine/README.md` hash
updated to `912EC1EB`.

## 2026-11-17 - ISSUE-0024 fixed: debris never drawn under the cosmetic skip (T-073)

[VERIFIED] User report: the wreckage thrown off units by nukes is never visible. Census showed the
objects exist (peak 4,957 `GenericDebris` in a 5-cycle run, all with drawables and flagged visible),
while `ZH_DEBRIS_LOG` (logged at the top of `W3DDebrisDraw::doDrawModule`) recorded **zero** calls.

[VERIFIED] Root cause: `PartitionManager::update` skips the whole dirty-module handling for
`GenericDebris`/`KINDOF_HULK` when `CosmeticPartition` is on, so those objects never get a
`CellAndObjectIntersection`. `PartitionData::getShroudedStatus()` treats `m_coiInUseCount == 0` as
"stuff off the map" and returns `OBJECTSHROUD_SHROUDED`; `GameClient::updateDrawables` then flags the
drawable fully obscured, so it never draws. Controlled evidence: skip on -> no log file at all; skip
off -> `draw AVScrap2/4 ...`, `draw NVBtMstr_D2/D3 ...`.

[VERIFIED] Fix (two parts): (a) the zero-COI branch of `getShroudedStatus()` reports
`OBJECTSHROUD_CLEAR` for cosmetic debris/hulks (they are cosmetic, so a fog leak is harmless);
(b) `getCosmeticPartitionEnabled()` now defaults to **FALSE**, because once debris render the skip no
longer pays: same-session 1,000 x5 nuke runs, skip off 3.78 ms / 264.2 FPS median, p95 32.87 ms /
30.4 FPS; skip on (with the fix) 4.08 ms / 244.8 FPS, p95 37.30 / 26.8. The earlier reported "big
tail win" of the skip (EXP-021: p95 49.7 -> 22.2 ms) was mostly the cost of *not drawing* debris.

[VERIFIED] Shipping configuration re-measured (engine `B8F73520...96F7`, both copies staged):
1,000 x5 nuke cycles median **4.13 ms = 241.9 FPS**, p95 **36.38 ms = 27.5 FPS**, p99 48.72 ms =
20.5 FPS (runs 4.21/4.05 ms). Stock numbers unchanged by this fix.

[VERIFIED] Heal/repair question answered with a no-nuke radiation session (300 units, 9 radiation
fields, heal pulse every 15 logic frames, 7 min, `ZH_ICON_LOG`): `healIcons` peaked at **272** and
was non-zero on 19,677 of 56,052 frames (35%), `healPulses` on 1,317 frames. The heal-icon path is
working; `bars` stayed 0, which is expected because health bars only show for selected/hovered units.

Verification: `python tools/check_docs.py` exits 0 (86 Markdown files, 378 links, 71 tasks, 24
issues); `current-engine.patch` regenerated, `git apply -R --check` = 0; `engine/README.md` hash
updated. Reports: `docs/issues/ISSUE-0024-cosmetic-skip-hides-debris.md`,
`docs/experiments/EXP-024-debris-visible.md`.

## 2026-11-17 - Workspace cleanup audit (T-074)

[VERIFIED] Python recursive logical-byte inventory measured 26,155,857,736 bytes (24.36 GiB),
30,077 files, no errors or skipped reparse directories. game/ 10.37 GiB, artifacts/ 6.84 GiB,
build/ 3.97 GiB; outer Git objects 1.51 MiB with no garbage. Existing uncommitted work preserved.
[VERIFIED] 46/83 pre-existing artifact directories lack manifests; 24 also lack literal mentions
in the bounded docs/tool search (4.76 GiB). Secondary build trees total 3.26 GiB. [INFERRED]
Together ~8.02 GiB merit review; no deletion safety or actual allocated-space savings claimed.
Filed nonblocking ISSUE-0025 (artifact provenance) and ISSUE-0026 (entrypoint state drift).
No game/reference/build/vendor content deleted or modified. Report:
`docs/research/2026-11-17-workspace-cleanup-audit.md`; evidence:
`artifacts/2026-11-17-cleanup-audit/{inventory,details}.json`.
Verification: `python tools/check_docs.py` exited 0: 89 Markdown files, 384 relative links,
72 tasks, 9 ADRs, 26 issues; `OK: documentation system is consistent`.

[VERIFIED] ISSUE-0027: initial Git staging failed because .git is sandbox-read-only. Approved
retry committed only the new audit report as `c62c590`; existing work remained uncommitted.
Final `python tools/check_docs.py`: exit 0, 90 Markdown files, 386 links, 72 tasks, 27 issues.

## 2026-11-17 - Authorized disk cleanup (T-075)

[VERIFIED] User authorized cleanup after T-074. Removed 3,260 explicitly planned files:
4,182,192,881 bytes of numbered PNG frames, 3,326,445,592 bytes of generated secondary-build
products, 7,508,638,473 total (6.99 GiB). Preserved 16 full-resolution frames per sequence,
all-frame contact sheets, all non-sequence evidence and build executables/PDBs/config/dependencies.
Workspace now ~17.38 GiB; observed free space rose ~7.00 GiB. Game copies, original references,
vendor, current build and historical executable snapshots excluded. Added cleanup manifests for
24 reviewed runs; original provenance remains unknown, ISSUE-0025 stays Open. ISSUE-0028 records
and fixes a preflight directory type check: first attempt stopped before deletion; retry exited 0.
[VERIFIED] `python artifacts/2026-11-17-cleanup-execution/verify.py` exited 0: every planned removed
path absent, 396 retained SHA-256 checks match, 16,477 protected file metadata records unchanged.
Report: `docs/research/2026-11-17-cleanup-results.md`; exact paths, hashes, bytes and commands in
`artifacts/2026-11-17-cleanup-execution/manifest.md` and its plan/result/verification JSON.
Verification: `python tools/check_docs.py` exited 0: 92 Markdown files, 392 relative links,
73 tasks, 9 ADRs, 28 issues; documentation system is consistent.

## 2026-11-17 - T-076 removed the dead opt-ins; T-077 in-game hover help

[VERIFIED] Removed `CosmeticPartition` entirely: the skip branch in `PartitionManager::update`, its
`ZH_COSMETIC_PARTITION` read, the zero-COI shroud exception (partition code back to stock), the
`Options.ini` key, `OptionPreferences::getCosmeticPartitionEnabled` + declaration, and the tool
flags/params in `benchmark-shockwave-attrib.ps1`, `benchmark-entity-heavy.ps1`, `launch-game.ps1`,
`demo-1000.ps1`, `demo-live.ps1`, `demo-shockwave-army-nuke.ps1`, `demo-shockwave-nukes.ps1`,
`play-shockwave-performance.ps1`; `tools/ab-cosmetic-partition.ps1` deleted.

[VERIFIED] Removed the rejected T-053 deferred-debris queue: `zhMaybeDefer`, `zhFlushDeferredDebris`,
the queue struct/statics/`zhDeferInit`, both call sites in `ObjectCreationList.cpp`, the flush call in
`GameLogic::update`, and `<deque>`.

[VERIFIED] `ZH_COSMETIC_PARTITION` and `ZH_DEBRIS_DEFER` are absent from engine `059B5E7Aâ€¦DC0F`
(byte search) and from all sources/tools; the binary shrank 6,770,176 â†’ 6,768,640 bytes. Both copies
staged; smoke run (300 units, performance profile) 6.89 ms = **145.2 FPS**; patch regenerated and
`git apply -R --check` = 0.

[VERIFIED] T-077 in-game help: `OptionsMenuInit` now sets tooltips (they are code-driven â€” the `.wnd`
TOOLTIP field is only "Need tooltip translation" in `GameWindowManagerScript.cpp`) on
`ComboBoxAntiAliasing`, `ComboBoxDetail`, `CheckUnlockFPS`, `ParticleCapSlider`, `CheckHeatEffects`
and `CheckCloudShadows`, explaining what each costs. Verified the UTF-16 strings are present in the
staged binary. `docs/optimizations.md` documents the in-game section; `DrawDistance` and
`ShadowScreenRadius` remain file-only because no layout control exists for them (adding one needs a
modified `OptionsMenu.wnd`, which lives in packed game data).

## 2026-11-17 - Independent optimization and release-readiness inspection (T-078)

[VERIFIED] Inspected selected current source/patch paths, tooling and retained benchmarks. Built
and staged executables all hash ACADF232F6AC11154ECA505BB860EF2C6A2C1C3C45E7827363FB6EA63580126D;
read-only cumulative-patch reverse-check exits 0. Independently reanalysed six destruction runs:
mean of per-run destroy maxima 92.906 -> 8.152 ms. Six raw profile runs reproduce medians
21.864 -> 6.471 ms (3.38x), which compares AA8/High against AA0/Low on one rebuilt binary.
[VERIFIED] Windows CRT confirms DebrisBroadphase=yes parses false. Mock invocation of the actual
launcher proves TestEnv/FPS variables leak into its caller; no game process executed. Recorded
ISSUE-0029 through ISSUE-0034 for disabled-counter lifecycle, boolean parsing, FPS latch, staging
destination, environment isolation and inherited destroy-overflow boundary. ISSUE-0035 records
an initial PowerShell AuthorizationManager rejection; process-local retry exits 0, no machine
policy change. ISSUE-0036 records a pre-existing non-UTF-8 checkpoint; ASCII byte append succeeded.
[INFERRED] Useful measured singleplayer prototype; not ready for universal distribution. EXP-011
already records simulation divergence and confines broadphase to singleplayer. Save/load,
multiplayer CRC and additional mod/hardware testing remain unverified. No engine, game copy,
original installation, pristine baseline or user configuration was changed. Report:
`docs/research/2026-11-17-optimization-engineering-review.md`; commands/results/scripts:
`artifacts/2026-11-17-engineering-review/manifest.md`. Pre-existing working changes preserved.

[VERIFIED] Final checks: `python tools/check_docs.py` exits 0 (101 Markdown files, 415 links, 76 tasks, 9 ADRs, 36 issues). `python tools/check_docs.py --self-test` exits 0: clean fixture, broken link, stale state date, dangling task and duplicate issue tests all pass. Review and eight new issue reports committed as `73827a4`; existing mixed documentation/source changes were not included. An optional CIM process inventory was denied by the environment; ordinary Get-Process confirmed no remaining Python verification process after the self-test completed.

## 2026-11-17 - T-079 resolve engineering inspection findings

[VERIFIED] User explicitly requested a goal to finish the T-078 findings and emphasized validating
problems before extra work. ADR-0010 restores the unproven disabled scan instead of adding counter
lifecycle machinery. Removed fixed 256-module collection; validated boolean parsing; replaced FPS
runtime veto with mutable startup initialization; complete ZH_ environment isolation; shared path
safety rejects protected/outside/overlap/reparse/hardlink/Windows-alias destinations before mutation.
Existing baseline recreation is refused even with Force. Simulation-changing broadphase/filter/
budgets require explicit experimental singleplayer and are blocked by current network/replay mode.
[VERIFIED] Full engine built successfully outside sandbox with one MSBuild node after the owned
sandbox-stalled tree was inspected/stopped (ISSUE-0038). Engine A0407A85...4609 staged in engine-test
and shockwave-engine; prior ACADF232...126D preserved. Cumulative patch clean-index apply produces
exact current source, including new policy header. Compiled actual-source regressions pass parser,
FPS and mode policies plus 140 randomized scheduler cases through 1024 modules. 51 PowerShell
assertions pass for real safety entrypoints and mocked process success/failure environment cleanup.
[VERIFIED] Real stock 300-unit 12-second smoke checks: capped 33.34 ms median, uncapped 9.50 ms;
these verify startup/limiting, not an optimization ratio. Baseline VerifyOnly matches all 1914 files;
original/pristine executable hashes unchanged in safety tests. ISSUE-0037 harness refinements,
ISSUE-0038 build stall and ISSUE-0039 default-root binding failure all resolved with recorded reruns.
No source installation/baseline writes, registry edits or dependency downloads. Test fixtures removed.
[UNKNOWN] Broader mod, replay/save and multiplayer interoperability are not certified; T-025 remains
blocked. Local safety remediation does not create a universal installer. Report and verification:
`docs/research/2026-11-17-optimization-remediation.md`, `artifacts/2026-11-17-t079-remediation/manifest.md`.

[VERIFIED] Final `python tools/check_docs.py`: exit 0, 106 Markdown files, 438 links, 77 tasks, 10 ADRs, 39 issues. All 12 changed PowerShell scripts parse. The unchanged docs validator self-test was not repeated; it passed in T-078. Current evidence and implementation are ready for the T-079 commit.

## 2026-11-17 - T-079 final default-entrypoint correction

[VERIFIED] Final default-argument dry runs exposed ISSUE-0039's same early PSScriptRoot binding
pattern in launcher/performance entrypoints, beyond the baseline verifier. Deferred script-relative
parameter defaults into the initialized body across the nine affected entrypoints touched by T-079.
Default launch-game.ps1 -DryRun and play-shockwave-performance.ps1 -DryRun now exit 0; logs retained.
All 12 changed PowerShell scripts parse; final 51-assertion safety suite exits 0. No extra engine
change, build, game launch, wrapper write or registry change was required. ISSUE-0039 Fixed again
with the expanded evidence. Main remediation committed as 4682881; follow-up records this final
script-only correction.

## 2026-11-17 - T-022 / T-035 persistent goal, workload and renderer prototypes

[VERIFIED] User explicitly requested both tasks and a persistent /goal until finished. Goal active; both tasks In Progress. Built deterministic explicit-singleplayer movement workload, peer-search counters, command/spawn logs, request/route/expansion fingerprints and whole-update QPC attribution. Six 150-second runs: 738,098 requests with matching common-frame trace prefixes. maxOpen median 8 / p95 about 86 / max 275; all recorded requests retail-compatible. Whole-update PF share about 15.6% in two exploratory follow-ups; zero-unit control has zero requests. No algorithm change or gain claimed. EXP-025, ADR-0011.

[VERIFIED] Opt-in global light-depth target, orthographic projection, shader comparison and terrain/mesh receiver passes build and run through the pinned wrapper. System D3D8 rejects R32F and falls back. First map prototype regresses median35.20ms vs stencil14.47ms in diagnostic runs. V2 state caching caused a black world; V3 fixes the constant-cache/state-block mismatch, with normal colors captured. V3 diagnostic median27.54ms / p9534.05; no performance acceptance. Depth export, mask/coverage, batching and reset work remains. EXP-026; failures recorded as ISSUE-0040 through ISSUE-0052.

[VERIFIED] Build-8 exit0; engine 68D68B11146D74353231959D00967766B8EF7DA56EB137AAB1EE492CD089B01D, staged only in engine-test. Original options hashes restored after permitted probes; temporary wrapper removed. User requested heads-up before each launch and then closed heavy apps for later visual checks; recorded in continuity/state. Initial baseline timing overlaps compilation and user load, so it is exploratory; exact trace/queue results remain useful.

[VERIFIED] Source patch reverse-check and clean-index apply-check exit0, including new headers/includes. Both benchmark scripts parse. VerifyOnly reports all 1,914 baseline files match. Evidence and hashes catalogued in artifacts/2026-11-17-pathfinding and artifacts/2026-11-17-shadow-map. Documentation consistency check follows this entry.

[VERIFIED] Final `python tools/check_docs.py` exits 0 (122 Markdown files, 459 links, 77 tasks, 11 ADRs, 52 issues). Both new benchmark scripts parse. Baseline VerifyOnly exits 0: 1,914 files match. Original options restore hash F756DE96...86B5C verified; all timed game runs ended and the temporary wrapper slot is empty. No task marked Done, no performance gain claimed; persistent goal remains active. Log prefix verified against HEAD with Git newline normalization.

## 2026-11-17 - T-022 native heap acceptance; T-035 depth diagnostics

[VERIFIED] Corrected blocker lifecycle/navigation registration (ISSUE-0055); all200 adjusted starts pass movement checks, the40-unit opening is passable and building centers are blocked. Six corrected30s captures reproduce common request/command prefixes; these historical1280x720 captures provide queue/correctness evidence. Original EXP025 blocker workload was incomplete and is superseded for congestion analysis. Stable heap replay then justified an explicitly gated in-engine prototype, preserving costs/caps/ties/seed/cleanup order and pool layouts. EXP027/ADR0012 document the decision.

[VERIFIED] Native1920x1080 congested comparisons, three20s Heap-then-List pairs on measured engine6A609442...9220C, operation logger off: matching frames90..855,4951requests and9sampled game CRCs per run. All paths/expansion/commands/work/CRC match. Aggregate pathfinding time12.9% lower and whole-update9.5% lower. No-blocker comparison is PF4.1% slower/update essentially unchanged. Retain only as explicit experimental singleplayer (-ExperimentalSingleplayer -PathfindingQueue Heap); normal List default; network/replay/shell excluded. Same-order pairs and narrow workload limit generalization. T022 complete within this scope; no universal FPS or compatibility claim.

[VERIFIED] Actual extracted-method regression suite passes10queuecases/13modeguards, including ties/reinsertions/sortedcleanup and5000-cell boundary. Mocked launcher suite passes62assertions with separate output directory; no game launches. Initial sandbox junction failure filed ISSUE0057, resolved by permitted rerun; original51assertionT079receipt preserved. Partial queue trace tail recovery ISSUE0053 and isolated test-build correction ISSUE0056 documented.

[VERIFIED] T035 working depth BMP export resolves ISSUE0048. Visible depth contains tank grid; earlier hidden-camera missing-grid inference unsupported. New native1920x1080 delta/mask/color/stencil45s probes finish after individual heads-ups; main_viewport1920,1080 logged. Bias004 removes broad terrain bands but coverage/self-shadow relation not accepted. Source engine913AAEF061B72490996BDB42CD14DFD8B5CDC95FB084B272406CC3F1644935E4 builds exit0 and is staged onlyengine-test. All temporary options restored to SHA256F756DE96...86B5C, wrapper removed. Stencil remains default. T035 stays In Progress under the existing persistent goal; correction, batching, reset and performance validation remain.

[VERIFIED] All future tests use native1920x1080 at user's direction. Benchmarks accept Width/Height, default1920/1080 and record them. Source cumulative patch reverse/clean-index apply checks pass; artifact manifests and SHA inventories retained under queue-replay/shadow-depth. Final baseline and documentation checks follow below. Existing unrelated workspace changes preserved.

[VERIFIED] Final baseline VerifyOnly exits0:1914/1914files. Final documentation validator exits0:129Markdownfiles,468links,77tasks,12ADRs,57issues. No game process remains and engine-test wrapper slot is empty. Prior log prefix is unchanged under Git newline normalization.

## 2026-11-17 - T-035 bounded GPU projection batches and verified cache reuse

[VERIFIED] Previous goal turn was progress: T022 acceptance and native-resolution policy committed467c17b. This turn replaces10,371depth material installs with seven bounded geometry draws for9,329rigid meshes/248,043triangles. Explicit VS1.1 main/light projection, cached worldvertices and ordered regions preserve selected LOD/current caster policy. No simulation changes. ADR0013 records the architecture.

[VERIFIED] Native phase diagnosis after300records: CPU-projected batches21.59ms total/13.49collection; GPU projection+world cache13.03/9.39ms; ordered region cache native-region-mask8.206/3.220ms. Last run includes mask output and one camera zoom, and coverage is incomplete: no accepted fixed-scene stencil or overall FPS gain claimed. Colored opaque receiver gaps mostly clear with receiver-only raster ZBias1, separate from light-comparison bias. Physical placement/self-shadow and material coverage remain open ISSUE0054/0058; performance ISSUE0050 stays Investigating.

[VERIFIED] Shared model arrays are mutable; fixed in-place cache staleness with a byte-exact model snapshot/revision once per frame (ISSUE0059Fixed). `python tools/test-shadow-batches.py` exits0,17actual-source collector/cache cases: movement/reorder/hide, source/model/topology edits including unchanged pointers, LOD/attachments/exclusions,60000vertex bounds, invalid-index/deep hierarchy fallback, cache clear/rebuild. Tests do not certify full renderer output.

[VERIFIED] Four announced native1920x1080 probes complete and restore Options.ini SHA256F756DE96...86B5C; temporary wrapper removed. Main viewport1920,1080 logged; before/after zoom screenshots captured. Final build-region-raster.log exit0, engine376EDCF3585F245753E513987200497B3DB01B0A5F086E078BCDF61F16E71903 onlyengine-test staged. Benchmark exposes submission mode, map size and receiver raster bias independently.

[VERIFIED] Cumulative source patch reverse and clean-index apply checks exit0, including ignored vendor newfiles. Baseline VerifyOnly exits0, all1914files match. Native game process ended and wrapper slot empty. T035remains In Progress under the active full goal; next decisive evidence is isolated physical caster/receiver calibration, then complete material/reset checks and native full-coverage paired timing. Unrelated user workspace changes preserved. Final docs validation follows.

[VERIFIED] Final `python tools/check_docs.py` exits0:132Markdownfiles,471links,77tasks,13ADRs,59issues. Baseline and source-patch checks above pass. Persistent goal remains active; T035not complete.

## 2026-11-17 - T-035 analytic calibration, depth sampling and homogeneous receiver core

[VERIFIED] Previous turn was progress (b5a4ece batching/cache checkpoint). This turn adds an isolated box/plane GPU fixture and independent camera/light ray reference (EXP028). Orthographic/diagonal/map-light geometry and perspective diagonal fullscreen cases have zero stable mismatches. Actual INTZ main-depth sample values agree within A8readback quantization. Fullscreen helper is calibrated only; real scene depth is not connected yet. ADR0014chooses that integration next, preserving full objective.

[VERIFIED] Failures recorded immediately as ISSUE0060..0065. Fixture pending-view restore and color-only target capture/export corrected; translated shader diagnostics build/API corrected. A-1.04645coefficient exceeded PS1.x constant limits, producing all-lit fullscreen lookup. Uniform homogeneous normalization fixes it (0/1,005,664stable mismatches; all constants valid). Earlier assumed64/128diagnostic gains were invalid and are replaced with legal instruction scaling. No prior numerical delta interpretation is retained.

[VERIFIED] Angled camera/map light reveals real grazing acne (1,517stable mismatches) on both geometry/fullscreen receiver paths. Capability-probed INTZ light depth with actual hardware slope bias reduces this to37/1,012,711at slope1 (0.00365%, below unchanged0.1%tolerance), with zero false roof-core shadows and ground shadow retained. Slope1.5gives34; residual/real-scene quality still pending ISSUE0065. Source preserves legacy and translated bias state, unbinds sampled depth, and separates calibration receiver depth from light depth.

[VERIFIED] Every announced test uses main viewport1920x1080;1024x1024is the offscreen shadow target. Twelve calibration runs restore exact original options. Final native system D3D8 INTZ probe rejects target8876086c and normal frames continue; W3DShadow.cpp routes false to existing volume rendering. Temporary wrapper removed and original options hashF756DE96...86B5Crestored. Immutable install/baseline untouched.

[VERIFIED] Final build-intz-shadow.log exits0; engine5A9DAE8CE9FC2A4D1B5F5C0CD67D317501BC32872B3DC39DC72CE6364FF4E0B5 staged onlyengine-test and preserved in artifacts. Actual collector source SHA matches the passing17-case receipt. Cumulative patch reverse/clean-index checks pass, including ignored vendor headers/includes. No real-scene fullscreen coverage, reset/map certificate or accepted renderer/FPS gain claimed. T035remains In Progress under active full goal; next integrate actual main depth at correct clear/render lifecycle, validate all coverage/state/quality, then native full-coverage stencil A/B. Baseline/docs final checks follow.

## 2026-11-17 - T-035 shadow-map renderer rejected; T-022 accepted; harness scene issue

[VERIFIED] T-035 decided on measured evidence and closed as rejected (EXP-029, ADR-0015). Retained dense scene: stencil 14.47 ms median/p95 19.56 over 3,480 frames vs shadow map 27.54 ms/p95 34.04 over 1,680 frames with 1,023 casters (1.90x). Three controlled alternating pairs at 1920x1080 with the wrapper in both arms: 7.90/7.84/7.81 ms stencil vs 11.16/11.57/11.36 ms shadow map, mean ratio 1.4477. Native system D3D8 rejects R32F and INTZ (8876086c), so the path is wrapper-only. The experimental renderer source was removed from the engine and preserved in artifacts/2026-11-17-t035-rejected/; stencil volumes remain the only shadow path and no rendering default changed.

[VERIFIED] T-022 remains complete (EXP-027/ADR-0012): six corrected baseline captures, three native congested Heap/List pairs (pathfinding 0.8710, whole update 0.9048, identical paths/expansions/CRC), List default and Heap only by explicit experimental singleplayer. tools/test-pathfinding-heap.py passes 10 queue cases and 13 guards.

[VERIFIED] Measurement attempts exposed ISSUE-0066: the 1,000-unit stress grid logs created=1000 but the units do not draw in this environment, so the new controlled pairs measured a sparse tree scene rather than the tank grid. Passable placement, spawn delay, camera pin and benchmark -Screenshot/-Map options were added; the engine builds and runs with them, but the units still do not appear, so the issue stays Investigating and the dense evidence above relies on earlier retained captures.

[VERIFIED] Rebuilt engine CFE0AEAA31579E31ED782AEBF1D127AF7C8382FCF49A2DE8FF9158F62F8C760F is stencil-only plus test harness options, staged in game/engine-test. Two 15 s probes completed and wrote frame logs. tools/test-optimization-fixes.ps1 passes 62 assertions; python tools/check_docs.py exits 0 (143 files, 501 links, 77 tasks, 15 ADRs, 66 issues); the cumulative patch reproduces the working tree from a clean vendor index.

## 2026-11-17 - ISSUE-0066 diagnostic; T-035 reopened

[VERIFIED] Added post-spawn diagnostics (`-Diagnose`) reporting live object, drawable and render-object state. At frame 120 the 1,000-unit scene reports alive=1000 destroyed=0 drawables=1000 modules=1 renderobj=1 radius=32.4 visible=256; a 3-unit `-SpawnAtCamera` run reports alive=3 drawables=3 modules=1 renderobj=1 visible=3 with the sample 24 units from the camera pivot. No vehicle appears in any captured frame.

[VERIFIED] Ruled out as causes: placement (spawned at the camera), template (AmericaTankHumvee identical), shroud (`ZH_STRESS_NOSHROUD` sets m_shroudOn false, no change), and a T-022/T-079 regression (preserved pre-T-022 engine ABAD3E88 shows the same empty scene with ZH_STRESS=3 on northamerica and Defcon6).

[VERIFIED] T-035 was reopened: the provisional rejection rests on a non-alternating dense capture plus three controlled pairs that measured a sparse tree scene. BOARD and state.json now say In Progress, EXP-029 is marked provisional, and the archived renderer stays in artifacts/2026-11-17-t035-rejected/ for a dense alternating rerun. Stencil remains the shipped default.

[VERIFIED] New test-only switches: -Passable, -SpawnDelayFrames, -SpawnAtCamera, -NoShroud, -Diagnose, -Template, -Map. Engine EC18C7E7...FBCF is staged in engine-test (diagnostic build). python tools/check_docs.py passes; no gameplay or rendering default changed.

## 2026-11-17 - T-035 dense alternating A/B confirms rejection; ISSUE-0066 fixed

[VERIFIED] ISSUE-0066 root cause was capture timing, not rendering: the comparison camera was pinned for 240 frames but screenshots were taken 8-13 s into the run, after the game returned the view to its start area. A configurable pin (`ZH_STRESS_PIN_FRAMES`, benchmark `-PinFrames`) fixes it; `-PinFrames 100000` captures the full 1,000-Crusader grid (artifacts/2026-11-17-t035-dense/A-0-probe/scene.png, 47 FPS).

[VERIFIED] With the archived renderer rebuilt (engine 87FC112D...CCAF), three alternating Stencil/ShadowMap pairs at 1920x1080, 20 s, 1,000 tanks, passable placement, pinned camera and d3d8to9 in both arms measure 20.06/19.91/20.27 ms stencil vs 22.25/23.23/23.27 ms shadow map: ratios 1.1093, 1.1669, 1.1481, mean 1.1415x slower. A-3/B-3 screenshots show the same army at 51 vs 43 FPS. Rejection confirmed on clean dense evidence.

[VERIFIED] The renderer was removed again from the shipped engine and preserved in artifacts/2026-11-17-t035-rejected/. Final stencil-only engine AC32117197A0168F23C1F0A511D21EB606F09CD7AF389FB60AF92D3D90E02771 is staged in engine-test; retail backup F37A4929...495B intact. current-engine.patch reproduces from a clean index with zero shadow-map references.

[VERIFIED] Checks: tools/test-pathfinding-heap.py 10 queue + 13 guard cases; python tools/check_docs.py OK (143 files, 501 links, 77 tasks, 15 ADRs, 66 issues). T-022 and T-035 are both closed in BOARD/state.

## 2026-11-17 - Stable pathfinding heap enabled by default in singleplayer

[VERIFIED] heapAllowed() no longer requires the experimental-singleplayer token: inside a singleplayer game it defaults to the stable heap, network games and replays still force List through allowed(), and ZH_PF_HEAP=0 (or an invalid token) restores List. The request log now records the active queue as `# queue=heap|list`. ADR-0016 supersedes the opt-in part of ADR-0012.

[VERIFIED] In-game proof at 1920x1080 with no ZH_PF_HEAP set: `# queue=heap`; with ZH_PF_HEAP=0: `# queue=list` (artifacts/2026-11-17-heap-default). Compiled source tests: 10 queue cases and 12 mode guards pass, including multiplayer/replay fallback and invalid-token handling.

[VERIFIED] Engine 0C4C74CC71E4D36F5F13B830BF6FD900F778514E0168C72D91DC9E12A4477293 is staged in engine-test; retail backup F37A4929...495B intact. The pathfinding parity evidence (0.8710/0.9048, matching paths/CRC) is unchanged; no network or replay certification is claimed.

## 2026-11-17 - Independent review of T-022/T-035 completion

[VERIFIED] User requested review of the intervening completed work. Inspected HEAD7ce0636, source, launcher, archived records and screenshots without running the game. Independently recomputed all three dense ratios1.109337/1.166954/1.148120; the tested prototype rejection is supported. Actual-source heap tests pass10queue/12mode cases and current patch reverse-check passes.

[VERIFIED] Found launcher overriding the new heap default (mocked child flag0), incompatible new CSV queue annotation (actual new logs rejected), and benchmark defaulting to removed ShadowMap. Filed ISSUE0067..0069. Latest calibrated source only exists in ignored archive and required dense/rejected manifests are absent; filed ISSUE0071/0072. Canonical stale hash/default checkpoint corrected under ISSUE0070; actual staged/built hash0C4C74CC...7293. No gameplay fixes or real launches during review. ADR0014fullscreen main-depth path remains unbuilt; prototype rejection is not delivery of a faster renderer. Review report and independent receipts retained; source fixes remain outstanding. Final documentation checks follow.

[VERIFIED] Review final checks: separate clean-index patch applicability exits0; source reverse-check0; pristine baseline1,914/1,914. Documentation checker exits0:151Markdownfiles,515links,77tasks,16ADRs,72issues. An initial issue metadata multi-task format was corrected before final validation. No game launched; only review documentation and stale canonical identity corrected.

## 2026-11-18 - T-022/T-035 review findings resolved

[VERIFIED] Fixed launcher Auto/default/explicit queue integration, shared strict CSV metadata parsing and removed-shadow benchmark preflight. Tracked rejected calibrated source with pinned base and verified isolated reconstruction. Added retrospective dense/rejected manifests and inventories, preserving unknown historical parameters. Corrected EXP-029 frame-count claim. Closed ISSUE-0067/0068/0069/0071/0072; ISSUE-0070 already fixed. New test failure ISSUE-0073 (automatic args variable) fixed with retained failure receipt and passing rerun.

[VERIFIED] Mocked tools/test-optimization-fixes.ps1 passes 93 assertions; test-pathfinding-csv.py passes 18 checks; test-shadow-batches.py passes 17 actual-source cases; verify-rejected-shadow-source.py reconstructs 30 affected files. Both pathfinding entrypoints read retained annotated logs; List/Default parity matches 8,816 requests and 15 CRC samples per arm through logic frame 1411. Dense shadow reanalysis exits 0, rejection unchanged. Baseline VerifyOnly matches 1,914 files. Vendor reverse patch check exits 0. Built/staged hashes remain 0C4C74CC71E4D36F5F13B830BF6FD900F778514E0168C72D91DC9E12A4477293. No game launched or engine rebuilt; no new speedup claimed. Report: docs/research/2026-11-18-review-fixes.md. Evidence: artifacts/2026-11-18-review-fixes/manifest.md. Old goal not resumed; fullscreen ADR-0014 remains unbuilt. Final docs validator result follows.

[VERIFIED] Retained artifact inventories match all recorded byte sizes/SHA256 (63 dense and 3 rejected records). Archived source/patch files disable Git text normalization to preserve pinned bytes. Closeout helper initially failed reading UTF-8 via implicit Windows cp1252; ISSUE-0074 records the failure and explicit UTF-8 correction, verified by successful closeout writes.

[VERIFIED] Final `python tools/check_docs.py` exits 0: 154 Markdown files, 521 relative links, 77 tasks, 16 ADRs and 74 issues.

## 2026-11-18 - T-080 alpha candidate verified; T-081 added before finalization

[VERIFIED] User authorized a new ongoing goal for the first reversible alpha patcher. Rust CLI Install/Verify/Uninstall/Recover/Inspect/Play implemented with exact stock/ShockWave catalogs, verified backups, exclusive lock, atomic writes, conflict preservation and interruption recovery. Candidate 2 engine 8BFF29D77947DD0AF92A131C020391115F9C1A71AEF75615B3EC3B4D5D9CD467 is an isolated non-profile alpha build: 94 diagnostic getenv reads disabled and synthetic pathfinding entrypoints replaced with no-ops. Active development engine/source remain unchanged. Source preparation reproduces the compiled tree; Rust source package rebuilds offline. Full-copy round trips restore all 1,914 stock and 288 ShockWave files/names, including after runtime smoke tests. Both copies reached main menu and skirmish setup at verified physical 1920x1080 borderless; no match started, global options SHA unchanged. Candidate/receipts: artifacts/2026-11-18-patcher-alpha/. Issues 0075..0082 documented and fixed. Final debug suite: 22 tests, 1 production-only skip; production suite: 22 tests, 3 debug-only skips.

[VERIFIED] Before finalization user requested a mandatory guard-range fix (no toggle), primarily stock units and long-range units, skipping unnecessary changes. T-081 and ISSUE-0083 record the work. Guard UI and target scan both use adjusted vision rather than weapon range. Stock archive audit exposed a zero-length PatchZH marker rejected by the reader (ISSUE-0084); audit/fix work continues. T-080 and the goal remain active; candidate 2 is not the final deliverable.

## 2026-11-18 - T-081 guard range fixed; T-080 alpha candidate 4 packaged

[VERIFIED] `AIGuardMachine::getStdGuardRange` now returns `max(adjusted legacy vision, largest eligible automatic weapon range)` for a human player in singleplayer, with the same resolver used by the guard target scan and the `RadiusDecal` UI preview. AI/network/replay/enter-guard keep the legacy path; no toggle. The separate tracked patch `engine/patches/guard-range.patch` is applied only by `tools/prepare-alpha-engine.py`. Stock census: 25 archives, 149 first-match INIs, 2,103 object definitions, 354 guard variants, 47 base-floor candidates and 236 variants needing no change.

[VERIFIED] Native 1920x1080 borderless alternating evidence at `barrenbadlands` with a real human slot and distinct AI opponent: control-4 (legacy, engine `90C208FA...6574`) reported Tomahawk/Scud/Nuke guard 324, weapon range 347.5, target distance 335.75, `can_attack=3`, `within_weapon_range=1`, and fired zero times. Fixed-1 (engine `1CEFD1F4...B766`) reported guard 347.5 and fired at frames 486/843/1260; target health fell 800 -> 650/500/400. Crusader stayed 270/270 and fired in both runs. EXP-030 and artifacts/2026-11-18-guard-range record the method and raw rows.

[VERIFIED] The control crash was diagnosed from the retained minidump: access violation at `0x7BE4A`, resolved to `W3DModelDraw::handleWeaponFireFX`; `m_weaponRecoilInfoVec[wslot]` was empty when recoil/muzzle-flash data was written. `engine/patches/model-fire-fx-recoil.patch` fixes the off-by-one clamp and rebuilds recoil storage before indexing. ISSUE-0086 is fixed via ISSUE-0087; the fixture controller issue ISSUE-0085 is fixed by the real skirmish human/AI setup. Fixed-1 completes 1,500 frames while firing all four units.

[VERIFIED] Production alpha source `build/alpha-engine-source-final` applies both feature patches and disables 94 diagnostic reads (only `ZH_PF_HEAP` remains); the built engine is `4FD3B817F49F4EBAF87C4F30BB38AC8491BC9AED15AC208DDE3B742882702F42` with no fixture/`ZH_MAP`/diagnostic strings. `python tools/test-guard-range.py` passes 67 actual-source cases against that tree; `python tools/test-big-archive.py` passes 4 tests.

[VERIFIED] Final package `artifacts/2026-11-18-patcher-alpha/candidate-4/zh-patcher-0.1.0-alpha.1` (ZIP SHA256 `3243B4A3...BCB3`, engine `4FD3B817...2F42`) contains the patcher, corresponding source with both patches, notices and checksums. Production suite 24 tests/4 debug-only skips; debug suite 24 tests/1 production-only skip. Full-copy install/uninstall restores all 1,914 stock and 288 ShockWave original hashes. Native 1920x1080 borderless smokes reached the stock and ShockWave main menus; both games were closed and uninstalled, and every managed hash was restored. Corresponding-source offline rebuild exits 0.

[VERIFIED] T-080 and T-081 are Done; ADR-0018 records the guard decision. Remaining project blocker is ISSUE-0010 (no compatible late-game replay for T-025).

[VERIFIED] Final `python tools/check_docs.py` exits 0: 170 Markdown files, 542 relative links, 79 tasks, 18 ADRs and 87 issues.

## 2026-11-18 - T-082 community-style mod overlay delivered

[VERIFIED] Research recorded in `docs/research/2026-11-18-community-mod-installation.md`: GenLauncher keeps mods in `GLM/<mod>/<version>`, symlinks data into the game root, preserves displaced originals with `.GLR`, activates `.gib` as `.big`, excludes `.exe/.dll`, and cleans up after exit; ZHModLauncher uses `Mods/<mod>/*.zbig` and move/revert; the engine `-mod` switch loads one `.big` or a directory of `.big`, not general loose `Data/`. ADR-0019 chooses a transactional overlay rather than copying mods permanently.

[VERIFIED] Patcher additions: `.zhpatch-alpha/mods/<id>` library with hashed manifests; ordered `active.json`; read-only `mods inspect`; folder, single `.big`/`.gib`/`.zbig`, ZIP, 7z and attempted RAR import through the system `tar` with entry-list validation; zip traversal and installer refusal; `.gib`/`.zbig` -> `.big`; `.exe/.dll/.asi`/script skipping; link-first/copy-fallback activation; `mod-journal.json` with displaced-file backups; exact restore/recovery; `play` waits and restores; base install/uninstall refuses while an overlay is active. `patcher/README.md` and `patcher/Menu.ps1` document/use the commands; no third-party installer is executed.

[VERIFIED] Automated suite: debug 31 tests / 1 production-only skip; production 31 tests / 5 debug-only skips; both exit 0. New tests cover inspect-without-mutation, import, activation, verify, restore, remove, `.gib` mapping, `.big` collision, later-mod-wins switching, ZIP/7z/single-`.big`, path traversal, installer refusal, source-inside-game refusal, activation interruption at 3000/3001, restore interruption at 4001, base-uninstall refusal, and exact base hashes after every path. Full-copy stock/ShockWave tests restore all 1,914/288 hashes. The pre-T-082 checkpoint is tag `pre-t082-prototype` at `8f65119`.

[VERIFIED] Candidate 9 with `smoke-mod` (`ZZ_Smoke.big`, an exact copy of `WindowZH.big`) started at physical 1920x1080 borderless; the window was verified by `tools/measure-game-window.py`. Candidates 5-8 share the same overlay path; the candidate-5 screenshot shows the main menu. The packaged patcher logged `Mod overlay removed and original files restored` and `Game exited; mod overlay removed and base verified`. Stock and ShockWave snapshots compare 0/1,914 and 0/288 diffs after the test.

[VERIFIED] Candidate 9: ZIP SHA256 `BCF7C277...4E81`, patcher `C957B664...2A9E`, engine `4FD3B817...2F42`, corresponding source `E2DF9CC3...55FD`; package tests pass and the extracted source rebuild exits 0. Remaining limitations: no installer execution/download repository/dependency solver; RAR attempted but not fixture-tested; arbitrary mods, multiplayer, replays and long sessions remain uncertified.

[VERIFIED] Final `python tools/check_docs.py` exits 0: 173 Markdown files, 551 relative links, 80 tasks, 19 ADRs and 87 issues.

## 2026-11-18 - T-083 project folder rename blocked

[VERIFIED] Requested root name: `C&C generals optimization` (the requested trailing space was omitted for Windows compatibility). `Rename-Item` from the parent directory failed because another process is using the directory. No rename completed. Recorded ISSUE-0088 and marked T-083 Blocked; no processes terminated.

## 2026-11-18 - T-084 independent review of DeepSeekâ€™s alpha changes

[VERIFIED] Candidate 9 matches the package, patcher, engine and source ZIP hashes. Standalone checks passed 67 compiled guard cases and four BIG reader tests. Debug and production transaction suites each ran 31 cases and exited 0 after enabling link fixture creation (one and five skips respectively, ISSUE-0092). No native game session was run during this review.

[VERIFIED] Disposable candidate 9 fixtures reproduced original archive loss on rollback (ISSUE-0089), changed-base acceptance through direct activation (ISSUE-0090) and a lost read-only attribute (ISSUE-0091). T-082 acceptance is blocked. See the [T-084 review](research/2026-11-18-deepseek-engineering-review.md).

[VERIFIED] The current Git root has the requested directory name and the old path is absent. T-083 and ISSUE-0088 are closed based on that filesystem check.

## 2026-11-18 - T-085 overlay repair and retained command-prompt setup

[VERIFIED] Candidate 10 resolves Windows path aliases before backup, verifies the exact base before activation and during active-overlay Verify, preflights the full backup set, and preserves originalsâ€™ read-only attribute. ISSUE-0089â€“0091 are fixed. The packaged command launcher and menu match candidate 9 byte for byte. See the [repair report](research/2026-11-18-overlay-repair.md).

[VERIFIED] Debug and packaged production transaction suites each ran 37 cases and exited 0 with one and five skips respectively. The ZIP CRC and all package checksums passed. Fresh disposable stock and ShockWave copies restored all 1,914 and 288 original file hashes after install, case-alias overlay activation/restore and uninstall. The relocated journal refusal on the older stock copy is recorded in ISSUE-0093. Candidate 10 used the same engine and no native launch was conducted.

## 2026-11-18 - T-086 simplified console menu

[VERIFIED] Candidate 11 shows Install and Uninstall. Compatibility and managed-file checks run as part of the selected transaction. Both menu choices request automatic recovery under the patch lock. Advanced CLI remains available. The ASCII title fixes ISSUE-0094.

[VERIFIED] The PowerShell 5.1 harness checked both labels and ran Install and Uninstall on a disposable fixture. Debug and packaged production runs each executed 40 cases and exited 0 with one and six skips respectively. Package CRC, file hashes and source checks passed. [Candidate 11 manifest](../artifacts/2026-11-18-patcher-alpha/candidate-11/manifest.md).

## 2026-11-18 - T-087 and T-088 source launcher and compatible runtime

[VERIFIED] The source console uses the current package from state.json. Both Install and Uninstall worked in a Windows PowerShell 5.1 harness using a manual folder choice. A missing-package fixture printed a concise message before opening the picker. ISSUE-0095 is fixed. The untouched ShockWave reference remains protected. The prepared game/shockwave-patcher copy matches all 288 original hashes, passes Inspect and has no journal.

[VERIFIED] Candidate 13 admits a recognized engine with local mod data and journals the actual runtime inventory. Existing exact profiles remain available. Full-copy transactions restored all 1,914 cataloged stock hashes, 1,913 stock hashes with system Direct3D, 1,914 stock hashes with an extra data archive, 288 raw ShockWave hashes and 289 ShockWave hashes with an extra data archive. Debug and packaged production suites each ran 42 cases, with one and six skips respectively, and exited 0. Package checksums passed. The engine is unchanged and no native launch was conducted. [ADR-0020](decisions/ADR-0020-compatible-runtime-patcher-profile.md) and [candidate 13 receipts](../artifacts/2026-11-18-patcher-alpha/candidate-13/manifest.md).

## 2026-11-18 - T-077 packaged ShockWave settings check

[VERIFIED] Read the prepared OptionsMenu.cpp and installed OptionsMenu.wnd archive entries. Detail > Custom opens Advanced Display Options. Both layouts mark AA and Unlock FPS hidden despite the registered tooltips (ISSUE-0096). The local patched executable matches candidate 13 SHA-256. Running the engine CRC calculation on that executable produced 10D7D271, while the supplied screenshot shows 5D6C5FD1. The installed game files and options were unchanged.

## 2026-11-18 - T-089 independent skirmish speed and windowed capture

[VERIFIED] The old skirmish message forced its speed argument into the renderer. The tracked alpha feature patch now uses the simulation scheduler and keeps the separate render preference. Direct launches default to windowed presentation. The restricted build stalled in the known ISSUE-0080 pattern. Direct offline MSBuild with regeneration suppressed completed.

[VERIFIED] The actual source methods passed 24 compiled scheduling cases. Snipping Tool took foreground focus while the rebuilt ShockWave window remained visible and unminimized at 1920Ã—1080. Install/verify/uninstall restored all 288 original file hashes on the disposable copy. The production patcher suite ran 42 cases including six skips and exited 0. Package CRC and checksums passed. [Candidate 14](../artifacts/2026-11-18-patcher-alpha/candidate-14/manifest.md) Â· [T-089 receipts](../artifacts/2026-11-18-skirmish-speed/manifest.md).

## 2026-11-18 - T-090 console progress

[VERIFIED] Candidate 15 reports checking, backup, apply and restore stages as they start. Longer scans report file counts. The apply and restore bar counts verified paths. The packaged PowerShell 5.1 menu showed output in under one second on both actions and restored all 288 original ShockWave hashes. Debug and packaged production suites each collected 43 cases and exited 0 with one and six skips respectively. Package checksums passed. [Design notes](research/2026-11-18-console-progress-design.md) Â· [Verification](../artifacts/2026-11-18-patcher-alpha/candidate-15/manifest.md).

## 2026-11-18 - T-091 GitHub publication readiness

[VERIFIED] Reviewed clean master at `7c7460b` with no Git remote. `git rev-list --count master` returned 66. A filename check against `git log master --format= --name-only` found no executable, DLL, game archive, dump, replay or package extensions checked. A reachable Git object inventory found the largest blob was the 332,461-byte baseline hash manifest. `git check-ignore` matched both game installs, a test-copy executable, vendor source, a sample build output and a sample artifact ZIP. History inspection found local user-directory references and commit email metadata to review before making the history public. A limited pattern scan found no matching tokens or private key headers.

[VERIFIED] The root README describes P0 and omits the Rust patcher. This is another case of ISSUE-0026. The top level has no license or notices file. `patcher/Cargo.toml` declares GPL-3.0-only and the package script prepares separate engine terms and corresponding source. This review did not inspect the contents of a release archive or rebuild the package.

[SOURCED] EA released the engine source under GPLv3 with additional terms. Preserve the pinned upstream notices, mark the modifications, and use the EA non-endorsement statement in the public README. See the [EA engine source release](https://github.com/electronicarts/CnC_Generals_Zero_Hour) and [EA modding guidelines](https://www.ea.com/games/command-and-conquer/news/modding-faq).

[VERIFIED] `python tools/check_docs.py` passed for the reviewed commit. Publication was not requested and no GitHub remote or release was created.

## 2026-11-18 - T-092 engine optimization project scope

[VERIFIED] `git ls-files '*.rs' '*.patch'` and the patcher manifest distinguish the installer and guard fixture from the C++ engine patches. Updated the root README and current scope documents. The README describes the tested singleplayer alpha and the requirement for a compatible local install. Removed the outdated phase/build claims from AGENTS.md and resolved ISSUE-0026. [ADR-0021](decisions/ADR-0021-engine-optimization-scope.md) records the narrower scope.

[VERIFIED] `python tools/check_docs.py` and `git diff --check` passed. Documentation only.

## 2026-11-18 - T-093 privacy-checked source snapshot

[VERIFIED] Exported the tree from `876a63e` using `git archive --format=zip <tree>`. Replaced five local path references in two documentation files in the export. Checked the rebuilt 303-member ZIP for CRCs, Git metadata, personal paths, email addresses, common token patterns, and binary/archive extensions. Its extracted copy passed `python tools/check_docs.py` with only the expected local evidence warnings. See the [local manifest](../artifacts/2026-11-18-source-privacy-snapshot/manifest.md).

Use a fresh repository and a public-safe commit identity for publication. Keep the existing commit history private. [VERIFIED] No remote was added or upload made. The snapshot is a local draft pending root license and attribution files.

## 2026-11-18 - T-094 pre-publication security sweep

[VERIFIED] Python ZIP inspection confirmed the T-093 source snapshot SHA-256 in state, verified CRCs for 303 members and found no Git metadata, PE payloads, checked game or archive extensions, common credential patterns, absolute user profile paths or email addresses. This was a pattern-based inspection of the exact draft ZIP, including ASCII and UTF-16 views. It does not apply to later exports or the private history.

[VERIFIED] The separate candidate 15 binary ZIP matches its recorded SHA-256, all ten entries in its SHA-256 inventory verified, and both the outer and corresponding-source ZIP passed CRC checks. PE inspection found private build paths in the two executables, including the engine's CodeView PDB path (ISSUE-0100). No members were executed. The DLL/archive extension inventory of the corresponding-source tree returned no bundled game files of the checked types.

[VERIFIED] Focused source review traced launcher execution, local payload hashes, mod destination and link checks, compressed archive inspection/import, and the patcher's pinned offline dependency preparation. `extract_archive` performs listing and extraction without size, count, or time limits (ISSUE-0101). No hostile test files were produced. Current dependency advisories, vendor engine internals, and comprehensive dynamic security testing were outside this offline sweep. Nothing was uploaded.

[VERIFIED] Managed Standard scan startup timed out (ISSUE-0102). The results are from a local review without an independent reviewer. `python tools/check_docs.py` and `git diff --check` passed.

## 2026-11-18 - T-095 release privacy and prepared mod inputs

[VERIFIED] Rebuilt both executables offline. The final candidate 16 ZIP and its
corresponding-source ZIP passed CRC and hash checks. The final PE records
contained filename-only PDB references, and the ZIP members passed the private
build-path checks. Packaging rejected each candidate 15 binary independently.
ISSUE-0100 is fixed for candidate 16. Candidate 15 stays local.

[VERIFIED] Both mod commands now refuse compressed distribution archives. The
debug and production suites each collected 43 cases and exited 0 with one and
six mode-specific skips. Both exercised archive refusal, prepared directory
and raw `.big` activation/restore, and link rejection after retrying outside
the restricted shell (ISSUE-0092). ISSUE-0101 is fixed. No native game launch
or upload was conducted. See [ADR-0022](decisions/ADR-0022-prepared-mod-inputs.md)
and the [candidate 16 manifest](../artifacts/2026-11-18-patcher-alpha/candidate-16/manifest.md).

## 2026-11-18 - T-096 GitHub source preparation

[VERIFIED] Added root license notices identifying the modified engine and standalone
patcher. The engine license is copied verbatim from the pinned upstream commit.
The fresh source ZIP includes the T-095 fixes and excludes Git history. The
export replaces personal path references and is checked for user-profile paths,
email addresses, common credential patterns, Git metadata and bundled game
binary/archive types. See the [source snapshot manifest](../artifacts/2026-11-18-github-source/manifest.md).
No GitHub repository or release was created.

## 2026-11-18 - T-097 AI development disclosure

Added the project's Codex and OpenCode disclosure beneath the README
introduction with a link to the development session notes. Documentation only.

## 2026-11-18 - T-098 README disclosure wording

Revised the disclosure to describe AI-assisted development in formal terms.
The README still credits both tools and links to the development notes.

## 2026-11-18 - T-099 repair misdecoded documentation punctuation

[VERIFIED] Reversed legacy text-decoding damage in six Markdown files. The
earlier log entries retain their content and line breaks. The first heading
again matches the original Git revision. Synchronized the local README with
the user's wording on GitHub. The public repair contains no README edit.
Both checkouts passed `python tools/check_docs.py` and `git diff --check`.
See [ISSUE-0103](issues/ISSUE-0103-published-docs-mojibake.md).

## 2026-11-18 - T-100 README quick start

[VERIFIED] The GitHub Releases API returned an empty list. Added a README quick
start covering the pending patcher ZIP, the source build guide, installation
on a writable game copy, singleplayer launch, and rollback. The staged local
alpha ZIP still matches the candidate 16 SHA-256 in state.json.

## 2026-11-18 - T-101 simplify the README quick start

Removed the ShockWave-specific launch example and the backup reminder from
the quick start. It retains the download and source links and the general
installation, launch and uninstall steps.

## 2026-11-18 - T-102 publish the Windows singleplayer pre-release

[VERIFIED] Rebuilt the alpha engine without the upstream application icon
and excluded unused media from the corresponding-source archive. Updated
the public notices with the exact EA attribution and dependency licenses.
The packaged executables passed private-path and checksum checks, and the
extracted corresponding source configured offline. ISSUE-0104 is fixed.

[VERIFIED] Candidate 17 installed, verified and uninstalled successfully on
fresh stock and ShockWave copies, restoring all 1,914 and 288 original files
respectively. The first attempt to inspect the earlier stock copy reproduced
ISSUE-0093's stale journal identity, so the test used new disposable copies.
The GitHub draft upload timed out in Python and passed on retry with curl
(ISSUE-0105). GitHub reported the same SHA-256 and byte count before publishing
the pre-release. The README links directly to the ZIP. See the
[candidate 17 manifest](../artifacts/2026-11-18-patcher-alpha/candidate-17/manifest.md)
and [GitHub release](https://github.com/Shiromama/Command-and-Conquer-Generals-Optimization/releases/tag/v0.1.0-alpha.1).

## 2026-11-19 - T-103 README benchmark findings

[VERIFIED] Added median and p95 frame times from the controlled settings
comparison in [EXP-013](experiments/EXP-013-original-vs-optimized.md) to the
[README](../README.md#performance-findings). Linked the separate destruction
A/B, debris correctness probe, reverted experiments, replay blocker, and
pre-release verification. The figures are from existing experiment records.
`python tools/check_docs.py` and `git diff --check` passed.

## 2026-11-19 - T-104 benchmark table legend and public docs

[VERIFIED] Added an [EXP-013 table legend](experiments/EXP-013-original-vs-optimized.md#how-to-read-the-tables)
covering the profiles, workloads, FPS limits, frame-time metrics, and phase timings.
Header units are explicit and a comparison against the prior Git blob found all
17 numeric result rows unchanged. Published the README, EXP-013, and the
pre-release verification note in public commit `84750da`. `git push origin
HEAD:refs/heads/main` succeeded from an isolated public clone. GitHub file reads
on `main` returned all three expected blob SHAs. The public and local docs
validators and `git diff --check` passed. See [ISSUE-0106](issues/ISSUE-0106-github-connector-write-denied.md).

## 2026-11-19 - T-105 README Alt+Tab crash workaround

[VERIFIED] Added the windowed and borderless launch behavior and the 120-cycle
ShockWave result from [ISSUE-0011](issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md)
to the README. `git push origin HEAD:refs/heads/main` published README-only commit
`c2d1053` from the isolated public checkout. A GitHub read of `main:README.md`
matched blob `ae803983e4009d51f956bd2e6ca2fcf0326898b2`.
`python tools/check_docs.py` and `git diff --check` passed.

## 2026-11-19 - T-106 explain the Alt+Tab crash in the README

[VERIFIED] The README now describes the observed missing texture reference and
labels the graphics reset explanation as inferred. `git push origin
HEAD:refs/heads/main` published the README in `9c07bbc`. A GitHub read of
`main:README.md` matched blob `931f8db5bf22cf21a84d3592d7b00c10e34f3cdc`.
`python tools/check_docs.py` and `git diff --check` passed.


## 2026-11-19 - T-025 recover the ShockWave Last Stand replay

[VERIFIED] The replay uses a 119,440-byte Last Stand map with game checksum
`B44EACE8`. Copied the matching map, preview and string table from the nested
user-data directory into `Maps/Last Stand`. Each copy matched its source by
SHA-256. The patched game opened the battlefield via `-loadreplay`.
[ISSUE-0107](issues/ISSUE-0107-stress-replay-map-path.md) records the repair.

[VERIFIED] The recording's executable and AI-script checksum matches the patched
executable with both archived ShockWave scripts. In the original test directory,
loose AI scripts led to a strict headless mismatch at frame 0. With matching
archive data in an isolated game copy, the same command advanced to frame 4500
(2:30) and exited 1 on a remaining mismatch. See
[ISSUE-0108](issues/ISSUE-0108-last-stand-replay-sync.md). Timing attribution is
in progress. The reported 7 FPS has no confirmed cause yet.


## 2026-11-19 - T-107 identify the Last Stand slowdown

[VERIFIED] A diagnostic build of the recording's engine, using the matching
ShockWave scripts and skirmish policies, advanced past the standard replay
sync failure. Strict headless replay reached frame 10,851. In a separate 1080p
capture, the HUD read 7 FPS around 9:21 with most enemy concentrations offscreen.
The surrounding 300-frame window averaged 7.16 FPS, with path searches using
98.45 of 139.66 ms per frame (70.5%) and drawing using 11.50 ms. The test used
a separate build and game data copy. [Profiling report](research/2026-11-19-last-stand-slowdown.md)
and [build verification](issues/ISSUE-0109-last-stand-profiler-build-stall.md).


## 2026-11-19 - T-108 research Last Stand pathfinding fixes

[VERIFIED] Joined the T-107 path and attribution CSVs for frames 16979â€“17278 by
the documented one-frame offset. Mean total search time was 98.45 ms. The
largest timed scope per tick averaged 32.19 ms, while other search scopes
averaged 66.26 ms. Reviewed existing retries, FIFO admission, hierarchy,
group routes and the stable heap in the recording source and prior experiments.

[INFERRED] The [research report](research/2026-11-19-last-stand-pathfinding-options.md)
prioritizes measuring retry causes and prospective reuse, then reducing repeated
work, sharing coarse routes and bounding remaining bursts. Research scope only.


## 2026-11-19 - T-109 isolate the dominant Last Stand search class

[VERIFIED] Built the isolated Release census and ran the matching headless
replay with sync checks to the explicit frame-17402 checkpoint (exit 0).
The CSV contains 80,049 search scopes. In the 300-tick slow window, group
ground routing accounted for 60.11 of 75.41 ms/tick of search time (79.71%).
A retrospective latest-result comparison found 778 repeated group searches
with matching full-path fingerprints three or four ticks apart. Their
gross search cost was 19.08 ms/tick. See the
[search census](research/2026-11-19-last-stand-path-census.md) and supporting
manifest. The study used a diagnostic executable and ordinary solver results.


## 2026-11-19 - T-110 test the Last Stand group cache prototype

[VERIFIED] In the isolated strict headless capture, the per-search clearance
memo reduced the group solver's mean from 8.258 to 3.907 ms over the slow
window. It reused 68.50% of clearance checks. All 80,049 search records
matched T-109 apart from clocks. Replay exited 0 at frame 17402 with sync
checks active. The separate whole-route shadow guard admitted zero
matches once fixed occupancy was considered. See the
[prototype report](research/2026-11-19-last-stand-group-cache.md) and
[diagnostic patch](../engine/patches/T-110-last-stand-group-cache-probe.patch).


## 2026-11-19 - T-111 integrate formation clearance caching

[VERIFIED] The matched 1080p Last Stand pair improved from 10.05 to 14.98 FPS
and reduced p95 frame time from 133.48 to 92.44 ms. Both runs reached the strict
frame-17402 checkpoint with identical results for 15,242 path records. The exact
retained memo separately achieved the same parity at 14.34 FPS. The focused
fixture compiled with MSVC `/O2 /W4` and passed. The cumulative patch reversed on
the modified source and passed a clean-index apply check. The isolated Win32
Release `z_generals` target built with zero errors and loaded a ShockWave solo
mission at 1920Ã—1080. The feature runs in local matches. Candidate 17 remains the
published package. Restored the preferences written by the smoke and matched the
original options file hash. `python tools/check_docs.py` passed. See the
[comparison and build report](research/2026-11-19-last-stand-graphical-cache.md)
and [ADR-0023](decisions/ADR-0023-group-clearance-search-scope.md).


## 2026-11-19 - T-112 establish the 30 FPS budget and test another group optimization

[VERIFIED] The retained memo trace spent 29.68 ms/tick on group searches and
14.28 ms/tick on ordinary plus closest-reachable searches. All 2,185 group calls
shared three exact destinations. All 477 failed fine-grid calls had a same-tick
closest match. The inner-loop diagnostic pair reached frame 17,402 with sync
active and matched 15,242 path records. It measured 8.97 to 9.94 FPS and 45.61 to
35.39 ms/tick in group search. Cross-run timing drift remains tracked in
ISSUE-0116. Both clearance models passed. See the
[30 FPS investigation](research/2026-11-19-last-stand-30fps.md). The active goal
continues with shared formation work and per-unit fallback.


## 2026-11-19 - T-112 research alternate methods and measure expanded-cell overlap

[VERIFIED] Built the isolated expansion probe and ran the 1920Ã—1080 Last Stand
capture through frame 17,402 with sync active. `analyze-overlap.py` matched
15,242 prior path records and verified 4,335 complete expansion lists.
Formations revisited 97.1% of their visited coordinates within five ticks
for matching goals and topology stamps. Thirty-nine failed unit searches
shared cells with their fallbacks. The synthetic reverse field matched A*
costs for 2,185 requests. The scheduling model shows 44.27 ms/tick of search
arrivals versus 8.43 ms/tick available at 30 FPS. See the
[alternate techniques report](research/2026-11-19-last-stand-alternate-search.md).
The real 30 FPS goal remains active. `python tools/check_docs.py` passed.


## 2026-11-19 - T-112 test the native static formation field

[VERIFIED] The Win32 Release shadow ran the target 1920Ã—1080 replay to the
strict frame-17,402 checkpoint. `analyze-shadow.py` matched 15,242 route
records and confirmed 2,185 shadow evaluations. The field averaged 0.33 ms
per tick. Live blocked centers rejected 1,104 static candidates. The 116
full-width candidates covered 0.075 ms/tick of successful legacy work.
A separate exact unit footprint candidate passed 250,000 compiled fixture
comparisons. Its native performance is pending. See the
[native field report](research/2026-11-19-last-stand-native-field.md) and
[ISSUE-0117](issues/ISSUE-0117-field-shadow-path-access.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 test field-guided repair around live blockers

[VERIFIED] The isolated Win32 Release replay reached the strict 1080p
frame-17,402 checkpoint and matched 15,242 search records. The shadow
repaired 1,057 of 1,104 blocked candidate routes and averaged 2.62 ms per
tick including all field and repair costs. The modeled result is 19.71 FPS
at width two, with gameplay still on legacy routes. The repair kernel also
matched independent Dijkstra on 2,363 fixture queries. Started the
unit footprint replay pair with formation identity logging. See the
[live repair report](research/2026-11-19-last-stand-live-field.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 measure repeated commands, the unit shortcut and parallel headroom

[VERIFIED] Both unit-footprint runs passed sync at 1920Ã—1080 and matched
15,242 paths and 2,185 command receipts. The targeted unit timers fell
2.23 ms/tick and average FPS stayed near 15.7. All formation requests
came from scripts. The same members, destination and exact start
recurred within five ticks in 2,017 calls. In the measured control
trace, four freely divisible search workers with zero overhead model
28.44 FPS. Prepared and started the isolated local fixed-occupancy
guard capture. See the
[command and parallelism report](research/2026-11-19-last-stand-script-commands.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 measure local blocker validation and worker dispatch

[VERIFIED] The 1080p local occupancy replay passed sync and route
parity at frame 17,402. `analyze-occupancy.py` found 626 matches among
1,942 local comparisons, with identical route/return fingerprints.
The candidate matches covered 0.385 ms/tick of timed legacy work, versus
0.610 ms/tick in guard scans. A compiled immutable-snapshot worker
fixture processed 1,104 endpoint requests and returned identical
summaries with one, two and three participants. Three-participant
batch times totaled 75.85â€“79.73 ms on synthetic terrain. Prepared and
started the native group move-pipeline replay. See the
[blocker and worker cost report](research/2026-11-19-last-stand-occupancy-workers.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 time script move application and prototype a clearance skip

[VERIFIED] The native move-pipeline replay passed sync at frame 17,402
and matched 15,242 paths and 2,185 move receipts. The move command
averaged 25.198 ms/tick, of which 1.802 ms/tick was outside the measured
formation solver. The dominated-neighbor prototype's retail carry
fixture matched 200,000 sequences. Started a same-binary 1080p replay
pair for native route and timing validation. See the
[move pipeline report](research/2026-11-19-last-stand-move-pipeline.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 validate dominated width and prototype maintained clearance

[VERIFIED] The same-binary 1080p pair measured 16.23 to 17.18 FPS and
23.905 to 21.163 ms/tick in formation search. Both runs passed sync
and matched 15,242 paths and 2,185 command receipts. The shortcut
avoided 31,638,985 width calls in the slow window. The initial packed
fixture was slower than the scalar fixture. Lazy maintained clearance
matched eager and scalar checksums under synthetic edits, and the
guarded native table matched 400,000 changing-grid fixture decisions.
Started the native verify replay. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 verify native maintained width and start combined timing

[VERIFIED] The maintained shadow reached frame 17,402 at 1080p with
sync active and matched the earlier 15,242 path records and 2,185
formation command receipts. It compared 11,172,037 offered clearance
results with zero mismatches over the logged census. The slow window
covered 60.9% of the tested interior memo misses. Started a combined
A/B with the dominated-width shortcut fixed on. Also prepared an
independent sampled expansion-phase profiler for later diagnosis if
needed. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 measure combined clearance and size parallel work

[VERIFIED] `analyze-combined.py` found 15,242 matching path records and
2,185 matching formation commands in the same-binary 1080p pair. The
treatment was 17.26 FPS. The 9.84 FPS control resumed from a minimized
window before the timed section and had broad timing drift across
unchanged draw and unit-search scopes. Preserved the executable for a
reversed-order repeat. `parallel-after-clearance.py` modeled 27.04 FPS
for balanced four-lane whole search jobs with zero worker overhead.
The mixed-width compiled fixture matched 400,000 decisions. Built the
Win32 Release diagnostic and started the native shadow that also reads
existing D3D submission counts in the same replay. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 validate occupied clearance and capture renderer submissions

[VERIFIED] `analyze-mixed.py` matched 55,451,639 clearance answers and
all 15,242 paths and 2,185 commands, with sync at 17,402 and native
1920Ã—1080. `analyze-render.py` matched 300 frames and measured 937
draw calls and 8,228 D3D calls per frame on Intel. Prepared the timing
variant to reuse the per-search memo for occupied widths.
`updated-portfolio.py` modeled 31.33 FPS with width-two field repair,
four zero-overhead search lanes and 4 ms less draw time. The rendering
saving remains unmeasured. Started the same-binary D3D8/D3D9 backend
comparison. The wrapper case loaded the pinned DLL, system D3D9 and
the Intel graphics driver. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 compare Intel graphics backends and build packed clearance

[VERIFIED] `analyze-wrapper-trial.py` matched both 1080p checkpoints,
15,242 searches and 2,185 commands. Native D3D8 measured 17.34 FPS and
8.27 ms draw, and d3d8to9 measured 16.97 FPS and 9.02 ms draw. Both loaded
Intel's driver. `vulkaninfo --summary` enumerated the discrete GTX
and its Vulkan version. A fixture using 526,680 recorded centers per
synthetic density matched all widths and favored packed lanes over the
occupied-width memo. Built the Win32 Release diagnostic and started the
shadow and gated timing sequence. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 verify native packed widths and stage empty unit checks

[VERIFIED] `analyze-native.py on-lane-verify` matched frame 17,402,
1920Ã—1080 sync, all 15,242 searches and 2,185 commands, and all
55,451,639 width answers. The packed-lane shadow resolved 853,898 live
occupants in the slow window versus 32,660,878 in the mixed shadow.
The gated timing pair started. An independent all-unit presence mask
matched 540,000 scalar checks in `test-fixture.cmd`. Staged a native
coverage and parity probe for empty movement and destination footprints.
See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 complete lane timing and verify the next native stack

[VERIFIED] The packed lane treatment and terrain-only control both
matched the 1080p checkpoint and every route and command. Formation
timing moved from 20.655 to 20.533 ms/tick and average FPS from 17.24
to 16.42. `residual-by-outcome.py` attributed 17.437 ms/tick to successful
formation searches in the prior native reference. The combined shadow
matched 20.40 million offered empty movement footprints and 4.57 million
shared-zone expansion cases. The direct-slot heap matched both recorded
queue traces in `test-fixture.cmd switch` and cut queue-only replay time
by 21â€“32%. Started the isolated build and paired replay for the stack.
See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 verify stacked treatment and stage residual attribution

[VERIFIED] The stacked treatment reached frame 17,402 with sync active
at 1920Ã—1080 and `analyze-first-arm.py` matched 15,242 searches and 2,185
commands. It measured 16.39 FPS with the paired control still running.
`measure-existing.py` counted 23.924 ms/tick outside the existing logic
sub-timers in the earlier reference, including script formation work.
Prepared the native diagnostic to match enclosing script, path queue and
player scopes with existing outer search clocks and separate their residual
work. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 complete stack comparison and verify PGO toolchain

[VERIFIED] `analyze-stacked.py` matched replay sync at 1920Ã—1080 and
all 15,242 paths and 2,185 commands. The stack measured 16.39 FPS versus
16.84 for its same-binary control, with formation time at 20.403 versus
20.977 ms/tick. Started the fine residual profiler with the stack off.
`test-toolchain.cmd` generated and used a real Win32 PGO profile and
confirmed identical sample output. The isolated full-engine link
produced the trainer and control. The residual replay matched the original
paths and sync and identified 5.985 ms/tick in generic team scripts versus
0.222 ms/tick outside searches in the path queue. Started the serial PGO
training and conditional test pair. Prepared the team-script phase preview. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 verify the team-script probe and bound combined savings

[VERIFIED] `check-syntax.cmd` accepted both preview sources using the
recorded Win32 flags after correcting [ISSUE-0121](issues/ISSUE-0121-team-syntax-unquoted-source.md).
`check-opcodes.cmd` verified the shared sampler across two translation
units. The native team replay and condition/action summaries are staged.
`model-team-budget.py` aligned three parity-checked captures and modeled
29.82 FPS with four workers, width-two field repair, half the current team
cost and 1 ms of worker overhead. Native PGO training continued past
frame 8,751 with the original link inputs. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 account for phase boundaries and share a native warmup

[VERIFIED] `model-phase-workers.py` reconciled both search phases for
300 ticks. Four workers modeled 23.36 FPS overall from 17.34 FPS, or
18.00 FPS for the path queue alone. `model-queue-retries.py` found 238
different outcomes among 726 repeats over 30 ticks using recorded grid
inputs. The route and nearest-score probes compiled with recorded Win32
flags. `test-fixture.cmd` verified route equality and zone lookup.
Generated one combined replay for both path probes and team diagnostics.
The original trainer hit its time limit. The partial profile linked and
started the 1080p native pair. The fast trainer linked after fixing
[ISSUE-0122](issues/ISSUE-0122-fast-pgo-missing-train-folder.md).
See [ISSUE-0123](issues/ISSUE-0123-last-stand-pgo-training-timeout.md) and
the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-19 - T-112 verify partial PGO and all three replay diagnostics

[VERIFIED] The partial PGO pair matched both native checkpoints and
15,242 search plus 2,185 command records. `analyze-pair.py` measured
15.86 FPS control and 17.17 FPS profiled. The single combined replay
matched the same records. It found no exact optimized field paths among
1,342 built candidates. The nearest-path probe found 93.9% of footprint
checks could improve neither score. The team probe found most action
time in the sequential-script starter. Both the closest-path shortcut
and the starter timing preview passed Win32 scratch compilation. Started
the same-binary closest-path A/B at native 1920Ã—1080. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 finish the closest-path timing pair

[VERIFIED] `analyze-pair.py` matched the original route and command
records and native replay sync for both closest-path configurations.
The score shortcut saved 0.564 ms/tick in its target phase. Mean FPS
in the pair was 16.32 control and 16.57 treatment. The revised PGO and
worker model with team actions removed reaches 25.75 FPS. Started one
1080p replay for the team starter and formation command origin, after
resolving [ISSUE-0124](issues/ISSUE-0124-command-origin-include-path.md).
See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 identify formation script origin and prepare a queue tail index

[VERIFIED] The native starter run passed sync and matched 15,242 search
and 2,185 command records. `analyze-origins.py` traced all formation
calls to the GLA attack approach instruction. `analyze-starter.py`
measured 5.320 ms/tick in allocation and append. The guarded tail index
keeps original head selection and links each new script after the same
tail. The Win32 scratch check and append/promotion fixture passed. Started
a native comparison with a separate ordered queue fingerprint. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 verify indexed queue append and low-telemetry timing

[VERIFIED] `analyze-pair.py` matched 111,149 ordered scripts at frame
17,278, the original 15,242 search and 2,185 command records, and both
1080p sync checkpoints. Tail append improved from 5.117 to 0.172 ms/tick
and paired FPS from 15.93 to 17.17. `analyze-low-trace.py` verified the
same executable, graphics options, queue fingerprint and sync. The
low-telemetry repeat measured 18.04 FPS, 55.43 ms mean and 80.06 ms p95.
The remaining mean gap to 30 FPS is 22.10 ms. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 locate the remaining formation search cost

[VERIFIED] The formation phase replay reached the native sync checkpoint
and matched 15,242 search records, 2,185 commands and the ordered queue
snapshot. The 300-tick analysis attributed 18.402 of 20.914 ms/tick to
grid search and 1.268 to smoothing. The line-step and prefix-smoothing
Win32 fixtures passed 66,049 and 2.6 million comparisons respectively.
The neighbor-loop probe passed the Win32 check and started its 1080p
replay. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 test stable integer buckets on recorded queues

[VERIFIED] The neighbor replay passed sync, route, command and ordered
queue checks. Its sampled attribution overcounted the directly measured
parent, so the finer timing is excluded (ISSUE-0125). The bucket fixture
verified 11,907,527 operations with matching heads and ordered cleanup.
It used 0.312â€“0.499 of the current direct-slot heap's queue time. The
wrapper fixture verified bounds, FIFO ties and retail fallback. Started
the same-binary native formation pair. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 verify formation buckets in the native replay

[VERIFIED] `analyze-pair.py` matched the native sync, routes, commands
and ordered script queue in both configurations. The stable bucket
queue reduced formation searches by 3.335 ms/tick and raised matched
FPS from 18.17 to 19.36 at unchanged 1080p settings. `model-remaining.py`
found 26.26 FPS with four phase-separated workers before dispatch cost.
Started the unit-bucket comparison with formation buckets fixed on. See
the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 verify unit buckets and start direct ID comparison

[VERIFIED] The same-binary unit bucket comparison matched sync, routes,
commands and the ordered script queue. The targeted ordinary and closest
scope fell from 14.286 to 12.594 ms/tick and FPS moved from 17.78 to
18.22. Both bucket modes are enabled in the direct-ID comparison. Its
initial Win32 fixture and compile checks passed. Pool-index buckets and
the zone halo also passed replay-derived fixtures. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.


## 2026-11-20 - T-112 verify direct object IDs and combine grid candidates

[VERIFIED] `analyze-pair.py` matched both native sync checkpoints, the
ordered queue, routes and commands. The direct-ID pair moved from 19.64
to 20.08 FPS and from 71.49 to 68.80 ms p95 with the existing settings.
The combined compact bucket and halo preview passed Win32 syntax and
started its native pair, after resolving the pool scratch include error
in [ISSUE-0126](issues/ISSUE-0126-pool-bucket-scratch-headers.md). See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 finish cache timing and test portable GPU selection

[VERIFIED] The combined grid pair measured 19.46 to 18.88 FPS. The
occupied-width pair measured 20.11 to 19.59 FPS, with 0.891 ms/tick less
formation time and an 88.9% cache hit rate. Both pair analyzers verified
native 1080p sync, 15,242 search records, 2,185 commands and ordered script
queue parity. The 20.11 FPS control is the best measured run. The three
candidate flags stay disabled.

[VERIFIED] Recomputed the four- and eight-worker limits from the
direct-ID trace. A cost-history experiment tested starting one previously
queued unit search earlier and modeled 28.33 FPS. The heavy ordinary
and closest calls still warrant inner-loop work. During untimed warmup,
the deferred unit-neighbor candidate passed Win32 syntax and was built
for its own same-binary replay pair.

[VERIFIED] The Direct3D 9 adapter probe selected the GTX 1650 Ti with a
portable link export. Both Direct3D 8 probe variants used Intel.
`prepare.py --verify` matched the two wrapper replay variants' common
engine inputs. No machine graphics preferences were written. The
sample-guided compiler preflight confirmed the local linker accepts the
switch and the documented conversion utilities were absent from the
installed tool directories. Records, limitations, and recovered scratch
failures are in the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 finish unit-read timing and start GTX comparison

[VERIFIED] The deferred unit reads moved ordinary and closest searches
from 10.785 to 10.683 ms/tick and changed the overall interval from
49.64 to 51.40 ms (20.14 to 19.46 FPS). The same-binary pair matched
both sync checkpoints, all 15,242 searches, 2,185 commands and ordered
script queue. The flag stays off. Best verified FPS is 20.14, still
16.31 ms/frame above the 30 FPS budget.

[VERIFIED] The portable adapter pair linked without the default CRT
warning after the correction in [ISSUE-0130](issues/ISSUE-0130-optimus-object-default-library.md).
The two code-section hashes matched after masking Win32 base-relocation
operands. The NVIDIA treatment started at 1920Ã—1080 and loaded the
pinned wrapper, Direct3D 9 and the GTX driver. The matched timing result
remains pending. See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 verify matched graphics-adapter result

[VERIFIED] In the same 1080p window, the pinned wrapper with Intel UHD
measured 19.94 FPS and the GTX 1650 Ti measured 21.93 FPS. Mean frame
time fell from 50.15 to 45.61 ms and mean draw from 9.047 to 4.983 ms.
The GTX result is the best measured run and leaves a 12.28 ms/frame gap.

[VERIFIED] `analyze-pair.py` verified both sync checkpoints, 15,242
searches, 2,185 commands, ordered queue parity, graphics options
hashes, and both runtime driver and wrapper receipts. A module casing
error was fixed using the original receipts in
[ISSUE-0131](issues/ISSUE-0131-adapter-module-name-case.md).
No pixel comparison was performed. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 recalculate worker headroom on the GTX trace

[VERIFIED] `model-worker-budget.py` on the GTX replay receipt modeled
29.76 FPS for four workers on existing jobs and 32.02 FPS for four
with an earlier start selected by job history. Both charge 1 ms of
assumed overhead. The model leaves 2.11 ms/frame above that allowance
for the earlier-start design. Actual worker scheduling and its input
validation costs are unmeasured. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 measure live early-dispatch eligibility

[VERIFIED] The native GTX observer reached frame 17,402 in sync.
`review.py` matched 15,242 searches, 2,185 commands, script queue order,
the NVIDIA driver and the original graphics settings. The live
history picker reached dispatch on 20 of 299 attempted ticks. All 20
had different sampled request fields and occupancy revisions. Mean
selection/request read and request-field comparison took 11.37 and
0.315 us, respectively. These timings exclude a native solver snapshot.

[VERIFIED] The Win32 worker fixture matched accepted synthetic routes
and executed serial fallback for stale and unfinished speculative
jobs. All 240 large-grid batches validated reads across unrelated
page changes and rejected touched page changes. See
[ISSUE-0132](issues/ISSUE-0132-early-queue-overlay-include.md),
[ISSUE-0133](issues/ISSUE-0133-snapshot-page-publication.md), and
the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
A follow-up native observer generates evidence for queue windows and
coarse position changes from one capture. Its syntax check passed
after [ISSUE-0134](issues/ISSUE-0134-queue-window-dispatch-object.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 measure the limit of tick-start job selection

[VERIFIED] The GTX queue-window replay matched the original options,
checkpoint sync, 15,242 searches, 2,185 commands and script queue.
The most promising tested history picker before scripts covered
0.676 ms/tick of original job time with unchanged sampled policy and
cells. `upper-bound.py` measured a 1.899 ms/tick hindsight ceiling
for that stage before live grid checks or worker costs.

[VERIFIED] The native mirrors and queues after scripts and at queue
entry passed the Win32 checker. The instrumented replay now measures
native grid copy-on-write publication and dirty pages, audits the mirror
against actual ground-cell reads and compares plausible overlap at
the later boundaries. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md)
and [ISSUE-0135](issues/ISSUE-0135-native-page-overlay-mixed-headers.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 validate native snapshots and stage four-worker checks

[VERIFIED] The native ground mirror replay matched the GTX reference
at 1920Ã—1080, all 15,242 path records, 2,185 commands, ordered queue and
sync at frame 17,402. All ten full 350Ã—200 ground-cell audits matched.
The 286-page mirror published in 4.180 us at tick start and 9.452 us
after scripts. After scripts, the 16-slot history picker offered
1.299 ms/tick of optimistic overlap.

[VERIFIED] The Win32 worker footprint fixture and native compile
passed. The replay preview schedules one destination check after
scripts and up to three more at queue entry. It measures publication,
claim and original predicate timings and compares the claimed
results in original queue order. The authoritative solver remains
in control. See the
[maintained width report](research/2026-11-19-last-stand-maintained-width.md),
[ISSUE-0136](issues/ISSUE-0136-worker-policy-build-variant.md) and
[ISSUE-0137](issues/ISSUE-0137-worker-footprint-helper-scope.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 verify footprint policy and stage raw route parity

[VERIFIED] The native footprint-policy diagnostic matched 113,826
movement and 21,699 destination comparisons, plus the original GTX
replay sync, routes, commands and ordered queue. The worker CSV was
empty due to the omitted snapshot setting in
[ISSUE-0139](issues/ISSUE-0139-worker-launch-missing-page-switch.md).
The corrected combined launcher checks all relevant settings.

[VERIFIED] The worker-local ground expansion kernel matched 512
deterministic fixture trials across four workspaces, including raw
route and cost, expansion, cleanup and fallback cases. The native
adapter passed Win32 syntax after
[ISSUE-0138](issues/ISSUE-0138-worker-search-bucket-header.md).
The combined GTX trial compares the raw candidate from live policy
inputs and independently validates queued immutable footprint results.
See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 measure repeated footprint work

[VERIFIED] `operation-budget.py` reproduced the GTX trace's 62.5%
mean frame share for formation, ordinary and closest search. Their
combined count exceeded 11 million expansions in the stress window.
`check-memo.cmd` reduced repeated footprint evaluations in 40
synthetic searches while preserving every route and cost receipt.
The operation-count result and native timing limitations are recorded
in the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 verify worker claims and start native memo timing

[VERIFIED] The combined GTX replay matched sync, all 15,242 searches,
2,185 commands and ordered script queue. All four worker lanes ran.
All 307 accepted footprint results matched. The original predicates
took less time than claiming the tiny jobs. The native ordinary
route shadow matched 729 of 857 supported jobs. The candidate that
preserves the start flag and measures available pool records passed
its fixture and Win32 syntax checks. See
[ISSUE-0139](issues/ISSUE-0139-worker-launch-missing-page-switch.md)
and [ISSUE-0141](issues/ISSUE-0141-worker-raw-route-mismatch.md).

[VERIFIED] The original solver's per-search footprint memo passed
syntax and started a matched 1080p GTX A/B. Both arms use the same
verified baseline stack and graphics. Timing and gameplay parity are
pending. See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md)
and [ISSUE-0140](issues/ISSUE-0140-unit-memo-runner-newlines.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 time the footprint memo and stage full worker searches

[VERIFIED] The matched GTX memo A/B reached sync with 15,242 identical
search records, 2,185 commands, and equal script queue fingerprints.
`review.py` measured 21.84 and 21.95 FPS, p95 66.665 and 63.935 ms,
and 19,083,596 skipped footprint evaluations with zero sampled
differences. The cache remains opt-in for testing.

[VERIFIED] The full ordinary-ground frozen worker fixture
`check-fixture.cmd` passed 256 four-lane searches. The Win32
`check-syntax.cmd` passed after
[ISSUE-0142](issues/ISSUE-0142-worker-frozen-actor-id.md).
The native shadow leaves the original solver authoritative.
`start.ps1` launched the isolated 1920Ã—1080 GTX diagnostic.
See the [maintained width report](research/2026-11-19-last-stand-maintained-width.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 verify full worker paths and stage early dispatch

[VERIFIED] Fine-grid entry `review.py` confirmed GTX sync at frame
17,402, all 15,242 searches, 2,185 commands and ordered script
queue parity. All 646 supported frozen worker routes and 189
supported live-input routes matched exactly. The 30 unsupported
worker entries relied on the original solver. Late worker
publication averaged 505.176 Âµs, with ready exact jobs covering
0.626 ms/tick of original solver cost. See
[ISSUE-0141](issues/ISSUE-0141-worker-raw-route-mismatch.md).

[VERIFIED] The early dispatch candidate retains native queue order.
Lane zero takes one high-cost-history request after scripts, and
the simulation thread audits worker dependencies at the native
queue slot. The `check-fixture.cmd` and `check-syntax.cmd` gates
passed after [ISSUE-0143](issues/ISSUE-0143-early-worker-fixture-mutated-input.md)
and [ISSUE-0144](issues/ISSUE-0144-early-worker-crush-signature.md).
The original solver remains authoritative.

## 2026-11-20 - T-112 measure early queued worker dispatch

[VERIFIED] The early full-search shadow reached the GTX 1080p
checkpoint at frame 17,402 and matched 15,242 searches, 2,185
commands, the ordered script queue, graphics receipt and sync.
The policy adapter supported 250 of 252 native eligible entry
points, and all 250 matched raw chains, flags, costs, expansions
and cleanup counts. 835 submissions averaged 736.845 Âµs for
snapshot and submission.

[VERIFIED] Only 11 of 298 early submissions passed dependency
validation; 41 were stale, 31 unready and 215 never reached
dispatch. The 11 valid routes matched. All early candidates
together carry 23.970 ms of original fine-solver work over 300
ticks, or 0.080 ms/tick. Lane worker solvers averaged
6,873/1,376/1,341 Âµs against 9,071/1,875/1,684 Âµs for the
original.

[INFERRED] Early dispatch cannot fund the 12.235 ms gap even with
perfect eligibility, because the queued post-script prefix does
not contain the large formation searches. With the late-handoff
pair spending 1.138 ms/tick to cover 0.626 ms/tick, the worker
track is parked. ISSUE-0141, ISSUE-0143 and ISSUE-0144 are fixed.
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 size request-level group route reuse

[VERIFIED] Offline analysis of the 1080p GTX diagnostic found 122
distinct request keys and 42 endpoints across 2,185 group searches.
At a four-tick TTL, 777 later searches returned the exact same
route, worth 5.99 ms/tick or 13.15% of the 45.568 ms frame.
Another 788 changed route or state (10.25 ms/tick) and 484
returned null both times (1.82 ms/tick). Exact hits recur after
three (644) or four (133) ticks and cost 1.15 ms p50, 7.75 ms p95
and 11.31 ms max. The remaining 1,408 group searches cost 13.47
ms/tick.

[VERIFIED] All 777 exact hits share the navigation revision but
none share the fixed-occupancy stamp. A fixed-stamp guard would
pass zero of them, which explains the earlier whole-route cache's
zero hits. The older headless census cross-checks at 778 exact
matches and 19.08 ms/tick on the slower stack.

[INFERRED] A route-cell guard captures all 777 exact hits. Whether
it also passes changed-route candidates needs the native shadow;
the trace records route hashes but not route cells or occupancy.
The analysis script and inputs are recorded in
`artifacts/2026-11-20-last-stand-request-reuse/manifest.md`.
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 prepare and compile the route-cell guard shadow

[VERIFIED] `artifacts/2026-11-20-last-stand-route-guard/build-only.ps1`
compiled `z_generals.vcxproj` and linked a 7,050,240-byte
`nvidia/generalszh.exe` (SHA256 `4AC3E5F7...B6871E`). The source
candidate hashes to `D55D47CE...7CF2FE` and `RouteGuard.inc` to
`60569B06...81607D`. `link.log` reports the `NvOptimusEnablement`
export and no `LNK4098`; the executable contains the
`ZH_ROUTE_GUARD_LOG` and `ZH_ROUTE_GUARD_TTL` strings. The pinned
wrapper matches `122928CF...53F8AB8`.

[VERIFIED] `RouteGuard.inc` adds a diagnostic probe at
`Pathfinder::findGroundPath`. The legacy solver remains
authoritative. It keys each diameter-6 ground request by the start
and goal cells, layer, crusher policy and navigation revision,
reuses the latest result within four ticks, validates the cached
route cells at diameter six after a three-cell start skip, and
logs hit, guard, exact and timing fields.

[INFERRED] The offline sizing predicts 777 exact captures worth
5.99 ms/tick and 788 changed-route candidates. The compiled run
will measure guard false positives and false negatives. No game
launch was performed; `run-guard.ps1` and `review-guard.py` are
ready. `python tools/check_docs.py` passed.

## 2026-11-20 - T-113 measure the pathfinding algorithm limit

[VERIFIED] The T-112 expansion trace contains 4,335 searches and
11,027,422 popped cells. Unit exact searches re-expand 41.8% of
their pops (813,685 of 1,945,147); the worst failed search popped
24,153 cells but visited 11,847 distinct cells. Formation searches
pop 21.8x the straight-line distance on average (p95 62.1x) with
only 1.5% duplicates, and their p95 bounding box covers 40.5% of
the 350x200 grid.

[VERIFIED] Per-pop cost is 743 ns formation, 1,100 ns unit exact
and 568 ns closest. The earlier 2.5 ns figure divided 300 ticks of
work by total pops and is corrected in the maintained-width note.
The heuristic overestimates diagonals, turn costs are outside it,
the line callback reopens closed cells, and a failed hierarchy
clears all zones before the fine search.

[INFERRED] The reopen waste is up to 2.98 ms/tick of unit work; the
formation exploration is the larger algorithmic target. A naive
fail-fast cap is rejected: at 8,192 pops it saves all 1.23M long
failure pops but loses 310 of 1,629 successful formation routes.
The next tests are a no-reopen unit shadow and a standard-A*
formation shadow. No game launch. `python tools/check_docs.py`
passed.

## 2026-11-20 - T-113 run the offline no-reopen unit fixture

[VERIFIED] The deterministic 48x48 fixture ran 4,000 start/goal
queries through the verified `GroundSearch.h` kernel and two
variants. Legacy popped 940,065 cells and reopened 198,071. The
no-reopen variant popped 742,128 and reopened none: 21.1% fewer
pops, all 4,000 routes found, 3,541 byte-identical routes (88.5%),
3,941 equal costs (98.5%), 5 lower and 54 higher. A
consistent-heuristic-only variant still reopened 195,448 cells,
because the line edge costs 5 while the heuristic step is 10/14.

[INFERRED] The line callback, not the heuristic, is the reopen
source. The no-reopen mode is the cheap first algorithm experiment.
The 11.5% route divergence and 1.35% higher-cost routes need the
route-changing acceptance protocol. The native shadow is held with
the route-guard run; no game process was started.
`python tools/check_docs.py` passed.

## 2026-11-20 - T-112 run the native route-cell guard

[VERIFIED] The compiled guard ran the replay to frame 17,402 with
`sync=ok` and matched 9,106 window searches and 2,185 commands.
The first build skipped every request because
`Pathfinder::worldToCell` returns `true` on overflow and the probe
treated `true` as failure. After fixing the check, the run
completed logic-only; no D3D module was recorded (ISSUE-0145).

[VERIFIED] With a three-cell start skip, 154 exact routes were
captured (0.16 ms/tick), 33 guard passes were changed routes, 623
exact routes were rejected and 1,239 changed routes were rejected.
With an eight-cell skip, 181 exact (0.19 ms/tick), 53 false
positives and 596 false negatives. Guard cost was 0.022 ms/tick.

[INFERRED] The diameter-6 cell-center check is stricter than the
search's own validity, so the 777 exact route hashes are not
accessible with this guard. The conservative route cache is
deprioritized; the no-reopen unit search and the formation
algorithm are the next tests. ISSUE-0145 tracks the missing GPU
path. `python tools/check_docs.py` passed.

## 2026-11-20 - T-114 prune workspace growth

[VERIFIED] User-authorized permanent deletion removed
19,090,138,009 bytes (17.78 GiB) across 15,344 files: the five
obsolete release trees (`alpha-engine-release`,
`alpha-engine-release-final`, `t089-alpha-release`,
`t095-alpha-release`, `t111-alpha-release`) and the older
`game/alpha-stock-v010` and `game/alpha-shockwave-v010` copies.
The workspace fell from about 56.3 GiB to about 38.5 GiB;
`build/` went 23.7 to 9.7 GiB and `game/` 22.5 to 18.8 GiB.
`artifacts/` stayed at 6.85 GiB and was not touched.

[VERIFIED] The final executable from each release tree was copied
to `build/engines/` before deletion. The production
`alpha-engine-final.exe` hashes to `4FD3B817...702F42`; the
development fixture `alpha-engine.exe` to `1CEFD1F4...F8B766`;
candidates 14, 15/16 and the T-111 build are also preserved.
The active `last-stand-profile-release`, published
`t102-alpha-release`, `engine-vs-community`, protected references
and the current v010b alpha pair remain. See the
[prune report](research/2026-11-20-workspace-prune.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-115 codify the workspace retention budget

[VERIFIED] `AGENTS.md` now has hard rule 10 and a Workspace and
evidence budget section: one active and one published release tree,
one stock/ShockWave alpha pair, one canonical artifact folder per
experiment, a reuse gate, and soft 45 GiB / hard 50 GiB caps.
[ADR-0024](decisions/ADR-0024-workspace-retention-budget.md) records the
policy; `artifacts/README.md` and the session protocol link the checker.

[VERIFIED] `tools/check-workspace-size.py` reports 38.52 GiB across
88,498 files, below the 45 GiB soft cap. It is read-only and exits
non-zero only above the hard cap. The parent instruction file was
mirrored to this copy. `python tools/check_docs.py` passed.

## 2026-11-20 - T-115 remove the fixed workspace caps

[VERIFIED] Per user decision, the 45 GiB soft / 50 GiB hard caps were
removed. [ADR-0025](decisions/ADR-0025-no-fixed-workspace-cap.md)
supersedes ADR-0024; `AGENTS.md` Â§8 is now "Workspace and evidence
efficiency" with no quota. The reuse gate, prefer-one-active-build,
canonical artifact, archive-exe and reviewed-deletion rules remain.
`tools/check-workspace-size.py` is informational and always exits 0.
The current footprint is 38.52 GiB. `python tools/check_docs.py`
passed.

## 2026-11-20 - T-113 run the native no-reopen and standard-A* shadows

[VERIFIED] The native no-reopen unit shadow ran through the verified T-112
frozen-worker adapter on the GTX Last Stand window. It submitted 676 searches:
644 were covered by the worker kernel and 32 stayed with the original solver.
All 644 covered searches reported zero reopens and expanded 401,546 cells
against 696,330 legacy (**42.33% fewer**). Route hashes were equal in 351/644
(54.5%); goal costs were equal in 556/644 (86.3%), with 74 higher and 14 lower.
The authoritative replay reached frame 17,402 with `sync=ok`; all 15,242
searches, 2,185 commands and the ordered script tail match the verified
`on-gpu-nvidia` reference. See the
[no-reopen manifest](../artifacts/2026-11-20-last-stand-no-reopen-native/manifest.md).

[VERIFIED] The standard-A* formation shadow (consistent octile heuristic,
closed set final, no line insertion) covered 1,737 of the 2,185 field queries:
1,633 reached and 104 were unreachable. It expanded 8,479,758 model cells
against 7,139,913 legacy (**+18.8%**), while finding shorter routes
(231,240.5 vs 256,698.4 cells, **-9.9%**; 1,449 shorter, 76 longer). No route
had an exact optimized-node match (0/1,633). Replay sync, search, command and
queue parity are exact. The model does **not** support the pure-waste
hypothesis; the next branch is a faithful cell-cost A* or the clearance-field /
D* Lite path. See the
[standard-A* manifest](../artifacts/2026-11-20-last-stand-standard-astar/manifest.md).

[INFERRED] The no-reopen kernel is a real lever but changes 45.5% of routes
and 11.5% of costs, so it needs the fresh-skirmish acceptance protocol. The
standard-A* result argues against replacing the line/turn search on pop counts
alone. `python tools/check_docs.py` passed.

## 2026-11-20 - T-113 check stock-vs-mod replay compatibility

[VERIFIED] The Last Stand replay names the custom user map
`userdata/maps/last stand`. The stock 1.04 engine loads the map/replay and
renders a battle, but it settles into a static frame within about 29 seconds at
a GenTool-reported 166 FPS. That frame is the known replay divergence/frozen
state, not a valid stock performance result.

[VERIFIED] The rebuilt diagnostic engine with stock data stops at
`CRC Mismatch in Frame 0` and `frame=2 sync=mismatch`. The replay requires the
ShockWave data from frame 0, so the stock-data run is a different simulation.
The retail 1.04 engine with the ShockWave data stayed on the loading screen for
more than two minutes when `game.dat` was launched directly; the normal mod
loader may be required.

[INFERRED] The same replay cannot be used for a stock-vs-mod performance
comparison. The 166 FPS stock frame is not evidence of stock performance. The
next valid comparison is a stock-recorded replay on the Last Stand map or the
synthetic 1,000-unit group-path harness with stock data vs ShockWave data. See
the [research note](research/2026-11-20-stock-vs-mod-replay.md) and the
[compatibility artifacts](../artifacts/2026-11-20-stock-vs-mod-replay/manifest.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-113 compare stock and ShockWave design

[VERIFIED] The ShockWave executable is byte-identical to stock 1.04
(`F37A4929...`); the mod is a data-only overlay. The static INI census found
4,101 object declarations vs 3,179 stock, 3,522 weapons vs 1,715, 1,683
particle systems vs 1,098, 1,364 FX lists vs 485, and 758 overlay INI files vs
135 stock files. The overlay wins the engine's sorted archive load.

[VERIFIED] T-107/T-113 place the slow-window cost in the group pathfinder:
98.45 of 139.66 ms (70.5%) in path searches, only 11.50 ms in drawing; 2,185
formation orders in 300 ticks, 21.8x straight-line exploration (p95 62.1x),
40.5% p95 bounding box of the 350x200 Last Stand map, and 41.8% unit
re-expansion. The stock 1,000-tank benchmark is an open-map, no-group-order
workload at 6.62 ms, so it is not a comparable pathfinding test.

[INFERRED] The inefficiency is the interaction of a data-heavy mod, a
narrow-lane survival map, dense occupancy and continuous scripted group
orders with the stock group pathfinder. It is a scenario-design stress case,
not evidence that the base engine is generally slow. The target is the group
pathfinder or the scenario's order/geometry design, not the renderer or the
INI loader. See the
[design comparison](research/2026-11-20-stock-vs-mod-design.md) and the
[data census](../artifacts/2026-11-20-stock-vs-mod-design/manifest.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-113 external pathfinding research

[SOURCED] Upstream issue #100 documents the core pathology: AI units pile up
on cliffs and obstacles, the retail engine allocates only 30k pathfinding
resources, and failed searches retry and compound the lag. Mauller's per-cell
allocation fix removes the lockups but is non-retail; Skyaero reports a
skip-list/heap can give more than 25% late-game pathfinding improvement. Our
diagnostic replay deliberately uses the retail-compatible List and pool to
match the recording, while live singleplayer uses the T-022 heap and can use
the non-retail allocation, so the measured replay FPS may be pessimistic.

[VERIFIED] The pinned source already contains the 2026 upstream work:
`RETAIL_COMPATIBLE_PATHFINDING_ALLOCATION`, the per-cell obstacle data, the
O(1) path append (`m_pathTail`, no `appendToList`) and the reverse insertion
sort. No cherry-pick is needed; the remaining cost is search strategy, failed
searches/pool behavior, and scenario design.

[SOURCED] The external candidates are flow fields and D* Lite (the existing
`GroupFieldShadow` reverse field/live repair is already close), HPA*/HAA* on
the zone hierarchy, anytime/bounded search, route reuse, and the community
v1.0-vs-1.04 lead. The shortest next measurement is a fresh skirmish with the
live/default path (heap, memo, non-retail allocation), not another replay
tuning run. See the
[external research note](research/2026-11-20-external-pathfinding-research.md).
No game was launched for this research. `python tools/check_docs.py` passed.

## 2026-11-20 - T-113 build non-retail allocation and test fresh scenarios

[VERIFIED] Built retail and non-retail pathfinding allocation exes from the
same diagnostic source: retail `C677E016...` and non-retail `D168B120...`.
The source was restored afterwards. The build is singleplayer-only; no
replay/network compatibility is claimed. The `ZH_MAP`/`ZH_STRESS` harness was
re-enabled for the fresh test and restored.

[VERIFIED] The 1,000-tank fresh Last Stand scenarios are partition-bound, not
pathfinding-bound: path requests 50-276, expansions 0, `l_partition` 36-43 ms;
the non-retail allocation made no measurable difference. The 1,000 tanks
overlap/are blocked at the player start. The UI benchmark starts the actual
8-player Last Stand skirmish from `Skirmish.ini`; a 20 s smoke reached 11,640
attribution frames. The 10-minute live baseline/non-retail A/B was started.

[VERIFIED] The HPA* offline model on a 350x200 width-6 street grid expanded
**51% fewer cells** (median ratio 0.489) at **+0.4%** path cost; 185/197
routes were within 1%. The existing `GroupFieldShadow` width-2 repair is not a
width-6 solver (width-6 coverage 116/1,633). A `Last Stand Test` map copy is
staged for WorldBuilder; the v1.0 `.bak` version remains unverified.

[INFERRED] The non-retail allocation needs the live 8-player result before it
can be judged. HPA*/HAA* is the strongest algorithm prototype; the scenario
edit is the cheapest design test. See the
[non-retail A/B](../artifacts/2026-11-20-nonretail-pathfinding/manifest.md),
[HPA* model](../artifacts/2026-11-20-hpa-star-model/manifest.md),
[field assessment](research/2026-11-20-group-field-promotion.md),
[scenario copy](../artifacts/2026-11-20-scenario-edit/manifest.md), and
[v1.0 lead](research/2026-11-20-v1-vs-104-lead.md).
`python tools/check_docs.py` passed.

## 2026-11-20 - T-113 live 8-player non-retail A/B

[VERIFIED] The UI benchmark started the real Last Stand 8-player skirmish
from `Skirmish.ini` (50k cash, same slot list as T-107). The 10-minute
retail-allocation arm averaged 8.878 ms (112 FPS) with 37,537 path requests,
12,155,658 expansions and 27.46 s search; `l_ai` mean 0.229 ms. The
non-retail arm averaged 8.143 ms (123 FPS) with 21,723 requests, 2,628,136
expansions and 6.84 s search; `l_ai` mean 0.064 ms. Path work fell 75.1%,
p99 fell 30.658 -> 15.954 ms, and frames >33 ms fell 674 -> 124.

[VERIFIED] This is a behavior-changing A/B: the routes and AI/game state
diverge. The human player was idle, the skirmish ends early, and the attribute
tail is the menu; both arms have ~26.6k in-game logic rows. The T-107
human-driven GLA-approach stress (2,185 formation orders/300 ticks) was not
measured. The synthetic `ZH_STRESS` 1,000-tank scenes are collision-bound and
do not validate the allocation.

[INFERRED] The non-retail per-cell allocation is a promising opt-in
singleplayer candidate; it is not a proven 30 FPS fix for the human stress.
The next acceptance test is a played fresh skirmish with the GLA approach
active. HPA*/HAA* remains the strongest algorithm prototype; the field
width-2 repair is not a width-6 solver; the scenario map copy is staged; the
v1.0 lead remains unverified. See the
[fresh A/B](../artifacts/2026-11-20-fresh-skirmish/manifest.md) and the
[non-retail manifest](../artifacts/2026-11-20-nonretail-pathfinding/manifest.md).
`python tools/check_docs.py` passed.

## 2026-11-21 - T-116 diagnose Last Stand group path failures

[VERIFIED] The new-mode human Last Stand run (new replay `stress test 2.rep`,
SHA-256 `C8B9C0...A35F`) reached the T-107 window and logged 3,142 formation
commands. **315 (10.0%) returned no path**; all 315 had `moving=0` and stood
still. Failed groups were smaller (mean 4.2 members, median 4) than successful
groups (mean 7.1, median 7). The run made 999,332 path requests, 1.08 billion
expansions and 2,500 s of search; `l_ai` mean 6.976 ms, p95 32.55, max 368 ms.
`l_partition` mean was only 0.255 ms; the slowest updates were spawn/production.

[VERIFIED] `AIGroup::friend_computeGroundPath` issues one `findGroundPath` per
group (start = group center/center vehicle, goal = destination,
`PATH_DIAMETER_IN_CELLS`). `findGroundPath` rejects at
`clearCellForDiameter`, `goalCell`/`parentCell` `allocateInfo`, zone mismatch or
search exhaustion; `PathfindCell` marks `UNIT_PRESENT_FIXED`/
`UNIT_PRESENT_MOVING` and `blockedByAlly`. The group's own center vehicle and
allied units can occupy the start/goal/route; the smaller groups fail more.

[INFERRED] The user's observations are confirmed: units stay because their
group path failed, and allied units act as obstacles. Sharing **within** a
group is already done; the remaining sharing is **across groups**, the
T-110/T-112 route cache (777 exact repeats, 5.99 ms/tick offline, strict guard).
Dense units are already grouped; the smaller groups fail more, so merging small
groups or reducing simultaneous orders is the design lever.

[INFERRED] Fix order: start/goal ally relaxation; cross-group route cache;
group aggregation; HPA*/clearance field. Unit collision/partition is secondary
in this run. The next diagnostic should log the exact `findGroundPath` failure
gate and replay the new-mode replay (no route change), then apply the endpoint
relaxation and test a fresh human run. See the
[failure analysis](research/2026-11-21-last-stand-group-path-failures.md) and the
[run manifest](../artifacts/2026-11-20-fresh-skirmish/human-newmode/manifest.md).
`python tools/check_docs.py` passed.

## 2026-11-21 - T-116 live reasons and clear-leader fix

[VERIFIED] The played live diagnostic (both relax switches off) logged 3,184
formation commands in frames 16,978-17,249: 2,486 returned a path and **697
(21.9%) failed**. The failures were **606 `zone_mismatch`** and **91
`search_failed`**, with **zero `goal_width`**; all were stationary. Failed
groups were smaller (mean 3.22, median 3) than successful ones (mean 6.42,
median 7).

[VERIFIED] The 697 failures are 697 distinct group IDs, but only **13 distinct
leader objects** account for the 606 zone mismatches and **one leader** for all
91 search-failed commands (start `(2661,1770)`, target `(1282,890)`, five
members). The AI repeatedly re-forms groups around centre vehicles inside the
AI base building footprint; this is a leader/start-cell problem, not 697
independent units and not goal crowding.

[VERIFIED] The saved new-mode replay is invalid for exact diagnosis: it reports
`CRC Mismatch in Frame 0` even on the exact recording exe, and the headless
commands have zero positional matches with the live run. Its 1,164-failure
reason mix is indicative only.

[VERIFIED] The earlier 12-cell spiral start nudge was **rejected for cost**: it
reached only frame 12,085 in 22 minutes (relax-off 17,280 in 12:24), with 162.7
ms of path search in the last recorded frame. It converted cheap zone rejects
into full searches.

[VERIFIED] The replacement clear-leader build `CA492C95...` selects the closest
member on clear, unpinched terrain as the group path start under
`ZH_GROUP_START_RELAX=1`; it adds no path search and logs `alt_leader` in
`commands.csv`. The real AI-only skirmish went idle (frame 18,731, no formation
commands in the T-107 window), so the automated mechanism A/B uses the diverged
replay; the live human start-relax arm remains pending. See the
[diagnostic manifest](../artifacts/2026-11-21-t116-group-relax/manifest.md),
the
[failure analysis](research/2026-11-21-last-stand-group-path-failures.md), and
the [played baseline](../artifacts/2026-11-21-t116-group-relax/live-diag-commands.csv).
`python tools/check_docs.py` passed.

## 2026-11-21 - T-116 clear-leader headless and zone-check build

[VERIFIED] The clear-cell leader build `CA492C95...` with
`ZH_GROUP_START_RELAX=1` reached the frame-17,280 checkpoint in **13:40**
(relax-off 12:24) and did **not** stall; the spiral nudge had stalled at frame
12,085 after 22 minutes. The clear-leader replacement removes the pathological
cost.

[VERIFIED] Its `commands.csv` is absent: the diverged replay's AI had no group
formations inside the absolute 16,978-17,277 window. Window path workload was
2,723 requests / 2.8 M us versus 7,787 / 20.7 M for relax-off; the full-run path
total was 691 M us versus 588 M. The state diverged, so this is a mechanism/cost
check, not a clean fix effect.

[VERIFIED] The live-arm zone-check build `3D2DFE2F...` requires the start cell
to be clear, unpinched and in the goal cell's effective zone; it adds no path
search. The live human start-relax arm remains pending. See the
[diagnostic manifest](../artifacts/2026-11-21-t116-group-relax/manifest.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-117 deploy guard hold, deployed avoidance, long-range vision

[VERIFIED] Added three generic opt-in switches to the diagnostic source:

- `ZH_DEPLOY_GUARD_HOLD=1`: every `DeployStyleAIUpdate` unit ignores
  AI-sourced move commands while fully deployed (`READY_TO_ATTACK`) and in a
  guard state, so it stops packing up to chase a shifting target. Player
  move/attack commands still pass, so the unit can be moved deliberately.
- `ZH_DEPLOYED_AVOID=1`: `clearCellForDiameter` treats any occupant with
  `OBJECT_STATUS_DEPLOYED` as a hard width obstacle, so allied paths route
  around it instead of squeezing past.
- `ZH_LONG_RANGE_VISION=1`: `Object::getVisionRange` returns the longest weapon
  range when it is more than 5% above the current vision, and
  `AIGuardMachine::getStdGuardRange` returns the longest automatic weapon range
  for player units. Guard radius, firing range and map reveal then match for
  long-range units.

[VERIFIED] The combined build is
`C024B41021F7B76674AC4FB69456EC30FF1D876ED7E7749BC9B6B5C731CED0D5`
(`build/engines/t116-combined.exe`). It also carries the T-116 clear-leader
group-start fix behind `ZH_GROUP_START_RELAX=1`.

The combined live Last Stand run is in progress with all four switches on. The
pathfinding failure counts will be mixed with the new combat/vision behaviour,
as expected; `commands.csv` still logs `reason` and `alt_leader`. See the
[design note](research/2026-11-22-deploy-guard-long-range-vision.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-116/T-117 combined result

[VERIFIED] The combined build `C024B410...` ran with all four switches on and
logged 2,670 commands: **539 `alt_leader=1` successes** (all succeeded) and
**327 failures (12.2%)**, all `zone_mismatch`, with **zero `search_failed`**.
The remaining failures come from **7 leaders** and are all `alt_leader=0`
(single-member groups or no usable member). The baseline had 697 failures,
including 91 `search_failed`; those are gone.

[VERIFIED] The combined window was slower: interval **133.3 ms** versus 67.0
ms, `l_ai` **28.04 ms** versus 15.04 ms, path search 29.1 M us versus 23.1 M,
expansions 10.0 M versus 8.3 M. This is mixed with the T-117 combat/vision
changes and a more active battle; a T-116-only run with the T-117 switches off
is needed to isolate the pathfinding cost.

[VERIFIED] The Nuke Cannon/vision visible effects are not recorded in the logs;
the user's in-game report is pending. The game copy (`76099735...`) and
`Skirmish.ini` (`CB9435EF...`) were restored; no game process remains.

The leftover 327 are the single/no-usable-member case; the next fix is a
single-unit/centroid fallback or moving the one stuck member. See the
[failure analysis](research/2026-11-21-last-stand-group-path-failures.md) and
the [design note](research/2026-11-22-deploy-guard-long-range-vision.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-117 guard hold broadened and cached vision

[VERIFIED] The first guard-hold rule (`READY_TO_ATTACK` + `CMD_FROM_AI`) did not
stop the Nuke Cannon in the combined run. The guard chase uses the player's last
command source and can begin while the unit is still packing/unpacking. Build
`F0FB03A9...` ignores **all** move commands while the top-level AI state is any
guard state; the player must Stop/unguard to move it. `ZH_DEPLOY_DEBUG_LOG`
records the command, source, top state and deploy state for deploy-style units.
The focused deploy test is in progress.

[VERIFIED] The T-117 vision rule called `getLargestWeaponRange()` on every
`getVisionRange()` (fog/team/AI/partition). Build `7D75AF57...` (`combined3`)
adds `Object::applyLongRangeVision()`, which caches the effective vision at
object creation and on weapon-set changes and raises the shroud-clearing range
to match; `getVisionRange()` returns the cache. This is the first
FerriteCore/Lithium-style optimization to measure in the next Last Stand run.

[INFERRED] The Minecraft-mod mapping ranks the next candidates as the pathfinder
occupant/status cache, cross-group route reuse, HPA*/flow field, then AI tick
scheduling; rendering (Sodium/EntityCulling) is secondary because `draw` is 10.6
ms in the combined window. See the
[Minecraft optimization mapping](research/2026-11-22-minecraft-optimization-inspirations.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-117 deploy test: no deploy unit; T-116-off baseline

[VERIFIED] The 30-minute deploy-test Last Stand (combined2 `F0FB03A9...`,
T-116 off, T-117 on) reached 3,219 commands: **134 zone failures (4.2%)**, but
the failed groups are now large (median **15** members). No
`ZH_DEPLOY_DEBUG_LOG` file was created and no deploy-style command was logged:
the human was TT, so no Nuke Cannon was built. **The guard hold is still
unvalidated**; it needs a China skirmish with a Nuke Cannon.

[VERIFIED] The deploy-test window was slower: interval **158.3 ms**, `l_ai`
22.2 ms, path **124.7 ms/frame**, expansions 45.5k/frame. T-116 was off; the
134 large failures are the multi-member case the clear leader should rescue.
Combined3 (T-116 on + cached vision) is the next Last Stand test; a short China
Nuke Cannon test is needed for the guard hold. See the
[design note](research/2026-11-22-deploy-guard-long-range-vision.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-118 pathfinder occupant cache

[VERIFIED] `PathfindCellInfo` now carries `Object *m_posObject`, the cached
positioned unit for width queries. It is set in `PathfindCell::setPosUnit` when
a unit enters a cell, cleared when the position is removed, and nulled when the
info record is recycled or released. `PathfindCell::getPosObject()` exposes it;
`clearCellForDiameter` uses it instead of
`TheGameLogic->findObjectByID(cell.getPosUnit())` in both the optimized and
legacy footprint scans.

[INFERRED] The occupant ID was invariant for the life of the occupancy record,
so the hash lookup was repeated work in a hot path (goal width, neighbour
expansion, goal-offset search). The cache should lower per-cell cost while
leaving expansions/routes unchanged; verify with `ZH_PF_FRAME` (`usec_total`,
requests, expansions) and `ZH_ATTR_LOG` (`l_ai`, interval). The
`t116-path-cache.exe` build is in progress; no game run yet.

[Risks] The pointer is valid only while the occupancy record is valid. The
pathfinder must clear it on unit removal/death and info recycle; a missed clear
would leave a dangling pointer where the old ID lookup returned null. The
`PathfindCellInfo` grew by one pointer; no save/CRC field was added. Test unit
death/removal carefully.

Next: if the cache is stable and faster, keep it; if the gain is small, the
cross-group route cache and HPA*/flow field are the next pathfinding levers. See
the [occupant-cache note](research/2026-11-22-pathfinder-occupant-cache.md) and
the [Minecraft mapping](research/2026-11-22-minecraft-optimization-inspirations.md).
`python tools/check_docs.py` passed.

## 2026-11-22 - T-118 path-cache build ready

[VERIFIED] `t116-path-cache.exe` (`63C2530F...`) is built from T-116 + T-117 +
cached vision + the occupant pointer cache. No game run has been started.

[INFERRED] The controlled test is T-116 on with the T-117 switches off:
`t116-path-cache` versus `t116-leader-zone` (T-116 only). With the same map and
setup, expansions/routes should be identical and `ZH_PF_FRAME` `usec_total` /
`ZH_ATTR` `l_ai` should be the comparison. Unit death/removal must be exercised
to prove the cached pointer is cleared.

If the gain is small, the cross-group route cache (T-110/T-112) and HPA*/flow
field are the next pathfinding levers. See the
[occupant-cache note](research/2026-11-22-pathfinder-occupant-cache.md).
`python tools/check_docs.py` passed.


## 2026-11-22 - T-119 unattended engine debugging workflow

Reviewed retained Last Stand runs, T-081's scripted human-slot fixture, the
T-117/T-118 validation plans, and primary tooling references. Added the
[debugging runbook](debugging.md) and
[ADR-0026](decisions/ADR-0026-unattended-engine-debugging.md).
T-120 starts with a short deploy-guard fixture that must prove the target
behavior was exercised. [VERIFIED] `python tools/check_docs.py` reported
`OK: documentation system is consistent`. `python tools/check-workspace-size.py`
reported 38.87 GiB before and after to two decimal places. This session reviewed
and documented the workflow without running an engine scenario.

## 2026-11-22 - T-120 fixture, T-117 hold validation, T-118 cache gate

[VERIFIED] Added the dev-only T-120 fixture and runner: `tools/deploy-fixture.inc`,
`tools/prepare-deploy-fixture.py`, `tools/run-deploy-fixture.ps1` and
`tools/summarize-path-fixture.py`. The runner enforces separate startup, progress and total
deadlines, stages one engine into `game/last-stand-replay`, restores the executable and
`Skirmish.ini`, and records `run.json`.

[VERIFIED] The wrong-template case returned `invalid_fixture` at frame 60 in **7.9 s**
(`template lacks DeployStyleAIUpdate`), proving the coverage gate fails fast. The covered
control and candidate both passed on the same executable (`1EB00B96...`): a China Nuke Cannon
deployed, fired at frame 174/175, and the control packed/moved 105.4 units in guard. The
candidate stayed deployed and stationary (0.0) and moved 38.9 units only after Stop.

[VERIFIED] The fixture found two T-117 implementation defects: the hold compared the
top-level `AI_GUARD` (16) against the guard machine's inner IDs 5000-5005, so it was inert;
and `DeployStyleAIUpdate::update()` still undeployed on an internal guard path. Fixing both in
`DeployStyleAIUpdate.cpp` made the candidate pass. Deployed avoidance, long-range vision and
the combined3 Last Stand run remain pending.

[VERIFIED] The guard-hold source is preserved as
[`engine/patches/T-117-deploy-guard-hold.patch`](../engine/patches/T-117-deploy-guard-hold.patch);
`git -C vendor/GeneralsGameCode apply --check --ignore-space-change` returned 0 against the clean
vendor index.

[VERIFIED] T-118 added `ZH_PF_OCCUPANT_CACHE`, `ZH_PF_CACHE_ORACLE` and a self-test. The
self-test reported **16 mismatches** (100 cell queries, 84 exact hits); the clean oracle
reported **0 mismatches and 100/100 exact hits**. The final path bench (2.7k requests) measured
cache on 2.912 s vs off 2.880 s path search, a **1.1% slowdown**, so the cache is correct but not
a demonstrated speedup and stays behind its switch.

See the [implementation and results](research/2026-11-22-unattended-fixture-results.md) and the
[manifest](../artifacts/2026-11-22-t120-deploy-fixture/manifest.md). The remaining next actions
are the played Last Stand checks for T-116/T-117 and the frame-budget work (T-112).
`python tools/check_docs.py` result is recorded after the update.

## 2026-11-22 - T-116 formation fixture and playtest build

[VERIFIED] The formation fixture reproduced the recorded start failure on the Last Stand map:
with a command-center footprint at `(2775,1168)` and a goal at `(1281,890)`, the control
returned `zone_mismatch` (`leader_usable=false`, `alternate_usable=true`) while
`ZH_GROUP_START_RELAX=1` returned `none` and dispatched a moving route. The matched executable
was `DB1F5689...`; six units were spawned. Some control members still took fallback individual
routes, so the live "all stationary" symptom remains a played check.

[VERIFIED] Built the clean playtest engine `build/engines/t120-playtest.exe`
(`0D3A2819...`, no `ZH_FIXTURE_RESULT`/`ZH_FIXTURE_CASE` strings, T-117/T-116/T-118 switches
present) and staged it as `game/last-stand-replay/Generals.exe`. `tools/play-t120.ps1 -DryRun`
printed the expected 1920x1080 command and exited 0. The retail backup remains `76099735...`;
`tools/play-t120.ps1 -Restore` restores it. A 20-second launch smoke reached the ShockWave
window without an early exit; it was stopped and `Skirmish.ini` was restored to `CB9435...`.

## 2026-11-22 - T-117 remaining switches and combined Last Stand probe

[VERIFIED] Added focused `vision_probe` and `avoid_probe` cases. Vision: legacy Nuke vision
**180**, shroud clearing **350**; with `ZH_LONG_RANGE_VISION=1`, vision and clearing are both
**447.5** (weapon range). Avoidance: a fixed deployed Redguard goal cell returns width **2**
with `ZH_DEPLOYED_AVOID=0` and **1** with it on; both arms passed. The width probe forces
`UNIT_PRESENT_FIXED` with `setGoalUnit`/`setPosUnit` because the width scan only consults fixed
occupants.

[VERIFIED] A combined-switch Last Stand formation run with `ZH_GROUP_START_RELAX=1`,
`ZH_LONG_RANGE_VISION=1` and `ZH_DEPLOYED_AVOID=1` passed on `2A9F5DC4...`: leader unusable,
alternate usable, `last_failure=none`, moving route. This is a scripted switch-integration
check, not a played match; the command CSV was not produced for the script-source move. The
staged playtest remains `0D3A2819...` and is unchanged.

## 2026-11-22 - T-121 CPU/GPU resource profile

[VERIFIED] Profiled the playtest build during the Last Stand replay. The process used
**100-105% of one logical core**; one thread held **98-104%**, every other engine thread stayed
below 2%. Whole-system CPU was **25-48%**, GPU Engine **9-18%**, GTX **0% / 0 MiB** (the game
ran on the Intel UHD path), and memory was **350-400 MB** with 11.8 GB free. One fully busy core
is only 12.5% of the 8-thread CPU, which is why Task Manager's whole-system view looks low.

[VERIFIED] The retained 7.5 FPS window (frames 16,978-17,277) is 133.3 ms/frame: logic 120.5,
path search 97.1, AI 28.0, draw 10.6, client 12.0; 27.8 requests and 33,423 expansions/frame.
The main loop is serial (`GameEngine::execute` -> client update -> logic update -> path queue);
the only `CreateThread` in the engine sources is asynchronous DNS. See the
[resource profile](research/2026-11-22-cpu-gpu-resource-profile.md) and the
[heavy sample](../artifacts/2026-11-22-t120-deploy-fixture/replay-resource-heavy2/). WPR could not
start without elevation, so function-level stack sampling remains a follow-up.

[VERIFIED] A hierarchical-corridor prototype (`ZH_HIER_CORRIDOR`, reusing the existing
hierarchical route to bound the fine A*) gave no gain at frame ~8,000: baseline 14.24 ms median,
radius 8 14.10 ms, radius 2 14.09 ms; expansions 4,290 vs 4,425/4,291. It also produced no
formation-command rows. The prototype was not promoted; the playtest engine remains
`0D3A2819...`.

[VERIFIED] A promoted width-6 field/repair candidate (`ZH_FIELD_SOLVE`) was built and run. At
frames 7,000-7,979 the interval was 59.8 ms vs 61.6 baseline, but path expansions were exactly
**12,510.95 in both** and path usec 43,850 vs 44,606; most requests fell back. The run reached
frame 14,880 before the 900 s timeout, not the 16,978-17,402 window, and produced no formation
commands. It was not promoted; the playtest remains `0D3A2819...`.

## 2026-11-22 - T-122 width-6 cluster/portal HPA*

[VERIFIED] Built a true width-6 HPA* candidate in `findGroundPath`: 10x10 ground clusters,
width-6 portals on shared borders, coarse A* over the cluster graph, the normal width-6 fine A*
restricted to the resulting cluster corridor, and a full-search retry if the corridor fails.
The portal graph is cached per map bounds and the playtest `0D3A2819...` was unchanged while
probing.

[VERIFIED] The hard-corridor probe (`build/engines/t120-hpa2.exe`, `62D8F2AA...`) and the
unchanged `0D3A2819...` both ran the same replay to `frame=17402 sync=ok`. In 16,978-17,402:

| Metric | Baseline `0D3A` | HPA* hard |
|---|---:|---:|
| Interval mean | 142.84 ms | **102.08 ms** |
| FPS from mean | 7.0 | **9.8** |
| Path usec | 104,601 | **74,531** |
| Expansions | 25,644 | **11,373** |
| Paired frame wins | - | **326 / 425** |

The whole run improved from 74.76 to 70.62 ms mean. Command IDs diverge with the routes: only 41
group IDs are shared, and 102 `(frame, leader)` attempts align, of which 27 have the same member
hash and 61 the same returned/reason. Exact parity is not claimed.

[VERIFIED] The 10,000-12,599 window regressed from 110.19 to 159.40 ms. The new
`hpa_attempts`/`hpa_retries` frame counters show **3.3-3.5 of ~4 attempts per frame fail** and pay
a second full search whose nested trace is not counted in `expansions_total`. A soft-corridor
variant (`2F403D55...`) removed the retry but left gameplay at logic frame 9,311, so it never
reached the heavy window and was rejected. A 5-frame failure memo (`8D29C1D4...`) cut the 12k
retries from 3.45 to 1.64 and 10-12k to 128.33 ms, but its full run changed the simulation (2,483
command rows vs 2,015) and worsened the heavy window to **180.59 ms**; it was rejected and the
memo reverted.

[VERIFIED] The promoted build is the verified default-on hard-corridor
`build/engines/t120-hpa4-final.exe` (`51451674...`), staged in `game/last-stand-replay`. It
reached `frame=17402 sync=ok` with **no `ZH_HPA_*` variables**; `tools/play-t120.ps1` also sets
`ZH_HPA_CORRIDOR=1`. Its heavy window was 110.38 ms on a slower machine run, but its command CSV
is byte-identical to the 102.08 ms probe, so the difference is drift. This is a route-changing
singleplayer build; the 10-12k retry cost remains open. See the
[resource profile](research/2026-11-22-cpu-gpu-resource-profile.md) and the
[artifact manifest](../artifacts/2026-11-22-t120-deploy-fixture/manifest.md).

## 2026-11-22 - T-123/T-124 live portal validation and repeated-request cache

[VERIFIED] The formation command log exposed a much larger inefficiency than the solver: the
16,978-17,277 window has only **85 distinct `(member_hash, from_cell, to_cell)` keys** but
**2,427 attempts**. 2,340 (96.4%) are exact repeats at a **3-4 frame gap**, and the leader is
identical for all 2,340. The group object is re-created each time, which is why group-ID and
route-cell caches missed it.

[VERIFIED] T-123 validates every coarse cluster edge against live width-6 clearance before the
fine search. The 12,600 probe (`D4B6B158...`) has **zero retries** in both windows: 10,000-12,599
falls from 159.38 to **123.01 ms** (110.17 baseline) with 3.1 rejected corridors/frame; 5,000-9,999
is 62.69 ms.

[VERIFIED] T-124 caches the exact group request in `findGroupGroundPath` (leader + bit-identical
from/to + diameter, `ZH_GROUP_PATH_CACHE_TTL`, default 10 frames, singleplayer-only) and returns a
copy of the previous path or failure. The full TTL-10 run (`3C813EB9...`) reached `frame=17402
sync=ok`:

| Window | Baseline | HPA hard | HPA + cache |
|---|---:|---:|---:|
| 5,000-9,999 | 69.91 ms | 63.35 ms | **50.75 ms** |
| 10,000-12,599 | 110.17 ms | 159.38 ms | **74.23 ms** |
| 12,600-16,977 | 119.02 ms | 86.62 ms | **78.62 ms** |
| 16,978-17,402 | 142.84 ms | 102.08 ms | **97.48 ms** |
| Whole run | 74.76 ms | 70.62 ms | **51.74 ms** |

Cache hits are 57-62% in the mid-game and 57% in the heavy window. This is the largest single win
in the task and it removes repeated searches rather than making A* faster.

[VERIFIED] The promoted default-on build is `build/engines/t120-hpa10-final.exe`
(`8FEC201A...`, staged). It reached `frame=17402 sync=ok` with **no `ZH_*` environment** and
measured a **51.59 ms** whole-run mean (42.13 logic, 30,932 path usec) and a 104.22 ms heavy
window (the env-set TTL-10 run was 97.48 ms; identical cache counters and command CSV show the
6.7 ms gap is machine drift). `tools/play-t120.ps1` sets `ZH_HPA_CORRIDOR=1` and
`ZH_GROUP_PATH_CACHE_TTL=10`. The next measurement is T-125: `ZH_PATH_CENSUS` on the heavy window
to attribute the remaining ~15 non-group requests/frame and the construction-event spikes.

## 2026-11-22 - T-125 census, cache sizing and construction invalidation

[VERIFIED] `ZH_PATH_CENSUS` (frames 16,978-17,401, 9,605 outer requests) attributes the 58.2
ms/frame path budget: `findGroundPath` group misses **68.8%** (1,331 calls, 12.8 ms mean, 3.45M
expansions), `internalFindPath` 14.9%, `findClosestPath` 14.1%, attack 1.3%, move-away 0.6%.
The remaining group misses are only **28 unique keys**; a TTL-20 cache would hit 67.9% and avoid
27.5 ms/frame. `findClosestPath` and `internalFindPath` have **0% exact repeats within 20 frames**
(the actor's start cell changes), so a request cache cannot remove them.

[VERIFIED] The 128-slot cache was collision-limited: replaying the command log through the same
hash gives 56.2% hits at 128 slots (observed 56.6%), 65.2% at 256, 70.2% at 512. `navigationRevision`
changes only 5 times in 425 frames, so keying on it is nearly free and invalidates exactly at
building/zone events.

[VERIFIED] The 512-slot + revision + TTL-20 build (`D8357471...`) reached `frame=17402 sync=ok`:

| Window | Baseline | Previous build | **New** |
|---|---:|---:|---:|
| 5,000-9,999 | 69.91 ms | 48.83 ms | **41.67 ms** |
| 10,000-12,599 | 110.17 ms | 73.76 ms | **50.16 ms** |
| 12,600-16,977 | 119.02 ms | 78.40 ms | **62.21 ms** |
| 16,978-17,402 | 142.84 ms | 104.22 ms | **67.24 ms** |
| Whole run | 74.76 ms | 51.59 ms | **40.60 ms** |

The heavy window is **14.9 FPS** (7.0 baseline), whole-run path usec 21,672 (52,710 baseline), and
cache hits/misses in the heavy window are 3.53/1.39 (72% hits). This build
(`build/engines/t120-hpa12-final.exe`, `D8357471...`) is staged as the playtest;
`tools/play-t120.ps1` sets `ZH_HPA_CORRIDOR=1` and `ZH_GROUP_PATH_CACHE_TTL=20`.

[VERIFIED] A navigation-revision change occurs at frame 17,213/17,214. The census does not log
which object caused it; the "Stinger Site" label is [INFERRED] from the screenshot/HUD time. The
user's live session instead showed groups stopped by existing buildings without a new
construction, so the replay and live scenario are not identical. The cache now invalidates on any
revision change. The old build's 17,220 path frame was **252.7 ms**; the revision-keyed build is
**19.0 ms**, and 17,208 drops from 119.2 to 66.0 ms.

## 2026-11-22 - T-127 width memo; failure TTL rejected

[VERIFIED] Enabling the per-search width memo for width-6 ground paths (invalidated at search
exit) cut the same requests with identical expansions and cache counters:

| Window | 512/rev/TTL20 | + width memo |
|---|---:|---:|
| 5,000-9,999 | 41.67 ms | **39.54 ms** |
| 10,000-12,599 | 50.16 ms | **45.94 ms** |
| 12,600-16,977 | 62.21 ms | **56.69 ms** |
| 16,978-17,402 | 67.24 ms | **62.89 ms** |
| Whole run | 40.60 ms | **37.60 ms** |
| Whole-run path usec | 21,672 | **18,988** |

[VERIFIED] The grouped census misses are 989 successes (15.47 s, 15.6 ms mean) and 342 failures
(1.56 s, 4.6 ms mean). The replay's remaining path cost is mostly successful long formations, not
blocked routes; the user's live stuck-group case is a different mix.

[VERIFIED] A failure-only 60-frame TTL was tested at 12,600: misses fell 0.92 -> 0.73/frame in
10-12.6k, but the interval rose 45.94 -> 47.21 ms (5-10k 39.54 -> 40.97). It is **not promoted**:
it does not pay for itself and would delay recovery of stuck units. The playtest is the width-memo
build `844A319E...` (`t120-hpa14-final.exe`), staged with `ZH_HPA_CORRIDOR=1` and
`ZH_GROUP_PATH_CACHE_TTL=20`.

## 2026-11-22 - T-128 blocked-route fixture diagnostic

[VERIFIED] Added `ZH_FIXTURE_BLOCKER_AT=leader|mid|goal` (runner `-BlockerAt`) to the formation
fixture and ran the Last Stand map with a `ChinaCommandCenter` blocker, a `ChinaTankBattleMaster`
group of 6, and the recorded T-116 leader/goal:

| Blocker | `leader_usable` | `alternate_usable` | `last_failure` | `formation_moved` |
|---|---|---|---|---|
| leader | false | true | `zone_mismatch` | true |
| mid | true | true | `none` | true |
| goal (radius 8) | false | false | `goal_width` | true |
| goal (radius 24, reverted) | false | false | `none` | **false** |

[VERIFIED] A building at an open midpoint is already detoured around and the group moves. A
building on the goal produces `goal_width`. Widening the goal search to 24 cells replaces
`goal_width` with a valid path (`none`), but the group still does not move - the residual is
**post-path** formation/steering/guard behavior, not the search radius. The 24-cell experiment was
env-gated and reverted; the playtest remains `844A319E...`.

[INFERRED] The user's "nothing in the path but not moving" is most consistent with the leader/start
building footprint (`zone_mismatch`, mitigated by `ZH_GROUP_START_RELAX`) or a post-path
formation/guard block. The engine already asks destination allies to move
(`moveAlliesAwayFromDestination`) and marks `blockedByAlly`, but has no persistent
unit-vs-building blocker memory or general right-of-way request; that remains T-128.

[VERIFIED] The 24-cell goal-search telemetry isolates the stall: `group_idle=false`, 6 members,
**6/6 moving**, **6/6 with a path**, path age 240, **146 nodes**, first node (2775.0, 1168.0) at
the unit (2774.9, 1167.9), and **0 displacement**. Rebuilding the cached path's `nextOptimized`
links did not change it, so the units are moving with a valid path but the speed/collision layer
does not advance them. The next trace is the group/locomotor speed and the four units spawned on
the same leader point; the fixture telemetry now records those fields.

[VERIFIED] Correction: the radius-24 stall was a **fixture artifact**. The fixture spawned four
units on the exact leader coordinate; the separated-spawn control (same blocker/goal, distinct
positions) moved (`formation_moved=true`, first unit ~150 units from spawn, 6/6 paths, 147 nodes).
The engine does not have the post-path stall claimed above. The live stuck-tank symptom still
needs a faithful reproduction; the likely causes remain the T-116 leader/zone footprint or a
guard/deployed unit blocking a choke, not a general movement bug.

[VERIFIED] A choke-wall fixture (8 `ChinaCommandCenter` buildings across the midpoint, distinct
spawns) was bypassed: the command log at frame 600 records `returned=1`, `reason=none`, 6 members,
`moving=0` at issue; after 240 frames `formation_moved=true` and the first unit is ~270 units from
spawn. The fixture now logs formation commands at any frame (`ZH_FORMATION_COMMANDS_ALL`, per-row
flush) and supports `leader|mid|goal` blockers, but the open map always offers a detour.

[BLOCKED] T-128's blocker-aware give-up/re-target needs a faithful stuck-group repro. The remaining
input is a live playtest `ZH_FORMATION_COMMANDS` capture from the user's session: launch
`tools/play-t120.ps1 -FormationLog`, let a group stall behind buildings, and share
`artifacts/live-formation-commands.csv` so its `returned`, `reason`, `moving` and `alt_leader` can
be classified.

## 2026-11-22 - Playtest-switch replay check

[VERIFIED] The staged `844A319E...` build was run with the actual playtest switches
(`ZH_GROUP_START_RELAX=1`, `ZH_DEPLOY_GUARD_HOLD=1`, `ZH_DEPLOYED_AVOID=1`,
`ZH_LONG_RANGE_VISION=1`, `ZH_HPA_CORRIDOR=1`, `ZH_GROUP_PATH_CACHE_TTL=20`). It reached logic
frame **~12,011** and then showed the score screen, so the 16,978-17,402 window was unreachable.
The process kept rendering the score screen uncapped: **121,440 render frames at ~10 ms**, Intel
UHD **99%**, GTX **0%** - the high GPU use seen after the run, not pathfinding compute. The game
was closed and the playtest exe restored (`844A319E...`).

[VERIFIED] The switches change the replay outcome, so the heavy-window comparison cannot be made
with this fixed input. The no-switch `844A319E` run remains the comparable benchmark (heavy
62.89 ms, whole 37.60 ms). The playtest configuration needs a live-session validation.

## 2026-11-22 - Remaining non-group cost and sliding-cache check

[VERIFIED] `internalFindPath` and `findClosestPath` do not call `clearCellForDiameter`, and the
census found **0% exact repeats** for them within 20 frames. A terrain-width cache cannot remove
their cost.

[VERIFIED] A sliding group cache (refresh on hit, max age 60; `B27DA263...`) cut misses 0.92 ->
0.44/frame and path usec 26,371 -> 24,224 in 10-12.6k, but the interval was flat: 45.94 -> 46.06 ms
(5-10k 39.54 -> 39.67). It was rejected; the verified playtest remains `844A319E...`.

[INFERRED] The 62.89 ms heavy frame is ~30 ms path, ~20 ms other logic, ~11 ms draw. Caching has
plateaued; the next structural lever is the committed path worker or reducing other logic.

## 2026-11-22 - Closest-search cap

[VERIFIED] `findClosestPath` now stops after `ZH_CLOSEST_MAX_EXPANSIONS` expansions and returns
the closest reachable cell already recorded. With a 4,000 cap on the `844A319E` base:

| Window | `844A319E` | + cap |
|---|---:|---:|
| 5,000-9,999 | 39.54 ms | **35.75 ms** |
| 10,000-12,599 | 45.94 ms | **40.36 ms** |
| 12,600-16,977 | 56.69 ms | **56.22 ms** |
| 16,978-17,402 | 62.89 ms | **52.29 ms** |
| Whole run | 37.60 ms | **35.20 ms** |
| Heavy path usec | 29,955 | **22,935** |

[VERIFIED] The cap changes behavior: group command rows in the heavy window fall from 2,086 to
**1,039**, and `search_failed` rises from 79 to **230** (`none` 1,088 -> 663). The replay still
reaches `frame=17402 sync=ok`. This is a route/AI-changing singleplayer trade-off.

[VERIFIED] Promoted build `2BC7180B...` (`t120-hpa18-final.exe`, staged);
`tools/play-t120.ps1` sets `ZH_CLOSEST_MAX_EXPANSIONS=4000`. Heavy window **52.29 ms / 19.1 FPS**,
whole **35.20 ms**; still short of 30 FPS. The remaining path is ~23 ms and other logic ~19 ms, so
the next structural lever remains the committed worker or other-logic reduction.

[VERIFIED] A lower path-queue cell budget (`ZH_PATH_QUEUE_CELLS=2000` vs the stock 5,000) was
tested at 12,600: the replay ended at logic frame **~9,501** on the score screen because path
requests starved and the match diverged. Rejected; the stock 5,000-cell queue budget stays.

## 2026-11-22 - Heavy-phase breakdown and structural conclusion

[VERIFIED] The promoted `2BC7180B...` heavy window measures 52.29 ms: logic 41.45 (l_ai 20.78,
l_updates 8.57, l_partition 1.22), draw 9.6, client 10.44; path usec 22.93 (15.63 requests/frame,
max 13,785). The phase timers overlap, so the path sits inside the AI phase; the remainder is
gameplay logic.

[INFERRED] No safe switch-level other-logic reduction remains. A lower queue budget starved
requests; object updates and AI state machines are behavior. Reaching 30 FPS needs the path
overlapped with other logic/draw via a committed worker (frame snapshot, separate pathfinder state,
validation, ordered dispatch). The existing speculative worker is parked: snapshot 1.138 ms/tick
vs 0.626 covered, 11/298 early candidates validated. This is a structural rewrite, not another
cache.

[VERIFIED] `GroundSearch::Workspace::run` is a full per-lane A* kernel (nodes, queue, seen table)
with immutable `Access` reads, but `Query`/`Access` have **no width-6 footprint**; it covers
ordinary routes only. A same-frame committed group worker needs a kernel/access extension plus
commit validation.

[VERIFIED] The frozen route shadow is wired only into `internalFindPath` (`AIPathfind.cpp:4064`),
not `findGroundPath`/`findGroupGroundPath`; its `Access` uses the actor's own radius, not the
6-wide group footprint. A width-6 worker needs a new submit/snapshot/commit path for the group
search.

## 2026-11-22 - Cluster-size tuning rejected

[VERIFIED] `ZH_HPA_CLUSTER=6` on the capped build at 12,600: 5,000-9,999 **39.20 ms** vs 36.12
(10x10), 10,000-12,599 **39.30 ms** vs 40.63, 5,000-12,599 **39.24 ms** vs 37.66. The narrower
corridor helps only 10-12.6k and is net worse; 10x10 stays. `ZH_HPA_CLUSTER` remains an env-gated
knob (default 10).

## 2026-11-22 - Path-queue/client overlap rejected

[VERIFIED] A minimal overlap ran the path queue on a worker during `TheGameClient->UPDATE`, joining
before logic (`ZH_PATH_OVERLAP=1`). At 12,600: 5,000-9,999 **32.55 ms** (36.12), 10,000-12,599
**37.94** (40.63), 5,000-12,599 **34.20** (37.66). Full run: 12,600-16,977 **56.45** vs 56.22 and
heavy **53.91 vs 52.29** (path usec 33,146 vs 22,935; command rows 2,599 vs 1,039). The one-frame
path delay increases heavy-window work and changes the command stream; whole run is 33.99 vs
35.20 ms, but the target window regresses. Rejected; source reverted, playtest `2BC7180B...`.

## 2026-11-23 - Cache-copy re-optimization rejected

[VERIFIED] Rebuilding the cached path's `nextOptimized` links on every hit
(`ZH_GROUP_PATH_REOPT=1`) was worse at 12,600: 5,000-9,999 **39.01 ms** vs 36.12, 10,000-12,599
**48.36** vs 40.63, 5,000-12,599 **42.21** vs 37.66. The smoothing cost outweighs the benefit;
reverted, playtest stays `2BC7180B...`.

## 2026-11-23 - TTL-30 rejected

[VERIFIED] A 30-frame fixed cache TTL was worse than 20: 5,000-9,999 **44.78 ms** vs 36.12,
10,000-12,599 **54.26** vs 40.63, 5,000-12,599 **48.03** vs 37.66, despite fewer misses
(0.57/0.54 vs 0.63/0.72). Longer reuse follows stale paths and changes behavior; TTL 20 stays.

## 2026-11-23 - Group frozen-shadow result

[VERIFIED] Wired a `pathDiameter == 6` group query into `findGroundPath` using the frozen A*
kernel with radius 3 (6-wide footprint) and the leader actor. With the page snapshot enabled
(`ZH_EARLY_QUEUE_LOG` + `ZH_NATIVE_PAGE_LOG`), the heavy window produced 142 accepted jobs from
22 of 25 group leaders and 139 compared routes, but **0 chain matches and 0 cost matches**.
The radius-3 footprint does not reproduce the serial width-6 group route/cost; the existing
kernel cannot be committed for group paths. A faithful width-6 clearance/line-cost/endpoint-relax
kernel is required. Diagnostic source kept env-gated; playtest `2BC7180B...`.

## 2026-11-23 - Exact-width synchronous kernel rejected

[VERIFIED] Running `GroundSearch::Workspace` synchronously with the live exact
`clearCellForDiameter(6)` Access over the heavy run: 8,088 group queries, all found a route,
7,597 serial success comparisons, 491 serial failures, but only **4 chain/cost matches**. Exact
width alone does not reproduce the serial group route; the width penalties, line checks, goal-cell
rules and endpoint relax differ. A committable group worker needs a faithful port of the serial
group search, not a kernel tweak. Playtest `2BC7180B...`.

## 2026-11-23 - Width-6 group kernel commit (T-127 candidate)

[VERIFIED] The kernel now has an exact `Access::width` (live `clearCellForDiameter`) plus the
serial `0.6f * delta * COST_ORTHOGONAL` width penalty and pinched/line rules. The synchronous
diagnostic still matched only **2 chain / 4 cost of 7,595** serial group routes, so exact parity
is not achievable with this kernel. It is much cheaper: **743 us/query**, 251 heavy queries
totalling 184 ms (0.43 ms/frame), p95 2.06 ms.

[VERIFIED] Committing the validated kernel route in the same frame (every cell
`CELL_CLEAR`, unpinched and zone-passable; serial fallback otherwise) cut the heavy window from
52.29 to **43.98 ms (22.7 FPS)** and the whole run from 35.19 to **31.92 ms (31.3 FPS)**. Path
usec 22,935 -> **16,399**, `l_ai` 20.78 -> **16.51**. The repeat produced identical CRCs/commands
with path **16,378 usec**; its 38.65 ms heavy mean had lower client/draw load (4.8/4.4 vs 10.8/9.9).
Commands 983 vs 1,039, with more `none` (686 vs 663) and fewer `search_failed` (84 vs 230); 90
heavy serial fallbacks; the replay reaches `frame=17402 sync=ok`.

[VERIFIED] Rejected: serial line-continue (parts 22,336 usec, expansions 8,919, but 1,551 commands
and `goal_width` 375/`zone_mismatch` 175) and ordinary `internalFindPath` replacement (match ended
at ~frame 6,606, score screen ran to 63,840).

[VERIFIED] Harness: `ZH_GRAPHICAL_REPLAY_STOP` now stops when the engine leaves replay mode after
frame 100, and `tools/wait-replay.ps1` kills a benchmark when `l_updates + l_ai < 0.2 ms` for 30 s.
The verifyidle run ended with `WAIT_RESULT=CHECKPOINT` / `replay_finished`. The staged playtest is
`1EE75D56...` (`t120-idlestop.exe`) with `ZH_GROUP_KERNEL_REPLACE=1`; `2BC7180B...` is the rollback.

[VERIFIED] `ZH_UNIT_MASK=on` (validated empty-footprint short-circuit) was neutral: identical
CRCs/commands/expansions, path 16,520 vs 16,400 usec, `l_ai` 16.53 vs 16.51; not promoted. The
remaining heavy path is ordinary `internalFindPath`/`findClosestPath`; the zero-path floor is
~27.6 ms, so 30 FPS needs path <= ~5.7 ms. The whole run is already 31.3-31.5 FPS; the heavy
30 FPS target needs a safe ordinary solver or draw/client overlap.

[VERIFIED] Closest cap 2,000 regressed: heavy **67.34 ms (14.9 FPS)**, path 32,957 usec, commands
2,508, group misses 928. The AI-only ordinary kernel preserved the 17,402 match but also regressed:
heavy 51.72 ms (19.3 FPS), path 23,104 usec, `l_ai` 26.68, commands 2,098, `zone_mismatch` 525.
Both rejected; the 4,000 cap and group-only kernel stay. Every serial search lever is now neutral
or negative; the 30 FPS heavy target needs a worker/overlap or a faithful ordinary solver.

[VERIFIED] Heavy-window census split (425 frames, 16.7 ms total): `internalFindPath` 6.25,
`findGroundPath` 3.74 (mostly 90 serial fallbacks), `findClosestPath` 3.59, `findAttackPath` 2.37,
hierarchy/move-away 0.78 ms/frame. Exact `(object, from, to)` repeats have median gaps of 20/45
frames; repeats within 5 frames save only ~0.03 ms/frame, and same-frame destination sharing is
negligible. A short-TTL cache cannot capture the remaining work.

[VERIFIED] Relaxing the group commit validation to the serial clip-zone rule reduced fallbacks but
ended the match at ~frame 15,853, before the heavy window. Rejected; the strict validation's
fallbacks protect behavior.

[INFERRED] A worker must cover ordinary + closest + attack (**12.2 ms/frame**) to matter, and the
frozen snapshot must beat its own cost. The existing snapshot path is 1.138 ms/tick for 0.626
ms/tick of covered ordinary work, so a cheaper snapshot/validation is the prerequisite for a real
path thread.

[VERIFIED] ADR-0027 records the worker gate: the group kernel stays synchronous, and a deferred
ordinary worker is not shipped because the AI's requests are 20-45 frames apart (a one-frame result
is stale), the existing snapshot costs 1.138 ms/tick for 0.626 ms/tick covered, and the one-frame
overlap regressed heavy 53.91 vs 52.29 ms. The worker is authorized only after a partial/double-
buffered snapshot, same-frame queue or prefetch, ordered validation and a command mix no worse than
the group build.

[VERIFIED] Region-gate shadow: a 32-cell margin / 128-cap read bound covered 85.0% of
`internalFindPath` calls with **100% exact chain/cost parity** at 70 us vs ~1,430 us serial (kernel
and serial expansion counts identical). Committing it in the same frame still diverged across five
variants (start-cell zone, `canOptimize`, open+closed budget charge, AI-only): heavy 57.38-70.30 ms,
path 29,558-41,010 usec, commands 2,081-2,817 vs the group build's 983. Raw parity is not final
`Path::optimize`/queue-timing parity; the region commit is rejected. Staged `1EE75D56...`.

[VERIFIED] The final region commit (start-cell `blockedByAlly` exclusion + exact open+closed budget
charge + `canOptimize`) is **behavior-exact**: CRC `04C62655` and the 983-row / 122,319-byte
command stream match the group build. It is **not a performance win**: path 17,361 vs 16,399 usec,
whole 31.88 vs 31.92 ms (heavy 40.26 measured with client/draw 5.14/4.62 vs the baseline's
10.80/9.92). The 85% coverage is count-weighted (cheap searches); the expensive long searches
remain serial. Rejected for performance; staged `1EE75D56...`.

[VERIFIED] Cost-weighted region coverage: cap 128 7.6% of serial cost (net 0.15 ms/frame), cap 192
38.4% (1.03 ms), cap 256 56.1% (1.55 ms), with 100% route parity at every bound. The cap-256 commit
is behavior-exact (CRC `04C62655`, 983 rows) but path 17,460 vs 16,399 usec and whole 32.49 vs
31.92 ms; region checks, materialization and queue accounting offset the kernel saving. The
region/ordinary commit is closed for performance.

[VERIFIED] Frozen worker shadow on the staged build: 4 lanes 731/1,131 (64.6%) submissions,
730/730 exact route parity, 273/731 ready (37.3%); 8 lanes 1,027/1,131 (**90.8%**),
**1,026/1,026 parity**, 467/1,027 ready (**45.5%**). Page freeze is 9-14 us; the per-submit input
copy (resident 65k + units + zone) is 512 us, i.e. 1.10 ms/tick. The old 1.138 ms/tick figure was
this copy, not the freeze. The production design is queue-start submission with one shared
per-frame resident/zone/unit snapshot.

[VERIFIED] The shared per-frame input is **not parity-safe**: submit cost 511.6 -> 348.2 us (1.10 ->
0.75 ms/tick), but route parity 100% -> **59.1%** (565/956) and readiness 45.5% -> **24.8%**. The
path input is dynamic within a frame (units, resident records, zone), so a frame-start snapshot
changes 41% of routes. The per-search input is parity-correct but costs 512 us and is ready only at
the serial end (45.5%), too late to skip the serial. The worker path is blocked by input dynamism
and timing, not kernel speed; the 30 FPS heavy target remains structurally unmet.

[VERIFIED] The covered ordinary serial searches average **502 us** (543,658 / 1,083), essentially
the same as the **512 us** per-search input build. A worker input costs as much as the search it
replaces; even a free kernel cannot win. The group paths won because their searches are 5-15 ms;
ordinary/closest/attack are 0.5-5 ms and input-bound. The remaining 12.2 ms is input-bound, not
search-bound; the 30 FPS heavy target needs a persistent incremental world state or engine-level
overlap, not another worker/region/cap.

[VERIFIED] Correction: the per-search input drops to **154.6 us** (median 146.2) when the unit facts
are built directly from the object list (no redundant `findObjectByID`) and the resident grid is a
shared empty vector (resident only gates new-record accounting, not the route). Route parity stays
**100%** (1,023/1,023); ready 42.1%. The input is 31% of the 502 us search, not equal to it. The
worker is potentially profitable; the next step is the queue-level prepare/apply commit or a bounded
per-path wait, with the closest/attack searches still separate.

[VERIFIED] The bounded per-path worker commit is **rejected**: with the 154.6 us input and a 400 us
wait, the sample-window path is **16,692 vs 13,722 us/frame** for the group build (1,085 submits,
1,015 accepted, 186 abandoned) and the full run diverges (CRC `9D9A905B...`, commands 981 vs 983,
`zone_mismatch` 50 vs 41). The per-path wait serializes input + wait + serial fallback; it is slower
than the search it replaces. A queue-level prepare/apply is the remaining design.

[VERIFIED] Heavy module sleep attribution (`ZH_ATTR_SAMPLE=1`): **2,508 awake vs 19,124 sleepy**
(88.4% asleep); `l_updates` 9.67 ms sampled (8.4 unsampled); slowest module update 508 us mean
(p95 973); `AIUpdateInterface` is the slowest module in **361/425 frames**. The engine already skips
88% of modules through the sleepy heap; the 8.4 ms is awake AI/physics/weapon work, not traversal.
A dirty/event list cannot remove it.

[VERIFIED] The d3d8to9 wrapper A/B on the staged build was load-confounded and slower (heavy 56.55
vs 43.98 ms, path 20,649 vs 16,399, client/draw worse); removed and system D3D8 restored. Not
promoted.

[VERIFIED] The AI pending/apply split was implemented: prepare-only `internalFindPath`, pathfinder
pending store, `computePath` intercept before the closest fallback, and deferred apply at the next
`doPathfind` dispatch with serial fallback. It diverged (CRC `6BCE4A92...`, commands 927 vs 983,
`search_failed` 117 vs 84) and regressed the sample-window path **17,640 vs 13,722 us/frame** (full
19,987 vs 16,399). The one-frame deferral makes paths stale and triggers re-requests; the deferred
apply costs more than the serial search it skips. Rejected; staged `1EE75D56...`.

[VERIFIED] The same-frame queue batch was implemented (prepare-all in `processPathfindQueue`, one
`applyBatch` at the boundary, AI `applyBatchPath`/`serialBatchPath`) and rejected: CRC `BD4F07ED...`,
commands 877 vs 983 (`goal_width` 164 vs 129, `search_failed` 98 vs 84); sample path **14,651 vs
13,722 us/frame**, full 18,524 vs 16,399. Applying paths at the queue boundary changes the AI's path
timing/order and pays serial fallbacks for misses. Staged `1EE75D56...`.

[VERIFIED] The per-module-type aggregate attempt (`ZH_ATTR_MODULE_LOG`) was too heavy: the
per-update `KEYNAME`/unordered-map accumulation slowed the run to ~127 ms/frame, hit the 25-minute
watchdog at frame ~11,800, and never reached the heavy window; `modules.csv` is empty. The
awake/sleepy counts and slowest-module data remain the valid attribution; a lighter fixed-ID
histogram is required.

[VERIFIED] The fixed-slot histogram (`modulelog3`, frames 16,919-17,399) succeeded: `AIUpdateInterface`
2,570 ms total = **5.34 ms/frame** (63.5% of the top-20 4,044 ms), `TransportAIUpdate` 267,
`WorkerAIUpdate` 229, `ChinookAIUpdate` 120 (AI total ~**6.6 ms/frame**), `ObjectWeaponStatusHelper`
328 (0.68), `PhysicsBehavior` 286 (0.59), the rest <65 ms. Module sum 8.41 ms/frame vs `l_updates`
9.45 sampled (8.4 unsampled). The run kept the group CRC `04C62655` and the 983-row command stream.
The awake update cost is AI-state-machine-dominated, not physics/weapons; the next target is the
`AIUpdateInterface` state machine.

[INFERRED] Threading distance: only the diagnostic 8-lane path kernel pool is threaded; four commit
variants (per-path wait, one-frame pending, same-frame queue batch, shared frame input) all lose or
diverge. Logic, AI, path queue, client and draw remain main-thread. A true multithread needs a
deterministic simulation job system (object/AI/path ordering + CRC) and a render thread, which is a
multi-month engine project, not a local optimization.

## 2026-11-23 - AI sub-phase, per-state, and residual attribution (T-127)

[VERIFIED] `aiphase` (exact `04C62655`, 983 commands) splits `AIUpdateInterface` 5.31 ms/frame
into state machine **5.16**, locomotor 0.68, turret 0.48, bookkeeping 0.10; the timers also fire in
the Transport/Worker/Chinook subclasses, so the AI family total is **6.42 ms/frame**.

[VERIFIED] `aistate` (same CRC/commands) attributes the state total: **`AI_GUARD` 2.06,
`AI_HUNT` 1.25, `AI_IDLE` 1.21**, waypoint-team 0.34, `AI_DOCK` 0.15, rest <0.08. Guard/hunt
delegate to sub-machines, so this is sub-machine work, not a per-frame guard scan
(`GuardEnemyScanRate` defaults to 15 frames).

[VERIFIED] `ZH_LAST_STAND_RESIDUAL` closes the 5.9 ms logic gap (300 ticks): script **5.445**
(sequential 5.06, sides 0.32, team-state 0.07), path queue **11.887** (dispatch overhead 0.16),
players **3.192** (planner 1.412, base building 1.333 inside it; team generic scripts 1.727);
terrain/CRC/stats/recorder/commands 0.02. `script_search` 2.798 is synchronous pathfinding issued
from scripts; team generic actions cost 1.630 with conditions only 0.062.

[INFERRED] Clean heavy 38.65 ms split: path 16.6 (43%; queue 11.9 + script-issued 2.8 + other ~1.9),
AI modules 8.4, script evaluation 2.6, player/team scripts 3.2, partition 1.2, client 4.9 with draw
4.4 nested (the earlier "client+draw 20.7" double-counted draw). The 30 FPS heavy target is **5.3 ms
away on the clean run**, not 10.7 ms. Unturned: team generic actions 1.6, script evaluation 2.6,
guard/hunt/idle sub-machines 4.5, player/base bookkeeping 1.7. Next: per-script attribution of the
team generic actions, then the guard/hunt sub-machine states.

[VERIFIED] Team-action labels (map-load deterministic): the nine hot `GLA Attack Sequence
Center/Back/Flank` scripts execute **`TEAM_STOP` (175)**; others are
`TEAM_APPLY_ATTACK_PRIORITY_SET` (43), `SET_RANDOM_TIMER` (147), `TEAM_GUARD_AREA` (204),
`TEAM_EXIT_ALL` (55). `doTeamStop` re-issues `groupIdle` to every member every frame; an
already-idle member re-enters `AI_IDLE` and resets its sleep timer.

[VERIFIED] Deduping idle-on-idle (`ZH_IDLE_DEDUPE=1`) reaches `frame=17402 sync=ok` but diverges
(CRC `969FAFE4`, commands 2,722 vs 983) and is much slower: logic 31.75 -> **53.09 ms**, `l_ai`
15.24 -> 32.72, path 15,088 -> **28,510 usec**, expansions 6,758 -> 10,201; only `l_updates` falls
(8.84 -> 6.75). Rejected: the repeated `TEAM_STOP` is load-bearing suppression. The
`ZH_MOVE_DEDUPE` candidate is built but not measured. The earlier concurrent `teamtypes`/
`movededupe` launches were invalid (second process while `Generals.exe` was in use); only the
map-load labels are used.

## 2026-11-24 - Target scans and script dedupes (rejected)

[VERIFIED] `guardhunt` (exact `04C62655`/983 commands) attributes the AI states: GUARD 2.034 =
sub-state IDLE 1.795 + OUTER 0.108 + RETURN 0.076, inner-target scan **1.785** (88%); HUNT 1.233 =
enemy scan **0.637** + `AI_ATTACK_OBJECT` 0.531; IDLE 1.192 = mood scan **1.096** (92%). The three
`PartitionManager` scans are **3.52 ms/frame, 68% of the 5.16 ms AI state cost**.

[VERIFIED] Three behavior-preserving candidates were built and measured with exact CRC/commands:
`ZH_MOVE_DEDUPE` path 15,088 -> 15,985, `l_ai` 15.24 -> 16.27, logic 31.75 -> 32.87;
`ZH_SCAN_FILTER_FIRST` scans 3.517 -> 3.439 (-0.078), GUARD 2.034 -> 2.086;
`ZH_GROUP_MOVE_DEDUPE` (2-frame team/waypoint cache in `doMoveToWaypoint`) path 15,088 -> 16,032,
`l_ai` 15.24 -> 16.28, logic 31.75 -> 33.07, with expansions 6,758 and cache 3.1/0.6 identical.
None improves the frame; the scan cost is cell/filter traversal, and the group cache already
absorbs repeated script moves.

[INFERRED] No local behavior-preserving hotspot remains. The path budget is the genuine ~0.6 new
group searches/frame plus unit requests; 30 FPS needs a deterministic path/AI job system, a render
thread, or a deliberate gameplay trade (path budget, scan rate, route reuse) that requires a live
playtest decision.

## 2026-11-24 - Job-system gate: region freeze passes; path-budget trade rejected

[VERIFIED] `pathbox` (exact `04C62655`/983 commands) recorded the allocated-cell box of 9,568 outer
searches (19.9/frame): mean 2,006 cells (p50 63, p90 5,904, max 41,328); per-frame per-request sum
39,911 cells, exact rectangle union **18,567 cells** (p90 36,580). A union freeze is ~**0.19
ms/tick at 10 ns/cell** (0.09 at 5, 0.28 at 15) and passes ADR-0027's `< 0.5 ms/tick` gate; a
per-request freeze is 0.40 ms (marginal). The remaining blocker is `internalFindPath`'s ~10
mutated `Pathfinder` members plus the per-cell `m_info` scratch, which need a private
`SearchContext` over the shared grid.

[VERIFIED] The scenario-limit trade (`ZH_PATH_CELL_BUDGET=3000`, `ZH_PATH_SEARCH_CAP=3000`)
diverges and ends the match at ~frame 16,513 (`replay_finished`), 900 frames before the 17,402
checkpoint; the heavy window never occurs. Path starvation changes the outcome; the budget is not
a usable smoothing knob. Rejected.

## 2026-11-24 - SearchContext slice reverted; dispatch grid proved mutable

[VERIFIED] The open/closed-list thread-local slice kept exact `04C62655`/983 commands, but the
control classifies it as a regression: `baseline-now` (pure staged build) heavy **37.69 ms /
32.09 logic / 15,232 usec path** vs the slice **38.72 / 32.95 / 16,047** (+5.4% path from the
dynamic-init TLS guard; the control is only ~1% above `kernelreplace2`). Slice reverted; a lane
context must be a plain per-lane pointer.

[VERIFIED] A dispatch-scoped counter at `nativePageSnapshot::changed()` (every static-cell write)
shows the grid is **mutable mid-dispatch**: 26,888 writes in the heavy window (77.5/frame, p50 64,
p90 165, max 356) on 347/481 frames, from `updateGoal`/pinch/zone updates after each request. Later
searches see earlier requests' static changes, so frozen-input parallel searches cannot be exact
(the 59.1% shared-input parity is explained).

[VERIFIED] Disjoint-extent 2-lane batching from the `pathbox` boxes: only 67/481 frames (14%) fully
packable, second lane covers 23% of the work, ideal speedup **1.30x** (~3 ms of 15.2 ms). Not
enough alone.

[INFERRED] The lane dispatcher is blocked by inter-request static mutation, not the scratch lists.
Exact parallelism needs each request's ~77 writes propagated into the frozen copy in order (page
diff) or serial live-grid searches; prefetch-at-command-issue has the same staleness. Multi-session
architecture task; the 30 FPS heavy target remains unmet.

[VERIFIED] Predictable-box packing (start/goal rectangles + 4/8/16-cell margin) is weaker than the
post-hoc boxes: 49/34/26 of 481 heavy frames fully pack into two lanes (10/7/5%), with a
**1.27-1.29x** path ceiling. [INFERRED] Even perfect 2-lane disjoint dispatch saves only ~3.2 ms
(38.65 -> ~35.5 ms, 28.2 FPS) and requires the full prepare/apply + per-lane SearchContext
refactor. It cannot reach the 30 FPS target; that needs a render thread (client 4.9 ms) or a
page-diff ordered worker, both multi-session. Continuing requires a scope decision.

## 2026-11-24 - Per-search unit memo promoted (first behavior-preserving path win)

[VERIFIED] Enabled the built but unused `nativeUnitMemo` (per-search cache of
`TCheckMovementInfo`, invalidated on static-cell changes, 1-in-256 self-check). Exact
`04C62655`/983 commands; expansions identical. Back-to-back same-build pair (`memooff` ->
`unitmemo`): path **16,154 -> 14,793 usec (-8.4%)**, logic **32.97 -> 31.58**, `l_ai`
**16.39 -> 14.97**. The memo log: 6.04M calls, 5.06M hits (83.7%), 19,408 checks, **0
mismatches**. A third run of the promoted default (`memodefault`, no env) kept exact CRC with
path 14,227 and logic 30.35.

[VERIFIED] Promoted default-on (`ZH_NATIVE_UNIT_MEMO=0` disables); candidate
`build/engines/t120-memo-default.exe` (`C9147884...`). The staged playtest remains
`1EE75D56...`. Clean heavy ~38.65 -> ~37.2 ms (~27 FPS); 30 FPS remains unmet.

[VERIFIED] Parallel-safety write test: both page-snapshot runs diverged (`BD4F07ED`, 109,209-byte
command stream vs 122,319), with or without the early-queue probe, so the page-snapshot diagnostics
are not behavior-neutral and the write data is indicative. In that trajectory, 219 frames fully
pack into two disjoint boxes; **188 have no cross-lane static writes**, 31 do (630/1,675 writes,
37.6% of writes in packable frames). [INFERRED] Disjoint lanes are clean for most packable frames,
but 5-14% packing and a 1.27-1.29x ceiling give only ~2-3 ms; exact dispatch still needs per-lane
state and page-diff ordering, so it is not the path to 30 FPS.

## 2026-11-24 - No-draw ceiling: render thread has the headroom

[VERIFIED] Same-session heavy pair with the promoted memo build, exact `04C62655`/983 commands:
`baseline-charger` interval 39.16 ms (logic 31.19, client 7.40, draw 6.67, path 14,438) vs
`nodraw` (`ZH_PROFILE_WARMUP_UNTIL=17402`) **29.22 ms (34.2 FPS)**, logic 28.44, client 0.51,
draw 0.00, path 14,169. The draw is simulation-neutral; the interval drop is 9.94 ms (6.67 draw +
a lower logic/`l_updates` regime).

[INFERRED] The conservative direct-overlap projection is 39.16 - 6.67 = **32.49 ms (30.8 FPS)**;
the measured no-draw ceiling leaves ~4 ms for thread synchronization. A render thread with
device-thread ownership and a double-buffered drawable snapshot can reach 30 FPS. Implementation is
multi-session; no 30 FPS claim until a clean heavy run of the threaded build.

## 2026-11-24 - Render-thread handshake validated (milestone 1)

[VERIFIED] `ZH_RENDER_THREAD=1` implements a bounded two-frame slot + condition-variable handshake
with serial fallback; the real `DRAW()` is skipped and the worker sleeps `ZH_RENDER_WORK_US` to
model a present-bound draw. A startup deadlock was found and fixed: the worker decremented
`pending` without notifying the submit waiter (`ZH_RENDER_WORK_US=0` masked it because the main
thread never waited). The fix adds `m_cv.notify_all()` after the decrement.

[VERIFIED] Heavy pair, exact `04C62655`/983 commands: `baseline-charger` 39.16 ms vs `nodraw`
29.22 ms vs `renderhandshake` (6.7 ms worker) **29.24 ms** — handshake overhead **+0.02 ms (0.1%)**,
the present-bound worker fully hidden. Binary `t120-rt-handshake.exe` (`9A1F6C66...`). Not a
performance candidate; no 30 FPS claim.

[INFERRED] Next: drawable/display snapshot parity on the main thread, then device/present
ownership, then heavy validation of the threaded build.

## 2026-11-24 - Render transform snapshot (serial slice)

[VERIFIED] `ZH_RENDER_SNAPSHOT=1` captures each drawable's `Matrix3D` into an ID-indexed side table
immediately before DRAW; `Drawable::draw` consumes the captured matrix instead of the live object
transform. Serial heavy replay: exact `04C62655`/983 commands, checkpoint 17402; draw 4.51 ms in
the fast client regime vs 6.67 ms in `baseline-charger`'s slow regime, so the overhead sits inside
the known client bimodality (~1,000 matrix copies + O(1) lookups).

[VERIFIED] A member-in-Drawable variant crashed early (~frame 5,000, no checkpoint, empty stdout)
because the Drawable layout is ABI-shared with the mod DLL; reverted. The ID-indexed side table
preserves the layout and is the retained design.

[INFERRED] Next: capture at the client-update boundary, draw from the snapshot on the handshake
worker, then move device/present ownership. Opacity/stealth, effects, terrain, particles, shadows,
water, camera views, and UI remain live reads and need snapshot coverage before the worker owns the
real DRAW.

[VERIFIED] `ZH_DEFER_UNIT_READS=1` (defer zone/height reads until the cheap neighbor checks pass) is
behavior-identical (`04C62655`/983 commands) but measured heavy path **15,194 usec** versus
14,208-14,438 in recent runs; not promoted (neutral-to-worse, within run variance).

## 2026-11-24 - Device-thread draw: serial works, overlap needs the snapshot

[VERIFIED] `ZH_RENDER_THREAD=1` + `ZH_RENDER_DEVICE=1` + `ZH_RENDER_WAIT=1`: the worker calls
`TheDisplay->DRAW()` while the main thread waits; the 300-frame replay completes with exact
CRC/commands. D3D8 tolerates the worker device call when serialized.

[VERIFIED] Removing `ZH_RENDER_WAIT` (overlap) crashes immediately after the first submit (empty
attr, stderr stops at `submit 1`). Drawing live drawables/objects while the main thread updates
them is unsafe without the full render-state snapshot.

[INFERRED] The handshake, serial transform snapshot and device-thread call are validated. The full
snapshot (opacity/stealth, effects, terrain, particles, shadows, water, camera views, UI) is the
remaining prerequisite for overlap; 30 FPS still waits for a clean threaded heavy run.

## 2026-11-24 - First full overlap: 37.20 ms, draw is CPU-bound

[VERIFIED] `ZH_RENDER_THREAD=1` + `ZH_RENDER_DEVICE=1` + `ZH_RENDER_WAIT=1` (submit after the client
update, wait at the end) runs the worker draw during logic for the full 17,402 replay with exact
`04C62655`/983 commands. Heavy **37.20 ms (26.9 FPS)** vs `baseline-charger` 39.16 (25.5); client
0.49, draw 0.00 (main), but logic **31.19 -> 36.44** and path 14,438 -> 15,726. Net **-1.96 ms**.

[INFERRED] The draw is **CPU-bound, not GPU-wait-bound**; the worker's D3D8 submission competes
with logic on this 4-core CPU, so hiding 6.7 ms of draw recovers only ~2 ms (logic slows ~5 ms).
A render thread alone cannot reach 30 FPS; reducing the draw's CPU cost (batching/instancing) or
genuinely idle capacity is required. The 30 FPS target remains unmet.

## 2026-11-24 - CPU draw profile: scene 2.1 ms, HUD text 1.2 ms

[VERIFIED] Heavy-window draw split (serial, exact `04C62655`/983): `drawViews()` **2.10 ms**;
in-game UI 1.33-2.22 ms, of which `postWindowDraw` 1.63 (player info **0.715**, game clock
**0.435**, render FPS 0.060, system time 0.030) and `winRepaint` 0.553; preDraw/hints/postDraw
~0.03; client draw 0.001; mouse 0.024.

[INFERRED] There is no single cullable waste in the draw: it is scene rendering plus normal HUD
text. A behavior-preserving string cache saves only ~0.1-0.2 ms; the scene needs W3D
batching/instancing (major device-layer project). Together with the overlap result, 30 FPS is not
reachable by a local draw tweak; the heavy frame remains ~37-39 ms (~27 FPS).

[VERIFIED] Shadow split inside `drawViews()`: volumetric **0.363 ms/frame**, projected 0.057,
prepare 0.000. Volumetric shadows are ~17% of the 2.1 ms scene; culling/disabling them is at most
~0.36 ms and a visual trade.

[VERIFIED] Scene internal split: visibility 0.152, per-object frame update 0.006, terrain 0.284,
visible render loop **0.038** with only **120 visible render objects/frame**. The remaining
~1.3-1.6 ms of `drawViews` is WW3D/DX8 flush/state/present overhead, not per-drawable geometry.
[INFERRED] Drawable batching/instancing cannot remove that overhead; the 30 FPS target needs a
renderer/DX8-pipeline change (or accepting the limit), not a batching tweak.

[VERIFIED] WW3D render tail: camera 0.003, clear 0.000, WW3D mesh flush **0.006**, sorting flush
**0.002**, present/`End_Scene` **0.494**. Draw calls and state changes are negligible.
[INFERRED] There is no behavior-preserving batching/state-elimination win left in the draw; the
remaining cost is scene/present/HUD overhead. 30 FPS needs a renderer/present pipeline project or
accepting the limit.

## 2026-11-25 - Windowed triple buffering rejected

[VERIFIED] Same-build heavy pair, exact `04C62655`/983 commands: windowed `BackBufferCount=2`
gives interval **36.40 ms**, client 4.84, draw 4.35; the off build gives **36.32 ms**, client 4.74,
draw 4.24. Triple buffering is +0.08 ms (neutral-to-worse), not promoted; the gate stays off.

[VERIFIED] `baseline-charger` 39.16 ms was a slow-present run (client 7.40/draw 6.67); the
fast-regime heavy is **~36.3 ms (27.5 FPS)**. The run-level client bimodality remains the dominant
measurement variance; 30 FPS is still unmet.

## 2026-11-25 - Correction: the real scene flush is 1.06 ms

[VERIFIED] `RTS3DScene::Render` calls its own `Flush` (the real mesh/draw submission) after
`Customized_Render`. Timed in the heavy window: color passes 0.000, light env 0.001, custom render
0.549, **flush 1.060 ms** (120 visible objects), sum 1.61 ≈ `scene->Render` 1.66. The `WW3D::Flush`
measured earlier (0.006) is a second, empty flush; the "draw calls negligible" conclusion was a
misattribution.

[INFERRED] Draw-call batching/state work can target the 1.06 ms flush, but halving it saves only
~0.5 ms — still short of the ~3 ms gap to 30 FPS. The corrected draw is: custom 0.55 + real flush
1.06 + present 0.57 + HUD ~1.2 + repaint 0.55.

## 2026-11-25 - Flush internals: occluded/stencil is the largest stage

[VERIFIED] `RTS3DScene::Flush` heavy stages: occluded/stencil **0.446 ms**, particles 0.133, sorted
translucent 0.087, translucent 0.036, water/static lists 0.010, trees 0.001, opaque mesh flush
0.000; shadows are ~0.42 separately. The stencil-occlusion pass is the largest single stage.

[INFERRED] The flush is diffuse, not one batchable stream: occluded/stencil 0.45 (a visual feature
— behind-building markers), shadows 0.42, particles 0.13. No single behavior-preserving flush
reduction approaches the ~3 ms gap; 30 FPS remains unmet at ~36.3 ms fast-regime.

## 2026-11-25 - The GTX 1650 Ti was never used: D3D8 vs D3D9 is the whole difference

[VERIFIED] Measurement environment, previously unrecorded: every run in this session used the
project's `performance` options profile -- 1920x1080, `AntiAliasing = 0`, `StaticGameLOD = Custom` /
`IdealStaticGameLOD = Low`, `TextureFilter = Bilinear`, `AnisotropyLevel = 2`, with shadow volumes,
shadow decals, 5000 particles, heat effects, extra animations, soft water, trees and building
occlusion on. Retail-High equivalent (AA 8 + High LOD) was never measured.

[VERIFIED] The engine ran on the **Intel UHD iGPU** the whole time. While a replay ran, `nvidia-smi`
showed the dGPU at 0% / 9 MiB with no `Generals.exe` process, and the game's `engtype_3D` instance
was busy on the non-NVIDIA adapter. Three attempts to move it failed: the `NvOptimusEnablement`
export (verified in the PE by `dumpbin`, RVA `0x67F4D8`), fullscreen, and a per-app
`GpuPreference=2` Windows setting. The engine creates a **native D3D8** device and this NVIDIA
driver does not route D3D8 to the discrete GPU.

[VERIFIED] The `d3d8to9` proxy (v1.16.0, `122928CF...`) does route it: `nvidia-smi` then lists
`...last-stand-replay\Generals.exe` as `C+G` at 32% / 74 MiB. Matched-state heavy pair (same binary
and flags, calibration 7,704 us Intel vs 7,697 us GTX), exact `04C62655`/983:

| Stage | Intel D3D8 | GTX D3D9 | Delta |
|---|---:|---:|---:|
| occlusion/stencil | 6.042 | 0.873 | -5.17 |
| `views` total | 11.214 | 3.227 | -7.99 |
| client / draw | 13.53 / 12.55 | 5.32 / 4.49 | -8.2 / -8.1 |
| logic | 32.85 | 31.00 | -1.85 |
| **heavy interval** | **46.87** | **36.80** | **-10.07** |

[INFERRED] The discrete GPU is worth ~8 ms of draw and ~1.9 ms of logic (less memory contention),
but 36.80 ms is still 3.5 ms short of 33.33. On the GTX the occlusion pass costs only 0.87 ms, so
the `ZH_SKIP_OCCLUDED` trade loses most of its value there; the remaining wall is logic (~31 ms).

## 2026-11-25 - Measurement variance is larger than the optimizations; calibration + interleaved A/B

[VERIFIED] Identical binaries give very different heavy windows. Same build and flags, full visuals:
`allcontrol` 37.12 ms (logic 27.23, client 9.47, draw 8.70) vs `dgpucontrol` 46.87 ms (logic 32.85,
client 13.53, draw 12.55). The 30.5 FPS trade run did not reproduce: `alltrades` 32.76 ms vs
`alltrades2` 42.19 ms (logic 37.09, path 16,308 us); exact CRC in both.

[VERIFIED] Added `ZH_CALIB_LOG`: a fixed 2M multiply-add workload, logged every 100 frames, whose
elapsed time tracks effective CPU speed. It varies **1.43x** inside one run (7,208-10,337 us) and
correlates weakly with frame logic (corr -0.10 over 9,200 frames). Single-run deltas below ~2 ms
are therefore not evidence; a 30.5 FPS claim needs repeats or pairing.

[VERIFIED] Added `ZH_AB_INTERLEAVE=1`: each visual-trade gate flips on a schedule, so both
conditions are sampled in one run and machine drift cancels. One-frame alternation proved invalid
(it aliases through the present pipeline: the gates worked in `flush` logs but `draw`/`client`
landed on the *following* frame), so the schedule is 60-frame blocks. Client-only gates, so the
exact `04C62655`/983 CRC gate still applies.

[VERIFIED] The registry per-app GPU preference was removed; the game still ran on the GTX
(`nvidia-smi` 30% / 74 MiB), so the `d3d8to9` proxy alone is sufficient and portable.

## 2026-11-25 - Block-interleaved A/B on the GTX: the trades are worth ~4.5 ms

[VERIFIED] `ZH_AB_INTERLEAVE=1` flips the three trade gates in 60-frame blocks (one-frame
alternation was aliased by the present pipeline). One GTX run, heavy window, exact `04C62655`/983:
skip blocks **32.41 ms** (logic 28.62, client 3.34, draw 2.42, `views` 1.15) vs render blocks
**40.91 ms** (logic 32.81, client 7.52, draw 6.64, `views` 5.43); flush occluded 0.000 vs 2.226,
particles 0.007 vs 0.366, sorted 0.001 vs 0.784.

[VERIFIED] The heavy window ramps (early blocks 23-28 ms, late 38-49 ms), so the aggregate -8.51 ms
overstates the trade; stable adjacent pairs differ by **+4.46, +4.47, +5.89 ms**. The trade is
~4.2 ms of client/draw plus ~4.2 ms of logic contention.

[INFERRED] GTX + all three trades = **32.41 ms (30.9 FPS)** on the skip blocks with exact CRC -- the
first paired, in-run result above 30 FPS. It costs occluded rendering, volumetric shadows and
particles, and peak blocks still reach ~43 ms, so frame pacing is not smooth.

[VERIFIED] Particle prioritisation (the external ZHE lead) needs no engine work: the engine already
has per-system priorities, a `Priority =` INI field, `m_maxParticleCount` +
`removeOldestParticles(excess, priority)`, and dynamic-LOD particle thresholds. With
`DynamicLOD = no` the engine forces the very-high level, so the priority skip is inactive. All
particles cost ~0.9 ms on the GTX, so this cannot close the gap.

[VERIFIED] The registry per-app GPU preference was removed; the game still ran on the GTX, so the
`d3d8to9` proxy alone is sufficient and portable.

## 2026-11-25 - Correction: clean all-trades GTX run is 28.9 FPS, not 30.9

[VERIFIED] All three trades always on (no interleave), GTX, calibration 7,463 us, exact
`04C62655`/983: heavy mean **34.59 ms (28.9 FPS)**, p50 31.65, p90 54.99, p99 101.68; logic 30.99,
client 3.26, draw 2.34. Full visuals, same GPU (`wrapped`, calibration 7,697): 36.80 ms, logic
31.00, client 5.32, draw 4.49.

[INFERRED] At matched logic (31.0) the three trades are worth **2.2 ms**, not the 4.5 ms read from
the block-interleave skip population, which happened to sit at logic 28.62. The block figure
(32.41 ms / 30.9 FPS) is therefore **not** a clean all-trades result; the clean mean is 28.9 FPS.
p50 (31.65 ms) is inside the 33.33 budget -- the mean is dragged by spikes (p90 55 ms). 30 FPS
remains unmet.

## 2026-11-25 - HUD text cache: -0.06 ms; the heavy mean is a 49-frame tail

[VERIFIED] `ZH_UI_TEXT_CACHE=1` (cache the game-clock and system-time strings; they only change once
per second) measured block-interleaved on the GTX at full visuals, exact `04C62655`/983: client
**3.254 vs 3.317 ms (-0.062)**, in-game UI 0.594 vs 0.612 (-0.017). Real but negligible; the
behaviour-preserving HUD avenue is closed.

[VERIFIED] The heavy window is tail-driven. In both GTX runs the slowest 49 of 481 frames
(`wrapped` interval 78.9 ms, logic 72.8, `l_ai` 33.5, path 26,872 us) carry **22-23% of the total
time**, while the other 432 run at 32.0 ms (logic 26.3, `l_ai` 12.8, path 13,297). The spikes are
not a request burst (23.0 vs 19.5 requests) but single heavy searches: frame 17,343 has one
48.9 ms search (17,059 expansions), frame 17,280 one 50.0 ms search.

[INFERRED] **30 FPS is a tail problem.** Flattening the slowest 10% to fast-frame cost would save
~4.8 ms (`wrapped` 36.80 -> ~32.0 = 31 FPS; `allgtx` 34.59 -> ~29.8 = 33.5 FPS), of which ~2.1 ms
is AI-state work and ~1.5 ms path search. Remaining levers: an expansion bound on the
ordinary/internal search (behaviour trade; the closest-search cap is precedent) or AI/path burst
smoothing.

## 2026-11-25 - Ordinary-search cap rejected: the retry storm costs more than the spike

[VERIFIED] `ZH_PATH_SEARCH_CAP=10000` (existing gate, default unlimited) on the GTX at full
visuals: heavy **45.00 ms (22.2 FPS)** vs 36.80, logic **41.73** vs 31.00, p90 69.5 vs 56.3; CRC
`99BEDEC5...`; commands **2,331 vs 983**, `zone_mismatch` **652 vs 41**.

[INFERRED] A capped search is re-issued immediately, so one 50 ms search becomes several short
searches plus extra AI/command work. The tail cannot be removed by bounding the solver; it needs a
faster solver (incremental/parallel, multi-session) or a scenario-level change. 30 FPS at unchanged
settings is not reachable with the local levers now measured.

## 2026-11-25 - Packaged configuration staged with an opt-in performance profile

[VERIFIED] The verified engine is staged as `build/engines/t112-playtest.exe` and copied to
`game/last-stand-replay/Generals.exe`, SHA-256 `35442E24...`; build output, staged copy and game copy
are byte-identical. Memo default-on; `d3d8to9` v1.16.0 (`122928CF...`) installed in the replay copy.

[VERIFIED] `tools/play-t120.ps1 -Performance` sets the three visual-trade flags opt-in; without it
the build keeps full visuals. Measured on the GTX: heavy **34.59 ms / 28.9 FPS** vs 36.80 / 27.2,
whole run **37.4 vs 34.7 FPS**.

[VERIFIED] A 300-frame smoke run of the staged build with the profile reached `frame=300 sync=ok`
at 1920x1080 (`SMOKE_EXIT=0`) and left the staged hash unchanged. GTX placement is by identity: the
binary is byte-identical to the build output that `wrapped`/`allgtx` ran while `nvidia-smi` listed
`Generals.exe` as `C+G`.

## 2026-11-25 - Solver route chosen; group workload is 3 goals over 983 searches

[VERIFIED] The heavy-window formation log (983 rows, all in 16919-17399) contains only **3 distinct
destinations** (452/271/260 requests) and **55 distinct (start, goal) pairs**. The redundancy is in
goals, not starts.

[INFERRED] This is the textbook case for a goal-rooted field, but reuse is blocked by *dynamic unit
occupancy*, not goal count: TTL-30 reuse measured slower than TTL-20 (44.78/54.26/48.03 vs
36.12/40.63/37.66), and the route-cell guard rejected 596 of 777 exact-route opportunities. A faster
solver must therefore handle dynamic costs (incremental/D* Lite) or rebuild on an occupancy stamp.
First milestone: measure how often the local occupancy stamp changes along the 55 corridors, which
bounds safe reuse.

## 2026-11-25 - Group-cache misses are a one-frame TTL shortfall

[VERIFIED] Added `ZH_GROUP_KEY_LOG` (per-call cache predicates). The heavy window has 1,764 calls,
**1,472 hits (83.4%)** and 292 misses; the revision is constant (563), so revision changes cause
none. The 292 split into **224 same-key TTL expiries** (191 at age exactly 21 frames against a
20-frame TTL, 25 at age 24) and 68 different-key slot collisions.

[INFERRED] The 55 routes recur on a ~21-frame cadence and the TTL expires one frame early. TTL 24
should capture ~218 of 224 re-searches, worth several ms/frame. Safety depends on how often the
recomputed route differs from the cached one -- the next measurement. (An earlier TTL-30 test was
slower, but it predates the committed group kernel, so it is being re-tested at TTL 24.)

## 2026-11-25 - TTL 24 rejected; the 292 group misses are necessary work

[VERIFIED] `ZH_GROUP_PATH_CACHE_TTL=24` (GTX, full visuals): heavy **42.91 ms / 23.3 FPS** vs 36.80,
p50 36.74 vs 33.57, p90 69.5 vs 56.3, logic 34.10 vs 31.00, path 16,424 vs 14,680 us; cache hits
unchanged (1,476 vs 1,472), misses up (315 vs 292); CRC `F64D5008` vs `04C62655`, commands 966 vs
983 (`goal_width` 51 vs 129).

[INFERRED] A 21-frame-old route no longer matches the recomputation, so reuse diverges the
simulation and yields a different request mix. The 20-frame TTL is the safety boundary, not an
off-by-one bug, and the 292 misses are necessary recomputations. The solver must make each
re-search cheaper (incremental/D* Lite state reuse across the ~21-frame cadence) or parallel;
extending cache lifetime is closed.

## 2026-11-25 - Prefetch worker capped at 0.5 ms; the budget is ordinary searches

[VERIFIED] The group-kernel sync log (`ZH_GROUP_KERNEL_SYNC`, active with
`ZH_GROUP_KERNEL_REPLACE=1`) shows 90 kernel runs in the 481-frame heavy window, 243.5 ms total =
**506 us/frame** (p50 1,350, p90 9,754, max 16,542), against a **14,680 us/frame** path budget --
**3.4%**. A prefetch worker that eliminates all group-search time therefore buys at most ~0.5 ms.

[INFERRED] The budget is the ~20 ordinary/closest/attack searches per frame (~500-700 us each) with
0% exact repeats, so they cannot be prefetched. The only remaining use of a worker for them is
within-frame parallelism, whose blockers are already measured (per-search input 155 us at 100%
parity but 42.1% ready; bounded per-path wait slower than serial at 16,692 vs 13,722 us/frame, CRC
`9D9A905B`). Milestone 2 as specified cannot close the gap.

## 2026-11-25 - Admissible heuristic rejected: the overestimate is load-bearing

[VERIFIED] Implemented `ZH_HEURISTIC_ADMISSIBLE=1` in both `PathfindCell::costToGoal` (serial) and
`workerGroundSearch::heuristic` (kernel): retail `10*max + 5*min` vs the admissible octile
`10*max + 4*min` (orthogonal 10, diagonal 14). GTX full visuals: heavy **56.60 ms / 17.7 FPS** vs
36.80, logic 53.13 vs 31.00, `l_ai` 33.12 vs 14.94, path 31,332 vs 14,680 us, expansions 10,955 vs
6,759 (+62%); CRC `F9AAA3E5`; commands 2,794 vs 983 (`zone_mismatch` 954 vs 41).

[INFERRED] The overestimate is a deliberate greediness/optimality trade and is load-bearing. An
admissible bound expands far more nodes and changes routes, causing mass re-planning. This closes
the last algorithmic lever on the path budget; everything left is a redesign.

## 2026-11-25 - Page-diff validation is not the worker blocker (8%)

[VERIFIED] The existing page-diff validation shadow (495 claimed jobs, 2026-11-20 log) resolves as
307 accepted with exact `match=1` (62%), 133 unknown-unit (27%, correctly moot), **40
changed-pages (8%)**, 15 unfinished (3%). Validation cost 2.2 us accepted / 6.6 us changed vs a
0.3-0.7 us reference.

[INFERRED] Page-diff propagation is a minor failure mode, not the blocker; object lifetime (27%) and
readiness (3%) dominate, and 89% of jobs resolve correctly. The redesign's first slice should target
readiness/apply order, not page-diff replay. Numbers predate the current build and need re-verifying
on the heavy window.

[VERIFIED] Artifact check: the newer group shadow logs are unusable -- `groupshadow-heavy/frozen.csv`
has 0 rows and `groupshadow-heavy2/frozen.csv` is a placeholder (constant `usec=350`, empty
`ready`/`match`, lane always 0). The 2026-11-20 worker log is the only usable lane data in the tree.

## 2026-11-25 - Current-build lane validation confirmed (page-diff still ~7%)

[VERIFIED] The lane shadow needs all three switches (`ZH_NATIVE_PAGE_LOG` + `ZH_EARLY_QUEUE_LOG` +
`ZH_NATIVE_WORKER_LOG`); with only the worker log it writes a header-only file. On the staged
`35442E24` engine: 973 validation events = **756 accepted with exact match (77.7%)**, 139
unknown-unit (14.3%), **68 changed-pages (7.0%)**, 10 unfinished (1.0%); costs 1.5 us accepted /
5.1 us changed.

[VERIFIED] The shadow is not parity-neutral: the run diverged to CRC `BD4F07ED` (the queue-batch
signature), so these are mechanism numbers from a perturbed trajectory.

[INFERRED] Page-diff is ~7% on both builds (8% in 2026-11-20), acceptance rose from 62% to 77.7%,
and readiness loss is 1%. A worker redesign should target object lifetime and apply order/worker
efficiency, not page-diff replay.

## 2026-11-25 - The lane shadow diverges from the page snapshot alone

[VERIFIED] Bisect of `BD4F07ED`: the queue probe plus worker log **without** the page snapshot is
exact (`04C62655`, `laneshadow2`); adding only `ZH_NATIVE_PAGE_LOG` (no worker) gives `BD4F07ED`
(`laneshadow4`); page+queue+worker also gives `BD4F07ED` (`laneshadow3`). The worker threads are not
implicated; the page-snapshot path alone perturbs the simulation.

[INFERRED] Reviewed suspects are read-only (`capture()` accessors are null-safe; the `changed()`
memo-invalidation hook fires in both cases), so the cause is likely heap/allocation interaction or
write-hook ordering. Consequence: both lane-validation splits (62/27/8/3 and 77.7/14.3/7.0/1.0) are
mechanism-only, and a real worker parity gate must run with the shadow off.

## 2026-11-25 - Page-snapshot divergence is environmental, not corruption

[VERIFIED] `pages.csv` audits the frozen copy against the live grid at 15 checkpoints in
`laneshadow4`: **0 mismatches everywhere**, with `changed_cells` 452-655 between snapshots. The
snapshot is faithful; no writes are lost.

[INFERRED] With `capture()` read-only and the audit clean, the `BD4F07ED` divergence is an
environmental side effect of the diagnostic (heap/timing shift from a 286-page grid), not a
removable state mutation. The lane shadow therefore cannot be a CRC-exact oracle, and its splits stay
mechanism-only -- which does not block the solver, because a real worker must gate with the shadow
off and page-diff is ~7% by two independent logs.

## 2026-11-25 - Cumulative engine patch regenerated; staged build restaged

[VERIFIED] `engine/patches/current-engine.patch` regenerated from a **pristine worktree**
(`git worktree add --detach HEAD`) with the working tree copied over, so the vendor checkout's own
dirty state was never touched. Result: **659,830 bytes, 102 files, SHA `F1B90106...`** (previous:
161,118 bytes). A `GameLogic.cpp.before` backup file in the source tree was excluded; it alone was
6,416 lines and would have inflated the patch.

[VERIFIED] Validation: `git apply --ignore-space-change --check` exits 0 on a clean `HEAD` worktree,
and applying it reproduces `GroundSearch.h`, `AIPathfind.cpp` and `GameEngine.cpp` byte-identically
(SHA-256 equal). Both temporary worktrees were removed; the vendor checkout is untouched.

[VERIFIED] Restaged `build/engines/t112-playtest.exe` and `game/last-stand-replay/Generals.exe` to
**`8A76D607...`**, the build that includes the gated closest-kernel support and was verified at exact
`04C62655`/983. `d3d8to9` (`122928CF...`) remains installed.

## 2026-11-25 - Closest shadow built and measured: 74% non-trivial endpoint parity

[VERIFIED] `ZH_CLOSEST_SHADOW` runs the frozen kernel with `closest.enabled` alongside the serial
`findClosestPath` and logs start/goal/radius, serial nodes+cost, kernel steps/cost/usec and both end
cells. It is **CRC-neutral** (exact `04C62655`/983), so it can run in normal replays.

[VERIFIED] Whole replay: 847 calls, kernel returned a chain on 100%; endpoint match 68% overall and
**74% for the 572 calls with >1 kernel step**; cost match 0% (different cost accounting; sample
serial 5 vs kernel 0); 32% of calls return a single step. Kernel p50 5 us / p90 31 us. Heavy window:
56 calls, endpoint match **55/56 (98%)**, cost match 0.

[INFERRED] The harness is now the instrument for the port. Next: classify the 26% non-trivial
mismatches by distance, and replace the cross-definition cost comparison with a like-for-like one.

## 2026-11-25 - PGO profile captured; optimisation paused on request

[VERIFIED] Instrumented link (`CMAKE_EXE_LINKER_FLAGS=/LTCG:PGInstrument`, objects already `/GL`,
`pgort140.dll` alongside) trained on the full replay: `frame=17402 sync=ok`, CRCs identical to every
control run (`D6BD7CEA` at 17,300, `45252FE3` at 17,400), `commands.csv` 122,319 bytes. Profile
`generalszh!1.pgc`: **16,382,536 bytes, SHA `56A06104...`**, preserved under
`artifacts/2026-11-25-pgo/pgoprofile/`.

[VERIFIED] The first attempt failed for a mechanical reason: the 25-minute watchdog killed the
instrumented build at frame 14,879 (it runs ~3.5x slower, ~10 fps) and a forced kill loses the
profile. The engine's `setQuitting(TRUE)` at the checkpoint gives a normal exit, which flushes it.

[VERIFIED] Build tree restored to normal linking (`CMAKE_EXE_LINKER_FLAGS` empty, relinked);
`dumpbin /dependents` shows **no `pgort140.dll`**. Staged playtest remains `52F56C99...`.

[INFERRED] Optimisation is **on hold by request**: no `/LTCG:PGO` relink and no measurement yet.
When resumed: relink with `/LTCG:PGO` against the profile, require the linker's "N of M functions
optimized using profile data" receipt, then run the heavy replay gated on exact `04C62655`/983 and
compare mean/p90/logic/path against 36.80 ms / 14,680 us.



## 2026-11-25 - Live 33% skirmish recorded; user picks 33% as the feel winner

[VERIFIED] Live skirmish at `ZH_ALLY_COST_PCT=33`, recorded to `artifacts/2026-11-25-live-33/`:
60,319 logic-running frames, overall **38.07 ms mean (26.3 FPS)**; top-decile load (visible objects
237-775 vs 120 in the replay window) **55.01 ms (18 FPS)**, logic 45.19, client 9.21, draw 7.89;
calibration 7,542 us. The live match is ~2x the replay's render load, so it is not comparable to the
replay gate.

[VERIFIED] The user judged it smoother than the replay variants (including under nukes/heavy
animation) despite higher logged frame times -- consistent with steadiness rather than lower means
(the replay variants hitch at p90).

[DECISION] User chose **33% as the winner for feel**. `tools/play-t120.ps1` now defaults to
`-AllyCost 33`; 66% stays documented as the benchmark value (heavy 30.06 ms / 33.3 FPS; 29.01 / 34.5
with the visual trades).

## 2026-11-25 - Congestion-price survival sweep: 66% is the lowest survivable value

[VERIFIED] Battle resolution frame by `ZH_ALLY_COST_PCT`: 33% -> ~8,400; 50% -> ~15,600; 60% ->
~16,700 (200 frames short); **66% -> 17,402**; 100% -> 17,402; 0% -> 17,402 but slower (43.75 ms).
The 33% variant is deterministic across two runs (identical CRCs `3F1588B4`, `BCAF974D`, `DA7B9F8B`,
`92E4A144`).

[INFERRED] Resolution frame rises monotonically with the price between 33 and 66, so lower values
collapse earlier. 66% is the lowest survivable value found; the 60% gap is ~200 frames, making a
62-64 chase a poor use of runs for a negligible feel difference. Recommendation: 66% for benchmarks,
33% for feel playtests.

## 2026-11-25 - Ally 66% + visual trades: 29.01 ms / 34.5 FPS; playtest build staged



[VERIFIED] `ZH_ALLY_COST_PCT=66` + `ZH_SKIP_OCCLUDED/VOLUMETRIC/PARTICLES`: heavy **29.01 ms
(34.5 FPS)**, p90 45.42, logic 25.40, client 3.26, draw 2.29, path 9,770 us, calibration 7,522 us.
Same logic CRC (`695F3403`) as the other 66% runs.

[VERIFIED] Packaged: staged engine **`9660EB14...`**; `tools/play-t120.ps1` gains
`-AllyCost 100|66|33|0` (default retail 100) and keeps `-Performance`. Cumulative patch regenerated
(**670,882 bytes**, SHA `639DAAB9...`, `apply --check` clean).

[INFERRED] The path change (logic) and the visual trades (draw) stack; part of the 29.01 is a 2.3%
faster machine and the fast client regime, but the logic/path cuts reproduce identically. This is the
best heavy-window result of the project: 36.80 -> 29.01 ms, 27.2 -> 34.5 FPS.

## 2026-11-25 - Ally cost 66% repeated: heavy 30.06 ms (33.3 FPS), identical CRC

[VERIFIED] The 66% repeat produced **identical CRCs** (`695F3403` / `5B2954C4`) and an identical
command file (64,429 bytes), so the behaviour is deterministic. Heavy **30.06 ms (33.3 FPS)** vs
36.80 control; logic 25.52 vs 31.00, `l_ai` 11.80 vs 14.94, path **9,684** vs 14,680 us. The run had
the faster client regime (4.30 vs 5.32) and a 4% faster machine (calibration 7,393 vs 7,697), which
explains part of the gap; the path/logic cuts reproduce exactly and are regime-independent.

[INFERRED] **First configuration above 30 FPS in the heavy window at unchanged visuals.** It is a
gameplay trade (behaviour CRC differs from retail) and the user preferred the feel of the 33% variant.
Combination with the visual trades is running to establish the ceiling.

## 2026-11-25 - Ally congestion cost 66%: heavy 33.74 ms (29.6 FPS), path -33%

[VERIFIED] `ZH_ALLY_COST_PCT=66` completes 17,402 with heavy **33.74 ms / 29.6 FPS** vs 36.80,
logic **25.16** vs 31.00, `l_ai` **11.96** vs 14.94, path **9,778** vs 14,680 us (-33%), expansions
5,036 vs 6,759, commands **523** vs 983 (`zone_mismatch` 20 vs 41, `search_failed` 14 vs 84).
Calibration matched (7,644 vs 7,697 us) and the run had the slower client regime (8.13 vs 5.32), so
the interval gain is understated. Repeat run started to confirm.

[INFERRED] The response is non-monotonic: 0% is worse (43.75), 33% ends the battle (~8,400), 66%
completes and improves. Charging less for congestion yields simpler routes and fewer re-planning
events here. Must be confirmed by repeat, then combined with the visual trades.

## 2026-11-25 - Congestion pricing is load-bearing: 0% worse, 33% ends the battle

[VERIFIED] `ZH_STATIC_ROUTING=1` (drop the ally congestion terms, keep terrain/buildings): replay
completes at 17,402 but heavy **43.75 ms / 22.9 FPS** vs 36.80, logic 39.68 vs 31.00, `l_ai` 25.92,
path **22,329** vs 14,680 us, expansions **12,094** vs 6,759, commands **1,758** vs 983
(`zone_mismatch` 392 vs 41).

[VERIFIED] `ZH_ALLY_COST_PCT=33` (3 -> 1 per ally): battle ends ~frame 8,400 (score screen, no heavy
window). The 0% variant completes while 33% does not -- the outcome is not monotonic in the amount
changed.

[INFERRED] Ally terms are the engine's only congestion control, not optional traffic pricing.
Removing them floods cells and raises re-planning; reducing them changes who wins. The modern
static-routing model needs its other half (local steering/pushing), which this engine lacks. A port
must build that avoidance layer first.

## 2026-11-25 - External practice: how large-unit-count RTS keep pathfinding affordable

[SOURCED] Five techniques recur across games with hundreds/thousands of units: (1) path once per
group rather than per unit (Company of Heroes paths the squad leader and predicts member positions;
AoE formations share a path); (2) flow fields per destination (Supreme Commander 2, Planetary
Annihilation; a 50x50 field ~0.3 ms, computed on a hierarchical path); (3) hierarchical/region
pathing with aggressive caching; (4) **separating static navigation from dynamic avoidance** -- path
around terrain only, handle units by local steering/pushing; (5) time-sliced budgeted request queues
and deterministic job systems. Note in
[the practice note](../docs/research/2026-11-25-large-unit-count-rts-practice.md).

[INFERRED] This explains our failures: the engine **prices living units into the A* cost**
(`3*COST_DIAGONAL` per fixed ally and ally-moving penalties, `AIPathfind.cpp:3581-3642`), so a cached
route is unsafe within ~20 frames (TTL 24 diverged), every re-search differs, and capping triggers
re-requests. The 14.7 ms is not slow A*; it is paying dynamic-occupancy prices inside a static
search. Static-only routing plus local avoidance is the highest-leverage change and would make
caching/flow fields safe, but it is a **gameplay-visible trade** (units could path through allies and
push differently), so it needs a product decision.

## 2026-11-25 - Scan-timer trade closed: 3x idle interval also ends the battle

[VERIFIED] `ZH_FORCE_IDLE_FRAMES=10` + `ZH_GUARD_SCAN_RATE=30` ends the replay at ~frame 8,500;
`ZH_FORCE_IDLE_FRAMES=3` alone ends it at ~frame 9,300 (score screen, no `commands.csv`, no heavy
window). Even a 3x idle interval changes the battle outcome.

[INFERRED] The scan cadence is behaviourally load-bearing: any value that saves measurable time also
ends the replay before the heavy window, so it cannot be traded for frame time in this scenario.
Note the engine already implements the hybrid (guard scans every 15 frames, staggered; idle mood
checks gated by `m_nextMoodCheckTime`), so the remaining scan cost is the scheduled scans themselves,
not redundant polling. Lever closed.

## 2026-11-25 - Closest search is only 0.34 ms/frame: the swap is not worth it

[VERIFIED] Logging `serial_us` per `findClosestPath` call in this build: the heavy window has 56
calls over 43 frames (1.3/frame), per-call p50 233 us / p90 784 us / max 14.6 ms, and **per-frame
mean 0.34 ms** (p90 0.71). The kernel equivalent is 0.054 ms/frame.

[INFERRED] A perfect swap saves ~0.3 ms/frame, under a tenth of the ~3.5 ms deficit -- not worth the
behaviour trade or wiring risk. Correction: the census figure "findClosestPath 3.59 ms/frame" does
not hold for this heavy window; it was not re-measured before the swap was called promising. The path
budget is the ordinary/attack/other searches (~13.6 of 14.5 ms). The kernel's 50x per-call advantage
is real but irrelevant at 1.3 calls/frame.

## 2026-11-25 - Closest mismatches are one cell and always closer to the goal

[VERIFIED] Of 572 non-trivial shadow calls, 146 (26%) pick a different end cell; every one is within
1.0-1.4 cells (p50 1.0, max 1.4), and in **146/146** the kernel ends closer to the goal than the
serial search -- never farther.

[INFERRED] The kernel is not failing to route: it finds a marginally better closest cell because its
cost model is lighter (default `Movement`, width 0) than the serial `score = distSqr + cost^2 *
factor * multiplier`, which trades a cell of distance for a cheaper route. Parity therefore needs the
`Access` to carry the real movement/admission terms, not a scoring change.

## 2026-11-25 - Kernel closest objective now matches the serial cost-weighted score

[VERIFIED] `workerGroundSearch`'s closest fallback now reproduces the serial selection score instead
of a distance heuristic: `score = distSqr + cost^2 * COST_TO_DISTANCE_FACTOR_SQR *
closestPolicy.pathCostMultiplier`, with `COST_TO_DISTANCE_FACTOR = 1/10` taken from
`PathfindConstants.h`, the screen-distance tiebreak when the policy asks, and the optional
`Access::closest` decision marking non-enterable / non-destination cells ineligible. It builds
cleanly.

[INFERRED] Behaviour is unchanged by construction: the whole block sits inside
`if (query.closest.enabled)`, which no caller sets, and no `Access` implements the resolver, so the
`if constexpr` branch compiles away. No new replay was spent confirming an inert branch; the
ClosestPolicy neutrality run already gated the same path at exact `04C62655`/983.

[VERIFIED] Patch regenerated (**662,096 bytes**, SHA `E3609DE8...`), `apply --check` clean and
`GroundSearch.h` reproduces byte-identically; worktrees removed, vendor untouched. Staged build
restaged to **`C5D3C0F1...`**.

[INFERRED] Next: the `ZH_CLOSEST_SHADOW` harness in `findClosestPath` — build the `Access` from the
closest context, run the kernel with the policy enabled alongside the serial search, and log
frame/start/goal/radius/route hashes/costs/usec — then report route and cost match rates from one
heavy run.



## 2026-11-25 - ClosestPolicy contract verified neutral; patch and build re-synced

[VERIFIED] The `ClosestPolicy`/`ClosestDecision` contract and the policy-gated nearest-chain
fallback build cleanly and are **behaviour-neutral**: exact `04C62655`/983 commands, path 14,509 vs
14,680 us, heavy 34.04 vs 36.80 ms (fast-client regime: client 3.30 vs 5.32). No caller enables the
policy and no `Access` implements the resolver, so the `if constexpr` path compiles away.

[VERIFIED] Cumulative patch regenerated again from a pristine worktree: **661,348 bytes**, SHA
`CC361E57...`, `git apply --check` clean and `GroundSearch.h` reproduces byte-identically. The
vendor checkout remains untouched and both temporary worktrees were removed.

[VERIFIED] Staged `build/engines/t112-playtest.exe` and the game copy at **`5A20FC79...`** (the
policy build verified above); `d3d8to9` (`122928CF...`) installed.

[INFERRED] The remaining port step is unchanged and now precisely specified: implement the serial
cost-weighted closest score in `workerGroundSearch` (`PathfindConstants.h` `COST_TO_DISTANCE_FACTOR
= 1/10`), then the per-call shadow. Choosing by heuristic distance would mismatch by construction.

## 2026-11-25 - Kernel closest-reachable support added (behaviour neutral)

[VERIFIED] `workerGroundSearch` gains `Query::closest` (default false) and `Result::closest`: an
unreachable goal returns the nearest reachable chain, built with the same goal-first parent walk,
`goalCost` set to that node's cost. No caller opts in.

[VERIFIED] Regression gate with no caller opting in: exact `04C62655`/983, path 14,556 vs 14,680 us,
heavy 34.18 vs 36.80 ms (fast-client regime). Behaviour unchanged.

[INFERRED] Remaining work: wire `findClosestPath` to the kernel query/access with `closest=true`,
convert `raw` to a `Path`, and compare route/cost parity with the shadow off. The object-level
predicates must enter the query contract first.

## 2026-11-25 - Occluded/stencil skip (visual trade): draw -2.68 ms

[VERIFIED] `ZH_SKIP_OCCLUDED=1` (skip `flushOccludedObjects`) same-build heavy pair, exact
`04C62655`/983 commands: control **36.90 ms** (logic 27.38, client 9.10, draw 8.37, views 7.21) vs
skip **35.49 ms** (logic 28.57, client 6.55, draw **5.68**, views **3.37**). Draw -2.68, interval
-1.41 (logic +1.19 variance). The occluded stage was **3.19 ms** in this regime (0.446 in the fast
regime), so the benefit is ~0.45-3.2 ms depending on present state.

[INFERRED] The skip removes behind-building markers/occluded rendering — a visual trade. It stays
opt-in, not default. 30 FPS remains unmet (best heavy 35.49 ms / 28.2 FPS in this pair).

## 2026-11-26 - T-129: public README and T-112 milestone published

[VERIFIED] The public README now leads with the 1,000-unit Last Stand result: 46.9 ms native
D3D8/Intel, 36.8 ms with `d3d8to9` on the GTX 1650 Ti, 30.1 ms with the 66% ally-congestion price,
and 29.0 ms with the three visual trades. It labels the 66% and visual profiles as opt-in trades,
states that the published alpha predates them, and separates the code-change table from the older
graphics-settings benchmark. The new chart is `docs/assets/last-stand-heavy-window.svg`; the
supporting note is `docs/research/2026-11-25-last-stand-congestion-price.md`.

[VERIFIED] The README also records the cost split (logic 31.0 ms, path 14.7 ms, client 5.3, draw
4.5), the 49-of-481-frame tail, and a measured-and-rejected table (cache TTL 24, 10k search cap,
admissible heuristic, render-thread overlap, shadow-map renderer, triple buffering) so those
experiments are not repeated.

[VERIFIED] `python tools/check_docs.py` passes after the README, chart, note, INDEX, BOARD, state
and continuity updates. The tracked source/docs snapshot is published on public `main` without the
private local history. A pre-publication scan of the tracked snapshot found no binaries, credentials,
private keys, API tokens, email addresses or real IP addresses; the only matches were version strings
and BCrypt API parameter names. The two workspace paths, the retail repack vendor path, and the
`%USERPROFILE%` tool paths are redacted in the public tree; the local evidence retains the originals.
The public commit SHA is recorded in `docs/state.json`.

## 2026-11-26 - T-129: public snapshot pushed

[VERIFIED] Public `main` advanced from `9c07bbc` to **`a2c92c8`** with 114 files changed. The
snapshot commit author/committer is the GitHub noreply identity; the local private history was not
pushed. `git ls-remote` reports `a2c92c8` for `refs/heads/main`, the raw `README.md` returns the new
Last Stand section, and `docs/assets/last-stand-heavy-window.svg` returns HTTP 200.

[VERIFIED] The published tree was re-scanned after redaction: 402 tracked files, no binaries, no
private keys, no API tokens, no email addresses and no real IP addresses. `python tools/check_docs.py`
passes in the publication tree; the only warnings are artifact links whose manifests are intentionally
local (the `artifacts/` folder is not committed).










