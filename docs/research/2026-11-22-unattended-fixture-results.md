# Unattended deploy fixture and path-cache validation

- Date: 2026-11-22
- Task: T-120 (runner and deploy fixture), T-117 (guard hold), T-118 (occupant cache)
- Status: T-120 complete; T-117 hold and guard-state fixes verified in a focused fixture;
  T-118 cache correctness verified, no timing gain; Last Stand integration pending
- Runbook: [debugging.md](../debugging.md) and [ADR-0026](../decisions/ADR-0026-unattended-engine-debugging.md)
- Evidence: [artifact manifest](../../artifacts/2026-11-22-t120-deploy-fixture/manifest.md)

## Implementation

| Piece | Path | Purpose |
|---|---|---|
| Engine fixture | `tools/deploy-fixture.inc` | Dev-only scripted skirmish with a real human slot, a China Nuke Cannon deploy/shot/move case, and a `path_bench` case with stationary neutral blockers. |
| Injection | `tools/prepare-deploy-fixture.py` | Restores the shipping source, then injects only the fixture into `build/last-stand-profile-source`. The T-118 switch/oracle is permanent in `PathfindCell.cpp`; the shipping `GameLogic.cpp` copy is kept under the artifact folder. |
| Runner | `tools/run-deploy-fixture.ps1` | Stages one engine into `game/last-stand-replay`, sets an explicit child environment, enforces startup/progress/total deadlines, restores the executable and `Skirmish.ini`, and writes `run.json`. |
| Summary | `tools/summarize-path-fixture.py` | Summarizes `ZH_PF_FRAME` requests, time and expansions for cache A/B runs. |

The deploy case requires a real `PLAYER_HUMAN` slot, a computer opponent, the subject
template's `DeployStyleAIUpdate` module, a visible hostile target, a deploy transition and at
least one shot. It then issues a player move during guard, Stop, and a second move.
`ZH_DEPLOY_GUARD_HOLD=1` is the candidate; control and candidate use the same executable and
input sequence. `ZH_DEPLOYED_AVOID` and `ZH_LONG_RANGE_VISION` stay off for isolation.

## T-120 runner result

| Case | Engine SHA-256 | Result | Time |
|---|---|---|---|
| Wrong template (Crusader) | `452366B8...` | `invalid_fixture` at frame 60, `template lacks DeployStyleAIUpdate` | **7.9 s** |
| Covered control | `1EB00B96...` | `pass`, deploy + shot + guard move + post-Stop move | 13.6 s |
| Covered candidate | `1EB00B96...` | `pass`, deploy + shot + held guard move + post-Stop move | 13.7 s |

The wrong-template run proves the coverage gate fails fast instead of waiting through a long
match. The runner restored the game executable and `Skirmish.ini` on every run; the restored
hash matched in `run.json`.

## T-117 findings and fixes

The fixture exposed two defects in the existing hold implementation:

1. `DeployStyleAIUpdate::aiDoCommand` tested guard sub-state IDs `AI_GUARD_INNER` (5000) to
   `AI_GUARD_ATTACK_AGGRESSOR` (5005). `getCurrentStateID()` returns the top-level state
   `AI_GUARD` (16), so the range never matched and the hold was inert. Fixed to
   `state == AI_GUARD || state == AI_GUARD_TUNNEL_NETWORK`.
2. The command filter stopped new move orders, but the guard machine could still install an
   internal path; `DeployStyleAIUpdate::update()` then undeployed the unit on
   `isWaitingForPath() || getPath()`. The update now cancels that path and keeps the unit in
   `DEPLOY`/`READY_TO_ATTACK` while the hold is active in guard.

Matched final pair (same executable `1EB00B96...`):

| Run | Shot frame | Moved in guard | Unpacked in guard | Moved after Stop | Verdict |
|---|---:|---|---|---|---|
| Control (`ZH_DEPLOY_GUARD_HOLD=0`) | 175 | yes, 105.4 units | yes | yes | **pass** |
| Candidate (`ZH_DEPLOY_GUARD_HOLD=1`) | 174 | **no, 0.0** | **no** | yes, 38.9 units | **pass** |

The candidate stayed deployed and stationary during the guard move, then packed and moved after
Stop. This verifies the hold and the Stop escape hatch.

The remaining two T-117 switches were then tested directly:

| Probe | Off | On | Verdict |
|---|---|---|---|
| Long-range vision (Nuke, weapon 447.5) | vision **180**, shroud clearing **350** | vision **447.5**, shroud clearing **447.5** | **both pass** |
| Deployed avoidance (Redguard, fixed goal cell, 2-wide query) | width **2** | width **1** | **both pass** |

The avoidance probe forces a fixed goal occupancy because the width scan only consults
`UNIT_PRESENT_FIXED` cells. With the switch off the two-cell footprint is clear; with it on the
deployed occupant rejects the wide footprint and only the one-cell fallback remains.

