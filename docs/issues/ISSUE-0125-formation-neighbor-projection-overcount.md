# ISSUE-0125: Formation neighbor sample projection exceeded its parent clock

- **Status:** Investigating
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The neighbor diagnostic reached the native 1080p checkpoint
and matched the original routes, commands and ordered queue. The
projected neighbor span was 26.261 ms/tick, above the directly measured
19.102 ms/tick parent grid-search interval. The projected breakdown is
unfit for ranking or savings claims.

## Resolution / verification

[INFERRED] The sampled parent includes timestamp overhead from nested
scopes, which gets scaled with the sample. A fixed sample phase can also
overrepresent unusually expensive first expansions. Use disjoint sample
groups and rotate their offsets if this breakdown is repeated. Require
the aggregate estimate to fit the directly measured parent interval.
