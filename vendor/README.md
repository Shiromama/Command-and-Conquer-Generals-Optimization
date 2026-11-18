# Vendored sources

Third-party code used as a reference or build base. Vendor trees are **gitignored**; the
exact revisions are pinned in [`sources.lock`](sources.lock).

## GeneralsGameCode

- Upstream: <https://github.com/TheSuperHackers/GeneralsGameCode>
- License: GPL-3.0 (see the clone's `LICENSE.md`)
- Path: `vendor/GeneralsGameCode/` (not tracked)
- Pinned commit: see [`sources.lock`](sources.lock)

Why vendored: it is the actively maintained C++20 fork of the official GPLv3 Zero Hour source
release. It is the base for source-level optimization (ADR-0005), not a dependency of the
documentation tooling.

### Re-create the checkout

```powershell
git clone --depth 1 https://github.com/TheSuperHackers/GeneralsGameCode.git vendor/GeneralsGameCode
git -C vendor/GeneralsGameCode checkout <commit-from-sources.lock>
```

### Working rules

1. Do not commit the vendor tree.
2. Do not make silent edits and call them "upstream". Capture local changes as patches under
   `engine/patches/` (created when the first patch exists) or fork to a tracked location.
3. Record any revision change in `sources.lock` and in [`../docs/log.md`](../docs/log.md).
4. Build output goes to `build/` (gitignored).
