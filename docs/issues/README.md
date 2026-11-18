# Issue register

> **Status:** living · **Last verified:** 2026-11-14
> One file per issue: `ISSUE-####-short-slug.md` (IDs monotonic, never reused).
> The register records **problems encountered while doing the work**: crashes, wrong results,
> broken tools, environment failures, blocked assumptions, and confirmed defects. Design
> choices belong in [`../decisions/`](../decisions/README.md); general progress belongs in
> [`../log.md`](../log.md).

## Index

| ID | Title | Severity | Status | Task |
|---|---|---|---|---|
| [ISSUE-0100](ISSUE-0100-alpha-binary-local-build-paths.md) | Alpha binaries disclose local build paths | Medium | Fixed | T-094 |
| [ISSUE-0101](ISSUE-0101-unbounded-mod-archive-extraction.md) | Mod inspection and import have no archive resource limits | Medium | Fixed | T-094 |
| [ISSUE-0102](ISSUE-0102-security-workbench-start-timeout.md) | Codex Security workbench startup timed out | Low | Open | T-094 |
| [ISSUE-0099](ISSUE-0099-console-transaction-silent.md) | The console stays silent during patch transactions | Low | Fixed | T-090 |
| [ISSUE-0097](ISSUE-0097-skirmish-speed-overrides-render-limit.md) | Starting skirmish forces the speed slider value into the renderer | Medium | Fixed | T-089 |
| [ISSUE-0098](ISSUE-0098-exclusive-fullscreen-snipping.md) | Screen snipping minimizes the game in fullscreen | Medium | Fixed | T-089 |
| [ISSUE-0096](ISSUE-0096-alpha-options-controls-hidden.md) | The packaged ShockWave layout hides AA and Unlock FPS | Low | Workaround | T-077 |
| [ISSUE-0095](ISSUE-0095-source-menu-cannot-find-package.md) | Source launcher cannot find the packaged executable | Medium | Fixed | T-087 |
| [ISSUE-0094](ISSUE-0094-console-menu-wrap-and-encoding.md) | Console menu wraps and its title renders incorrectly | Low | Fixed | T-086 |
| [ISSUE-0088](ISSUE-0088-project-folder-rename-locked.md) | Project folder rename blocked by an open handle | Low | Fixed | T-083 |
| [ISSUE-0089](ISSUE-0089-mod-overlay-case-alias-data-loss.md) | Case aliases can delete an original during overlay rollback | High | Fixed | T-082 |
| [ISSUE-0090](ISSUE-0090-direct-overlay-skips-base-catalog.md) | Direct overlay activation accepts a changed base | Medium | Fixed | T-082 |
| [ISSUE-0091](ISSUE-0091-mod-restore-drops-readonly.md) | Overlay restore drops an original’s read-only attribute | Medium | Fixed | T-082 |
| [ISSUE-0092](ISSUE-0092-sandbox-patcher-link-fixtures.md) | Restricted shell prevents patcher link fixture creation | Low | Workaround | T-084 |
| [ISSUE-0093](ISSUE-0093-renamed-workspace-alpha-journal-identity.md) | Alpha test journals reference the previous workspace path | Low | Workaround | T-085 |
| [ISSUE-0001](ISSUE-0001-reference-install-runtime-writes.md) | Reference installation may be mutated by a normal game launch | Medium | Open | T-005 |
| [ISSUE-0002](ISSUE-0002-gentool-owns-d3d8-slot.md) | GenTool occupies the `d3d8.dll` proxy slot | High | Open | T-009 |
| [ISSUE-0003](ISSUE-0003-ini-rules-unreadable.md) | Game rules in `INIZH.big` cannot be read yet | Medium | Fixed | T-007 |
| [ISSUE-0004](ISSUE-0004-validator-placeholder-false-positive.md) | Validator flagged its own documentation of placeholder markers | Low | Fixed | T-004 |
| [ISSUE-0005](ISSUE-0005-fullscreen-not-working.md) | Game does not run fullscreen on the target laptop | High | Fixed (work copy) | T-012 |
| [ISSUE-0006](ISSUE-0006-entity-performance.md) | Performance drops with many entities | High | Workaround | T-028 |
| [ISSUE-0007](ISSUE-0007-hybrid-gpu-default.md) | Game may run on the Intel iGPU instead of the GTX 1650 Ti | High | Workaround | T-039 |
| [ISSUE-0008](ISSUE-0008-gentool-rebuilt-crash.md) | GenTool proxy crashes the rebuilt engine | High | Workaround | T-014 |
| [ISSUE-0009](ISSUE-0009-no-heavy-benchmark.md) | No valid entity-heavy benchmark scenario | High | Fixed | T-015 |
| [ISSUE-0010](ISSUE-0010-heavy-replay-unavailable.md) | No compatible heavy replay for late-game validation | Medium | Open | T-025 |
| [ISSUE-0011](ISSUE-0011-shockwave-alt-tab-null-texture-crash.md) | Repeated Alt+Tab crashes ShockWave (null texture on device restore) | High | Workaround | T-040 |

