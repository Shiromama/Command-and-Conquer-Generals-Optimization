# ISSUE-0007: Game may run on the Intel iGPU instead of the GTX 1650 Ti

- **Status:** Workaround
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-039
- **Related:** [`../research/2026-11-14-engine-digestion.md`](../research/2026-11-14-engine-digestion.md), ISSUE-0006, [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md), ADR-0007
- **Environment:** ASUS TUF F15 FX506LI; Windows 11 26200; NVIDIA 32.0.15.8088

## Symptom

The laptop has hybrid graphics: the Intel UHD iGPU drives the 1920×1080@144 display, while the
GTX 1650 Ti is present but not the active display adapter. Before the fix, Windows had **no
per-application GPU preference** for `Generals.exe`, so the 2003 D3D8 game would use the
system default (typically the iGPU for old applications).

## Reproduction / evidence

```
Win32_VideoController:
  NVIDIA GeForce GTX 1650 Ti  (no current mode)
  Intel(R) UHD Graphics       1920x1080 @ 144 Hz  (active)
UserGpuPreferences: no entry for Generals.exe
```

`[VERIFIED]` 2026-11-14.

## Impact

Rendering, particles, and shadow work may run on the much weaker iGPU, amplifying frame drops
with many entities. It also complicates fullscreen behavior on hybrid laptops.

## Root cause

No explicit Windows graphics preference for the game executable. `[VERIFIED]` absence;
actual adapter selection by the game `[UNKNOWN]` until confirmed with an overlay or GPU
counter.

## Workaround

**Active, verified 2026-11-15.** On this laptop D3D8 enumerates exactly one adapter (Intel UHD
630), so source-level adapter selection cannot move a D3D8 device (`tools/adapter-probe.cpp`:

```
adapters=1
[0] vendor=0x8086 device=0x9BC4 desc="Intel(R) UHD Graphics"
```

The working path is a D3D9 backend plus Windows' per-app preference:

1. install d3d8to9 v1.16.0 as `d3d8.dll` in the copy;
2. `tools/set-gpu-preference.ps1 -ExePath <copy>\Generals.exe -Action Enable`
   (`HKCU\Software\Microsoft\DirectX\UserGpuPreferences`, `GpuPreference=2`);
3. verify with `tools/list-process-modules.ps1`: `nvd3dum.dll` / `nvldumd.dll` load instead of
   `igdumdim32.dll`.

Measured on ShockWave (400 tanks + nuke FX): median **26.09 → 19.66 ms**, p95 **35.94 → 21.47
ms** (EXP-008). The change is per-user and reversible with `-Action Disable`; it must be
re-applied if the copy moves because the key is the executable path.

The retail/GenTool online profile still runs on the iGPU unless the user sets an NVIDIA
Control Panel profile for that executable; Windows' preference is ignored by D3D8.

## Resolution / verification

**Workaround active** (not a source fix on this hardware). Verified commands and evidence are
above and in [`../experiments/EXP-008-shockwave-nuke-performance.md`](../experiments/EXP-008-shockwave-nuke-performance.md).
Source-level `ZH_ADAPTER` selection is implemented (T-039) and is a no-op on a one-adapter D3D8
system; it remains the portable fix for machines where D3D8 exposes both adapters.

## History

- 2026-11-14 — recorded during environment inventory (PE version info).
- 2026-11-14 — machine-specific registry preference applied, then reverted to keep the
  baseline/work workflow portable; source-level adapter selection remains the fix.
- 2026-11-15 — probe proved D3D8 exposes one adapter; d3d8to9 + per-app preference verified to
  load the NVIDIA driver and improve frame time by 1.33x.
