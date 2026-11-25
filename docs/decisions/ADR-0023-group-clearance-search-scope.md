# ADR-0023: Scope the group clearance cache to one search

- **Status:** Accepted
- **Date:** 2026-11-19
- **Related:** T-111, [1080p replay comparison](../research/2026-11-19-last-stand-graphical-cache.md)

## Decision

Cache formation clearance answers inside an individual group ground search in local Zero Hour
matches. Include the cell, layer, diameter and crusher policy in each key. End reuse when the
search exits or encounters reset, recovery or re-entry. The ordinary solver still chooses the route.

## Evidence

[VERIFIED] The measured 1080p comparison retained every recorded route result and passed the sync
checkpoint. The [earlier whole-route experiment](../research/2026-11-19-last-stand-group-cache.md)
found zero eligible cross-search hits under its global occupancy check.

## Consequences

[VERIFIED] Zero Hour reserves 8,192 entries (224 KiB of entry storage on Win32) per pathfinder,
with bounded lookup cost and eviction by replacement. The local match guard limits the feature
to singleplayer and skirmish. Network and replay playback use the original clearance path.
