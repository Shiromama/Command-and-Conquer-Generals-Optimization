# ADR-0009: GenTool-compatible discrete-GPU path (supersedes part of ADR-0007)

- **Status:** Accepted
- **Date:** 2026-11-15
- **Deciders:** project lead
- **Related:** T-042, T-039; [`ADR-0007-shockwave-two-profiles.md`](ADR-0007-shockwave-two-profiles.md), [`../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md`](../issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md), [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md)

## Context

ADR-0007 recorded that "GenTool + d3d8to9 (`d3d8x.dll`) starts but exits before the menu in this
install", which forced the online profile onto the D3D8 iGPU. That observation was made with a
GenTool config that had no `window=` key while the game was launched with `-win`: GenTool
selected its default (exclusive) mode, the D3D9 wrapper could not match it, and the process
exited with code 0.

GenTool has officially supported chainloading `d3d8x.dll` since 7.5, and the community reports
d3d8to9 working behind it. Retested with the borderless preset:

```
d3d8.cfg: [gentool76] pitch=37 / window=3
launch  : Generals.exe -win -xres 1920 -yres 1080 (game copy)
files   : d3d8.dll = GenTool 8.9, d3d8x.dll = d3d8to9 1.16.0
```

- process modules: `D3D8.DLL` (GenTool), `d3d8x.dll`, `d3d9.dll`, `nvd3dum.dll` (GTX 1650 Ti)
  `[VERIFIED]` `tools/list-process-modules.ps1`;
- 120 focus cycles in a live skirmish: alive, handles 738→738, memory stable, no new
  `ReleaseCrashInfo.txt` `[VERIFIED]` `alttab-retail-gentool-d3d8x-120.csv`.

## Decision

1. The **online profile** may run GenTool + d3d8to9 as `d3d8x.dll` + borderless
   (`-win`, GenTool `window=3`). This keeps GenTool/SWR.net features, avoids the
   exclusive-fullscreen Alt+Tab crash, and renders on the discrete GPU.
2. d3d8to9 remains **opt-in and reversible**: install by putting the DLL in the game folder,
   revert by deleting `d3d8x.dll`. The real installation is only touched with the user's
   explicit action, not by a script that edits it silently.
3. The **performance profile** (rebuilt engine, no GenTool) remains the choice for singleplayer
   and for measurements, because it has no wrapper overhead, no anti-cheat surface and the
   T-041 budgets.
4. Update ADR-0007's consequence list accordingly; its decision to keep two profiles stands.

## Consequences

### Positive

- Online play can gain the 1.33× median / 40% p95 GPU improvement (EXP-008) without giving up
  GenTool.
- The alt-tab workaround and the GPU fix combine into one configuration.
- Reversible, user-scoped, no installer or registry profile hack.

### Negative / risks

- Anti-cheat compatibility of a chainloaded d3d8to9 is **presumed** from GenTool's supported
  chainload feature, not independently verified against SWR.net; verify with an online match.
- d3d8to9 is a third-party wrapper; total-conversion mods can expose instability. Monitor.
- Three configurations now exist (engine, GenTool borderless, GenTool + d3d8x borderless); keep
  the docs explicit about which is measured.

### Follow-ups

- User play-test on SWR.net with the chainloaded wrapper.
- Re-run the 120-cycle stress after any GenTool or mod update.

## Amendment 2026-11-15 (user decision)

- **Online play stays stock**: no T-041 limiter and no binary modification. The limiter is
  singleplayer-only because object counts are part of the multiplayer CRC
  (`GameLogic::getCRC`, `GameLogic.cpp:4410-4462`) and GenTool validates game files
  (EXP-008 §9).
- GenTool + d3d8to9 (`d3d8x.dll`) + borderless remains the **opt-in** online dGPU/crash-safe
  profile, launched by [`../../tools/play-shockwave-online.ps1`](../../tools/play-shockwave-online.ps1).
  SWR.net acceptance is **unverified**: the user has no account/opponent to test. Delete
  `d3d8x.dll` to revert to plain GenTool if a lobby rejects it.
- Conservative online fallback: GenTool + borderless without `d3d8x` (no dGPU, but 120 cycles
  stable in ISSUE-0011).
