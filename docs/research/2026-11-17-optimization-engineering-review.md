# Independent engineering inspection: optimization and patcher readiness

- **Date:** 2026-11-17
- **Task:** T-078
- **Reviewer:** Codex
- **Verdict:** [INFERRED] Useful performance research and a promising singleplayer prototype; not ready for a universal optimizer release.

## Scope and confidence

[VERIFIED] Inspected the current cumulative patch scope (23 changed source files), selected affected engine paths, staging/launch/build/profile scripts, experiment records and retained CSVs. Built executable and both staged copies have SHA-256 `ACADF232F6AC11154ECA505BB860EF2C6A2C1C3C45E7827363FB6EA63580126D`. Reverse-applying the cumulative patch with `--check --ignore-space-change` succeeds. The working tree contains extensive pre-existing uncommitted changes; this review evaluates that working tree, not just HEAD. Contributor/model authorship cannot be established from these files alone.

[VERIFIED] This inspection ran independent CSV analysis, the Windows CRT boolean conversion, and a mocked invocation of the actual launcher. No game was launched, rebuilt, staged or modified. Counter/FPS/overflow witnesses are source-derived control-flow demonstrations, not engine integration tests. Original installation and pristine baseline were not written. Evidence: `artifacts/2026-11-17-engineering-review/manifest.md`, `checks.json`, `launcher-check.json`.

## Findings, ordered by release importance

### 1. High: disabled counter is not maintained through save/load and destruction

[VERIFIED] `Object.cpp:2155` introduces `g_zhDisabledObjects`. Its only updates are the increment in `setDisabledUntil` (2215) and decrement in `clearDisabled` (2398). `Object::xferSnapshot` directly transfers `m_disabledMask` (4265); `loadPostProcess` (4586) only restores containment. The scan in `GameLogic.cpp:4727` is skipped while the counter is zero. No counter reset, destructor decrement or snapshot rebuild exists in the reviewed C++ references.

[INFERRED] Loading timed-disabled objects into a fresh process can leave expiry processing disabled until another object increments the counter. Deleting disabled objects can leave a stale positive count and defeat the optimization. Exact player-visible symptoms need an integration test with EMP/hack/subdual saves, multiple simultaneous disable types, destruction and a second match. A no-disabled-object benchmark does not validate this invariant. Prefer reverting the guard until those cases pass. [ISSUE-0029](../issues/ISSUE-0029-disabled-counter-lifecycle.md).

### 2. High: staging destination is not protected

[VERIFIED] `tools/stage-engine.ps1:46-47` recursively deletes user-supplied `GameDir` with `-Force`; line 81 overwrites `Generals.exe`. It does not validate the resolved destination against immutable references, permitted mutable copies, source/target overlap, or reparse points before mutation. `prepare-shockwave-copy.ps1` has a comparable unrestricted Force path.

[INFERRED] Supplying an original install, baseline, source directory or wrong parent can destroy or overwrite it. This is a concrete unsafe interface for an end-user patcher, although the documented default points to a mutable copy. No deletion was attempted. Require resolved-target guards, identity detection, a mutation plan, backups and transactional rollback before exposing arbitrary installations. [ISSUE-0032](../issues/ISSUE-0032-staging-destination-unguarded.md).

### 3. High compatibility risk already documented: broadphase is not simulation-equivalent

[VERIFIED] [EXP-011 §3.3](../experiments/EXP-011-broadphase-correctness.md) records different collision hashes in 1,729 of 2,619 common frames and explicitly confines the optimization to singleplayer. Contact evaluation and callbacks are interleaved. The rejected-pair probe checks current geometry, not collisions that can become possible after earlier callbacks move objects.

[INFERRED] Zero rejected-but-colliding pairs at probe time is useful geometric evidence but does not establish equivalent final simulation. A default-on broadphase cannot be advertised as a retail-compatible multiplayer or replay fix. This does not prove two identical optimized peers desync with each other; that remains untested. Exclude it from a compatibility preset and validate deterministic state/CRC traces, saves and replays separately. Existing statements in `docs/optimizations.md` that it is a pure speed-up preserving collisions need this qualification.

