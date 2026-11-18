# ISSUE-0055: Movement harness structures were not navigation obstacles

- **Status:** Fixed
- **Severity:** Medium
- **Date found:** 2026-11-17
- **Task:** T-022
- **Environment:** movement fixture validation

## Symptom / evidence

[VERIFIED] fixture-1/fixture.csv reports chokePassable1 and buildingPassable1 for five spawned power plants. The intended impassable objective is not verified and earlier blocker/on-off runs cannot establish navigation-obstacle cost.

## Root cause

[VERIFIED] Harness used ThingFactory::newObject/setPosition without the explicit addObjectToPathfindMap call made by the canonical GameLogic spawn routine. The canonical routine also calls behavior onBuildComplete and reserves the adjusted mobile goal.

## Impact

Earlier movement/queue traces remain real operations and deterministic evidence, but blocker-scene acceptance is incomplete. T-022 stays In Progress pending corrected navigation fixture and measurements.

## Workaround

Follow the canonical singleplayer spawn lifecycle in the harness; validate blocked building-center and passable opening before accepting blocker runs.

## Resolution / verification

Pending corrected fixture, repeated deterministic runs and queue replay.

[VERIFIED] Canonical onBuildComplete/navigation registration and adjusted goal reservation added only to the explicit singleplayer harness. All six replacement registered-baseline runs validate 200 passable units. The blocker fixture logs chokePassable1/buildingPassable0, 40-world-unit opening (100 spacing minus two 30-unit minor radii). Three repeats per configuration have identical common-frame commands/requests. Earlier blocker timings/queue conclusions are superseded; see registered-summary.json.
