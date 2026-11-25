# ISSUE-0115: Solo mission smoke rewrote shared Options.ini

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-111

[VERIFIED] The 1080p Release smoke changed the shared Options.ini hash while leaving the last
replay hash identical. The before and after hashes are in the smoke receipt.

## Resolution / verification

[VERIFIED] The campaign difficulty handler saves the preference when Easy is selected. Reversing
that preference change reproduced the original file hash. Restored those exact bytes after
confirming the live file still had the smoke's post-test hash. `Get-FileHash` then returned
`3EB940FC18EE81D97C5AEEBBC238B42FB64BA4ABDC540DB9D59F0689FB0F320C`.
See `restore-smoke-options.txt` in the T-111 artifact directory.
