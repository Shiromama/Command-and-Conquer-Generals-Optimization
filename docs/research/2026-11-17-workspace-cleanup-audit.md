# Workspace cleanup audit — 2026-11-17 (T-074)

[VERIFIED] The workspace contains **24.36 GiB (26.16 GB decimal)** across 30,077 files at the first scan. This is local workspace size, not Git history bloat. The outer Git index contains 113 paths totalling **1.05 MiB** in their current working-tree versions; `git count-objects -vH` reports **1.51 MiB**, no packs and no garbage. Existing uncommitted source/tool/document changes were present before the audit.

## Measurement and limits

[VERIFIED] Python 3.10 `os.walk(..., followlinks=False)` and `stat().st_size`, including hidden/ignored files; reparse directories excluded (none found). No scan errors. Sizes are logical bytes, not allocated disk space: compression, hardlinks and allocation rounding were not measured. Savings below are candidates/upper bounds, not guaranteed free disk space. The scan predates its own output and subsequent documentation updates.

Evidence: `artifacts/2026-11-17-cleanup-audit/inventory.json`, `details.json`, and `manifest.md`. The second pass searches literal artifact-folder names in `.md`, `.py`, `.ps1` and `.json` files under docs, tools, engine and .opencode. An absent mention does not prove an artifact is unused; indirect references and external consumers are not covered.

## Where the space goes

| Area | GiB | Classification |
|---|---:|---|
| `game/` | 10.3722 | Five baseline/work/test copies; review individually |
| `artifacts/` | 6.8390 | Experiment evidence; largest cleanup opportunity |
| `build/` | 3.9667 | Generated builds and dependency caches |
| `Command and Conquer Generals Zero Hour - Shockwave/` | 1.8218 | Read-only ShockWave reference |
| `Command and Conquer Generals Zero Hour/` | 1.2915 | Protected immutable stock reference |
| `vendor/` | 0.0657 | Source checkout with local edits; retain |
| `.git/` | 0.0015 | Tiny Git database; retain |
| `docs/` | 0.0008 | Tiny project knowledge; retain |
| `engine/` | 0.0002 | Patches needed to reproduce the engine; retain |

All sizes in the table are [VERIFIED] by the saved inventory.

## Cleanup order

1. **Review unmanifested screenshot runs first.** [VERIFIED] Of 83 pre-existing artifact directories, 46 have no top-level `manifest.md`. Twenty-four are also not mentioned by the bounded reference search: **4.76 GiB** combined. This is a review list, not a deletion list. Most artifact bytes are PNGs: **6.52 GiB**; CSVs are only **0.15 GiB**. Preserve raw timing data, run settings, engine identity, representative visual proof and manifests. Review repeated frame sequences for archival or thinning; keep images cited as regression evidence. PNG-to-ZIP savings are [UNKNOWN] and likely limited [INFERRED] because PNG already compresses data.
2. **Retire obsolete build intermediates.** [VERIFIED] `build/engine-ltcg/` is **2.92 GiB**; `build/engine-vs/` is **0.33 GiB**. [INFERRED] They are candidates because the build/stage scripts default to `build/engine-vs-community/` (**0.68 GiB**). The LTCG tree is referenced by EXP-010 and engine identity documentation: retain its executable, hashes, relevant logs and CMake configuration before removing generated intermediates. Preserve `build/engine-vs-community/_deps/`: EXP-010 explicitly reuses it. Full `build/` deletion would force dependency recovery and rebuilding. Keep `build/engines/` (four historical executables, **25.8 MiB**) until its comparison-script uses are retired.
3. **Consider fewer mutable game copies only after preserving their differences.** [VERIFIED] `game/work/` is **1.91 GiB** and `game/shockwave-work/` **2.33 GiB**. [INFERRED] Either could eventually be recreated, but they serve reference/comparison roles and are not junk. `docs/game-copies.md` records a modified ShockWave map-select archive and backups; source installations alone do not reproduce that modification. Archive a verified delta and update scripts/docs before retiring a copy. Keep both active engine test copies for stock and ShockWave validation.
4. **Leave protected references, source, patches and docs intact.** `Command and Conquer Generals Zero Hour/` and `game/baseline-pristine/` must never be changed, moved or deleted under AGENTS.md. The ShockWave source is also documented as read-only. Avoid replacing game assets with hardlinks: subsequent in-place writes could alter shared content [INFERRED].

