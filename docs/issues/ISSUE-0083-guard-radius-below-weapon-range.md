# ISSUE-0083: Guard radius can truncate usable weapon range

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-081

## Evidence

[VERIFIED] User reports stock guard rings/engagement stopping short, particularly long-range units. AIGuardMachine::getStdGuardRange returns adjusted vision only; InGameUI uses it for the ring and lookForInnerTarget uses it as the target search limit. Weapon::getAttackRange includes current bonuses separately. This establishes a mechanism for guard radii below weapon range; unit coverage/runtime reproduction remain pending.

## Resolution / verification

Audit stock guard-capable units; raise only insufficient player-controlled singleplayer guard radii to cover eligible automatic weapons. Keep a single shared calculation for ring and search. This is a built-in fix, without a user toggle. Preserve target visibility/type checks and unaffected units.

[VERIFIED] Initial scratch patch check used the wrong working directory and found no target paths; no files changed. Retried with absolute git/work-tree paths and cwd bound to the isolated alpha source; check and apply both exit 0. Active vendor source remains untouched.

[VERIFIED] Native alternating control/fixed evidence at 1920x1080 borderless, same map/slots/positions. Control-4 (legacy `getStdGuardRange`, engine `90C208FA...6574`) reports Tomahawk guard/legacy 324, weapon range 347.5, target distance 335.75, `can_attack=3`, `within_weapon_range=1`, but no shot for 12 samples. Scud and Nuke launchers behave the same. Fixed-1 (engine `1CEFD1F4...B766`) reports guard 347.5/legacy 324 and fires at frames 486, 843 and 1260; target health falls 800 -> 650/500/400. Crusader remains 270/270 at distance 100 and fires in both runs. See [`EXP-030`](../experiments/EXP-030-guard-range-runtime.md) and `artifacts/2026-11-18-guard-range/{control-4,fixed-1}`. The production engine `4FD3B817...2F42` contains the same guard source hash `2ADC9D18...80C9` as fixed-1; 67 compiled actual-source cases pass against the production tree.
