# Work log

> **Append-only.** Newest entry at the bottom. Each entry: date, task ID(s), what changed,
> evidence. Never rewrite an entry; add a correction entry instead.
> The latest date here must equal `updated_at` in [`state.json`](state.json).

## 2026-11-14 — P0: agent-readable documentation base

**Tasks:** T-001, T-002, T-003, T-004

**Context.** The workspace contained only a patched Zero Hour installation (1.29 GB) with no
project files, no git repository, and no documentation. Goal: make the project readable and
interpretable by any agent, across sessions, before technical work begins.

**Created**

- `AGENTS.md` — entry point: repository map, hard rules, evidence labels, update protocol.
- `README.md`, `.gitignore` (game install + artifacts excluded).
- `docs/INDEX.md` — document catalog, conventions, update triggers.
- `docs/project-brief.md` — goal, scope, constraints, proposed success criteria.
- `docs/environment.md` — verified OS/toolchain/hashes/config snapshot.
- `docs/game-inventory.md` — archive/binary/data inventory and launcher notes.
- `docs/architecture.md` — current component model + four Rust attachment hypotheses.
- `docs/roadmap.md` — P0–P4 phases, exit criteria, risk register.
- `docs/tasks/BOARD.md` — task ledger `T-001`…`T-010`.
- `docs/decisions/` — ADR-0001…ADR-0004 + template.
- `docs/research/TEMPLATE.md`, `docs/experiments/TEMPLATE.md`.
- `docs/glossary.md`, `docs/state.json`, `docs/log.md`.
- `docs/research/` placeholder conventions; `artifacts/README.md`.
- `.opencode/continuity.md` — cross-session checkpoint.
- `tools/check_docs.py` — validator (links, state schema, log freshness, task/ADR integrity)
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
  file reads on 2026-11-14; sizes/hashes recorded in `docs/environment.md` §3.
- `python tools/check_docs.py` →

  ```
  Checked 18 markdown files, 99 relative links, 10 tasks, 4 ADRs.
  OK: documentation system is consistent
  ```

- `python tools/check_docs.py --self-test` →

  ```
  PASS: clean fixture validates
  PASS: broken link detected
  PASS: stale state date detected
  PASS: dangling next_action detected
  SELF-TEST OK: validator detects injected breakage
  ```

- Repository initialized as a local git repo and committed; `git ls-files` contains docs/tools
  only, never the game installation (see next entry for the commit evidence).

## 2026-11-14 — P0 verification and first commit

**Tasks:** T-001, T-002, T-003, T-004

- Commit `ed545a2` — `T-001 T-002 T-003 T-004: P0 agent-readable documentation base`.
- `python tools/check_docs.py` → `Checked 18 markdown files, 99 relative links, 10 tasks,
  4 ADRs.` / `OK: documentation system is consistent` (exit 0).
- `python tools/check_docs.py --self-test` → 4 × `PASS`, exit 0.
- `git ls-files` → 24 tracked files, **0** under `Command and Conquer Generals Zero Hour/`.
- Cold-start comprehension test by an independent agent (read-only) confirms the entry point
  answers phase, next actions, constraints, and document locations without chat history.

## 2026-11-14 — Cold-start review fixes

**Tasks:** T-001, T-004

An independent read-only agent was given only the repository (no chat history) and asked to
summarize goal/phase, next actions, environment facts, constraints, record locations,
verification, evidence labels, and open questions.

Result: all eight questions were answered from the docs; no broken links. Defects found and
fixed:

- Circular dependency T-005 ↔ T-006 on the board → T-005 is the first P1 step and unblocks T-006.
- `state.next_actions` omitted T-008 and listed T-009 while T-009 was dependency-blocked →
  T-008 added, T-009 left on the board with "after T-006 and T-008".
- `docs/INDEX.md` §3.5 overstated the placeholder check → now matches the validator
  (`{{`, `TODO:`, `FIXME`; `TEMPLATE.md` skipped). The validator also now ignores inline
  code spans so documents can describe those markers without failing.
