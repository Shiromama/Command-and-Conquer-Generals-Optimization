# ISSUE-0143: Early worker fixture mutated a published input

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The early-worker fixture exited with access violation
`0xC0000005` after the dependency tracker began sizing its bitsets
from immutable input. The fixture appended a unit to the input
after constructing an accessor over the empty unit table.

## Resolution / verification

[VERIFIED] The fixture constructs a new accessor after populating
the changed input and checks its recorded unit dependency.
`artifacts/2026-11-20-last-stand-early-full-worker/check-fixture.cmd`
passed 256 parallel exact searches.
