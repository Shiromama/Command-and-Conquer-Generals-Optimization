# ADR-0007: Two ShockWave profiles (performance engine vs retail+GenTool)

- **Status:** Accepted
- **Date:** 2026-11-15
- **Deciders:** project lead
- **Related:** T-036…T-040; [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md), [`../issues/ISSUE-0008-gentool-rebuilt-crash.md`](../issues/ISSUE-0008-gentool-rebuilt-crash.md), [`../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md`](../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md)

## Context

Verified facts that constrain any ShockWave design:

1. **ShockWave is data-only.** Its `game.dat` and `Generals.exe` are byte-identical to
   vanilla ZH 1.04 (`F37A4929…495B`). The launcher renames `!*.gib` to `*.big`; the engine
   loads only `*.big` and resolves duplicates to the first archive in ascending filename
   order. `[VERIFIED]` [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md) §2.
2. **The GPL engine runs the mod.** A materialised copy (`game/shockwave-work`,
   `game/shockwave-engine`) boots the ShockWave shell map, menu, title and a full skirmish
   with the mod's units and effects. `[VERIFIED]`
3. **GenTool 8.9 is part of the online experience** (SWR.net / C&C Online anti-cheat,
   widescreen presets). The rebuilt engine crashes with GenTool's proxy (ISSUE-0008), and
   GenTool + d3d8to9 (`d3d8x.dll`) starts but exits before the menu in this install.
4. **D3D8 exposes one adapter only on this laptop** (`adapters=1`, Intel UHD Graphics;
   `tools/adapter-probe.cpp`). Source-level adapter selection therefore cannot move a D3D8
   device to the NVIDIA GPU here. Windows' per-app GPU preference is ignored by D3D8.
5. **d3d8to9 (D3D9) + the per-app High-performance preference does use the NVIDIA GPU**
   (`nvd3dum.dll` loaded), and d3d8to9 alone is a stable wrapper for the rebuilt engine.
   `[VERIFIED]`

## Decision

1. Ship **two explicit profiles**, never a silent mutation of the user's installation:
   - **Performance (singleplayer/skirmish):** rebuilt GPL engine, copied mod install with
     `.gib → .big` materialised, GenTool disabled, optional d3d8to9 + GPU preference.
   - **Online/retail:** the untouched mod installation, stock 1.04 exe, GenTool 8.9
     (ShockWave launcher), plus only verified reversible additions.
2. Keep the engine's adapter-selection code (`ZH_ADAPTER`, default largest dedicated VRAM)
   as a portable fallback for machines where D3D8 exposes multiple adapters. On this laptop
   it is a no-op.
3. Use the Windows per-app GPU preference (`HKCU\Software\Microsoft\DirectX\UserGpuPreferences`,
   `GpuPreference=2`) **only together with a D3D9 path (d3d8to9)** and only through
   [`../../tools/set-gpu-preference.ps1`](../../tools/set-gpu-preference.ps1), which is
   reversible and per-user. Document that it is keyed by executable path, so moving a copy
   requires re-running it.
4. Prefer engine-side optimizations (particle batching, shadow LOD, draw culling, low-detail
   preset) and measured data tuning over visual downgrades; no mod assets are modified.

## Consequences

### Positive

- The performance work can use the full source toolchain (frame logging, culls, harness)
  while the mod keeps its content and gameplay.
- Online play keeps GenTool and the stock binary, avoiding anti-cheat/CRC surprises.
- GPU selection is reversible and user-scoped; no driver/profile hacks.

### Negative / risks

- Two profiles must be explained and kept in sync (same materialised data, different exe).
- The high-performance profile is not usable for SWR.net/C&C Online anti-cheat.
- d3d8to9 is a third-party wrapper and is known to be less stable with total-conversion mods;
  it must stay opt-in and be re-tested after mod updates.

### Follow-ups

- T-038: measure the mod with the rebuilt engine (particles, destruction, shadows).
- T-040: alt-tab stress on both profiles; close ISSUE-0011 only with evidence.
- Revisit the GenTool + d3d8x failure if online performance becomes a requirement.
