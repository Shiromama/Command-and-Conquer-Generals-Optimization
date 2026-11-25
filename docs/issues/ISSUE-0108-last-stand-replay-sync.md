# ISSUE-0108: Last Stand replay diverges during playback

- **Status:** Workaround
- **Severity:** Medium
- **Date found:** 2026-11-19
- **Task:** T-025
- **Related:** [ISSUE-0107](ISSUE-0107-stress-replay-map-path.md), [ISSUE-0010](ISSUE-0010-heavy-replay-unavailable.md)

## Symptom

[VERIFIED] The recovered 52,902-frame ShockWave 1.201 replay opens and the patched engine stops the strict replay check on a simulation CRC mismatch.

## Reproduction and evidence

[VERIFIED] The replay header carries build time `Nov 18 2026 18:25:20`, present in `game/shockwave-patcher/Generals.exe` (SHA-256 `76099735FEDB1331E88700C257FC7A3A572518DADCCD24C7FC9E9FC2C5BEFA17`). From that game directory, `Generals.exe -headless -replay "stress test replay.rep"` exits 1 with `CRC Mismatch in Frame 0`.

[VERIFIED] The header's executable and AI-script checksum is `E4635A93`. Applying the engine's rotate-and-add checksum to the executable, little-endian version `0x00010004`, and both archived ShockWave `.scb` scripts produces that value. Using both loose scripts produces `29B8217C`. An isolated `game/last-stand-replay` copy omits `Data/Scripts/{MultiplayerScripts.scb,SkirmishScripts.scb,Scripts.ini}`. The same strict command in that copy exits 1 at frame 4500 (2:30 of a recorded 29:23). Raw logs are in `artifacts/2026-11-19-last-stand-replay/`.

## Impact

[UNKNOWN] Whether the remaining mismatch changes the late-game workload enough to affect the reported slowdown. Late-game timings from a run with sync checks bypassed require corroboration against a fresh skirmish or a verified replay.

## Resolution / verification

[UNKNOWN] Root cause of the frame-4500 mismatch. The pathfinding queue and human guard-range policies differ between live skirmishes and replay playback in this build. The failed check does not establish that either caused the divergence or the FPS drop.


## Diagnostic workaround

[VERIFIED] The profiling build uses the same skirmish guard and pathfinding
policies as the recording when both diagnostic switches are selected. The
strict headless replay reaches frame 10,851. A separate graphical run reproduces
7 FPS without the sync bypass. This isolates a usable workload for profiling.
The original playback behavior remains open. See [the profiling report](../research/2026-11-19-last-stand-slowdown.md).
