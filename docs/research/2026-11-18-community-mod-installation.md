# Community mod installation in Command & Conquer: Generals Zero Hour

- **Date:** 2026-11-18
- **Task:** T-082
- **Status:** Complete

## Question

How do Zero Hour players and launchers install and activate mods, and what should a
patcher reproduce without becoming an arbitrary installer runner?

## Sources

- [GenLauncher README](https://github.com/p0ls3r/GenLauncher) and
  [`SymbolicLinkHandler.cs`](https://github.com/p0ls3r/GenLauncher/blob/master/GenLauncherNet/Utility/SymbolicLinkHandler.cs):
  mods live under `GLM/<mod>/<version>`, are selected in the launcher, and are mirrored
  into the game folder with symbolic links. Conflicting original files are renamed with a
  `.GLR` suffix and restored after the game closes. `.exe` and `.dll` are excluded from the
  mirror. `.gib` is used for an inactive `.big`; the link target is `.big`.
- [ZHModLauncher README](https://github.com/forcecore/ZHModLauncher): `Mods/<mod>/*.zbig`
  files are renamed to `.big` and moved into the game folder at launch, then moved back
  after the game exits. It notes that `-mod` works for a mod with one `.big`, but not for
  every multi-file mod.
- [ModDB Aftermath installation note](https://www.moddb.com/mods/command-conquer-aftermath):
  the common manual instructions are to unzip the downloaded files into the Zero Hour
  folder and start the game. Community tutorials describe three forms: an installer `.exe`,
  a `.big` archive, or loose `Data`/`Maps` folders copied over the game directory.
- Local engine source: `vendor/GeneralsGameCode/Core/GameEngine/Source/Common/CommandLine.cpp`
  `parseMod` accepts `-mod <path>`; a relative path is resolved under the user-data
  directory. `vendor/.../Common/System/BIGFileSystem.cpp` `loadMods` loads one `m_modBIG`
  file or all `*.big` files in `m_modDir` with overwrite enabled. The source does not load
  general loose `Data/` files from `m_modDir`; only a few special paths (cursors, videos)
  consult it.

## Findings

[SOURCED] There is no single community installer format. Manual installs copy archives
and/or loose folders into the game root. Launchers keep the game root clean by activating
files only for the duration of a launch.

[SOURCED] GenLauncher's important semantics are: one library folder per mod/version, an
ordered active selection, temporary links into the game folder, displaced originals
preserved with a suffix, `.gib`/`.zbig` activated as `.big`, and cleanup after the game
exits. It deliberately does not activate `.exe`/`.dll`.

[VERIFIED] The engine's `-mod` path is not sufficient as the only mechanism for broad mod
compatibility: it loads `.big` archives from a file or directory, but not a general loose
`Data/` tree. Community multi-`.big` and loose-folder mods therefore need either a
file-level overlay or direct copying.

[INFERRED] The safest patcher behavior that matches community practice is a transactional
overlay: keep mods separate, activate their data files into the game root at launch,
preserve/replace originals, and restore on exit or recovery. This preserves the exact base
snapshot and avoids executing third-party installers.

## Decision

See ADR-0019. The first implementation supports a mod library, an ordered active list,
`.big`/`.gib`/`.zbig` and loose files, symlink-first activation with copy fallback, skip
`.exe`/`.dll`/`.asi`, and journaled restore/recovery. It does not run `.exe` installers,
does not download mods, and does not certify mod/game compatibility.

## Limits

- No archive extraction (`.zip`, `.rar`, `.7z`) in the first implementation; the user
  extracts or points at the folder/`.big`.
- No automatic download/repository.
- One ordered active list; collisions use later-mod-wins, matching archive overwrite order.
- Multiplayer/replay compatibility remains uncertified.
