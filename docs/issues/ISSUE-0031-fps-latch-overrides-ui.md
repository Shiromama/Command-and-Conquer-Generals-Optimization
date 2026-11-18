# ISSUE-0031: Cached uncapped state overrides live FPS controls

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-078
- **Environment:** Current local vendor working tree and tracked tools

## Symptom

[VERIFIED] Static source inspection: zhUncappedFromEnv caches the initial preference/environment result for the process. The final allowFpsLimit expression ANDs with its inverse; changing m_useFpsLimit or a preset cannot override an initial uncapped state. All normal repository launches force ZH_NOFPSLIMIT=1.

## Reproduction / evidence

[VERIFIED] Inspect `Core/GameEngine/Source/Common/FramePacer.cpp:42-59,155; OptionsMenu.cpp:447; tools/launch-game.ps1` relative to the vendor tree for C++ and repository root for tools. See [engineering review](../research/2026-11-17-optimization-engineering-review.md) and `artifacts/2026-11-17-engineering-review/`.

## Impact

[INFERRED] The saved Unlock FPS checkbox can appear to work while no cap is applied in the same session. A normal repository relaunch forces uncapped again.

## Root cause

[VERIFIED] The implementation does not cover the state or input described above.

## Workaround

Keep explicit launch override semantics separate from mutable preferences; test checkbox and hotkeys in both startup states.

## Resolution / verification

Open. This is an inspection session; no runtime fix or game mutation is claimed.

## History

- 2026-11-17 — Found during independent T-078 inspection.

## T-079 resolution (2026-11-17)

[VERIFIED] FPS overrides now initialize mutable startup state after INI processing; the FramePacer runtime veto/cache is removed. Ordinary launches honor saved preferences. UI re-enabling the cap after the uncapped hotkey restores a finite cap.

[VERIFIED] Compiled tests exercise actual FramePacer limiter method with both live toggle directions and startup preference/env/command combinations. Isolated game smoke: WithFpsLimit median 33.34 ms; uncapped median 9.50 ms. UI mouse interaction was not automated. Evidence: `artifacts/2026-11-17-t079-remediation/manifest.md`; [remediation record](../research/2026-11-17-optimization-remediation.md).
