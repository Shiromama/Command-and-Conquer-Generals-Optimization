# ShockWave installation inventory

> **Status:** verified inventory · **Last verified:** 2026-11-15
> Source: `Command and Conquer Generals Zero Hour - Shockwave/` (1.82 GB, 1,900+ files).
> This is a **data-only mod on the retail 1.04 engine**; see §2. Never modify it.

## 1. What is installed

| Item | Value | Evidence |
|---|---|---|
| Root | `Command and Conquer Generals Zero Hour - Shockwave/` | `[VERIFIED]` listing |
| Size | 1.82 GB | `[VERIFIED]` recursive size |
| `game.dat` / `Generals.exe` | 6,883,376 bytes, SHA-256 `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B` | `[VERIFIED]` identical to the vanilla ZH 1.04 executables in `game/baseline-pristine/` |
| `game.dat.bak`, `generals.exe.bak` | 6,483,968 / 6,480,431 bytes | `[VERIFIED]` leftovers from an older launcher generation; not used at runtime |
| d3d8 proxy | `d3d8.dll` 3,843,584 bytes, SHA-256 `BE5276180D04B3DE…`, "GenTool", GenTool splash reports **8.9** | `[VERIFIED]` file hash + in-game splash screen |
| GenTool config | `d3d8.cfg`: `[gentool76]` + `pitch=37` (section name is legacy; binary is 8.9) | `[VERIFIED]` |
| Mod archives | 13 `!*.gib` files (≈ 563 MB) + retail `*.big` | `[VERIFIED]` |
| Loose data | `Data/Scripts`, `Data/WaterPlane`, `Data/Cursors`, `Data/ShMovies`… | `[VERIFIED]` |

## 2. The launcher is a file renamer, not an engine patch

`Shockwave_Lnchr.dat` is a file map:

```
!Shw_ini.gib      > !Shw_ini.big
!ShwW3D.gib       > !ShwW3D.big
Data\scripts\Scripts.ini > Data\scripts\Scripts.bcs
...
```

`[VERIFIED]` `Shockwave_Lnchr.dat` contents. The launcher renames the `!*.gib` archives to
`*.big` before starting `Generals.exe` and restores the names on exit.

Why that is sufficient `[VERIFIED]` in the GPL source:

- `BIGFileSystem::init()` loads `*.big` from the run directory (`BIGFileSystem.cpp:89`), so a
  `.gib` file is invisible to the engine.
- `loadArchiveFilesFromDirectory` uses `getFileListInDirectory(..., TRUE)` (sorted ascending)
  and `loadIntoDirectoryTree(archiveFile, overwrite = FALSE)`, which appends duplicates and
  resolves to the **first** entry (`ArchiveFileSystem.cpp:118-205`). `!` (0x21) sorts before
  letters, so `!0Shwpatch.big`, then `!Shw_*.big`, win over the retail `*.big`.

Consequence: **the mod's runtime is stock 1.04 code**. All mod changes are data (INI, W3D,
textures, audio, maps, scripts). `[VERIFIED]` executable hash equals retail.

## 3. What the mod actually contains (extracted with `tools/big-archive.py`)

| Archive | Entries | Bytes | Notes |
|---|---|---|---|
| `!Shw_ini.gib` | 759 | 25,549,672 | `Data/INI/**`; 1,642 `ParticleSystem` blocks vs 1,087 in stock `INIZH.big` |
| `!ShwW3D.gib` | 2,384 | 123,908,460 | `Art/W3D/**` models and animations |
| `!ShwTextures.gib` | 968 | 67,030,214 | `Art/Textures/**` |
| `!Shw_maps.gib` | — | 31,714,721 | maps |
| `!0Shwpatch.gib` | 5 | 631,247 | hotfix textures + `ScoutCarHorn.wav`; loads first |

`[VERIFIED]` `python tools/big-archive.py info <archive>` and
`artifacts/2026-11-15-shockwave-analysis/`.

