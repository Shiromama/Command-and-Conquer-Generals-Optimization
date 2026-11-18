# ISSUE-0040: Pathfinding edit assumed a precompiled-header include

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** source instrumentation script

## Symptom

[VERIFIED] Initial edit script raised `ValueError: substring not found` looking for PreRTS.h in PathfindCell.cpp. Earlier exploratory reads also used incorrect MD/Core paths; file discovery corrected those immediately.

## Reproduction / evidence

[VERIFIED] PathfindCell.cpp begins its includes with GameLogic/Object.h; it has no PreRTS.h. Only the new telemetry header was created before the script stopped. No existing source was changed by the failed edit.

## Impact

Instrumentation edit needs the actual include anchor. Does not block the task.

## Root cause

[VERIFIED] Assumed all source files used the same precompiled-header convention.

## Workaround

Use the observed first include and assert each edit anchor exists.

## Resolution / verification

Pending build and inspection of the resulting diff.

[VERIFIED] Correct include anchors applied; build-2.log and build-3.log record successful compilation, and smoke-passable completed with telemetry.
