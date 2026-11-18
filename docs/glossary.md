# Glossary

> **Status:** living · **Last verified:** 2026-11-14
> Add terms as they appear. Format: term — definition — evidence label if non-obvious.

## Project terms

| Term | Meaning |
|---|---|
| **P0–P4** | Roadmap phases; see [`roadmap.md`](roadmap.md). |
| **Evidence label** | `[VERIFIED]`, `[SOURCED]`, `[INFERRED]`, `[UNKNOWN]`; see [`../AGENTS.md`](../AGENTS.md) §4. |
| **ADR** | Architecture decision record in [`decisions/`](decisions/README.md). |
| **Baseline** | The measured, reproducible "before" state used to judge any optimization. |
| **Reference installation** | The read-only game folder; see ADR-0002. |
| **Baseline copy** | `game/baseline-pristine/`: byte-exact, read-only, SHA-256 manifest; see ADR-0006. |
| **Work copy** | `game/work/`: mutable copy where fixes and tests are applied; never the baseline. |
| **Profile** | Small config overlay under `game/profiles/` applied to the work copy (e.g. `fullscreen`). |

## Game / engine terms

| Term | Meaning |
|---|---|
| **Zero Hour (ZH)** | Standalone expansion to Command & Conquer: Generals (2003). The installed product. `[VERIFIED]` |
| **SAGE** | Strategy Action Game Engine; the engine family Generals/Zero Hour belong to. `[SOURCED]` |
| **`game.dat`** | The game executable under a `.dat` name; identical to `Generals.exe` in this install. `[VERIFIED]` |
| **GenTool** | Community wrapper/proxy that ships as `d3d8.dll` here; version 1.0.0.0 resource, `gentool76` config. `[VERIFIED]` |
| **BIG / `BIGF`** | EA archive container format. All 22 `.big` files (21 archives in the root, 1 stub in `launcher/`) start with ASCII `BIGF`. `[VERIFIED]` magic; format details `[SOURCED]` || **INI** | Text-based data definitions (units, weapons, armor, AI). In this install they live inside `INIZH.big`, not in loose files. `[VERIFIED]` empty `Data/INI` + `[SOURCED]` modding practice |
| **W3D** | Westwood 3D model/animation format used by the engine. `[SOURCED]` |
| **`.scb`** | Compiled map/script bytecode; loose copies exist in `Data/Scripts`. `[SOURCED]` |
| **`.bik`** | Bink video file; played via `BINKW32.DLL`. `[SOURCED]` |
| **Miles / MSS** | Miles Sound System audio middleware (`mss32.dll`, `MSS/*.m3d`). `[SOURCED]` |
| **`.lcf`** | Launcher configuration (here `generals.lcf`, `RUN = . game.dat`). `[VERIFIED]` file text |
| **Proxy DLL** | A DLL named like a system library (e.g. `d3d8.dll`) that forwards calls while adding behavior. GenTool already occupies this slot. `[SOURCED]` |
| **WorldBuilder** | Official map editor shipped as `WorldBuilder.exe` 0.8.0.0. `[VERIFIED]` version info |
| **Fixed tick** | Deterministic simulation step used by RTS engines; a candidate optimization surface. `[INFERRED]` |

## Tooling terms

| Term | Meaning |
|---|---|
| **PresentMon** | External frame-presentation capture tool; candidate for baseline measurement. `[SOURCED]` |
| **ETW** | Event Tracing for Windows; OS-level profiling. `[SOURCED]` |
| **RenderDoc** | Graphics API capture/debugger; D3D8 support is limited (D3D9+ typical). `[SOURCED]` |
| **x86dbg** | Windows debugger commonly used for 32-bit game binaries. `[SOURCED]` |
