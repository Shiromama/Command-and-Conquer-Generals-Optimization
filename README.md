# Zero Hour Engine Optimization

EA has not endorsed and does not support this product.

Targeted C++ engine patches for **Command & Conquer: Generals Zero Hour**, based on the
[TheSuperHackers/GeneralsGameCode](https://github.com/TheSuperHackers/GeneralsGameCode) fork
of EA's released engine source. The project includes a reversible Windows patcher,
benchmark tooling, and records of the performance and compatibility tests.

This project was developed with assistance from Codex and OpenCode.
The [`.opencode` session notes](.opencode/continuity.md) document development
decisions, verification results, and remaining work.

## Quick start

**Download.** Check [Releases](https://github.com/Shiromama/Command-and-Conquer-Generals-Optimization/releases)
for the Windows patcher ZIP. The prebuilt download is pending. To experiment
with the source today, see the [engine build guide](engine/README.md).

Once you have the patcher ZIP:

1. Close Zero Hour and any mod launcher. Make a writable copy of your compatible
   Zero Hour installation.
2. Extract the entire patcher ZIP into a separate folder. Open `Patcher.cmd`,
   select your game copy, and choose **Install**.
3. Open `Generals.exe` from the patched copy and start a singleplayer skirmish.
   For ShockWave, open PowerShell in the patcher folder and run this command
   with the path to your game copy:

   ```powershell
   .\zh-patcher.exe play --game-dir 'C:\Games\ZeroHourCopy'
   ```

4. To restore the original files, close the game, open `Patcher.cmd`, select the
   same copy, and choose **Uninstall**. Keep the `.zhpatch-alpha` backup folder
   and the matching patcher package until you're done testing.

## What changed

- [VERIFIED] Engine work includes faster debris collision candidate filtering, a corrected
  guard range for human-owned stock units in singleplayer, and separate skirmish simulation
  speed and rendering FPS controls. [Debris validation](docs/experiments/EXP-011-broadphase-correctness.md) ·
  [Guard range experiment](docs/experiments/EXP-030-guard-range-runtime.md) ·
  [Skirmish speed verification](docs/log.md#2026-11-18---t-089-independent-skirmish-speed-and-windowed-capture)
- [VERIFIED] Stock Zero Hour and ShockWave were exercised in native 1920×1080 smoke tests.
  Install and uninstall were verified against cataloged files on disposable copies.
  [Alpha verification](docs/log.md#2026-11-18---t-080-alpha-candidate-verified-t-081-added-before-finalization)

## Compatibility

This is a **singleplayer alpha**. Use a writable copy of your own compatible Windows
installation of Zero Hour. The [patcher guide](patcher/README.md) lists the recognized
game files and supported runtime configurations. Multiplayer, existing saves, replays,
and compatibility with individual community mods still need validation.

## Source and build

- [Engine build instructions](engine/README.md) and [patch layout](engine/patches/README.md)
- [Patcher usage and recovery](patcher/README.md)
- [Performance experiments](docs/experiments/EXP-013-original-vs-optimized.md) and
  [documentation index](docs/INDEX.md)
- [Current project status](docs/state.json) and [contributor instructions](AGENTS.md)
- [Licenses and upstream attribution](LICENSE.md)

Verify the documentation with `python tools/check_docs.py`.
