# ISSUE-0144: Early worker capture used the wrong native crush signature

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-20
- **Task:** T-112

[VERIFIED] The Win32 syntax check failed with MSVC C2664 because
`canCrushOrSquish` accepts an `Object *` target and the shadow
adapter supplied a `const Object *`.

## Resolution / verification

[VERIFIED] Kept the native mutable target pointer type for the
read-only crush test on the simulation thread.
`artifacts/2026-11-20-last-stand-early-full-worker/check-syntax.cmd`
successfully checked both engine translation units.