[INFERRED] The first two groups expose **about 8.02 GiB for review** (4.76 GiB artifacts + 3.26 GiB secondary builds), without retiring any game copy. This is not an approved deletion amount, and preserving evidence/build identities will reduce it.

## Largest unmanifested, unmentioned artifact candidates

| Directory | MiB | Image bytes as percent of directory |
|---|---:|---:|
| `artifacts/shockwave-burst-fixed3/` | 652.4 | 100.0% |
| `artifacts/shockwave-single-debris4/` | 496.4 | 100.0% |
| `artifacts/shockwave-single-debris3/` | 491.0 | 100.0% |
| `artifacts/shockwave-final-debris/` | 456.2 | 100.0% |
| `artifacts/shockwave-burst-fixed2/` | 397.9 | 100.0% |
| `artifacts/shockwave-burst-fixed/` | 300.4 | 100.0% |
| `artifacts/shockwave-single-debris2/` | 274.2 | 100.0% |
| `artifacts/shockwave-single-debris/` | 265.7 | 100.0% |
| `artifacts/shockwave-real-nuke-noskip/` | 252.5 | 100.0% |
| `artifacts/shockwave-debris-closeup/` | 225.5 | 100.0% |
| `artifacts/shockwave-burst-pan/` | 208.8 | 100.0% |
| `artifacts/shockwave-burst-fixed4/` | 188.7 | 100.0% |

[VERIFIED] Paths and sizes above come from `details.json`. All 24 candidates are recoverable from that file using `manifest == false` and `mentioned == false`, excluding the audit's own directory.

## Other cleanup findings

- [VERIFIED] The outer `.gitignore` already excludes game copies, builds, vendor checkout and artifacts. More ignore rules or `git gc` will not address the measured workspace size.
- [VERIFIED] `game/{baseline-pristine,work,engine-test}/GLM/` is about **614 MiB each**. The baseline hash manifest includes GLM files. They are not validated as runtime requirements [UNKNOWN], but the baseline is protected and mutable copies must be reviewed independently; do not blindly delete every GLM directory.
- [VERIFIED] ShockWave work copies contain both `.gib` and materialized `.big` files. Their role is documented in `docs/game-inventory-shockwave.md`; byte identity and deletion safety were not established in this audit. Do not treat matching names or sizes as proof of redundancy.
- [VERIFIED] `AGENTS.md` still describes P1 and a blocked source build, while `docs/state.json` describes P2 and staged built engines. This is navigation drift, not meaningful disk usage. See ISSUE-0026.
- [VERIFIED] Missing artifact manifests violate the existing evidence rules. See ISSUE-0025. No files were deleted, compressed, moved or modified in game/reference/build/vendor trees during this audit.

## Proposed retention practice

[INFERRED] Keep one active build tree plus deliberate, small historical executable snapshots; preserve dependencies needed for offline rebuilding. For each experiment retain CSVs, settings, summaries, hashes and selected visual proof. Put full frame sequences in an explicitly retained archive or remove only a reviewed list after evidence selection. Require a manifest when creating each run; do not infer disposability from age or a name containing `final`, `fixed` or `test`.

## Verification

- `git count-objects -vH`: 747 loose objects, 1.51 MiB, garbage 0.
- Inventory: 30,077 files, 26,155,857,736 logical bytes, 0 errors, 0 skipped reparse directories.
- Documentation validation: `python tools/check_docs.py` (result recorded in the session log and artifact manifest).
