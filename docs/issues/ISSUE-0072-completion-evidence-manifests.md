# ISSUE-0072: Completion evidence directories lack required manifests

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] artifacts/2026-11-17-t035-dense/manifest.md and artifacts/2026-11-17-t035-rejected/manifest.md do not exist. Dense raw CSVs and archive source are present, and independent recomputation agrees with the reported ratios. Missing manifests violate the repository's required evidence inventory/provenance workflow.

## Resolution / verification

Add current provenance and SHA256 inventories covering parameters, source/base identity, launch order, raw records, screenshots and archived patch files. Label any reconstructed information honestly.

### 2026-11-18 verified resolution

[VERIFIED] Added manifest.md, provenance.json and SHA256 inventory.json to both dense and rejected artifact directories. Inventories verified against retained files; reconstructed provenance is explicitly labeled and missing original launch parameters remain unknown. Reanalysis with `python tools/analyze-shadow-map-ab.py artifacts/2026-11-17-t035-dense --output artifacts/2026-11-18-review-fixes/dense-analysis.json` exits 0 and retains the rejection. EXP-029 now records unequal frame counts accurately.
