# ISSUE-0075: Cached crate sources lack an offline registry index

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-18
- **Task:** T-080

## Evidence

[VERIFIED] cargo build --offline --manifest-path patcher/Cargo.toml fails to resolve serde_json although crate sources are cached; no corresponding offline registry index is available. No downloads or game mutations occurred.

## Resolution / verification

Use a checksum-pinned directory source reconstructed from the existing local crate cache. Include that directory source in the local alpha corresponding-source package so builds do not require this PC's cache. Verification pending.

### Verified resolution

[VERIFIED] `cargo build --release --locked --offline` succeeds using the pinned cached directory source. The packaged corresponding source also rebuilds offline; artifacts/2026-11-18-patcher-alpha/source-rebuild-final.log.
