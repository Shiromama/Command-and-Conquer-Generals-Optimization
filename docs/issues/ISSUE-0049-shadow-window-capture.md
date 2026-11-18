# ISSUE-0049: First visible renderer capture failed before the timed run ended

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** Windows computer-use, 30-second visible probe

## Symptom / evidence

[VERIFIED] sky.list_windows returned engine-test window 8458420. get_window_state then failed with foreground window did not report a process id. Refresh found no engine window after the timed run ended; no screenshot was inspected.

## Impact

Visual acceptance remains unverified. The visible run completed and restored options and the wrapper slot.

## Root cause

[UNKNOWN] Capture/foreground timing. A longer announced run with explicit activation is needed.

## Workaround

Refresh selection, activate the unique returned game window, then capture during a longer visual run.

## Resolution / verification

Pending successful screenshot inspection.

[VERIFIED] Explicit activation during the 90-second run succeeded. Captured wrapper-visible-clean/scene.png and scene-camera-change.png and stencil-visible-clean/scene.png; state returned the correct engine-test window.
