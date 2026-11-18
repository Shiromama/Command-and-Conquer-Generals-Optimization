# ISSUE-0059: Rigid shadow cache needs shared geometry revision

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] MeshGeometryClass::Get_Vertex_Array returns a mutable pointer. Pointer/count/transform identity alone cannot detect edits in place; a cached mesh region could retain stale vertices or topology. Source witness: Core/Libraries/Source/WWVegas/WW3D2/meshgeometry.h. This is a correctness gap in the new opt-in cache, not an observed retail crash.

## Resolution / verification

Added one byte-exact geometry snapshot/revision check per shared model per render frame. Regions include that revision when deciding reuse; no hash collision assumption. Pending actual-source mutation regression and runtime verification.

[VERIFIED] `python tools/test-shadow-batches.py` exits0:17actual-source cases pass, including in-place shared vertex and triangle edits with unchanged pointers, transforms and counts. Also covers changed source/model, transforms, LOD/attachment selection, hiding/reordering, size changes,60000-vertex batching, invalid indices/depth guard and resource-cache clearing. These compile actual collector/cache code; they do not establish full renderer image correctness.
