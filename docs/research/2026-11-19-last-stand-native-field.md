# Native shadow test of a shared formation route field

- Date: 2026-11-19
- Task: T-112
- Baseline: [alternate techniques and native overlap](2026-11-19-last-stand-alternate-search.md)
- Evidence: [isolated build and replay manifest](../../artifacts/2026-11-19-last-stand-shadow-field/manifest.md)

## Native comparison

[VERIFIED] The diagnostic takes the actual ground start and snapped goal from
`findGroundPath` after the initial checks. It builds a compact static ground
snapshot for the observed topology revision. Walkable centers are clear and
unpinched. Width classes reproduce the interior static footprint shape up to
six cells. The legacy result remains authoritative.

[VERIFIED] A lazy reverse Dijkstra frontier is shared across starts with the
same snapped goal. The cache holds at most eight frontiers, and rebuilding
the static snapshot clears them. The simplified field uses orthogonal and
diagonal step costs and a static penalty for narrow cells. It omits layer
links, legacy line insertions and transient occupancy during construction.

[VERIFIED] After the original solver finishes, the diagnostic checks its
candidate's center occupancy, clearance width and zone acceptance along the
full route. It records static snapshot, frontier and validation times
separately. A change to the observed topology or fixed-occupancy stamps
during the original solver skips the shadow query. This is a diagnostic
scope, and these stamps have no production invalidation guarantee.

[INFERRED] The relaxed width checks describe candidates for further
experiments. They do not prove identical movement or validate every layer
or diagonal rule in the legacy engine. A candidate would need a live route
check and dedicated parity or fresh-skirmish tests before replacing results.

## Result

[VERIFIED] The Win32 Release diagnostic reached frame 17,402 at 1920×1080
with sync active. Its 15,242 path records matched the inner-loop reference
and earlier exact-memo run after excluding elapsed times. All 2,185
expected group records were present.

| Native shadow outcome | Group calls |
|---|---:|
| Candidate reached the goal on the static field | 1,633 |
| No eligible start/goal was recorded after initial legacy checks | 448 |
| Start or goal outside the modeled static graph | 104 |
| Static candidate crossed a live blocked center | 1,104 |
| Candidate passed the recorded live checks at width six | 116 |
| Candidate passed the recorded live checks at width two or more | 392 |
| Candidate passed the recorded live checks at width one or more | 529 |

[VERIFIED] The field settled 323,601 nodes across six static rebuilds.
The full candidate cost averaged **0.33 ms/tick**, including snapshot,
frontier and validation time. Four cache slots would have allocated the
same 14 goal fields as the eight tested, based on replaying the observed
access order. Each raw target mapped to one snapped cell in observed
queries that reached the field. The raw (128, 89) target snapped to
(130, 89). Blocked-center rejections account for **67.6%** of
static candidates. There were no zone rejections among those candidates.

[VERIFIED] The 116 full-width candidates cover only 0.075 ms/tick of
successful legacy group work in the earlier timed reference. The
width-two tier covers 2.58 ms/tick and the width-one tier covers 4.20 ms/tick
after excluding legacy failures. The latter includes narrow and
behavior-changing routes, and four more candidates for legacy failures.

[INFERRED] Using the earlier exact-memo frame budget and charging all probe
cost, the strict-width replacement model moves **14.34 to 14.29 FPS**.
The width-two and width-one models yield 14.82 and 15.18 FPS. These
subtractions combine diagnostic and baseline clocks and omit the cost of
building or executing a new engine Path. They show that this fixed route
field is a poor fit by itself. The patch remains diagnostic.

[INFERRED] Test bounded A* over the same ground graph with live occupancy
and the static field as a cost-to-go estimate. Use the settled static cost
for visited nodes, with a conservative lower bound for unsettled nodes.
This is a valid bound for that prototype graph if live constraints only
remove edges or add cost. It does not establish a bound for the full
legacy solver. Keep a deterministic work limit, validate each resulting
route, and count fallback cost. Record where and how long static routes
remain blocked so whole-route repair can be compared with short detours.
Judge the next candidate by the share of legacy milliseconds covered and
its net cost, as well as route geometry.

## Other unit searches

[VERIFIED] Reanalyzing the 2,975,393 distinct cell visits per unit search
from the previous native capture showed **70.7%** recent coordinate reuse
within five ticks when grouping by topology stamp, surfaces, crusher flag
and ignored obstacle. It drops to **13.8%** on adding the destination and
**6.4%** on adding the unit ID in separate comparisons.

[INFERRED] This favors a compact common terrain classification for per-unit
work over building a destination field for every unit goal. The logged
properties do not cover radius, center, relationship, crushability or
unit occupancy. Preserve those live checks. In the source,
`Pathfinder::checkForMovement` scans the footprint and consults object IDs
and relationships when cells are occupied, while
`Pathfinder::validMovementPosition` handles the terrain surface separately.
Test a cheaper ground footprint path in a controlled replay.

[VERIFIED] Prepared a second diagnostic candidate that skips leading empty
ground cells in the footprint, then resumes the original occupied-cell checks
at the first nonempty cell. The ground shortcut is guarded by the full
footprint being within map bounds. The MSVC fixture extracted both function
bodies and compared return values and all four movement outputs on **250,000**
cases. Of these, 125,432 sampled ground and 33,257 were eligible for the direct
branch. The fixture included layered cells, edges, allies, enemies, ignored
units and occupied goals. Native performance is still unmeasured.
