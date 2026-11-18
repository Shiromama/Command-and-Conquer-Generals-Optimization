# ISSUE-0089: Case aliases can delete an original during overlay rollback

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-18
- **Task:** T-082

## Evidence

[VERIFIED] Candidate 9 was run on a disposable synthetic installation using the fixtures from `tools/test-patcher.py`. Two mods targeted the same existing archive using different letter case, with one mod supplying bytes identical to the original. Activation failed with OS error 2. Rollback reported a missing/corrupt backup. The original archive was absent, the mod backup directory was empty, and retrying restore failed.

## Cause and impact

[VERIFIED] `mod_plan` keys entries by case-sensitive strings. On the Windows fixture both entries resolved to the same file. When backup of the second entry failed, rollback restored the first entry and then removed the restored original because its hash matched the second entry's expected overlay hash. No remaining journal backup held the original bytes.

## Resolution / verification

[VERIFIED] Candidate 10 resolves equivalent Windows names before planning and verifies the full backup set before removing any live file. `test_mod_windows_case_alias_and_identical_original`, `test_mod_restore_preflights_all_backups` and the interruption cases in `tools/test-patcher.py` passed. The alias fixture retains the original bytes and spelling after restore. [T-085 verification](../research/2026-11-18-overlay-repair.md)
