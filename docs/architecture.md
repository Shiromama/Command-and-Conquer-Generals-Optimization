# Architecture (current understanding)

> **Status:** living model, mostly unvalidated · **Last verified:** 2026-11-14
> This document separates what has been verified locally from external knowledge and open
> hypotheses. Do not promote a hypothesis to fact without a verification entry in
> [`log.md`](log.md).

## 1. Summary

Zero Hour is a 2003 real-time strategy game built on EA's SAGE-lineage engine. It ships as a
single Windows x86 executable (`game.dat` == `Generals.exe`) plus 21 `BIGF` archives (and one
empty stub) that hold
rules (INI), models (W3D), textures, audio, maps, and UI. Rendering goes through Direct3D 8;
in this installation a community **GenTool** proxy DLL occupies `d3d8.dll`.

[VERIFIED] The chosen runtime path is to modify and rebuild the existing C++ engine.
See the [engine build](../engine/README.md) and [ADR-0021](decisions/ADR-0021-engine-optimization-scope.md).

## 2. Component model (as installed)

```
generals.lcf ──> game.dat (== Generals.exe, patched)
                   │
                   ├── d3d8.dll  (GenTool 1.0.0.0 proxy) ──> system D3D8 / GPU
                   ├── mss32.dll (Miles Sound System) + MSS/*.m3d
                   ├── BINKW32.DLL (Bink video) ──> Data/**/*.bik
                   └── BIGF archives (INIZH, W3DZH, TexturesZH, MapsZH, ...)
                         └── Data/ loose overlay (cursors, scripts, movies, water)

launcher/Generals.exe (44 KB stub) ──reads──> launch.txt / commandline.txt / ...
```

Evidence: components `[VERIFIED]` (files, version info, config text); data flow between them
`[INFERRED]` from file names, formats, and standard engine architecture.

## 3. Data surfaces

| Surface | Format | Location | Status |
|---|---|---|---|
| Game rules (units, weapons, armor, AI, upgrades) | INI text | `INIZH.big` | Not extracted `[UNKNOWN contents]` |
| Models/animations | W3D | `W3DZH.big`, `W3DEnglishZH.big` | Not inspected |
| Textures | DDS/TGA (assumed) | `TexturesZH.big`, `TerrainZH.big`, `990_DecalsZH.big` | Not inspected |
| Maps | engine map format | `MapsZH.big` | Not inspected |
| UI layouts | INI + textures | `WindowZH.big`, `ControlBar*` archives | Not inspected |
| Scripts | `.scb` (compiled) + `Scripts.ini` | `Data/Scripts`, archives | Loose `.scb` verified |
| Audio | Miles `.m3d` plugins; audio payloads | `MSS/`, `Audio*.big`, `Speech*.big`, `Music*.big` | Drivers verified |
| Video | Bink `.bik` | `Data/English/Movies`, `Data/Movies` | Verified |
| Shaders | engine shader text | `ShadersZH.big` (996 bytes) | Not inspected |

`[SOURCED]` format identifications (W3D, BIG, Bink, Miles) from the Generals/OpenSAGE
modding ecosystem; `[VERIFIED]` the files exist and the archive magic is `BIGF`.

## 4. Known architecture facts

| Fact | Evidence |
|---|---|
| `game.dat` and `Generals.exe` are byte-identical (same SHA-256) | `[VERIFIED]` hashes in [`environment.md`](environment.md) |
| `.bak` executables are ~400 KB smaller than the live ones | `[VERIFIED]` sizes; patched build `[INFERRED]` |
| `d3d8.dll` is GenTool 1.0.0.0, not Microsoft's runtime | `[VERIFIED]` PE version info |
| `d3d8.cfg` contains `[gentool76]` and `pitch=37` | `[VERIFIED]` file text |
| Loose `Data/INI` is empty; rules must come from `INIZH.big` | `[VERIFIED]` directory count = 0 |
| Game launches windowed through the stub (`-win`) in this install | `[VERIFIED]` `commandline.txt`; effect `[INFERRED]` |
| 21 `BIGF` archives + a 24-byte stub in `launcher/`, 1.29 GB total | `[VERIFIED]` |

## 5. Historical optimization hypotheses

### H1 — D3D8 proxy
Replace/augment `d3d8.dll` with a DLL that forwards to the real D3D8 and adds
instrumentation, frame pacing, or a modern backend translation layer.

- **Pros:** well-known technique; captures all draw calls.
- **Cons:** the filename is already GenTool's; must forward correctly and stay compatible;
  D3D8 → modern API translation is a large undertaking.
- **Unknowns:** GenTool's exports/hooks; whether the game tolerates a different proxy;
  anti-tamper behavior.

### H2 — External instrumentation / tracing
Profile the process from outside (ETW, PresentMon, API tracers) and optimize based on data
before writing runtime code.

- **Pros:** zero risk to game files; produces the P1 baseline.
- **Cons:** limited visibility into internal simulation; some tools are invasive.
- **Unknowns:** which profilers work with this build and GenTool.

### H3 — Asset tooling
Tools for archive extraction/packing, INI parsing/validation, replay analysis, or
load-time optimization.

- **Pros:** self-contained, testable, low risk; useful regardless of runtime work.
- **Cons:** does not directly improve frame time unless load time is the target.
- **Unknowns:** exact BIGF directory format (deferred, ADR-0004); replay format.

### H4 — Simulation/gameplay hooks
Target the fixed-tick simulation (pathfinding, AI, object updates) via binary patching or
injection.

- **Pros:** highest potential gameplay-scale wins.
- **Cons:** highest risk; requires deep reverse engineering; fragile across builds.
- **Unknowns:** virtually everything; needs P2 RE work.

These were scoping hypotheses before the source build. See [ADR-0021](decisions/ADR-0021-engine-optimization-scope.md)
for the current direction.

## 6. Constraints on any design

- The source installation and `game/baseline-pristine/` must remain untouched; all fixes go to
  `game/work/` or tracked source patches.
- Any runtime component must be reversible and documented (install/uninstall steps).
- Measurements must state whether GenTool and the patched executable were active.
- Original binaries are confirmed PE32/x86; a 64-bit rewrite/port is not a cheap option.

## 7. Next architectural questions

1. Can the source build run with the work copy's data without modifying it?
2. What does a frame actually cost — drawable/UI scans, D3D8 submission, or GPU?
3. How much of the entity slowdown is pathfinding versus rendering?
4. Can adapter selection and exclusive fullscreen be fixed in source instead of per-PC
   registry settings?
5. Which optimizations can be done without breaking replay/multiplayer CRC compatibility?

Tracked in [`state.json`](state.json) → `open_questions`.

## 8. Verified optimization targets

The static survey is recorded in
[`research/2026-11-14-engine-digestion.md`](research/2026-11-14-engine-digestion.md). The
highest-confidence targets are:

- drawable region iteration over every drawable per view (`W3DView.cpp:1688` TODO);
- per-drawable client updates and icon UI;
- particle sorted-list insertion (`sortingrenderer.cpp:324-337` TODO bucket sort);
- pathfinding sorted open list and 30k cell allocation cap;
- projected-shadow and behind-building passes.

These are hypotheses until the source build and Tracy measurements rank them on this machine.
