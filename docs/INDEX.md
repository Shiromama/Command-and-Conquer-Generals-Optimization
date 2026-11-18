# Documentation index & conventions

> **Status:** living document · **Last verified:** 2026-11-14
> This is the catalog of project knowledge. `AGENTS.md` is the agent entry point; this file
> explains what each document is for and how to keep the set coherent as work progresses.

## 1. Reading order

| Order | Document | Read it when |
|---|---|---|
| 1 | [`../AGENTS.md`](../AGENTS.md) | Always, first. |
| 2 | [`state.json`](state.json) | Always — current phase, focus, next actions, blockers. |
| 3 | [`project-brief.md`](project-brief.md) | You need the goal, scope, and success criteria. |
| 4 | [`environment.md`](environment.md) | You need verified machine/toolchain/install facts. |
| 5 | [`game-inventory.md`](game-inventory.md) | You need to know what exists in the game folder. |
| 6 | [`architecture.md`](architecture.md) | You are planning where code or instrumentation fits. |
| 7 | [`roadmap.md`](roadmap.md) | You need the phase plan and exit criteria. |
| 8 | [`tasks/BOARD.md`](tasks/BOARD.md) | You are picking or updating a task. |
| 9 | [`decisions/`](decisions/README.md) | A structural choice was or will be made. |
| 10 | [`research/`](research/TEMPLATE.md), [`experiments/`](experiments/TEMPLATE.md) | You are producing durable findings. |
| 11 | [`glossary.md`](glossary.md) | A term is unfamiliar. |
| 12 | [`issues/`](issues/README.md) | Something failed, contradicts docs, or blocks work. |
| 13 | [`game-copies.md`](game-copies.md) | You need the baseline/work copy identity, hashes, or portable copy workflow. |
| 14 | [`research/2026-11-14-engine-digestion.md`](research/2026-11-14-engine-digestion.md) | You need the low-level bottleneck map and community fix list. |
| 99 | [optimizations.md](optimizations.md) | You want to change the engine's performance settings (draw distance, shadow LOD, debris broadphase, FPS cap) in-game or in Options.ini. |
| 15 | [`research/2026-11-14-fullscreen-source-plan.md`](research/2026-11-14-fullscreen-source-plan.md) | You are implementing the exclusive-fullscreen source fix. |
| 16 | [`research/2026-11-14-engine-build-results.md`](research/2026-11-14-engine-build-results.md) | You need build, DPI, fullscreen, or frame-log evidence. |
| 17 | [`experiments/EXP-001-msaa-entity-heavy.md`](experiments/EXP-001-msaa-entity-heavy.md) | You need the measured entity-heavy baseline and first optimization. |
| 18 | [`experiments/EXP-002-scene-distance-cull.md`](experiments/EXP-002-scene-distance-cull.md) | You need the opt-in draw-distance cull result. |
| 19 | [`experiments/EXP-003-static-low-detail.md`](experiments/EXP-003-static-low-detail.md) | You need the visibility-preserving Low-detail profile result. |
| 20 | [`experiments/EXP-004-architecture-headroom.md`](experiments/EXP-004-architecture-headroom.md) | You need uncapped headroom and shadow-volume cost evidence. |
| 21 | [`experiments/EXP-005-screen-size-shadow-lod.md`](experiments/EXP-005-screen-size-shadow-lod.md) | You need the 120 px shadow LOD result. |
| 22 | [`experiments/EXP-006-d3d8to9-wrapper.md`](experiments/EXP-006-d3d8to9-wrapper.md) | You need the optional d3d8to9 A/B result. |
| 23 | [`experiments/EXP-007-projected-shadow-rejected.md`](experiments/EXP-007-projected-shadow-rejected.md) | You need the rejected projected/decal shadow prototype result. |
| 24 | [`research/2026-11-15-external-performance-research.md`](research/2026-11-15-external-performance-research.md) | You need upstream/OpenSAGE/RTS comparisons for the performance choices. |
| 25 | [`../engine/README.md`](../engine/README.md) | You are building, patching, or staging the source engine. |
| 26 | [`log.md`](log.md) | You need the chronological history of the project. |
| 27 | [`game-inventory-shockwave.md`](game-inventory-shockwave.md) | You are working on the ShockWave mod (data-only, `.gib`/launcher, adapter reality). |
| 28 | [`experiments/EXP-008-shockwave-nuke-performance.md`](experiments/EXP-008-shockwave-nuke-performance.md) | You need the ShockWave nuke/destruction and GPU-adapter measurements. |
| 29 | [`decisions/ADR-0007-shockwave-two-profiles.md`](decisions/ADR-0007-shockwave-two-profiles.md) | You are choosing between the performance engine and retail+GenTool. |

| 30 | [`research/2026-11-15-low-level-optimization-validation.md`](research/2026-11-15-low-level-optimization-validation.md) | You need evidence, priorities and experiment gates for memory layout, allocation, SIMD, threading, pathfinding and Rust. |

## 2. Document catalog

