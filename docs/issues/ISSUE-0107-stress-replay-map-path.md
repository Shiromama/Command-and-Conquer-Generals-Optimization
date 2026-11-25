# ISSUE-0107: Stress test replay cannot find Last Stand

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-19
- **Task:** T-025
- **Related:** [ISSUE-0010](ISSUE-0010-heavy-replay-unavailable.md)

## Symptom

The supplied screenshot shows “MAP NOT FOUND” when opening `stress test replay.rep`.

## Evidence

[VERIFIED] The replay header records ShockWave 1.201, `userdata/maps/last stand`, size 119440 bytes and map checksum `B44EACE8`. Applying the engine's rotate-and-add checksum to the local `Maps/LastStand/Last Stand/Last Stand.map` yields the same size and checksum. The canonical path `Maps/Last Stand/Last Stand.map` was absent. The separate map named `The Last Stand` has a different size and checksum.

## Resolution / verification

[VERIFIED] Copied `Last Stand.map`, `Last Stand.tga`, and `Map.str` into the new user-data folder `Maps/Last Stand`. Source and destination hashes match for all three files. The map SHA-256 is `20BAD83411A5FCA3D76F2C5EA8338ACB6196A32E05BC0E5C01E44CE6B365ED41`. The replay and the nested source folder were preserved.

[VERIFIED] `tools/launch-game.ps1 -GameDir game/shockwave-patcher -Mode windowed -Width 1280 -Height 720 -ExtraArgs @('-loadreplay','"stress test replay.rep"')` opened the battlefield and displayed one human and seven Hard Army slots. The simulation reported a separate sync mismatch tracked in [ISSUE-0108](ISSUE-0108-last-stand-replay-sync.md).
