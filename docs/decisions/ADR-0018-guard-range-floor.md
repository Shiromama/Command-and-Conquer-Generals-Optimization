# ADR-0018: Singleplayer human guard floor covers usable weapon range

- **Status:** Accepted
- **Date:** 2026-11-18
- **Task:** T-081

## Context

[VERIFIED] `AIGuardMachine::getStdGuardRange` returned only the adjusted vision range (`AI_VISIONFACTOR_OWNERTYPE | AI_VISIONFACTOR_MOOD | AI_VISIONFACTOR_GUARDINNER`). Both the guard target scan and the guard-radius UI decal use that value, while `Weapon::getAttackRange` includes separate current bonuses. Stock long-range units can therefore have a guard ring and acquisition radius below their usable weapon range. The user requested a built-in stock-unit fix with no toggle, prioritizing long-range units.

## Decision

For a player-controlled human unit in a singleplayer game, compute the guard range as `max(adjusted legacy vision, largest eligible automatic weapon range)`. Eligibility follows the same command-source, ammo, weapon-lock, damage and anti-mask rules the guard target scan can use, so helper/manual-only weapons do not inflate the radius. Preserve the legacy result for AI units, network games, replays, shell/inactive states and enter-guard templates. Use the same resolver for the guard machine and the UI radius preview so the ring and search limit cannot diverge.

Do not add a user toggle. Apply the change as a separate tracked alpha feature patch, not by modifying the active vendor tree.

## Consequences

### Positive

- Human singleplayer guard rings and acquisition cover the weapon range the unit can actually use.
- Network/replay behavior and AI difficulty remain on the legacy path.
- A single shared calculation removes a ring/search mismatch class.

### Negative / risks

- The engine-level gate cannot certify every mod/unit combination; this alpha's catalog remains the local stock and ShockWave snapshots.
- The fix intentionally raises the radius for stock long-range variants only where eligible weapon range exceeds legacy vision.
- UI ring resizing is statically tested; a final visual screenshot of the decal is not part of this record.

### Follow-ups

- Optional runtime visual check of the guard decal.
- Broader stock upgrade/variant coverage if the alpha scope expands.
- Keep multiplayer and replay compatibility uncertified and disabled from the change.

## Verification

[VERIFIED] Native alternating control/fixed runs at 1920x1080: the legacy build did not fire at 335.75 with legacy radius 324; the fixed build reported 347.5 and fired with all three audited long-range units. 67 compiled actual-source guard/mode/weapon/decal cases pass against the production source. See [`EXP-030`](../experiments/EXP-030-guard-range-runtime.md), ISSUE-0083 and `artifacts/2026-11-18-guard-range/`.
