# Game copies and baseline identity

> **Status:** verified · **Last verified:** 2026-11-14 · **ADR:** [`decisions/ADR-0006-baseline-work-copies.md`](decisions/ADR-0006-baseline-work-copies.md)
> **Scripts:** [`../tools/prepare-game-copies.ps1`](../tools/prepare-game-copies.ps1), [`../tools/launch-game.ps1`](../tools/launch-game.ps1)

## 1. Labels

| Label | Path | Role | Writable |
|---|---|---|---|
| `v104-gentool76-2026-11-14` | `game/baseline-pristine/` | Exact copy of the complete installation; never edited | **No** (all 1,914 files read-only) |
| `v104-gentool76-2026-11-14` | `game/work/` | Mutable copy where fixes are applied and tested | Yes |
| — | `%USERPROFILE%\Documents\Command and Conquer Generals Zero Hour Data` | Live user settings/saves; outside the copies | Yes (back up before tests) |

Source installation (read-only, untouched):
`C:\Program Files (x86)\R.G. Mechanics\Command and Conquer - Generals\Command and Conquer Generals Zero Hour`

## 2. Baseline identity

| Item | Value |
|---|---|
| Label | `v104-gentool76-2026-11-14` |
| Created | 2026-11-14 22:44 (local) |
| Files | 1,914 |
| Bytes | 2,047,921,400 (1.91 GiB) |
| Manifest | [`manifests/game-baseline-v104-gentool76-2026-11-14.sha256`](manifests/game-baseline-v104-gentool76-2026-11-14.sha256) |
| Verification | `OK: baseline matches manifest (1914 files)` |
| Baseline `d3d8.cfg` SHA-256 | `FE01E44C6A701E42AC8F89495A8D6B52F7243847D10EDB6559FA8FD1AB390357` |
| Work `d3d8.cfg` SHA-256 | `17F36E299D48BBFCD17A9B468C7296DD338FD5CB60EE087A542E9785DF5ED2B7` |

The manifest header records the source path, label, timestamp, and line format. The manifest is
tracked in git; the copies themselves are ignored.

## 3. What differs in the work copy

Only the GenTool configuration was changed, through the tracked `fullscreen` profile:

```ini
[gentool76]
pitch=37
window=3
[updater]
Maps_1v1_ZH.zip=0
Maps_2v2_ZH.zip=0
```

- `window=3` is GenTool's FULL preset; with `-win` it produces a borderless window whose
  client area matches the desktop.
- The `[updater]` zeros prevent GenTool from downloading maps into the work/baseline copy
  during tests. This is a reproducibility choice, not a gameplay fix.
- No game binaries, archives, or other files were changed.

The baseline still has the original `window=2` and `Maps_1v1_ZH.zip=1`.

## 4. Fullscreen verification (work copy)

Launched with:

```powershell
tools\launch-game.ps1 -Mode borderless -QuickStart
# -> Generals.exe -win -xres 1920 -yres 1080 -quickstart
```

Observed after 20 s:

| Field | Value |
|---|---|
| Process title | `Command & Conquer (TM) Generals Zero Hour` |
| Window rect | `-3,-26` `1926x1109` |
| **Client rect** | **`1920x1080`** |
| Style | `0x94C80000` |
| Documents `options.ini` / `Skirmish.ini` / `ReleaseCrashInfo.txt` | unchanged hashes and timestamps |

The game process was terminated after measurement. This matches the earlier identical-copy
test and confirms the FULL preset produces a 1920×1080 client area with borders off-screen.
See [`issues/ISSUE-0005-fullscreen-not-working.md`](issues/ISSUE-0005-fullscreen-not-working.md).

## 5. Engine test copy

`game/engine-test/` is a third copy created from `baseline-pristine` for the rebuilt source
engine. It is not the baseline and not the retail work copy.

| Item | Value |
|---|---|
| Built exe | `Generals.exe` (source build, DPI + frame logger + benchmark harness + distance/shadow culls) |
| Built SHA-256 | `7C3CE0AD24D6E8439E7994C923C838DB1EFF92DCE9944F8546B7D1D2A29ABE21` |
| Retail backup | `Generals.retail.exe` — `F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B` |
| GenTool proxy | disabled (`d3d8.dll.gentool-disabled`); system `SysWOW64\d3d8.dll` is used |
| Record | `game/engine-test/engine.json` |

Why GenTool is disabled: its proxy causes an immediate `0xC0000005` with the rebuilt exe
(ISSUE-0008). The source build works with the system D3D8 DLL.

Reproduce:

