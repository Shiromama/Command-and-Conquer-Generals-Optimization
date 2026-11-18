# Session continuity

Updated: 2026-11-18
Phase: P2

## Current result

T-092 updated the public README and retired the separate language-driven tooling phase.
The project scope is C++ engine optimization with a standalone patcher. See
[ADR-0021](../docs/decisions/ADR-0021-engine-optimization-scope.md).

Candidate 16 is the latest local package. T-095 removes private build paths and
restricts mod input to prepared data. T-090 added console progress. T-089 separated
the Skirmish Game Speed slider from rendering FPS and verified windowed capture.
See the [candidate 16 manifest](../artifacts/2026-11-18-patcher-alpha/candidate-16/manifest.md).

The patcher now has a GenLauncher-style transactional mod layer:
- mods live under `.zhpatch-alpha/mods/<id>/` with hashed manifests;
- ordered `active.json`; later mods win;
- `.gib`/`.zbig` activate as `.big`; loose folders preserved;
- prepared folder or individual `.big`/`.gib`/`.zbig` file;
- validated paths and link/hardlink rejection;
- `.exe/.dll/.asi`/script/installer files are skipped and never run;
- activation uses link-first/copy-fallback, moves displaced originals to `mod-backups/`, and
  restores exact bytes after the game exits or on `mods restore`/`recover`;
- `play` with active mods waits and restores; base install/uninstall refuses while active;
- `mods inspect` is read-only; `mods add/list/enable/disable/remove/activate/restore/verify`
  are documented in `patcher/README.md`.

The pre-T-082 clean checkpoint is tag `pre-t082-prototype` at `8f65119`.

## Verification

- Debug: 43 cases, 1 production-only skip, exit 0.
- Production: 43 cases, 6 debug-only skips, exit 0.
- Mod cases: import/inspect/activate/restore/remove, `.gib` mapping, `.big` collision,
  ordered switching, compressed archive and installer refusal,
  source-inside-game refusal, activation interruption 3000/3001, restore interruption 4001,
  base-uninstall refusal, exact base hashes.
- Full-copy stock/ShockWave: 1,914/288 hashes restored after package install/uninstall.
- Candidate 9 native 1920x1080 borderless `.big` overlay smoke verified the window, then
  restored and verified the base; candidates 5-8 share the overlay path. Same-binary
  candidate-5 screenshot shows the main menu.
- Extracted corresponding-source offline rebuild exits 0.
- Post-test snapshot diffs: stock 0/1,914, ShockWave 0/288.

## Next work

T-025 remains blocked on ISSUE-0010 (no compatible heavy replay). T-008 instrumentation
survey is the other open next action. Do not describe multiplayer, replays, arbitrary mods,
installer execution or long sessions as certified. Prepare downloaded archives separately
and pass the extracted folder to `mods add --source <folder>`.

## Build/tree state

- Candidate 14 engine source/output are `build/t089-alpha-source` and `build/t089-alpha-release`. Use candidate 13 to uninstall the earlier engine before updating the existing ShockWave copy.

- `build/alpha-engine-source-final` / `build/alpha-engine-release-final` are the production
  engine (4FD3...) used by candidates 9 and 10.
- `build/alpha-engine-source` / `build/alpha-engine-release` contain the fixed development
  fixture (1CEFD1F4...) and must not be packaged.
- `game/alpha-stock-v010b` and `game/alpha-shockwave-v010b` are currently uninstalled and
  match their original snapshots. Their test journals predate the root rename. Fresh disposable copies were used for T-085 verification (ISSUE-0093).
- Original install and `game/baseline-pristine` remain immutable.

## Constraints

Every actual game launch must be announced in commentary first and use native 1920x1080.
Do not modify immutable game references. Do not commit game binaries, archives or extracted
assets. Update docs/state/log/BOARD and run `python tools/check_docs.py` before ending work.
Keep the alpha feature patches separate from `current-engine.patch`.

## Project root rename request (2026-11-18)

T-083 is complete. Git resolves to the requested root and the old directory is absent. Verification is recorded in [ISSUE-0088](../docs/issues/ISSUE-0088-project-folder-rename-locked.md).
