# Environment baseline

> **Status:** verified snapshot · **Last verified:** 2026-11-14
> Re-verify and update this file if the machine, toolchain, or installation changes.
> Commands used: PowerShell `Get-Item`/`Get-FileHash`/`Get-CimInstance`, `rustc --version`,
> `cargo --version`, `python --version`, `node --version`, `git --version`.

## 1. Host

| Item | Value | Evidence |
|---|---|---|
| OS | Microsoft Windows 11 Home Single Language | `[VERIFIED]` `Win32_OperatingSystem.Caption` |
| Version | 10.0.26200 (Windows NT 10.0.26200.0) | `[VERIFIED]` |
| Architecture | AMD64 | `[VERIFIED]` `PROCESSOR_ARCHITECTURE` |
| Shell | PowerShell (commands in this repo assume PowerShell 5.1+) | `[VERIFIED]` |
| Workspace | `<workspace>` | `[VERIFIED]` |
| Git repo | initialized locally during P0 (see ADR-0003) | `[VERIFIED]` |

## 2. Toolchain

| Tool | Version | Path | Evidence |
|---|---|---|---|
| rustc | 1.82.0 (f6e511eec 2024-10-15) | `%USERPROFILE%\.cargo\bin\rustc.exe` | `[VERIFIED]` |
| cargo | 1.82.0 (8f40fc59b 2024-08-21) | `%USERPROFILE%\.cargo\bin\cargo.exe` | `[VERIFIED]` |
| Python | 3.10.0 | `%USERPROFILE%\AppData\Local\Programs\Python\Python310\python.exe` | `[VERIFIED]` |
| Node.js | v24.19.0 | `C:\Program Files\nodejs\node.exe` | `[VERIFIED]` |
| Git | 2.47.0.windows.2 | `C:\Program Files\Git\cmd\git.exe` | `[VERIFIED]` |
| Visual Studio | 2022 Community 17.13.2, C++ tools installed | `C:\Program Files\Microsoft Visual Studio\2022\Community` | `[VERIFIED]` (`vswhere`) |
| CMake | 3.31.2 | `C:\Program Files\CMake\bin\cmake.exe` | `[VERIFIED]` |
| Ninja | not on PATH | — | `[VERIFIED]` (needed by the `win32` CMake preset; VS generator is an alternative) |
| 7-Zip | not on PATH | — | `[VERIFIED]` (`7z` missing); no archive tooling yet |

Notes:

- Rust 1.82 is older than the current stable line; pin or upgrade deliberately before creating
  a workspace. The toolchain version is part of the reproducibility baseline.
- Python is used only for repository verification (`tools/check_docs.py`), not for game tooling.

## 3. Game installation

| Item | Value | Evidence |
|---|---|---|
| Path | `Command and Conquer Generals Zero Hour/` (workspace-relative) | `[VERIFIED]` |
| Total size | 1.29 GB (1,385,000,000 bytes approx., `Get-ChildItem -Recurse`) | `[VERIFIED]` |
| Product | Command & Conquer: Generals Zero Hour | `[VERIFIED]` folder contents, `Launcher.txt` |
| Reported patch level | 1.04 (March 2005) — final listed patch in `Launcher.txt` | `[VERIFIED]` (file text) |
| Tracked in git | no (ignored, see ADR-0002) | `[VERIFIED]` `.gitignore` |

### 3.1 Key binaries and hashes

SHA-256, computed with `Get-FileHash -Algorithm SHA256`.

| File | Bytes | SHA-256 | Notes |
|---|---:|---|---|
| `game.dat` | 6,883,376 | `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B` | Byte-identical to `Generals.exe` `[VERIFIED]` — patched build |
| `Generals.exe` | 6,883,376 | `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B` | Same hash as `game.dat` `[VERIFIED]` |
| `game.dat.bak` | 6,483,968 | not hashed | Pre-patch backup `[INFERRED: `.bak` naming + size difference]` |
| `generals.exe.bak` | 6,480,431 | not hashed | Pre-patch backup `[INFERRED]` |
| `d3d8.dll` | 3,843,584 | not hashed | Version 1.0.0.0, ProductName **GenTool** `[VERIFIED]` (PE version info) |
| `GenToolUpdater.exe` | 1,556,992 | not hashed | "Auto-updater for GenTool", 1.0.0.0 `[VERIFIED]` |
| `WorldBuilder.exe` | 10,604,603 | not hashed | "Command And Conquer Generals World Builder", 0.8.0.0 `[VERIFIED]` |
| `BINKW32.DLL` | 358,963 | not hashed | Bink video runtime `[SOURCED]` |
| `mss32.dll` | 349,696 | not hashed | Miles Sound System `[SOURCED]` |
| `P2XDLL.DLL` | 519,168 | not hashed | Multiplayer/networking helper `[UNKNOWN]` role |
| `patchw32.dll` | 185,344 | not hashed | Patch helper `[UNKNOWN]` role |
| `SECDRV.SYS` | 12,400 | not hashed | Legacy SafeDisc driver; not installed by this repo `[SOURCED]` |

