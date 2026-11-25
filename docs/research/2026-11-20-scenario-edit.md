# Scenario-edit branch: Last Stand map copy

- Date: 2026-11-20
- Task: T-113
- Status: map copy staged; edits pending in WorldBuilder
- Evidence: [map copy manifest](../../artifacts/2026-11-20-scenario-edit/manifest.md),
  [stock-vs-mod design](2026-11-20-stock-vs-mod-design.md),
  [algorithm note](2026-11-20-pathfinding-algorithm-limit.md)

## Why this branch

[VERIFIED] The slow window is 70.5% path searches. The scenario issues 2,185
formation orders in 300 ticks, all traced to the GLA approach instruction, on
a 350x200 map where the p95 search bounding box covers 40.5% of the map. A
design change that reduces simultaneous group orders or widens the worst
lanes targets the same workload without an engine change.

## What is ready

[VERIFIED] A disposable copy of the Last Stand user map exists at
`Documents\...\Maps\Last Stand Test`, with the original `.map`, `.tga` and
`Map.str`; `Skirmish.ini` already selects the Last Stand 8-player, 50k-cash
setup. `WorldBuilder.exe` is available in the reference install.

## What is not done

The actual geometry/script edits. They require WorldBuilder:

1. Open the `Last Stand Test\Last Stand Test.map` copy.
2. Find the GLA approach instruction in the map's script (the T-113
   `analyze-origins.py` trace names it as the source of every formation call).
3. Apply one change: stagger the wave starts, reduce the simultaneous group
   count, or widen one or two chokepoints.
4. Save the copy, point `Skirmish.ini` at it, start the 8-player skirmish with
   the UI benchmark, and compare the 10-minute window with the original-map
   baseline.

## Acceptance

Use the fresh-skirmish protocol, not the replay exact-route gate:

- frame time, logic time and path-search time;
- time to first movement and completed orders;
- stuck units and congestion;
- fight intensity at the same unit count and wave timing;
- the same map size, players, cash and templates.

A scenario edit is a **mod-design fix**, not an engine optimization. If it
wins, record it as a map/script change with its own manifest; do not present it
as an engine speedup.

No game run was made for the edited map.
