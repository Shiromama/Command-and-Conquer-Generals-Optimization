# ISSUE-0008: GenTool proxy crashes the rebuilt engine

- **Status:** Workaround
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-014
- **Related:** [`../../engine/README.md`](../../engine/README.md), ISSUE-0002
- **Environment:** Rebuilt `generalszh.exe`, SHA-256 `F8CAC4C0…0998`; GenTool `d3d8.dll`

## Symptom

The rebuilt engine exits immediately with `0xC0000005` (access violation) and no window when
GenTool’s `d3d8.dll` is present in the game directory. The same exe launches normally when
that DLL is removed/renamed and the system `SysWOW64\d3d8.dll` is used.

## Reproduction / evidence

```
Generals.exe -win -quickstart -xres 1920 -yres 1080
  with GenTool d3d8.dll  → exited, code -1073741819 (0xC0000005), no window
  without GenTool        → running, window created
```

`[VERIFIED]` 2026-11-14.

## Impact

Any rebuilt-engine test must disable GenTool. This also means GenTool’s widescreen/window
presets are unavailable to the rebuilt engine until compatibility is addressed.

## Root cause

`[UNKNOWN]`. Likely GenTool’s executable validation/proxy behavior is incompatible with a
non-retail build; not confirmed at the instruction level.

## Workaround

`tools\stage-engine.ps1` disables GenTool by default (renames `d3d8.dll` to
`d3d8.dll.gentool-disabled`). Use `-WithGenTool` only for retail-exe experiments.

The rebuilt engine’s DPI patch makes the system D3D8 path usable at 1920×1080.

## Resolution / verification

Pending. Options: a compatible D3D8 wrapper (`d3d8to9`/DXVK), a GenTool-compatible build, or
shipping the source build without GenTool. Close only when a rebuilt exe runs with the chosen
wrapper and is verified in-game.

## History

- 2026-11-14 — reproduced with and without GenTool; staging default changed to disable it.
