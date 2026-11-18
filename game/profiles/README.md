# Config profiles

Portable overlays applied to the **work copy** by `tools/prepare-game-copies.ps1`.
They are intentionally small and machine-independent.

| Profile | File | Effect |
|---|---|---|
| `fullscreen` | `fullscreen/d3d8.cfg` | GenTool `window=3` (FULL preset); borderless 1920×1080 when launched with `-win` |
| `windowed` | `windowed/d3d8.cfg` | GenTool `window=2` (source behavior); useful for A/B comparisons |

## How profiles are applied

The script copies the profile's `d3d8.cfg` over the work copy's file. The baseline copy keeps
its original `d3d8.cfg` (usually `window=2`). Profiles also zero GenTool's map auto-download
entries so a work/baseline run cannot silently pull maps into the copy; set them back to `1`
if you deliberately want GenTool's map pack.

## Adding a profile

1. Create `game/profiles/<name>/` with only the files that differ.
2. Document the exact change and expected behavior here.
3. Add the name to the script's `ValidateSet` and test both apply and revert.

Profiles must not contain absolute paths, registry tweaks, or user-specific settings.