## When to file an issue

File one **immediately** when any of these happens — do not wait for a fix:

- a command, build, or test fails in a way that is not immediately explained;
- observed behavior contradicts the docs;
- a tool or format assumption turns out to be wrong;
- the environment blocks progress (missing tool, permission, corrupt file);
- a workaround is applied to unblock a task.

## Required fields

Every issue must state: status, severity, date found, related task, symptom, reproduction or
evidence, impact, workaround (or "none"), and resolution/verification when closed.
Use [`TEMPLATE.md`](TEMPLATE.md).

## Status lifecycle

`Open` → `Investigating` → `Workaround` → `Fixed` (or `Won't fix` / `Duplicate`).

- **Open** — recorded, not yet worked.
- **Investigating** — someone is actively diagnosing; add dated findings.
- **Workaround** — a temporary mitigation exists; root cause still open.
- **Fixed** — root cause addressed and **verified**; put the verification command/result in
  the resolution section.
- **Won't fix / Duplicate** — explain why; link the canonical issue if duplicate.

## Severity

| Level | Meaning |
|---|---|
| Critical | Prevents all progress or risks data/installation loss. |
| High | Blocks the current phase or invalidates a planned approach. |
| Medium | Slows work or blocks a non-critical task; workaround may exist. |
| Low | Cosmetic, documentation, or minor tooling defect. |

## Rules

1. **Evidence, not adjectives.** Include the exact command, error text, file hash/version, or
   a path under `artifacts/`.
2. **Link, don't duplicate.** Reference the task (`T-###`), ADR, or experiment involved.
3. **Blocking issues change state.** If an issue blocks a task: set the task to `Blocked` on
   [`../tasks/BOARD.md`](../tasks/BOARD.md) and add the issue ID to `blockers` in
   [`../state.json`](../state.json).
4. **Fixes require verification.** A `Fixed` issue names the test/command that proves it,
   and the log entry that records the fix.
5. **Never delete.** Reopen a closed issue with a dated note if it recurs; do not rewrite
   history.
| [ISSUE-0012](ISSUE-0012-shockwave-harness-autostart-crash.md) | Test harness auto-start crashes on ShockWave data | Low | Workaround | T-036 |
| [ISSUE-0013](ISSUE-0013-windowed-edge-scroll-disabled.md) | Screen-edge scrolling disabled in the borderless profile | Medium | Fixed | T-044 |
| [ISSUE-0014](ISSUE-0014-broadphase-z-center.md) | Broadphase used bottom-center positions for the 3D sphere test | High | Fixed | T-049 |
| [ISSUE-0015](ISSUE-0015-engine-patch-series-not-reproducible.md) | The per-task engine patches cannot be applied as a series | Medium | Fixed | T-049 |
| [ISSUE-0016](ISSUE-0016-harness-env-and-state-leaks.md) | Test-harness environment and object state leak into later runs | Medium | Fixed | T-049 |
| [ISSUE-0017](ISSUE-0017-validator-artifact-links.md) | Validator treats gitignored artifact evidence as broken links | Low | Fixed | T-049 |

