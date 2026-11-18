# ADR-0022: Require prepared mod inputs in the alpha patcher

- **Status:** Accepted
- **Date:** 2026-11-18
- **Related:** T-095, [ISSUE-0101](../issues/ISSUE-0101-unbounded-mod-archive-extraction.md), [ADR-0019](ADR-0019-community-mod-overlay.md)

## Decision

Both mod inspection and import accept prepared directories and individual game
data archives. Compressed distribution archives must be extracted separately.
This updates the input policy in ADR-0019. Overlay activation and transaction
recovery continue to use the prepared data.

## Evidence

[VERIFIED] The former workflow invoked a general-purpose extractor before the
patcher could bound the amount of data written. The new shared input check
rejects compressed distribution archives before reading their contents. The
patcher tests exercise both entry points and verify activation and restoration
with a prepared directory and a raw game data archive.
