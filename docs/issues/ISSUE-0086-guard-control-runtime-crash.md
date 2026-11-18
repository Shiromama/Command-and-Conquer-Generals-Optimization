# ISSUE-0086: Guard control crash during weapon fire

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-18
- **Task:** T-081

## Evidence

[VERIFIED] control-2 fixture creates human-owned subjects (mood=33) and a Crusader fires at a visible target (can_attack=3, within_weapon_range=1, last_shot=86, health 800 to 740), then process exits with 0xC0000005 around frame 120. The separate legacy-control build is in use, not the new guard resolver. Raw rows and launch failure: artifacts/2026-11-18-guard-range/control-2/. Managed executable bytes are restored by the runner's finally block.

[VERIFIED] control-3 repeats the corrected human-local-player fixture (mood=33; guard 270, primary range 147.5, distance 100; first shot frame 94; target health 800 to 740 at frame 120) and still exits 0xC0000005 after frame 150. In contrast, the earlier control run with AI-owned subjects (mood=1058) completed all four subjects through frame 1500 without crashing. The current engine is still the legacy guard build. The managed executable was restored and package verify passed. Evidence: artifacts/2026-11-18-guard-range/control-3/ and guard.csv.

[INFERRED] Converting an existing map civilian/AI player to human during a campaign-style game may invalidate map/AI lifecycle assumptions. This is not yet an established crash root cause or evidence that the guard fix causes the crash.

[VERIFIED] The inference above is superseded. The crash dump from PID 182580 (`CrashMZ-20261118-020247-c9f87e3-pid182580.dmp`) records an access violation at module offset `0x7BE4A`, which `llvm-symbolizer` resolves to `W3DModelDraw::handleWeaponFireFX`. The instruction writes through `m_weaponRecoilInfoVec[wslot]` after the barrel vector was validated but the recoil vector was still empty. Root cause and fix are recorded in ISSUE-0087.

## Resolution / verification

[VERIFIED] `engine/patches/model-fire-fx-recoil.patch` clamps the barrel index with `>=` and rebuilds recoil storage when its size differs from the current barrel vector. After the fix, control-4 (human local player, AI opponent) and fixed-1 complete 1,500 frames and fire without an exception. The fixture also uses a real skirmish human/AI setup from startup. Managed executable restoration and package verification passed after every run.
