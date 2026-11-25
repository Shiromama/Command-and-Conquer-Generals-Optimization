# Workspace prune — 2026-11-20 (T-114)

- Status: complete; permanent deletion authorized by the user
- Evidence: [prune manifest](../../artifacts/2026-11-20-workspace-prune/manifest.md)
  and `plan.json`
- Prior audit: [2026-11-17 workspace cleanup](2026-11-17-workspace-cleanup-audit.md)

## Result

[VERIFIED] The workspace was about **56.3 GiB** before this pass and about
**38.5 GiB** after it. The pass removed **19,090,138,009 bytes (17.78 GiB)**
across 15,344 files in seven directories:

| Path | GiB | Files |
|---|---:|---:|
| `build/alpha-engine-release` | 2.82 | 2,748 |
| `build/alpha-engine-release-final` | 2.82 | 2,694 |
| `build/t089-alpha-release` | 2.81 | 2,572 |
| `build/t095-alpha-release` | 2.80 | 2,562 |
| `build/t111-alpha-release` | 2.80 | 2,562 |
| `game/alpha-stock-v010` | 1.92 | 1,918 |
| `game/alpha-shockwave-v010` | 1.82 | 288 |

[VERIFIED] `build/` fell from 23.7 to 9.7 GiB and `game/` from 22.5 to
18.8 GiB. `artifacts/` stayed at 6.85 GiB: the artifacts were not the growth
driver and no artifact was deleted.

## Preserved

The final `generalszh.exe` from each deleted release tree was copied to
`build/engines/` before deletion:

| File | SHA-256 |
|---|---|
| `alpha-engine.exe` | `1CEFD1F4...F8B766` (development fixture) |
| `alpha-engine-final.exe` | `4FD3B817...702F42` (production engine, candidates 9/10) |
| `t089-alpha.exe` | `76099735...BEFA17` |
| `t095-alpha.exe` | `FD3AD052...7FA6BC4` |
| `t111-alpha.exe` | `1B5A809C...71962B` |

The source trees, tracked patches and `build/engine-vs-community/` remain, so
the release trees are reproducible. The deleted alpha copies are recreated by
the patcher test workflow; the current `alpha-stock-v010b` /
`alpha-shockwave-v010b` pair was kept.

## Kept intact

- Stock and ShockWave reference installs, `game/baseline-pristine/`,
  `game/work/`.
- The active `build/last-stand-profile-release/`, the published
  `build/t102-alpha-release/`, and `build/engine-vs-community/`.
- The ShockWave work/engine/patcher copies, `game/last-stand-replay/`,
  `game/engine-test/`, and the v010b alpha pair.
- All `artifacts/` evidence, including the older copies' test records.

## Verification

- `Test-Path` is false for all seven removed paths.
- The five retained executables exist and hash as recorded.
- The protected/current paths above still exist.
- `python tools/check_docs.py` passes after this report and the task entry.

## Retention rule

[ADR-0025](../decisions/ADR-0025-no-fixed-workspace-cap.md) sets the current
policy: there is no fixed size cap. Prefer one active release tree and reuse
it; copy the final executable/hash to `build/engines/` before deleting
superseded intermediates. Reuse the current game copies and keep only
deliberate disposable copies. This pass did not review or delete artifacts;
that remains a separate evidence-selection task.