| Document | Kind | Maintained by | Update trigger |
|---|---|---|---|
| [`project-brief.md`](project-brief.md) | Stable intent | Lead | Scope/goal changes only |
| [`state.json`](state.json) | Machine state | Lead | Every session end |
| [`environment.md`](environment.md) | Verified facts | Whoever verifies | Toolchain/machine change |
| [`game-copies.md`](game-copies.md) | Baseline identity | Whoever runs copies | New baseline or profile |
| [`game-inventory.md`](game-inventory.md) | Verified facts | Whoever verifies | New install inspection |
| [`architecture.md`](architecture.md) | Living model | Whoever learns | New verified engine knowledge |
| [`roadmap.md`](roadmap.md) | Plan | Lead | Phase or priority change |
| [`tasks/BOARD.md`](tasks/BOARD.md) | Task ledger | All agents | Task create/start/finish/block |
| [`decisions/`](decisions/README.md) | Append-only ADRs | Decision maker | Any structural decision |
| [`research/`](research/TEMPLATE.md) | Durable notes | Researcher | Research completed |
| [`experiments/`](experiments/TEMPLATE.md) | Experiment records | Experimenter | Experiment run |
| [`glossary.md`](glossary.md) | Terminology | All agents | New term appears |
| [`issues/`](issues/README.md) | Problem register | All agents | Any failure/blocker found or resolved |
| [`log.md`](log.md) | Append-only history | All agents | Every session |
| [`../.opencode/continuity.md`](../.opencode/continuity.md) | Session checkpoint | Lead | Every session start/end |

## 3. Conventions

### 3.1 Evidence

Every non-obvious factual claim gets one of the labels defined in
[`../AGENTS.md`](../AGENTS.md) §4: `[VERIFIED]`, `[SOURCED]`, `[INFERRED]`, `[UNKNOWN]`.
Prefer a command + output capture over prose. Store bulky output in `artifacts/` and cite it.

### 3.2 Dates and IDs

- Dates are ISO-8601 (`YYYY-MM-DD`) and use the local session date.
- Tasks: `T-###` (monotonic, never reused). Decisions: `ADR-####` (monotonic).
- Experiments: `EXP-###`. Research notes: `RES-###` or `YYYY-MM-DD-slug`.
- Milestones: `M#`.

### 3.3 Append-only documents

`log.md` and accepted ADRs are append-only. Never rewrite history; add a dated correction
entry and, for ADRs, add a new ADR that supersedes the old one.

### 3.4 Writing for other agents

- Lead with the conclusion; put evidence after it.
- Use explicit paths, hashes, versions, and counts instead of "the folder", "the DLL".
- Mark every hypothesis as such; do not let a guess harden into a project fact.
- Keep each document scannable: headings, tables, short bullets.
- Do not paste secrets, licence keys, or large binary dumps into docs.

### 3.5 Placeholders

Templates under `research/` and `experiments/` use `<angle-bracket>` placeholders and are
exempt from the placeholder check. Any other document must not contain `{{`, `TODO:`, or
`FIXME`; `tools/check_docs.py` enforces this and skips `TEMPLATE.md` files.

## 4. Update protocol (summary)

1. Start: `state.json` → `tasks/BOARD.md` → mark task In Progress.
2. Work: capture evidence; write research/experiment files as needed.
3. Decide: record an ADR; link it from the task and log.
4. Finish: append `log.md`; update `state.json`, `BOARD.md`, `.opencode/continuity.md`.
5. Verify: `python tools/check_docs.py` must pass; commit with the task ID.

Full protocol: [`../AGENTS.md`](../AGENTS.md) §6.

## Workspace maintenance

- [2026-11-17 cleanup audit](research/2026-11-17-workspace-cleanup-audit.md): measured disk usage, evidence retention, and review candidates; no deletions.

- [2026-11-17 cleanup results](research/2026-11-17-cleanup-results.md): 6.99 GiB removed; preserved evidence and verification.

- [Independent optimization engineering review](research/2026-11-17-optimization-engineering-review.md): correctness findings, independently reanalysed benchmarks and universal-patcher release gates (T-078).

- [Optimization inspection remediation](research/2026-11-17-optimization-remediation.md): T-079 fixes, exact build/test results and experimental-singleplayer boundary.

- [Movement/pathfinding workload](experiments/EXP-025-pathfinding-workload.md): T-022 telemetry, six-run determinism and queue measurements.
- [Real shadow-map prototype](experiments/EXP-026-shadow-map-prototype.md): T-035 capability and calibration record; renderer rejected by EXP-029.

- [EXP-027: stable pathfinding heap](experiments/EXP-027-stable-pathfinding-heap.md) — corrected fixture, native timing and parity, explicit experimental selection.

- [EXP-028: analytic shadow calibration](experiments/EXP-028-shadow-calibration.md) — independent box/plane visibility, perspective fullscreen core, hardware depth/slope and capability fallback.

- [EXP-029: shadow-map rejection](experiments/EXP-029-shadow-map-rejected.md) - measured stencil comparison, wrapper-only constraint and source revert.

- [EXP-030: guard-range runtime validation](experiments/EXP-030-guard-range-runtime.md) - native control/fixed evidence for the singleplayer human guard floor, long-range stock units and 67 compiled source cases.

- [Community mod installation](research/2026-11-18-community-mod-installation.md) - GenLauncher/ZHModLauncher/engine `-mod` findings behind the transactional mod overlay (ADR-0019).
- [Mod overlay delivery and verification](research/2026-11-18-mod-overlay-delivery.md) - T-082 architecture, supported formats, test matrix, package identity and limitations.

- [T-022/T-035 review fixes](research/2026-11-18-review-fixes.md): launcher defaults, strict telemetry parsing, benchmark preflight and tracked rejected-source provenance.

- [DeepSeek alpha engineering review](research/2026-11-18-deepseek-engineering-review.md) — T-084 package checks and reproduced candidate 9 findings.

- [Candidate 10 overlay repair](research/2026-11-18-overlay-repair.md) — case aliases, exact-base verification, metadata preservation and the retained command-prompt installer.

- [Console progress design](research/2026-11-18-console-progress-design.md) — T-090 status stages and measured file counts.
