# ISSUE-0045: Shadow probe cannot temporarily edit the user options inside the sandbox

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035
- **Environment:** sandboxed Windows PowerShell

## Symptom / evidence

[VERIFIED] system-probe.log records UnauthorizedAccessException writing Documents/Command and Conquer Generals Zero Hour Data/options.ini. No game launched. Profile backup is retained under system-probe.

## Impact

High-detail renderer probe needs a reversible profile change outside the workspace. Original restore attempt also failed and masked the first error.

## Root cause

[VERIFIED] Sandbox denies the external preferences write. Runner unnecessarily rewrote identical original bytes in finally.

## Workaround

Check the current hash before restoring and skip identical writes; run the authorized benchmark with the required filesystem permission. Always preserve backup and record restore identity.

## Resolution / verification

Pending original-byte comparison and permitted probe.

[VERIFIED] Original options and backup SHA256 match F756DE96...86B5C after denied run. Permitted 20-second probe completed; options-restored.json records identical before/after hashes. No reference installation writes.
