# System, fullscreen, and performance triage — 2026-11-14

- **Date:** 2026-11-14
- **Author/agent:** lead
- **Task:** T-012, T-013, T-014, T-015
- **Status:** Draft

## Question

Why can't the game run fullscreen, and where does the performance go when entity counts rise?
What is the most effective way to optimize further (including the proposed Rust rewrite)?

## Answer (short)

- Fullscreen: the real install's GenTool config uses `window=2` (not the FULL preset), and the
  install is in `Program Files (x86)`, so config changes need elevation. On an identical copy,
  `window=3` produces a true borderless 1920×1080 client area. `[VERIFIED]`
- Performance: not yet measured. The host is an i5-10300H with hybrid Intel/NVIDIA graphics
  and the game previously had **no** high-performance GPU preference; one is now applied.
  Settings are high (5000 particles, high LOD, AA 14) on a 30 FPS-capped, CPU-bound engine.
  `[VERIFIED]` config/hardware; bottleneck `[UNKNOWN]`.
- Strategy: do **not** rewrite from scratch. EA released the GPLv3 source in 2025, and an
  active C++20 fork builds with the installed VS2022/CMake. Use that as the base and add Rust
  tooling/isolated modules where measurements justify it (ADR-0005). `[SOURCED]`

## Method

Read-only inspection of the installed game, user configuration, registry, and hardware;
web research of GenTool/community documentation and the source release; one controlled launch
test on a hardlinked copy of the workspace installation with two GenTool window presets.

## Evidence

