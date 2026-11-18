# Zero Hour Patcher 0.1.0-alpha.1

Singleplayer alpha for the cataloged Zero Hour and ShockWave snapshots and compatible Zero Hour copies with local mod data. A compatible copy must have a recognized `Generals.exe`, a recognized `game.dat` when present, `INIZH.big` and `W3DZH.big`, and either system Direct3D or the cataloged GenTool proxy. Other executable builds and graphics proxies need separate validation. Multiplayer, old saves and replays, and individual community mods still need testing.

## Changes in this build

- The skirmish **Game Speed** slider controls the simulation tick rate. The render cap still follows the FPS preference and render-FPS shortcuts.
- Direct game launches use windowed presentation by default so Windows capture overlays can appear over the game. The patcher's Play command uses borderless windowed mode. Use `-fullscreen` only if you want exclusive fullscreen.
- Built-in singleplayer guard-range fix: for human-owned stock units, the guard ring and target acquisition cover the usable automatic weapon range, including long-range variants. There is no toggle. AI, network and replay behavior stay on the legacy path.
- Weapon-fire stability fix: a drawing path could write through empty recoil storage when a unit fired; the engine now rebuilds that storage before indexing it.
- Community mod overlay: import a prepared folder or a `.big`/`.gib`/`.zbig` file, activate one ordered selection, and restore the exact base after the game exits or after recovery.

## Use

Extract the entire package to a writable folder. Double-click `Patcher.cmd`, choose a writable **copy** of your game directory, then choose **Install** or **Uninstall**. Install checks compatibility and verifies the result. Uninstall restores and checks the original managed files. Both choices recover an interrupted operation before proceeding. The menu uses Windows PowerShell 5.1.

The console shows the current operation, periodic file counts during longer scans, and a small progress bar for checked patch or restore paths. Use `--progress` with command-line Install or Uninstall to show the same output.

To update a copy patched by an earlier candidate, use that candidate's **Uninstall** first, then choose **Install** in this package.

The command-line examples below cover advanced operations. Use `zh-patcher.exe play` for the patcher's 1920x1080 borderless launch and temporary community-mod activation. Use this launch for ShockWave so its known archives stay materialized.

From the development workspace, `patcher/Patcher.cmd` uses the packaged release recorded in `docs/state.json`. For a clean ShockWave test in this workspace, select `game/shockwave-patcher`. It is the writable copy prepared from the untouched reference.

## Community mods

An already active data mod can stay in place on a compatible engine build. Install records that copy's runtime inventory and preserves its mod data. The known ShockWave launcher layout retains its cataloged archive handling. For additional mods, the patcher keeps imported packages in a separate library under `.zhpatch-alpha/mods/<id>`.

```powershell
.\zh-patcher.exe mods inspect --source 'D:\Downloads\SomeMod'     # read-only package preview
.\zh-patcher.exe mods add --game-dir 'D:\Games\ZeroHourCopy' --source 'D:\Downloads\SomeMod'
.\zh-patcher.exe mods list --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe mods enable --game-dir 'D:\Games\ZeroHourCopy' --mod SomeMod
.\zh-patcher.exe play --game-dir 'D:\Games\ZeroHourCopy'         # waits, then restores
.\zh-patcher.exe mods restore --game-dir 'D:\Games\ZeroHourCopy' # manual cleanup
```

Supported mod inputs are prepared folders and individual `.big`, `.gib`, or `.zbig` files. Folder structure is preserved. `.gib` and `.zbig` files activate as `.big`. The patcher skips executable, DLL, and script files. A prepared folder can contain multiple `.big` files and loose `Data` or `Maps` trees.

Enable multiple mods in load order by separating ids with commas; later mods win on duplicate paths. Activation preserves displaced game files in a journal and restores them after the game exits or after `mods restore`/`recover`. Keep the patcher window open while a `play --mod` game is running; closing the process leaves the overlay journal for `recover`.

For `.zip`, `.7z`, or `.rar` downloads, extract and review the mod files separately, then point `mods inspect --source` or `mods add --source` at the prepared folder. Pass the same kind of folder for mods distributed as installer packages. Multiplayer and replay mod compatibility remain uncertified.

CLI examples (PowerShell, from the package directory):

```powershell
.\zh-patcher.exe inspect --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe install --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe verify --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe play --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe uninstall --game-dir 'D:\Games\ZeroHourCopy'
.\zh-patcher.exe recover --game-dir 'D:\Games\ZeroHourCopy'
```

Inspect is a read-only preview. Install replaces Generals.exe, backs up/removes the known GenTool d3d8.dll proxy, and creates copies of known ShockWave .gib archives as .big, and backs up/disables three known stock loose scripts to follow the mod launcher. Original .gib archives, global options, registry, saves and mod launchers are untouched. This alpha uses system D3D8; it does not install d3d8to9 or set GPU preferences. Rendering performance can differ from earlier wrapper-based benchmarks.

Backups and the transaction journal live in `.zhpatch-alpha` in the selected game folder. Keep this directory and the matching alpha package. After an interruption, close the game and select Install or Uninstall again to recover and complete that action. Recovery preserves temporary files in the state directory for inspection. Uninstall and recovery refuse changed managed files or damaged backups. Move your changed file to a safe location and put the expected installed or original file back before retrying. Unrelated user files and changed unmanaged assets are preserved. Uninstall retains the journal and backups. Reinstall is supported when the original file set still matches.

Every operation refuses linked paths/hardlinks and running Generals/Zero Hour or known ShockWave launchers. No automatic elevation, downloads or telemetry. Checksums detect accidental package damage; this local alpha is unsigned, so checksums do not establish publisher authenticity.

## Source and build

The accompanying corresponding-source archive contains the patcher, offline Rust dependency sources, prepared engine source, source provenance and build scripts. Rust 1.82, Visual Studio 2022 Community with C++/ATL, CMake and Windows SDK are required to rebuild. See SOURCE-BUILD.md in that archive. Engine import/runtime dependencies already owned with the game are not redistributed. Public redistribution is outside this local alpha release's validation scope. See NOTICES.txt and LICENSE files.

The prepared engine disables diagnostic environment reads and excludes the synthetic pathfinding harness. Stable Heap remains the singleplayer default; network/replay force List internally, without compatibility certification. No shadow-map renderer is included. Shipping patcher builds exclude debug fault injection.
