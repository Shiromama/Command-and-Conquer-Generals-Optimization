# Native script move pipeline and dominated width probes

- Date: 2026-11-19
- Task: T-112
- Baseline: [local blockers and worker costs](2026-11-19-last-stand-occupancy-workers.md)
- Evidence: [move pipeline](../../artifacts/2026-11-19-last-stand-move-pipeline/manifest.md) and [dominated-neighbor source and fixtures](../../artifacts/2026-11-19-last-stand-dominated-width/manifest.md)

## Move pipeline

[VERIFIED] The diagnostic times `AIGroup::groupMoveToPosition` and its
ground-path, infantry, vehicle and formation application phases.
It preserves command order and action calls. A separate census checks
the original path records and captures nested calls.

[VERIFIED] The native replay reached frame 17,402 with sync active and
the same 1920×1080 graphics settings. All 15,242 path records matched
the unit-footprint treatment outside timing, and all 2,185 command
receipts matched. There were 2,185 outer script calls and no nested
calls in the slow window.

| Same 300-tick window | Mean per tick |
|---|---:|
| Entire group move command | 25.198 ms |
| Ground path computation wrapper | 23.573 ms |
| Infantry application | 0.285 ms |
| Vehicle application | 0.657 ms |
| Formation application | 0.000 ms |
| All work outside the measured formation search | 1.802 ms |

[VERIFIED] The last row subtracts the original formation trace
from the command total. It includes command setup, unclassified work,
and diagnostic overhead. Outside the path computation wrapper,
the mean was 1.624 ms/tick and p95 was 2.711 ms.

[INFERRED] Even dropping the entire 1.802 ms outside the solver
would leave a gap to the 33.33 ms target. Concentrate optimization
on formation search and independent frame work. Eliminating repeats
at the order boundary would require behavioral verification because
the original search often changes when live blockers change.

## Dominated neighbor candidate

[VERIFIED] The six-cell formation neighbor loop applies a nonnegative
clearance penalty. When a neighbor already has an equal or lower
known cost than the candidate's exactly representable base cost, its
clearance penalty cannot cause an improvement. The legacy code still
updates adjacency flags, allocation counts and the blocked-by-ally flag.
The retail-compatible goal edge can also consume the previous
non-goal neighbor's computed cost.

[VERIFIED] A diagnostic candidate avoids the clearance call for a
dominated neighbor while preserving those side effects. It records
the pending width calculation only for the retail carry. It resolves
that calculation before a goal edge needs it or before the expansion
ends, and discards it when the next accepted non-goal neighbor
overwrites the carried cost.

[VERIFIED] The compiled fixture compared the two control-flow models
over 200,000 randomized four-expansion sequences. Relaxation decisions,
observed goal-edge costs and final carried values matched. The models
required 3,840,328 and 3,593,054 width evaluations respectively.
The fixture is independent of the engine's cell and route state.
The prepared candidate needs a native same-binary comparison.

## Dominated neighbor replay result

[VERIFIED] Both runs of the same Win32 Release executable reached
frame 17,402 with matching options at 1920×1080 and sync active.
All 15,242 path and expansion records matched outside clocks. All
2,185 formation command receipts matched.

| 300-frame slow window | Control | Dominated-width shortcut |
|---|---:|---:|
| Mean FPS | 16.23 | 17.18 |
| Mean frame time | 61.61 ms | 58.19 ms |
| p95 frame time | 83.70 ms | 79.56 ms |
| Mean formation search | 23.905 ms/tick | 21.163 ms/tick |
| Mean ordinary plus closest search | 11.674 ms/tick | 11.518 ms/tick |
| Mean draw time | 9.083 ms | 8.732 ms |

[VERIFIED] The treatment deferred 36,501,583 clearance calls in that
window and restored 4,862,598 retail carry values. The intervention
avoided 31,638,985 calls. That includes calls the existing memo
would have answered. The 2.742 ms/tick formation-search reduction
comes from one measured pair, with a smaller draw timing difference
also present.

[INFERRED] Keep this candidate for combined verification. The
observed 58.19 ms mean is still 24.86 ms above the 30 FPS budget.
The [maintained width candidate](2026-11-19-last-stand-maintained-width.md)
tests avoiding repeated clearance work across queries and does not
assume savings add on top of the dominated-width shortcut.
