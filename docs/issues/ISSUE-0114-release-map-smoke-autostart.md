# ISSUE-0114: Release smoke started at the menu with the map argument

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-111

[VERIFIED] The first release smoke used `-map maps\northamerica\northamerica.map` with
`-quickstart`. The candidate reached the ShockWave main menu. The command did not
open that map directly in this launch.

## Resolution / verification

[VERIFIED] Used the same test process to open Solo Play, USA Mini-Game, Easy. The candidate
rendered the mission briefing, terrain and effects, and showed the mission clock advancing.
The supplied map argument is unnecessary for this smoke workflow. Direct map autostart was
outside the group clearance task.
