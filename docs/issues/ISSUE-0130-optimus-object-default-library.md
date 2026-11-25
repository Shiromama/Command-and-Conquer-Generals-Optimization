# ISSUE-0130: Optimus export-only object advertised a conflicting default runtime

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The first GPU treatment link emitted LNK4098 for `LIBCMT`
after adding the scratch export-only object. The control omitted that
object. This introduced a toolchain difference beyond the preference
export and disqualifies the first treatment link for timing.

[VERIFIED] Editing the batch wrapper while its first link was still
executing shifted the interpreter's position and triggered redundant
links. The scratch session was interrupted with Ctrl+C and returned
exit 1. The running game used its separate engine output.

## Resolution / verification

[VERIFIED] The scratch batch now compiles the runtime-free object with
`/Zl` and rejects a `DEFAULTLIB` directive in the result. The fresh
`start.ps1` rebuilt both variants without LNK4098, confirmed that only
the treatment exports `NvOptimusEnablement`, reverified the shared
link inputs and launched the GTX treatment. The normalized code
sections match after masking base-relocation operands.
