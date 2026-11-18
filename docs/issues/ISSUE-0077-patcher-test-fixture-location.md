# ISSUE-0077: Patcher test fixtures violate the protected-workspace boundary

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] First executable black-box suite refuses nested game/t080-tests-*/target directories because only direct mutable children of game are allowed. The hardlink test also receives WinError 5 under the filesystem sandbox. No actual game launched. The protection behaved as designed; tests were incorrectly arranged.

## Resolution / verification

Move synthetic game fixtures to direct mutable children and keep package fixtures outside the game target. Run the authorized inert-fixture test outside the restrictive filesystem sandbox for the hardlink case. Rerun pending.

### Verified resolution

[VERIFIED] Direct-child disposable fixtures and separate package fixtures pass. Hardlink, junction and exclusive-lock cases run outside the filesystem sandbox; no game binaries are used in these tests.
