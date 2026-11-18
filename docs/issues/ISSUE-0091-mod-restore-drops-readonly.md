# ISSUE-0091: Overlay restore drops an original's read-only attribute

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-082

## Evidence

[VERIFIED] A candidate 9 fixture archive marked read-only before activation returned with its original bytes and a writable attribute after `mods restore`.

## Cause and impact

[VERIFIED] Activation clears the original's read-only attribute before moving it into the backup directory. The overlay journal records the original hash and omits this metadata, so restore leaves the changed attribute in place. Hash-only round trips cannot detect this change.

## Resolution / verification

[VERIFIED] Candidate 10 moves the original with its metadata under the same game root. `test_mod_preserves_readonly_in_restore_and_backup_recovery` verified the original bytes and read-only bit after normal restore and after debug interruptions at checkpoints 2000, 2001 and 3000. [T-085 verification](../research/2026-11-18-overlay-repair.md)
