# T-084 independent review of DeepSeek's alpha patcher and guard changes

**Date:** 2026-11-18

**Scope:** Four DeepSeek commits from `2fc779b` through `08ad8aa`, reviewed against `c9f87e3`. Review changes are confined to project documentation. Disposable fixtures were used for new checks and no game window was launched.

## Release assessment

Hold candidate 9 mod-overlay use pending [ISSUE-0089](../issues/ISSUE-0089-mod-overlay-case-alias-data-loss.md). A Windows case-alias collision can cause rollback to delete an original without retaining a backup. Candidate 9 also [accepts a changed base through direct activation](../issues/ISSUE-0090-direct-overlay-skips-base-catalog.md) and [drops a read-only attribute during restore](../issues/ISSUE-0091-mod-restore-drops-readonly.md). All three findings reproduced on the packaged executable with disposable synthetic copies. Correctness requires a unique destination per Windows file and rollback that can distinguish originals from overlay files even when the bytes are identical.

## Verification

- [VERIFIED] `python tools/test-patcher.py` exited 0 with 31 tests and one skip. `python tools/test-patcher.py --production --exe <candidate-9>/zh-patcher.exe` exited 0 with 31 tests and five skips. Link creation required a rerun outside the restricted shell. [ISSUE-0092](../issues/ISSUE-0092-sandbox-patcher-link-fixtures.md).
- [VERIFIED] `python tools/test-guard-range.py --source build/alpha-engine-source-final --output build/t084-guard-review` passed 67 compiled source checks. `python tools/test-big-archive.py` passed all four tests. The guard checks exercise extracted methods with stubs. Native control/fixed evidence remains in [EXP-030](../experiments/EXP-030-guard-range-runtime.md).
- [VERIFIED] SHA-256 of the candidate 9 package ZIP, engine, patcher and source ZIP matched the [delivery report](2026-11-18-mod-overlay-delivery.md). The corresponding-source ZIP matched both tracked Rust source files, both reviewed engine feature patches and the transaction suite byte for byte.
- [VERIFIED] `git diff --check c9f87e3..08ad8aa` flagged whitespace on embedded patch context lines in the two engine patch files. The flags are limited to the patch representation.
