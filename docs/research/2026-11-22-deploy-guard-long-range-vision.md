# Deploy guard hold, deployed avoidance, and long-range vision

- Date: 2026-11-22
- Task: T-117 (follows T-116)
- Status: implemented behind opt-in switches; combined C024 run completed; the
  guard hold was broadened after it still moved (build F0FB...); cached-vision
  build combined3 (`7D75AF57...`) built. The focused T-120 fixture found and fixed
  two guard-hold defects: the top-level guard-state test and path-driven
  undeploy. Hold now passes a controlled Nuke Cannon case; Last Stand
  integration and the avoidance/vision cases remain pending.
- Related: [Minecraft optimization mapping](2026-11-22-minecraft-optimization-inspirations.md)
- Evidence: [T-116 diagnostic manifest](../../artifacts/2026-11-21-t116-group-relax/manifest.md)

## What the user asked for

Deploy-to-fire units such as the Nuke Cannon pack up and chase whenever a target
shifts, so they repeatedly redo their setup and sometimes never fire. The user
also wanted allied units to route around a deployed unit instead of pushing it,
and long-range units to see as far as they can shoot.

## Switches

All three are opt-in and generic; none is hard-coded to the Nuke Cannon.

| Switch | Scope | Behaviour |
|---|---|---|
| `ZH_DEPLOY_GUARD_HOLD=1` | every `DeployStyleAIUpdate` unit | while the top-level AI state is any guard state, ignore **all** move commands (the guard chase uses the player's last command source, so source filtering was not enough). Press **Stop/unguard** to move deliberately. |
| `ZH_DEPLOYED_AVOID=1` | every unit with `OBJECT_STATUS_DEPLOYED` | `clearCellForDiameter` treats the deployed unit as a hard width obstacle, so allied paths route around it. This is a path-width change, not a physics/collision change. |
| `ZH_LONG_RANGE_VISION=1` | every long-range unit | `Object::applyLongRangeVision` caches the effective vision at object creation and on weapon-set changes: vision and shroud clearing are raised to the longest weapon range when it is >5% above the current vision. `getVisionRange` then returns the cached value instead of scanning weapons on every fog/team/AI/partition call. `AIGuardMachine::getStdGuardRange` returns the longest automatic weapon range for player units, so the guard radius equals the firing range. |

## Why these are separate from T-116

T-116 only changes which member is used as the group path start. The T-117
changes alter combat/vision behaviour, so the combined run's pathfinding failure
counts are mixed; the `commands.csv` `reason`/`alt_leader` columns still show
the T-116 mechanism.

## Validation

Combined build `C024B41021F7B76674AC4FB69456EC30FF1D876ED7E7749BC9B6B5C731CED0D5`
ran with all switches on. The T-116 `commands.csv` showed **539
`alt_leader=1` successes**, **327 remaining `zone_mismatch` failures** (7
leaders, all `alt_leader=0`) and **zero `search_failed`**. The combined window
was slower (interval 133 ms vs 67 ms, `l_ai` 28 ms vs 15 ms), but this is mixed
with the new combat/vision behaviour and the more active battle.

The first guard-hold implementation did **not** stop the Nuke Cannon: the guard
chase uses the player's last command source, and it can start while the unit is
still packing/unpacking. Build `F0FB03A9...` (combined2) broadens the rule to
ignore all move commands in any guard state and adds `ZH_DEPLOY_DEBUG_LOG`.

The focused deploy test ran the Last Stand for 30 minutes, but **no
deploy-style command was logged**: the human was TT, so no Nuke Cannon was
built. At that point the hold was still unvalidated; a **China** skirmish with a Nuke Cannon was
required (the T-120 fixture below now covers it). The same run (T-116 off, T-117 on) logged 3,219 commands: **134 zone
failures (4.2%)**, but the failed groups are now large (median 15 members), and
the window was slower: interval 158 ms, `l_ai` 22.2 ms, path 124.7 ms/frame,
expansions 45.5k/frame. The T-116 clear leader was off; combined3 (T-116 on +
cached vision) is the next Last Stand test.

[VERIFIED] The T-120 focused fixture then reproduced the hold failure with a real China Nuke
Cannon and found two implementation defects: the command filter compared
`getCurrentStateID()` against the guard machine's inner IDs (5000-5005), but the top-level
state is `AI_GUARD` (16); and `update()` still undeployed on an internal guard path. Both are
fixed in `DeployStyleAIUpdate.cpp`. On the matched final pair (same executable `1EB00B96...`),
the control packed and moved 105.4 units during guard, while the candidate stayed deployed and
stationary (0.0) and moved 38.9 units only after Stop. Both runs had a shot at frame 174/175.
The single-unit deploy log stayed empty because the existing logger is fully buffered and the
runner kills the process; the per-frame diagnostic CSV is the retained evidence. The Last Stand
integration with combined3 and the deployed-avoidance/long-range-vision cases remain pending.

[VERIFIED] The focused probes then covered the other two switches. Without `ZH_LONG_RANGE_VISION`
the Nuke reports vision 180 and shroud clearing 350; with it, both are **447.5** (the weapon
range). Without `ZH_DEPLOYED_AVOID` a fixed deployed Redguard cell has width **2**; with it the
2-wide footprint is rejected and the width falls to **1**. A combined-switch Last Stand formation
run (start relax + long-range vision + deployed avoidance) passed on `2A9F5DC4...`. The played
Last Stand check remains the final integration evidence.

Expected visible effects:

- deployed Nuke Cannon/Tomahawk/Scud-style units stay deployed while guarding
  and fire from position instead of packing up to chase;
- allied groups route around a deployed unit instead of squeezing past it;
- long-range units reveal the map out to their firing range, and their guard
  radius matches it.

## Limitations

- The guard hold ignores every move command while the top-level AI state is a
  guard state, cancels a guard-installed path and keeps the unit deployed; a
  player move now requires Stop/unguard first. This is the intended lock, not a
  general move filter.
- The focused fixture covers one Nuke Cannon on one map and a direct player move
  during guard, not the Last Stand AI chase or every deploy-style unit. The
  `ZH_DEPLOY_DEBUG_LOG` is fully buffered, so a killed process can leave it empty;
  the fixture's per-frame diagnostic CSV is the reliable evidence.
- Deployed avoidance is a path width/cost change; the collision system is not
  changed, so a unit already overlapping the deployed object may still be
  resolved by the existing physics.
- The vision cache is refreshed at object creation, `setVisionRange` and
  weapon-set changes; a range bonus applied directly to `m_visionRange` without
  `setVisionRange` would not refresh it.
- The vision rule applies to AI units too, so enemy long-range units also see
  farther. It is opt-in and can be turned off.
- No replay/network compatibility claim.
