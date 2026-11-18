# ISSUE-0088: Project folder rename blocked by an open handle

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-083

## Symptom and evidence

[VERIFIED] Attempting `Rename-Item -LiteralPath "<workspace>" -NewName "C&C generals optimization" -ErrorAction Stop` from the parent directory failed: `The process cannot access the file because it is being used by another process.` The folder was not renamed. The same command invocation also used an invalid `Split-Path -LiteralPath ... -Parent` parameter combination during its destination check.

## Impact

T-083 cannot complete while the project directory is locked. The process holding the handle is [UNKNOWN].

## Reproduction / workaround

Close applications using the project directory, then retry the rename from its parent, explicitly checking that the destination does not already exist. No applications were terminated.

## Resolution / verification

[VERIFIED] On 2026-11-18, `git rev-parse --show-toplevel` returned the requested `C&C generals optimization` root. From that root, `Test-Path -LiteralPath '..\C&C generals optimization'` returned True and `Test-Path -LiteralPath '..\C&C generals optimization using rust'` returned False. The requested filesystem state is present.
