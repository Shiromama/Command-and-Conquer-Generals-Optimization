# T-079: resolve the optimization inspection findings

- **Date:** 2026-11-17
- **Status:** Complete for the seven reviewed concerns; universal distribution remains unvalidated.
- **Task:** T-079
- **Decision:** [ADR-0010](../decisions/ADR-0010-correctness-before-speculative-gains.md)
- **Prior inspection:** [T-078](2026-11-17-optimization-engineering-review.md)

## Outcome

[VERIFIED] Fixed ISSUE-0029 through ISSUE-0034 and established an explicit singleplayer boundary for simulation-changing optimizations. Build/staged engine SHA-256: `A0407A85E72996564B3C5A4621D556C5E4F56650A7ED3B8B05D1FB4E1C474609`. The prior staged engine `ACADF232...126D` is preserved as an artifact backup. No original installation or pristine-baseline writes were made. Both isolated `game/engine-test` and `game/shockwave-engine` are staged with the fixed build; no ShockWave gameplay run was performed in this session.

| Concern | Resolution | Verification |
|---|---|---|
| Unsafe destinations | Shared preflight rejects protected/outside/overlapping/linked/ambiguous targets; existing baseline recreation always refused | [VERIFIED] 51 PowerShell assertions; real entry points reject intended paths for the intended reason; valid test-copy staging succeeds |
| Disabled counter | Remove T-067 counter/guard, restore original scan | [VERIFIED] Object.cpp has no upstream diff; counter absent; engine build and smoke pass |
| Broadphase compatibility | Default off; normal launcher forces simulation options off; explicit experimental-singleplayer mode required | [VERIFIED] Actual shared policy tested in all 8 request/network/replay combinations; compiled engine checks current mode before broadphase/filter/budget paths |
| 256-module boundary | Unbounded reusable vector, descending collection order, live indices | [VERIFIED] Actual extracted removal/erase code: 140 randomized cases through 1,024 modules; unrelated registrations remain valid |
| Diagnostic leakage | Complete ZH_ namespace snapshot/clear/restore inside try/finally | [VERIFIED] Actual launcher tested with mock process success/failure and invalid inputs; direct stock benchmark also isolates all diagnostics |
| Boolean parser | Case-insensitive yes/no, true/false, 1/0; invalid/missing broadphase values off | [VERIFIED] Actual getter and shared parser compiled and run |
| Live FPS controls | Apply overrides only once after startup INI load; limiter reads mutable state; normal launch honors saved preferences | [VERIFIED] Actual limiter method tested with startup permutations and live state transitions; real capped and uncapped smoke runs |

## Verification commands and results

- [VERIFIED] `cmake --build build/engine-vs-community --config Release --target z_generals -- /m:1 /nodeReuse:false`: exit 0, engine linked. The earlier sandboxed multi-node attempt stalled; its own verified process tree was stopped before retry (ISSUE-0038). No dependency download or reconfiguration was required.
- [VERIFIED] `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1`: exit 0, 51 assertions, including baseline trailing-dot/space/short-name aliases, junction/hardlink rejection and caller environment restoration. Process launches in this test are mocked; no game runs.
- [VERIFIED] `tools/test-engine-optimization-fixes.py`, under the existing VS vcvars32 environment: exit 0. Tests use the actual shared policy header and extracted getter/limiter/scheduler code with stub surrounding services; this is not an engine save/load or multiplayer integration test.
- [VERIFIED] Cumulative patch reverse-check exits 0. Applying it to a clean vendor HEAD alternate index then comparing that index to the working tree exits 0, including the new policy header. No vendor checkout/index replacement was needed.
- [VERIFIED] Two real 300-unit stock smoke runs (12 seconds each, first 30 recorded frames omitted): capped median **33.34 ms**, p95 **35.00**; uncapped median **9.50 ms**, p95 **12.42**. Both generated frame/stress logs and were stopped by their own process ID. These are startup/limiter smoke checks, not optimization A/B evidence.
- [VERIFIED] `powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare-game-copies.ps1 -VerifyOnly`: exit 0, **1,914 baseline files match**. The initial default-root binding failure was corrected and retained as ISSUE-0039. Protected reference executable hashes also match before/after the safety tests.

## Use

[VERIFIED] Ordinary `launch-game.ps1` now honors `FPSLimit` and excludes inherited diagnostics. `-NoFPSLimit` and `-WithFpsLimit` are explicit startup inputs that do not veto later UI/hotkey changes. Simulation-changing settings require `-ExperimentalSingleplayer`; the engine still blocks them in network games and replays. `play-shockwave-performance.ps1` defaults broadphase off. Benchmark/demo entry points expose the explicit experimental choice instead of silently enabling it. See [settings](../optimizations.md).

## Limits and next work

[UNKNOWN] Retail multiplayer interoperability, SWR.net acceptance, legacy replay/save compatibility of the entire rebuilt engine, arbitrary mods and other hardware are not certified. The existing T-025 replay blocker remains. Removing the known simulation opt-ins from the default does not prove the upstream source engine is retail-equivalent.

[INFERRED] A general installer still needs a supported-build/mod matrix, transactional installation/rollback and distribution validation. The corrected scripts intentionally only mutate verified workspace-copy paths; they are not a general end-user installer. No further performance improvement is claimed by this correctness pass. Restoring the disabled scan and turning broadphase off can cost performance compared with experimental settings; that is an intentional correctness choice supported by EXP-018's unproven counter gain and EXP-011's divergence.

[VERIFIED] Test harness and build issues encountered along the way were recorded, inspected and resolved (ISSUE-0037 through ISSUE-0039). Source/configuration fixes were validated before runtime staging. All evidence, commands and hashes are catalogued in `artifacts/2026-11-17-t079-remediation/manifest.md`.

[VERIFIED] Final documentation validation: `python tools/check_docs.py` exits 0 (106 Markdown files, 438 links, 77 tasks, 10 ADRs, 39 issues). All 12 changed PowerShell scripts parse. The unchanged validator self-test previously passed in T-078 and was not redundantly repeated.

## Default-entrypoint follow-up

[VERIFIED] The initial ISSUE-0039 root fix was expanded to the nine affected touched entrypoints after default launcher/performance -File dry runs exposed the same early parameter-binding issue. Script-relative defaults now resolve in the initialized body. Both default dry runs exit 0, all 12 changed PowerShell scripts parse, and the final safety suite still passes 51 assertions. This required no further engine change or rebuild. Main remediation commit: `4682881`.
