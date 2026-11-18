# ISSUE-0102: Codex Security workbench startup timed out

- **Status:** Open
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-094
- **Environment:** Codex desktop, managed Standard scan startup

## Symptom and evidence

[VERIFIED] The Codex Security prompt-only Standard scan start call timed out
after 300 seconds and returned no scan ID. A focused local offline review
provided the findings in T-094.

## Resolution / verification

Open. A subsequent managed startup must return a running scan ID before
reporting managed scan coverage. The local audit has no independent reviewer.
