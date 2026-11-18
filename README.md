# Zero Hour Engine Optimization

EA has not endorsed and does not support this product.

Targeted C++ engine patches for **Command & Conquer: Generals Zero Hour**, based on the
[TheSuperHackers/GeneralsGameCode](https://github.com/TheSuperHackers/GeneralsGameCode) fork
of EA's released engine source. The project includes a reversible Windows patcher,
benchmark tooling, and records of the performance and compatibility tests.

This project was developed with assistance from OpenAI Codex and OpenCode.
The [`.opencode` session notes](.opencode/continuity.md) document development
decisions, verification results, and remaining work.

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
