# T-085 overlay repair and release verification

**Date:** 2026-11-18

## Transaction fixes

- [VERIFIED] Overlay planning groups destination names with Windows case-insensitive comparison. Later mods win, an existing file keeps its spelling, and ambiguous duplicates within one mod are rejected. Rollback checks the complete journal and backups before removing a target. A file whose bytes match both the original and overlay stays in place if the backup has yet to be taken or has already been restored. [ISSUE-0089](../issues/ISSUE-0089-mod-overlay-case-alias-data-loss.md)
- [VERIFIED] Direct activation and modded Play validate the installed catalog under the target lock. Verify while an overlay is active validates the mod files, untouched base assets and the backed-up contents of displaced base files. [ISSUE-0090](../issues/ISSUE-0090-direct-overlay-skips-base-catalog.md)
- [VERIFIED] Originals move within the game copy without clearing their read-only attribute. The test covers normal restore and recovery before backup, after backup and after overlay placement. [ISSUE-0091](../issues/ISSUE-0091-mod-restore-drops-readonly.md)

Recovery retains interrupted journal writes for inspection. It refuses an inconsistent legacy journal and leaves any surviving backups available. An original already lost by candidate 9 requires a separate copy or backup.

## Installer workflow

[SOURCED] GenPatcher uses an Apply Fixes action for base-game setup. GenLauncher offers a separate mod library and temporarily applies mod files when launching. ZHModLauncher also stages archives for a single play session and then moves them back. SWR Productions distributes standard installer releases and explicitly labeled no-installer packages for ShockWave. [GenPatcher](https://legi.cc/genpatcher/?lang=en) · [GenLauncher](https://github.com/p0ls3r/GenLauncher) · [ZHModLauncher](https://github.com/forcecore/ZHModLauncher) · [ShockWave releases](https://www.moddb.com/mods/cc-shockwave/downloads)

[VERIFIED] The user chose to keep the existing command-prompt setup. Candidate 10 ships the same `Patcher.cmd` and `Menu.ps1` as candidate 9, with byte-for-byte matches. The package keeps the existing Install, Verify, Uninstall, Recover, Play and Mods menu. The graphical prototype was removed.

## Verification

- [VERIFIED] Offline Cargo debug and release builds exited 0. `python tools/test-patcher.py` ran 37 cases with one skip. The production run with `--production --exe <candidate-10>/zh-patcher.exe` ran 37 cases with five skips. Both suites exited 0. Cases include case collisions with identical payloads, bad or missing backups, drift in the base game, interrupted journal writes, read-only restoration and overlay rollback after a launch failure.
- [VERIFIED] The package ZIP passed CRC checks and `SHA256SUMS.txt` matched all files. Packaged Rust sources and test harness matched the tracked inputs. The packaged engine hash remains `4FD3B817…2F42`.
- [VERIFIED] Candidate 10 completed Inspect, Install, Verify, case-alias overlay activation, Verify with the overlay active, Restore, and Uninstall on fresh disposable copies. Final SHA-256 inventories matched all **1,914 stock** and **288 ShockWave** original files. Both overlays used the copy fallback. The two retained test copies have journals tied to the former project root. [ISSUE-0093](../issues/ISSUE-0093-renamed-workspace-alpha-journal-identity.md) · [Candidate 10 artifact manifest](../../artifacts/2026-11-18-patcher-alpha/candidate-10/manifest.md)
- [VERIFIED] Candidate 10 is a local singleplayer alpha. No native game was launched for T-085. Prior native smoke evidence is recorded in the [T-082 delivery report](2026-11-18-mod-overlay-delivery.md).
