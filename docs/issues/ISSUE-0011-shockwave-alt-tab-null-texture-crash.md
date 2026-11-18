# ISSUE-0011: Repeated Alt+Tab crashes ShockWave with a null-texture access violation

- **Status:** Workaround
- **Severity:** High
- **Date found:** 2026-11-15
- **Task:** T-040
- **Related:** ISSUE-0005, ISSUE-0008, T-039; [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md)
- **Environment:** ASUS TUF F15; Intel UHD + GTX 1650 Ti; 1920x1080; GenTool 8.9; ShockWave 1.201 on retail 1.04

## Symptom

Repeated Alt+Tab while a ShockWave match is running terminates the game. The user sees the
usual "Technical Difficulties" style exit. Windows Error Reporting logs nothing for
`Generals.exe` because the engine catches the exception itself and exits after writing
`ReleaseCrashInfo.txt`.

## 2. Verified crash signature

`%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data\ReleaseCrashInfo.txt`
(`[VERIFIED]` both files):

```
Release Crash at Sun Nov 15 04:25:30 2026
; Reason Uncaught Exception in GameEngine::update
Exception is access violation
Access address:00000020 was written to.
Stack Dump: <Unknown>(-1) : <Unknown> 0x0081A7A5
Eip:0081A7A5  Ecx:00000000
Bytes at CS:EIP (0081A7A5): 89 41 20 8B 41 38 C3
```

`ReleaseCrashInfoPrev.txt` (04:05:29, before this session — i.e. a genuine user play session)
has the **same EIP, same fault address and same register pattern**. Two independent sessions,
one identical fault: this is the reported crash.

- `89 41 20` = `mov [ecx+0x20], eax` with `ecx = 0` → write to `0x20`, a null `this`.
- The following `8B 41 38` / `C3` identify the function body exactly.

## 3. Root-cause mapping

The retail binary contains exactly one copy of that instruction sequence, at
`0x0081A7A0` (`image base 0x00400000`). The same sequence exists exactly once in our source
build; the linker map names it:

```
TextureBaseClass::Peek_D3D_Base_Texture()
    mov eax, ds:[WW3D::SyncTime]   ; LastAccessed = WW3D::Get_Sync_Time()
    mov [ecx+0x20], eax
    mov eax, [ecx+0x38]            ; return D3DTexture
    ret
```

`[VERIFIED]` `tools/pe-disasm.py around … 0x81A7A5`; source
`Core/Libraries/Source/WWVegas/WW3D2/texture.cpp:254-258`; symbol via the linker map at
`0x007F7480` in `build/engine-vs-community`.

So the engine is calling a **texture method through a null `TextureBaseClass*` while
rendering**. This is consistent with a device-loss/reset path leaving a null texture
reference (render target, shadow map, cloud/water texture, or a material texture) that the
next frame dereferences.

## 4. Reproduction

Environment: `game/shockwave-work` (retail 1.04 exe, GenTool 8.9, `1920x1080`, exclusive
fullscreen), China Nuke General skirmish on North America.

Tool: `tools/alt-tab-stress.ps1` (helper-window focus dance + optional real Alt+Tab chord,
per-cycle memory/handle metrics).

| Run | Cycles | Result |
|---|---|---|
| menu, 20 cycles | 20 | survived |
| in-game, 20 cycles | 20 | survived |
| in-game, 100 cycles, 0.5 s dwell | 100 | survived all cycles, private bytes 230–239 MB and handles 667–673 (flat), **then crashed during the post-run hold** — `ReleaseCrashInfo.txt` 04:25:30 |

`[VERIFIED]` `artifacts/2026-11-15-shockwave-analysis/alttab-retail-100.csv` and the shell
transcript. No memory/handle leak is visible before the fault, so this is not a slow resource
exhaustion; it is a state error after repeated device loss/restore.

## 5. External corroboration

`[SOURCED]` PCGamingWiki, *Command & Conquer: Generals* → "Technical Difficulties" → "When
using Alt+Tab": the game "can at times crash when using Alt+Tab, in particular the second
time", attributed to non-native resolutions. Listed fixes: d3d8to9 (as `d3d8x.dll` when
GenTool is present), windowed mode, or TheSuperHackers' game code ("does not suffer from this
issue"). Community reports also blame GenTool for alt-tab crashes
(gamereplays.org thread 999775; r/commandandconquer threads).

## 6. Working hypotheses

1. **Retail device-lost path leaves a null texture** used by the next draw (best fit for the
   fault). The SuperHackers source already removed the old `WM_ACTIVATEAPP` device-reset path
   and shortens device-lost waits; that engine is the natural candidate fix.
