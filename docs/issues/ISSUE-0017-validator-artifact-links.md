# ISSUE-0017: Validator treats gitignored artifact evidence as broken links

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-15
- **Task:** T-049
- **Related:** T-004, T-045, T-047, T-048; [`../../tools/check_docs.py`](../../tools/check_docs.py)
- **Environment:** Python 3.10; Windows 11

## Symptom

`python tools/check_docs.py --self-test` failed:

```
SELF-TEST FAILED: clean fixture did not validate:
  broken link: docs\tasks\BOARD.md -> ../../artifacts/shockwave-real-nuke/
```

The normal repo check passed only because the local `artifacts/` directories exist. `artifacts/`
is gitignored except for `README.md`, so a clean clone (and the self-test fixture, which keeps only
`artifacts/README.md`) reports every evidence link as broken.

## Reproduction / evidence

Any doc link into a local artifact directory, e.g. `BOARD.md` -> `artifacts/shockwave-real-nuke/`
or `engine/README.md` -> `artifacts/2026-11-15-copy-audit/`. The self-test fixture strips all
artifact subdirectories, then `validate()` runs the same link check.

## Impact

The documented self-test could not pass, and a fresh clone would fail `check_docs.py` even though
the documentation was valid. This weakens the repository's verification path.

## Root cause

`check_links()` treated every missing relative target as an error, without distinguishing
gitignored, machine-local evidence under `artifacts/` from tracked documentation files.

## Workaround

Keep the artifact directories present locally; do not run `--self-test` (not a fix).

## Resolution / verification

`check_docs.py` now classifies a missing target under the repository's `artifacts/` directory as a
warning (`artifact evidence not present locally`) instead of an error. Missing tracked files
still fail.

```
python tools\check_docs.py
OK: documentation system is consistent

python tools\check_docs.py --self-test
PASS: clean fixture validates
PASS: broken link detected
SELF-TEST OK: validator detects injected breakage
```

## History

- 2026-11-15 - Found while running the T-049 verification; fixed.
