# Fullscreen source-fix plan — 2026-11-14

- **Status:** planned; not applied (protects the in-progress baseline build)
- **Task:** T-023
- **Related:** [`2026-11-14-engine-digestion.md`](2026-11-14-engine-digestion.md), ['../game-copies.md'](../game-copies.md)

## Why a source fix is still needed

The work-copy fix is borderless windowed fullscreen: a 1920×1080 client area with borders
off-screen. It is not exclusive Direct3D fullscreen, and it still depends on GenTool's window
preset. The source path is the durable, portable fix.

## Verified source facts

| Fact | Location |
|---|---|
| Windowed mode loads D3D8 dynamically | `dx8wrapper.cpp:317-321` |
| Window creation uses `WS_POPUP`; fullscreen ORs `WS_EX_TOPMOST` into the style, not exstyle | `WinMain.cpp:694-758` (line ~714) |
| Fullscreen present params use `D3DPRESENT_RATE_DEFAULT` and `D3DPRESENT_INTERVAL_DEFAULT` | `dx8wrapper.cpp:1011-1012` |
| Fullscreen mode uses `Find_Color_And_Z_Mode`; 32-bit X8R8G8B8 may be promoted to an A8R8G8B8 back buffer | `dx8wrapper.cpp:1072`, `1461-1515` |
| Mode search uses `D3DADAPTER_DEFAULT` / adapter 0, not the selected adapter | `dx8wrapper.cpp:1536-1564`, `1043` |
| Adapter list is enumerated, but default device is adapter 0 | `dx8wrapper.cpp:722-761`, `Set_Render_Device` (`CurRenderDevice=0`) |
| Device-lost path sleeps 200 ms per frame until reset | `dx8wrapper.cpp:1722-1731` |
| `WM_ACTIVATEAPP` no longer resets the device (upstream #28/#801/#846 already present) | `WinMain.cpp:460-487` |

## Proposed patches, in order

1. **Do not promote the fullscreen back buffer to A8R8G8B8.**
   Use the display format (X8R8G8B8) for the fullscreen back buffer, or promote both color and
   back buffer consistently. This addresses the reported “back buffer format mismatch →
   endless ChangeDisplaySettings → no present” failure (upstream PR #3656).
2. **Use the selected adapter everywhere.**
   Replace hardcoded adapter 0 / `D3DADAPTER_DEFAULT` in mode search and `CheckDeviceType`
   calls with `CurRenderDevice`.
3. **Add a portable adapter selector.**
   Expose `-adapter N` (and a config default) rather than a registry preference. Default stays
   adapter 0 for compatibility; on hybrid laptops the launcher/script can pass the discrete
   adapter. Do not auto-pick by vendor without measurement.
4. **Reduce the device-lost stall.**
   Replace the 200 ms sleep with a short wait (e.g. 10–50 ms) or a wait on the device event.
   Test that recovery still works and no busy loop appears.
5. **Fix window style flags.**
   Move `WS_EX_TOPMOST` into the extended style argument instead of OR-ing it into the normal
   style. Cosmetic/robustness fix.
6. **Refresh-rate handling (optional).**
   Prefer the desktop refresh rate for exclusive mode instead of `D3DPRESENT_RATE_DEFAULT`,
   after measuring on 1920×1080@144.

## Test matrix

| Test | Launch | Expected |
|---|---|---|
| Borderless workaround | `-win` + GenTool `window=3` | 1920×1080 client, borders off-screen |
| Exclusive baseline | `-fullscreen` (no `-win`) | Stable mode switch, no reset loop |
| Alt+Tab | exclusive, tab out/in ×3 | No crash, device recovers |
| Hybrid GPU | `-adapter 1` (once added) | Renders on GTX 1650 Ti; overlay confirms |
| Regression | 10-minute skirmish | No new crash log; frame pacing stable |

## Build strategy

1. Build the unmodified source (`build/engine-vs-community`, `z_generals`) as the engine
   baseline; record SHA-256 and test it in an isolated `game/engine-test/` copy.
2. Apply one patch at a time to `vendor/GeneralsGameCode`, rebuild incrementally, and run the
   same test.
3. Export each accepted change as a tracked patch under `engine/patches/` with the upstream
   commit and rationale.
4. Promote only verified patches to `game/work/`; never touch `game/baseline-pristine/`.

## Risks

- Source is built with MSVC 19.43, not VC6; it is not retail-CRC compatible. Single-player
  testing only unless the retail-compatibility path is preserved.
- GenTool may not recognize the rebuilt executable; test with and without its `d3d8.dll`.
- D3D8 exclusive mode on Windows 11 may still be affected by DWM/compat shims.
- Adapter numbering is machine-specific; the option must be explicit and documented.
