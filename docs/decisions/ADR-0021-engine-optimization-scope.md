# ADR-0021: Focus the project on C++ engine optimization

- **Status:** Accepted
- **Date:** 2026-11-18
- **Deciders:** Project lead
- **Related:** T-016, T-080, T-092, [ADR-0005](ADR-0005-source-based-hybrid.md)

## Context

[VERIFIED] The runtime changes are C++ patches against the pinned
GeneralsGameCode source. The Rust files in the repository implement the standalone
installer and a test fixture launcher. See [engine patches](../../engine/patches/README.md),
the [patcher manifest](../../patcher/Cargo.toml) and the [fixture launcher](../../tools/guard-fixture-launcher.rs).

## Decision

Present the project as targeted optimization and fixes to the existing engine.
Retire the separate language-driven tooling phase and plans for game-engine modules
in another language. Keep the existing installer, test tooling, and their build
requirements. This updates the scope of ADR-0005 while retaining its decision to
build and modify the upstream C++ engine.
