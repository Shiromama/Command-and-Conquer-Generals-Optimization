# ADR-0020: Compatible runtime profile for local mod data

- **Status:** Accepted
- **Date:** 2026-11-18
- **Task:** T-088

## Context

[VERIFIED] The two exact test catalogs use the same `Generals.exe` and `game.dat` hashes. The existing patcher's full inventory gate rejects local data changes even when those engine binaries match. The user wants a portable package for modded and unmodded copies.

## Decision

Keep the exact catalog profiles. For other copies, accept a cataloged engine identity, the expected core Zero Hour archives, and system Direct3D or the cataloged GenTool proxy. Record the selected copy's runtime inventory before changing game files and verify the patched result against that inventory. Leave local mod data in place. Reuse the exact ShockWave materialization rules only when the launcher and every mapped source and destination match their cataloged hashes.

The install journal retains the local inventory and derives managed paths from the same package policy for verification and recovery. Uninstall restores the managed files from their verified backups. The package remains scoped to singleplayer. Unsupported engine builds, graphics proxies and unknown launcher layouts require separate validation.
