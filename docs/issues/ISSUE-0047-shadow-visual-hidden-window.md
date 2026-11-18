# ISSUE-0047: Visual probe hid the game window

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** benchmark-shadow-map.ps1, Windows computer-use

## Symptom / evidence

[VERIFIED] wrapper-visual produces renderer frame rows, but sky.list_windows returns no Generals window. The runner used Start-Process -WindowStyle Hidden, so this run is not a visual inspection.

## Impact

Cannot inspect image correctness from this run. Timing remains exploratory under concurrent PC load.

## Root cause

[VERIFIED] Used the hidden helper-process launch style for a visual game check.

## Workaround

Add an explicit Visible switch and use it only for an announced visual check.

## Resolution / verification

Pending visible-window inspection. User now requires a heads-up before every game launch; no clean performance run until background workload is coordinated.

[VERIFIED] wrapper-visible-clean/scene.png and scene-camera-change.png were captured from the unique visible engine-test window. The Visible switch fixes the runner style; the original 60-second hidden run is not visual evidence.
