# ISSUE-0032: Engine staging accepts immutable or arbitrary destinations

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: GameDir is user-controlled. There is no resolved-path containment, immutable-reference exclusion, or reparse-point guard before recursive Force deletion or executable/config writes.

## Reproduction / evidence

[VERIFIED] Inspect `tools/stage-engine.ps1:45-52,60-65,92` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[INFERRED] A misselected original/mod install or pristine baseline can be overwritten; -Force can recursively delete the selected directory. No destructive reproduction was attempted. This is a release blocker for reusing this script as an end-user patcher.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Restrict staging to verified mutable workspace copies; reject protected paths and ancestors and validate resolved targets before mutation. Add identity checks and transactional backup/rollback for a distributable installer.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] Shared safety preflight restricts destinations to direct mutable game children, rejects protected/alias/reparse/hardlink/overlap paths, and guards staging, mod preparation, launch, wrapper, online and performance helpers. Baseline recreation is refused even with Force.

[VERIFIED] 51 PowerShell assertions pass, including real staging-entry rejection for protected paths and their Windows aliases, junctions/hardlinks, source overlap and other mutation helpers. Valid staging of both isolated copies succeeds; 1,914 baseline hashes match. This closes the local unsafe interface, not the future general installer design. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
