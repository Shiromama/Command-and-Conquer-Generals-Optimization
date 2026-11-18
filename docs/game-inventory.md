# Game installation inventory

> **Status:** verified snapshot · **Last verified:** 2026-11-14
> Everything here was observed in `Command and Conquer Generals Zero Hour/`. This is a
> read-only reference copy; see ADR-0002. Sizes are bytes from `Get-ChildItem`.

## 1. Top-level layout

| Path | Kind | Notes |
|---|---|---|
| `*.big` (21 in root, 1 stub in `launcher/`) | Game archives | `BIGF` container format; hold INI, W3D, textures, audio, maps, UI. `[VERIFIED]` magic |
| `game.dat`, `Generals.exe` | Executables | Identical SHA-256, 6,883,376 bytes, patched build `[VERIFIED]` |
| `*.bak` | Backups | `game.dat.bak`, `generals.exe.bak`, `WindowZH.big.bak` `[VERIFIED]` |
| `d3d8.dll` + `d3d8.cfg` | Direct3D 8 proxy | GenTool 1.0.0.0, config section `gentool76` `[VERIFIED]` |
| `GenToolUpdater.exe` | Utility | GenTool auto-updater `[VERIFIED]` version info |
| `WorldBuilder.exe` | Editor | World Builder 0.8.0.0 `[VERIFIED]` |
| `MSS/` | Audio drivers | Miles Sound System `.m3d`/`.asi`/`.flt` plugins `[SOURCED]` |
| `Data/` | Loose data overlay | Cursors, movies, scripts, water textures; **`Data/INI` is empty** `[VERIFIED]` |
| `launcher/` | Wrapper | 44,032-byte stub `Generals.exe` + `.txt` control files `[VERIFIED]` |
| `Launcher.txt` | Patch notes | Versions 1.01–1.04 `[VERIFIED]` |
| `generals.lcf` | Launcher config | Points at `game.dat` `[VERIFIED]` |
| `d3d8.cfg` | GenTool config | `pitch=37` `[VERIFIED]` |

## 2. Archives

There are 21 archives in the installation root plus a 24-byte empty stub,
`launcher/MapsZH.big` (marker `L225`). All 22 start with the ASCII magic `BIGF`. Contents are
not extracted in this repository yet (ADR-0004); the archive parser is deferred to P1.

| Archive | Bytes | Likely contents |
|---|---:|---|
| `340_ControlBarPro1080ZH.big` | 50,502 | UI control bar, 1080p variant |
| `340_ControlBarProZH.big` | 25,423,641 | UI control bar |
| `400_ControlBarHDEnglishZH.big` | 47,868,005 | HD control bar (English) |
| `990_DecalsZH.big` | 7,519,527 | Decal textures |
| `AudioEnglishZH.big` | 58,326,522 | English voice/audio |
| `AudioZH.big` | 23,965,542 | Base audio |
| `EnglishZH.big` | 80,472,928 | English localization data |
| `GensecZH.big` | 787,464 | Game security data `[UNKNOWN detail]` |
| `INIZH.big` | 18,764,687 | **All INI game rules/data** (the loose `Data/INI` folder is empty) |
| `MapsZH.big` | 39,749,312 | Multiplayer/skirmish maps |
| `Music.big` | 786,724 | Music tracks |
| `MusicZH.big` | 34,741,916 | Zero Hour music |
| `PatchZH.big` | 118,822 | Patch payload |
| `ShadersZH.big` | 996 | Shader definitions |
| `SpeechEnglishZH.big` | 254,275,694 | English speech (largest archive) |
| `SpeechZH.big` | 6,174,552 | Base speech |
| `TerrainZH.big` | 8,660,432 | Terrain textures/data |
| `TexturesZH.big` | 222,753,036 | Unit/building textures |
| `W3DEnglishZH.big` | 2,696,872 | English W3D assets |
| `W3DZH.big` | 189,741,064 | W3D models/animations |
| `WindowZH.big` | 8,493,520 | UI windows/layouts |
| `WindowZH.big.bak` | 8,493,653 | Backup of the above |
| `launcher/MapsZH.big` | 24 | Empty `BIGF` stub (marker `L225`), not a data archive |

Observations:

- The four biggest archives (`SpeechEnglishZH`, `TexturesZH`, `W3DZH`, `EnglishZH`) account
  for roughly 747 MB, over half the installation. `[VERIFIED]` sizes
- `INIZH.big` is the primary rules/data surface: gameplay tuning, weapons, armor, AI, and
  object definitions live there, not in loose files. `[VERIFIED]` empty `Data/INI` +
  `[SOURCED]` Generals modding practice.

## 3. Loose data overlay (`Data/`)

| Folder | Contents | Count/size |
|---|---|---|
| `Cursors/` | `.ani` cursor animations | ~54 files `[VERIFIED]` |
| `English/Movies/` | `.bik` campaign/briefing movies | ~34 files, ~340 MB `[VERIFIED]` |
| `INI/` | **empty directory** — rules are in `INIZH.big` | 0 files `[VERIFIED]` |
| `Movies/` | `.bik` menu/logo movies | 3 files `[VERIFIED]` |
| `Scripts/` | `Scripts.ini`, `SkirmishScripts.scb`, `MultiplayerScripts.scb` | 3 files, ~2.3 MB `[VERIFIED]` |
| `WaterPlane/` | `caust00..31.tga` water caustics | 32 files `[VERIFIED]` |

## 4. Launcher behavior

`launcher/Generals.exe` is only 44,032 bytes, far smaller than the 6.8 MB game binary, and
the folder contains plain-text control files (`launch.txt` → `..\Generals.exe`,
`commandline.txt` → `-win`, `shellexecute.txt` → `0`, `big.txt` empty).
`[INFERRED: the stub reads these files and starts the real executable with the given
arguments; not yet confirmed at runtime.]`

The root `generals.lcf` says `RUN = . game.dat`, and the root `Generals.dat` is a 56-byte
binary blob while `launcher/Generals.dat` is the text `dummy file for gameranger validation`.
`[VERIFIED]` contents/sizes.

**Runtime writes:** the game has not been launched from this repository yet. RTS titles of
this era commonly write configuration, logs, and savegames next to the executable and in the
user profile, and GenTool may rewrite `d3d8.cfg`. Before the first launch (T-005), hash the
installation, prefer launching a copy under `artifacts/`, and record where writes land.
`[UNKNOWN]` exact write locations for this build.

## 5. Third-party modifications present

- **GenTool** — a community wrapper/proxy (`d3d8.dll`, `GenToolUpdater.exe`, `d3d8.cfg`).
  Version resource says 1.0.0.0; config section says `gentool76`. `[VERIFIED]`
- Patched executables — `game.dat` and `Generals.exe` are identical and ~400 KB larger than
  their `.bak` counterparts. `[VERIFIED]` sizes/hashes; cause `[INFERRED]` (GenTool patching).
- Legacy `SECDRV.SYS` (SafeDisc) is present but no driver is installed by this repository.
  `[VERIFIED]` file; `[SOURCED]` nature.

These modifications matter for optimization work: any proxy-DLL approach must decide how it
coexists with GenTool (see [`architecture.md`](architecture.md) §5 and ADR-0002).

## 6. Not yet known

- Exact archive directory layout/compression and how to extract assets (deferred, ADR-0004).
- Whether the executables are packed/compressed or have anti-tamper checks. `[UNKNOWN]`
- Which code paths dominate frame time. `[UNKNOWN]` — P1 measurement.
- Full contents of `INIZH.big`. `[UNKNOWN]` until extracted.
