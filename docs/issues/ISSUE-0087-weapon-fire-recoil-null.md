# ISSUE-0087: Weapon fire FX writes through empty recoil storage

- **Status:** Fixed
- **Severity:** High
- **Date found:** 2026-11-18
- **Task:** T-081

## Evidence

[VERIFIED] The guard control fixture with a human-owned Crusader crashed with exit code `0xC0000005`. The retained minidump `CrashMZ-20261118-020247-c9f87e3-pid182580.dmp` records `EXCEPTION_ACCESS_VIOLATION` with information `[1, 0]` (write to address `0`) at module offset `0x7BE4A`. The instruction is `mov dword ptr [ecx + edx*4], 1`; `ecx` is loaded from `m_weaponRecoilInfoVec[wslot]` and is null. `llvm-symbolizer` with the matching PDB resolves the address to `W3DModelDraw::handleWeaponFireFX`.

[VERIFIED] `W3DModelDraw::handleWeaponFireFX` checked `m_curState->m_validStuff & BARRELS_VALID`, then indexed `m_weaponRecoilInfoVec[wslot][specificBarrelToUse]` whenever the selected barrel had a recoil or muzzle-flash bone. `rebuildWeaponRecoilInfo` sizes that vector when `setModelState` validates barrels, but barrel validation can occur during a later logic update after the state was first used. The barrel vector then has entries while the recoil vector is still empty. The old clamp also accepted `specificBarrelToUse == wbvec.size()`.

[VERIFIED] The crash reproduced in control-2 and control-3 before the fix, on the legacy guard build, so it was independent of the guard resolver.

## Root cause

Recoil storage is not guaranteed to match the current barrel vector at weapon-fire time; indexing it with an empty or stale vector dereferences null.

## Resolution / verification

[VERIFIED] `engine/patches/model-fire-fx-recoil.patch` changes the clamp to `specificBarrelToUse >= (Int)wbvec.size()` and rebuilds recoil storage when its size differs from `wbvec.size()` before indexing. This preserves recoil/muzzle-flash behavior when data is present and skips it safely when it is not.

[VERIFIED] Native 1920x1080 borderless fixed-1 (engine `1CEFD1F4...B766`) fired from Crusader, Tomahawk, Scud and Nuke launchers across 1,500 frames with no exception. The production engine `4FD3B817...2F42` includes the same patch (`alpha-source.json` feature hash `d6e64f68cb6484a0a20fd8e7cac4536718536a1be99106efd66959b6bf6e3354` for `W3DModelDraw.cpp`). Evidence: `artifacts/2026-11-18-guard-range/fixed-1/`, `production-build-1.log` and `CrashMZ-20261118-020247-c9f87e3-pid182580.dmp` (local user data, not copied into the package).
