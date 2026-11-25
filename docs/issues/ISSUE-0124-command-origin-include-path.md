# ISSUE-0124: Script-origin syntax check missed a local include

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] `check-origins.cmd` compiled the staged ScriptEngine source,
then stopped with C1083 on AIGroup's local `MovePipeline.inc`. The
original include had resolved beside AIGroup.cpp before copying that
source to the scratch directory.

## Resolution / verification

[VERIFIED] `prepare-command-origin.py` adds each original source location
to the corresponding isolated response file. `check-origins.cmd` then
returned zero for both Win32 translation units.
