# Shared field with live route repair

- Date: 2026-11-19
- Task: T-112
- Baseline: [native static field](2026-11-19-last-stand-native-field.md)
- Evidence: [live field build, fixture and replay](../../artifacts/2026-11-19-last-stand-live-field/manifest.md)

## Method

[VERIFIED] The new shadow keeps the static goal field and checks its
candidate path against the live grid. When the static path exists but the
live checks reject it, a forward A* search tries to go around the blocker.
It excludes blocked centers and disallowed zones, checks the live diagonal
side cells, and caches live clearance per cell within the attempt.
It gives up after 4,096 accepted frontier expansions. The legacy solver
still handles the request and controls the replay.

[INFERRED] Stored settled distances are lower bounds on the modeled live
cost, because live occupancy and zones can only increase modeled costs or
remove edges. For an unsettled cell, the static frontier's settled horizon
and an obstacle-free geometric bound provide a conservative estimate.
The experiment covers the modeled ground graph. Zero Hour's legacy solver
also uses layer transitions and line insertions.

[VERIFIED] The compiled MSVC fixture compared the native repair kernel to
independent live-grid Dijkstra on 50 randomized maps. Costs matched for
2,101 reachable and 262 unreachable endpoint pairs. Tests used both a
partially built field and a field extended to the source. This validates
the modeled cost for these fixtures.

## Timing method

[INFERRED] Charge the whole candidate cost, including static builds,
route validation and repair attempts that need the legacy solver. Credit
only the timed reference work for candidates that also had a successful
legacy path. This counterfactual measures whether the candidate earns a
real gameplay trial. It cannot predict the trajectories of units using
different routes.

## Native result

[VERIFIED] The Win32 Release replay reached frame 17,402 with sync active
at 1920×1080 and matching graphics settings. All 15,242 original search
results and expansions matched the previous capture outside clocks. There
were 2,185 formation evaluations, with the same static decisions as the
static shadow.

| Repair outcome in the slow window | Result |
|---|---:|
| Blocked static routes eligible for repair | 1,104 |
| Repaired routes found | 1,057 |
| Searches that reached the 4,096-expansion limit | 47 |
| Mean repair work, successful and failed attempts | 2.29 ms/tick |
| Mean cost including snapshot, static field and validation | 2.62 ms/tick |

[VERIFIED] Combining direct and repaired routes, width two or better covers
1,342 successful legacy calls accounting for 21.61 ms/tick of timed group
work. The width-one tier covers 1,501 and 23.85 ms/tick. At width six,
only 132 calls and 0.19 ms/tick qualify. Successful repairs at width two
had a median geometric length 0.90 times the legacy path and a p95 of
1.06 times. Length does not prove equivalent formation movement.

| Modeled acceptance | Mean frame time | Average FPS | p95 time |
|---|---:|---:|---:|
| Width six | 72.16 ms | 13.86 | 100.87 ms |
| Width two | 50.73 ms | 19.71 | 79.86 ms |
| Width one | 48.50 ms | 20.62 | 78.00 ms |

[INFERRED] Even the width-one model needs another **15.17 ms/frame** to
reach 30 FPS at the exact-memo reference's measured non-search load. The
entire nonformation search budget in that reference is only 14.59 ms/tick.
The native unit experiment can contribute to the target, but the model
also requires wider savings, such as reducing repeated group orders,
improving repair coverage/cost, or reducing other CPU work. An aggressively
smaller repair cap would also lose expensive covered requests. Of 19.65
ms/tick covered by successful repairs, only 3.73 ms/tick completed within
1,024 expansions. This is a cutoff analysis, with no measured timing at
the smaller cap.

[INFERRED] The next decisive questions are whether the repeated formation
commands can be coalesced without changing order handling, and whether
the live route candidate preserves acceptable formation movement in a
fresh skirmish. These timing estimates come from shadow work and earlier
legacy clocks. No current build was observed playing this window at the
modeled FPS.
