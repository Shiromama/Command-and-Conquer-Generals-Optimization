# How large-unit-count RTS games keep pathfinding affordable

Research note, 2026-11-25. Question: games with hundreds to thousands of units stay smooth while
Generals' 1,000-unit window does not. What do they do differently, and which parts are applicable?

## What this engine does (measured this session)

- ~**20 path requests per frame**, 0% exact repeats, ~700 us each, **14.7 ms/frame** total (40% of a
  36.8 ms frame). Occasional single searches cost ~50 ms.
- The search prices **dynamic units into the route cost**: `3*COST_DIAGONAL` per fixed ally,
  `allyMoving` penalties near the start, `100*COST_ORTHOGONAL` for impassable/obstacle cells
  (`AIPathfind.cpp:3581-3642`).
- Route caching exists but must expire at **20 frames** because unit costs change; extending it to 24
  diverged the replay and was slower. Search caps produce a retry storm (45 ms).
- Group/formation paths exist (width-6 kernel) and are cheap: 983 group requests in the heavy window
  collapse to **3 destinations and 55 (start, goal) pairs**.

## The five techniques the field converges on

1. **Path once per group, not per unit.** Company of Heroes paths the *squad leader* and predicts
   member positions along that path (AI Game Programming Wisdom 4, "Company of Heroes Squad
   Formations"); openage's AoE formation notes state grouped units take the same path; the AoE2
   pathfinding talk (Meeting C++ 2025) notes overlap is allowed *inside* a formation.
2. **Flow fields per destination.** Supreme Commander 2 and Planetary Annihilation generate one
   vector field per destination and let every unit sample it; a 50x50 field generates in ~0.3 ms,
   with the field computed only along a coarse/hierarchical path
   (howtorts.github.io flow fields; jdxdev.com "RTS Pathfinding 1 - Flowfields").
3. **Hierarchical/region pathing with caching.** Plan on a coarse region graph, then refine locally;
   cache aggressively because the coarse graph changes rarely.
4. **Separate navigation from avoidance.** Modern RTS path around **static** terrain only; units are
   handled by local steering/pushing, not by re-running A*. Multiple gamedev sources state the same
   rule: same-team units should not be pathfinding obstacles for each other, only avoidance
   concerns.
5. **Time-sliced, budgeted requests and deterministic job systems.** Requests enter a queue and are
   solved within a per-frame budget, applied later; large-scale RTS engines use fixed-partition job
   systems so the simulation stays deterministic.

## Why our earlier attempts failed, in this light

The engine violates technique 4: it **bakes living units into the A* cost**. Consequences we measured:

- a cached route becomes unsafe within ~20 frames (TTL 24 diverged) because the priced units moved;
- every re-search differs, so the 96% request redundancy cannot be exploited;
- capping a search triggers immediate re-requests, because the route is stale for reasons unrelated
  to terrain.

In other words, the 14.7 ms is not "A* is slow"; it is **paying dynamic-occupancy prices inside a
static search, then redoing the search when the prices change**.

## What a port would look like, staged

1. **Static-only routing + local avoidance** (highest leverage): drop ally/unit terms from the A*
   cost, keep terrain/obstacle costs, and move inter-unit handling into the existing move/steer code
   (the engine already has "move allies away"). Routes then depend only on terrain and static
   buildings, so a route stays valid until terrain changes -> caching becomes safe, and the 55
   (start, goal) pairs in the heavy window become cheap.
   - Expected: large (most of the 14.7 ms), because it removes the reason for re-planning.
   - Cost: gameplay-visible. Units will overlap/push differently and may path through allies.
2. **Formation-level pathing for ordinary moves**: extend the existing width-6 group kernel to
   multi-unit move orders (it already handles 3 destinations / 55 pairs cheaply).
3. **Flow field per destination** for the repeated mass-move case; the data (983 requests, 3 goals)
   is exactly the shape flow fields amortise.
4. Only then consider threading: with static routes, the input is immutable and a worker becomes
   safe and cheap (the earlier blocked-input problem disappears).

## Bearing on the 30 FPS target

Technique 1 alone changes the cost model that produced every failed lever (TTL, caps, retries,
prefetch). It is a **gameplay trade**, not a pure optimisation, so it needs a product decision: early
C&C behaviour (units blocking paths, repathing) is part of the game's feel. The modern recipe would
make 1,000 units behave more like Supreme Commander/CoH and less like retail Generals.

## Sources

- HowToRTS, *Basic Flow Fields* (Supreme Commander 2, Planetary Annihilation):
  https://howtorts.github.io/2014/01/04/basic-flow-fields.html
- jdxdev, *RTS Pathfinding 1 - Flowfields* (50x50 field ~0.3 ms, hierarchical):
  https://jdxdev.com/blog/2020/05/03/flowfields
- *Company of Heroes Squad Formations*, AI Game Programming Wisdom 4:
  https://forum.arongranberg.com/uploads/short-url/rWod3K2KhNWcOEdjewnsLXQKU6A.pdf
- openage, AoE formations reverse-engineering notes (grouped units take the same path):
  https://raw.githubusercontent.com/SFTtech/openage/master/doc/reverse_engineering/game_mechanics/formations.md
- *Age of Empires: 25+ years of pathfinding problems with C++* (Meeting C++ 2025):
  https://youtube.com/watch?v=lEBQveBCtKY
- gamedev discussions on local avoidance vs pathfinding (same-team units are not path obstacles):
  https://reddit.com/r/gamedev/comments/zwrhb3/ and
  https://forum.unrealengine.com/t/detour-crowd-ai-units-brake-slow-down-behind-friendlies-instead-of-pathing-around-rts-style/2680565
