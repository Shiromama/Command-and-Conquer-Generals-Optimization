# T-090 console progress design

The two-choice menu now immediately announces the current operation. Package checks, game-file scans, backup preparation, recovery, file changes, and final verification have distinct messages. Each longer scan periodically reports how many file hashes have been checked. Patch and restore have a known set of paths, so those phases have a short ASCII bar and a checked-path count. The final success line follows the transaction's existing verification.

[SOURCED] Microsoft's progress guidance ties determinate progress to a predictable end and uses indeterminate feedback while work duration is unknown. The Command Line Interface Guidelines recommend immediate feedback during longer work and plain output when a terminal is unavailable. The installer uses line-oriented updates suitable for the existing console and for copied logs. [Microsoft progress controls](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/progress-controls) · [Command Line Interface Guidelines](https://clig.dev/#robustness)

The menu opts in through `--progress`. A normal CLI invocation retains its existing output.
