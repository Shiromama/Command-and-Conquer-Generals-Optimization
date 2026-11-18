# ISSUE-0006: Performance drops with many entities

- **Status:** Workaround
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-028
- **Related:** [`../experiments/EXP-001-msaa-entity-heavy.md`](../experiments/EXP-001-msaa-entity-heavy.md), [`../experiments/EXP-002-scene-distance-cull.md`](../experiments/EXP-002-scene-distance-cull.md), [`../experiments/EXP-003-static-low-detail.md`](../experiments/EXP-003-static-low-detail.md), ISSUE-0007
- **Environment:** i5-10300H (4C/8T), 24 GB RAM, GTX 1650 Ti + Intel UHD, 1920×1080@144

## Symptom

Reported by the user: frame rate degrades as the number of entities grows. No baseline,
scenario, or settings matrix has been captured yet.

## Reproduction / evidence

Reproduced with the test-only harness in `engine/patches/T-015-benchmark-harness.patch`:
`ZH_MAP=maps\northamerica\northamerica.map`, `ZH_STRESS=1000`, 1920×1080, 3 × 40 s runs.
Split timing at AA 8×: `draw` 50.32 ms, `logic` 4.49 ms. Relevant verified configuration:

- `options.ini`: `Resolution = 1920 1080`, `StaticGameLOD = High`, `MaxParticleCount = 5000`,
  `DynamicLOD = yes`, `UseShadowVolumes = yes`, `UseShadowDecals = yes`,
  `AntiAliasing = 14`. `[VERIFIED]`
- `Skirmish.ini`: `FPS = 30`, `StartingCash = 50000`, map `northamerica`. `[VERIFIED]`
- Engine is a 32-bit, single-threaded-logic 2003 RTS with a **30 FPS cap** in normal play;
  GenTool can raise the cap but changes game speed unless logic is decoupled. `[SOURCED]`
- CPU has 4 physical cores; the simulation is expected to be CPU-bound with many units.
  `[INFERRED]`

## Impact

Late-game skirmishes become unplayable at high unit counts. This is the primary optimization
target after fullscreen.

## Root cause

Measured on the 1,000-unit scene: **rendering dominates**, not simulation. At AA 8× the split
was `draw` 50.32 ms and `logic` 4.49 ms (EXP-001). The largest controllable components found:

1. **MSAA** — `AntiAliasing = 14` silently clamps to 8×; turning it off removed ~21 ms.
   `[VERIFIED]` EXP-001.
2. **Shadow/lightmap/particle passes** — the built-in Low detail preset reduced draw
   submission from 27.26 to 18.45 ms while keeping every unit visible. `[VERIFIED]` EXP-003.
3. **Remaining draw submission** at High detail (~27 ms) — draw-call/object submission, not
   model detail (distance LOD gave no gain). `[INFERRED]` EXP-002.
4. Memory/asset behavior at high unit counts remains unmeasured; logic was only ~5 ms here.

## Workaround

The portable `performance` profile sets `AntiAliasing = 0` and `StaticGameLOD = Low`:

```powershell
tools\apply-options-profile.ps1 -Profile performance
```

Measured median frame time **59.41 → 33.36 ms (1.78×)**, draw time **50.32 → 18.45 ms**, and
effective FPS **16.8 → 30.0** (the engine cap). All 1,000 units remain visible; Low detail
disables shadows/lightmaps/heat effects and lowers particles (EXP-001, EXP-003). Original
Options.ini is backed up under `artifacts/options-backups/`. `balanced` (AA 2 + Medium) and
`default` (AA 8 + High) profiles are available.

## Resolution / verification

Workaround verified on the 1,000-unit synthetic scene:
- AA 14 (8×) → 0: median **59.41 → 35.05 ms (1.70×)**, draw **50.32 → 27.26 ms** (EXP-001).
- AA 0 + Low detail: median **35.05 → 33.36 ms**, p95 **40.20 → 36.85 ms**, draw
  **27.26 → 18.45 ms** (EXP-003). All units visible; 30 FPS cap reached.
- Opt-in distance cull 400: median **35.05 → 33.30 ms**, p95 **40.20 → 36.65 ms**, draw
  **27.26 → 18.1 ms** (EXP-002). Units beyond 400 units are hidden, so this is opt-in only.

Architecture research, clean environment (EXP-004/005): with the cap removed, Low runs
17.47 ms (57.2 FPS), so the cap hides ~16 ms. High detail is shadow-volume bound (25.02 ms
uncapped); shadows off is 17.63 ms, and a 120 px screen-size shadow LOD is 20.30 ms with
large/near shadows kept. The next source target is a shadow-map/blob prototype, not batching.
Re-confirm on a real late-game replay before closing; an AA clamp is still a follow-up.

## History

- 2026-11-14 — recorded from user report; settings and hardware inspected.
- 2026-11-15 — 1,000-unit scenario measured; AA 8× identified as dominant render cost; profile
  applied and measured 1.70× improvement (EXP-001).
- 2026-11-15 — opt-in scene distance cull measured; draw time 27.26 → 18.1 ms (EXP-002).
- 2026-11-15 — Low detail preset measured; median 35.05 → 33.36 ms, draw 27.26 → 18.45 ms,
  all units visible; performance profile now applies AA 0 + Low (EXP-003).
- 2026-11-15 — uncapped headroom measured (Low 37.7 FPS); shadow volumes identified as the
  High-detail cost; shadow distance 400 recovers 7 ms with units visible (EXP-004).
- 2026-11-15 - screen-size shadow LOD at 120 px gives clean High 20.30 ms uncapped, draw
  15.20 ms, near/large shadows kept (EXP-005). Optional d3d8to9 gave 5.7% Low and 8.4%
  High+120 px gains in a clean A/B (EXP-006). Clean Low is 17.47 ms (57.2 FPS).
- 2026-11-15 - existing projected-shadow path stalled on render-to-texture creation and the
  decal path showed no clear visual gain; reverted. Keep the 120 px LOD; real shadow maps need
  a renderer project (EXP-007, T-035).
