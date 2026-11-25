# Can the Last Stand replay run on the original non-modded game?

- Date: 2026-11-20
- Task: T-113 (side check)
- Evidence: [stock-vs-mod compatibility artifacts](../../artifacts/2026-11-20-stock-vs-mod-replay/manifest.md)
- Related: [ISSUE-0108](../issues/ISSUE-0108-last-stand-replay-sync.md)

## Question

The Last Stand slowdown is severe in the ShockWave/rebuilt-engine setup. Does
the same `stress test replay.rep` run on the original non-modded 1.04 game, so
the slowdown can be attributed to the mod rather than the engine?

## Answer

[VERIFIED] The replay itself names a **custom user map**:
`M=0buserdata/maps/last stand`. The map is
`Documents\...\Maps\Last Stand\Last Stand.map` (119,440 bytes), so the stock
1.04 engine can load the map and start the replay. It renders a battle and
settles into a static frame within about 29 seconds at the GenTool-reported
166 FPS. That frame is **not** a valid stock performance result: it is the
known replay divergence/frozen state, not a completed stock simulation.

[VERIFIED] Running the rebuilt diagnostic engine against **stock data** stops
immediately:

```text
CRC Mismatch in Frame 0
Graphical replay checkpoint frame=2 sync=mismatch resolution=1920x1080
```

The replay requires the ShockWave data from frame 0. The stock-data game is a
different simulation, so its frame times cannot be compared with the
ShockWave/rebuilt run.

[VERIFIED] The retail 1.04 engine with the ShockWave data stayed on the
ShockWave loading screen for more than two minutes and never reached the
battle when `game.dat` was launched directly. The normal mod launcher/load path
may be required. This is a load-path limitation and was not used for a runtime
claim.

## Interpretation

[INFERRED] The user's observation that the stock game feels faster may still
hold for stock maps/scenarios, but this particular replay is a
ShockWave/diagnostic recording. It cannot be replayed faithfully with stock
data. The 166 FPS stock frame is a frozen/diverged state and must not be cited
as evidence of stock performance.

## Next valid comparison

1. **Record a new stock-compatible replay** on the Last Stand map using the
   stock game, then play it on stock and mod data.
2. **Synthetic 1,000-unit group-path harness** on the same map with stock data
   vs ShockWave data, using the rebuilt engine. This avoids the replay CRC
   dependency and isolates the map/data effect. Recommended first.

Either comparison must use the same map, unit counts, group-order pattern and
game speed, and must record frame time on the same adapter/settings.