- `INIZH.big` is also replaced inside the mod folder (18,764,481 bytes vs 18,764,687 stock), so
  a few stock rules are edited as well.
- `GameData.ini` keeps `UseShadowVolumes = Yes`, `UseShadowDecals = Yes`,
  `MaxParticleCount = 2500`; the user's `Options.ini` raises the runtime particle cap to 5000.

## 4. The player's effective settings

`%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data\Options.ini`
(`[VERIFIED]` 2026-11-15):

```
Resolution = 1920 1080
AntiAliasing = 0
StaticGameLOD = Low        IdealStaticGameLOD = Low
MaxParticleCount = 5000
UseShadowVolumes = yes     UseShadowDecals = yes
TextureReduction = 0
```

## 5. Rendering adapter (important)

The machine is a hybrid laptop: NVIDIA GTX 1650 Ti + Intel UHD Graphics, display at
1920×1080, DPI scale 120 (`[VERIFIED]` `Win32_VideoController`, registry `AppliedDPI`).

Both the retail ShockWave process and the rebuilt engine loaded the **Intel** user-mode
driver, i.e. the game rendered on the iGPU:

- retail process modules: `igdumdim32.dll`, `igd9dxva32.dll`, `igdgmm32.dll`,
  `igdinfo32.dll` from the Intel driver store (`[VERIFIED]`
  `tools/list-process-modules.ps1`, 32-bit PowerShell);
- engine crash minidump module list: same Intel modules plus `System32\d3d8.dll`
  (`[VERIFIED]` `tools/minidump-triage.py` on
  `Documents\...\CrashDumps\CrashMZ-20261115-002524-…dmp`).

The engine hardcoded `D3DADAPTER_DEFAULT` in `dx8wrapper.cpp` (device creation and mode
queries). Optimization T-039 adds source-level adapter selection (`ZH_ADAPTER`, default =
largest dedicated VRAM). This is expected to dominate every other ShockWave graphics win
because nuke effects are fill-rate bound.

## 6. Reproducible isolation workflow

```powershell
# one command: copy + materialise, install engine, install d3d8to9, set GPU preference, launch
.\tools\play-shockwave-performance.ps1

# or step by step:
# 1. copy the mod install and materialise .gib -> .big (never touches the source)
.\tools\prepare-shockwave-copy.ps1 -GameDir game\shockwave-engine

# 2. install a built engine (disables GenTool by default; retail exe is backed up)
.\tools\stage-engine.ps1 -GameDir game\shockwave-engine `
    -BuiltExe build\engine-vs-community\GeneralsMD\Release\generalszh.exe

# 3. d3d8to9 + per-app high-performance GPU preference (needed for the dGPU)
Copy-Item artifacts\d3d8to9\d3d8-1.16.0.dll game\shockwave-engine\d3d8.dll -Force
.\tools\set-gpu-preference.ps1 -ExePath game\shockwave-engine\Generals.exe -Action Enable

# 4. launch / inspect
.\tools\launch-game.ps1 -GameDir game\shockwave-engine -Mode borderless -QuickStart
.\tools\capture-game-window.ps1 -Path artifacts\shot.png
```

For **online-style stock play** (no limiter; GenTool + d3d8to9 + borderless):

```powershell
.\tools\play-shockwave-online.ps1 -GameDir game\shockwave-work
# equivalent manual setup: stock Generals.exe, GenTool d3d8.dll,
# d3d8to9 as d3d8x.dll, d3d8.cfg window=3, launch -win
```

`[VERIFIED]` the copy boots the mod on the rebuilt engine: the window title reports the
ShockWave product string and version 1.201/1.04, and the shell map/menu renders ShockWave art
(`artifacts/2026-11-15-shockwave-analysis/screens/shockwave-menu3.png`). With d3d8to9 + the GPU
preference the process loads `nvd3dum.dll` (GTX 1650 Ti) instead of `igdumdim32.dll`
(`tools/list-process-modules.ps1`).
