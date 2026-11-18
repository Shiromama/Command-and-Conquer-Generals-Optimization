# ADR-0005: Source-based hybrid optimization, not a clean-room Rust rewrite

- **Status:** Accepted
- **Date:** 2026-11-14
- **Deciders:** project lead (pending user confirmation of scope)
- **Related:** T-009, T-014, T-016; [`../project-brief.md`](../project-brief.md), [`../architecture.md`](../architecture.md)

## Context

The project started from a shipped 2003 build with no source. That changed:

- EA released the full **Generals / Zero Hour C++ source** under **GPLv3** in 2025
  (`electronicarts/CnC_Generals_Zero_Hour`, archived). `[SOURCED]`
- **TheSuperHackers/GeneralsGameCode** maintains an active fork updated to C++20 and
  Visual Studio 2022, with CMake presets, a Tracy profiling build, and merged fixes such as
  decoupling the render update from the logic time step and fullscreen crash fixes.
  `[SOURCED]` and `[VERIFIED]` (local clone `vendor/GeneralsGameCode` @ `0ff1220`).
- The machine can build it: VS2022 Community 17.13.2 + CMake 3.31.2, 134 GB free.
  `[VERIFIED]`
- OpenSAGE (C#) reimplements SAGE but is still not playable. `[SOURCED]`

The user's actual problems are narrow: unable to run fullscreen, and frame drops with many
entities on an i5-10300H / GTX 1650 Ti laptop. A clean-room Rust rewrite would have to
reimplement rendering, simulation, pathfinding, AI, networking, UI, and all archive formats,
while preserving assets, mods, replays, and multiplayer compatibility — a multi-year scope
with no advantage over using the released source.

## Decision

1. **Use the GPLv3 source as the runtime base.** Build and modify the C++ engine rather than
   reimplementing it.
2. **Fix the reported symptoms first** (fullscreen, entity-heavy performance), then profile
   and optimize hot paths in the source.
3. **Use Rust where it has a clear boundary and measurable benefit**, not as a wholesale
   replacement:
   - Rust tooling: launcher/config doctor, INI/asset analyzers, replay analysis, benchmark
     orchestration.
   - Optional Rust modules behind a narrow C ABI (e.g., a pure algorithm or data transform)
     only if they outperform the C++ implementation in a reproducible benchmark.
4. Keep game assets, installs, and proprietary dependencies out of this repository.

## Consequences

### Positive

- The project inherits 20 years of compatibility, mod support, and multiplayer behavior.
- Existing upstream fixes (fullscreen, high-FPS decoupling, Tracy profiling) are available.
- Rust work can be small, testable, and benchmarked instead of speculative.

### Negative / risks

- GPLv3 obligations apply to distributed modified builds.
- 32-bit MSVC build, legacy dependencies (Miles, Bink, DirectX SDK, STLport), and CMake/vcpkg
  setup are non-trivial.
- Upstream churn; changes should be patches or a fork, not silent edits to `vendor/`.
- Rust↔C++ integration adds build complexity and must justify itself with measurements.

### Follow-ups

- T-014: produce a reproducible win32 build and run it against a fixed scenario.
- T-015: capture the entity-heavy baseline on the current install.
- T-016: scaffold the Rust tooling workspace once the build/baseline exists.
- Revisit this ADR if a Rust component can demonstrably replace an engine subsystem, or if
  upstream support for the target platform stalls.
