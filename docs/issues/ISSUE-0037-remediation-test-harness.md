# ISSUE-0037: T-079 regression harness refinement

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-079
- **Environment:** Windows PowerShell 5.1 and existing MSVC build

## Symptom

[VERIFIED] The initial new test script failed parsing interpolated `$tag:` strings (InvalidVariableReferenceWithDrive). No test body or game mutation ran.

## Reproduction / evidence

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1`. Results and further validation are recorded under `artifacts/2026-11-17-t079-remediation/`.

## Impact

The new regression harness required correction before its results could validate fixes.

## Root cause

[VERIFIED] PowerShell interprets a colon after an interpolated bare variable as a scope/drive separator; braced variable syntax is required.

## Workaround

Use braced interpolation and run the actual tests again.

## Resolution / verification

Pending successful regression run.

## History

- 2026-11-17 — Recorded initial parser rejection; corrected interpolation before retry.

- 2026-11-17 — After parser correction, sandbox denied creating a test junction (Access is denied). Test stopped before launcher checks; retry needs permission for fixture-only link creation.
- 2026-11-17 - Direct cmd-shell tool invocation misquoted the vcvars path before compilation; moved the exact setup commands into an artifact .cmd file to avoid nested-shell quoting.

- 2026-11-17 — Extracted getter compilation identified a missing FALSE constant in the test stub; supplied the engine-equivalent false constant. The full engine already compiled successfully.

## T-079 resolution (2026-11-17)

[VERIFIED] Corrected PowerShell interpolation, used a literal compiler setup command file, added the engine FALSE constant to the test stub and allowed fixture-only link tests outside the sandbox.

[VERIFIED] Final PowerShell suite exits 0 (51 assertions); compiled source regressions exit 0 (140 scheduler cases plus parser/FPS/policy cases). All disposable game fixtures removed after validating their resolved paths. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).

- 2026-11-17 — Final docs validation rejected checkpoint wording lacking the literal Phase: P2 line; corrected the required marker and reran the validator.
