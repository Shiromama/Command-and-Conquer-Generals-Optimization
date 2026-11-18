# Cleanup results — 2026-11-17 (T-075)

[VERIFIED] Removed **3,260 files / 6.99 GiB** of logical data after the user authorized the T-074 cleanup recommendations. The workspace decreased from approximately **24.36 GiB to 17.38 GiB**. Reported C: free space increased by **7.00 GiB** during execution; other system activity can affect free-space readings.

## Removed and retained

| Category | Removed logical bytes | GiB |
|---|---:|---:|
| Numbered full-resolution PNG sequences in selected undocumented runs | 4,182,192,881 | 3.89 |
| Generated compiler/linker intermediates in engine-ltcg and engine-vs | 3,326,445,592 | 3.10 |

[VERIFIED] Screenshot cleanup was limited to 17 sequences under 16 of the 24 unmanifested/unmentioned T-074 candidate directories. Each sequence retains 16 evenly spaced full-resolution frames, including endpoints, plus any directly referenced frames. JPEG contact sheets show every original frame with its filename. Menu screenshots, GIFs, timing CSVs, logs, configuration and other files remain. All 24 candidate runs received cleanup manifests that explicitly mark missing original experiment provenance as [UNKNOWN].

[VERIFIED] Build cleanup was limited to generated `.lib`, `.obj`, `.pch`, `.iobj`, `.ipdb`, `.tlog`, `.idb`, and `.ilk` files under Core/GeneralsMD in `build/engine-ltcg` and `build/engine-vs`. Executables, PDBs, DLLs, CMake configuration, logs, dependencies and other files remain. The current `build/engine-vs-community` and `build/engines` were excluded entirely.

[VERIFIED] No game copy, original installation, source checkout, tracked source patch or existing documentation was deleted. The metadata snapshots cover **16,477 files** under game/, both original installation folders, vendor/, the current build and historical executable directory: paths, lengths and modification timestamps are unchanged. This is a metadata comparison, not a fresh content hash of all game assets.

## Verification and limits

[VERIFIED] `python artifacts/2026-11-17-cleanup-execution/verify.py` exited 0: all 3,260 planned paths are absent, all **396 retained-file SHA-256 checks match**, and no protected metadata differs. The snapshot after cleanup measured 18,664,035,739 logical bytes (17.38 GiB), before small documentation/manifest updates. Artifact storage is now about **2.96 GiB**, builds **0.87 GiB**.

[VERIFIED] The deletion script resolved every target inside the workspace, checked an explicit allowed area, file size and all ancestor reparse flags, and checked no build/game process was active before removing individual files with PowerShell `Remove-Item -LiteralPath`. No recursive directory deletions occurred.

The deleted original PNGs are **not recoverable from this cleanup**. Their names, lengths and hashes remain in the plan; contact sheets preserve visual context at reduced resolution. Removed compiler products require rebuilding before those secondary configurations can be used again. No rebuild or runtime test was necessary because the current build and runtime copies were excluded.

[VERIFIED] ISSUE-0028 records an initial preflight type-check error that prevented deletion, its correction, and the successful retry. ISSUE-0025 remains Open: 22 pre-existing artifact directories still lack manifests, and historical capture provenance remains incomplete in the cleanup-only manifests. Existing source/entrypoint issue ISSUE-0026 is outside this disk cleanup.

## Evidence and reproduction

[VERIFIED] Evidence directory: `artifacts/2026-11-17-cleanup-execution/` with `manifest.md`, `prepare.py`, `apply.ps1`, `verify.py`, `plan.json`, `result.json`, `protected-before.json`, and `verification.json`. The JSON plan lists every removed file and every hashed retained file. Preparation is one-shot and must not be rerun over already sampled sequences; deletion is likewise a historical execution record, not a general cleanup command.

Commands executed:

```powershell
python artifacts/2026-11-17-cleanup-execution/prepare.py
& './artifacts/2026-11-17-cleanup-execution/apply.ps1'
python artifacts/2026-11-17-cleanup-execution/verify.py
python tools/check_docs.py
```

Documentation validation result is recorded in `docs/log.md` and the evidence manifest. The original [audit](2026-11-17-workspace-cleanup-audit.md) remains the pre-cleanup snapshot.