- Archive count was imprecise → 21 root archives + a 24-byte `BIGF` stub at
  `launcher/MapsZH.big`; inventory, architecture, and glossary corrected.
- No guidance for runtime writes on first launch → risk documented in `game-inventory.md` §4
  and added to T-005 scope (prefer launching a copy, record before/after hashes).

False positive: the reviewer reported "no `.git` directory". `Test-Path .git` → `True`,
`git log` shows both commits, and `git ls-files` reports 24 tracked files; the reviewer's
sandbox did not expose repository metadata. No change made.

Verification: `python tools/check_docs.py` → `OK` (exit 0); `--self-test` → all PASS. Fixes
committed in the following commit.

## 2026-11-14 — Issue/bug register added

**Tasks:** T-011

Added a dedicated place for problems, as distinct from tasks, decisions, and experiments:

- `docs/issues/README.md` — purpose, when to file, severity levels, status lifecycle,
  blocking-issue rules, index of current issues.
- `docs/issues/TEMPLATE.md` — required fields: symptom, reproduction/evidence, impact, root
  cause, workaround, resolution/verification.
- Seeded real entries: ISSUE-0001 (reference install may be mutated by a normal launch),
  ISSUE-0002 (GenTool owns the `d3d8.dll` slot), ISSUE-0003 (INI rules unreadable until
  `INIZH.big` is parsed), ISSUE-0004 (validator false positive on documented markers — fixed
  with the inline-code fix and kept as a worked example).
- `AGENTS.md` now requires filing an issue on any failure/contradiction/blocker, marking the
  task `Blocked` and updating `state.blockers` when it stops progress, and closing only with
  verification. `docs/INDEX.md`, the board (`T-011`), and the continuity checkpoint updated.
- `tools/check_docs.py` now validates issue IDs, filenames, title/ID match, status, severity,
  date, task link, resolution section, index listing, and uniqueness; self-test injects a
  duplicate issue ID.

Verification: `python tools/check_docs.py` → `OK`; `--self-test` → all PASS.

## 2026-11-14 — P1: pristine baseline, work copy, fullscreen fix

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


## 2026-11-14 — P1: source build, DPI/fullscreen, frame timing

**Tasks:** T-014, T-015, T-017, T-023

**Build**

- First configure selected BuildTools MSVC 14.42 and failed: `PreRTS.h(47): C1083 atlbase.h`.
- ATL was already installed in Community 14.43; reconfigured with
  `-DCMAKE_GENERATOR_INSTANCE=...Community -T v143`.
- `z_generals` built successfully: `build/engine-vs-community/GeneralsMD/Release/generalszh.exe`,
  `BUILD_EXIT=0`.
- Baseline source exe `F8CAC4C0…0998`; current DPI+logger exe `4D6589F6…091B`.

**DPI / fullscreen**

- Added per-monitor DPI awareness at `WinMain` (patch `engine/patches/T-023-dpi-awareness.patch`).
- DPI-aware query: process awareness 2; borderless client **1920×1080**; exclusive client
  **1920×1080**; previously 1536×864 at 125% scaling.
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


## 2026-11-14 — Clean rebuild and stress-harness attempt

- Rebuilt after reverting the test-only stress hook; current DPI+logger exe is
  `595161836AC847F5A01DB3A3701E3EDF23E0F9A1411BF2EC2022B2395EC25A4B`.
- Staged clean exe in `game/engine-test/`; GenTool disabled; 15-s smoke test alive and frame
  log produced.
- Stress-spawn experiment (`ZH_STRESS`) was unreliable: no default team in the debug map,
  teamless object creation crashed, and UI automation/map load was not repeatable. Reverted;
  no unverified stress patch is shipped.
- Entity-heavy benchmark remains blocked (ISSUE-0009); frame logger and DPI patch are verified.


## 2026-11-14 — Scenario attempts and clean rebuild

