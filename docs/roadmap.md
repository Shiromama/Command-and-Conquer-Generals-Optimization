# Roadmap

> **Status:** proposed plan · **Last verified:** 2026-11-15 · **Owner:** project lead
> Phases change only via the update protocol; record changes in [`log.md`](log.md) and
> [`state.json`](state.json). All hypotheses below are unvalidated until an experiment
> record proves otherwise.

## Phase overview

| Phase | Name | Status | Exit criterion |
|---|---|---|---|
| **P0** | Setup & agent-readable documentation | **Complete** | Docs system validated; environment and install facts recorded. |
| **P1** | Isolation, baseline & first fixes | **Complete** | Read-only baseline + work copy verified; fullscreen fixed; source build and 1,000-unit benchmark working. |
| **P2** | Build, profile & optimize engine | **In progress** | Reproducible performance improvement with scenario regression checks. See [current state](state.json) for measurements and remaining validation. |
| **P3** | Former standalone tooling phase | Retired | See [ADR-0021](decisions/ADR-0021-engine-optimization-scope.md). |
| **P4** | Integration & hardening | Backlog | Repeatable build/run, behavior verified, docs updated. |

## P0 — Setup & agent-readable documentation (complete)

Goal: make the project legible to any agent from the repository alone.

Deliverables (done):

- `AGENTS.md` entry point with hard rules, evidence labels, update protocol.
- Verified environment and installation inventories with hashes/sizes.
- Living architecture model, roadmap, glossary, ADR log, task ledger, append-only work log.
- Machine-readable `state.json` + cross-session checkpoint.
- `tools/check_docs.py` validator with self-test.

Evidence: see [`log.md`](log.md) entry of 2026-11-14.

## P1 — Isolation, baseline & first fixes (complete)

Goal: make every later result trustworthy and portable.

Done:

1. Copy the complete install into a read-only, hashed baseline and a mutable work copy
   (`game/baseline-pristine/`, `game/work/`); source install untouched.
2. Add parameterized copy/verify/launch scripts; no registry or hardcoded paths.
3. Fix fullscreen on the work copy (`window=3` profile) and verify a 1920×1080 client area.
4. Decide the optimization surface (ADR-0005) and map the engine’s scaling costs
   ([`research/2026-11-14-engine-digestion.md`](research/2026-11-14-engine-digestion.md)).

5. Build the GPLv3 source (T-014).
6. Define and capture the entity-heavy benchmark (T-015).
7. Instrument the top hotspots with Tracy (T-017).

Exit criteria: a working source build, a measured entity-heavy baseline, and a ranked first
optimization target.

## P2 — Build, profile & optimize engine

Goal: locate the actual cost and change it, with before/after measurements.

Candidate work, in expected order:

1. Particle sort/batching (`sortingrenderer.cpp:324-337`, community PR #3557).
2. Drawable region spatial index (`W3DView.cpp:1688` TODO; replaces a per-frame full scan).
3. Pathfinding open-list/allocation (`PathfindCell.cpp`; CRC risk — single-player only first).
4. Fullscreen/adapter source fixes (#3656, #28, #3049, first-adapter selection).
5. Build-level A/B: `/LARGEADDRESSAWARE`, LTCG, PGO; measure, don’t assume.

Exit criteria: a ranked list of costs with measurements; at least one optimization with a
reproducible improvement; no regression in the fixed scenario.

## P4 — Integration & hardening

Goal: make the result ordinary to use: reproducible build, version pinning, regression checks,
documentation, and a release procedure.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Game binary is packed/protected | Medium | High | Test instrumentation early in P1; fall back to external tools. |
| GenTool conflicts with proxy approach | High | Medium | Chainload as `d3d8x.dll`; keep GenTool for widescreen; measure with it on/off. |
| Measurement noise makes wins unprovable | Medium | High | Fixed scenario, repeated runs, report variance. |
| Source dependency downloads blocked | High | High | Ask for approval; pin revisions; build offline after first fetch. |
| Game assets accidentally committed | Low | High | `.gitignore` + hard rules + validator reminders. |
| Baseline/work copies drift | Medium | High | Read-only baseline + SHA-256 manifest verification before each experiment. |

## Non-goals for the roadmap

- Engine rewrite.
- Asset redistribution.
- Online-play modification or anti-cheat work.
