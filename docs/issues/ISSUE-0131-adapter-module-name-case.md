# ISSUE-0131: Adapter analyzer treated Windows module names as case-sensitive

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] Both graphical replays exited in sync. The Python analyzer
matched the path, command and queue records, then raised
`KeyError: 'd3d8.dll'`. The process module receipts used `D3D8.DLL`.

## Resolution / verification

[VERIFIED] The generated analyzer and its generator now case-fold module
names. `python artifacts/2026-11-20-last-stand-optimus-replay/analyze-pair.py`
exited 0 with both pinned wrapper paths and expected adapter drivers
verified from the original receipts. No replay rerun was needed.
