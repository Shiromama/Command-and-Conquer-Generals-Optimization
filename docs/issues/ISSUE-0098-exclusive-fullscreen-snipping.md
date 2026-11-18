# ISSUE-0098: Screen snipping minimizes the game in fullscreen

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-089

## Evidence

The user observed the game minimizing when opening the Windows snipping overlay. [VERIFIED] Candidate 13 defaults to exclusive fullscreen when launched directly, while the patcher's `play` command selects windowed rendering and applies a borderless frame. The reported run's launch mode is [UNKNOWN].

## Resolution / verification

[VERIFIED] Candidate 14 defaults to windowed rendering for direct launches. The patcher's Play path remains borderless, and explicit `-fullscreen` selects exclusive mode. In a native 1920×1080 ShockWave smoke, `Generals.exe` held foreground focus before the Snipping Tool capture overlay opened. `SnippingTool.exe` took focus while the game window remained visible and unminimized. The test opened the capture overlay through its Windows URI. No image was saved. [Native receipt](../../artifacts/2026-11-18-skirmish-speed/native-window.json)
