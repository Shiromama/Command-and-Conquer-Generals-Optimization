# ISSUE-0066: Stress comparison scene creates units that do not draw

- **Status:** Investigating
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] The harness logs `created=1000` and a first-object position, but the 1,000-unit stress
grid is not visible in captured frames. `probe-passable/scene.png`, `probe-defcon6-passable/
scene.png`, `probe-defcon6-zoom/scene.png` and `probe-delay/scene.png` show terrain, trees and, in
one case, a civilian truck, but no tanks, while `stress.log` reports:

```
spawn cycle=1 frame=60 count=1000 cols=25 rows=40 spacing=38.06 radius=18.03 cleaned=0
created=1000 first=2615.0,1495.0,45.9 view=3068.0,2241.3,120.0
```

[VERIFIED] The shadow-map caster count in the same configuration is 494 (trees/props only,
109,373 triangles), not roughly 1,000 casters plus props as a visible tank grid would produce.

[VERIFIED] The map's geometric centre on northamerica is water: the earlier `ZH_STRESS_CENTER_MAP`
implementation placed both the grid and the camera there, and those captures showed open ocean.
That specific failure is understood.

## Impact

Any A/B that relies on this scene is measuring an almost empty world. The T-035 controlled pairs
in `artifacts/2026-11-17-t035-ab/` are valid as a same-scene renderer comparison but do not
represent the 1,000-unit workload. Do not cite them as dense-scene evidence.

## Attempted fixes (all built, engine runs, units still absent)

1. `ZH_STRESS_PASSABLE=1` adjusts each unit onto pathfinder-passable ground, reusing the T-022
   fixture step (`zhPfCompleteObject` + `adjustDestination`).
2. `ZH_STRESS_DELAY=<frames>` postpones the first spawn until the tactical view has a real start
   position; `stress.log` confirms the spawn then happens at frame 60 with the camera at
   `(3068, 2241)`.
3. A 240-frame camera pin re-applies `lookAt` to the grid centre plus `setZoom(1.0)`, because the
   game repositions the view after the first logic frame.
4. `tools/benchmark-shadow-map.ps1` gained `-Passable`, `-SpawnDelayFrames`, `-Screenshot`,
   `-Map` and `-AtCamera`, and records the scene image inside the timed run.

[UNKNOWN] Why created units are not drawn or registered as shadow casters. Candidates: the objects
are destroyed or hidden immediately after `setPosition`; the spawn height places them under the
terrain mesh; or the neutral-team template cannot produce drawables in this build. The next
diagnostic should log live object count, `isDestroyed`, `getDrawable`, and `isVisible` after a
delay instead of relying on `stressIds.size()` (which only proves `newObject` returned objects).

## Resolution / verification

## Resolution (2026-11-17) — fixed

[VERIFIED] Root cause was in the measurement harness, not the game: the comparison camera was
pinned for only 240 frames (~2-4 s), and every screenshot was captured 8-13 s into the run, after
the game had moved the view back to its start area. The units drew correctly the whole time,
off-screen. The `visible` counts (256/3) were genuine: those drawables were inside the pinned
frustum.

[VERIFIED] Fix: the pin duration is configurable (`ZH_STRESS_PIN_FRAMES`, benchmark `-PinFrames`).
With `-PinFrames 100000`, `artifacts/2026-11-17-t035-dense/A-0-probe/scene.png` shows the full
1,000-Crusader grid at 47 FPS, and `A-3`/`B-3` show the same scene in the dense
stencil-vs-shadow-map pairs. `stress.log` reports `alive=1000 destroyed=0 drawables=1000 hidden=0
visible=276` at frame 120 with `sample=1865.0,1155.0,13.4`.

[VERIFIED] The earlier diagnostics (modules=1, renderobj=1, radius=32.4, correct render position)
were accurate; they ruled out model/drawable/transform faults before the capture timing was
identified. No engine rendering defect exists.

[VERIFIED] Closed. T-035 used the corrected scene for three dense alternating pairs (EXP-029).

## 2026-11-17 diagnostic pass (still open)

[VERIFIED] Post-spawn logging at frame 120 now reports object and drawable state: `alive=1000 destroyed=0 drawables=1000 modules=1 renderobj=1 radius=32.4 visible=256` with `sample=2915.0,2035.0,119.1 ground=119.1 view=3068.0,2241.3,120.0`. A 3-unit run with `-SpawnAtCamera` reports `alive=3 destroyed=0 drawables=3 modules=1 renderobj=1 visible=3` with the sample 24 world units from the camera pivot. The drawables therefore exist, have a draw module and a render object with a sane radius, are flagged visible, and sit under the camera, yet no vehicle appears in `probe-3units-mod/scene.png`, `probe-badlands/scene.png`, `probe-humvee/scene.png` or `probe-noshroud/scene.png`.

[VERIFIED] Ruled out: bad placement (spawned exactly at the camera), wrong template (AmericaTankHumvee behaves identically), shroud (`ZH_STRESS_NOSHROUD=1` set `TheWritableGlobalData->m_shroudOn = FALSE`, no change), and a regression introduced by T-022/T-079 (the preserved pre-T-022 engine `ABAD3E88` shows the same empty scene with `ZH_STRESS=3` on both northamerica and Defcon6).

[UNKNOWN] Remaining candidates: the drawable is not submitted by the display draw pass despite `visible=3`; the render object is hidden by a drawable/render-object state not covered by `isVisible()`; or the W3D terrain mesh sits above the logic ground height at the sample point. Next probe should read `Drawable::m_drawableFullyObscuredByShroud`, the drawable info visibility flags and `RenderObjClass::Is_Not_Hidden_At_All()` for the sample, and count drawables actually submitted by `W3DDisplay::draw` in one frame.

[VERIFIED] New test switches (all test-only): `-Passable`, `-SpawnDelayFrames`, `-SpawnAtCamera`, `-NoShroud`, `-Diagnose`, `-Template`, `-Map`. `-Diagnose` writes the diag line above to `stress.log`.
