# ISSUE-0119: Render census generator found two source anchors

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first `prepare-render-sample.py` run stopped at its
uniqueness guard. The render end marker occurs in both redraw and normal
draw code. No engine source file was written.

## Resolution / verification

[VERIFIED] The generator now searches for the end marker within
`W3DDisplay::draw()`. `python prepare-render-sample.py` exited 0.
`render-submissions.diff` contains one normal draw hook and the required
includes.
