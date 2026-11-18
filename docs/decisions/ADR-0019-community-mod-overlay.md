# ADR-0019: Community-compatible transactional mod overlay

- **Status:** Accepted
- **Date:** 2026-11-18
- **Task:** T-082

## Context

[SOURCED] Zero Hour mods are distributed as `.big` archives, `.gib`/`.zbig` disabled
archives, loose `Data`/`Maps` folders, or third-party `.exe` installers. GenLauncher keeps
mods in its own `GLM` library, mirrors data files into the game folder with symbolic links
for the duration of a launch, preserves conflicting originals, and removes the links when
the game exits. ZHModLauncher uses a `Mods/<mod>/*.zbig` library and moves `.big` files into
the game folder temporarily. Manual installs often copy the files into the game root and
rely on `!`/`0`/`ZZZ` archive prefixes for load order.

[VERIFIED] The engine `-mod` command accepts a single `.big` or a directory of `.big`
archives and loads them with overwrite enabled. It does not load a general loose `Data/`
tree from the mod directory, so it cannot represent every community mod by itself.

The current patcher only supports exact stock/ShockWave catalogs and refuses changed
runtime files. It must not silently accept arbitrary game files; the base snapshot remains
the compatibility boundary.

## Decision

Add a separate community-mod layer on top of the exact base installation:

- Import a mod from a folder or a single `.big`/`.gib`/`.zbig` into
  `.zhpatch-alpha/mods/<id>/`; never import from a linked source and never execute
  third-party installers.
- Store a hash manifest and an ordered active-mod list. Later mods win on duplicate target
  paths, matching archive overwrite order.
- Activate by creating the target files in the game root: `.gib`/`.zbig` map to `.big`;
  loose files keep their relative path; `.exe`, `.dll` and `.asi` are skipped. Prefer a
  symlink to the mod source; fall back to a durable copy if symlink creation is not
  permitted. Preserve every displaced game file in a journaled backup.
- Launch the installed base engine with the overlay active, then remove the overlay and
  restore every displaced file after the game exits. If the process is interrupted, the
  journal remains `active` and `recover`/`mods restore` restores the base.
- Keep the base install/uninstall journal separate. Refuse base install/uninstall while a
  mod overlay is active; `recover` restores the mod layer first.
- Do not run installers, download content, modify the registry, elevate, or claim mod
  compatibility. Multiplayer, replays and arbitrary mods remain uncertified.

This reproduces the community launcher behavior that matters (separate mod library,
temporary activation, preserved originals, `.big`/`.gib`/`.zbig` handling, cleanup) without
turning the patcher into an arbitrary executable installer.

## Consequences

### Positive

- Multiple mods can share one exact base copy without copying them permanently into the
  game root.
- Activation is reversible and journaled, including interrupted runs.
- Loose `Data`/`Maps` files and multi-`.big` mods work, unlike the engine's `-mod` alone.
- The exact base catalog still proves which game build the mod runs on.

### Negative / risks

- Symlink creation may require Developer Mode or elevation on some systems; the copy
  fallback costs time and disk space.
- Mod files can still be malicious data; hash manifests detect accidental changes, not
  intent. Executables/DLLs are skipped, but no mod is certified.
- Load order is an explicit list; the engine's internal `.big` order is not inferred.
- The overlay temporarily changes the game root; a crashed patcher leaves the journal for
  manual recovery.

### Follow-ups

- Optional `.zip` extraction if a dependency can be pinned offline.
- Visual/native smoke with a non-trivial community mod.
- Per-mod compatibility notes and a repository index, outside this alpha.

## Verification

- Synthetic transaction tests for import, activation, restore, collision, skip rules,
  path traversal, link refusal, interrupted activation and recovery.
- Real-copy activation/restore with the exact stock and ShockWave catalogs, checking all
  base hashes after restore.
- Native 1920x1080 borderless smoke with a temporary `.big` overlay, then exact hash
  restoration.
- Documentation updated with the community findings and limitations.

## Verification result (2026-11-18)

[VERIFIED] The implementation was delivered as T-082. Debug suite: 31 tests / 1
production-only skip; production suite: 31 tests / 5 debug-only skips. The new cases cover
import/inspect/activate/restore/switch/remove, `.big`/`.gib`/`.zbig`, ZIP and 7z extraction,
single-archive imports, ZIP traversal rejection, installer refusal, source-inside-game
refusal, activation/restore interruption, base-uninstall refusal while active, and exact
base restoration after every path. Full-copy stock/ShockWave uninstall restored 1,914/288
hashes. A packaged candidate 9 native 1920x1080 borderless smoke with a valid `.big` overlay
reached the main menu, then restored and verified the base. Details:
[`../research/2026-11-18-mod-overlay-delivery.md`](../research/2026-11-18-mod-overlay-delivery.md).
