# ISSUE-0116: Last Stand timing varied between diagnostic baselines

- **Status:** Investigating
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] With the retained memo on and the T-112 inner-loop opt-in off, the new reference
ran at 8.97 FPS in the 300-frame 1080p window. The previous exact-memo executable ran at
14.34 FPS. The path census matched all 15,242 results and both runs reached the sync checkpoint.
Mean draw time also moved from 8.00 to 12.33 ms, outside the intended pathfinding change.
The captures use different executables, and the source of the broad timing variation is unknown.

## Resolution / verification

Compare both T-112 modes within the new binary. Check untargeted draw and per-unit timings for
common drift. Confirm any retained speed claim using a reversed-order or alternating pair.

[VERIFIED] The first T-112 same-binary pair passed route and sync parity. Its group timer
moved from 45.61 to 35.39 ms, ordinary plus closest search from 20.65 to 20.30 ms, and draw
from 12.33 to 12.59 ms. The cause of the earlier cross-run drift remains unverified.

[VERIFIED] The maintained-width A/B also showed substantial timing variation.
The control averaged 9.84 FPS versus 17.26 FPS in the treatment, while draw
and individual searches moved from 12.86 and 19.01 ms to 9.10 and 11.55 ms.
The control resumed after a minimized-window pause early in warmup. Both
traces matched routes, commands and checkpoints. The earlier dominated-width
treatment was already at 17.18 FPS, so the difference in the maintained-width
pair cannot establish the change's isolated effect. See the
[paired measurement](../research/2026-11-19-last-stand-maintained-width.md#combined-native-replay).
