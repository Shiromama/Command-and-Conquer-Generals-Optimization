# ISSUE-0120: PGO generator expected a single-line linker command

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-19
- **Task:** T-112

[VERIFIED] The first `prepare-link.py` preview stopped at its record
shape assertion. The current Win32 build's linker record continues on a
second response line with an object input. No linker was invoked.

## Resolution / verification

[VERIFIED] The generator now joins all lines in the one native linker
record and checks that the WinMain object remains present. Running
`python prepare-link.py` exited 0 and wrote the three isolated response
files, including the control and trainer. This verifies argument
generation. Full-engine relinking is a separate check.