| Claim | Label | Where verified |
|---|---|---|
| Host: ASUS TUF F15 FX506LI, i5-10300H 4C/8T, 24 GB, GTX 1650 Ti + Intel UHD | `[VERIFIED]` | CIM queries in this session |
| Display: 1920×1080 @ 144 Hz on Intel UHD | `[VERIFIED]` | `Win32_VideoController` |
| Real install is under `Program Files (x86)\<vendor>\...`, exe hash `F37A…495B` | `[VERIFIED]` | file hash; desktop shortcuts |
| Workspace copy is byte-identical for `Generals.exe`/`d3d8.dll` | `[VERIFIED]` | SHA-256 |
| Real `d3d8.cfg`: `[gentool76] window=2`; workspace default has no `window` | `[VERIFIED]` | file reads |
| `options.ini`: 1920×1080, High LOD, 5000 particles, AA 14, shadows on | `[VERIFIED]` | file read |
| `Skirmish.ini`: `FPS = 30`, map `northamerica` | `[VERIFIED]` | file read |
| No GPU preference entry for the game before the change | `[VERIFIED]` | `reg query UserGpuPreferences` |
| `window=3` client rect = 1920×1080 at (-3,-26); `window=2` = 1926×1109 at (-195,-26) | `[VERIFIED]` | hardlink-copy launch test, `GetWindowRect`/`GetClientRect` |
| Config file in Program Files not writable by current user | `[VERIFIED]` | `Set-Content` → access denied |
| GenTool presets are CORNER/CENTER/TOP/FULL; FULL + `-win` = borderless fullscreen | `[SOURCED]` | [GenTool docs](https://www.gamereplays.org/cnczerohour/portals.php?name=gentool&show=index&tab=8563389) |
| Engine has a 30 FPS cap; GenTool can raise it but game speed follows unless logic is decoupled | `[SOURCED]` | [PCGamingWiki](https://www.pcgamingwiki.com/wiki/Command_%26_Conquer:_Generals) |
| EA released Zero Hour source under GPLv3 in 2025 | `[SOURCED]` | [electronicarts/CnC_Generals_Zero_Hour](https://github.com/electronicarts/CnC_Generals_Zero_Hour) |
| TheSuperHackers fork is C++20/VS2022 with CMake, Tracy profiling, high-FPS/fullscreen fixes | `[SOURCED]` | [repo](https://github.com/TheSuperHackers/GeneralsGameCode), local clone @ `0ff1220` |
| VS2022 Community 17.13.2 + CMake 3.31.2 installed; 134 GB free | `[VERIFIED]` | `vswhere`, `cmake --version` |

## Details

### 1. Runtime installations

| Copy | Path | Notes |
|---|---|---|
| Real (launched) | `C:\Program Files (x86)\<vendor>\...\Zero Hour` | Extra mod BIGs, `modded.exe`, GenTool `window=2`, read-only config |
| Backup | `C:\Command and Conquer - Generals backup\...\Zero Hour` | Same exe/d3d8 hashes; writable |
| Workspace reference | `Command and Conquer Generals Zero Hour\` | Subset of the real install; default GenTool config |

All `Generals.exe` copies share SHA-256 `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B`.
`[VERIFIED]`

### 2. Fullscreen test

Hardlinked copy in `artifacts/2026-11-14-fullscreen-test/zh` (no extra 1.3 GB used), launched as:

```
generals.exe -win -quickstart -xres 1920 -yres 1080
```

| `window` | Window rect | Client rect | Position | Interpretation |
|---:|---|---|---|---|
| 2 | 1926×1109 | (not captured) | (-195, -26) | non-FULL preset |
| 3 | 1926×1109 | **1920×1080** | (-3, -26) | borderless fullscreen |

The game process stayed alive in both runs and wrote no new crash report (latest crash log is
from 2026-04-14). `[VERIFIED]`

### 3. Why the config change is not applied to the real install

`Set-Content` on `...\Program Files (x86)\...\d3d8.cfg` returned
`UnauthorizedAccessException`. Applying the fix requires elevation, an in-game GenTool change
run elevated, or a writable installation copy. No elevation was performed.

### 4. Performance hypotheses (ranked, unproven)

1. **Wrong GPU.** Old D3D8 app with no preference on an Optimus laptop → Intel UHD. A
   per-PC registry preference was tried and then reverted to keep fixes portable; source-level
   adapter selection is now the intended fix (T-023).
2. **CPU simulation at high unit counts.** 4C/8T, single-threaded logic; likely dominant late
   game.
3. **Rendering effects.** 5000 particles, shadow volumes/decals, high LOD, AA 14 at 1080p.
4. **30 FPS cap / pacing.** Drops below 30 are visible; raising FPS without decoupling logic
   changes game speed.

### 5. Source-based plan

- Base: `vendor/GeneralsGameCode` @ `0ff1220` (GPLv3, C++20, CMake).
- Build preset `win32` needs Ninja Multi-Config + vcpkg dependencies; Visual Studio generator
  is an alternative.
- Upstream already has Tracy profiling (`win32-profile`) and merged render/logic decoupling.
- Rust scope: launcher/config doctor, INI/asset/replay tooling, and only measured, isolated
  engine modules (ADR-0005).

## Limitations / open questions

- No frame-time measurement has been taken; the bottleneck is still a hypothesis.
- The game's actual GPU adapter was not observed at runtime (no overlay/counter).
- `window=2`'s exact preset (TOP vs CORNER) is inferred from public docs, not the binary.
- The April 2026 crash (`EIP 0x652319D9`) could not be attributed to a module.
- Source build dependencies (vcpkg, DirectX SDK, Miles/Bink) have not been resolved yet.

## Artifacts

- `artifacts/2026-11-14-work-fullscreen/result.json` — work-copy fullscreen verification
  (client 1920×1080); the earlier hardlink test folder was removed after its result was
  recorded here.
- `docs/manifests/game-baseline-v104-gentool76-2026-11-14.sha256` — immutable baseline
  identity for all future measurements.
- The registry preference backup was removed when the preference was reverted; no Generals
  entry remains in `UserGpuPreferences`.

Superseded/expanded by [`2026-11-14-engine-digestion.md`](2026-11-14-engine-digestion.md).
- `artifacts/2026-11-14-fullscreen-test/d3d8.cfg.before` — real install config backup.
