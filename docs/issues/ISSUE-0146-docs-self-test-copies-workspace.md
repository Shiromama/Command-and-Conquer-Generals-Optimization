# ISSUE-0146: Docs validator self-test copies heavyweight workspace trees

- **Status:** Open
- **Severity:** Low
- **Date found:** 2026-11-22
- **Task:** T-119

## Symptom and evidence

[VERIFIED] `python tools/check_docs.py --self-test` was stopped before it
reported any assertion results. In `self_test()`, the validator calls
`shutil.copytree(src, dst, ignore=ignore)` before checking the fixture. The
ignore function omits most artifacts and the stock install but includes
`build/`, `game/` and the separate ShockWave installation. The size checker
reported 9.83 GiB under `build/` and 18.76 GiB under `game/`. The self-test
should only need inputs to the docs validator.

## Workaround

[VERIFIED] `python tools/check_docs.py` passed on the live workspace. This
checks document consistency. The injected-failure tests await a lightweight
fixture.

## Resolution / verification

Use a bounded fixture containing the validator inputs, including tracked
relative-link destinations. Verify that `python tools/check_docs.py --self-test`
passes on a normal workspace without copying local game or build trees.