| [ISSUE-0018](ISSUE-0018-broadphase-evidence-filename.md) | Broadphase evidence names a nonexistent CSV | Low | Fixed | T-050 |

| [ISSUE-0019](ISSUE-0019-broadphase-summary-population.md) | Broadphase frame p95 summary lacks reproducible sample window | Low | Fixed | T-050 |

| [ISSUE-0020](ISSUE-0020-engine-hash-identifies-one-link.md) | A rebuilt engine never matches the recorded SHA-256 | Medium | Fixed | T-051 |

| [ISSUE-0021](ISSUE-0021-broadphase-cylinder-radius.md) | Debris broadphase rejects real collisions against tall cylinders | Medium | Fixed | T-055 |

| [ISSUE-0022](ISSUE-0022-launcher-nofpslimit-noop.md) | FPS-unlock switch did nothing in release builds | Medium | Fixed | T-057/T-058 |
| [ISSUE-0023](ISSUE-0023-draw-distance-hides-units.md) | Units pop out of view when the camera moves (DrawDistance default-on) | High | Fixed | T-064 |
| [ISSUE-0024](ISSUE-0024-cosmetic-skip-hides-debris.md) | Debris are never drawn while CosmeticPartition is on | High | Fixed | T-073 |

| [ISSUE-0025](ISSUE-0025-artifact-manifests-missing.md) | Missing manifests for artifact runs | Low | Open | T-074 |
| [ISSUE-0026](ISSUE-0026-entrypoint-state-drift.md) | Entrypoint overview disagrees with canonical state | Low | Open | T-074 |
| [ISSUE-0027](ISSUE-0027-audit-commit-sandbox.md) | Audit commit requires Git metadata permission | Low | Fixed | T-074 |
| [ISSUE-0028](ISSUE-0028-cleanup-preflight-directory-type.md) | Cleanup preflight directory type check | Low | Fixed | T-075 |

| [ISSUE-0029](ISSUE-0029-disabled-counter-lifecycle.md) | Disabled-scan counter omits snapshot loading and object lifecycle | High | Fixed | T-078 |
| [ISSUE-0030](ISSUE-0030-broadphase-yes-parses-false.md) | Documented DebrisBroadphase=yes disables the optimization | Medium | Fixed | T-078 |
| [ISSUE-0031](ISSUE-0031-fps-latch-overrides-ui.md) | Cached uncapped state overrides live FPS controls | Medium | Fixed | T-078 |
| [ISSUE-0032](ISSUE-0032-staging-destination-unguarded.md) | Engine staging accepts immutable or arbitrary destinations | High | Fixed | T-078 |
| [ISSUE-0033](ISSUE-0033-launcher-diagnostic-env-leaks.md) | Launcher environment isolation omits newer gameplay diagnostics | Medium | Fixed | T-078 |
| [ISSUE-0034](ISSUE-0034-destroy-overflow-still-truncates.md) | Destroy-list overflow fallback still removes only 256 updates | Medium | Fixed | T-078 |

| [ISSUE-0035](ISSUE-0035-review-harness-execution-policy.md) | Local review harness rejected by execution policy | Low | Fixed | T-078 |

| [ISSUE-0036](ISSUE-0036-continuity-legacy-encoding.md) | Continuity checkpoint uses legacy encoding | Low | Fixed | T-078 |

| [ISSUE-0037](ISSUE-0037-remediation-test-harness.md) | T-079 regression harness refinement | Low | Fixed | T-079 |

| [ISSUE-0038](ISSUE-0038-sandbox-msbuild-workers.md) | Sandboxed MSBuild workers stall | Medium | Fixed | T-079 |

