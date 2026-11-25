# ISSUE-0005: Game does not run fullscreen on the target laptop

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-012
- **Related:** [`../game-copies.md`](../game-copies.md), [`../research/2026-11-14-system-and-engine-triage.md`](../research/2026-11-14-system-and-engine-triage.md), ISSUE-0002
- **Environment:** ASUS TUF F15 FX506LI; Intel UHD + GTX 1650 Ti; 1920×1080@144; Windows 11 26200

## Symptom

Reported by the user from normal play: the game cannot be run fullscreen. The installation
launches in a window instead of covering the display.

## Reproduction / evidence

- The real install is `C:\Program Files (x86)\<vendor>\...\Command and Conquer Generals Zero Hour`.
- Its `d3d8.cfg` (GenTool config) contains `window=2`; GenTool's window presets are
  CORNER / CENTER / TOP / FULL, and only FULL is intended as borderless fullscreen.
  `[VERIFIED]` config text; mapping `[SOURCED]` GenTool docs.
- Desktop shortcut `... Zero Hour Windowed.lnk` passes `-win`; the normal shortcut does not.
  `[VERIFIED]`
- Controlled test on an identical hardlinked copy (workspace install) at 1920×1080:
  | `window=` | Window rect | Client rect | Position |
  |---:|---|---|---|
  | 2 | 1926×1109 | n/a | (-195, -26) |
  | 3 | 1926×1109 | **1920×1080** | (-3, -26) |

  With `window=3` the client area exactly matches the desktop and the borders/title bar sit
  off-screen: borderless fullscreen. `[VERIFIED]`
- Writing `d3d8.cfg` in the Program Files install fails with `UnauthorizedAccessException`
  for the current non-elevated user. `[VERIFIED]`
- `options.ini` already uses `Resolution = 1920 1080`. `[VERIFIED]`

## Impact

Fullscreen play is unavailable; the user must run windowed. Borderless mode is also the
recommended mitigation for the engine's known fullscreen Alt+Tab crashes.

## Root cause

Primary: GenTool is configured with a non-FULL window preset (`window=2`), and the game is
launched with `-win`, so it stays a positioned window. Secondary: the install sits under
`Program Files (x86)`, so GenTool cannot persist config changes without elevation; changing
the preset in-game may silently fail to save.

## Workaround

1. Launch the **Windowed** shortcut (`-win`).
2. Press `Insert` in game, select **Window Position → FULL**.
3. Keep game resolution equal to desktop resolution (1920×1080).
4. If the setting does not persist, run the game once as administrator, or set
   `window=3` under `[gentool76]` in `d3d8.cfg` with elevation.

A source build (T-014) may remove the need for GenTool's window hack entirely.

## Resolution / verification

**Fixed on the work copy** (`game/work/`), with the source install and baseline untouched.

The `fullscreen` profile sets GenTool `window=3` and disables map auto-downloads. Launch:

```powershell
tools\launch-game.ps1 -Mode borderless -QuickStart
# -> Generals.exe -win -xres 1920 -yres 1080 -quickstart
```

Measured after 20 s on 2026-11-14:

| Field | Value |
|---|---|
| Window | `-3,-26`, `1926x1109` |
| **Client area** | **`1920x1080`** |
| Style | `0x94C80000` |
| Documents config | unchanged (hashes/timestamps) |

The baseline keeps the original `window=2`; the source install was not modified. A source
build (T-014/T-023) can remove the GenTool dependency.

## History

- 2026-11-14 — reproduced and measured window presets on an identical copy; write access
  blocker identified; workaround documented.
- 2026-11-14 — baseline/work copies created; fullscreen profile applied and verified on the
  work copy (1920×1080 client area); baseline and source install untouched.