2. **GenTool 8.9 participates**: it owns the `d3d8.dll` slot and may reset/recreate resources.
   Test retail without GenTool, and with d3d8to9 chain-loaded as `d3d8x.dll`.
3. **Alt+Tab/minimise path**: our focus-dance does not minimise the window. The user's real
   Alt+Tab may; test with the real chord and, if needed, a taskbar click.

## 7. Workarounds and fix plan

All rows below are 120 focus cycles in a live skirmish at 1920×1080, `tools/alt-tab-stress.ps1`
(`crashinfo_before` / `crashinfo_after` compared, per-cycle memory and handle counts recorded):

| Configuration | Mode | Result | Handles over 120 cycles |
|---|---|---|---|
| Retail + GenTool 8.9 | exclusive fullscreen | **crash** at ~100 cycles (EIP `0081A7A5`) | flat (667→673) |
| Retail + system D3D8 (no GenTool) | exclusive fullscreen | **crash**, same EIP (`ReleaseCrashInfo.txt` 05:09:22) | flat (513→505) |
| Retail + d3d8to9 `d3d8.dll` | exclusive fullscreen | alive, no new crash info | 740→856 (+~1/cycle) |
| Retail + GenTool 8.9 | **borderless** (`-win`, `window=3`) | alive, no new crash info | flat (666→664) |
| Retail + GenTool + d3d8to9 (`d3d8x.dll`) | **borderless** (`-win`, `window=3`) | alive, no new crash info; **NVIDIA `nvd3dum.dll`** | flat (738→738) |
| Rebuilt engine + d3d8to9 | borderless | alive, no new crash info | 759→763 |

Conclusions:

- The fault is in the **retail 1.04 exclusive-fullscreen device-loss path**, not in ShockWave's
  data and not specifically in GenTool: both GenTool and plain system D3D8 crash with the same
  null-texture signature, while the D3D9 path (d3d8to9) and borderless mode do not.
- **Online-safe fix:** run the retail game borderless (`-win` + GenTool `window=3`). 120 cycles
  stable with flat handles; this keeps GenTool, SWR.net and the ordinary launcher. On the real
  installation this needs no file edits: start ShockWave with the launcher's **Windowed**
  button, then press Insert and set GenTool's Window Position to **Full**.
- **Online + dGPU:** additionally place d3d8to9 v1.16.0 in the game folder as `d3d8x.dll`
  (GenTool chainloads it). With borderless this survives 120 cycles with flat handles and loads
  `nvd3dum.dll` (GTX 1650 Ti) instead of `igdumdim32.dll`. Delete `d3d8x.dll` to revert.
  `[VERIFIED]` modules list + `alttab-retail-gentool-d3d8x-120.csv`.
- **Singleplayer fix:** the rebuilt engine (which already contains the upstream device-reset
  fixes) or d3d8to9. The engine additionally has no handle growth; d3d8to9 leaks ~1 handle per
  focus cycle on the retail binary (monitor for very long sessions).
- Do not run the retail binary in exclusive fullscreen while using Alt+Tab.

## Resolution / verification

**Status: Workaround.** The retail binary still contains the fault; the verified mitigations
above avoid it. Verification commands and evidence:

```
.\tools\alt-tab-stress.ps1 -Cycles 120 -DwellSeconds 0.4 -HoldSeconds 30 `
    -MetricsPath artifacts\2026-11-15-shockwave-analysis\alttab-<config>-120.csv
```

- borderless + GenTool: `alttab-retail-gentool-borderless-120.csv` (120/120, handles 666→664,
  `ReleaseCrashInfo.txt` unchanged).
- borderless + GenTool + d3d8to9 (`d3d8x.dll`): `alttab-retail-gentool-d3d8x-120.csv`
  (120/120, handles 738->738, `nvd3dum.dll` loaded, no new crash info).
- d3d8to9 retail: `alttab-retail-d3d8to9-120.csv` (120/120, handles 740→856, no crash info).
- rebuilt engine + d3d8to9: `alttab-engine-dgpu-120.csv` (120/120, handles 759→763).
- exclusive + system D3D8: crash at 05:09:22, EIP `0081A7A5`, same signature as the GenTool
  crash at 04:25:30 and the pre-session crash at 04:05:29.

The root cause is the null `TextureBaseClass*` dereference during device restore; a source-level
guard was deliberately not added because it would hide a state bug. Upstream's device-reset
rework is the durable fix and is present in the rebuilt engine.

**Online acceptance (not verified).** SWR.net/GenTool acceptance of the chainloaded d3d8to9 was
not tested: the user has no SWR.net account/opponent. Per the user's decision, online play stays
stock (no T-041 limiter, no binary modification); `d3d8x.dll` remains opt-in and can be deleted
to revert. Conservative fallback: GenTool + borderless without `d3d8x`.
