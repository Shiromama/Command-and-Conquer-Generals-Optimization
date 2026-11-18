# T-082 mod-overlay delivery and verification

- **Date:** 2026-11-18
- **Task:** T-082
- **Status:** Complete
- **Decision:** [ADR-0019](../decisions/ADR-0019-community-mod-overlay.md)
- **Research:** [Community mod installation](2026-11-18-community-mod-installation.md)

Candidate 10 supersedes this candidate 9 delivery. [T-085 repair and verification](2026-11-18-overlay-repair.md).

## Summary

The patcher now keeps community mods in a separate library and activates a selected ordered
list only for the duration of a game launch. The exact stock/ShockWave base remains the
compatibility gate; the mod layer never permanently copies files into the game root.

The design follows the important community behavior observed in GenLauncher and
ZHModLauncher: separate mod directories, `.big`/`.gib`/`.zbig` handling, temporary
activation into the game folder, preserved originals, and cleanup after the game exits. It
does not execute third-party installers or download content.

## Architecture

- Library: `.zhpatch-alpha/mods/<id>/files/` plus `manifest.json` (source-relative file
  hashes, skipped executables/scripts, import timestamp).
- Selection: `.zhpatch-alpha/mods/active.json` is an ordered id list. Later mods win on
  duplicate target paths, matching archive overwrite order.
- Activation: `.zhpatch-alpha/mod-journal.json` records every target, its base hash, the
  mod source, and the post-activation hash. Displaced originals move to
  `.zhpatch-alpha/mod-backups/`.
- File handling: `.gib`/`.zbig` activate as `.big`; loose files keep their relative path;
  `.exe`, `.dll`, `.asi`, batch/PowerShell/installer files are skipped and never run.
- Activation prefers a symbolic link and falls back to a durable copy when symlink creation
  is unavailable. The copy path is what the test machine used.
- Restore removes only journal-owned targets, restores the exact backup bytes, removes
  created directories when empty, preserves unexpected changed files as
  `.zhpatch-alpha/recovered-mod-*`, and verifies every original hash.
- Base install/uninstall refuses while an overlay is active. `recover` restores the mod
  layer first and leaves an installed base installed.

## Supported and unsupported

Supported inputs: a folder, one `.big`/`.gib`/`.zbig`, or `.zip`/`.7z`/`.rar` archives that
the system `tar` (bsdtar) can read. Safe extraction lists every archive path first, rejects
absolute/`..`/drive/trailing-dot paths, extracts to a temporary directory outside the game
copy, and rejects links/hardlinks in the result.

Unsupported intentionally: installer `.exe`/`.msi` packages are not executed; the user is
told to extract with 7-Zip and import the folder. There is no repository/download,
dependency resolver, automatic visual compatibility check, or multiplayer/replay
certification. RAR was not tested with a constructed sample because no RAR writer is
installed; the same safe bsdtar path is attempted and the manual fallback is reported.

## Changes

| File | Change |
|---|---|
| `patcher/src/main.rs` | Mod library, archive inspection/extraction, ordered activation, journals, restore/recovery, CLI integration, `play` wait/restore. |
| `patcher/README.md` | Supported formats, commands, activation model, unsupported installer guidance, limitations. |
| `patcher/Menu.ps1` | Mods submenu: list/inspect/add/enable/disable/remove/restore/verify. |
| `tools/test-patcher.py` | 6 mod test methods plus archive/safety/interruption coverage; 30 tests total. |
| `docs/research/2026-11-18-community-mod-installation.md` | GenLauncher/ZHModLauncher/engine `-mod` findings. |
| `docs/decisions/ADR-0019-community-mod-overlay.md` | Accepted design and tradeoffs. |
| `docs/tasks/BOARD.md`, `docs/state.json`, `docs/log.md`, `docs/INDEX.md` | Task, state, verification and report links. |

## Verification

### Automated

- Debug patcher suite: **31 tests, 1 skip** (production-only test), exit 0.
- Production patcher suite: **31 tests, 5 skips** (debug-only interruption tests), exit 0.
- New mod tests cover:
  - inspect without mutation, add, list, enable, activate, verify, restore, remove;
  - `.gib` target mapping and `.big` collision;
  - later-mod-wins switching and restoration;
  - ZIP and 7z imports, single `.big`, unsupported RAR guidance;
  - ZIP traversal rejection, installer refusal, source-inside-game refusal;
  - activation interruption at two checkpoints and restore interruption;
  - base uninstall refusal while active;
  - exact base hashes after restore.
- Packaged candidate 9 production suite: 31 tests, 5 skips, exit 0.
- Full-copy stock/ShockWave install/uninstall: **1,914** and **288** original hashes
  restored.
- Extracted corresponding-source offline patcher rebuild exited 0.

### Native

- Candidate 9 with `smoke-mod` (`ZZ_Smoke.big`, a copy of `WindowZH.big`)
  started at physical **1920x1080** borderless; `tools/measure-game-window.py` verified the
  exact client/outer rectangle. The same patcher/engine binaries under candidate 5 produced
  the main-menu screenshot. The game was closed normally through the process, the packaged
  patcher printed:
  `Mod overlay removed and original files restored` and
  `Game exited; mod overlay removed and base verified`.
- Post-smoke base verify passed; post-test snapshot comparison: stock **0/1914** diffs,
  ShockWave **0/288** diffs.

### Git checkpoint

- `pre-t082-prototype` tag points at `8f65119`, the last clean pre-T-082 prototype commit.

## Package

| Item | Value |
|---|---|
| Final package | `artifacts/2026-11-18-patcher-alpha/candidate-9/zh-patcher-0.1.0-alpha.1/` |
| ZIP SHA256 | `BCF7C2777A190DE5A0649B23949BD282CB594D6B10B580C8FB87799665D44E81` |
| Patcher SHA256 | `C957B664602CB78EBDBCCACEC7932FEEC3A1CAC6DC6055A9C6B6923216E42A9E` |
| Engine SHA256 | `4FD3B817F49F4EBAF87C4F30BB38AC8491BC9AED15AC208DDE3B742882702F42` |
| Corresponding source SHA256 | `E2DF9CC36C914AF5888DCE4371780BA3E94F197B20E9546E3DC3DD46BB5B55FD` |

Candidate 4 remains the exact-base/guard-fix package; candidate 5 added the mod overlay and
passed the same tests; candidate 6 added the package README changelog; candidate 7 corrected the package manifest scope; candidate 8 tightened journal and parent-path safety; candidate 9 rejects corrupt active-mod lists. All of candidate 5-9 share the same patcher/engine binaries.

## Remaining limitations

- No installer execution, download repository, dependency resolution or automatic patch
  discovery. Patches/add-ons are imported as separate ordered mods.
- No universal mod compatibility claim; arbitrary mods/maps/scripts may still fail in the
  engine. The base must be an exact supported snapshot.
- RAR extraction is attempted through the system archive tool but not tested with a
  constructed RAR fixture.
- Multiple active mods use explicit list order; there is no solver for conflicting files.
- Multiplayer, replays, long sessions and arbitrary hardware remain uncertified.
- A killed patcher during an active game leaves the overlay journal; run `mods restore`
  after closing the game or `recover`.