```powershell
.\tools\stage-engine.ps1 -BuiltExe build\engine-vs-community\GeneralsMD\Release\generalszh.exe
.\tools\launch-game.ps1 -GameDir game\engine-test -Mode borderless -QuickStart
```

### ShockWave copies and the 2026-11-15 audit

The ShockWave install is a separate source tree (`Command and Conquer Generals Zero Hour - Shockwave`)
with `.gib` archives and the launcher's rename map; the two copies are derived from it, not from
`baseline-pristine`.

| Copy | Role | `Generals.exe` | `d3d8.dll` | Notes |
|---|---|---|---|---|
| `game/shockwave-work` | Retail 1.04 + ShockWave, mutable | retail `F37A4929...495B` | GenTool `BE527618...41F7`; d3d8to9 as `d3d8x.dll` | Fullscreen profile; `.gib` materialised to `.big`; ADR-0009 online path |
| `game/shockwave-engine` | Same data, rebuilt engine | `F606E603...C007A3` (6,753,792 B) | d3d8to9 `122928CF...8AB8` | GenTool disabled (`d3d8.dll.gentool-disabled`); `engine.json` records both hashes |
| `game/engine-test` | Older source build for the pre-ShockWave benchmarks | `7C3CE0AD...ABE21` | system D3D8 (no local `d3d8.dll`) | Not the current engine; keep as a benchmark snapshot |

Audit results (`[VERIFIED]` `artifacts/2026-11-15-copy-audit/copy-diff.md`):

- `game/baseline-pristine`: **1,914/1,914 files unchanged** against the manifest.
- `game/work`: 1,914 files, only `d3d8.cfg` differs (the `fullscreen` profile).
- `game/engine-test`: only the built/retail exe, `d3d8.cfg`, and the expected backup/log/JSON files
  differ from the baseline. The built exe is the older `7C3CE0...` snapshot.
- The ShockWave copies match the ShockWave source except for the documented exe/wrapper/profile
  changes, the materialised `.big` replacements, and the map-select UI archive below.

**Map-select UI archive.** `game/shockwave-work/!Shw_wnd.big` was modified after the copy was made
(`.bak` preserved): four `Window/Menus/*MapSelectMenu.wnd` entries change `LISTBOXDATA = LENGTH:
1200` to 100/200/300. The repacked archive is `C287FAC2...4035` (8,459,572 B); the original is
`26EF0EEA...C643` (8,459,568 B). The same patched archive was copied to `game/shockwave-engine`
(original kept as `!Shw_wnd.big.orig`) so both copies have the same map-select behaviour.
`prepare-shockwave-copy.ps1 -Force` materialises the unpatched original; it would need the
`.bak`/`.orig` restored afterwards. This is a local UI workaround, not part of the engine patch.

## 6. Reproduce on another PC

```powershell
# 1. Point at any complete installation; nothing in it is modified.
.\tools\prepare-game-copies.ps1 `
  -SourceGameDir 'D:\Games\Command and Conquer Generals Zero Hour' `
  -Label 'v104-gentool76-2026-11-14' `
  -Profile fullscreen

# 2. Verify the baseline later.
.\tools\prepare-game-copies.ps1 -Label 'v104-gentool76-2026-11-14' -VerifyOnly

# 3. Launch the mutable copy.
.\tools\launch-game.ps1 -Mode borderless -QuickStart
```

Paths, labels, resolution, and profiles are parameters. No registry keys, hardcoded user
names, or machine-specific GPU settings are used.

## 7. Rules

1. Never write to `game/baseline-pristine/` or the source installation.
2. All changes go to `game/work/` or tracked source patches; record them in the log.
3. Re-baseline only with a new label; do not overwrite an existing manifest.
4. Back up `%USERPROFILE%\Documents\...` before experiments that may write settings/saves.
5. If a test modifies the work copy's config, record the before/after hash.

## 8. Verification

```powershell
.\tools\prepare-game-copies.ps1 -Label 'v104-gentool76-2026-11-14' -VerifyOnly
# OK: baseline matches manifest (1914 files).

(Get-ChildItem game\baseline-pristine -Recurse -File -Force | Where-Object IsReadOnly).Count
# 1914
```

## Patcher-ready ShockWave copy

[VERIFIED] `game/shockwave-patcher/` is a writable copy of the untouched project ShockWave reference. Its 288 file hashes match the recorded `shockwave-before.json` inventory, and candidate 13 Inspect accepted it. The copy has no installation journal. Prefer this target for a clean patcher test and select it manually in the folder picker.