| [ISSUE-0039](ISSUE-0039-copy-verifier-default-root.md) | Copy verifier default root fails under -File | Low | Fixed | T-079 |

| [ISSUE-0040](ISSUE-0040-pathfinding-edit-anchor.md) | Pathfinding edit assumed a precompiled-header include | Low | Fixed | T-022 |

| [ISSUE-0041](ISSUE-0041-pathfinding-scope-edit.md) | Telemetry wrapper closed before search ended | Low | Fixed | T-022 |

| [ISSUE-0042](ISSUE-0042-pathfinding-offmap-spawn.md) | Movement workload spawned near map edge | Medium | Fixed | T-022 |

| [ISSUE-0043](ISSUE-0043-pathfinding-link-pdb.md) | Incremental build cannot write PDB | Medium | Workaround | T-022 |

| [ISSUE-0044](ISSUE-0044-shadow-map-prototype-build.md) | Shadow prototype compile errors | Low | Fixed | T-035 |

| [ISSUE-0045](ISSUE-0045-shadow-probe-options-permission.md) | Shadow probe preferences write denied | Low | Fixed | T-035 |

| [ISSUE-0046](ISSUE-0046-shadow-map-float-target.md) | System D3D8 rejects float shadow target | Medium | Workaround | T-035 |

| [ISSUE-0047](ISSUE-0047-shadow-visual-hidden-window.md) | Visual probe hid game window | Low | Fixed | T-035 |

| [ISSUE-0048](ISSUE-0048-shadow-depth-export.md) | R32F depth export fails | Low | Fixed | T-035 |

| [ISSUE-0049](ISSUE-0049-shadow-window-capture.md) | Visible renderer capture failed | Low | Fixed | T-035 |

| [ISSUE-0050](ISSUE-0050-shadow-map-submission-regression.md) | First shadow prototype regresses frame time | Medium | Investigating | T-035 |

| [ISSUE-0051](ISSUE-0051-shadow-constant-cache-restore.md) | Cached constants produce black world | Medium | Fixed | T-035 |

| [ISSUE-0052](ISSUE-0052-session-doc-encoding.md) | Session documentation encoding | Low | Fixed | T-022, T-035 |

| [ISSUE-0053](ISSUE-0053-queue-trace-truncated-tail.md) | Queue trace truncated tail | Low | Fixed | T-022 |

| [ISSUE-0054](ISSUE-0054-shadow-map-self-shadow-mask.md) | Tank self-shadow mask needs validation | Medium | Investigating | T-035 |

| [ISSUE-0055](ISSUE-0055-workload-blockers-not-registered.md) | Workload blockers missing navigation registration | Medium | Fixed | T-022 |

| [ISSUE-0056](ISSUE-0056-heap-integration-test-build.md) | Extracted heap test build failure | Low | Fixed | T-022 |

| [ISSUE-0057](ISSUE-0057-launcher-tests-junction-permission.md) | Mock launcher junction permission | Low | Fixed | T-022 |

| [ISSUE-0058](ISSUE-0058-batched-shadow-receiver-coverage.md) | Batched receiver inherits caster exclusions | Medium | Investigating | T-035 |

| [ISSUE-0059](ISSUE-0059-rigid-shadow-cache-mutation.md) | Rigid cache misses geometry mutation | Medium | Fixed | T-035 |

| [ISSUE-0060](ISSUE-0060-shadow-calibration-missing-shadow.md) | Isolated calibration lacks ground shadow | High | Fixed | T-035 |

| [ISSUE-0061](ISSUE-0061-screen-mask-readback-null-depth.md) | Fullscreen readback assumes bound depth | Medium | Fixed | T-035 |

| [ISSUE-0062](ISSUE-0062-fullscreen-shadow-all-lit.md) | Fullscreen comparison misses calibrated shadow | High | Fixed | T-035 |

| [ISSUE-0063](ISSUE-0063-screen-disassembly-build.md) | Diagnostic disassembly API declaration | Low | Fixed | T-035 |

