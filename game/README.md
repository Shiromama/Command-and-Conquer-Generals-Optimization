# Game copies

This directory holds **local, gitignored** copies of the game. The tracked documentation is
[`../docs/game-copies.md`](../docs/game-copies.md).

| Path | Role | Writable? |
|---|---|---|
| `baseline-pristine/` | Exact copy of the source installation; never edited | No (read-only attribute) |
| `work/` | Mutable copy where fixes are applied and tested | Yes |
| `engine-test/` | Rebuilt source engine; retail exe backed up; GenTool disabled | Yes |
| `profiles/` | Small, portable config overlays (e.g. fullscreen) | Yes (tracked) |
| `copies.json` | Machine-local record of source path, label, hashes | Yes (ignored) |

## Rules

1. Never edit `baseline-pristine/`. It is the baseline for measurements and hash checks.
2. Apply all changes to `work/` only.
3. Regenerate the baseline only by re-running `tools/prepare-game-copies.ps1` with a new label.
4. The game still reads user settings from `%USERPROFILE%\Documents\...`; that is outside this
   directory and must be backed up/snapshotted separately for experiments.
5. Do not commit the copies. Keep the hash manifest in `docs/manifests/`.
