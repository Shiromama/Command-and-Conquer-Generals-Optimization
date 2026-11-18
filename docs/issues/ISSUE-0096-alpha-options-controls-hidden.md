# ISSUE-0096: The packaged ShockWave layout hides AA and Unlock FPS

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-077

## Evidence

[VERIFIED] Reading `Window/Menus/OptionsMenu.wnd` from the installed `!Shw_wnd.big` and `WindowZH.big` found `HIDDEN` on `ComboBoxAntiAliasing` and `CheckUnlockFPS`. The shipped C++ registers tooltips for both. Selecting `Custom` in the Detail dropdown opens the advanced display panel, where the layouts expose particle cap, heat effects, and cloud shadows.

## Resolution / verification

[VERIFIED] The prepared engine reads `AntiAliasing` and `FPSLimit` from `Options.ini`. See [Optimization settings](../optimizations.md#settings) for access. The layout was inspected in place and remains unchanged.
