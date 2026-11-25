# ISSUE-0118: Last Stand maintained-width control paused while minimized

- **Status:** Workaround
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first maintained-width control wrote frame-attribution
rows through frame 3,446 but left no graphical checkpoint in stdout.
The treatment reached frame 17,402 with sync active at 1920×1080.
The [run evidence](../../artifacts/2026-11-19-last-stand-maintained-width/manifest.md)
preserves both receipts.

## Resolution / verification

[VERIFIED] The elevated launch environment still saw PID 136052 as
responding. The game window reported it was minimized. Restoring it via
`sky.activate_window` resumed the original run, with the CSV advancing
to frame 4,406. The measured window starts at frame 16,979.

[VERIFIED] `analyze-combined.py` exited 0 after the resumed control
completed. Both runs matched 15,242 path and 2,185 command records and
reached the 1080p frame 17,402 checkpoint. The timing spread extended to
unmodified subsystems and remains part of [ISSUE-0116](ISSUE-0116-last-stand-timing-variation.md).

[UNKNOWN] What minimized the window remains unknown.
