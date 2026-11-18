# ISSUE-0085: Initial guard fixture creates AI/neutral-owned subjects

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-081

## Evidence

[VERIFIED] First control fixture logs mood=1058, which has MM_Controller_AI (0x2), not MM_Controller_Player (0x1). It uses the campaign-map fallback local player rather than an explicit human slot. Even the Crusader control does not fire; these results cannot validate player guard behavior. Raw rows are retained in artifacts/2026-11-18-guard-range/control/guard.csv. Native 1920x1080 borderless launch completed; the test runner restores/verifies the managed executable after exit.

## Resolution / verification

Explicitly select a non-neutral map player, set its controller to human and bind it as the local player before spawning subjects. Keep the neutral target on a distinct player; log relationship and controller and require the unaffected Crusader to fire in both control/fixed runs. Repeat with fresh evidence directories. No shipping feature toggle will be added.

[VERIFIED] The fixture now starts an ordinary skirmish with slot 0 human and slot 1 easy AI, selects the non-neutral AI opponent, logs `setup,60,human=2/0,enemy=1/1,relationship=0`, and spawns the probe on the AI player's default team. Control-4 and fixed-1 both complete all four subjects through frame 1500, with the Crusader firing and target health falling. The remaining crash was a separate stock weapon-FX defect (ISSUE-0086/ISSUE-0087), not the controller selection. Evidence: `artifacts/2026-11-18-guard-range/{control-4,fixed-1}/guard.csv`.
