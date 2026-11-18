# ISSUE-0020: A rebuilt engine never matches the recorded SHA-256

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-15
- **Task:** T-051
- **Related:** [engine/README.md](../../engine/README.md), [ISSUE-0015](ISSUE-0015-engine-patch-series-not-reproducible.md), ADR-0005
- **Environment:** MSVC 19.43.34808, Win32, CMake 3.31.2

## Symptom

A no-op rebuild of the unchanged tree produced
`CE2192D1AAA3EAFD45481105DEA69ED3A094F81A2C0F4CCB753FBB66283D6E5A`, while
`engine/README.md` and `game/shockwave-engine/engine.json` recorded
`F606E60374B662877407D40C0603DA2961981816C8F445A629AD7ABD60C007A3` for the same source.
The docs treat the file hash as the build identity, so this looked like source drift.

## Reproduction / evidence

```
.\tools\build-engine.ps1                     # no source changes
Built: ...\generalszh.exe (6,753,792 bytes, sha256 CE2192D1...D6E5A)
.\tools\engine-identity.ps1 -Path build\engine-vs-community\GeneralsMD\Release\generalszh.exe `
    -Reference game\shockwave-engine\Generals.exe
```

Before the fix, a byte diff showed exactly 14 differing bytes and identical `.text`:

```
0x140            PE TimeDateStamp
0x4FF231..37     __TIME__ string ("16:39:16" vs "15:43:30")
0x57FB1C/38/54   TimeDateStamp of each of the 3 debug-directory entries
0x5A5E8C         CodeView RSDS Age
```

`.text` hash `14677BA0C384...12CF` was identical in both images; only `.rdata` and the PE header
differed. MSVC writes a per-link timestamp, a per-link PDB GUID/age, and some translation unit
embeds `__DATE__`/`__TIME__`.

## Impact

Any rebuild was indistinguishable from a source change, so hash-based verification of
`current-engine.patch` could not distinguish "patch applied correctly" from "same source,
new link". It also made the recorded engine identity in docs and `engine.json` misleading.

## Root cause

A single SHA-256 identifies **one link**, not one source revision. The build is reproducible in
code (`.text` byte-identical) but not in link metadata or embedded compile-time strings.

## Workaround

None needed.

## Resolution / verification

Added `tools/engine-identity.ps1`, which reports the full hash, per-section hashes, the
`.text`-only hash, and a **stable hash**: the image with the PE `TimeDateStamp`, each debug
directory entry timestamp, every CodeView RSDS GUID+age, and the `__DATE__`/`__TIME__` pair
zeroed.

```
.\tools\engine-identity.ps1 -Path build\engine-vs-community\GeneralsMD\Release\generalszh.exe `
    -Reference game\shockwave-engine\Generals.exe
Stable SHA-256:  AA8F76900F401E01E529C8443E04A2F3EF7D5DE3948093FA1E72263AEFA0B1F0   (both files)
Text SHA-256:    14677BA0C384429B30FAF8956AE7B9FBE06A093E834C98DA1D91912E635512CF   (both files)
STABLE IDENTITY MATCH: same code and data apart from link metadata.
```

Consequence for documentation: record the full hash as "this link" and the stable hash (or the
patch diff) as "this source". `engine/README.md` now says so.

## History

- 2026-11-15 — found during the T-051 preflight rebuild; fixed with `tools/engine-identity.ps1`
  and a corrected identity convention.
