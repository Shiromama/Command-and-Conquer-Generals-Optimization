# Guide: fullscreen (borderless) on Zero Hour

> **Status:** verified on an identical copy; user confirmation on the real install pending.
> **Date:** 2026-11-14 · **Issue:** [`../issues/ISSUE-0005-fullscreen-not-working.md`](../issues/ISSUE-0005-fullscreen-not-working.md)
> **Technical detail:** [`../research/2026-11-14-system-and-engine-triage.md`](../research/2026-11-14-system-and-engine-triage.md)

## Why it is windowed

This installation uses GenTool as a `d3d8.dll` proxy. GenTool's `d3d8.cfg` has a window
preset (`window=2`), and the game is launched with `-win`. Only the **FULL** preset makes a
1920×1080 client area with the borders off-screen; the other presets leave a positioned
window. On an identical copy, `window=3` measured a **1920×1080 client rect at (-3,-26)**.

The real install is under `Program Files (x86)`, so the config is not writable without
elevation. Changing the preset in-game may not persist.

## Recommended: GenTool menu (no file edits)

1. Launch the **Windowed** shortcut (its target includes `-win`), not the normal shortcut.
2. In the main menu, press `Insert` to open GenTool.
3. Select **Window Position** and set it to **FULL**.
4. Ensure the game resolution equals the desktop resolution: 1920×1080.
5. Tab out and back once if the taskbar overlaps the window.

If the setting does not survive a restart, GenTool could not write `d3d8.cfg`; use the
elevated method below.

## Alternative: set `window=3` (requires write access)

In the game directory, edit `d3d8.cfg`:

```ini
[gentool76]
pitch=37
window=3
```

Keep any `[updater]` section. If editing fails with access denied:

- run the game/editor **once as administrator**, or
- install/copy the game to a writable folder (e.g., `C:\Games\...`), or
- apply the change from an elevated PowerShell after backing up the file.

Launch with `-win` (Windowed shortcut). Expected result: 1920×1080 borderless, no title bar.

## Fallback: native source build

The GPLv3 source and TheSuperHackers fork include fullscreen crash fixes. Once a local build
exists (T-014), test it with the same scenario; it may remove the GenTool dependency for
fullscreen.

## Verification checklist

- [ ] `GetClientRect` / visual check reports 1920×1080.
- [ ] Alt+Tab out and back does not crash.
- [ ] Restart the game and confirm the preset persisted.
- [ ] Record the exact launch method and `d3d8.cfg` in ISSUE-0005.

## Do not

- Do not replace GenTool's `d3d8.dll`; it is the proxy that provides the preset and widescreen
  support (see ISSUE-0002).
- Do not change `options.ini` resolution while testing fullscreen; keep 1920×1080.
