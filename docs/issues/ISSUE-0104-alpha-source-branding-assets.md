# ISSUE-0104: Local alpha bundle contains upstream artwork

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-18
- **Task:** T-102

## Evidence

[VERIFIED] The candidate 16 corresponding-source ZIP bundled game icons,
legacy installer images and audio, and other media from the upstream tree.
The Zero Hour resource script also compiled the upstream application icon
into the test engine. The local alpha notices did not account for these
bundled resources.

## Resolution / verification

[VERIFIED] T-102 removed the upstream icon from the prepared resource script
and filtered unused images, audio, and models from packaging. Candidate 17's
engine contains the DPI manifest resource and no icon or bitmap resources.
The final ZIP and corresponding source passed CRC, checksum, private-path
and file inventory checks. The extracted source configured offline, and the
packaged patcher restored all original files after installation on both
disposable game copies. See the [candidate 17 manifest](../../artifacts/2026-11-18-patcher-alpha/candidate-17/manifest.md).
