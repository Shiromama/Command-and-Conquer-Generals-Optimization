# ISSUE-0013: Screen-edge scrolling is disabled in the borderless profile

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-044
- **Related:** T-039, T-043; [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md)
- **Environment:** rebuilt engine `9826083E…AEEE`, borderless `-win` 1920×1080, same laptop

## Symptom

In the optimized (borderless) profile, moving the cursor to the screen border does not scroll
the camera, while right-button drag panning works. The user reported this from actual play.

## Root cause

`LookAtTranslator::canScrollAtScreenEdge()` requires the cursor to be captured **and** checks
`ScreenEdgeScrollMode`:

- `ScreenEdgeScrollMode_Default = EnabledInFullscreenApp` (`LookAtXlat.h`)
- windowed apps need `ScreenEdgeScrollEnabledInWindowedApp = yes` in `Options.ini`
  (`OptionPreferences.cpp`), otherwise `canScrollAtScreenEdge()` returns false.

Our profile runs borderless (`-win`), so edge scrolling is disabled even though the window
covers the screen. Retail 1.04 has fullscreen-only edge scrolling too; the option was added by
the community engine.

## Fix

`tools/set-screen-edge-scroll.ps1` writes both keys to `Options.ini` (windowed + fullscreen),
keeps a one-time `.edge-scroll.bak` backup, and is called by
`tools/play-shockwave-performance.ps1`. Retail 1.04 ignores the unknown keys, so the shared
user profile stays compatible.

## Resolution / verification

With the keys set, focus the game, park the cursor at the left edge for 2 s, and compare
screenshots:

```
before fix: mean pixel diff 0.01  (no pan)
after fix : mean pixel diff 40.51 (camera panned)
```

`[VERIFIED]` `artifacts/shockwave-camera-test/edge-base.png` vs `edge-left.png`;
wheel zoom also verified (zoomed base after 4 wheel notches). `launch-game.ps1` now brings the
game window to the foreground after launch, because wheel/edge input is ignored while the
game is not focused (the earlier Start-Process launch left the terminal focused).

## Notes

- The online (retail) profile in borderless mode still cannot edge-scroll: retail 1.04 only
  enables it in fullscreen. The keys are harmless there; run the retail game fullscreen if
  edge scrolling matters online.
- The key is per-user, not per-install; it applies to every Zero Hour profile using the same
  Documents folder.
