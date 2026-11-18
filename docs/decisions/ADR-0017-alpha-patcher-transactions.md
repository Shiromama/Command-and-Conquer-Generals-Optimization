# ADR-0017: Exact-profile singleplayer alpha patcher

- **Status:** Accepted
- **Date:** 2026-11-18
- **Task:** T-080

## Context

[VERIFIED] Current staging tools only support mutable workspace copies and do not implement a complete end-user uninstall. User authorized building the first alpha with install/verify/uninstall and interrupted-install recovery. Existing stock and ShockWave references remain immutable.

## Decision

Build a standalone Windows Rust CLI with exact SHA256 compatibility catalogs for the local reference data sets. Label these as local tested snapshots, not every retail/mod release. Refuse unknown runtime files and loose overrides. Keep original data archives intact; materialize only known ShockWave launcher mappings. Use system D3D8 for this alpha; back up and temporarily remove the known incompatible GenTool proxy. Do not modify global options, registry or user saves. Provide an explicit native-resolution singleplayer launcher that clears inherited test variables.

Before any game mutation, persist verified original bytes and a journal describing fixed allowlisted target files and before/after hashes. Install, recover and uninstall are idempotent at every file boundary. On recovery accept only original or installed hashes; preserve and report third-party changes rather than force restoration. Use an exclusive per-target lock and atomic file replacement. Retain journal/backups after uninstall for audit and reinstall. Refuse protected references, links, ambiguous paths and running game processes.

Package the tool, pinned engine payload, catalog, checksums, corresponding source/build instructions and notices in a versioned local alpha directory. Exclude proprietary game assets/libraries. Distribution beyond local alpha is not certified; multiplayer, arbitrary mods, broad language/build coverage and long-session validation remain outside v0.1.

## Verification required

Automated interruption/retry at every mutation boundary, install/uninstall/reinstall round trips, conflict preservation, wrong identity, package tampering, locks/path aliases/links, backup corruption, and exact restoration on disposable stock/ShockWave copies. Runtime smoke tests require a heads-up before each launch and native 1920x1080. Record precise test scope; no new performance claim.
