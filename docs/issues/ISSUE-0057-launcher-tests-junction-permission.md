# ISSUE-0057: Mocked launcher suite cannot create test junction in sandbox

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-022

## Evidence

[VERIFIED] `powershell -File tools/test-optimization-fixes.ps1` stops at line 39 with Access denied creating a junction inside its fresh mutable test fixture. No game launches; all process calls are mocked. Original failure retained in artifacts/2026-11-17-queue-replay/launcher-safety-tests.log. Historical T-079 receipt is untouched because output is written only after all assertions pass.

## Resolution / verification

Pending rerun with filesystem permission for the isolated junction/hardlink tests. Output directory is now parameterized so new checks preserve the historical T-079 receipt.

[VERIFIED] Elevated rerun `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-optimization-fixes.ps1 -ArtifactDir artifacts/2026-11-17-queue-replay/launcher-tests` exits 0: PASS 62 staging/environment assertions. The temporary test fixture was removed by its verified mutable-copy cleanup guard. No game launched. New receipt is separate from the original 51-assertion T-079 receipt.
