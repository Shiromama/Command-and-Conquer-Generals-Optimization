# Independent review of T-022/T-035 completion

- Date: 2026-11-17
- Reviewed HEAD: 7ce0636574bfb5e39674066e11f2ded5a10da91f
- Scope: source, launch integration, telemetry, retained measurements and reproducibility
- Result: Changes requested. No real game launched and no gameplay source changed.

## Findings

1. **Normal launcher disables the newly requested heap default.** [VERIFIED] launch-game.ps1:72/151 sets List and child ZH_PF_HEAP=0, overriding the engine default. Reproduced through the actual launcher with a mocked process. The existing test explicitly expects List, so its green result does not cover ADR0016's intended behavior. [ISSUE-0067](../issues/ISSUE-0067-launcher-overrides-heap-default.md).
2. **New telemetry is incompatible with the existing verification tools.** [VERIFIED] The # queue line is parsed as a malformed request; compare-pathfinding.py rejects both actual new logs, and analyze-pathfinding.py's frame conversion cannot consume it. This prevents fresh parity/measurement analysis. [ISSUE-0068](../issues/ISSUE-0068-queue-comment-breaks-csv.md).
3. **Retained benchmark's default invokes removed functionality.** [VERIFIED] benchmark-shadow-map.ps1 still defaults ShadowMap and later requires its log, while current source is stencil-only. Fix preflight/default selection. [ISSUE-0069](../issues/ISSUE-0069-shadow-benchmark-removed-default.md).
4. **Latest calibrated source is only a local ignored archive.** [VERIFIED] It is absent from subsequent tracked cumulative patches. Preserve a tracked rejected-source snapshot/base for reproduction, without re-enabling it. [ISSUE-0071](../issues/ISSUE-0071-rejected-source-untracked.md).
5. **Evidence provenance is incomplete.** [VERIFIED] Dense/rejected artifact directories have no required manifest.md. [ISSUE-0072](../issues/ISSUE-0072-completion-evidence-manifests.md). Stale final hash/default documentation is corrected in this review checkpoint ([ISSUE-0070](../issues/ISSUE-0070-completion-metadata-stale.md)).

## What holds up

[VERIFIED] Independent recalculation from all six dense frames.csv files reproduces ShadowMap/Stencil median ratios1.109337,1.166954,1.148120. Parameter records show alternating launch order, the same executable,1920x1080 and wrapper in both arms. A-3/B-3 screenshots visibly contain the same tank scene. These support rejecting the tested R32F/per-mesh-receiver prototype; no shadow-map improvement should be shipped from that evidence.

[VERIFIED] Current actual-source heap regression tests pass10queue semantics cases and12mode guards. The review redirects only generated test output into its own artifact folder to preserve prior receipts. Current source-patch reverse-check passes; documentation checker passes before review changes. Built/staged executable hashes agree at0C4C74CC...7293.

## Scope boundary

[VERIFIED] EXP029 openly states that live main-depth capture/fullscreen receiving from ADR0014 was not built, and final dense measurements use the R32F diagnostic path. The rejection is supported for that tested design. It does not validate or reject the unbuilt fullscreen architecture, and does not deliver a faster real shadow-map renderer. Treat task closure as a negative prototype study, rather than successful delivery of the original renderer goal. Broader heap rollout evidence is still limited to local singleplayer fixtures; network/replay remain forced List in source.

## Verification evidence

artifacts/2026-11-17-independent-review/manifest.md records the independent recalculation, mocked launcher, actual request-log parser failures, source checks and regressions. Review did not resume the usage-limited implementation goal or run the game. Code findings remain unfixed for a separate implementation pass.
