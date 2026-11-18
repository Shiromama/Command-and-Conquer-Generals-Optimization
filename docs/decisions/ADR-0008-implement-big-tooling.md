# ADR-0008: Implement BIG archive tooling (supersedes ADR-0004)

- **Status:** Accepted
- **Date:** 2026-11-15
- **Deciders:** project lead
- **Related:** T-007, T-037; [`../game-inventory-shockwave.md`](../game-inventory-shockwave.md) §3

## Context

ADR-0004 deferred archive parsing until a concrete need existed. That need arrived with
ShockWave: its content is delivered as `!*.gib` files that the launcher renames to `*.big`,
and its performance characteristics (1,642 particle systems, 2,384 W3D entries, 968 textures)
must be read from the archives to reason about them. The engine's own
`BIGFileSystem.cpp` documents the container layout, including the non-obvious fact that the
archive-size field is little-endian while entry count and directory offset are big-endian.

## Decision

Ship a small first-party reader, [`../../tools/big-archive.py`](../../tools/big-archive.py),
with `info`, `list`, `extract`, and `cat` commands:

- validates magic, size fields against the real file length, directory bounds, and entry
  ranges before returning anything;
- refuses to write outside the requested output directory;
- is used read-only against the installation; extracted data goes to `artifacts/`.

No writer/packer is added: nothing in the current scope needs to rebuild an archive, and a
writer would create a new class of risk (CRC, install mutation).

## Consequences

### Positive

- Mod data can be inspected and compared with stock (particle counts, INI diffs, textures).
- The format quirk (mixed endianness) is captured in code and documentation instead of
  being rediscovered.
- Read-only tooling keeps the installation and baseline untouched.

### Negative / risks

- Extraction can produce large artifacts; they stay gitignored with a manifest.
- Community tools may support more variants (compressed archives, alternate headers); only
  the variants present in this project's installs are validated.

### Follow-ups

- T-007 can be closed as "reader delivered"; a writer remains out of scope.
- Add archive checksums to experiment manifests when extraction drives a measurement.
