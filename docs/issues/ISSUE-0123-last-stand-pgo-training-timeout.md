# ISSUE-0123: Last Stand PGO training stopped before the stress window

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] `start-pgo.ps1 -Action Replay` stopped at the shared runner's
25-minute limit with `on-pgo-train timed out`. The final attributed tick
was 13,225, before the 16,978–17,277 stress window and 17,402 sync
checkpoint. The trainer never proceeded to the optimized replay pair.

## Resolution / verification

[VERIFIED] `capture-training-checkpoint.cmd` ran Microsoft `pgosweep`
with `/noreset` during replay and saved a nonempty 14,905,344-byte
`.pgc`. `prepare-partial.py` verified matching SHA-256 hashes after
copying the saved counters, database, and control into a separate
experiment. A comparison from this training data represents the partial
profile only.

[VERIFIED] `prepare-fast.py` and `start-pgo.ps1 -Action Prepare`
linked a separate `/FASTGENPROFILE` trainer. Its training limit is
60 minutes. The faster trainer still needs native checkpoint verification
before its profile can be considered full-window evidence.
