# ISSUE-0141: Native worker raw-route shadow differs from the original solver

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The combined replay preserved sync, routes, orders and script
queue. The live-input raw-route shadow matched 729 of 857 supported
searches. Of the others, 108 successful original paths had matching
expansion and cleanup counts, and 20 original failures differed in
both counts.

## Investigation

[VERIFIED] Native `startPathfind` resets parent, costs and list flags.
It does not clear the existing blocked-by-ally bit. The shadow
previously seeded that bit as false. The shadow also substituted the
whole pool capacity for the records actually free after endpoint
allocation.

## Resolution / verification

[INFERRED] These are plausible causes of the successful-path and
exhaustion differences. The next candidate preserves the start bit
and uses the live free-list length.

[VERIFIED] Native `artifacts/2026-11-20-last-stand-frozen-worker-search/review.py`
verified the 1080p GTX checkpoint. All 189 supported live-input
shadow computations and 646 supported frozen-input worker searches
matched raw route, cost, expansion and cleanup receipts. The 37
unsupported entries left the original solver in place. There was
no mismatch among 835 comparisons across the same 872 native
ground-search entries.
