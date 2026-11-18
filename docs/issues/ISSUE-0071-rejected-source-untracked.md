# ISSUE-0071: Latest rejected renderer source exists only in ignored artifacts

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] git check-ignore identifies artifacts/2026-11-17-t035-rejected/ShadowMapPrototype.inc and renderer-hooks.patch as ignored; git ls-files reports neither. Inspection of every current-engine.patch from b5a4ece's subsequent commits finds no drawScreenShadow/calibrated source. The earlier b5a4ece checkpoint predates that work. EXP029's full local archive is useful on this PC but the latest calibrated/tested source is not preserved as a reproducible tracked source patch.

## Resolution / verification

Preserve a tracked rejected-source patch or source snapshot with an exact base revision and reconstruction instructions, while keeping it out of the active engine. Do not commit binaries or generated traces.

### 2026-11-18 verified resolution

[VERIFIED] Tracked engine/rejected/T-035/ preserves exact retained prototype/hooks plus a pinned base patch and reconstruction instructions. `python tools/verify-rejected-shadow-source.py --output artifacts/2026-11-18-review-fixes/archive-check` exits 0 and reconstructs 30 affected source files in scratch. `python tools/test-shadow-batches.py` with the recorded --output passes 17 actual-source cases. Active renderer is unchanged. Receipts: archive-check/commands.json, archive-check/files.json and batch-tests/run.log under artifacts/2026-11-18-review-fixes/. Historical executable reproduction is not claimed.