- Tried `ZH_MAP` automatic map start and deferred `ZH_STRESS` spawning. The hook found a valid
  team (`team=1D14E5D0`) and template `AmericaTankCrusader`, but `startNewGame` from the menu
  returned to the menu; spawns only affected the menu world. Reverted.
- Rebuilt clean DPI+logger engine:
  `0071F21BAF68F3F8189628C2CB209884EA5A96EEA51BB3DA99612D1F363EBC11`.
- Staged clean exe in `game/engine-test/`; GenTool disabled.
- Entity-heavy benchmark remains blocked (ISSUE-0009); no unverified stress patch shipped.


## 2026-11-14 — Final scenario retry and clean engine

- Retried deferred stress spawn through the Debug Load Map UI; the map list stayed open and no
  playable match was reached. Hook reverted.
- Rebuilt clean DPI+logger engine:
  `92835AF8C62360EC05E03B603EF9ABE3235A854CD954E26BCB4567C9ACD56D7E`.
- Staged clean exe in `game/engine-test/`; GenTool disabled; no `stress.log`.
- Entity-heavy baseline remains blocked on a valid scenario (ISSUE-0009).


## 2026-11-15 — Entity-heavy benchmark and first measured optimization

**Tasks:** T-015, T-017, T-024

**Scenario solved.** The test-only harness (`ZH_MAP` + deferred `ZH_STRESS`) now starts
`maps\northamerica\northamerica.map` without menus and spawns 1,000 visible tanks after the map
creates a valid team. Harness exported as `engine/patches/T-015-benchmark-harness.patch`
(test-only; do not ship in a normal build).

**Baseline (3 runs, 1,000 units, 1920×1080, AA 14 → 8× MSAA):**

```
median: 59.41 / 62.62 / 58.57 ms
p95:    67.02 / 69.19 / 66.33 ms
```

Split timing: `client` median 51.87 ms, `draw` median 50.32 ms, `logic` median 4.49 ms.

**Root cause found.** `OptionPreferences::getAntiAliasing()` clamps `AntiAliasing = 14` to
**8× MSAA** (`OptionPreferences.cpp:70-80`, `ww3d.cpp:2031-2049`). Reducing AA:

| AA | Effective | Median |
|---:|---|---:|
| 14 | 8× | 59.41–62.62 ms |
| 4 | 4× | 48.39 ms |
| 2 | 2× | 45.01 ms |
| 0 | off | 34.76–36.50 ms |

**Optimized (3 runs, AA 0):**

```
median: 34.76 / 35.05 / 36.50 ms
p95:    39.45 / 40.20 / 41.95 ms
```

Median-of-medians **59.41 → 35.05 ms (1.70×)**; effective FPS **16.8 → 28.5**. Draw time
**50.32 → 27.26 ms**. Original Options.ini backed up at
`artifacts/options-backups/options-2026-11-15-005413.ini`.

**Changes:**

- `tools/apply-options-profile.ps1` — portable `performance` (AA 0), `balanced` (AA 2),
  `default` (AA 8), with backup/restore; no game files touched.
- `engine/patches/T-015-benchmark-harness.patch` — `ZH_MAP`, deferred `ZH_STRESS`,
  `ZH_PERF_SPLIT` (client/draw/logic).
- `docs/experiments/EXP-001-msaa-entity-heavy.md` — full method/results.
- ISSUE-0006 → Workaround; ISSUE-0009 → Fixed; board/state/continuity updated.


## 2026-11-15 — Source-level distance cull

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


## 2026-11-15 — Visibility-preserving LOD attempt

- Implemented distance LOD via `HLodClass::Set_LOD_Level` (`ZH_LOD`, near/far thresholds).
- Measured at 1,000 units, AA 0: draw median **28.8 ms** vs **27.3 ms** baseline; frame median
  **36.71 ms** vs **35.05 ms**. No gain; reverted.
- The remaining draw cost is draw-call submission, not model detail. Batching/spatial index
  remains open (T-021/T-027).