### 4. Medium: documented boolean disables broadphase

[VERIFIED] `OptionPreferences.cpp:686-691` evaluates `stricmp(value,"no") != 0 && atoi(value) != 0`. Windows CRT execution confirms `yes -> false`, `no -> false`, `1 -> true`, `0 -> false`. Missing key returns true. Therefore copying `DebrisBroadphase = yes` from the documented preset turns it off. The ShockWave wrapper forces environment value 1, masking the parser error. Use a shared validated boolean parser and table-driven cases. [ISSUE-0030](../issues/ISSUE-0030-broadphase-yes-parses-false.md).

### 5. Medium: uncapped latch defeats live FPS controls

[VERIFIED] `FramePacer.cpp:42-59` permanently caches the initial environment/preference result; line 155 forbids the limiter while that cached result is uncapped. `OptionsMenu.cpp:447` changes the global preference but never clears the cache. `launch-game.ps1:165` forces `ZH_NOFPSLIMIT=1` for normal launches.

[INFERRED] Starting uncapped and then unchecking Unlock FPS cannot activate the limiter in that process; Ctrl+Numpad presets also remain ineffective while the forced override holds. Persistence of the checkbox is insufficient. Verify both startup states, both toggle directions, hotkeys and relaunch behavior. [ISSUE-0031](../issues/ISSUE-0031-fps-latch-overrides-ui.md).

### 6. Medium: launcher diagnostics leak across launches

[VERIFIED] The actual launcher, invoked with a mocked Start-Process, leaves `ZH_HEAL_PULSE=11`, `ZH_ATTR_SAMPLE=1`, `ZH_NOFPSLIMIT=1` in its caller instead of restoring the original 7/sentinel/sentinel. No game executes. Its restoration list omits these keys and newer radiation/healer/icon diagnostics, while TestEnv accepts any ZH_ key. Setup also occurs before the try/finally region.

[INFERRED] Benchmark settings can leak or inherit unintended diagnostics, weakening reproducibility; gameplay-altering diagnostics are present in the same build. Restore the union of inherited ZH_ variables, accepted TestEnv keys and variables assigned during launch, including error paths. Production builds should compile out the army/healing/radiation harness. [ISSUE-0033](../issues/ISSUE-0033-launcher-diagnostic-env-leaks.md).

### 7. Medium, inherited boundary: destroy fallback still truncates at 256 modules

[VERIFIED] `GameLogic.cpp:2598-2640` detects overflow but the fallback only collects while `numSUO < MAX_SUO`, still 256. At 257 registered modules at least one remains in the scheduler. The fixed limit existed before T-065; this is not evidence that the fast path introduced it, but the new fallback's safety claim is false.

[INFERRED] A sufficiently complex mod object can leave a scheduler pointer to a destroyed module. No tested stock/ShockWave template is known to reach this limit. Use unbounded or iterative removal, with a 257+ module fixture, rather than assuming all future mods fit. [ISSUE-0034](../issues/ISSUE-0034-destroy-overflow-still-truncates.md).

## What the performance evidence actually establishes

| Result independently checked | Assessment |
|---|---|
| T-065 six raw runs: mean of per-run destroy maxima 92.906 -> 8.152 ms | [VERIFIED] Strong evidence of a targeted destruction-path gain; frame p95 50.39 -> 48.23 ms, median 4.17 -> 4.22 ms. This is not an 11x whole-game improvement. |
| EXP-013 six raw stock profile runs: mean of per-run medians 21.864 -> 6.471 ms (3.38x) | [VERIFIED] Real profile throughput difference on one rebuilt engine, chiefly a rendering-quality tradeoff (AA8/High vs AA0/Low); not an isolated retail-vs-patched engine speed-up. |
| T-067 claimed ~2.6% median gain | [VERIFIED] Experiment itself says the difference is below run variation; correctness is not established by its empty-disabled workload. |
| Older partition-skip tail win | [VERIFIED] EXP-024 attributes much of it to invisible debris; T-076 removes the feature. It must not contribute to a current marketing claim. |
| Cylinder broadphase repair | [VERIFIED] EXP-011 documents a real detected false-rejection problem and a better probe; current code includes the fix. Tested geometry coverage is finite and does not establish simulation equivalence. |