### 3.2 Configuration files (verbatim)

| File | Content | Meaning |
|---|---|---|
| `d3d8.cfg` | `[gentool76]` / `pitch=37` | GenTool 7.6 config `[VERIFIED]` |
| `generals.lcf` | `RUN = . game.dat` + SKU registry key | Launcher config `[VERIFIED]` |
| `launcher/launch.txt` | `..\Generals.exe` | Stub target `[VERIFIED]` |
| `launcher/commandline.txt` | `-win` | Game launched windowed via stub `[VERIFIED]` + `[INFERRED]` |
| `launcher/shellexecute.txt` | `0` | Stub flag `[VERIFIED]` |
| `launcher/Generals.dat` | `dummy file for gameranger validation` | Stub marker `[VERIFIED]` |

## 4. Verification gaps

- `.bak` files were not hashed; their exact provenance (patch vs. backup) is `[INFERRED]`.
- `P2XDLL.DLL`, `patchw32.dll`, `DrvMgt.dll`, `langdata.dat`, `patchget.dat` roles are `[UNKNOWN]`.
- No baseline runtime measurements (FPS, frame time, load time) have been taken. That is P1.

## 5. Host hardware (target machine)

| Item | Value | Evidence |
|---|---|---|
| Model | ASUS TUF Gaming F15 FX506LI | `[VERIFIED]` `Win32_ComputerSystem` |
| CPU | Intel Core i5-10300H, 4 cores / 8 threads, 2.50 GHz base | `[VERIFIED]` |
| RAM | 24 GB (8 GB + 16 GB, 3200 MT/s) | `[VERIFIED]` `Win32_PhysicalMemory` |
| GPU 0 | NVIDIA GeForce GTX 1650 Ti, driver 32.0.15.8088 | `[VERIFIED]` |
| GPU 1 | Intel UHD Graphics, driver 26.20.100.7985 | `[VERIFIED]` |
| Display | 1920×1080 @ 144 Hz, driven by the Intel iGPU | `[VERIFIED]` |
| Free disk (C:) | ~134 GB at setup time | `[VERIFIED]` |

Hybrid graphics and the 30 FPS engine cap are central to the performance work (ISSUE-0006,
ISSUE-0007).

## 6. Engine source (new in P1)

| Item | Value | Evidence |
|---|---|---|
| Official release | `electronicarts/CnC_Generals_Zero_Hour`, GPLv3, archived | `[SOURCED]` |
| Working fork | `TheSuperHackers/GeneralsGameCode`, C++20/VS2022, CMake | `[SOURCED]` |
| Local clone | `vendor/GeneralsGameCode`, 57 MB, commit `0ff1220caf8dbcf254e4ad63ea8e907f22089624` | `[VERIFIED]` |
| Build prerequisites | VS2022 Community 14.43 with ATL; CMake 3.31; CMake fetches pinned deps | `[VERIFIED]` |
| Build result | `z_generals` → `generalszh.exe`, `BUILD_EXIT=0`; `engine/README.md` | `[VERIFIED]` |
| Rebuilt exe hash | `4D6589F6…091B` (DPI + frame logger) | `[VERIFIED]` |
| GenTool with rebuilt exe | crashes with `0xC0000005`; system D3D8 works | `[VERIFIED]` (ISSUE-0008) |

Pinned revision: [`../vendor/sources.lock`](../vendor/sources.lock). Build plan: T-014.

## 7. User configuration and real installation

The user launches a **different copy** than the workspace reference:

| Item | Path / value | Evidence |
|---|---|---|
| Real install | `C:\Program Files (x86)\<vendor>\Command and Conquer - Generals\Command and Conquer Generals Zero Hour` | `[VERIFIED]` shortcuts |
| Executable hash | `F37A4929…D344495B` (same as workspace) | `[VERIFIED]` |
| GenTool config | `[gentool76] pitch=37 window=2` + `[updater]` | `[VERIFIED]` |
| User options | `%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data\options.ini` | `[VERIFIED]` |
| Settings | 1920×1080, **AA 0 + Low detail** (performance profile; original AA 14 / High backed up), shadows/lightmaps reduced | `[VERIFIED]` |
| Skirmish config | map `northamerica`, 50,000 cash, `FPS = 30` | `[VERIFIED]` |
| GPU preference | registry preference was applied then **reverted**; no Generals entry remains | `[VERIFIED]` |
| Config write access | `d3d8.cfg` is **not writable** without elevation | `[VERIFIED]` |

Fullscreen test, window presets, and performance hypotheses are in
[`research/2026-11-14-system-and-engine-triage.md`](research/2026-11-14-system-and-engine-triage.md).

## 8. Working copies

Large game copies live under `game/` and are gitignored:

| Path | Role |
|---|---|
| `game/baseline-pristine/` | Read-only, hashed copy of the complete install (`v104-gentool76-2026-11-14`) |
| `game/work/` | Mutable copy; fullscreen profile applied and verified |

Identity, manifest, and reproduction commands: [`game-copies.md`](game-copies.md).
