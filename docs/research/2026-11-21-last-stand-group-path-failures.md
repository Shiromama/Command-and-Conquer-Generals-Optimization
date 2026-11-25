# Last Stand group-path failures and stalled units

- Date: 2026-11-21
- Task: T-116 (opened from T-113)
- Status: the 315 stalled groups are localized to the **group start cell's
  zone** (the centre vehicle's cell), not primarily to a crowded goal; an
  opt-in start nudge is implemented; live validation pending
- Evidence: [new-mode human run](../../artifacts/2026-11-20-fresh-skirmish/human-newmode/manifest.md),
  [T-116 diagnostic build/run](../../artifacts/2026-11-21-t116-group-relax/manifest.md),
  [pathfinding algorithm note](2026-11-20-pathfinding-algorithm-limit.md),
  [maintained-width report](2026-11-19-last-stand-maintained-width.md)

## What the user observed

Many units stood still even when no building was in their way; the user
suspected that units act as obstacles, that paths could be shared, and that
dense units could be grouped instead of treated individually.

## What the run shows

[VERIFIED] The new-mode human run reached the T-107 window and logged **3,142
formation commands**:

- **2,827 returned a path; 315 (10.0%) returned no path.**
- All 315 failed commands had `moving=0`; the groups stood still.
- Failed groups were smaller: mean **4.2** members (median 4, max 12) versus
  **7.1** for successful groups (median 7, max 15).
- One failure per group; no group failed twice.
- The path workload was 999,332 requests, 1.08 billion expansions and 2,500 s
  of search; `l_ai` mean 6.976 ms, p95 32.55, max 368 ms. `l_partition` was
  only 0.255 ms; the slowest updates were spawn/production, not partition
  churn.

[VERIFIED] A group move issues **one `findGroundPath` per group**
(`AIGroup::friend_computeGroundPath`; start = group center/center vehicle, goal
= destination, `PATH_DIAMETER_IN_CELLS`). The individual units are not each
running a path search for a group move.

[VERIFIED] `findGroundPath` early rejects on:

- `clearCellForDiameter` at the goal (no width-6 clear cell within 8 cells);
- `goalCell->allocateInfo` or `parentCell->allocateInfo`;
- zone mismatch (`zone1 != zone2`);
- the fine search exhausting/failing after the hierarchical fallback.

[VERIFIED] `PathfindCell` marks units as `UNIT_PRESENT_FIXED` /
`UNIT_PRESENT_MOVING` and `blockedByAlly`. The group's own center vehicle is at
the start, and other groups can occupy the goal or route.

## Destination and start analysis

[VERIFIED] All 3,142 formation commands target only **three** destinations:
approximately `(1281, 890)`, `(1281, 982)` and `(1273, 1086)`. The 315 failed
commands use the **same three destinations** as the 2,827 successful commands.

[VERIFIED] Every one of the 315 failures has a success at the same destination
within ±2 frames. The rejection is transient and state-dependent, not a
permanently unreachable goal.

[VERIFIED] The 315 failed starts cluster at a small set of fixed positions,
led by `(2775, 1168)` (100 failures), `(2487, 489)` (73), `(2218, 210)` (41),
`(2198, 374)` (28), `(2641, 720)` (27), `(2200, 375)` (18), `(2220, 396)` (13)
and `(2945, 351)` (11). These are the AI base/spawn positions. 199 of the 315
failed groups have four or fewer members; 125 have one or two.

[INFERRED] The group path starts at the group's centre vehicle
(`center = *centerVehicle->getPosition()`). At a base spawn that vehicle can
sit in the command centre's pathfinder footprint, whose cell belongs to a
different zone from the destination. The rest of the group may be outside, but
the whole group path is rejected at the zone gate. This explains the fixed
start clusters, the smaller groups, the transient failures, and why the same
destination succeeds moments later for another group.

[VERIFIED] The saved new-mode replay cannot settle the question: it reports
`CRC Mismatch in Frame 0` even on the exact recording executable, both visual
and headless. With sync errors ignored it reaches the window but its formation
commands have zero positional matches with the live run. Its failure reasons
(1,164 failures: 1,012 `zone_mismatch`, 152 `search_failed`, zero
`goal_width`) are **indicative only**, but they also point at the start zone.
See the [diagnostic manifest](../../artifacts/2026-11-21-t116-group-relax/manifest.md).

## Live diagnostic run

[VERIFIED] The 2026-11-21 live diagnostic run (same Last Stand setup, both
relax switches off) logged **3,184 formation commands** in frames
16,978-17,249: 2,486 returned a path and **697 (21.9%) failed**. The failure
reasons were **606 `zone_mismatch`** and **91 `search_failed`**; there were
**zero `goal_width`** failures. All 697 failed groups were stationary.

[VERIFIED] Failed groups were smaller than successful ones: mean **3.22**
members (median 3) versus **6.42** (median 7). The 606 zone-mismatch groups
had 2, 3 or 5 members most often (270/101/97), and the 91 search-failed groups
all had exactly **5** members.

[VERIFIED] The 697 failures are 697 distinct group IDs, but only **13 distinct
leader objects** are involved in the 606 zone mismatches, and **one leader**
accounts for all 91 search-failed commands. The search-failed leader is at
`(2661,1770)` and every one of those commands targets `(1282,890)`. The AI is
repeatedly re-forming groups around the same stuck centre vehicles at the AI
bases.

[INFERRED] This is a leader/start-cell problem, not 697 independent units.
The fix should choose a group member on clear terrain as the leader/path start
instead of a centre vehicle inside the base building footprint. That removes
the bad start without adding a path search.

[VERIFIED] A separate trial of the earlier **spiral start nudge** was stopped:
it reached only frame 12,085 in 22 minutes (relax-off: 17,280 in 12:24), with
162.7 ms of path search in the last recorded frame. The nudge converted cheap
zone rejects into full searches and is **rejected** as too expensive.

## The three claims

| Claim | Verdict |
|---|---|
| Units stay in place even with no buildings | **Confirmed**: 315 group paths returned no path, all stationary. |
| Units act as obstacles for pathfinding | **Partially confirmed**: `PathfindCell` tracks unit occupancy and `blockedByAlly`; allied units can narrow a goal/route. But the 315 failures are better explained by the **start cell's zone** at the AI base (the centre vehicle in the command centre footprint), not by goal crowding. |
| Share paths | **Already true within a group**: one group path, units follow. The remaining sharing is **across groups** — the T-110/T-112 route cache (777 exact repeats, 5.99 ms/tick offline), blocked by the strict guard. |
| Dense units should act as groups | The engine already groups; the 3,142 commands are groups. The failed groups are smaller, but because they spawn with their centre at the base building, not because density is untreated. Merging groups is a secondary scenario lever. |

## Candidate fixes, in order

1. **Clear-cell leader selection** — the group path starts at the centre
   vehicle, which can sit inside the AI base building footprint; the AI then
   re-forms groups around that stuck leader (13 leaders accounted for the 606
   zone-mismatch retries in the live baseline). With `ZH_GROUP_START_RELAX=1`,
   choose the member closest to the goal whose cell is clear, unpinched terrain
   **in the goal cell's effective zone** as the leader/path start. This removes
   the bad start without adding a path search. Implemented; live A/B pending.
   The earlier 12-cell start nudge was **rejected**: it converted cheap zone
   rejects into full searches and slowed the headless run from 17,280 frames in
   12:24 to 12,085 frames in 22 minutes.
2. **Goal/endpoint ally relaxation** — ignore allied units when measuring the
   group goal/route and accept a narrower clear goal. This targets genuinely
   crowded goals. Implemented behind `ZH_GROUP_ENDPOINT_RELAX=1`; keep it
   separate so the two effects can be isolated.
3. **Cross-group route cache** — T-110/T-112 exact-route reuse; the 777 exact
   repeats worth 5.99 ms/tick; the native guard was too strict. A guard that
   mirrors `validMovementPosition` is the missing piece.
4. **Group aggregation/scenario** — fewer/smaller simultaneous groups; the
   failed groups are the smaller ones.
5. **Unit collision/formation following** — secondary; `l_partition` is low in
   this run, and the path failures explain the stationary groups.
6. **HPA*/clearance field** — the larger algorithmic fix; reuse the HPA*
   model and `GroupFieldShadow` repair.

## Next diagnostic

The saved replay is not a valid exact-state diagnostic (frame-0 CRC mismatch
even on the recording exe). The played diagnostic run is the baseline: 3,184
commands, **697 failures** (606 `zone_mismatch`, 91 `search_failed`, zero
`goal_width`).

The real AI-only Last Stand skirmish was tried but the AI went idle: it reached
frame 18,731, yet `commands.csv` is absent and path telemetry stops at frame
5,338. It cannot replace the human-pressure run without a pressure harness
(the user's nuke/choke idea); the test-only nuke/spawn reads are compiled out.

The current automated mechanism test uses the **diverged replay** with the
clear-leader build `CA492C95...` and `ZH_GROUP_START_RELAX=1`, compared with the
existing relax-off headless run (1,164 failures: 1,012 `zone_mismatch`, 152
`search_failed`). The clear-leader run completed in 13:40 (relax-off 12:24) with
no stall, but its `commands.csv` is absent: the diverged AI had no group
formations in the absolute window. The window path workload was 2,723 requests
/ 2.8 M us versus 7,787 / 20.7 M; the full-run path total was 691 M versus
588 M. The state diverged, so this is a mechanism/cost check, not a fix effect.

The live-arm build requires the start cell to be clear, unpinched **and in the
goal cell's effective zone**; this directly prevents the 606 zone-mismatch
retries for multi-member groups. Single-member groups whose only cell is in the
wrong zone remain unfixable without moving the unit.

Live validation (combined run, 2026-11-22): with the clear-leader fix and the
T-117 switches on, the run logged 2,670 commands. **539 groups used
`alt_leader=1` and all succeeded**; failures fell to **327/2,670 (12.2%)**, all
`zone_mismatch`, with **zero `search_failed`**. The remaining 327 are
`alt_leader=0` (single-member groups or groups with no usable member) and come
from only **7 failed leaders**. The fix mechanism works; the leftover is the
single/no-usable-member case.

The combined window was slower (interval **133 ms** vs 67 ms, `l_ai` 28 ms vs
15 ms), but it also had the T-117 combat/vision changes and a more active
battle. A T-116-only run with the T-117 switches off is needed to measure the
pathfinding cost cleanly.

A separate deploy-test with **T-116 off and T-117 on** logged 3,219 commands:
**134 zone failures (4.2%)**, but the failed groups were large (median **15**
members), and the window was slower (158 ms, path 124.7 ms/frame). The 134
large failures are exactly the multi-member case the clear leader should
rescue; combined3 (T-116 on + cached vision) is the next Last Stand run.

## Limitations

- One played human baseline; the AI-only skirmish went idle, so the automated
  clear-leader test uses the diverged replay as a mechanism/cost check.
- The new-mode replay cannot be replayed exactly; its failure reasons are
  indicative only.
- The clear-leader selection and goal relax are opt-in singleplayer
  experiments; exact replay/route parity is not claimed for either.
- The played baseline's command log ends at frame 17,249 (the 40-minute
  force-stop lost the final 28 frames); the failure rate varies with the game
  state (697/3,184 here versus 315/3,142 in the earlier run).
- The start nudge was rejected for cost; do not re-enable it without a search
  bound.
- The `group.csv` log is header-only; the `ZH_GROUP_CACHE_LOG` did not capture
  live entries.
- The old normal replay and the new-mode replay use different team setup and
  seeds; compare distributions and endpoint behavior, not exact routes.
- No 30 FPS claim.
