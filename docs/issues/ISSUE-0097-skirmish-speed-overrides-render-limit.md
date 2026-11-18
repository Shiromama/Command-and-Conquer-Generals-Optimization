# ISSUE-0097: Starting skirmish forces the speed slider value into the renderer

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-089

## Evidence

[VERIFIED] The prior skirmish setup passes the slider position as the fourth argument of `MSG_NEW_GAME`. `GameLogic::onNewGame` used that argument to set the render target and force the render limiter on. The highest slider position sent 1,000, the engine's uncapped sentinel.

## Resolution / verification

[VERIFIED] Candidate 14 routes the slider to the simulation scheduler for local matches launched through that screen. The slider selects 15–60 logic ticks per second. Skirmish setup preserves the user's render preference when clearing the shell. `python tools/test-skirmish-speed.py --source build/t089-alpha-source --output artifacts/2026-11-18-skirmish-speed/compiled` passed 24 cases with capped and uncapped rendering, independent simulation targets and replay/network boundary checks.