- Rebuilt cull-only engine and staged it:
  `5CF4EA0717FE38A11A1CB1007C6DA930D3BC75EA468CFC59E601CFFBAB1160F0`.
- Opt-in cull remains the only measured source-level draw gain (draw 27.3 → 18.1 ms at 400).


## 2026-11-15 — Visibility-preserving Low-detail profile and portable runner

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


## 2026-11-15 — Architecture headroom and shadow-volume cost

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


## 2026-11-15 — External SAGE/RTS performance cross-check

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



## 2026-11-15 — Screen-size shadow LOD and optional d3d8to9 A/B

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
`122928CF…F8AB8`) into `game/engine-test` only, ran a 3+3 Low-detail A/B:

```
native:  26.58 / 25.93 / 26.45 ms; draw 19.24 / 19.19 / 19.44
wrapper: 25.37 / 24.89 / 25.00 ms; draw 17.99 / 17.87 / 18.47
```

Median **26.45 -> 25.00 ms (5.5%)**, draw **19.24 -> 17.99 ms (6.5%)**, no crash. High-detail
wrapper runs were contaminated by BlueStacks running in the foreground, so they are indicative
only. The wrapper was removed; native system D3D8 remains the default. Recorded in EXP-006.

**Changes.** Patch `T-030-shadow-culling.patch` now contains distance + screen-size culls;
launcher gains `-ShadowSize`; docs EXP-005/EXP-006 and manifests; engine hash
`EB4EC006…C3FBF`. Board: T-032/T-033 Done, T-034 shadow-map prototype added.

**Verification.** `python tools/check_docs.py` OK; baseline manifest verified; source install
0 files modified; engine-test has no local `d3d8.dll`; options AA 0 + Low.


## 2026-11-15 — Clean-environment correction for architecture benchmarks

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
`EB4EC006…C3FBF`; baseline and source-install checks unchanged.


## 2026-11-15 — Projected/decal shadow prototype rejected

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

**Tasks:** T-041, T-042; ADR-0009; EXP-008 §7.

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

**Tasks:** T-041 (scope), T-042; ADR-0009 amendment; EXP-008 §9.

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

**Task:** T-043; EXP-008 §7/§9.

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
multiplayer CRC snapshot, so T-043 is singleplayer-only like T-041 (EXP-008 §9).

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
  launcher. Verified: edge pan pixel diff 0.01 → 40.51; wheel zoom zooms after 4 notches.
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

[VERIFIED] Caveat recorded in EXP-013 §5: absolute draw time at Low is much lower than the older
EXP-003 record (1.85 vs 18.45 ms), so cross-session absolute numbers are not comparable; the
same-session ratio is.

Verification: `python tools/check_docs.py` exited 0; artifacts under
`artifacts/2026-11-16-original-vs-optimized/` with `manifest.md` and `summary.json`.

## 2026-11-16 - T-057 FPS cap: what removing it buys, and a launcher bug

[VERIFIED] Mechanism: the render cap is `m_useFpsLimit` + `FramePacer::m_enableFpsLimit` with a
preset list of 30, 50, 56, 60, 65 ... 120, 144, 240, 480, Uncapped (`FrameRateLimit.cpp:69`).
It can be changed by `-noFPSLimit` / `-fps <n>` on the command line
(`CommandLine.cpp:1054,1310`), by `Ctrl+Numpad +/-` in game (`MetaEvent.cpp:810`, HUD shows
`▲30`..`▲X`), or by `UseFPSLimit`/`FramesPerSecondLimit` in GameData. Logic stays at 30 Hz;
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
(-15%, p95 9.38 -> 7.96) and ShockWave 4.18 -> 3.81 ms (p95 63.01 -> 61.72). EXP-013 §5.2 now marks
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
  144.9 FPS**, p95 8.85 ms (113.0 FPS), p99 12.04 ms (83.1 FPS). Reference (EXP-013 §5.2):
  6.62 ms / 151.1 FPS -> **-4.1% FPS, within run variation**.
