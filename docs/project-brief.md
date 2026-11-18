# Project brief

> **Status:** active scope, P2 · **Last verified:** 2026-11-15 · **Owner:** project lead
> Change this document when the goal, scope, or success criteria change.

## 1. Goal

Make **Command & Conquer: Generals Zero Hour** run correctly and fast on the target laptop,
then keep improving the engine with measurable, reproducible changes.

Reported problems, in priority order:

1. **Fullscreen does not work.** The game only runs windowed.
2. **Performance collapses with many entities.** Late-game skirmishes become unplayable.

Optimize the existing engine using the released GPLv3 source and measure each change against
a reproducible baseline.

## 2. Current phase

**P2 — profile and optimize the engine.** The source installation is untouched. A verified
read-only baseline and mutable work copy exist under `game/` (1,914 files, SHA-256 manifest).
Fullscreen is fixed and verified (1920×1080 client area). The 1,000-unit harness is
reproducible, and the portable `performance` profile (AA 0 + Low detail) improves median frame
time **1.78x** (59.41 → 33.36 ms; 16.8 → 30.0 FPS) while keeping all units visible. Real
late-game replay validation is blocked on a compatible replay (ISSUE-0010). Architecture
research (clean environment) shows ~16 ms of headroom at Low: 17.47 ms / 57 FPS uncapped.
Shadow volumes are the High-detail cost; 120 px shadow LOD gives 20.30 ms with near shadows
kept. [VERIFIED] The shadow-map prototype was benchmarked and rejected. The engine continues
to use stencil shadows. See [EXP-029](experiments/EXP-029-shadow-map-rejected.md).

## 3. Strategy (decided)

The engine changes are C++ source patches against a pinned revision of
**TheSuperHackers/GeneralsGameCode**. The patcher and benchmark tools support installation,
recovery, and measurement. [VERIFIED] See the [engine build](../engine/README.md) and
[patcher guide](../patcher/README.md).

See [ADR-0021](decisions/ADR-0021-engine-optimization-scope.md).

## 4. In scope

- Fixing fullscreen/borderless mode and Alt+Tab stability.
- Measuring and improving entity-heavy performance (CPU/GPU/rendering).
- Building, profiling, and modifying the GPLv3 source.
- Reversible patch installation and compatibility validation.
- Reproducible measurements, patches, and documentation.

## 5. Out of scope

- A from-scratch reimplementation of the engine, assets, or networking.
- Redistributing game assets, archives, or proprietary libraries.
- Anti-cheat circumvention or online-play abuse.
- Silent changes to the user's real installation without a backup and a recorded procedure.

## 6. Constraints

| Constraint | Consequence |
|---|---|
| Real install is in `Program Files (x86)` and ACL-protected | Config edits require elevation or a writable copy; see ISSUE-0005. |
| Source is GPLv3 | Distributed modified builds must comply with GPLv3. |
| 32-bit MSVC/C++ engine, legacy libs (Miles, Bink, DirectX SDK) | Build setup is non-trivial; dependencies must be resolved. |
| Engine logic is 30 FPS-coupled | Raising FPS without decoupling changes game speed. |
| GenTool occupies `d3d8.dll` | No naive proxy replacement; see ISSUE-0002. |
| Hybrid Intel/NVIDIA laptop | GPU selection must be explicit; see ISSUE-0007. |
| Multiplayer/mod compatibility matters | Behavior-preserving changes preferred; record compatibility impact. |

## 7. Success criteria

1. **Fullscreen:** stable 1920×1080 borderless play on the work copy, verified by client-rect
   measurement, with Alt+Tab not crashing. The source install and baseline stay untouched.
2. **Performance:** a fixed scenario with a documented baseline and a reproducible improvement
   (target set after baseline), with 1% low and median frame time reported.
3. **No regressions:** gameplay, rendering, audio, saves, and multiplayer behavior preserved
   for the scenarios tested.
4. **Reproducible:** exact build/launch/config steps and artifacts recorded, with no
   machine-specific registry or hardcoded-path fixes.
5. **Reference installs untouched** unless a change is backed up, documented, and approved.

## 8. Open decisions

- How to batch identical unit draw calls at High detail without breaking rendering or replays
  (T-020/T-021).
- Whether a drawable spatial index is worth the complexity given the existing region lists.
- Portable adapter selection and AA clamping in source (T-023 and follow-up).
- A compatible late-game replay for validation (T-025/ISSUE-0010).
- Distribution and GPLv3 compliance.
