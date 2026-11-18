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

**Download.** [Windows patcher ZIP](https://github.com/Shiromama/Command-and-Conquer-Generals-Optimization/releases/download/v0.1.0-alpha.1/zh-patcher-0.1.0-alpha.1.zip)
· [Release notes and checksum](https://github.com/Shiromama/Command-and-Conquer-Generals-Optimization/releases/tag/v0.1.0-alpha.1).
To build from source, see the [engine build guide](engine/README.md).

Once you have the patcher ZIP:

1. Close Zero Hour and any mod launcher. Make a writable copy of your compatible
   Zero Hour installation.
2. Extract the entire patcher ZIP into a separate folder. Open `Patcher.cmd`,
   select your game copy, and choose **Install**.
3. Open `Generals.exe` from the patched copy and start a singleplayer skirmish.
4. To restore the original files, close the game, open `Patcher.cmd`, select the
   same copy, and choose **Uninstall**.

## Performance findings

[VERIFIED] In controlled 1920×1080 benchmarks on one laptop, switching from
**8× anti-aliasing and High detail** to **AA off and Low detail** reduced frame
times in both test scenes. Each comparison used the same rebuilt engine with
the render cap disabled on both sides. Stock used system Direct3D 8. ShockWave
used d3d8to9 on the GTX 1650 Ti. [Benchmark setup and results](docs/experiments/EXP-013-original-vs-optimized.md#5-uncapped-re-run-t-058--the-definitive-numbers) ·
[Test hardware](docs/environment.md)

| Test scene | Median frame time | p95 frame time |
|---|---:|---:|
| Stock Zero Hour, 1,000 tanks (3 alternating pairs) | 21.86 → 6.47 ms | 27.12 → 8.26 ms |
| ShockWave, five 1,000-unit spawn and nuke cycles (2 alternating pairs) | 8.62 → 4.33 ms | 177.37 → 61.59 ms |

Lower is better. The p95 is the frame time that 95% of frames finish within.
These figures describe the settings change on the benchmark build. Real late-game
replay validation is still open. [Replay validation blocker](docs/issues/ISSUE-0010-heavy-replay-unavailable.md)

### What profiling showed

- **Mass destruction caused large simulation spikes.** [VERIFIED] Frame traces
  identified bulk spawning, first AI and physics ticks, and destruction as major
  costs in the ShockWave stress scene. In a separate three-pair A/B test, changing
  how the engine removes update modules reduced the average peak time spent in
  the destruction phase from 92.91 to 8.15 ms. Whole-frame p95 moved from
  50.39 to 48.23 ms. [Frame attribution](docs/experiments/EXP-009-frame-attribution.md) ·
  [Destruction A/B test](docs/experiments/EXP-017-destroy-path.md)
- **Debris collision filtering needed a correctness check.** [VERIFIED] Testing
  tall geometry exposed missed collisions in the first version. With the corrected
  bounds, the probe recorded zero missed collisions over 3,667 frames and the
  filter reduced the candidate count by about 81% in the final test.
  [Collision validation](docs/experiments/EXP-011-broadphase-correctness.md)
- **Some experiments were rolled back.** [VERIFIED] Distance culling became opt-in
  again after it hid on-screen units. The partition shortcut was removed after it
  made debris invisible. The shadow-map
  prototype averaged 14% higher median frame times than stencil shadows across
  three dense-scene pairs. [Distance culling](docs/experiments/EXP-023-draw-distance-default.md) ·
  [Debris visibility](docs/experiments/EXP-024-debris-visible.md) ·
  [Shadow renderer A/B test](docs/experiments/EXP-029-shadow-map-rejected.md)

## What changed

- **Alt+Tab crash workaround.** [VERIFIED] The retail game crashed during
  repeated focus switches in exclusive fullscreen. The patched game now opens
  windowed by default, and `zh-patcher.exe play` opens it borderless. In a
  1920×1080 ShockWave skirmish, the rebuilt engine with d3d8to9 completed 120
  focus-switch cycles in borderless mode without crashing.
  [Alt+Tab stress test](docs/issues/ISSUE-0011-shockwave-alt-tab-null-texture-crash.md#resolution--verification) ·
  [Launch modes](patcher/README.md#changes-in-this-build)
- [VERIFIED] Engine work includes faster debris collision candidate filtering, a corrected
  guard range for human-owned stock units in singleplayer, and separate skirmish simulation
  speed and rendering FPS controls. [Debris validation](docs/experiments/EXP-011-broadphase-correctness.md) ·
  [Guard range experiment](docs/experiments/EXP-030-guard-range-runtime.md) ·
  [Skirmish speed verification](docs/log.md#2026-11-18---t-089-independent-skirmish-speed-and-windowed-capture)
- [VERIFIED] Stock Zero Hour and ShockWave reached their main menus in native
  1920×1080 smoke tests. The published pre-release passed separate install,
  verify, and uninstall checks on disposable copies, restoring all 1,914 stock
  and 288 ShockWave original files. [Launch smoke tests](docs/log.md#2026-11-18---t-080-alpha-candidate-verified-t-081-added-before-finalization) ·
  [Pre-release verification](docs/log.md#2026-11-18---t-102-publish-the-windows-singleplayer-pre-release)

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