- ShockWave 1,000 x5 cycles, 2 runs: 4.06 / 4.06 ms (**246.4 / 246.2 FPS**), mean **4.06 ms =
  246.3 FPS**, p95 **49.59 ms (20.2 FPS)** vs reference 61.72 ms (16.2 FPS), p99 67.87 ms
  (14.7 FPS) vs 85.50 (11.7 FPS). Median is 6.1% lower in FPS, the tail is **~25% higher in FPS**.

[INFERRED] The stock scene cannot benefit: its 1,000-tank grid is ~540x510 world units, so a
400-unit draw distance culls almost nothing, and there is no debris for the partition skip. The
ShockWave scene gains on the tail. Note the ShockWave runner still exports
`ZH_COSMETIC_PARTITION=0`, so that feature was env-overridden off in these runs (EXP-016 §4);
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
`Set-Content` had written `docs/tasks/BOARD.md` in the system ANSI encoding, so `§`/`×` were stored
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

[VERIFIED] `ZH_COSMETIC_PARTITION` and `ZH_DEBRIS_DEFER` are absent from engine `059B5E7A…DC0F`
(byte search) and from all sources/tools; the binary shrank 6,770,176 → 6,768,640 bytes. Both copies
staged; smoke run (300 units, performance profile) 6.89 ms = **145.2 FPS**; patch regenerated and
`git apply -R --check` = 0.

[VERIFIED] T-077 in-game help: `OptionsMenuInit` now sets tooltips (they are code-driven — the `.wnd`
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

## 2026-11-18 - T-084 independent review of DeepSeek’s alpha changes

[VERIFIED] Candidate 9 matches the package, patcher, engine and source ZIP hashes. Standalone checks passed 67 compiled guard cases and four BIG reader tests. Debug and production transaction suites each ran 31 cases and exited 0 after enabling link fixture creation (one and five skips respectively, ISSUE-0092). No native game session was run during this review.

[VERIFIED] Disposable candidate 9 fixtures reproduced original archive loss on rollback (ISSUE-0089), changed-base acceptance through direct activation (ISSUE-0090) and a lost read-only attribute (ISSUE-0091). T-082 acceptance is blocked. See the [T-084 review](research/2026-11-18-deepseek-engineering-review.md).

[VERIFIED] The current Git root has the requested directory name and the old path is absent. T-083 and ISSUE-0088 are closed based on that filesystem check.

## 2026-11-18 - T-085 overlay repair and retained command-prompt setup

[VERIFIED] Candidate 10 resolves Windows path aliases before backup, verifies the exact base before activation and during active-overlay Verify, preflights the full backup set, and preserves originals’ read-only attribute. ISSUE-0089–0091 are fixed. The packaged command launcher and menu match candidate 9 byte for byte. See the [repair report](research/2026-11-18-overlay-repair.md).

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

[VERIFIED] The actual source methods passed 24 compiled scheduling cases. Snipping Tool took foreground focus while the rebuilt ShockWave window remained visible and unminimized at 1920×1080. Install/verify/uninstall restored all 288 original file hashes on the disposable copy. The production patcher suite ran 42 cases including six skips and exited 0. Package CRC and checksums passed. [Candidate 14](../artifacts/2026-11-18-patcher-alpha/candidate-14/manifest.md) · [T-089 receipts](../artifacts/2026-11-18-skirmish-speed/manifest.md).

## 2026-11-18 - T-090 console progress

[VERIFIED] Candidate 15 reports checking, backup, apply and restore stages as they start. Longer scans report file counts. The apply and restore bar counts verified paths. The packaged PowerShell 5.1 menu showed output in under one second on both actions and restored all 288 original ShockWave hashes. Debug and packaged production suites each collected 43 cases and exited 0 with one and six skips respectively. Package checksums passed. [Design notes](research/2026-11-18-console-progress-design.md) · [Verification](../artifacts/2026-11-18-patcher-alpha/candidate-15/manifest.md).

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
