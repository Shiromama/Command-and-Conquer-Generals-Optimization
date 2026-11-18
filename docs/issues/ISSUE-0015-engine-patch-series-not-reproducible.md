# ISSUE-0015: The per-task engine patches cannot be applied as a series

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-049
- **Related:** T-014, T-015, T-023, T-036, T-039, T-043; [`../../engine/README.md`](../../engine/README.md)
- **Environment:** Git 2.47.0.windows.2; vendor `GeneralsGameCode` @ `0ff1220` (CRLF blobs); Windows 11

## Symptom

The documented reproduction (`git -C vendor\GeneralsGameCode apply engine\patches\<name>.patch`)
does not reproduce the current engine. `T-023` fails first on the clean vendor index, and even
with `--ignore-space-change` the series gets stuck after five patches.

## Reproduction / evidence

```
git -C vendor\GeneralsGameCode apply --cached --check engine\patches\T-023-dpi-awareness.patch
error: while searching for:
{?
	Int exitcode = 1;?
?
#ifdef RTS_PROFILE_LEGACY?
...
error: patch failed: GeneralsMD/Code/Main/WinMain.cpp:798
```

The files are not a sequential series:

| Patch | Also contains |
|---|---|
| `T-015-benchmark-harness.patch` | the T-023 DPI block (`PROJECT PATCH (T-023)`) |
| `T-036-shockwave-stress.patch` | the T-015 `ZH_PERF_LOG` block |
| `T-039-adapter-selection.patch` | the T-015 `ZH_PERF_LOG` block |

A greedy apply to a clean index applies `T-015-benchmark-harness`, `T-021`, `T-030`, `T-041`,
`T-043`, then stops: the remaining patches either re-add already-present code or expect context
that the first five did not create. The patch files also carry a UTF-8 BOM and CRLF while the
vendor blobs are CRLF; `git apply` strips CR from patch lines unless whitespace matching is
relaxed, which is a second failure mode.

## Impact

A clean checkout cannot be turned into the built engine from the tracked record. Provenance and
reproducibility depended on the (gitignored) working tree.

## Root cause

The per-task patch files are snapshots generated against partially patched trees, not independent
incremental diffs against `HEAD`. Later patch files embed earlier changes as added lines. The
"one patch = one change" rule was not enforced when the files were regenerated.

## Workaround

Keep the (gitignored) `vendor/GeneralsGameCode` working tree; do not re-clone and re-apply.

## Resolution / verification

- Added `engine/patches/current-engine.patch`: raw `git diff` of the complete working tree
  against `HEAD` (no BOM). It is the canonical reproducible patch.
- Verification (clean temporary index, real worktree untouched):

```powershell
$env:GIT_INDEX_FILE = "$env:TEMP\engine-index"
git -C vendor\GeneralsGameCode read-tree HEAD
git -C vendor\GeneralsGameCode apply --cached --ignore-space-change engine\patches\current-engine.patch
git -C vendor\GeneralsGameCode diff      # empty: worktree == patched HEAD
```

`--ignore-space-change` is required because Git strips CR from the CRLF vendor blobs while
matching context; the applied content still has the correct CRLF line endings.
- `engine/README.md` and `engine/patches/README.md` now point at the cumulative patch and mark
  the per-task files as historical snapshots. The per-task files are retained for provenance,
  but they are not a sequence and must not be applied together.
- The T-043 patch was also updated with the ISSUE-0014 broadphase fix.

## History

- 2026-11-15 - Found during the T-049 audit; cumulative patch added and verified.