| [ISSUE-0064](ISSUE-0064-pixel-constant-range.md) | PS1.x reconstruction constant range | High | Fixed | T-035 |

| [ISSUE-0065](ISSUE-0065-grazing-shadow-acne.md) | Grazing face shadow-map acne | High | Investigating | T-035 |

| [ISSUE-0066](ISSUE-0066-stress-scene-not-visible.md) | Stress comparison creates units that do not draw | Medium | Fixed | T-035 |

| [ISSUE-0067](ISSUE-0067-launcher-overrides-heap-default.md) | Launcher overrides the new singleplayer heap default | Medium | Fixed | T-022 |

| [ISSUE-0068](ISSUE-0068-queue-comment-breaks-csv.md) | Queue annotation breaks existing pathfinding analyzers | Medium | Fixed | T-022 |

| [ISSUE-0069](ISSUE-0069-shadow-benchmark-removed-default.md) | Shadow benchmark defaults to a removed renderer | Medium | Fixed | T-035 |

| [ISSUE-0070](ISSUE-0070-completion-metadata-stale.md) | Completion metadata predates the final heap build | Low | Fixed | T-022, T-035 |

| [ISSUE-0071](ISSUE-0071-rejected-source-untracked.md) | Latest rejected renderer source exists only in ignored artifacts | Medium | Fixed | T-035 |

| [ISSUE-0072](ISSUE-0072-completion-evidence-manifests.md) | Completion evidence directories lack required manifests | Low | Fixed | T-035 |

| [ISSUE-0073](ISSUE-0073-preflight-test-automatic-variable.md) | Preflight test automatic variable collision | Low | Fixed | T-035 |

| [ISSUE-0074](ISSUE-0074-review-log-encoding.md) | Review closeout implicit text encoding | Low | Fixed | T-035 |

| [ISSUE-0075](ISSUE-0075-patcher-offline-registry.md) | Patcher offline registry index absent | Low | Fixed | T-080 |

| [ISSUE-0076](ISSUE-0076-patcher-fixture-syntax.md) | Patcher fixture reserved keyword | Low | Fixed | T-080 |

| [ISSUE-0077](ISSUE-0077-patcher-test-fixture-location.md) | Patcher synthetic fixture location | Low | Fixed | T-080 |

| [ISSUE-0078](ISSUE-0078-alpha-lzhl-offline-configure.md) | Alpha offline LZHL configuration | Low | Fixed | T-080 |

| [ISSUE-0079](ISSUE-0079-shockwave-launcher-map-scope.md) | ShockWave archive and loose-script routing | Medium | Fixed | T-080 |

| [ISSUE-0080](ISSUE-0080-alpha-build-process-stall.md) | Alpha build helper process stall | Medium | Fixed | T-080 |

| [ISSUE-0081](ISSUE-0081-alpha-harness-helper-declarations.md) | Alpha harness helper declarations | Low | Fixed | T-080 |

| [ISSUE-0082](ISSUE-0082-patcher-full-copy-roundtrip.md) | Full-copy uninstall inventory mismatch | High | Fixed | T-080 |

| [ISSUE-0083](ISSUE-0083-guard-radius-below-weapon-range.md) | Guard radius can truncate usable weapon range | Medium | Fixed | T-081 |

| [ISSUE-0084](ISSUE-0084-big-zero-length-entry.md) | BIG reader rejects a zero-length PatchZH archive marker | Low | Fixed | T-081 |

| [ISSUE-0085](ISSUE-0085-guard-fixture-controller.md) | Guard fixture controller/relationship setup | Medium | Fixed | T-081 |

| [ISSUE-0086](ISSUE-0086-guard-control-runtime-crash.md) | Guard control crash during weapon fire | High | Fixed | T-081 |

| [ISSUE-0087](ISSUE-0087-weapon-fire-recoil-null.md) | Weapon fire FX writes through empty recoil storage | High | Fixed | T-081 |