[INFERRED] The strongest parts of the work are measurement-driven rejection of weak candidates, retained raw data, isolated game copies, attribution of the destruction spike, and cumulative source patching. The weakest parts are lifecycle correctness, configuration integration, overbroad compatibility wording and release engineering. A visible-object census alone was already shown insufficient to prove actual drawing (EXP-024).

## Conditions for a universal optimizer

1. **Correctness gate:** [INFERRED] Resolve the findings above, then test save/load during disable effects, repeated matches, destruction, fog/shroud, visible debris, UI changes and scheduler invariants. Add meaningful regression tests for these cases.
2. **Compatibility gate:** [UNKNOWN] Stock ZH and ShockWave synthetic workloads are the only demonstrated local performance scope reviewed here. Test actual moving armies/pathfinding, AI/economy/combat and long sessions. T-025's compatible late-game replay remains blocked. Separate stock ZH 1.04, each named mod/version, language/build variants and executable-modifying extensions in an explicit support matrix. If “original game” includes Generals without Zero Hour, validate that as its own product; this ZH executable is not evidence of support.
3. **Mode gate:** [INFERRED] Offer a retail-compatibility preset that leaves simulation-changing options disabled. Keep the experimental singleplayer engine separate; multiplayer/online and legacy replay support require deterministic and interoperability tests, not an assumption from successful startup.
4. **Installer gate:** [INFERRED] Detect known identities and refuse unknown builds, prefer side-by-side deployment, preserve mod DLL chains and archive precedence, support dry run and verified rollback after interruption, and isolate configuration per installation. The current ShockWave materialization map is mod-specific, not a generic mod detector.
5. **Evidence gate:** [INFERRED] Compare unmodified-source and optimized-source builds at identical settings separately from profile/quality and GPU changes. Pin source, patch hash, build flags, INI, mod/archives, wrapper, GPU, camera, seed and background load; use fixed elapsed-time windows and event-aligned tail/logic metrics. Repeated runs across machines are needed before promising general gains.
6. **Release gate:** [INFERRED] Produce a clean versioned release manifest and source/build package, remove test-only gameplay paths from the shipping build, verify dependency/wrapper distribution requirements and provide a support/rollback policy before public distribution.

## Checks and unresolved limits

[VERIFIED] `python artifacts/2026-11-17-engineering-review/verify.py` exits 0: actual CRT parser behavior, enumerated counter references, source witnesses, six destruction-run summaries reproduced from CSVs, six profile-run medians recomputed, patch reverse-check exits 0 and three executable hashes match.

[VERIFIED] `powershell -NoProfile -ExecutionPolicy Bypass -File artifacts/2026-11-17-engineering-review/verify-launcher.ps1` exits 0 and demonstrates the environment leak without executing a game. Initial execution without the process-local policy override was rejected by AuthorizationManager, recorded in ISSUE-0035. No machine policy was changed.

[UNKNOWN] Full engine rebuild, disabled-save integration, multiplayer CRC, additional mods, other hardware, long-session resource usage and crash recovery were not exercised in this review. Source checking and retained measurements support the findings; they cannot certify those runtime properties.

## 2026-11-17 remediation follow-up

[VERIFIED] T-079 follow-up: ISSUE-0029 through ISSUE-0034 are now resolved, and simulation-changing options are excluded from normal/network/replay execution. This inspection describes the pre-fix build; see the remediation record for current behavior and validation limits. See [remediation](../research/2026-11-17-optimization-remediation.md).
