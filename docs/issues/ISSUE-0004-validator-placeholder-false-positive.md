# ISSUE-0004: Validator flagged its own documentation of placeholder markers

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-14
- **Task:** T-004
- **Related:** [`../../tools/check_docs.py`](../../tools/check_docs.py), [`../INDEX.md`](../INDEX.md) §3.5
- **Environment:** Python 3.10.0

## Symptom

After documenting the placeholder rules in `docs/INDEX.md` and `docs/log.md`, the validator
failed with six errors — the docs describing the forbidden markers were themselves detected
as unresolved placeholders:

```
ERROR: unresolved placeholder '{{' in docs\INDEX.md
ERROR: unresolved placeholder 'TODO:' in docs\INDEX.md
ERROR: unresolved placeholder 'FIXME' in docs\INDEX.md
... same for docs\log.md ...
FAILED: 6 problem(s).
```

## Reproduction / evidence

1. Add "must not contain `{{`, `TODO:`, or `FIXME`" to any non-template doc.
2. Run `python tools/check_docs.py`.
3. Observe the false positives. `[VERIFIED]` 2026-11-14.

## Impact

Documentation could not describe the rule it was enforcing without failing the check.

## Root cause

The placeholder scan ran over raw prose without excluding inline code spans or fenced code.
The fenced-code case was already handled; inline code was not.

## Workaround

Temporarily write the markers with extra spacing/characters. Not adopted.

## Resolution / verification

`tools/check_docs.py` now strips inline code spans (`INLINE_CODE_RE`) before scanning for
placeholders, so documented markers are ignored while real stray markers still fail.

Verified with (counts reflect the docs at the time of the fix; they grow as files are added):

```
python tools/check_docs.py
# Checked 18 markdown files, 99 relative links, 10 tasks, 4 ADRs.
# OK: documentation system is consistent

python tools/check_docs.py --self-test
# PASS: clean fixture validates
# PASS: broken link detected
# PASS: stale state date detected
# PASS: dangling next_action detected
# SELF-TEST OK: validator detects injected breakage
```

## History

- 2026-11-14 — found by validator run during cold-start review fixes; fixed and re-verified.
