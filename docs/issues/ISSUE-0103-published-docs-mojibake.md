# ISSUE-0103: Published documentation contains misdecoded punctuation

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-099
- **Related:** [ISSUE-0074](ISSUE-0074-review-log-encoding.md)

## Evidence

[VERIFIED] The public work log displayed characters stored in the Markdown file.
The first local revision of the log had the intended punctuation. Later local
revisions contain UTF-8 byte sequences interpreted as a legacy Windows encoding
and saved as text. Some sequences show two passes of corruption. The same
sequences occur in both the local and public source trees.

## Resolution / verification

[VERIFIED] Reversed the misdecoding in six Markdown files, preserving line
breaks and restoring the first heading to the text in the initial log revision.
The Markdown, JSON and text file scan found no remaining instances of the
checked sequences. Both checkouts passed `python tools/check_docs.py`.
