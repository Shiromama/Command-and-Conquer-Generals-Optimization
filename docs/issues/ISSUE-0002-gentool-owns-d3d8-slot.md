# ISSUE-0002: GenTool occupies the d3d8.dll proxy slot

- **Status:** Open
- **Severity:** High
- **Date found:** 2026-11-14
- **Task:** T-009
- **Related:** [`../architecture.md`](../architecture.md) §5 H1, ADR-0002
- **Environment:** `d3d8.dll` 3,843,584 bytes, GenTool 1.0.0.0; `d3d8.cfg` `[gentool76]`

## Symptom

The planned Rust D3D8 proxy hypothesis (H1) assumes control of `d3d8.dll`, but that filename
is already used by GenTool. Dropping in a Rust proxy would replace or conflict with the
community wrapper that this installation depends on.

## Reproduction / evidence

```
Get-Item "...\d3d8.dll" | % VersionInfo
# ProductName: GenTool, FileVersion: 1.0.0.0
d3d8.cfg: [gentool76] / pitch=37
```

`[VERIFIED]`

## Impact

Blocks a naive H1 implementation. Any proxy design must decide: coexist (chain-load GenTool),
supersede it, or avoid the DLL slot entirely (external instrumentation or a different
injection point). Affects T-009 (choose optimization surface) and P3 scope.

## Root cause

Third-party modification present in the reference install; not a defect in project code.

## Workaround

None needed yet. H2 (external instrumentation) and H3 (asset tooling) are unaffected.
Measurements must record whether GenTool is active, since it may alter rendering behavior.

## Resolution / verification

Pending T-009: write an ADR describing the chosen coexistence/supersession strategy. Close
only when the strategy is implemented and verified against a running game.

## History

- 2026-11-14 — recorded during environment inventory (PE version info).