A combined-switch Last Stand formation run (`ZH_GROUP_START_RELAX=1`,
`ZH_LONG_RANGE_VISION=1`, `ZH_DEPLOYED_AVOID=1`) passed on the same probe executable. This is a
scripted switch-integration check, not a played match; the playtest remains the full
verification.

## T-116 focused formation result

The formation case starts the Last Stand map, places a command-center footprint at the recorded
leader `(2775,1168)` and orders a six-unit group to `(1281,890)`.

| Run | Leader usable | Alternate usable | Last path failure | Moved | Verdict |
|---|---|---|---|---|---|
| Control (`ZH_GROUP_START_RELAX=0`) | false | true | **`zone_mismatch`** | yes (fallback members) | **pass** |
| Candidate (`ZH_GROUP_START_RELAX=1`) | false | true | **`none`** | yes | **pass** |

Both runs used `DB1F5689...` and six units. The control reproduces the group-start rejection
reason, and the candidate selects a usable alternate start and dispatches a route. Some control
members still take fallback individual routes, so this does not reproduce the live "all
stationary" symptom; the played Last Stand isolation remains the next T-116 check.

## T-118 cache results

The cache comparator is `getPosObject()` with `ZH_PF_OCCUPANT_CACHE=0` falling back to
`findObjectByID`, `ZH_PF_CACHE_ORACLE=1` comparing cached and fresh pointers, and
`ZH_PF_CACHE_SELFTEST=1` injecting 16 empty cache results. The fixture queries 100 stationary
neutral blockers' pathfinder cells directly.

| Run | Mismatches | Cell queries / exact hits | Verdict |
|---|---:|---|---|
| Self-test (`SELFTEST=1`) | **16** | 100 / 84 | Oracle catches the injected empty entries |
| Clean oracle | **0** | 100 / 100 | Cache pointer matches the fresh lookup at every query |

Final path-bench timing (same executable, 8 groups x 25 movers + 100 stationary blockers):

| Cache | Requests | Expansions | Path time | Mean | p95 |
|---|---:|---:|---:|---:|---:|
| On | 2,672 | 1,545,396 | 2.912 s | 4,148 us | 17,419 us |
| Off | 2,707 | 1,546,477 | 2.880 s | 3,939 us | 17,099 us |

The cache is correct at every queried cell but is **1.1% slower** on this workload, within a
small run spread but with no measured gain. The width scan is dominated by the maintained
formation-width path, which resolves occupants through `findObjectByID` directly, so this bench
does not represent a fixed-goal-heavy Last Stand window. Keep the cache behind its switch and
do not claim a speedup; a fixed-goal-heavy replay/window or a direct width-scan microbenchmark is
required before enabling it by default.

## Playtest build

The clean playtest engine `build/engines/t120-playtest.exe`
(`0D3A2819...`) is staged in `game/last-stand-replay/Generals.exe`; the retail backup
`Generals.exe.original` remains `76099735...`. `tools/play-t120.ps1` launches it at 1920x1080
with `ZH_DEPLOY_GUARD_HOLD=1`, `ZH_GROUP_START_RELAX=1`, `ZH_PF_OCCUPANT_CACHE=0`,
`ZH_DEPLOYED_AVOID=1` and `ZH_LONG_RANGE_VISION=1`; `-Restore` puts the retail exe back. The
clean binary contains no fixture strings (`ZH_FIXTURE_RESULT`/`ZH_FIXTURE_CASE` absent) and
contains the T-117/T-116/T-118 switches. `tools/play-t120.ps1 -DryRun` prints the exact command
and exits 0.

## Build note

The existing CMake cache pointed at the BuildTools instance, whose MSVC 14.42 toolset has no
ATL. The tree was reconfigured against the Community instance (MSVC 14.43, ATL present) with the
same profile-off/LTCG-on options. The dev engine is `build/engines/t120-deploy-fixture.exe`
(`1EB00B96...` for the final fixture/cache-probe build). The guard-hold changes are preserved in
[`engine/patches/T-117-deploy-guard-hold.patch`](../../engine/patches/T-117-deploy-guard-hold.patch);
`git -C vendor/GeneralsGameCode apply --check --ignore-space-change` passed against the clean
vendor index. The dev fixture is injected only for test builds and was restored from the source
tree after the runs; the cache switch/oracle remains in the shipping `PathfindCell.cpp`.

## Limitations

- One map (`barrenbadlands` for deploy, `northamerica` for path bench), one seed, one unit type.
- The guard case uses a direct player move during guard, not the Last Stand AI chase.
- The path bench does not exercise the fixed-occupant width scan; the direct cell-query gate
  covers the cache pointer and oracle, not the full width decision.
- The T-116 fixture reproduces the `zone_mismatch` group-start rejection, but fallback individual
  routes still move some control members; the live played isolation remains open.
- The dev fixture is injected only into `build/last-stand-profile-source`; it is not packaged.
  The cache switch/oracle is permanent source but has no tracked cumulative patch yet. The clean
  playtest engine is `build/engines/t120-playtest.exe` (hash in the artifact manifest).
