# ADR-0026: Use coverage-checked unattended engine fixtures

- **Status:** Accepted for the debugging workflow
- **Date:** 2026-11-22
- **Related:** T-119, T-120, [debugging instructions](../debugging.md), [ISSUE-0108](../issues/ISSUE-0108-last-stand-replay-sync.md)

## Context

| Evidence | Decision it supports |
|---|---|
| [VERIFIED] T-081 started an ordinary skirmish with a human slot, spawned known stock templates and issued guard orders in the engine. Its paired run detected a guard-range difference. [EXP-030](../experiments/EXP-030-guard-range-runtime.md) | Reuse scripted player-owned fixtures for combat behaviors that depend on ownership. |
| [VERIFIED] T-116's AI-only skirmish advanced past the measurement window without issuing formation orders in it. The played control had 606 zone failures concentrated on 13 leaders. The combined run changed several behaviors and showed 539 alternate-leader successes, which establishes activity but leaves the isolated performance effect open. [T-116 analysis](../research/2026-11-21-last-stand-group-path-failures.md) · [Run manifest](../../artifacts/2026-11-21-t116-group-relax/manifest.md) | Recreate one failing formation for correctness. Script pressure and assert formation coverage for a scale run. Isolate feature switches before measuring. |
| [VERIFIED] T-117's 30-minute attempt logged no deploy-style commands. T-118's existing executable includes other changes and has no runtime result. [Board](../tasks/BOARD.md) · [State](../state.json) | Require a known module and a targeted trigger early. Make the occupant lifetime check the first cache gate. |
| [VERIFIED] Original Last Stand strict playback fails at tick 0 with one script configuration and at tick 4500 with the recorded script inputs. The separately configured diagnostic build passed strict playback through a recorded checkpoint. T-116's newer recording diverged at tick 0 even on its recording executable. [ISSUE-0108](../issues/ISSUE-0108-last-stand-replay-sync.md) · [Profiling report](../research/2026-11-19-last-stand-slowdown.md) · [T-116 manifest](../../artifacts/2026-11-21-t116-group-relax/manifest.md) | Keep strict replay as a useful, bounded source of evidence. A reproducible scripted setup avoids making replay repair a prerequisite for these fixtures. |

## Research and tradeoffs

- [SOURCED] Factorio documents separate headless replay, benchmark and scripted scenario/save test modes. Its scripted test has an explicit completion call. Zero Hour can adopt the completion contract using its existing fixture hooks. Fixing general replay compatibility first would delay tasks that can already use normal game startup and scripted inputs. [Factorio command-line reference](https://wiki.factorio.com/Command_line_parameters)
- [SOURCED] CTest provides per-test timeouts and resource locks. Reuse the repository's existing launch infrastructure first because it owns staging, artifacts and cleanup. CTest can wrap stable fixtures later. A CTest lock applies to its own tests, while the runner needs its own protection from independent launches. [CTest TIMEOUT](https://cmake.org/cmake/help/latest/prop_test/TIMEOUT.html) · [CTest RESOURCE_LOCK](https://cmake.org/cmake/help/latest/prop_test/RESOURCE_LOCK.html)
- [SOURCED] ProcDump can watch for unhandled exceptions or capture a process on demand. WPR records ETW events for analysis in WPA. MSVC ASan supports x86 and requires compatible compiler/link settings. Use these as targeted follow-ups to the first bad assertion, stall or unattributed cost. The routine fixture result should work without those tools installed. [ProcDump](https://learn.microsoft.com/en-us/sysinternals/downloads/procdump) · [WPR](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-recorder) · [MSVC ASan](https://learn.microsoft.com/en-us/cpp/sanitizers/asan?view=msvc-170)
- [INFERRED] UI automation can cover actual user input and presentation when those layers are under test. For the current state-machine, path and lifecycle cases, invoking normal commands from a fixture gives repeatable tick timing and direct coverage evidence. AI-only simulation remains useful when the case proves the required AI actions occurred.

## Decision

Use the smallest representative case with explicit coverage, deterministic inputs where feasible, bounded execution and a machine-readable verdict. Reuse the existing guard and pathfinding harness patterns. Treat the short deploy fixture as the first implementation, then add the formation and lifetime cases. Use a scripted Last Stand workload or qualified strict replay for integration and performance. Keep all fixtures opt-in and local to development builds.

## Consequences

The first implementation needs a working setup, watchdog and result schema before it pays back on repeated runs. Human play is reserved for gaps that require a real observation. A fixture pass applies to its covered conditions. Whole-match behavior, standard replay compatibility and performance remain separate evidence questions.
