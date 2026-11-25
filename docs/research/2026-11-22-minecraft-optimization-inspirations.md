# Minecraft optimization mods and the Zero Hour engine

- Date: 2026-11-22
- Task: T-117 (follows T-116/T-112)
- Status: mapping note; one cache implemented (combined3); other candidates ranked
- Evidence: [T-117 design](2026-11-22-deploy-guard-long-range-vision.md),
  [T-116 combined run](../../artifacts/2026-11-21-t116-group-relax/manifest.md)

## Why look at Minecraft mods

The modern Minecraft optimization mods are a useful checklist because they were
built for a single-threaded Java game with a hot AI/pathfinding/data layer. Not
all of them map to a C++ D3D8 RTS, but the *method* does: measure the hot path,
remove repeated work, improve data locality, reuse results, and only then
parallelize.

[VERIFIED] The combined T-116/T-117 Last Stand window is **logic/AI-bound**:
`logic` 120.5 ms, `l_ai` 28.0 ms, `draw` 10.6 ms, and path search 29.1 M us over
300 frames. Rendering is not the first bottleneck in this scenario.

## What maps

| Mod idea | Technique | Zero Hour mapping |
|---|---|---|
| **Lithium** | AI/pathfinding scheduling, path reuse, collision and data-structure optimizations | The group pathfinder is the hot path. T-022 heap, T-110/T-112 route cache and the T-112 frozen workers are the existing pieces; the missing lever is safe route reuse or HPA*. |
| **FerriteCore** | Reduce memory/cache overhead; avoid repeated lookups and object bloat | Implemented: cache the effective vision in `Object` instead of scanning weapon slots on every `getVisionRange()` (fog, team, AI, partition). Next: cache the pathfinding cell's occupant object/status instead of `findObjectByID`/`testStatus` per width query. |
| **Sodium** | Rendering batching, occlusion and vertex-format work | Draw is only 10.6 ms in the combined window; secondary for Last Stand. The project's draw-distance/shadow culling is the existing analogue. |
| **EntityCulling** | Skip rendering hidden entities | The project's draw culling/occlusion; useful in draw-heavy scenes, not the pathfinding stress. |
| **C2ME** | Parallel chunk generation/work | The engine is single-threaded game logic. The T-112 frozen-worker snapshot is the existing speculative parallel path; it was parked for late-snapshot cost. A safe job system is a larger project. |
| **Starlight / Krypton** | Lighting engine / networking | Not applicable: static/vertex lighting and singleplayer focus. |

## Implemented now: cached effective vision

[VERIFIED] `Object::getVisionRange()` previously called
`getLargestWeaponRange()` on every query. That is a per-call weapon-slot loop on
a fog/team/AI/partition hot path. `Object::applyLongRangeVision()` now computes
the effective vision at object creation and on weapon-set changes, stores it in
`m_visionRange`, and raises `m_shroudClearingRange` to match. `getVisionRange()`
returns the cached value. Build `combined3` carries this.

This is exactly the FerriteCore/Lithium habit: do the invariant work once, not
per query.

## Next candidates, in order

1. **Pathfinding occupant/status cache** (FerriteCore/Lithium) — implemented
   in T-118: `PathfindCellInfo` caches the positioned `Object*`, and
   `clearCellForDiameter` uses it instead of `findObjectByID`. Build
   `t116-path-cache.exe` `63C2530F...`; no run yet. Verify the expansions are
   unchanged and `ZH_PF_FRAME`/`l_ai` improve before claiming a gain.
2. **Cross-group route cache** (Lithium-style reuse). The T-110/T-112 cache has
   777 exact repeats (5.99 ms/tick offline) but the strict guard rejected most.
   A guard that mirrors `validMovementPosition` is the missing piece.
3. **HPA*/flow field** (Lithium-style coarse navigation). The offline model shows
   51% fewer expanded cells at +0.4% path cost. This is the largest algorithmic
   lever for the 539 rescued groups and the long cross-map paths.
4. **AI tick scheduling/coalescing** (Lithium). `l_updates` is 6.9 ms in the
   combined window; idle/sleeping AI and coalesced group updates are the next
   logic-side target after pathfinding.
5. **Rendering culling/batching** (Sodium/EntityCulling). Only after the logic
   cost is under control; `draw` is 10.6 ms in this window.

## Measurement plan

- Compare `combined3` (cached vision) against the C024 combined run with the
  same Last Stand setup and switches. Use `ZH_ATTR_LOG` and `ZH_PF_FRAME`; the
  T-116 `commands.csv` still reports `reason`/`alt_leader`.
- The deploy-test (T-116 off, T-117 on) is a useful baseline: 3,219 commands,
  134 zone failures (4.2%, median 15), interval 158 ms, path 124.7 ms/frame.
  The T-116 on + cached vision run is the next comparison.
- Then isolate T-116-only and T-117-only runs; the combined numbers are mixed.
- Keep one canonical artifact per run; do not add a new folder per candidate.

## Limitations

- The mod techniques are inspirations, not drop-in code; Minecraft's data model
  and threading differ.
- The combined window is one scenario and mixes T-116/T-117; the frame numbers
  are not a clean A/B.
- The cached vision is refreshed at creation, `setVisionRange` and weapon-set
  changes; a direct write to `m_visionRange` would bypass it.
